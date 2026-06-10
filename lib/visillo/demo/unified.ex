defmodule Visillo.Demo.Unified do
  @moduledoc """
  Demo unificada: editor + file browser + chat + dashboard.

  Navegación con pestañas (Ctrl+Tab / Ctrl+Shift+Tab).
  Cada pestaña ofrece una funcionalidad completa del framework.
  """

  use Visillo.Component

  alias Visillo.Demo.MicroEditor
  alias Visillo.Widgets.TreeView

  @tabs [" Files ", " Editor ", " Chat ", " Dashboard "]

  defstruct [
    :active_tab,
    :width,
    :height,
    :status_msg,
    # Sub-estados
    :editor,
    :tree,
    # Dashboard
    :dash_data,
    :tick_count,
    # Chat simple
    chat_log: [],
    chat_input: ""
  ]

  @impl true
  def init(_props) do
    {w, h} = Alaja.Terminal.size()

    {:ok, editor} = MicroEditor.init([])
    {:ok, tree} = TreeView.init(root: File.cwd!(), show_hidden: false)

    {:ok,
     %__MODULE__{
       active_tab: 0,
       width: w,
       height: h,
       status_msg: "Ctrl+Tab Siguiente · Ctrl+Shift+Tab Anterior · Ctrl+Q Salir",
       editor: editor,
       tree: tree,
       dash_data: %{},
       tick_count: 0
     }}
  end

  @impl true
  def focusable?, do: true

  # ── Cursor ───────────────────────────────────────────────

  @impl true
  def cursor(state) do
    if state.active_tab == 1 do
      MicroEditor.cursor(state.editor)
    else
      nil
    end
  end

  # ── Keyboard ─────────────────────────────────────────────

  @impl true
  def handle_key("tab", [:ctrl], state) do
    new = rem(state.active_tab + 1, length(@tabs))
    {:ok, %{state | active_tab: new, status_msg: "Pestaña: #{Enum.at(@tabs, new)}"}}
  end

  def handle_key("tab", [:ctrl, :shift], state) do
    new = rem(state.active_tab - 1 + length(@tabs), length(@tabs))
    {:ok, %{state | active_tab: new, status_msg: "Pestaña: #{Enum.at(@tabs, new)}"}}
  end

  def handle_key("q", [:ctrl], _state), do: {:quit, :user}

  # ── Tab 0: Files ─────────────────────────────────────────
  def handle_key(key, mods, %{active_tab: 0} = state) do
    case TreeView.handle_key(key, mods, state.tree) do
      {:ok, new_tree} -> {:ok, %{state | tree: new_tree}}
      {:send, {:file_selected, path}} -> {:send, {:open_file_from_tree, path}}
      {:send, {:dir_expanded, path}} -> delegate_tree_msg(state, {:dir_expanded, path})
      {:send, {:dir_collapsed, path}} -> delegate_tree_msg(state, {:dir_collapsed, path})
      :ignore -> :ignore
      other -> other
    end
  end

  # ── Tab 1: Editor ────────────────────────────────────────
  def handle_key(key, mods, %{active_tab: 1} = state) do
    case MicroEditor.handle_key(key, mods, state.editor) do
      {:send, msg} -> {:send, {:editor, msg}}
      :ignore -> :ignore
      {:quit, reason} -> {:quit, reason}
    end
  end

  # ── Tab 2: Chat ──────────────────────────────────────────
  def handle_key(key, [], %{active_tab: 2} = state) when byte_size(key) <= 4 do
    {:ok, %{state | chat_input: state.chat_input <> key}}
  end

  def handle_key("backspace", [], %{active_tab: 2} = state) do
    {:ok, %{state | chat_input: String.slice(state.chat_input, 0..-2//1)}}
  end

  def handle_key("enter", [], %{active_tab: 2} = state) do
    msg = String.trim(state.chat_input)

    if msg != "" do
      reply = chat_reply(msg)
      timestamp = formatted_time()
      log = state.chat_log ++ [" [#{timestamp}] Tú: #{msg}", " [#{timestamp}] Bot: #{reply}"]
      # Keep last 100 messages
      log = if length(log) > 100, do: Enum.take(log, -100), else: log
      {:ok, %{state | chat_log: log, chat_input: ""}}
    else
      :ignore
    end
  end

  def handle_key(_, _, %{active_tab: 2}), do: :ignore

  # ── Tab 3: Dashboard ─────────────────────────────────────
  def handle_key(_, _, %{active_tab: 3}), do: :ignore

  # ── Global catch-all ─────────────────────────────────────
  def handle_key(_, _, _state), do: :ignore

  # ── Update ───────────────────────────────────────────────

  @impl true
  def update({:editor, msg}, state) do
    case MicroEditor.update(msg, state.editor) do
      {:ok, new_editor} -> {:ok, %{state | editor: new_editor}}
      {:ok, new_editor, _cmd} -> {:ok, %{state | editor: new_editor}}
    end
  end

  def update({:open_file_from_tree, path}, state) do
    # Open the file in the editor and switch to editor tab
    {:ok, editor} = MicroEditor.init(file: path)

    {:ok,
     %{
       state
       | editor: editor,
         active_tab: 1,
         status_msg: "Opened: #{path}"
     }}
  end

  def update({:dir_expanded, path}, state) do
    delegate_tree_msg(state, {:dir_expanded, path})
  end

  def update({:dir_collapsed, path}, state) do
    delegate_tree_msg(state, {:dir_collapsed, path})
  end

  def update(:tick, state) do
    # Every 10 ticks, refresh dashboard data
    if rem(state.tick_count, 10) == 0 do
      {:ok, %{state | tick_count: state.tick_count + 1, dash_data: collect_dash_data()}}
    else
      {:ok, %{state | tick_count: state.tick_count + 1}}
    end
  end

  def update(_, state), do: {:ok, state}

  defp delegate_tree_msg(state, msg) do
    {_, new_tree} = TreeView.update(msg, state.tree)
    {:ok, %{state | tree: new_tree}}
  end

  # ── Render ───────────────────────────────────────────────

  @impl true
  def render(state, theme) do
    viewport_h = state.height - 3

    box(border: :none, direction: :column) do
      [
        # Tab bar
        render_tab_bar(state, theme),
        # Separator
        text(""),
        # Active tab content
        render_active_tab(state, theme, viewport_h),
        # Status bar
        render_status(state, theme)
      ]
    end
  end

  defp render_tab_bar(state, _theme) do
    tabs =
      @tabs
      |> Enum.with_index()
      |> Enum.flat_map(fn {label, idx} ->
        tab =
          if idx == state.active_tab do
            text(" #{label} ", color: :background, bg: :foreground, bold: true)
          else
            text(" #{label} ", color: :secondary)
          end

        if idx == 0, do: [tab], else: [text("│", color: :info), tab]
      end)

    box(border: :none, direction: :row) do
      [text(" ")] ++ tabs
    end
  end

  defp render_active_tab(state, theme, viewport_h) do
    case state.active_tab do
      0 -> render_file_browser(state, theme, viewport_h)
      1 -> render_editor(state, theme, viewport_h)
      2 -> render_chat(state, theme, viewport_h)
      3 -> render_dashboard(state, theme, viewport_h)
    end
  end

  # ── Tab 0: File Browser ──────────────────────────────────

  defp render_file_browser(state, theme, viewport_h) do
    tree_content = TreeView.render(state.tree, theme)

    box(border: :single, title: " File Browser ", padding: 0, height: viewport_h) do
      [
        tree_content,
        gap(1),
        text(" ↑↓ Navegar  ·  Enter Abrir  ·  ←→ Expandir/Colapsar", color: :info, italic: true)
      ]
    end
  end

  # ── Tab 1: Editor ────────────────────────────────────────

  defp render_editor(state, theme, _viewport_h) do
    MicroEditor.render(state.editor, theme)
  end

  # ── Tab 2: Chat ──────────────────────────────────────────

  defp render_chat(state, _theme, viewport_h) do
    log_lines = Enum.take(state.chat_log, -(viewport_h - 3))

    box(border: :single, title: " Chat ", padding: 1, height: viewport_h) do
      [
        box(border: :none, height: viewport_h - 4) do
          if log_lines == [] do
            [text(" Escribe algo para empezar...", color: :info, italic: true)]
          else
            Enum.map(log_lines, fn line ->
              color =
                cond do
                  String.contains?(line, "Bot:") -> :success
                  String.contains?(line, "Tú:") -> :primary
                  true -> :foreground
                end

              text(line, color: color)
            end)
          end
        end,
        separator(),
        text("> #{state.chat_input}#{if String.length(state.chat_input) > 0, do: "█", else: ""}",
          color: :foreground
        )
      ]
    end
  end

  # ── Tab 3: Dashboard ─────────────────────────────────────

  defp render_dashboard(state, _theme, viewport_h) do
    data = state.dash_data
    cpu = Map.get(data, :cpu, "N/A")
    mem = Map.get(data, :mem, "N/A")
    disk = Map.get(data, :disk, "N/A")
    host = Map.get(data, :host, "N/A")
    uptime = Map.get(data, :uptime, "N/A")

    box(border: :single, title: " Dashboard ", padding: 1, height: viewport_h) do
      [
        text(" Sistema", bold: true, color: :primary),
        separator(),
        text(" Host: #{host}", color: :foreground),
        text(" Uptime: #{uptime}", color: :foreground),
        gap(1),
        text(" Recursos", bold: true, color: :primary),
        separator(),
        render_metric("CPU", cpu, :info),
        render_metric("Mem", mem, :warning),
        render_metric("Disk", disk, :success),
        gap(1),
        text(" Pestañas disponibles:", color: :info, italic: true),
        text("   [0] Files  — Explorador de archivos", color: :secondary),
        text("   [1] Editor — Editor de texto", color: :secondary),
        text("   [2] Chat   — Asistente", color: :secondary),
        text("   [3] Dashboard — Monitor del sistema", color: :secondary)
      ]
    end
  end

  defp render_metric(label, value, color) do
    text(" #{label}: #{value}", color: color)
  end

  defp render_status(state, _theme) do
    tab_label = Enum.at(@tabs, state.active_tab, "?")
    status_bar(state.status_msg, tab_label, "Ctrl+Q Salir")
  end

  # ── Helpers ──────────────────────────────────────────────

  defp formatted_time do
    {_, {h, m, s}} = :calendar.local_time()
    pad = fn n -> String.pad_leading(to_string(n), 2, "0") end
    "#{pad.(h)}:#{pad.(m)}:#{pad.(s)}"
  end

  defp chat_reply("hola" <> _), do: "¡Hola! ¿En qué puedo ayudarte?"

  defp chat_reply("ayuda" <> _),
    do: "Comandos disponibles: hola, ayuda, editor, sistema, hora, quien_eres"

  defp chat_reply("editor" <> _),
    do:
      "Ve a la pestaña Editor (Ctrl+Tab) para editar archivos. Usa Ctrl+E para el explorador lateral."

  defp chat_reply("sistema" <> _),
    do: "Revisa la pestaña Dashboard para ver métricas del sistema en tiempo real."

  defp chat_reply("hora"), do: "Son las #{formatted_time()}."
  defp chat_reply("hora" <> _), do: "Son las #{formatted_time()}."

  defp chat_reply("quien_eres"),
    do: "Soy el asistente integrado de esta TUI. Estoy aquí para ayudarte a navegar."

  defp chat_reply(_), do: "No entendí. Escribe 'ayuda' para ver comandos disponibles."

  defp collect_dash_data do
    cpu = read_cpu()
    mem = read_mem()
    disk = read_disk()
    host = read_host()
    uptime = read_uptime()

    %{
      cpu: cpu,
      mem: mem,
      disk: disk,
      host: host,
      uptime: uptime
    }
  end

  defp read_cpu do
    # Cross-platform CPU info: Erlang runtime + OS fallback
    # macOS: sysctl, Linux: /proc/stat
    try do
      case :os.type() do
        {:unix, :darwin} ->
          case System.cmd("sh", ["-c", "top -l 1 -n 0 | grep 'CPU usage'"]) do
            {out, 0} -> out |> String.trim() |> String.slice(0..40)
            _ -> "N/A"
          end

        {:unix, _} ->
          case File.read("/proc/loadavg") do
            {:ok, data} -> "load: #{String.trim(data)}"
            _ -> "N/A"
          end

        _ ->
          "N/A"
      end
    rescue
      _ -> "N/A"
    end
  end

  defp read_mem do
    # Cross-platform: Erlang VM memory + OS-specific
    try do
      total = :erlang.memory(:total) |> div(1024 * 1024)
      proc = :erlang.memory(:processes) |> div(1024 * 1024)
      "BEAM: #{total}MB total, #{proc}MB proc"
    rescue
      _ -> "N/A"
    end
  end

  defp read_disk do
    try do
      case :os.type() do
        {:unix, :darwin} ->
          case System.cmd("sh", [
                 "-c",
                 "df -h / | tail -1 | awk '{print $3 \" / \" $2 \" (\" $5 \")\"}'"
               ]) do
            {out, 0} -> String.trim(out)
            _ -> "N/A"
          end

        {:unix, _} ->
          case System.cmd("sh", [
                 "-c",
                 "df -h / | tail -1 | awk '{print $3 \" / \" $2 \" (\" $5 \")\"}'"
               ]) do
            {out, 0} -> String.trim(out)
            _ -> "N/A"
          end

        _ ->
          "N/A"
      end
    rescue
      _ -> "N/A"
    end
  end

  defp read_host do
    case :inet.gethostname() do
      {:ok, name} -> to_string(name)
      _ -> "N/A"
    end
  end

  defp read_uptime do
    try do
      # Cross-platform uptime
      case :os.type() do
        {:unix, :darwin} ->
          case System.cmd("sh", ["-c", "uptime | sed 's/.*up //' | sed 's/,.*//'"]) do
            {out, 0} -> String.trim(out)
            _ -> "N/A"
          end

        {:unix, _} ->
          case File.read("/proc/uptime") do
            {:ok, data} ->
              secs = data |> String.trim() |> String.split(" ") |> hd() |> String.to_integer()
              d = div(secs, 86400)
              h = div(rem(secs, 86400), 3600)
              m = div(rem(secs, 3600), 60)
              "#{d}d #{h}h #{m}m"

            _ ->
              "N/A"
          end

        _ ->
          "N/A"
      end
    rescue
      _ -> "N/A"
    end
  end
end

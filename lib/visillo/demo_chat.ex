defmodule Visillo.Demo.Chat do
  @moduledoc """
  Demo: Interactive chat with "/" commands.

  Features:
    * Message area with auto-scroll
    * Input line for writing messages
    * Special "/" commands:
      - `/help` - Help panel
      - `/list` - Selectable list (choose one)
      - `/multi` - Multi-selection list (choose several)
      - `/onboard` - Animated onboarding process
    * Color-coded messages by type (system, user, command_result, error)
    * Modal overlays for commands
    * Animation via handle_tick for /onboard
  """

  use Visillo.Component

  defstruct [
    :mode,
    # :chat | :help | :list_select | :multi_select | :onboard
    :messages,
    # [%{id, type, author, content, timestamp}]
    :input_buffer,
    :list_items,
    :list_selected,
    :multi_selected,
    # MapSet de indices
    :onboard,
    # %{step, steps, progress, log, done}
    :msg_counter,
    :height,
    :start_onboard,
    :new_msg_ticks
  ]

  @default_items [
    "Elixir",
    "Phoenix Framework",
    "LiveView",
    "Nerves",
    "Broadway",
    "Ecto",
    "Oban",
    "Tesla",
    "Swoosh",
    "Mox"
  ]

  @impl true
  def init(_props) do
    timestamp = System.system_time(:second)

    {:ok,
     %__MODULE__{
       mode: :chat,
       messages: [
         %{
           id: 0,
           type: :system,
           author: "System",
           content: "Welcome to Visillo Chat. Type /help for available commands.",
           timestamp: timestamp
         },
         %{
           id: 1,
           type: :system,
           author: "System",
           content:
             "Commands: /list (select one), /multi (select many), /onboard (animation demo)",
           timestamp: timestamp
         }
       ],
       input_buffer: "",
       list_items: @default_items,
       list_selected: 0,
       multi_selected: MapSet.new(),
       onboard: %{
         steps: ["Connecting", "Authenticating", "Syncing", "Optimizing", "Ready"],
         step: 0,
         progress: 0,
         log: [],
         done: false
       },
       msg_counter: 2,
       height: 24,
       start_onboard: false,
       new_msg_ticks: 0
     }}
  end

  @impl true
  def focusable?, do: true

  @impl true
  def handle_resize(_w, h, state) do
    {:ok, %{state | height: h}}
  end

  # ── Key handlers: Modo chat ────────────────────────────────────────────────
  # NOTA: Los widgets (input(), etc.) son PURAMENTE DISPLAY.
  # El módulo Chat maneja TODOS los eventos de teclado aquí en handle_key.
  # Widgets no procesan eventos — solo decoran la salida visual.

  def handle_key("q", [:ctrl], %{mode: :chat}), do: {:quit, :user}

  def handle_key("enter", [], %{mode: :chat} = _state), do: {:send, :submit_input}

  def handle_key("space", [], %{mode: :chat} = _state), do: {:send, {:input_char, " "}}

  def handle_key("tab", [], %{mode: :chat}), do: :ignore

  def handle_key("backspace", [], %{mode: :chat} = _state), do: {:send, :input_backspace}

  def handle_key("delete", [], %{mode: :chat} = _state), do: {:send, :input_delete}

  def handle_key("home", [], %{mode: :chat} = _state), do: {:send, :input_home}

  def handle_key("end", [], %{mode: :chat} = _state), do: {:send, :input_end}

  def handle_key(char, [], %{mode: :chat} = _state) when byte_size(char) <= 4,
    do: {:send, {:input_char, char}}

  # ── Key handlers: Modo help ────────────────────────────────────────────────

  def handle_key("escape", [], %{mode: :help}), do: {:send, :close_overlay}
  def handle_key("ctrl+c", [], %{mode: :help}), do: {:send, :close_overlay}
  def handle_key("enter", [], %{mode: :help}), do: {:send, :close_overlay}
  def handle_key("q", [], %{mode: :help}), do: {:send, :close_overlay}

  # ── Key handlers: Modo list_select ─────────────────────────────────────────

  def handle_key("up", [], %{mode: :list_select}), do: {:send, {:list_move, -1}}
  def handle_key("down", [], %{mode: :list_select}), do: {:send, {:list_move, 1}}
  def handle_key("enter", [], %{mode: :list_select}), do: {:send, :list_confirm}
  def handle_key("escape", [], %{mode: :list_select}), do: {:send, :close_overlay}
  def handle_key("ctrl+c", [], %{mode: :list_select}), do: {:send, :close_overlay}

  # ── Key handlers: Modo multi_select ────────────────────────────────────────

  def handle_key("up", [], %{mode: :multi_select}), do: {:send, {:list_move, -1}}
  def handle_key("down", [], %{mode: :multi_select}), do: {:send, {:list_move, 1}}
  def handle_key("enter", [], %{mode: :multi_select}), do: {:send, :multi_toggle}
  def handle_key("x", [:ctrl], %{mode: :multi_select}), do: {:send, :multi_confirm}
  def handle_key("escape", [], %{mode: :multi_select}), do: {:send, :close_overlay}
  def handle_key("ctrl+c", [], %{mode: :multi_select}), do: {:send, :close_overlay}

  # ── Key handlers: Modo onboard ─────────────────────────────────────────────

  def handle_key("escape", [], %{mode: :onboard}), do: {:send, :close_overlay}
  def handle_key("ctrl+c", [], %{mode: :onboard}), do: {:send, :close_overlay}

  def handle_key("enter", [], %{mode: :onboard, start_onboard: false}),
    do: {:send, :start_onboard}

  def handle_key("enter", [], %{mode: :onboard, onboard: %{done: true}}),
    do: {:send, :close_overlay}

  def handle_key("q", [], %{mode: :onboard}), do: {:send, :close_overlay}

  # ── Quit ───────────────────────────────────────────────────────────────────

  def handle_key("q", [], _state), do: {:quit, :user}
  def handle_key(_, _, _), do: :ignore

  # ── Tick handler (animacion del onboard + notificacion) ────────────────────

  @impl true
  def handle_tick(_frame, %{mode: :onboard, onboard: ob, start_onboard: true} = state) do
    if ob.done do
      {:ok, state}
    else
      progress = min(100, ob.progress + :rand.uniform(5))
      log_line = log_line_for_step(ob.step, progress)
      step_done = progress >= 100
      new_step = if step_done, do: min(ob.step + 1, length(ob.steps) - 1), else: ob.step

      {:ok,
       %{
         state
         | onboard: %{
             ob
             | step: new_step,
               progress: if(step_done, do: 0, else: progress),
               log: (ob.log ++ [log_line]) |> Enum.take(-12),
               done: ob.step >= length(ob.steps) - 1 && step_done
           }
       }}
    end
  end

  def handle_tick(_frame, state) do
    new_ticks = max(0, (state.new_msg_ticks || 0) - 1)
    {:ok, %{state | new_msg_ticks: new_ticks}}
  end

  # ── Update ─────────────────────────────────────────────────────────────────

  # Input character (modo chat)
  def update({:input_char, char}, state) do
    {:ok, %{state | input_buffer: (state.input_buffer || "") <> char}}
  end

  # Backspace (modo chat)
  def update(:input_backspace, state) do
    buf = state.input_buffer || ""
    {:ok, %{state | input_buffer: String.slice(buf, 0..-2//1)}}
  end

  # Delete in single-line input is a no-op (same line, nothing to delete forward)
  def update(:input_delete, state), do: {:ok, state}

  # Home / End in single-line input are no-ops (cursor always at end)
  def update(:input_home, state), do: {:ok, state}
  def update(:input_end, state), do: {:ok, state}

  @impl true
  def update(:submit_input, %{input_buffer: buf} = state) when is_binary(buf) do
    text = String.trim(buf)

    cond do
      text == "" ->
        {:ok, %{state | input_buffer: ""}}

      String.starts_with?(text, "/") ->
        handle_command(text, state)

      true ->
        {:ok, add_message(state, :user, "You", text)}
    end
  end

  def update(:submit_input, state), do: {:ok, %{state | input_buffer: ""}}

  # Sincronizar input_buffer con el valor del widget input()
  def update({:text_changed, new_val, _cursor}, state) do
    {:ok, %{state | input_buffer: new_val}}
  end

  def update({:list_move, delta}, state) do
    new_sel = max(0, min(state.list_selected + delta, length(state.list_items) - 1))
    {:ok, %{state | list_selected: new_sel}}
  end

  def update(:list_confirm, state) do
    item = Enum.at(state.list_items, state.list_selected, "?")
    msg = "Selected: #{item}"
    {:ok, add_message(%{state | mode: :chat}, :command_result, "System", msg)}
  end

  def update(:multi_toggle, state) do
    sel = state.list_selected

    ms =
      if MapSet.member?(state.multi_selected, sel) do
        MapSet.delete(state.multi_selected, sel)
      else
        MapSet.put(state.multi_selected, sel)
      end

    {:ok, %{state | multi_selected: ms}}
  end

  def update(:multi_confirm, state) do
    items =
      state.multi_selected
      |> MapSet.to_list()
      |> Enum.sort()
      |> Enum.map(&Enum.at(state.list_items, &1))

    msg = "Selected: #{Enum.join(items, ", ")}"

    {:ok,
     add_message(
       %{state | multi_selected: MapSet.new(), mode: :chat},
       :command_result,
       "System",
       msg
     )}
  end

  def update(:close_overlay, state) do
    {:ok, %{state | mode: :chat}}
  end

  def update(:start_onboard, state), do: {:ok, %{state | start_onboard: true}}

  def update(_, state), do: {:ok, state}

  # ── Comandos "/" ───────────────────────────────────────────────────────────

  defp handle_command(text, state) do
    [cmd | _rest] = String.split(text)
    full_cmd = cmd |> String.downcase()
    handle_command_by_name(full_cmd, state)
  end

  defp handle_command_by_name("/help", state) do
    {:ok, %{state | mode: :help, input_buffer: ""}}
  end

  defp handle_command_by_name("/list", state) do
    {:ok, %{state | mode: :list_select, list_selected: 0, input_buffer: ""}}
  end

  defp handle_command_by_name("/multi", state) do
    {:ok,
     %{
       state
       | mode: :multi_select,
         list_selected: 0,
         multi_selected: MapSet.new(),
         input_buffer: ""
     }}
  end

  defp handle_command_by_name("/onboard", state) do
    {:ok,
     %{
       state
       | mode: :onboard,
         input_buffer: "",
         start_onboard: false,
         onboard: %{
           steps: ["Connecting", "Authenticating", "Syncing", "Optimizing", "Ready"],
           step: 0,
           progress: 0,
           log: [],
           done: false
         }
     }}
  end

  defp handle_command_by_name(cmd, state) do
    msg = "Unknown command: #{cmd}. Type /help for available commands."
    {:ok, add_message(state, :error, "System", msg)}
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp add_message(state, type, author, content) do
    id = state.msg_counter || 0

    msg = %{
      id: id,
      type: type,
      author: author,
      content: content,
      timestamp: System.system_time(:second)
    }

    %{
      state
      | messages: state.messages ++ [msg],
        input_buffer: "",
        msg_counter: id + 1,
        new_msg_ticks: 5
    }
  end

  defp msg_area_height(state) do
    # Total minus: border(1 top + 1 bottom) + input(1) + status_bar(1)
    state.height - 4
  end

  defp log_line_for_step(step, progress) do
    lines = %{
      0 => [
        "Resolving hosts...",
        "Establishing connection...",
        "Handshake in progress...",
        "Connected!"
      ],
      1 => [
        "Verifying credentials...",
        "Checking permissions...",
        "Retrieving token...",
        "Authenticated!"
      ],
      2 => [
        "Fetching remote data...",
        "Processing delta updates...",
        "Resolving conflicts...",
        "Data synced!"
      ],
      3 => [
        "Analyzing structures...",
        "Applying optimizations...",
        "Rebuilding indexes...",
        "Optimization complete!"
      ],
      4 => ["Final checks...", "Starting services...", "Ready to go!"]
    }

    step_lines = Map.get(lines, step, ["Working...", "Still working...", "Almost done..."])
    idx = div(progress * length(step_lines), 101)
    Enum.at(step_lines, min(idx, length(step_lines) - 1), "Done!")
  end

  # ── Render ─────────────────────────────────────────────────────────────────

  @impl true
  def render(state, theme) do
    box(border: :rounded, title: " Visillo Chat ", title_align: :center, direction: :column) do
      [
        # Area de mensajes con altura fija
        box(border: :none, direction: :column, height: msg_area_height(state)) do
          render_messages(state, theme)
        end,

        # Input widget — PURAMENTE DISPLAY. Los eventos los maneja Chat.handle_key/3.
        input(
          value: state.input_buffer,
          placeholder: "Type a message or /command...",
          on_change: :text_changed
        ),

        # Status bar
        status_bar(
          if(state.new_msg_ticks > 0, do: "New message!", else: "Chat"),
          "#{length(state.messages)} msgs",
          "Enter send | / commands | q quit"
        ),

        # Overlay on top (modal)
        render_overlay(state, theme)
      ]
    end
  end

  # ── Messages area ──────────────────────────────────────────────────────────

  defp render_messages(state, theme) do
    msg_height = max(1, msg_area_height(state) - 2)
    total_msgs = length(state.messages)
    scroll_y = max(0, total_msgs - msg_height)

    scroll_view(scroll_y: scroll_y) do
      Enum.map(state.messages, fn msg ->
        box(border: :none, direction: :column) do
          [
            box(border: :none, direction: :row) do
              [
                text("#{msg.author}", color: msg_color(msg.type, theme), bold: true),
                text("  #{msg_time(msg)}", color: :info, dim: true),
                text("  [#{msg.type}]", color: msg_color(msg.type, theme), dim: true)
              ]
            end,
            text("  #{msg.content}", color: msg_color(msg.type, theme)),
            separator(label: "##{msg.id}")
          ]
        end
      end)
    end
  end

  defp msg_color(:system, t), do: t.primary
  defp msg_color(:user, t), do: t.foreground
  defp msg_color(:command_result, t), do: t.warning
  defp msg_color(:error, t), do: t.error
  defp msg_color(_, t), do: t.foreground

  defp msg_time(msg) do
    dt = DateTime.from_unix!(msg.timestamp)

    "#{String.pad_leading(to_string(dt.hour), 2, "0")}:#{String.pad_leading(to_string(dt.minute), 2, "0")}:#{String.pad_leading(to_string(dt.second), 2, "0")}"
  end

  # ── Overlays ───────────────────────────────────────────────────────────────

  defp render_overlay(%{mode: :chat}, _theme), do: gap(0)

  defp render_overlay(%{mode: :help}, theme) do
    modal(" / Commands Help ", width: 50) do
      [
        text("/help   - Show this help panel", color: theme.primary),
        separator(),
        text("/list   - Select a single item from a list", color: theme.warning),
        separator(),
        text("/multi  - Toggle multiple items, then confirm", color: theme.secondary),
        separator(),
        text("/onboard- Watch an animated onboarding process", color: theme.success),
        separator(),
        text("Press Esc or Enter to close", color: theme.info, italic: true)
      ]
    end
  end

  defp render_overlay(%{mode: :list_select} = state, _theme) do
    modal(" Select an Item ", width: 45) do
      [
        text("Choose an item:", bold: true),
        list(state.list_items, selected: state.list_selected, max_height: 10),
        separator(),
        text("arrows navigate | Enter confirm | Esc cancel", color: :info, italic: true)
      ]
    end
  end

  defp render_overlay(%{mode: :multi_select} = state, _theme) do
    sel_count = MapSet.size(state.multi_selected)

    modal(" Multi-Select [#{sel_count} selected] ") do
      [
        text("Press Enter to toggle, Ctrl+X to confirm:", bold: true),
        separator(),
        render_multi_items(state),
        separator(),
        status_bar(
          "arrows | Enter toggle",
          "#{sel_count} / #{length(state.list_items)} selected",
          "Ctrl+X confirm | Esc cancel"
        )
      ]
    end
  end

  defp render_overlay(%{mode: :onboard} = state, _theme) do
    modal(" Onboarding Process ", width: 60) do
      if state.onboard.done do
        [
          text("[OK] Onboarding complete!", bold: true, color: :success, align: :center),
          separator(),
          text("Result: All systems operational", color: :foreground),
          separator(),
          text("Press Enter or Esc to close", color: :info, align: :center)
        ]
      else
        if state.start_onboard do
          [
            stepper(state.onboard.steps, state.onboard.step),
            separator(),
            spinner(
              active: true,
              style: :dots,
              label: "Step #{state.onboard.step + 1}: #{current_step_name(state.onboard)}...",
              color: :primary
            ),
            progress_bar(state.onboard.progress, 100, show_percentage: true, color: :primary),
            separator(label: "Log"),
            box(border: :none, direction: :column, height: 6) do
              Enum.map(state.onboard.log, &text("> #{&1}", color: :info))
            end,
            text("Esc to cancel", color: :info, italic: true)
          ]
        else
          [
            text("Onboarding Process", bold: true, color: :primary, align: :center),
            separator(),
            text("This will guide you through the initial setup.", color: :foreground),
            gap(1),
            text("Press Enter to start, Esc to cancel", color: :info, align: :center)
          ]
        end
      end
    end
  end

  defp render_overlay(_, _theme), do: gap(0)

  defp current_step_name(%{steps: steps, step: idx}) do
    Enum.at(steps, idx, "?")
  end

  defp render_multi_items(state) do
    items = state.list_items || []

    box(border: :none, direction: :column) do
      items
      |> Enum.with_index()
      |> Enum.map(fn {item, i} ->
        checked = MapSet.member?(state.multi_selected, i)
        prefix = if checked, do: "[x] ", else: "[ ] "
        is_sel = i == state.list_selected

        text("#{prefix}#{item}",
          bold: is_sel,
          color: if(is_sel, do: :primary, else: :foreground),
          bg: if(is_sel, do: :focus_bg, else: nil)
        )
      end)
    end
  end
end

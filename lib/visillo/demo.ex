defmodule Visillo.Demo.MenuApp do
  @moduledoc """
  Demo: Simple application with menu, navigation, and breadcrumbs.

  Demonstrates:
    * Main menu with keyboard navigation
    * Navigation breadcrumbs
    * List search
    * Status bar
  """

  use Visillo.Component

  defstruct [
    # :main | :list | :detail | :search | :config | :help
    :screen,
    :menu_selected,
    :list_items,
    :list_selected,
    :list_scroll,
    :search_query,
    :search_active,
    :breadcrumbs,
    :detail_item,
    :config_theme,
    :config_mouse,
    :config_animations
  ]

  @menu_items [
    {"📋 Lista de Items", :list},
    {"🔍 Buscar", :search},
    {"⚙️  Configuración", :config},
    {"❓ Ayuda", :help},
    {"🚪 Salir", :quit}
  ]

  @sample_items [
    "Elixir",
    "Erlang",
    "Phoenix",
    "LiveView",
    "Nerves",
    "Broadway",
    "Ecto",
    "Oban",
    "Tesla",
    "Swoosh",
    "ExUnit",
    "Dialyzer",
    "Credo",
    "Mix",
    "Hex"
  ]

  @impl true
  def init(_props) do
    {:ok,
     %__MODULE__{
       screen: :main,
       menu_selected: 0,
       list_items: @sample_items,
       list_selected: 0,
       list_scroll: 0,
       search_query: "",
       search_active: false,
       breadcrumbs: ["Home"],
       detail_item: nil,
       config_theme: "Dracula",
       config_mouse: true,
       config_animations: true
     }}
  end

  @impl true
  def focusable?, do: true

  @impl true
  def handle_key("q", [], state) when state.screen == :main, do: {:quit, :user}

  def handle_key("escape", [], %{screen: :list}), do: {:send, :go_back}
  def handle_key("escape", [], %{screen: :detail}), do: {:send, :go_back}
  def handle_key("escape", [], %{screen: :config}), do: {:send, :go_back}
  def handle_key("escape", [], %{screen: :help}), do: {:send, :go_back}
  def handle_key("escape", [], %{screen: :search}), do: {:send, :go_back}

  def handle_key("enter", [], state) when state.screen == :main do
    {:send, {:menu_select, state.menu_selected}}
  end

  def handle_key("up", [], state) when state.screen == :main do
    {:send, {:menu_move, -1}}
  end

  def handle_key("down", [], state) when state.screen == :main do
    {:send, {:menu_move, 1}}
  end

  def handle_key("up", [], state) when state.screen == :list do
    {:send, {:list_move, -1}}
  end

  def handle_key("down", [], state) when state.screen == :list do
    {:send, {:list_move, 1}}
  end

  def handle_key("enter", [], state) when state.screen == :list do
    {:send, {:list_select}}
  end

  def handle_key(char, [], state) when state.search_active do
    case char do
      "backspace" -> {:send, {:search_del}}
      "enter" -> {:send, :search_commit}
      _ when byte_size(char) <= 4 -> {:send, {:search_char, char}}
      _ -> :ignore
    end
  end

  def handle_key("t", [], state) when state.screen == :config do
    {:send, :toggle_theme}
  end

  def handle_key("enter", [], state) when state.screen == :config do
    {:send, :toggle_mouse}
  end

  def handle_key("a", [], state) when state.screen == :config do
    {:send, :toggle_animations}
  end

  def handle_key(_, _, _), do: :ignore

  @impl true
  def update({:menu_move, delta}, state) do
    new_sel = rem(state.menu_selected + delta + length(@menu_items), length(@menu_items))
    {:ok, %{state | menu_selected: new_sel}}
  end

  def update({:menu_select, idx}, state) do
    case Enum.at(@menu_items, idx) do
      {_, :quit} ->
        {:ok, state, {:quit, :user}}

      {label, screen} ->
        {:ok,
         %{
           state
           | screen: screen,
             breadcrumbs: state.breadcrumbs ++ [label],
             search_active: screen == :search,
             search_query: if(screen == :search, do: "", else: state.search_query)
         }}

      _ ->
        {:ok, state}
    end
  end

  def update(:go_back, state) do
    breadcrumbs = Enum.drop(state.breadcrumbs, -1)
    {:ok, %{state | screen: :main, breadcrumbs: breadcrumbs, search_active: false}}
  end

  def update({:list_move, delta}, state) do
    items = filtered_items(state)
    new_sel = max(0, min(state.list_selected + delta, length(items) - 1))
    scroll = compute_scroll(new_sel, state.list_scroll, 10)
    {:ok, %{state | list_selected: new_sel, list_scroll: scroll}}
  end

  def update({:list_select}, state) do
    items = filtered_items(state)
    item = Enum.at(items, state.list_selected)

    {:ok,
     %{state | screen: :detail, detail_item: item, breadcrumbs: state.breadcrumbs ++ [item || ""]}}
  end

  def update({:search_char, char}, state) do
    {:ok, %{state | search_query: state.search_query <> char, list_selected: 0, list_scroll: 0}}
  end

  def update({:search_del}, state) do
    q = String.slice(state.search_query, 0..-2//1)
    {:ok, %{state | search_query: q, list_selected: 0, list_scroll: 0}}
  end

  def update(:search_commit, state) do
    {:ok,
     %{
       state
       | screen: :list,
         search_active: false,
         breadcrumbs: ["Home", "Buscar", state.search_query]
     }}
  end

  def update(:toggle_theme, state) do
    new_theme = if state.config_theme == "Dracula", do: "Light", else: "Dracula"
    {:ok, %{state | config_theme: new_theme}}
  end

  def update(:toggle_mouse, state), do: {:ok, %{state | config_mouse: !state.config_mouse}}

  def update(:toggle_animations, state),
    do: {:ok, %{state | config_animations: !state.config_animations}}

  def update(_, state), do: {:ok, state}

  @impl true
  def render(state, theme) do
    box(border: :rounded, direction: :column, title: " Visillo Demo ", title_align: :center) do
      [
        breadcrumbs(state.breadcrumbs, color: theme.primary),
        separator(),
        render_screen(state, theme),
        separator(),
        render_status_bar_content(state, theme)
      ]
    end
  end

  defp render_screen(%{screen: :main} = state, _theme) do
    box(direction: :column, border: :none, padding: 1) do
      Enum.map(@menu_items |> Enum.with_index(), fn {{label, _}, i} ->
        is_sel = i == state.menu_selected

        text(
          if(is_sel, do: " > ", else: "   ") <> label,
          bold: is_sel,
          color: if(is_sel, do: :primary, else: :foreground)
        )
      end)
    end
  end

  defp render_screen(%{screen: :list} = state, _theme) do
    items = filtered_items(state)

    box(direction: :column, border: :none) do
      [
        text("#{length(items)} items encontrados", color: :info),
        separator(),
        list(items,
          selected: state.list_selected,
          scroll_offset: state.list_scroll,
          max_height: 12
        )
      ]
    end
  end

  defp render_screen(%{screen: :search} = state, _theme) do
    items = filtered_items(state)

    box(direction: :column, border: :none, padding: 1) do
      [
        text("Buscar:", bold: true),
        input(value: state.search_query, placeholder: "Escribe para filtrar…"),
        separator(label: "#{length(items)} resultados"),
        list(items,
          selected: state.list_selected,
          scroll_offset: state.list_scroll,
          max_height: 8
        )
      ]
    end
  end

  defp render_screen(%{screen: :detail, detail_item: item}, _theme) do
    box(direction: :column, border: :single, title: " Detalle ", padding: 1) do
      [
        text("Elemento: #{item}", bold: true, color: :primary),
        separator(),
        paragraph(
          "Esta es la vista de detalle para '#{item}'. En una aplicación real, aquí verías información detallada del elemento seleccionado.",
          wrap: :word
        ),
        gap(),
        text("Pulsa Escape para volver", color: :info, italic: true)
      ]
    end
  end

  defp render_screen(%{screen: :config} = state, _theme) do
    box(border: :none, direction: :column, padding: 1) do
      [
        text("Configuracion", bold: true, color: :primary),
        separator(),
        text("Theme: #{state.config_theme}", color: :info),
        text("  Press 't' to toggle theme", color: :foreground, italic: true),
        gap(1),
        text("[#{if state.config_mouse, do: "x", else: " "}] Mouse support", color: :foreground),
        gap(1),
        text("[#{if state.config_animations, do: "x", else: " "}] Animations",
          color: :foreground
        ),
        gap(1),
        text("Pulsa Escape para volver", color: :info, italic: true)
      ]
    end
  end

  defp render_screen(%{screen: :help}, _theme) do
    box(border: :none, direction: :column, padding: 1) do
      [
        text("Ayuda - Atajos de teclado", bold: true, color: :primary),
        separator(),
        text("Flechas arriba/abajo   Navegar menu"),
        text("Enter                 Seleccionar"),
        text("Escape                Volver atras"),
        text("q                     Salir"),
        gap(1),
        text("En listas:", bold: true, color: :secondary),
        text("  Flechas             Navegar items"),
        text("  Enter               Ver detalle"),
        gap(1),
        text("En busqueda:", bold: true, color: :secondary),
        text("  Cualquier tecla     Filtrar"),
        text("  Backspace           Borrar caracter"),
        text("  Enter               Confirmar filtro"),
        gap(1),
        text("Visillo Framework v1.0", color: :info, italic: true)
      ]
    end
  end

  defp render_screen(_, _), do: text("Pantalla desconocida")

  defp render_status_bar_content(%{screen: screen}, _theme) do
    hint =
      case screen do
        :main -> "Flechas * Enter Seleccionar * q Salir"
        :list -> "Flechas * Enter Detalle * Esc Volver"
        :detail -> "Esc Volver"
        :search -> "Escribir * Backspace * Enter Fijar * Esc Volver"
        :config -> "t Tema * Enter Mouse * a Animac. * Esc Volver"
        :help -> "Esc Volver"
        _ -> "Esc Volver"
      end

    status_bar(
      to_string(screen) |> String.capitalize(),
      "Visillo",
      hint
    )
  end

  defp filtered_items(%{search_query: "", list_items: items}), do: items

  defp filtered_items(%{search_query: q, list_items: items}) do
    q_down = String.downcase(q)
    Enum.filter(items, &String.contains?(String.downcase(&1), q_down))
  end

  defp compute_scroll(selected, scroll, viewport_height) do
    cond do
      selected < scroll -> selected
      selected >= scroll + viewport_height -> selected - viewport_height + 1
      true -> scroll
    end
  end
end

defmodule Visillo.Demo.MicroEditor do
  @moduledoc """
  Demo: Editor de texto tipo micro/nano con soporte multi-buffer.

  Demuestra el uso del framework para aplicaciones complejas de edición.
  Características:
    * Edición de texto multilínea con múltiples buffers (tabs)
    * Ctrl+Tab / Ctrl+Shift+Tab cambiar de buffer
    * Ctrl+N nuevo buffer, Ctrl+O abrir archivo en nuevo buffer, Ctrl+W cerrar buffer
    * Barra de estado con posición del cursor
    * Modal de confirmación al salir con cambios
    * Atajos de teclado tipo micro
  """

  use Visillo.Component

  defmodule Buffer do
    @moduledoc false
    defstruct [
      :lines,
      :cursor_row,
      :cursor_col,
      :scroll_row,
      :scroll_col,
      :filename,
      :modified,
      :undo_stack,
      :undo_index,
      :clipboard,
      :selection
    ]
  end

  defstruct [
    :buffers,
    :active_buffer,
    # :normal | :confirm_quit | :open_file
    :mode,
    :status_msg,
    :width,
    :height,
    # Ruta que el usuario está escribiendo en el diálogo "Abrir archivo"
    :open_file_path,
    # Sidebar (TreeView)
    :tree_state,
    # Word wrap: si true, las líneas largas se envuelven visualmente
    wrap: false,
    sidebar_open: false,
    sidebar_width: 30
  ]

  # ── Buffer helpers ──────────────────────────────────────────────────────

  defp buf(state), do: Enum.at(state.buffers, state.active_buffer, %Buffer{lines: [""]})

  defp set_buf(state, buffer) do
    %{state | buffers: List.replace_at(state.buffers, state.active_buffer, buffer)}
  end

  defp update_buf(state, fun), do: set_buf(state, fun.(buf(state)))

  @impl true
  def init(props) do
    filename = Keyword.get(props, :file, "untitled.txt")
    wrap = Keyword.get(props, :wrap, false)

    file_content =
      case File.read(filename) do
        {:ok, text} -> String.split(text, "\n")
        {:error, _} -> [""]
      end

    # Obtener dimensiones reales del terminal en el momento del init.
    # El App llamará handle_resize/3 también en el primer render, pero
    # queremos valores correctos desde el principio para el layout.
    {w, h} = Alaja.Terminal.size()

    initial_buffer = %Buffer{
      lines: file_content,
      cursor_row: 0,
      cursor_col: 0,
      scroll_row: 0,
      scroll_col: 0,
      filename: filename,
      modified: false,
      undo_stack: [],
      undo_index: -1,
      clipboard: "",
      selection: nil
    }

    {:ok,
     %__MODULE__{
       buffers: [initial_buffer],
       active_buffer: 0,
       mode: :normal,
       status_msg: "Ctrl+S Guardar \u2022 Ctrl+Q Salir \u2022 Ctrl+E Sidebar",
       width: w,
       height: h,
       open_file_path: "",
       wrap: wrap,
       tree_state:
         Visillo.Widgets.TreeView.init(root: File.cwd!(), show_hidden: false)
         |> elem(1)
     }}
  end

  @impl true
  def focusable?, do: true

  @impl true
  def cursor(%{mode: :open_file}), do: nil
  def cursor(%{mode: :confirm_quit}), do: nil

  def cursor(%__MODULE__{wrap: true} = state) do
    b = buf(state)
    line_count = length(b.lines)
    line_num_width = String.length(to_string(line_count))
    text_width = state.width - line_num_width - 3

    visual_rows_before =
      b.lines
      |> Enum.take(b.cursor_row)
      |> Enum.reduce(0, fn line, acc ->
        acc + length(wrap_line_segments(line, max(text_width, 1)))
      end)

    segment_idx = div(b.cursor_col, max(text_width, 1))
    segment_col = rem(b.cursor_col, max(text_width, 1))

    scroll_visual =
      b.lines
      |> Enum.take(b.scroll_row)
      |> Enum.reduce(0, fn line, acc ->
        acc + length(wrap_line_segments(line, max(text_width, 1)))
      end)

    screen_col = line_num_width + 3 + segment_col
    screen_row = 1 + visual_rows_before + segment_idx - scroll_visual
    {max(0, screen_col), max(1, screen_row)}
  end

  def cursor(state) do
    b = buf(state)
    line_count = length(b.lines)
    line_num_width = String.length(to_string(line_count))
    screen_col = line_num_width + 3 + (b.cursor_col - b.scroll_col)
    screen_row = 1 + (b.cursor_row - b.scroll_row)
    {screen_col, screen_row}
  end

  @impl true
  def handle_resize(w, h, state) do
    {:ok, %{state | width: w, height: h}}
  end

  @impl true
  def handle_key("enter", [], %{mode: :confirm_quit}), do: {:send, :confirm_quit}
  def handle_key("y", [], %{mode: :confirm_quit}), do: {:send, :confirm_quit}
  def handle_key("Y", [], %{mode: :confirm_quit}), do: {:send, :confirm_quit}
  def handle_key("escape", [], %{mode: :confirm_quit}), do: {:send, :cancel_quit}
  def handle_key("n", [], %{mode: :confirm_quit}), do: {:send, :cancel_quit}
  def handle_key("N", [], %{mode: :confirm_quit}), do: {:send, :cancel_quit}
  def handle_key(_, _, %{mode: :confirm_quit}), do: :ignore

  # ── Modo: Abrir archivo ────────────────────────────────────────────
  def handle_key("enter", [], %{mode: :open_file} = state),
    do: {:send, {:open_file, state.open_file_path}}

  def handle_key("escape", [], %{mode: :open_file}), do: {:send, :cancel_open_dialog}

  def handle_key("backspace", [], %{mode: :open_file}), do: {:send, :open_path_backspace}

  def handle_key(char, [], %{mode: :open_file}) when byte_size(char) <= 4,
    do: {:send, {:open_path_char, char}}

  def handle_key(_, _, %{mode: :open_file}), do: :ignore

  # ── Multi-buffer (tabs) ─────────────────────────────────
  def handle_key("tab", [:ctrl], _state), do: {:send, :next_buffer}
  def handle_key("tab", [:ctrl, :shift], _state), do: {:send, :prev_buffer}
  def handle_key("w", [:ctrl], _state), do: {:send, :close_buffer}

  def handle_key("q", [:ctrl], state) do
    if Enum.any?(state.buffers, & &1.modified) do
      {:send, :show_confirm_quit}
    else
      {:quit, :user}
    end
  end

  def handle_key("e", [:ctrl], _state), do: {:send, :toggle_sidebar}

  # ── Sidebar navigation (when open) ───────────────────────
  def handle_key("up", [], %{sidebar_open: true}), do: {:send, :sidebar_up}
  def handle_key("down", [], %{sidebar_open: true}), do: {:send, :sidebar_down}

  def handle_key("enter", [], %{sidebar_open: true} = state) do
    entry = Enum.at(state.tree_state.entries, state.tree_state.selected)

    if entry do
      case entry.type do
        :dir ->
          if entry.expanded,
            do: {:send, {:dir_collapsed, entry.path}},
            else: {:send, {:dir_expanded, entry.path}}

        :file ->
          {:send, {:file_selected, entry.path}}
      end
    else
      :ignore
    end
  end

  def handle_key("right", [], %{sidebar_open: true} = state) do
    entry = Enum.at(state.tree_state.entries, state.tree_state.selected)

    if entry && entry.type == :dir && !entry.expanded do
      {:send, {:dir_expanded, entry.path}}
    else
      :ignore
    end
  end

  def handle_key("left", [], %{sidebar_open: true} = state) do
    entry = Enum.at(state.tree_state.entries, state.tree_state.selected)

    if entry && entry.type == :dir && entry.expanded do
      {:send, {:dir_collapsed, entry.path}}
    else
      :ignore
    end
  end

  def handle_key("s", [:ctrl], _state), do: {:send, :save}
  def handle_key("n", [:ctrl], _state), do: {:send, :new_file}
  def handle_key("o", [:ctrl], _state), do: {:send, :show_open_dialog}
  def handle_key("up", [], _state), do: {:send, {:move, -1, 0}}
  def handle_key("down", [], _state), do: {:send, {:move, 1, 0}}
  def handle_key("left", [], _state), do: {:send, {:move, 0, -1}}
  def handle_key("right", [], _state), do: {:send, {:move, 0, 1}}
  def handle_key("home", [], _state), do: {:send, :line_start}
  def handle_key("end", [], _state), do: {:send, :line_end}
  def handle_key("enter", [], _state), do: {:send, :newline}
  def handle_key("tab", [], _state), do: {:send, {:insert_char, "  "}}
  def handle_key("backspace", [], _state), do: {:send, :backspace}
  def handle_key("delete", [], _state), do: {:send, :delete_char}
  def handle_key("page_up", [], _state), do: {:send, {:page, -1}}
  def handle_key("page_down", [], _state), do: {:send, {:page, 1}}

  # Undo / Redo
  def handle_key("z", [:ctrl], _state), do: {:send, :undo}
  def handle_key("y", [:ctrl], _state), do: {:send, :redo}
  def handle_key("z", [:ctrl, :shift], _state), do: {:send, :redo}

  # Copy / Paste
  def handle_key("c", [:ctrl], _state), do: {:send, :copy}
  def handle_key("v", [:ctrl], _state), do: {:send, :paste}

  # Shift+Arrow selection
  def handle_key("up", [:shift], _state), do: {:send, {:select_move, -1, 0}}
  def handle_key("down", [:shift], _state), do: {:send, {:select_move, 1, 0}}
  def handle_key("left", [:shift], _state), do: {:send, {:select_move, 0, -1}}
  def handle_key("right", [:shift], _state), do: {:send, {:select_move, 0, 1}}

  def handle_key(char, [], _state) when byte_size(char) <= 4 do
    {:send, {:insert_char, char}}
  end

  def handle_key(_, _, _), do: :ignore

  # ── Multi-buffer (tabs) updates ──────────────────────────

  def update(:next_buffer, state) do
    new_idx = rem(state.active_buffer + 1, length(state.buffers))
    {:ok, %{state | active_buffer: new_idx}}
  end

  def update(:prev_buffer, state) do
    new_idx = rem(state.active_buffer - 1 + length(state.buffers), length(state.buffers))
    {:ok, %{state | active_buffer: new_idx}}
  end

  def update(:close_buffer, state) do
    buffers = List.delete_at(state.buffers, state.active_buffer)

    {buffers, new_idx} =
      if buffers == [] do
        {[
           %Buffer{
             lines: [""],
             filename: "untitled.txt",
             undo_stack: [],
             undo_index: -1,
             clipboard: "",
             selection: nil
           }
         ], 0}
      else
        new_idx = min(state.active_buffer, length(buffers) - 1)
        {buffers, new_idx}
      end

    {:ok, %{state | buffers: buffers, active_buffer: new_idx}}
  end

  # ── Navigation ───────────────────────────────────────────

  def update({:move, dr, dc}, state) do
    b = buf(state)
    new_row = max(0, min(b.cursor_row + dr, length(b.lines) - 1))
    line = Enum.at(b.lines, new_row, "")
    new_col = max(0, min(b.cursor_col + dc, String.length(line)))
    scroll = compute_scroll(new_row, b.scroll_row, state.height - 3)
    scroll_c = compute_scroll_col(new_col, b.scroll_col, state.width, length(b.lines), state.wrap)

    {:ok,
     set_buf(state, %{
       b
       | cursor_row: new_row,
         cursor_col: new_col,
         scroll_row: scroll,
         scroll_col: scroll_c,
         selection: nil
     })}
  end

  def update(:line_start, state) do
    b = buf(state)
    {:ok, set_buf(state, %{b | cursor_col: 0, scroll_col: 0, selection: nil})}
  end

  def update(:line_end, state) do
    b = buf(state)
    line = Enum.at(b.lines, b.cursor_row, "")
    new_col = String.length(line)
    scroll_c = compute_scroll_col(new_col, b.scroll_col, state.width, length(b.lines), state.wrap)
    {:ok, set_buf(state, %{b | cursor_col: new_col, scroll_col: scroll_c, selection: nil})}
  end

  def update({:page, dir}, state) do
    b = buf(state)
    page_size = state.height - 3
    new_row = max(0, min(b.cursor_row + dir * page_size, length(b.lines) - 1))
    scroll = compute_scroll(new_row, b.scroll_row, page_size)
    line = Enum.at(b.lines, new_row, "")
    new_col = min(b.cursor_col, String.length(line))
    scroll_c = compute_scroll_col(new_col, b.scroll_col, state.width, length(b.lines), state.wrap)

    {:ok,
     set_buf(state, %{
       b
       | cursor_row: new_row,
         cursor_col: new_col,
         scroll_row: scroll,
         scroll_col: scroll_c,
         selection: nil
     })}
  end

  # ── Editing ──────────────────────────────────────────────

  def update({:insert_char, char}, state) do
    update_buf(state, fn b ->
      lines =
        List.update_at(b.lines, b.cursor_row, fn line ->
          String.slice(line, 0, b.cursor_col) <>
            char <> String.slice(line, b.cursor_col..-1//1)
        end)

      new_col = b.cursor_col + 1

      scroll_c =
        compute_scroll_col(new_col, b.scroll_col, state.width, length(b.lines), state.wrap)

      %{
        b
        | lines: lines,
          cursor_col: new_col,
          scroll_col: scroll_c,
          modified: true,
          selection: nil
      }
    end)
  end

  def update(:newline, state) do
    update_buf(state, fn b ->
      b = push_undo(b)

      current_line = Enum.at(b.lines, b.cursor_row, "")
      before = String.slice(current_line, 0, b.cursor_col)
      after_cur = String.slice(current_line, b.cursor_col..-1//1)

      lines =
        b.lines
        |> List.replace_at(b.cursor_row, before)
        |> List.insert_at(b.cursor_row + 1, after_cur)

      new_row = b.cursor_row + 1
      scroll = compute_scroll(new_row, b.scroll_row, state.height - 3)

      %{
        b
        | lines: lines,
          cursor_row: new_row,
          cursor_col: 0,
          scroll_row: scroll,
          scroll_col: 0,
          modified: true,
          selection: nil
      }
    end)
  end

  def update(:backspace, state) do
    b = buf(state)

    cond do
      b.cursor_col > 0 ->
        b = push_undo(b)

        lines =
          List.update_at(b.lines, b.cursor_row, fn line ->
            String.slice(line, 0, b.cursor_col - 1) <> String.slice(line, b.cursor_col..-1//1)
          end)

        new_col = b.cursor_col - 1

        scroll_c =
          compute_scroll_col(new_col, b.scroll_col, state.width, length(b.lines), state.wrap)

        {:ok,
         set_buf(state, %{
           b
           | lines: lines,
             cursor_col: new_col,
             scroll_col: scroll_c,
             modified: true,
             selection: nil
         })}

      b.cursor_row > 0 ->
        b = push_undo(b)

        prev_line = Enum.at(b.lines, b.cursor_row - 1, "")
        current_line = Enum.at(b.lines, b.cursor_row, "")
        merged = prev_line <> current_line

        lines =
          b.lines
          |> List.replace_at(b.cursor_row - 1, merged)
          |> List.delete_at(b.cursor_row)

        new_row = b.cursor_row - 1

        {:ok,
         set_buf(state, %{
           b
           | lines: lines,
             cursor_row: new_row,
             cursor_col: String.length(prev_line),
             modified: true,
             selection: nil
         })}

      true ->
        {:ok, state}
    end
  end

  def update(:delete_char, state) do
    update_buf(state, fn b ->
      current_line = Enum.at(b.lines, b.cursor_row, "")

      if b.cursor_col < String.length(current_line) do
        b = push_undo(b)

        lines =
          List.update_at(b.lines, b.cursor_row, fn line ->
            String.slice(line, 0, b.cursor_col) <>
              String.slice(line, (b.cursor_col + 1)..-1//1)
          end)

        %{b | lines: lines, modified: true, selection: nil}
      else
        b
      end
    end)
  end

  # ── Sidebar (TreeView) ───────────────────────────────────

  def update(:toggle_sidebar, state) do
    {:ok, %{state | sidebar_open: not state.sidebar_open}}
  end

  def update({:file_selected, path}, state) do
    # Abrir archivo seleccionado en el TreeView como nuevo buffer
    case File.read(path) do
      {:ok, text} ->
        lines = String.split(text, "\n")

        new_buffer = %Buffer{
          lines: lines,
          cursor_row: 0,
          cursor_col: 0,
          scroll_row: 0,
          scroll_col: 0,
          filename: path,
          modified: false,
          undo_stack: [],
          undo_index: -1,
          clipboard: "",
          selection: nil
        }

        {:ok,
         %{
           state
           | buffers: state.buffers ++ [new_buffer],
             active_buffer: length(state.buffers),
             mode: :normal,
             status_msg: "Opened: #{path} (#{length(lines)} lines)"
         }}

      {:error, reason} ->
        {:ok, %{state | status_msg: "Error reading: #{reason}"}}
    end
  end

  def update({:dir_expanded, path}, state) do
    {_, tree} = Visillo.Widgets.TreeView.update({:dir_expanded, path}, state.tree_state)
    {:ok, %{state | tree_state: tree}}
  end

  def update({:dir_collapsed, path}, state) do
    {_, tree} = Visillo.Widgets.TreeView.update({:dir_collapsed, path}, state.tree_state)
    {:ok, %{state | tree_state: tree}}
  end

  def update(:sidebar_up, state) do
    t = state.tree_state
    new_sel = max(t.selected - 1, 0)

    {:ok,
     %{
       state
       | tree_state: %{
           t
           | selected: new_sel,
             scroll_offset: compute_scroll(new_sel, t.scroll_offset, state.height - 3)
         }
     }}
  end

  def update(:sidebar_down, state) do
    t = state.tree_state
    new_sel = min(t.selected + 1, length(t.entries) - 1)

    {:ok,
     %{
       state
       | tree_state: %{
           t
           | selected: new_sel,
             scroll_offset: compute_scroll(new_sel, t.scroll_offset, state.height - 3)
         }
     }}
  end

  # ── File operations ──────────────────────────────────────

  def update(:save, state) do
    b = buf(state)
    content = Enum.join(b.lines, "\n")

    case File.write(b.filename, content) do
      :ok ->
        {:ok,
         set_buf(state, %{b | modified: false}) |> Map.put(:status_msg, "Saved: #{b.filename}")}

      {:error, reason} ->
        {:ok, %{state | status_msg: "Error saving: #{reason}"}}
    end
  end

  # Ctrl+N: Nuevo buffer
  def update(:new_file, state) do
    new_buffer = %Buffer{
      lines: [""],
      cursor_row: 0,
      cursor_col: 0,
      scroll_row: 0,
      scroll_col: 0,
      filename: "untitled.txt",
      modified: false,
      undo_stack: [],
      undo_index: -1,
      clipboard: "",
      selection: nil
    }

    {:ok,
     %{
       state
       | buffers: state.buffers ++ [new_buffer],
         active_buffer: length(state.buffers),
         mode: :normal,
         status_msg: "New buffer",
         open_file_path: ""
     }}
  end

  # Ctrl+O: Mostrar diálogo de abrir archivo
  def update(:show_open_dialog, state) do
    b = buf(state)
    {:ok, %{state | mode: :open_file, open_file_path: b.filename || ""}}
  end

  def update(:cancel_open_dialog, state) do
    {:ok, %{state | mode: :normal, open_file_path: ""}}
  end

  def update({:open_path_char, char}, state) do
    {:ok, %{state | open_file_path: (state.open_file_path || "") <> char}}
  end

  def update(:open_path_backspace, state) do
    path = state.open_file_path || ""
    {:ok, %{state | open_file_path: String.slice(path, 0..-2//1)}}
  end

  def update({:open_file, path}, state) do
    trimmed = String.trim(path)

    case File.stat(trimmed) do
      {:ok, %{type: :directory}} ->
        {:ok, %{state | status_msg: "Is a directory: #{trimmed}"}}

      {:ok, _} ->
        case File.read(trimmed) do
          {:ok, text} ->
            lines = String.split(text, "\n")

            new_buffer = %Buffer{
              lines: lines,
              cursor_row: 0,
              cursor_col: 0,
              scroll_row: 0,
              scroll_col: 0,
              filename: trimmed,
              modified: false,
              undo_stack: [],
              undo_index: -1,
              clipboard: "",
              selection: nil
            }

            {:ok,
             %{
               state
               | buffers: state.buffers ++ [new_buffer],
                 active_buffer: length(state.buffers),
                 mode: :normal,
                 status_msg: "Opened: #{trimmed} (#{length(lines)} lines)",
                 open_file_path: ""
             }}

          {:error, reason} ->
            {:ok, %{state | status_msg: "Error reading file: #{reason}"}}
        end

      {:error, _} ->
        {:ok, %{state | status_msg: "File not found: #{trimmed}"}}
    end
  end

  def update(:undo, state) do
    update_buf(state, fn b ->
      new_idx = b.undo_index + 1

      if new_idx < length(b.undo_stack) do
        snap = Enum.at(b.undo_stack, new_idx)

        %{
          b
          | lines: snap.lines,
            cursor_row: snap.cursor_row,
            cursor_col: snap.cursor_col,
            undo_index: new_idx,
            modified: true
        }
      else
        b
      end
    end)
  end

  def update(:redo, state) do
    update_buf(state, fn b ->
      new_idx = b.undo_index - 1

      if new_idx >= 0 do
        snap = Enum.at(b.undo_stack, new_idx)

        %{
          b
          | lines: snap.lines,
            cursor_row: snap.cursor_row,
            cursor_col: snap.cursor_col,
            undo_index: new_idx,
            modified: true
        }
      else
        b
      end
    end)
  end

  def update(:copy, state) do
    update_buf(state, fn b ->
      line = Enum.at(b.lines, b.cursor_row, "")
      %{b | clipboard: line}
    end)
    |> then(fn s -> %{s | status_msg: "Copied line #{buf(s).cursor_row + 1}"} end)
    |> then(&{:ok, &1})
  end

  def update(:paste, state) do
    b = buf(state)

    if b.clipboard != "" do
      update_buf(state, fn b2 ->
        b2 = push_undo(b2)

        lines =
          List.update_at(b2.lines, b2.cursor_row, fn line ->
            String.slice(line, 0, b2.cursor_col) <>
              b2.clipboard <> String.slice(line, b2.cursor_col..-1//1)
          end)

        new_col = b2.cursor_col + String.length(b2.clipboard)

        scroll_c =
          compute_scroll_col(new_col, b2.scroll_col, state.width, length(b2.lines), state.wrap)

        %{
          b2
          | lines: lines,
            cursor_col: new_col,
            scroll_col: scroll_c,
            modified: true,
            selection: nil
        }
      end)
      |> then(fn s -> %{s | status_msg: "Pasted"} end)
      |> then(&{:ok, &1})
    else
      {:ok, %{state | status_msg: "Nothing to paste"}}
    end
  end

  def update({:select_move, dr, dc}, state) do
    update_buf(state, fn b ->
      sel =
        b.selection ||
          %{
            start_row: b.cursor_row,
            start_col: b.cursor_col,
            end_row: b.cursor_row,
            end_col: b.cursor_col
          }

      new_row = max(0, min(b.cursor_row + dr, length(b.lines) - 1))
      line = Enum.at(b.lines, new_row, "")
      new_col = max(0, min(b.cursor_col + dc, String.length(line)))

      scroll = compute_scroll(new_row, b.scroll_row, state.height - 3)

      scroll_c =
        compute_scroll_col(new_col, b.scroll_col, state.width, length(b.lines), state.wrap)

      %{
        b
        | cursor_row: new_row,
          cursor_col: new_col,
          scroll_row: scroll,
          scroll_col: scroll_c,
          selection: %{sel | end_row: new_row, end_col: new_col}
      }
    end)
  end

  def update(:show_confirm_quit, state) do
    {:ok, %{state | mode: :confirm_quit}}
  end

  def update(:confirm_quit, _state) do
    {:ok, %{}, {:quit, :user}}
  end

  def update(:cancel_quit, state) do
    {:ok, %{state | mode: :normal}}
  end

  def update(_, state), do: {:ok, state}

  @impl true
  def render(state, theme) do
    # Tab bar consume 1 row, header 1 row, status 1 row, sidebar row?
    viewport_h = state.height - 3
    sidebar_w = state.sidebar_width

    editor_area =
      if state.sidebar_open do
        sidebar_content = Visillo.Widgets.TreeView.render(state.tree_state, theme)

        box(border: :none, direction: :row) do
          [
            box(border: :single, title: " files ", flex: sidebar_w, padding: 0) do
              [sidebar_content]
            end,
            text("│", dim: true),
            box(border: :none, flex: 1000 - sidebar_w) do
              [render_editor(state, theme, viewport_h)]
            end
          ]
        end
      else
        render_editor(state, theme, viewport_h)
      end

    box(border: :none, direction: :column) do
      [
        # Tab bar
        render_tab_bar(state, theme),

        # Header bar
        render_header(state, theme),

        # Editor area (with optional sidebar)
        editor_area,

        # Status bar
        render_status(state, theme),

        # Modals
        cond do
          state.mode == :confirm_quit -> render_quit_modal(theme)
          state.mode == :open_file -> render_open_modal(state, theme)
          true -> nil
        end
      ]
    end
  end

  defp render_tab_bar(state, _theme) do
    tabs =
      state.buffers
      |> Enum.with_index()
      |> Enum.flat_map(fn {buf, idx} ->
        marker = if buf.modified, do: "● ", else: ""

        tab =
          if idx == state.active_buffer do
            text(" #{marker}#{buf.filename} ", color: :background, bg: :foreground)
          else
            text(" #{marker}#{buf.filename} ", color: :secondary)
          end

        if idx == 0, do: [tab], else: [text("│", color: :info), tab]
      end)

    box(border: :none, direction: :row) do
      [text(" ")] ++ tabs
    end
  end

  defp render_header(state, _theme) do
    b = buf(state)
    title = if(b.modified, do: "● ", else: "") <> b.filename

    status_bar(
      title,
      "micro-like editor",
      "Ctrl+N New • Ctrl+O Open • Ctrl+S Save • Ctrl+E Sidebar • Ctrl+Q Quit"
    )
  end

  defp render_editor(state, _theme, viewport_h) do
    b = buf(state)
    line_count = length(b.lines)
    line_num_width = String.length(to_string(line_count))
    text_width = state.width - line_num_width - 3
    cont_prefix = String.duplicate(" ", line_num_width) <> " │"

    {visual_rows, logical_map} =
      b.lines
      |> Enum.reduce({[], [], 0}, fn line, {vrows, lmap, lr} ->
        segs =
          if state.wrap do
            wrap_line_segments(line, text_width)
          else
            [line]
          end

        {vrows ++ segs, lmap ++ List.duplicate(lr, length(segs)), lr + 1}
      end)
      |> then(fn {v, m, _} -> {v, m} end)

    visual_start =
      if state.wrap do
        logical_map |> Enum.find_index(fn lr -> lr >= b.scroll_row end) |> Kernel.||(0)
      else
        b.scroll_row
      end

    visible_visual = Enum.slice(visual_rows, visual_start, viewport_h)

    box(border: :none, direction: :column, height: viewport_h) do
      visible_visual
      |> Enum.with_index()
      |> Enum.map(fn {seg, vi} ->
        visual_idx = visual_start + vi
        abs_row = Enum.at(logical_map, visual_idx, 0)
        is_current = abs_row == b.cursor_row

        first_visual_of_row =
          visual_idx == 0 or Enum.at(logical_map, visual_idx - 1) != abs_row

        line_prefix =
          if first_visual_of_row do
            String.pad_leading(to_string(abs_row + 1), line_num_width) <> " │"
          else
            cont_prefix
          end

        vs =
          if state.wrap do
            String.slice(seg, 0, max(0, text_width))
          else
            seg |> String.slice(b.scroll_col..-1//1) |> String.slice(0, max(0, text_width))
          end

        text(
          "#{line_prefix} #{vs}",
          color: if(is_current, do: :foreground, else: :secondary),
          bg: if(is_current, do: :focus_bg, else: nil)
        )
      end)
    end
  end

  # Divide una línea en segmentos de máximo max_width caracteres.
  defp wrap_line_segments(line, max_width) do
    len = String.length(line)

    if len <= max_width do
      [line]
    else
      for offset <- 0..(len - 1)//max_width do
        String.slice(line, offset, max_width)
      end
    end
  end

  defp render_status(state, _theme) do
    b = buf(state)
    pos = "Ln #{b.cursor_row + 1}, Col #{b.cursor_col + 1}"
    total = "#{length(b.lines)} líneas"
    status_bar(state.status_msg, pos, total)
  end

  defp render_quit_modal(_theme) do
    modal("¿Salir sin guardar?") do
      [
        text("Hay cambios sin guardar. ¿Deseas salir?", color: :warning),
        separator(),
        confirm("", on_yes: :confirm_quit, on_no: :cancel_quit, default: :no)
      ]
    end
  end

  defp render_open_modal(state, _theme) do
    modal("Abrir archivo", width: 60) do
      [
        text("Ruta:", bold: true),
        input(
          value: state.open_file_path || "",
          placeholder: "/path/to/file.ex"
        ),
        gap(1),
        text("Enter abrir • Escape cancelar", color: :info, italic: true)
      ]
    end
  end

  defp push_undo(buffer) do
    snapshot = %{
      lines: buffer.lines,
      cursor_row: buffer.cursor_row,
      cursor_col: buffer.cursor_col
    }

    stack = [snapshot | Enum.drop(buffer.undo_stack, buffer.undo_index + 1)]
    stack = Enum.take(stack, 50)
    %{buffer | undo_stack: stack, undo_index: 0}
  end

  defp compute_scroll(row, scroll, viewport) do
    cond do
      row < scroll -> row
      row >= scroll + viewport -> row - viewport + 1
      true -> scroll
    end
  end

  defp compute_scroll_col(_cursor_col, _scroll_col, _width, _line_count, true), do: 0

  defp compute_scroll_col(cursor_col, scroll_col, width, line_count, false) do
    line_num_width = String.length(to_string(line_count))
    gutter_width = line_num_width + 3
    available = width - gutter_width

    cond do
      cursor_col < scroll_col ->
        max(0, cursor_col - 2)

      cursor_col >= scroll_col + available - 1 ->
        cursor_col - available + 2

      true ->
        scroll_col
    end
  end
end

defmodule Visillo.Demo.Dashboard do
  @moduledoc """
  Demo: Dashboard de monitoreo tipo btop/htop.

  Demuestra:
    * Layout multi-panel con split
    * Gráficos de sparkline animados
    * Tablas con datos en tiempo real
    * Barras de progreso con umbrales de color
    * Actualización periódica via handle_tick
  """

  use Visillo.Component

  defstruct [
    :cpu_history,
    :mem_used,
    :mem_total,
    :processes,
    :selected_proc,
    :uptime_secs,
    :tab,
    :disk_total,
    :disk_used,
    :tick_counter
  ]

  @proc_names [
    "beam.smp",
    "postgres",
    "nginx",
    "redis-server",
    "node",
    "python3",
    "ruby",
    "elixir"
  ]

  @impl true
  def init(_props) do
    {:ok,
     %__MODULE__{
       cpu_history: List.duplicate(0.0, 60),
       mem_used: 4_200,
       mem_total: 16_384,
       processes: generate_processes(),
       selected_proc: 0,
       uptime_secs: read_uptime(),
       tab: 0,
       disk_total: 100,
       disk_used: 45,
       tick_counter: 0
     }}
  end

  @impl true
  def handle_key("q", [], _), do: {:quit, :user}
  def handle_key("up", [], _), do: {:send, {:proc_move, -1}}
  def handle_key("down", [], _), do: {:send, {:proc_move, 1}}
  def handle_key("tab", [], _), do: {:send, :next_tab}
  def handle_key(_, _, _), do: :ignore

  @impl true
  def handle_tick(_frame, state) do
    # Leer métricas reales cada 8 ticks (~4 veces/segundo a 30fps).
    # System.cmd es caro (spawn de proceso OS) y llamarlo cada tick
    # bloquearía el event loop del App.
    state = %{state | tick_counter: state.tick_counter + 1}

    if rem(state.tick_counter, 8) == 0 do
      cpu = read_cpu()
      cpu_history = tl(state.cpu_history) ++ [cpu]
      {mem_used, mem_total} = read_memory()
      processes = read_processes()
      {disk_total, disk_used} = read_disk()
      uptime = read_uptime()

      {:ok,
       %{
         state
         | cpu_history: cpu_history,
           mem_used: mem_used,
           mem_total: mem_total,
           processes: processes,
           uptime_secs: uptime,
           disk_total: disk_total,
           disk_used: disk_used
       }}
    else
      {:ok, state}
    end
  end

  @impl true
  def update({:proc_move, delta}, state) do
    new_sel = max(0, min(state.selected_proc + delta, length(state.processes) - 1))
    {:ok, %{state | selected_proc: new_sel}}
  end

  def update(:next_tab, state) do
    {:ok, %{state | tab: rem(state.tab + 1, 3)}}
  end

  def update(_, state), do: {:ok, state}

  @impl true
  def render(state, theme) do
    cpu_pct = List.last(state.cpu_history, 0.0)

    box(border: :bold, title: " System Monitor ", title_align: :center, direction: :column) do
      [
        tabs(
          [
            {" Overview ", :overview},
            {" Processes ", :processes},
            {" System ", :system}
          ],
          active: state.tab
        ),
        separator(),
        render_tab(state, state.tab, cpu_pct, theme),
        status_bar(
          "↑↓ Navigate  •  Tab Switch view",
          "#{format_uptime(state.uptime_secs)}  |  BEAM v#{System.version()}  |  #{length(state.processes)} procs",
          "q quit",
          bg: theme.status_bar_bg
        )
      ]
    end
  end

  # ─── Tab 0: Overview ───────────────────────────────────────────

  defp render_tab(state, 0, cpu_pct, _theme) do
    mem_pct = state.mem_used / max(state.mem_total, 1) * 100
    disk_pct = state.disk_used / max(state.disk_total, 1) * 100

    box(border: :none, direction: :column) do
      [
        box(border: :none, direction: :row) do
          [
            box(border: :single, title: " CPU ", direction: :column, flex: 1) do
              [
                progress_bar(cpu_pct, 100.0,
                  label: "CPU",
                  color: cpu_color(cpu_pct),
                  show_percentage: true
                ),
                gap(1),
                chart(state.cpu_history, type: :sparkline, colors: [:primary], height: 4)
              ]
            end,
            gap(1),
            box(border: :none, direction: :column, flex: 1) do
              [
                box(border: :single, title: " Memory ", direction: :column) do
                  [
                    progress_bar(state.mem_used, state.mem_total,
                      label: "RAM",
                      color: mem_color(mem_pct),
                      show_percentage: true
                    ),
                    text(
                      "#{format_mb(state.mem_used)} / #{format_mb(state.mem_total)}",
                      color: :info
                    )
                  ]
                end,
                gap(1),
                box(border: :single, title: " Disk ", direction: :column) do
                  [
                    progress_bar(state.disk_used, state.disk_total,
                      label: "DISK",
                      color: disk_color(disk_pct),
                      show_percentage: true
                    ),
                    text(
                      "#{state.disk_used} GB / #{state.disk_total} GB",
                      color: :info
                    )
                  ]
                end
              ]
            end
          ]
        end,
        separator(),
        box(border: :single, title: " Processes ") do
          procs = Enum.sort_by(state.processes, &(-&1.cpu)) |> Enum.take(10)

          table(
            ["PID", "NAME", "CPU%", "MEM", "STATUS"],
            Enum.map(procs, fn p ->
              [to_string(p.pid), p.name, Float.round(p.cpu, 1), "#{p.mem} MB", p.status]
            end),
            selected_row: state.selected_proc,
            borders: :simple
          )
        end
      ]
    end
  end

  # ─── Tab 1: Processes ──────────────────────────────────────────

  defp render_tab(state, 1, _cpu_pct, _theme) do
    procs = Enum.sort_by(state.processes, &(-&1.cpu)) |> Enum.take(20)

    box(border: :single, title: " Process List (sorted by CPU) ", direction: :column) do
      [
        table(
          ["PID", "NAME", "CPU%", "MEM", "STATUS"],
          Enum.map(procs, fn p ->
            [to_string(p.pid), p.name, Float.round(p.cpu, 1), "#{p.mem} MB", p.status]
          end),
          selected_row: state.selected_proc,
          borders: :simple
        )
      ]
    end
  end

  # ─── Tab 2: System Info ────────────────────────────────────────

  defp render_tab(state, 2, _cpu_pct, _theme) do
    box(border: :single, title: " System Info ", direction: :column) do
      [
        text("BEAM Version:  #{System.version()}", color: :primary),
        separator(),
        text("Erlang/OTP:    #{System.otp_release()}", color: :info),
        separator(),
        text("Process Count: #{:erlang.system_info(:process_count)}", color: :info),
        separator(),
        text("Schedulers:    #{:erlang.system_info(:schedulers_online)}", color: :info),
        separator(),
        text("System Arch:   #{:erlang.system_info(:system_architecture)}", color: :info),
        separator(),
        text("Uptime:        #{format_uptime(state.uptime_secs)}", color: :success),
        separator(),
        text("Running Procs: #{length(state.processes)}", color: :success)
      ]
    end
  end

  defp render_tab(_, _, _, _), do: text("Unknown tab")

  # ─── Color helpers ─────────────────────────────────────────────

  defp cpu_color(pct) when pct >= 80, do: :error
  defp cpu_color(pct) when pct >= 60, do: :warning
  defp cpu_color(_), do: :primary

  defp mem_color(pct) when pct >= 85, do: :error
  defp mem_color(pct) when pct >= 60, do: :warning
  defp mem_color(_), do: :success

  defp disk_color(pct) when pct >= 85, do: :error
  defp disk_color(pct) when pct >= 60, do: :warning
  defp disk_color(_), do: :success

  # ── Lectura de métricas del sistema ──────────────────────────

  defp parse_float(str) do
    str
    |> String.trim()
    |> Float.parse()
    |> then(fn
      {val, _} -> val
      _ -> 0.0
    end)
  rescue
    _ -> 0.0
  end

  defp read_cpu do
    try do
      os_cpu_read()
    rescue
      _ -> :rand.uniform() * 100.0
    end
  end

  defp os_cpu_read do
    case :os.type() do
      {:unix, :darwin} ->
        case System.cmd("ps", ["-A", "-o", "%cpu="], stderr_to_stdout: true) do
          {output, 0} ->
            vals = output |> String.split("\n", trim: true) |> Enum.map(&parse_float/1)
            if vals != [], do: Enum.sum(vals) / length(vals), else: 0.0

          _ ->
            :rand.uniform() * 100.0
        end

      {:unix, _} ->
        case File.read("/proc/loadavg") do
          {:ok, data} -> data |> String.trim() |> String.split(" ") |> hd() |> parse_float()
          _ -> :rand.uniform() * 100.0
        end

      _ ->
        :rand.uniform() * 100.0
    end
  end

  defp read_memory do
    # Cross-platform via Erlang VM memory
    try do
      total_vm = :erlang.memory(:total)

      used_vm =
        :erlang.memory(:processes) + :erlang.memory(:binary) + :erlang.memory(:code) +
          :erlang.memory(:ets)

      {div(used_vm, 1024 * 1024), div(total_vm, 1024 * 1024)}
    rescue
      _ -> {4200, 16_384}
    end
  end

  defp parse_process_line(line) do
    parts = String.split(line, ~r/\s+/, parts: 4)

    case parts do
      [pid_str, cpu_str, mem_str, comm | _] ->
        pid = String.to_integer(pid_str)
        cpu = Float.parse(cpu_str) |> elem(0)
        mem = round(Float.parse(mem_str) |> elem(0))
        name = Path.basename(comm)

        %{pid: pid, name: name, cpu: cpu, mem: mem, status: "running"}

      _ ->
        %{pid: 0, name: "unknown", cpu: 0.0, mem: 0, status: "?"}
    end
  rescue
    _ -> %{pid: 0, name: "unknown", cpu: 0.0, mem: 0, status: "?"}
  end

  defp read_processes(count \\ 20) do
    try do
      os_processes_read(count)
    rescue
      _ -> generate_processes()
    end
  end

  defp os_processes_read(count) do
    case :os.type() do
      {:unix, :darwin} ->
        case System.cmd("ps", ["-eo", "pid,%cpu,%mem,comm", "-r"], stderr_to_stdout: true) do
          {output, 0} ->
            output
            |> String.split("\n", trim: true)
            |> tl()
            |> Enum.take(count)
            |> Enum.map(&parse_process_line/1)

          _ ->
            generate_processes()
        end

      {:unix, _} ->
        case System.cmd("ps", ["-eo", "pid,%cpu,%mem,comm", "--no-headers"],
               stderr_to_stdout: true
             ) do
          {output, 0} ->
            output
            |> String.split("\n", trim: true)
            |> Enum.take(count)
            |> Enum.map(&parse_process_line/1)

          _ ->
            generate_processes()
        end

      _ ->
        generate_processes()
    end
  end

  defp read_disk do
    case System.cmd("df", ["-k", "/"], stderr_to_stdout: true) do
      {output, 0} ->
        output |> String.split("\n", trim: true) |> parse_df_line()

      _ ->
        {100, 45}
    end
  rescue
    _ -> {100, 45}
  end

  defp parse_df_line([]), do: {100, 45}

  defp parse_df_line([_header | rest]) do
    case rest do
      [line | _] ->
        parts = String.split(line, ~r/\s+/, parts: 6)

        case parts do
          [_, _blocks, used_str, avail_str, _cap, _mounted | _] ->
            used_gb = round(String.to_integer(used_str) / (1024 * 1024))

            total_gb =
              round((String.to_integer(used_str) + String.to_integer(avail_str)) / (1024 * 1024))

            {total_gb, used_gb}

          _ ->
            {100, 45}
        end

      _ ->
        {100, 45}
    end
  end

  defp read_uptime do
    try do
      os_uptime_read()
    rescue
      _ -> 0
    end
  end

  defp os_uptime_read do
    case :os.type() do
      {:unix, :darwin} ->
        case System.cmd("sysctl", ["-n", "kern.boottime"], stderr_to_stdout: true) do
          {output, 0} ->
            with [_, sec_str] <- Regex.run(~r/sec = (\d+)/, output),
                 boot_sec = String.to_integer(sec_str),
                 now_sec = System.os_time(:second) do
              max(0, now_sec - boot_sec)
            else
              _ -> 0
            end

          _ ->
            0
        end

      {:unix, _} ->
        case File.read("/proc/uptime") do
          {:ok, data} -> data |> String.trim() |> String.split(" ") |> hd() |> String.to_integer()
          _ -> 0
        end

      _ ->
        0
    end
  end

  defp generate_processes do
    Enum.map(@proc_names, fn name ->
      %{
        pid: :rand.uniform(99_999),
        name: name,
        cpu: :rand.uniform() * 30.0,
        mem: :rand.uniform(500),
        status: Enum.random(["running", "sleeping"])
      }
    end)
  end

  defp format_uptime(secs) do
    h = div(secs, 3600)
    m = div(rem(secs, 3600), 60)
    s = rem(secs, 60)
    :io_lib.format("~2..0B:~2..0B:~2..0B", [h, m, s]) |> to_string()
  end

  defp format_mb(mb) do
    if mb >= 1024 do
      :io_lib.format("~.1f GB", [mb / 1024.0]) |> to_string()
    else
      :io_lib.format("~.1f MB", [mb]) |> to_string()
    end
  end
end

defmodule Visillo.Demo.Installer do
  @moduledoc """
  Demo: Instalador interactivo multi-paso.

  Demuestra:
    * Stepper (wizard) con pasos
    * Formularios con campos de input
    * Validación de campos
    * Modal de confirmación
    * Spinner durante "instalación"
    * Animación de progreso
  """

  use Visillo.Component

  defstruct [
    # 0-4
    :step,
    # %{name: "", email: "", dir: ""}
    :form,
    # :name | :email | :dir
    :focused_field,
    :installing,
    :install_progress,
    :install_log,
    :errors,
    :done,
    :frame,
    # Sugerencias de autocompletado para el campo dir (step 2)
    :dir_suggestions,
    :dir_suggestion_idx
  ]

  @steps ["Bienvenida", "Configuración", "Directorios", "Confirmación", "Instalación"]

  @impl true
  def init(_props) do
    {:ok,
     %__MODULE__{
       step: 0,
       form: %{name: "mi-app", email: "", dir: "/opt/mi-app"},
       focused_field: :name,
       installing: false,
       install_progress: 0,
       install_log: [],
       errors: %{},
       done: false,
       frame: 0,
       dir_suggestions: [],
       dir_suggestion_idx: 0
     }}
  end

  @impl true
  def focusable?, do: true

  @impl true
  def handle_tick(frame, state) do
    state = %{state | frame: frame}

    if state.installing and state.install_progress < 100 do
      progress = min(100, state.install_progress + :rand.uniform(3))
      log_line = install_log_line(progress)

      new_state = %{
        state
        | install_progress: progress,
          install_log: (state.install_log ++ [log_line]) |> Enum.take(-8),
          done: progress >= 100,
          installing: progress < 100
      }

      {:ok, new_state}
    else
      {:ok, state}
    end
  end

  @impl true
  def handle_key("tab", [], state) when not state.installing do
    next_field =
      case state.focused_field do
        :name -> :email
        :email -> :dir
        :dir -> :name
      end

    {:send, {:focus_field, next_field}}
  end

  def handle_key("down", [], %{step: 2, dir_suggestions: [_ | _]} = state) do
    idx = min(state.dir_suggestion_idx + 1, length(state.dir_suggestions) - 1)
    {:send, {:dir_suggestion_idx, idx}}
  end

  def handle_key("up", [], %{step: 2, dir_suggestions: [_ | _]} = state) do
    idx = max(state.dir_suggestion_idx - 1, 0)
    {:send, {:dir_suggestion_idx, idx}}
  end

  # Enter con sugerencia visible → acepta la sugerencia seleccionada
  def handle_key(
        "enter",
        [],
        %{step: 2, focused_field: :dir, dir_suggestions: [first | _]} = state
      ) do
    selected = Enum.at(state.dir_suggestions, state.dir_suggestion_idx, first)
    {:send, {:accept_dir_suggestion, selected}}
  end

  def handle_key("tab", [], %{step: 2, focused_field: :dir, dir_suggestions: [first | _]} = state) do
    selected = Enum.at(state.dir_suggestions, state.dir_suggestion_idx, first)
    {:send, {:accept_dir_suggestion, selected}}
  end

  def handle_key("enter", [], state) when state.step < 3 and not state.installing do
    {:send, :next_step}
  end

  def handle_key("enter", [], state) when state.step == 3 do
    {:send, :start_install}
  end

  def handle_key("backspace", [], state) when not state.installing and state.step != 3 do
    {:send, {:field_backspace, state.focused_field}}
  end

  def handle_key("escape", [], state) when state.step > 0 and not state.installing do
    {:send, :prev_step}
  end

  def handle_key("q", [], state) when not state.installing and not state.done do
    {:quit, :user}
  end

  def handle_key("q", [], state) when state.done, do: {:quit, :user}

  def handle_key(char, [], state)
      when byte_size(char) <= 4 and not state.installing and state.step != 3 do
    {:send, {:field_char, state.focused_field, char}}
  end

  def handle_key(_, _, _), do: :ignore

  @impl true
  def update({:focus_field, field}, state), do: {:ok, %{state | focused_field: field}}

  def update({:dir_suggestion_idx, idx}, state), do: {:ok, %{state | dir_suggestion_idx: idx}}

  def update({:accept_dir_suggestion, path}, state) do
    form = Map.put(state.form, :dir, path)

    {:ok,
     %{state | form: form, dir_suggestions: dir_completions(path <> "/"), dir_suggestion_idx: 0}}
  end

  def update(:next_step, state) do
    errors = validate_step(state)

    if errors == %{} do
      new_step = min(4, state.step + 1)
      focused_field = step_focused_field(new_step)
      {:ok, %{state | step: new_step, focused_field: focused_field, errors: %{}}}
    else
      {:ok, %{state | errors: errors}}
    end
  end

  def update(:prev_step, state) do
    new_step = max(0, state.step - 1)
    {:ok, %{state | step: new_step, focused_field: step_focused_field(new_step), errors: %{}}}
  end

  def update(:start_install, state) do
    {:ok, %{state | step: 4, installing: true, install_progress: 0, install_log: []}}
  end

  def update({:field_char, :dir, char}, state) do
    form = Map.update(state.form, :dir, char, &(&1 <> char))
    dir = form.dir
    suggestions = dir_completions(dir)

    {:ok,
     %{
       state
       | form: form,
         errors: Map.delete(state.errors, :dir),
         dir_suggestions: suggestions,
         dir_suggestion_idx: 0
     }}
  end

  def update({:field_char, field, char}, state) do
    form = Map.update(state.form, field, char, &(&1 <> char))
    {:ok, %{state | form: form, errors: Map.delete(state.errors, field)}}
  end

  def update({:field_backspace, :dir}, state) do
    form = Map.update(state.form, :dir, "", fn v -> String.slice(v, 0..-2//1) end)
    suggestions = dir_completions(form.dir)
    {:ok, %{state | form: form, dir_suggestions: suggestions, dir_suggestion_idx: 0}}
  end

  def update({:field_backspace, field}, state) do
    form = Map.update(state.form, field, "", fn v -> String.slice(v, 0..-2//1) end)
    {:ok, %{state | form: form}}
  end

  def update(_, state), do: {:ok, state}

  defp step_focused_field(0), do: :name
  defp step_focused_field(1), do: :name
  defp step_focused_field(2), do: :dir
  defp step_focused_field(3), do: :dir
  defp step_focused_field(4), do: :dir

  @impl true
  def render(state, _theme) do
    box(border: :double, title: " ⚡ Instalador ", title_align: :center, direction: :column) do
      [
        stepper(@steps, state.step),
        separator(),
        render_step(state),
        separator(),
        render_nav_hint(state)
      ]
    end
  end

  defp render_step(%{step: 0}) do
    box(border: :none, direction: :column, padding: 2) do
      [
        text("¡Bienvenido al instalador!", bold: true, color: :primary, align: :center),
        gap(1),
        paragraph(
          "Este asistente te guiará por la instalación de la aplicación. El proceso tomará unos minutos.",
          wrap: :word
        ),
        gap(1),
        text("Pulsa Enter para continuar →", color: :info, align: :center)
      ]
    end
  end

  defp render_step(%{step: 1} = state) do
    box(border: :none, direction: :column, padding: 1) do
      [
        text("Configuración básica", bold: true, color: :primary),
        separator(),
        input(
          value: state.form.name,
          label: "Nombre de la app:",
          placeholder: "mi-aplicacion",
          on_change: {:field_char, :name}
        ),
        render_error(state.errors[:name]),
        gap(1),
        input(
          value: state.form.email,
          label: "Email de contacto:",
          placeholder: "admin@ejemplo.com",
          on_change: {:field_char, :email}
        ),
        render_error(state.errors[:email])
      ]
    end
  end

  defp render_step(%{step: 2} = state) do
    box(border: :none, direction: :column, padding: 1) do
      [
        text("Directorio de instalación", bold: true, color: :primary),
        separator(),
        input(value: state.form.dir, label: "Ruta de instalación:", placeholder: "/opt/mi-app"),
        render_dir_suggestions(state),
        render_error(state.errors[:dir]),
        gap(1),
        text("Espacio necesario: ~50 MB", color: :info)
      ]
    end
  end

  defp render_step(%{step: 3} = state) do
    box(border: :none, direction: :column, padding: 1) do
      [
        text("Resumen de instalación", bold: true, color: :primary),
        separator(),
        text("App:       #{state.form.name}", color: :foreground),
        text("Email:     #{state.form.email}", color: :foreground),
        text("Directorio: #{state.form.dir}", color: :foreground),
        separator(),
        text("¿Confirmar instalación? (Enter)", color: :warning, bold: true, align: :center)
      ]
    end
  end

  defp render_step(%{step: 4} = state) do
    box(border: :none, direction: :column, padding: 1) do
      [
        if state.done do
          [
            text("✅ ¡Instalación completada!", bold: true, color: :success, align: :center),
            text("Pulsa q para salir", color: :info, align: :center)
          ]
        else
          [
            spinner(
              active: true,
              style: :dots,
              label: "Instalando #{state.form.name}…",
              color: :primary
            ),
            progress_bar(state.install_progress, 100, show_percentage: true, color: :primary),
            separator(label: "Log"),
            render_install_log(state)
          ]
        end
      ]
    end
  end

  defp render_step(_), do: text("Paso desconocido")

  defp render_install_log(state) do
    log_height = 6
    log_len = length(state.install_log)
    scroll_y = max(0, log_len - log_height)

    scroll_view(scroll_y: scroll_y, height: log_height) do
      Enum.map(state.install_log, &text(&1, color: :info))
    end
  end

  defp render_dir_suggestions(%{dir_suggestions: []}), do: nil

  defp render_dir_suggestions(%{dir_suggestions: suggestions, dir_suggestion_idx: sel}) do
    box(border: :single, title: " sugerencias ", padding: 0, max_height: 8) do
      suggestions
      |> Enum.with_index()
      |> Enum.map(fn {path, i} ->
        icon = if File.dir?(path), do: "📁", else: "📄"

        text("  #{if i == sel, do: "▸", else: " "}#{icon} #{path}",
          color: if(i == sel, do: :primary, else: :foreground),
          bg: if(i == sel, do: :focus_bg, else: nil)
        )
      end)
    end
  end

  defp render_error(nil), do: gap(0)
  defp render_error(msg), do: text("⚠ #{msg}", color: :error)

  defp render_nav_hint(%{step: 0}),
    do: text("Enter → Siguiente | q Salir", color: :info, align: :center)

  defp render_nav_hint(%{step: 4, done: true}),
    do: text("q → Salir", color: :success, align: :center)

  defp render_nav_hint(%{step: 4}), do: text("Instalando…", color: :info, align: :center)

  defp render_nav_hint(%{step: s}) when s == length(@steps) - 2 do
    text("Enter → Instalar | Esc ← Atrás", color: :info, align: :center)
  end

  defp render_nav_hint(_),
    do: text("Enter → Siguiente | Esc ← Atrás | Tab Cambiar campo", color: :info, align: :center)

  defp validate_step(%{step: 1, form: form}) do
    %{}
    |> then(fn e ->
      if form.name == "", do: Map.put(e, :name, "El nombre es requerido"), else: e
    end)
    |> then(fn e ->
      if form.email != "" and not String.contains?(form.email, "@"),
        do: Map.put(e, :email, "Email inválido"),
        else: e
    end)
  end

  defp validate_step(%{step: 2, form: form}) do
    %{}
    |> then(fn e ->
      if String.starts_with?(form.dir, "/"),
        do: e,
        else: Map.put(e, :dir, "La ruta debe ser absoluta (empezar con /)")
    end)
  end

  defp validate_step(_), do: %{}

  # ── Autocompletado de directorios (step 2) ─────────────────────────

  # Busca entradas del sistema de archivos que coincidan con el prefijo dado.
  # Retorna lista de paths completos ordenados alfabéticamente.
  defp dir_completions(prefix) do
    dir =
      if String.ends_with?(prefix, "/") do
        prefix
      else
        Path.dirname(prefix)
      end

    base = Path.basename(prefix)

    case File.ls(dir) do
      {:ok, entries} ->
        entries
        |> Enum.filter(&String.starts_with?(&1, base))
        |> Enum.map(fn entry ->
          full = Path.join(dir, entry)
          if File.dir?(full), do: full <> "/", else: full
        end)
        |> Enum.sort()
        |> Enum.take(10)

      {:error, _} ->
        []
    end
  rescue
    _ -> []
  end

  defp install_log_line(progress) do
    lines = [
      "Verificando dependencias…",
      "Descargando paquetes…",
      "Instalando archivos…",
      "Configurando servicios…",
      "Creando directorios…",
      "Aplicando permisos…",
      "Generando certificados…",
      "Iniciando servicios…",
      "Verificando instalación…",
      "Limpiando temporales…"
    ]

    idx = div(progress * length(lines), 101)
    Enum.at(lines, min(idx, length(lines) - 1), "…")
  end
end

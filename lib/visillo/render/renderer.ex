defmodule Visillo.Render.Renderer do
  @moduledoc """
  Main widget renderer.

  Takes the "laid out" widget tree (with calculated positions and dimensions)
  and writes the corresponding cells into an `Alaja.Buffer`.

  Each widget type has its own render function.
  The renderer is pure: it has no state, no side effects.
  """

  import Bitwise

  alias Alaja.{Buffer, Cell}
  alias Visillo.{Widget, Animation}
  alias Visillo.Render.{Border, TextWrap}

  @type laid_out :: %{widget: Widget.t(), rect: map(), children: [map()]}

  @doc """
  Renders the laid-out tree into a buffer.

  ## Parameters

    * `laid_out` — Widget tree with calculated positions
    * `buffer` — Buffer to write cells into
    * `theme` — Active color theme
    * `opts` — Additional options (`:frame`, `:focused_id`)
  """
  @spec render(laid_out(), Buffer.t(), map(), keyword()) :: Buffer.t()
  def render(laid_out, buffer, theme, opts \\ []) do
    frame = Keyword.get(opts, :frame, 0)
    focused_id = Keyword.get(opts, :focused_id)
    render_node(laid_out, buffer, theme, frame, focused_id)
  end

  # ─── Dispatch por tipo de widget ─────────────────────────────────────────────

  defp render_node(
         %{widget: widget, rect: rect, children: children},
         buffer,
         theme,
         frame,
         focused_id
       ) do
    focused? = widget.id != nil and widget.id == focused_id

    buffer = render_widget_dispatch(widget, rect, buffer, theme, frame, focused?)

    Enum.reduce(children, buffer, fn child, buf ->
      render_node(child, buf, theme, frame, focused_id)
    end)
  end

  defp render_widget_dispatch(widget, rect, buffer, theme, frame, focused?) do
    case widget.type do
      :box -> render_box(widget, rect, buffer, theme, focused?)
      :text -> render_text(widget, rect, buffer, theme)
      :paragraph -> render_paragraph(widget, rect, buffer, theme)
      :button -> render_button(widget, rect, buffer, theme, focused?)
      :input -> render_input(widget, rect, buffer, theme, focused?)
      :list -> render_list(widget, rect, buffer, theme, focused?)
      :table -> render_table(widget, rect, buffer, theme, focused?)
      _ -> render_widget_dispatch_more(widget, rect, buffer, theme, frame, focused?)
    end
  end

  defp render_widget_dispatch_more(widget, rect, buffer, theme, frame, focused?) do
    case widget.type do
      :progress_bar -> render_progress_bar(widget, rect, buffer, theme)
      :spinner -> render_spinner(widget, rect, buffer, theme, frame)
      :menu -> render_menu(widget, rect, buffer, theme, focused?)
      :tabs -> render_tabs(widget, rect, buffer, theme)
      :modal -> render_modal(widget, rect, buffer, theme, focused?)
      :status_bar -> render_status_bar(widget, rect, buffer, theme)
      :separator -> render_separator(widget, rect, buffer, theme)
      _ -> render_widget_dispatch_rest(widget, rect, buffer, theme, frame, focused?)
    end
  end

  defp render_widget_dispatch_rest(widget, rect, buffer, theme, _frame, focused?) do
    case widget.type do
      :gauge -> render_gauge(widget, rect, buffer, theme)
      :stepper -> render_stepper(widget, rect, buffer, theme)
      :breadcrumbs -> render_breadcrumbs(widget, rect, buffer, theme)
      :confirm -> render_confirm(widget, rect, buffer, theme, focused?)
      :file_browser -> render_file_browser(widget, rect, buffer, theme, focused?)
      :chart -> render_chart(widget, rect, buffer, theme)
      _ -> render_widget_dispatch_last(widget, rect, buffer)
    end
  end

  defp render_widget_dispatch_last(widget, rect, buffer) do
    case widget.type do
      :grid -> buffer
      :scroll_view -> buffer
      :gap -> buffer
      :raw -> render_raw(widget, rect, buffer)
      _ -> buffer
    end
  end

  # ─── Box ─────────────────────────────────────────────────────────────────────

  defp render_box(widget, rect, buffer, theme, focused?) do
    border_style = Map.get(widget.props, :border, :rounded)
    title = Map.get(widget.props, :title)
    title_align = Map.get(widget.props, :title_align, :left)
    bg = resolve_color(Map.get(widget.props, :bg), theme)

    border_color =
      if focused?,
        do: theme.border_focus,
        else: Map.get(widget.props, :border_color, theme.border)

    Border.draw(buffer, rect, border_style, border_color, title, title_align, bg)
  end

  # ─── Text ────────────────────────────────────────────────────────────────────

  defp render_text(widget, rect, buffer, theme) do
    content = Map.get(widget.props, :content, "")
    fg = resolve_color(Map.get(widget.props, :color), theme)
    bg = resolve_color(Map.get(widget.props, :bg), theme)
    align = Map.get(widget.props, :align, :left)
    truncate = Map.get(widget.props, :truncate, true)
    effects = build_effects(widget.props)

    text =
      if truncate and String.length(content) > rect.width,
        do: String.slice(content, 0, max(0, rect.width - 1)) <> "…",
        else: content

    text = align_text(text, rect.width, align)

    write_string(buffer, rect.x, rect.y, text, fg, bg, effects, rect.width)
  end

  # ─── Paragraph ───────────────────────────────────────────────────────────────

  defp render_paragraph(widget, rect, buffer, theme) do
    content = Map.get(widget.props, :content, "")
    fg = resolve_color(Map.get(widget.props, :color), theme)
    bg = resolve_color(Map.get(widget.props, :bg), theme)
    wrap = Map.get(widget.props, :wrap, :word)
    max_lines = Map.get(widget.props, :max_lines)
    align = Map.get(widget.props, :align, :left)
    effects = build_effects(widget.props)

    lines = TextWrap.wrap(content, rect.width, wrap)
    lines = if max_lines, do: Enum.take(lines, max_lines), else: lines
    lines = Enum.take(lines, rect.height)

    lines
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {line, i}, buf ->
      aligned = align_text(line, rect.width, align)
      write_string(buf, rect.x, rect.y + i, aligned, fg, bg, effects, rect.width)
    end)
  end

  # ─── Button ──────────────────────────────────────────────────────────────────

  defp render_button(widget, rect, buffer, theme, focused?) do
    label = Map.get(widget.props, :label, "")
    variant = Map.get(widget.props, :variant, :primary)
    disabled = Map.get(widget.props, :disabled, false)
    icon = Map.get(widget.props, :icon, "")
    shortcut = Map.get(widget.props, :shortcut)

    {fg, bg} =
      cond do
        disabled ->
          {theme.foreground |> dim_color(), theme.input_bg}

        focused? ->
          {theme.background, button_color(variant, theme)}

        true ->
          {button_color(variant, theme), theme.background}
      end

    effects = if focused?, do: [:bold], else: []

    content = icon <> label
    content = if shortcut, do: content <> " [#{shortcut}]", else: content
    content = " " <> align_text(content, rect.width - 2, :center) <> " "

    write_string(buffer, rect.x, rect.y, content, fg, bg, effects, rect.width)
  end

  # ─── Input ───────────────────────────────────────────────────────────────────

  defp render_input(widget, rect, buffer, theme, focused?) do
    value = Map.get(widget.props, :value, "")
    placeholder = Map.get(widget.props, :placeholder, "")
    password = Map.get(widget.props, :password, false)
    label = Map.get(widget.props, :label)

    y_offset = if label, do: 1, else: 0

    buffer = render_input_label(buffer, rect, label, theme)

    display_value = input_display_value(value, placeholder, password, focused?)

    fg = input_text_color(value, focused?, theme)
    bg = if focused?, do: theme.input_bg, else: dim_color(theme.input_bg)
    border_color = if focused?, do: theme.border_focus, else: theme.border

    input_rect = %{rect | y: rect.y + y_offset, height: 1}
    buffer = draw_input_border(buffer, input_rect, border_color)

    inner = truncate_input(display_value, rect.width - 2)

    buffer =
      write_string(buffer, rect.x + 1, rect.y + y_offset, inner, fg, bg, [], rect.width - 2)

    render_input_cursor(buffer, rect, y_offset, value, focused?, theme, bg)
  end

  defp render_input_label(buffer, _rect, nil, _theme), do: buffer

  defp render_input_label(buffer, rect, label, theme) do
    write_string(buffer, rect.x, rect.y, label, theme.foreground, nil, [], rect.width)
  end

  defp input_display_value(value, placeholder, password, focused?) do
    cond do
      value == "" and not focused? -> placeholder
      password -> String.duplicate("*", String.length(value))
      true -> value
    end
  end

  defp input_text_color(value, focused?, theme) do
    if value == "" and not focused?,
      do: dim_color(theme.foreground),
      else: theme.input_fg
  end

  defp render_input_cursor(buffer, rect, y_offset, value, focused?, theme, bg) do
    if focused? do
      cursor_x = rect.x + 1 + min(String.length(value), rect.width - 3)
      write_cell(buffer, cursor_x, rect.y + y_offset, "▋", theme.input_cursor, bg)
    else
      buffer
    end
  end

  # ─── List ────────────────────────────────────────────────────────────────────

  defp render_list(widget, rect, buffer, theme, focused?) do
    items = Map.get(widget.props, :items, [])
    selected = Map.get(widget.props, :selected, 0)
    scroll_offset = Map.get(widget.props, :scroll_offset, 0)
    render_item_fn = Map.get(widget.props, :render_item)

    visible = Enum.slice(items, scroll_offset, rect.height)

    visible
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {item, i}, buf ->
      abs_idx = scroll_offset + i
      is_selected = abs_idx == selected
      y = rect.y + i

      {fg, bg, effects} =
        cond do
          is_selected and focused? ->
            {theme.list_selected_fg, theme.list_selected_bg, [:bold]}

          is_selected ->
            {theme.list_selected_fg, dim_color(theme.list_selected_bg), []}

          true ->
            {theme.foreground, nil, []}
        end

      text =
        if render_item_fn do
          render_item_fn.(item, is_selected)
        else
          item_to_string(item)
        end

      prefix = if is_selected, do: "▶ ", else: "  "
      line = prefix <> String.slice(text, 0, rect.width - 2)

      write_string(buf, rect.x, y, line, fg, bg, effects, rect.width)
    end)
  end

  # ─── Table ───────────────────────────────────────────────────────────────────

  defp render_table(widget, rect, buffer, theme, focused?) do
    headers = Map.get(widget.props, :headers, [])
    rows = Map.get(widget.props, :rows, [])
    selected_row = Map.get(widget.props, :selected_row, 0)
    borders = Map.get(widget.props, :borders, :simple)
    header_color = resolve_color(Map.get(widget.props, :header_color), theme) || theme.primary

    col_count = max(length(headers), Enum.map(rows, &length/1) |> Enum.max(fn -> 0 end))

    col_width =
      if col_count > 0, do: max(1, div(rect.width - col_count - 1, col_count)), else: rect.width

    # Header
    buffer =
      render_table_row(buffer, headers, rect.x, rect.y, col_width, header_color, nil, [:bold])

    # Separator line after header
    buffer =
      if borders != :none do
        sep = String.duplicate("─", rect.width)
        write_string(buffer, rect.x, rect.y + 1, sep, theme.border, nil, [], rect.width)
      else
        buffer
      end

    y_start = if borders != :none, do: 2, else: 1

    # Rows
    rows
    |> Enum.with_index()
    |> Enum.take(rect.height - y_start)
    |> Enum.reduce(buffer, fn {row, i}, buf ->
      y = rect.y + y_start + i
      is_selected = i == selected_row

      {fg, bg, effects} =
        if is_selected and focused?,
          do: {theme.list_selected_fg, theme.list_selected_bg, [:bold]},
          else: {theme.foreground, nil, []}

      render_table_row(buf, row, rect.x, y, col_width, fg, bg, effects)
    end)
  end

  defp render_table_row(buffer, cells, x, y, col_width, fg, bg, effects) do
    cells
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {cell, i}, buf ->
      text = String.slice(to_string(cell), 0, col_width)
      padded = String.pad_trailing(text, col_width)
      write_string(buf, x + i * (col_width + 1), y, padded, fg, bg, effects, col_width)
    end)
  end

  # ─── Progress Bar ─────────────────────────────────────────────────────────────

  defp render_progress_bar(widget, rect, buffer, theme) do
    value = Map.get(widget.props, :value, 0)
    total = Map.get(widget.props, :total, 100)
    label = Map.get(widget.props, :label)
    show_pct = Map.get(widget.props, :show_percentage, true)
    color = resolve_color(Map.get(widget.props, :color), theme) || theme.progress_fill

    pct = if total > 0, do: min(1.0, value / total), else: 0.0
    pct_label = if show_pct, do: " #{round(pct * 100)}%", else: ""
    prefix = if label, do: "#{label} ", else: ""

    bar_width = rect.width - String.length(prefix) - String.length(pct_label)
    filled = round(pct * bar_width)
    empty = bar_width - filled

    buffer = render_progress_segments(buffer, rect, prefix, filled, empty, color, theme)
    render_progress_pct(buffer, rect, prefix, bar_width, pct_label, show_pct, theme)
  end

  defp render_progress_segments(buffer, rect, prefix, filled, empty, color, theme) do
    buffer
    |> write_string(rect.x, rect.y, prefix, theme.foreground, nil, [], rect.width)
    |> write_string(
      rect.x + String.length(prefix),
      rect.y,
      String.duplicate("█", filled),
      color,
      nil,
      [],
      filled
    )
    |> write_string(
      rect.x + String.length(prefix) + filled,
      rect.y,
      String.duplicate("░", empty),
      dim_color(theme.border),
      nil,
      [],
      empty
    )
  end

  defp render_progress_pct(buffer, rect, prefix, bar_width, pct_label, show_pct, theme) do
    if show_pct do
      pct_x = rect.x + String.length(prefix) + bar_width

      write_string(
        buffer,
        pct_x,
        rect.y,
        pct_label,
        theme.foreground,
        nil,
        [],
        String.length(pct_label)
      )
    else
      buffer
    end
  end

  # ─── Spinner ─────────────────────────────────────────────────────────────────

  defp render_spinner(widget, rect, buffer, theme, frame) do
    active = Map.get(widget.props, :active, true)
    style = Map.get(widget.props, :style, :dots)
    color = resolve_color(Map.get(widget.props, :color), theme) || theme.primary
    label = Map.get(widget.props, :label, "")

    char =
      if active,
        do: Animation.spinner_char(style, frame),
        else: "✓"

    fg = if active, do: color, else: theme.success
    text = char <> if(label != "", do: " " <> label, else: "")

    write_string(buffer, rect.x, rect.y, text, fg, nil, [], rect.width)
  end

  # ─── Menu ────────────────────────────────────────────────────────────────────

  defp render_menu(widget, rect, buffer, theme, focused?) do
    items = Map.get(widget.props, :items, [])
    selected = Map.get(widget.props, :selected, 0)
    open = Map.get(widget.props, :open, false)

    current_label = menu_item_label(Enum.at(items, selected))

    indicator = if open, do: " ▲", else: " ▼"
    display = String.slice(current_label, 0, rect.width - 2) <> indicator

    fg = if focused?, do: theme.primary, else: theme.foreground
    buffer = write_string(buffer, rect.x, rect.y, display, fg, theme.input_bg, [], rect.width)

    if open do
      render_menu_dropdown(items, selected, rect, buffer, theme)
    else
      buffer
    end
  end

  defp menu_item_label({label, _}), do: label
  defp menu_item_label(label) when is_binary(label), do: label
  defp menu_item_label(_), do: ""

  defp render_menu_dropdown(items, selected, rect, buffer, theme) do
    items
    |> Enum.with_index()
    |> Enum.take(rect.height - 1)
    |> Enum.reduce(buffer, fn {item, i}, buf ->
      render_menu_dropdown_item(item, i, selected, rect, buf, theme)
    end)
  end

  defp render_menu_dropdown_item(item, i, selected, rect, buf, theme) do
    label =
      case item do
        {l, _} -> l
        l when is_binary(l) -> l
        _ -> to_string(item)
      end

    is_sel = i == selected

    {fg, bg, effects} =
      if is_sel,
        do: {theme.list_selected_fg, theme.list_selected_bg, [:bold]},
        else: {theme.foreground, theme.input_bg, []}

    text = if is_sel, do: "▶ " <> label, else: "  " <> label
    write_string(buf, rect.x, rect.y + 1 + i, text, fg, bg, effects, rect.width)
  end

  # ─── Tabs ────────────────────────────────────────────────────────────────────

  defp render_tabs(widget, rect, buffer, theme) do
    tabs = Map.get(widget.props, :tabs, [])
    active = Map.get(widget.props, :active, 0)

    # 1. Dibujar línea base separadora en y (los labels la sobreescriben)
    sep_line = String.duplicate("─", rect.width)
    buffer = write_string(buffer, rect.x, rect.y, sep_line, theme.border, nil, [], rect.width)

    # 2. Dibujar cada pestaña (una sola pasada)
    {buffer, _x} =
      tabs
      |> Enum.with_index()
      |> Enum.reduce({buffer, rect.x}, fn {tab, i}, {buf, x} ->
        label =
          case tab do
            {l, _} -> to_string(l)
            l -> to_string(l)
          end

        is_active = i == active

        {fg, bg, effects} =
          if is_active,
            do: {theme.background, theme.tab_active, [:bold]},
            else: {theme.tab_inactive, nil, []}

        text = " #{label} "
        buf2 = write_string(buf, x, rect.y, text, fg, bg, effects, String.length(text))
        {buf2, x + String.length(text) + 1}
      end)

    buffer
  end

  # ─── Modal ───────────────────────────────────────────────────────────────────

  defp render_modal(widget, rect, buffer, theme, _focused?) do
    if Map.get(widget.props, :visible, true) do
      title = Map.get(widget.props, :title, "")

      # Overlay semitransparente (relleno de fondo)
      buffer = fill_bg(buffer, rect, theme.modal_overlay)

      # Borde del modal
      Border.draw(buffer, rect, :rounded, theme.border_focus, title, :center, theme.background)
    else
      buffer
    end
  end

  # ─── Status Bar ──────────────────────────────────────────────────────────────

  defp render_status_bar(widget, rect, buffer, theme) do
    left = Map.get(widget.props, :left)
    center = Map.get(widget.props, :center)
    right = Map.get(widget.props, :right)
    bg = resolve_color(Map.get(widget.props, :bg), theme) || theme.status_bar_bg
    fg = resolve_color(Map.get(widget.props, :color), theme) || theme.status_bar_fg

    # Fondo completo
    buffer =
      write_string(
        buffer,
        rect.x,
        rect.y,
        String.duplicate(" ", rect.width),
        fg,
        bg,
        [],
        rect.width
      )

    # Left
    buffer =
      if left do
        text = " " <> widget_content_to_string(left)
        write_string(buffer, rect.x, rect.y, text, fg, bg, [], String.length(text))
      else
        buffer
      end

    # Center
    buffer =
      if center do
        text = widget_content_to_string(center)
        x = rect.x + div(rect.width - String.length(text), 2)
        write_string(buffer, x, rect.y, text, fg, bg, [], String.length(text))
      else
        buffer
      end

    # Right
    if right do
      text = widget_content_to_string(right) <> " "
      x = rect.x + rect.width - String.length(text)
      write_string(buffer, x, rect.y, text, fg, bg, [], String.length(text))
    else
      buffer
    end
  end

  # ─── Separator ───────────────────────────────────────────────────────────────

  defp render_separator(widget, rect, buffer, theme) do
    orientation = Map.get(widget.props, :orientation, :horizontal)
    char = Map.get(widget.props, :char, if(orientation == :horizontal, do: "─", else: "│"))
    color = resolve_color(Map.get(widget.props, :color), theme) || theme.border
    label = Map.get(widget.props, :label)

    case orientation do
      :horizontal ->
        line = String.duplicate(char, rect.width)
        buffer = write_string(buffer, rect.x, rect.y, line, color, nil, [], rect.width)

        if label do
          label_text = " #{label} "
          label_x = rect.x + div(rect.width - String.length(label_text), 2)

          write_string(
            buffer,
            label_x,
            rect.y,
            label_text,
            theme.foreground,
            nil,
            [],
            String.length(label_text)
          )
        else
          buffer
        end

      :vertical ->
        Enum.reduce(0..(rect.height - 1), buffer, fn i, buf ->
          write_cell(buf, rect.x, rect.y + i, char, color, nil)
        end)
    end
  end

  # ─── Gauge ───────────────────────────────────────────────────────────────────

  defp render_gauge(widget, rect, buffer, theme) do
    value = Map.get(widget.props, :value, 0)
    min_v = Map.get(widget.props, :min, 0)
    max_v = Map.get(widget.props, :max, 100)
    label = Map.get(widget.props, :label, "")
    color = resolve_color(Map.get(widget.props, :color), theme) || theme.primary
    segments = Map.get(widget.props, :segments, 20)
    show_value = Map.get(widget.props, :show_value, true)

    pct = if max_v > min_v, do: (value - min_v) / (max_v - min_v), else: 0.0
    pct = max(0.0, min(1.0, pct))
    filled = round(pct * segments)

    bar = "[" <> String.duplicate("█", filled) <> String.duplicate("░", segments - filled) <> "]"
    value_str = if show_value, do: " #{value}/#{max_v}", else: ""
    line = label <> bar <> value_str

    write_string(buffer, rect.x, rect.y, line, color, nil, [], rect.width)
  end

  # ─── Stepper ─────────────────────────────────────────────────────────────────

  defp render_stepper(widget, rect, buffer, theme) do
    steps = Map.get(widget.props, :steps, [])
    current = Map.get(widget.props, :current, 0)
    show_labels = Map.get(widget.props, :show_labels, true)

    step_width = if length(steps) > 0, do: div(rect.width, length(steps)), else: rect.width

    steps
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {step, i}, buf ->
      stepper_opts = %{
        current: current,
        steps: steps,
        step_width: step_width,
        show_labels: show_labels,
        rect: rect,
        theme: theme
      }

      render_stepper_step(buf, step, i, stepper_opts)
    end)
  end

  defp render_stepper_step(buf, step, i, opts) do
    %{current: current, step_width: step_width, rect: rect, theme: theme} = opts
    x = rect.x + i * step_width + div(step_width, 2)

    {dot, fg, effects} = stepper_dot_style(i, current, theme)

    buf = write_cell(buf, x, rect.y, dot, fg, nil)

    buf = stepper_connector(buf, x, i, current, opts)

    stepper_step_label(buf, step, i, current, effects, opts)
  end

  defp stepper_dot_style(i, current, theme) do
    cond do
      i < current -> {"✓", theme.success, []}
      i == current -> {"●", theme.primary, [:bold]}
      true -> {"○", theme.border, []}
    end
  end

  defp stepper_connector(buf, x, i, current, opts) do
    %{steps: steps, step_width: step_width, rect: rect, theme: theme} = opts

    if i < length(steps) - 1 do
      conn_x = x + 1
      conn_len = step_width - 1
      conn_color = if i < current, do: theme.success, else: theme.border
      line = String.duplicate("─", max(0, conn_len))
      write_string(buf, conn_x, rect.y, line, conn_color, nil, [], conn_len)
    else
      buf
    end
  end

  defp stepper_step_label(buf, step, i, current, effects, opts) do
    %{step_width: step_width, show_labels: show_labels, rect: rect, theme: theme} = opts

    if show_labels and rect.height > 1 do
      label = String.slice(step, 0, step_width)
      label_x = rect.x + i * step_width + div(step_width - String.length(label), 2)
      label_fg = if i == current, do: theme.primary, else: theme.foreground
      write_string(buf, label_x, rect.y + 1, label, label_fg, nil, effects, String.length(label))
    else
      buf
    end
  end

  # ─── Breadcrumbs ─────────────────────────────────────────────────────────────

  defp render_breadcrumbs(widget, rect, buffer, theme) do
    path = Map.get(widget.props, :path, [])
    separator = Map.get(widget.props, :separator, " › ")
    color = resolve_color(Map.get(widget.props, :color), theme) || theme.primary

    dim_color_val =
      resolve_color(Map.get(widget.props, :dim_color), theme) || dim_color(theme.foreground)

    {buffer, _x} =
      path
      |> Enum.with_index()
      |> Enum.reduce({buffer, rect.x}, fn {segment, i}, {buf, x} ->
        is_last = i == length(path) - 1
        fg = if is_last, do: color, else: dim_color_val
        effects = if is_last, do: [:bold], else: []

        buf2 = write_string(buf, x, rect.y, segment, fg, nil, effects, String.length(segment))
        x2 = x + String.length(segment)

        {buf3, x3} =
          if is_last do
            {buf2, x2}
          else
            {write_string(
               buf2,
               x2,
               rect.y,
               separator,
               dim_color(theme.border),
               nil,
               [],
               String.length(separator)
             ), x2 + String.length(separator)}
          end

        {buf3, x3}
      end)

    buffer
  end

  # ─── Confirm ─────────────────────────────────────────────────────────────────

  defp render_confirm(widget, rect, buffer, theme, _focused?) do
    message = Map.get(widget.props, :message, "")
    default = Map.get(widget.props, :default, :yes)

    buffer = write_string(buffer, rect.x, rect.y, message, theme.foreground, nil, [], rect.width)

    yes_style = if default == :yes, do: [:bold], else: []
    no_style = if default == :no, do: [:bold], else: []
    yes_fg = if default == :yes, do: theme.success, else: theme.foreground
    no_fg = if default == :no, do: theme.error, else: theme.foreground

    yes_text = if default == :yes, do: "[Yes]", else: " Yes "
    no_text = if default == :no, do: "[No] ", else: " No  "

    buffer = write_string(buffer, rect.x, rect.y + 1, yes_text, yes_fg, nil, yes_style, 5)
    write_string(buffer, rect.x + 7, rect.y + 1, no_text, no_fg, nil, no_style, 5)
  end

  # ─── File Browser ────────────────────────────────────────────────────────────

  defp render_file_browser(widget, rect, buffer, theme, focused?) do
    path = Map.get(widget.props, :path, "/")
    show_hidden = Map.get(widget.props, :show_hidden, false)
    icons = Map.get(widget.props, :icons, true)
    selected = Map.get(widget.props, :selected, 0)
    scroll_offset = Map.get(widget.props, :scroll_offset, 0)

    entries = list_directory(path, show_hidden)
    visible = Enum.slice(entries, scroll_offset, rect.height)

    visible
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {{name, type}, i}, buf ->
      entry_opts = %{
        scroll_offset: scroll_offset,
        selected: selected,
        icons: icons,
        focused?: focused?,
        rect: rect,
        theme: theme
      }

      render_file_browser_entry(name, type, i, entry_opts, buf)
    end)
  end

  defp render_file_browser_entry(name, type, i, opts, buf) do
    %{
      scroll_offset: scroll_offset,
      selected: selected,
      icons: icons,
      focused?: focused?,
      rect: rect,
      theme: theme
    } = opts

    abs_idx = scroll_offset + i
    is_selected = abs_idx == selected
    y = rect.y + i

    icon = file_entry_icon(type, icons)

    {fg, bg, effects} = file_entry_style(is_selected, focused?, type, theme)

    line = icon <> String.slice(name, 0, rect.width - String.length(icon))
    write_string(buf, rect.x, y, line, fg, bg, effects, rect.width)
  end

  defp file_entry_icon(type, true) do
    case type do
      :dir -> "[D] "
      :link -> "[L] "
      _ -> "[F] "
    end
  end

  defp file_entry_icon(_type, false), do: ""

  defp file_entry_style(is_selected, focused?, type, theme) do
    cond do
      is_selected and focused? ->
        {theme.list_selected_fg, theme.list_selected_bg, [:bold]}

      is_selected ->
        {theme.list_selected_fg, dim_color(theme.list_selected_bg), []}

      type == :dir ->
        {theme.primary, nil, []}

      true ->
        {theme.foreground, nil, []}
    end
  end

  # ─── Chart ───────────────────────────────────────────────────────────────────

  defp render_chart(widget, rect, buffer, theme) do
    data = Map.get(widget.props, :data, [])
    chart_type = Map.get(widget.props, :type, :bar)
    labels = Map.get(widget.props, :labels, [])
    colors = Map.get(widget.props, :colors, [theme.primary, theme.secondary, theme.success])
    show_values = Map.get(widget.props, :show_values, false)

    case chart_type do
      :bar -> render_bar_chart(data, labels, colors, rect, buffer, theme, show_values)
      :sparkline -> render_sparkline(data, colors, rect, buffer, theme)
      # simplified
      :line -> render_sparkline(data, colors, rect, buffer, theme)
      _ -> buffer
    end
  end

  defp render_bar_chart([], _labels, _colors, _rect, buffer, _theme, _show_values), do: buffer

  defp render_bar_chart(data, labels, colors, rect, buffer, theme, show_values) do
    max_val = Enum.max(data, fn -> 1 end)
    bar_width = max(1, div(rect.width - length(data), max(length(data), 1)))

    data
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {val, i}, buf ->
      x = rect.x + i * (bar_width + 1)
      pct = if max_val > 0, do: val / max_val, else: 0.0
      bar_h = round(pct * (rect.height - 1))
      color = Enum.at(colors, rem(i, length(colors)), theme.primary)

      # Draw bar from bottom up
      buf =
        Enum.reduce(0..(bar_h - 1), buf, fn j, b ->
          y = rect.y + rect.height - 1 - j
          write_string(b, x, y, String.duplicate("█", bar_width), color, nil, [], bar_width)
        end)

      # Value on top
      buf =
        if show_values do
          val_str = to_string(round(val))

          write_string(
            buf,
            x,
            rect.y + rect.height - 1 - bar_h - 1,
            val_str,
            theme.foreground,
            nil,
            [],
            bar_width
          )
        else
          buf
        end

      # Label at bottom
      if labels != [] do
        label = Enum.at(labels, i, "")
        label_str = String.slice(label, 0, bar_width)

        write_string(
          buf,
          x,
          rect.y + rect.height - 1,
          label_str,
          dim_color(theme.foreground),
          nil,
          [],
          bar_width
        )
      else
        buf
      end
    end)
  end

  defp render_sparkline(data, colors, rect, buffer, theme) do
    spark_chars = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
    max_val = Enum.max(data, fn -> 1 end)
    color = hd(colors)

    data
    |> Enum.take(rect.width)
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {val, i}, buf ->
      pct = if max_val > 0, do: val / max_val, else: 0.0
      char_idx = round(pct * (length(spark_chars) - 1))
      char = Enum.at(spark_chars, char_idx, "▁")
      _ = theme
      write_cell(buf, rect.x + i, rect.y, char, color, nil)
    end)
  end

  # ─── Raw ─────────────────────────────────────────────────────────────────────

  defp render_raw(widget, rect, buffer) do
    content = Map.get(widget.props, :content, "")
    # Strip ANSI para escribir en buffer (el buffer no entiende ANSI)
    plain = Regex.replace(~r/\e\[[0-9;]*[mKJH]/, content, "")
    write_string(buffer, rect.x, rect.y, plain, nil, nil, [], rect.width)
  end

  # ─── Helpers ─────────────────────────────────────────────────────────────────

  defp write_string(buffer, x, y, text, fg, bg, effects, max_width) do
    chars = String.graphemes(text)
    chars = Enum.take(chars, max_width)

    chars
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, i}, buf ->
      write_cell(buf, x + i, y, char, fg, bg, effects)
    end)
  end

  defp write_cell(buffer, x, y, char, fg, bg, effects \\ []) do
    if x >= 0 and y >= 0 and x < buffer.width and y < buffer.height do
      cell = Cell.new(char, fg, bg, effects: effects)
      Buffer.update_cell(buffer, x, y, cell)
    else
      buffer
    end
  end

  defp fill_bg(buffer, rect, bg) do
    Enum.reduce(0..(rect.height - 1), buffer, fn dy, buf ->
      write_string(
        buf,
        rect.x,
        rect.y + dy,
        String.duplicate(" ", rect.width),
        nil,
        bg,
        [],
        rect.width
      )
    end)
  end

  defp align_text(text, width, :center) do
    len = String.length(text)

    if len >= width do
      text
    else
      pad = div(width - len, 2)
      String.duplicate(" ", pad) <> text <> String.duplicate(" ", width - len - pad)
    end
  end

  defp align_text(text, width, :right) do
    len = String.length(text)
    if len >= width, do: text, else: String.duplicate(" ", width - len) <> text
  end

  defp align_text(text, _width, _left), do: text

  defp resolve_color(nil, _theme), do: nil
  defp resolve_color({r, g, b}, _theme), do: {r, g, b}
  defp resolve_color(atom, theme) when is_atom(atom), do: Map.get(theme, atom)
  defp resolve_color("#" <> hex, _theme), do: hex_to_rgb(hex)
  defp resolve_color(_, _), do: nil

  defp hex_to_rgb(hex) do
    case Integer.parse(hex, 16) do
      {n, ""} when byte_size(hex) == 6 ->
        r = bsr(n, 16) |> band(0xFF)
        g = bsr(n, 8) |> band(0xFF)
        b = band(n, 0xFF)
        {r, g, b}

      _ ->
        nil
    end
  end

  defp build_effects(props) do
    []
    |> then(fn e -> if Map.get(props, :bold), do: [:bold | e], else: e end)
    |> then(fn e -> if Map.get(props, :italic), do: [:italic | e], else: e end)
    |> then(fn e -> if Map.get(props, :underline), do: [:underline | e], else: e end)
    |> then(fn e -> if Map.get(props, :strikethrough), do: [:strikethrough | e], else: e end)
    |> then(fn e -> if Map.get(props, :dim), do: [:dim | e], else: e end)
  end

  defp button_color(:primary, theme), do: theme.button_primary
  defp button_color(:secondary, theme), do: theme.button_secondary
  defp button_color(:danger, theme), do: theme.button_danger
  defp button_color(:ghost, theme), do: theme.button_ghost
  defp button_color(_, theme), do: theme.button_primary

  defp dim_color({r, g, b}), do: {div(r, 2), div(g, 2), div(b, 2)}
  defp dim_color(nil), do: nil

  defp item_to_string({label, _}), do: to_string(label)
  defp item_to_string(item), do: to_string(item)

  defp widget_content_to_string(s) when is_binary(s), do: s
  defp widget_content_to_string(other), do: to_string(other)

  defp truncate_input(text, max_width) do
    if String.length(text) > max_width do
      String.slice(text, -max_width, max_width)
    else
      text
    end
  end

  defp draw_input_border(buffer, rect, color) do
    write_string(
      buffer,
      rect.x,
      rect.y,
      "▔" <> String.duplicate("─", max(0, rect.width - 2)) <> "▔",
      color,
      nil,
      [],
      rect.width
    )
  end

  defp list_directory(path, show_hidden) do
    case File.ls(path) do
      {:ok, entries} ->
        entries
        |> filter_hidden(show_hidden)
        |> Enum.sort()
        |> Enum.map(fn name ->
          full = Path.join(path, name)
          type = entry_type(full)
          {name, type}
        end)

      {:error, _} ->
        []
    end
  end

  defp filter_hidden(entries, true), do: entries
  defp filter_hidden(entries, false), do: Enum.reject(entries, &String.starts_with?(&1, "."))

  defp entry_type(full) do
    cond do
      File.dir?(full) -> :dir
      File.read_link(full) |> elem(0) == :ok -> :link
      true -> :file
    end
  end
end

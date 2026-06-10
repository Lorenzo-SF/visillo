defmodule Visillo.Layout.Constraint do
  @moduledoc """
  Layout constraints for widgets.

  Defines the space a widget can occupy and how it behaves
  in the flex/grid layout system.
  """

  @type t :: %__MODULE__{
          width: non_neg_integer() | nil,
          height: non_neg_integer() | nil,
          min_width: non_neg_integer(),
          min_height: non_neg_integer(),
          max_width: non_neg_integer() | :infinity,
          max_height: non_neg_integer() | :infinity,
          flex_grow: non_neg_integer(),
          flex_shrink: non_neg_integer(),
          padding: non_neg_integer() | {non_neg_integer(), non_neg_integer()},
          margin: non_neg_integer() | {non_neg_integer(), non_neg_integer()},
          align_self: :start | :center | :end | :stretch
        }

  defstruct width: nil,
            height: nil,
            min_width: 0,
            min_height: 0,
            max_width: :infinity,
            max_height: :infinity,
            flex_grow: 0,
            flex_shrink: 1,
            padding: 0,
            margin: 0,
            align_self: :stretch
end

defmodule Visillo.Layout do
  @moduledoc """
  Layout engine for Visillo.

  Transforms a Widget Tree into a LaidOut Tree with computed positions
  and dimensions for each widget.

  ## Layout modes

    * **`:flex` (default)** — Flexbox layout: proportional space distribution
    * **`:grid`** — Grid with fixed columns
    * **`:fixed`** — Absolute position and size
    * **`:split`** — Horizontal or vertical split in proportions

  ## Algorithm (Flex)

  1. **Measure** — Each widget reports its minimum and preferred size
  2. **Distribute** — Available space is allocated according to `flex_grow`
  3. **Shrink** — If space is insufficient, `flex_shrink` is applied
  4. **Position** — Widgets are positioned according to parent `direction`
  5. **Recurse** — Repeat for each child with its rect as bounding box
  """

  alias Visillo.{Widget, Layout.Constraint}

  @type rect :: %{
          x: non_neg_integer(),
          y: non_neg_integer(),
          width: non_neg_integer(),
          height: non_neg_integer()
        }

  @type laid_out :: %{
          widget: Widget.t(),
          rect: rect(),
          children: [laid_out()]
        }

  @doc """
  Computes the layout of a widget tree within a bounding box.

  ## Parameters

    * `root` — Root widget of the tree
    * `width` — Available width (in terminal columns)
    * `height` — Available height (in terminal rows)
    * `opts` — Additional options

  ## Returns

  A tree of `laid_out` widgets with `rect` assigned to each node.
  """
  @spec compute(Widget.t(), pos_integer(), pos_integer(), keyword()) :: laid_out()
  def compute(root, width, height, _opts \\ []) do
    root_rect = %{x: 0, y: 0, width: width, height: height}
    layout_widget(root, root_rect)
  end

  # ─── Private: layout recursivo ──────────────────────────────────────────────

  defp layout_widget(%Widget{} = widget, rect) do
    # Aplicar márgenes del constraint
    inner_rect = apply_margin(rect, widget.constraint)

    children_laid = layout_children(widget, inner_rect)

    %{
      widget: widget,
      rect: inner_rect,
      children: children_laid
    }
  end

  defp layout_children(%Widget{type: :box} = widget, rect) do
    direction = Map.get(widget.props, :direction, :column)
    padding = Map.get(widget.props, :border, :none) |> border_padding()
    padding = max(padding, widget.constraint.padding)

    inner = shrink_rect(rect, padding)
    layout_flex(widget.children, inner, direction)
  end

  defp layout_children(%Widget{type: :grid} = widget, rect) do
    cols = Map.get(widget.props, :columns, 2)
    gap = Map.get(widget.props, :gap, 1)
    layout_grid(widget.children, rect, cols, gap)
  end

  defp layout_children(%Widget{type: :tabs} = widget, rect) do
    # Tab bar ocupa 1 línea arriba
    active = Map.get(widget.props, :active, 0)
    tab_bar_rect = %{rect | height: 1}
    content_rect = %{rect | y: rect.y + 1, height: max(0, rect.height - 1)}

    tabs = Map.get(widget.props, :tabs, [])

    tab_content =
      case Enum.at(tabs, active) do
        {_label, child} when is_struct(child, Widget) ->
          [layout_widget(child, content_rect)]

        _ ->
          []
      end

    [%{widget: Widget.new(:raw, %{content: ""}), rect: tab_bar_rect, children: []}] ++ tab_content
  end

  defp layout_children(%Widget{type: :modal} = widget, rect) do
    if Map.get(widget.props, :visible, true) do
      modal_w = Map.get(widget.props, :width, min(rect.width - 4, 60))
      modal_h = estimate_height(widget.children) + 4

      modal_x = rect.x + div(rect.width - modal_w, 2)
      modal_y = rect.y + div(rect.height - modal_h, 2)

      modal_rect = %{
        x: max(0, modal_x),
        y: max(0, modal_y),
        width: modal_w,
        height: modal_h
      }

      inner = shrink_rect(modal_rect, 1)
      layout_flex(widget.children, inner, :column)
    else
      []
    end
  end

  defp layout_children(%Widget{type: :scroll_view} = widget, rect) do
    layout_flex(widget.children, rect, :column)
  end

  defp layout_children(%Widget{} = widget, rect) do
    layout_flex(widget.children, rect, :column)
  end

  # ── Flex layout ─────────────────────────────────────────────────────────────

  defp layout_flex([], _rect, _direction), do: []

  defp layout_flex(children, rect, direction) do
    {fixed, flex_children} = split_fixed_flex(children, direction)

    fixed_size = Enum.sum(Enum.map(fixed, fn {c, _} -> fixed_size(c, direction) end))
    flex_total = Enum.sum(Enum.map(flex_children, fn {c, _} -> c.constraint.flex_grow end))

    available =
      case direction do
        :column -> rect.height - fixed_size
        :row -> rect.width - fixed_size
      end

    flex_unit = if flex_total > 0, do: max(0, available) / flex_total, else: 0

    # Merge fixed + flex con sus tamaños, ordenados por posición original
    all_with_size =
      children
      |> Enum.with_index()
      |> Enum.map(fn {child, i} ->
        size =
          if child.constraint.flex_grow > 0 do
            max(
              child.constraint.min_height,
              round(flex_unit * child.constraint.flex_grow)
            )
          else
            fixed_size(child, direction)
          end

        {child, size, i}
      end)

    # Posicionar widgets secuencialmente
    {laid_out, _} =
      Enum.reduce(all_with_size, {[], 0}, fn {child, size, _i}, {acc, offset} ->
        child_rect =
          case direction do
            :column ->
              %{x: rect.x, y: rect.y + offset, width: rect.width, height: size}

            :row ->
              %{x: rect.x + offset, y: rect.y, width: size, height: rect.height}
          end

        # Aplicar constraints de ancho/alto fijos
        child_rect = apply_fixed_constraint(child_rect, child.constraint, direction)

        laid = layout_widget(child, child_rect)
        {acc ++ [laid], offset + size}
      end)

    laid_out
  end

  # ── Grid layout ─────────────────────────────────────────────────────────────

  defp layout_grid(children, rect, cols, gap) do
    col_w = div(rect.width - (cols - 1) * gap, cols)

    children
    |> Enum.with_index()
    |> Enum.map(fn {child, i} ->
      col = rem(i, cols)
      row = div(i, cols)
      row_h = estimate_height([child])

      child_rect = %{
        x: rect.x + col * (col_w + gap),
        y: rect.y + row * (row_h + gap),
        width: col_w,
        height: row_h
      }

      layout_widget(child, child_rect)
    end)
  end

  # ─── Helpers ────────────────────────────────────────────────────────────────

  defp split_fixed_flex(children, direction) do
    Enum.split_with(children |> Enum.with_index(), fn {child, _i} ->
      case direction do
        :column ->
          child.constraint.flex_grow == 0 and
            (child.constraint.height != nil or fixed_min(child, direction) > 0)

        :row ->
          child.constraint.flex_grow == 0 and
            (child.constraint.width != nil or fixed_min(child, direction) > 0)
      end
    end)
  end

  defp fixed_size(%Widget{constraint: c} = widget, :column) do
    if c.height != nil, do: c.height, else: native_height(widget)
  end

  defp fixed_size(%Widget{constraint: c} = widget, :row) do
    if c.width != nil, do: c.width, else: native_width(widget)
  end

  defp fixed_min(%Widget{constraint: c}, :column), do: c.min_height
  defp fixed_min(%Widget{constraint: c}, :row), do: c.min_width

  defp native_height(%Widget{type: :text}), do: 1
  defp native_height(%Widget{type: :separator}), do: 1
  defp native_height(%Widget{type: :progress_bar}), do: 1
  defp native_height(%Widget{type: :spinner}), do: 1
  defp native_height(%Widget{type: :status_bar}), do: 1
  defp native_height(%Widget{type: :breadcrumbs}), do: 1
  defp native_height(%Widget{type: :stepper}), do: 3
  defp native_height(%Widget{type: :button}), do: 1
  defp native_height(%Widget{type: :input}), do: 1
  defp native_height(%Widget{type: :gap, constraint: c}), do: c.min_height
  defp native_height(%Widget{type: :paragraph, props: p}), do: Map.get(p, :max_lines, 3)

  defp native_height(%Widget{type: :list, props: p}),
    do: min(length(Map.get(p, :items, [])), Map.get(p, :max_height, 10))

  defp native_height(%Widget{type: :chart, props: p}), do: Map.get(p, :height, 8)
  defp native_height(%Widget{type: :gauge}), do: 2

  defp native_height(%Widget{type: :menu, props: p}),
    do: if(Map.get(p, :open, false), do: length(Map.get(p, :items, [])) + 2, else: 1)

  defp native_height(%Widget{type: :table, props: p}), do: length(Map.get(p, :rows, [])) + 2
  defp native_height(%Widget{type: :image, props: p}), do: Map.get(p, :height, 8)
  defp native_height(%Widget{type: :confirm}), do: 2
  defp native_height(%Widget{type: :file_browser, props: p}), do: Map.get(p, :max_height, 10)
  defp native_height(%Widget{type: :modal, props: p}), do: Map.get(p, :height, 7)

  defp native_height(%Widget{type: :scroll_view, props: p}),
    do: max(Map.get(p, :viewport_height, 10), 1)

  defp native_height(%Widget{type: :raw}), do: 1
  defp native_height(_), do: 1

  defp native_width(%Widget{type: :gap, constraint: c}), do: c.min_width
  defp native_width(%Widget{type: :separator}), do: 1
  defp native_width(_), do: 0

  defp apply_margin(rect, %Constraint{margin: 0}), do: rect

  defp apply_margin(rect, %Constraint{margin: m}) when is_integer(m) do
    %{
      x: rect.x + m,
      y: rect.y + m,
      width: max(0, rect.width - m * 2),
      height: max(0, rect.height - m * 2)
    }
  end

  defp apply_margin(rect, %Constraint{margin: {mv, mh}}) do
    %{
      x: rect.x + mh,
      y: rect.y + mv,
      width: max(0, rect.width - mh * 2),
      height: max(0, rect.height - mv * 2)
    }
  end

  defp apply_fixed_constraint(rect, %Constraint{width: w} = c, direction)
       when w != nil and direction == :row do
    %{rect | width: min(w, rect.width)}
    |> then(fn r -> apply_fixed_constraint(r, %{c | width: nil}, direction) end)
  end

  defp apply_fixed_constraint(rect, %Constraint{height: h} = c, direction)
       when h != nil and direction == :column do
    %{rect | height: min(h, rect.height)}
    |> then(fn r -> apply_fixed_constraint(r, %{c | height: nil}, direction) end)
  end

  defp apply_fixed_constraint(rect, _c, _direction), do: rect

  defp shrink_rect(rect, 0), do: rect

  defp shrink_rect(rect, p) when is_integer(p) and p > 0 do
    %{
      x: rect.x + p,
      y: rect.y + p,
      width: max(0, rect.width - p * 2),
      height: max(0, rect.height - p * 2)
    }
  end

  defp shrink_rect(rect, _), do: rect

  defp border_padding(:none), do: 0
  defp border_padding(nil), do: 0
  defp border_padding(_), do: 1

  defp estimate_height(children) do
    Enum.sum(Enum.map(children, &native_height/1))
  end
end

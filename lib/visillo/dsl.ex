defmodule Visillo.DSL do
  @moduledoc """
  Declarative DSL for building widget trees.

  Automatically imported by `use Visillo.Component`.

  ## Example

      import Visillo.DSL

      box(border: :rounded, title: "App") do
        [
          text("Hello!", bold: true, color: :cyan),
          separator(),
          list(["Item 1", "Item 2"], selected: 0),
          status_bar("Left", "Center", "Right")
        ]
      end
  """

  alias Visillo.Widget
  alias Visillo.Layout.Constraint

  # ─── Contenedores ───────────────────────────────────────────────────────────

  @doc """
  Container with optional borders.

  ## Options

    * `:border` — `:none | :single | :double | :rounded | :bold | :ascii` (default: `:rounded`)
    * `:title` — Title on the top border
    * `:title_align` — `:left | :center | :right` (default: `:left`)
    * `:direction` — `:column | :row` (default: `:column`)
    * `:padding` — Internal padding (0..N)
    * `:gap` — Spacing between children (default: 0)
    * `:flex` — Flexbox growth factor (default: 0)
    * `:min_width`, `:min_height`, `:max_width`, `:max_height`
  """
  defmacro box(opts \\ [], do: block) do
    quote do
      children = List.wrap(unquote(block)) |> List.flatten() |> Enum.reject(&is_nil/1)
      {constraint, props} = Visillo.DSL.__extract_constraint__(unquote(opts))

      Widget.new(:box, props, children,
        id: Keyword.get(unquote(opts), :id),
        constraint: constraint
      )
    end
  end

  @doc """
  Grid container with columns.

  ## Options

    * `:columns` — Number of columns (default: 2)
    * `:gap` — Spacing between cells (default: 1)
    * `:row_gap` — Vertical spacing between rows
  """
  defmacro grid(opts \\ [], do: block) do
    quote do
      children = List.wrap(unquote(block)) |> List.flatten() |> Enum.reject(&is_nil/1)
      {constraint, props} = Visillo.DSL.__extract_constraint__(unquote(opts))
      Widget.new(:grid, Map.merge(%{columns: 2, gap: 1}, props), children, constraint: constraint)
    end
  end

  @doc """
  Container with horizontal and/or vertical scroll.

  ## Options

    * `:scroll_x` — Horizontal offset (default: 0)
    * `:scroll_y` — Vertical offset (default: 0)
  """
  defmacro scroll_view(opts \\ [], do: block) do
    quote do
      children = List.wrap(unquote(block)) |> List.flatten() |> Enum.reject(&is_nil/1)
      {constraint, props} = Visillo.DSL.__extract_constraint__(unquote(opts))

      Widget.new(:scroll_view, Map.merge(%{scroll_x: 0, scroll_y: 0}, props), children,
        constraint: constraint
      )
    end
  end

  # ─── Texto y display ────────────────────────────────────────────────────────

  @doc """
  Single-line text.

  ## Options

    * `:color` — Text color (RGB tuple, atom, or hex string)
    * `:bg` — Background color
    * `:bold`, `:italic`, `:underline`, `:strikethrough`, `:dim` — Effects
    * `:align` — `:left | :center | :right` (default: `:left`)
    * `:truncate` — Whether to truncate with `…` when exceeding width (default: `false`)
  """
  @spec text(String.t(), keyword()) :: Widget.t()
  def text(content, opts \\ []) do
    {constraint, props} = __extract_constraint__(opts)
    Widget.new(:text, Map.merge(%{content: content}, props), [], constraint: constraint)
  end

  @doc """
  Multi-line text with automatic wrapping.

  ## Options

    * `:wrap` — `:word | :char | :none` (default: `:word`)
    * `:max_lines` — Maximum lines (nil = no limit)
    * `:color` — Text color
    * `:align` — `:left | :center | :right`
  """
  @spec paragraph(String.t(), keyword()) :: Widget.t()
  def paragraph(content, opts \\ []) do
    {constraint, props} = __extract_constraint__(opts)

    Widget.new(:paragraph, Map.merge(%{content: content, wrap: :word}, props), [],
      constraint: constraint
    )
  end

  @doc """
  Imagen en terminal (requiere soporte del terminal).

  ## Options

    * `:protocol` — `:kitty | :iterm2 | :sixel | :ascii` (default: auto)
    * `:width` — Width in cells
    * `:height` — Height in cells
    * `:fallback` — Text if images are not supported
  """
  @spec image(String.t(), keyword()) :: Widget.t()
  def image(path, opts \\ []) do
    {constraint, props} = __extract_constraint__(opts)

    Widget.new(:image, Map.merge(%{path: path, protocol: :auto}, props), [],
      constraint: constraint
    )
  end

  @doc """
  Contenido ANSI raw (escape hatch para output ya formateado).
  """
  @spec raw(String.t() | iodata()) :: Widget.t()
  def raw(content), do: Widget.new(:raw, %{content: content})

  # ─── Widgets interactivos ───────────────────────────────────────────────────

  @doc """
  Interactive button.

  ## Options

    * `:on_click` — Message to send on click (or Enter with focus)
    * `:variant` — `:primary | :secondary | :danger | :ghost` (default: `:primary`)
    * `:disabled` — Whether disabled (default: `false`)
    * `:shortcut` — Keyboard shortcut (e.g. `"r"`)
    * `:icon` — Icon prefix (e.g. `"▶ "`)
  """
  @spec button(String.t(), keyword()) :: Widget.t()
  def button(label, opts \\ []) do
    {constraint, props} = __extract_constraint__(opts)

    Widget.new(
      :button,
      Map.merge(
        %{
          label: label,
          variant: :primary,
          disabled: false
        },
        props
      ),
      [],
      constraint: constraint
    )
  end

  @doc """
  Text input field.

  ## Options

    * `:value` — Current value (default: `""`)
    * `:placeholder` — Placeholder text
    * `:password` — Mask with `*` (default: `false`)
    * `:max_length` — Maximum length (nil = no limit)
    * `:on_change` — Message on change: `{msg_atom, new_value}`
    * `:on_submit` — Message on Enter: `{msg_atom, value}`
    * `:label` — Label above the field
  """
  @spec input(keyword()) :: Widget.t()
  def input(opts \\ []) do
    {constraint, props} = __extract_constraint__(opts)

    Widget.new(
      :input,
      Map.merge(
        %{
          value: "",
          placeholder: "",
          password: false
        },
        props
      ),
      [],
      constraint: constraint
    )
  end

  @doc """
  Scrollable list with selection.
  """
  @spec list([term()], keyword()) :: Widget.t()
  def list(items, opts \\ []) do
    {constraint, props} = __extract_constraint__(opts)

    Widget.new(
      :list,
      Map.merge(
        %{
          items: items,
          selected: 0,
          scroll_offset: 0
        },
        props
      ),
      [],
      constraint: constraint
    )
  end

  @doc """
  Interactive table.

  ## Options

    * `:headers` — List of strings with column names
    * `:rows` — List of value lists
    * `:selected_row` — Selected row (default: 0)
    * `:borders` — `:none | :simple | :full` (default: `:simple`)
    * `:header_color` — Header color
    * `:on_select` — Message on row selection: `{msg, row, index}`
  """
  @spec table([String.t()], [[term()]], keyword()) :: Widget.t()
  def table(headers, rows, opts \\ []) do
    {constraint, props} = __extract_constraint__(opts)

    Widget.new(
      :table,
      Map.merge(
        %{
          headers: headers,
          rows: rows,
          selected_row: 0,
          borders: :simple
        },
        props
      ),
      [],
      constraint: constraint
    )
  end

  # ─── Navegación ─────────────────────────────────────────────────────────────

  @doc """
  Dropdown menu.
  """
  @spec menu([term()], keyword()) :: Widget.t()
  def menu(items, opts \\ []) do
    {constraint, props} = __extract_constraint__(opts)

    Widget.new(
      :menu,
      Map.merge(
        %{
          items: items,
          selected: 0,
          open: false,
          position: :below
        },
        props
      ),
      [],
      constraint: constraint
    )
  end

  @doc """
  Navigation tabs.
  """
  @spec tabs([{String.t(), term()}], keyword()) :: Widget.t()
  def tabs(tab_list, opts \\ []) do
    {constraint, props} = __extract_constraint__(opts)

    Widget.new(
      :tabs,
      Map.merge(
        %{
          tabs: tab_list,
          active: 0,
          position: :top
        },
        props
      ),
      [],
      constraint: constraint
    )
  end

  @doc """
  Navigation path (breadcrumbs).
  """
  @spec breadcrumbs([String.t()], keyword()) :: Widget.t()
  def breadcrumbs(path, opts \\ []) when is_list(path) do
    {constraint, props} = __extract_constraint__(opts)

    Widget.new(
      :breadcrumbs,
      Map.merge(
        %{
          path: path,
          separator: " › "
        },
        props
      ),
      [],
      constraint: constraint
    )
  end

  @doc """
  Multi-step assistant (stepper/wizard).
  """
  @spec stepper([String.t()], non_neg_integer(), keyword()) :: Widget.t()
  def stepper(steps, current \\ 0, opts \\ []) do
    {constraint, props} = __extract_constraint__(opts)

    Widget.new(
      :stepper,
      Map.merge(
        %{
          steps: steps,
          current: current,
          orientation: :horizontal,
          show_labels: true
        },
        props
      ),
      [],
      constraint: constraint
    )
  end

  @doc """
  Interactive file browser.
  """
  @spec file_browser(String.t(), keyword()) :: Widget.t()
  def file_browser(path, opts \\ []) do
    {constraint, props} = __extract_constraint__(opts)

    Widget.new(
      :file_browser,
      Map.merge(
        %{
          path: path,
          show_hidden: false,
          icons: true,
          show_preview: false
        },
        props
      ),
      [],
      constraint: constraint
    )
  end

  # ─── Feedback / Indicadores ─────────────────────────────────────────────────

  @doc """
  Progress bar.
  """
  @spec progress_bar(number(), number(), keyword()) :: Widget.t()
  def progress_bar(value, total, opts \\ []) do
    {constraint, props} = __extract_constraint__(opts)

    Widget.new(
      :progress_bar,
      Map.merge(
        %{
          value: value,
          total: total,
          style: :bar,
          show_percentage: true
        },
        props
      ),
      [],
      constraint: constraint
    )
  end

  @doc """
  Animated loading spinner.

  ## Options

    * `:active` — Whether animated (default: `true`)
    * `:style` — `:dots | :line | :moon | :clock | :pulse | :bounce` (default: `:dots`)
    * `:color` — Spinner color
    * `:label` — Text next to the spinner
  """
  @spec spinner(keyword()) :: Widget.t()
  def spinner(opts \\ []) do
    {constraint, props} = __extract_constraint__(opts)

    Widget.new(
      :spinner,
      Map.merge(
        %{
          active: true,
          style: :dots
        },
        props
      ),
      [],
      constraint: constraint
    )
  end

  @doc """
  Analog gauge/meier.

  ## Options

    * `:label` — Gauge label
    * `:color` — Fill color
    * `:segments` — Number of segments (default: 20)
    * `:show_value` — Show numeric value (default: `true`)
  """
  @spec gauge(number(), number(), number(), keyword()) :: Widget.t()
  def gauge(value, min, max, opts \\ []) do
    {constraint, props} = __extract_constraint__(opts)

    Widget.new(
      :gauge,
      Map.merge(
        %{
          value: value,
          min: min,
          max: max,
          segments: 20,
          show_value: true
        },
        props
      ),
      [],
      constraint: constraint
    )
  end

  @doc """
  Data chart.

  ## Options

    * `:type` — `:bar | :sparkline | :line` (default: `:bar`)
    * `:labels` — X-axis labels
    * `:colors` — List of colors
    * `:title` — Chart title
    * `:show_values` — Show values on bars (default: `false`)
    * `:height` — Height in lines (default: 8)
  """
  @spec chart([number()], keyword()) :: Widget.t()
  def chart(data, opts \\ []) do
    {constraint, props} = __extract_constraint__(opts)

    Widget.new(
      :chart,
      Map.merge(
        %{
          data: data,
          type: :bar,
          height: 8,
          show_values: false
        },
        props
      ),
      [],
      constraint: constraint
    )
  end

  # ─── Overlays ───────────────────────────────────────────────────────────────

  @doc """
  Modal overlay.

  ## Options

    * `:visible` — Whether the modal is visible (default: `true`)
    * `:on_confirm` — Message on confirm
    * `:on_cancel` — Message on cancel/Escape
    * `:buttons` — List of `{label, msg}` (default: `[{"OK", :ok}]`)
    * `:width` — Modal width (default: auto)
  """
  defmacro modal(title, opts \\ [], do: block) do
    quote do
      children = List.wrap(unquote(block)) |> List.flatten() |> Enum.reject(&is_nil/1)
      {constraint, props} = Visillo.DSL.__extract_constraint__(unquote(opts))

      Widget.new(
        :modal,
        Map.merge(
          %{
            title: unquote(title),
            visible: true,
            buttons: [{"OK", :ok}]
          },
          props
        ),
        children,
        constraint: constraint
      )
    end
  end

  @doc """
  Yes/No confirmation dialog.

  ## Options

    * `:on_yes` — Message on confirm
    * `:on_no` — Message on reject
    * `:default` — `:yes | :no` (default: `:yes`)
  """
  @spec confirm(String.t(), keyword()) :: Widget.t()
  def confirm(message, opts \\ []) do
    {constraint, props} = __extract_constraint__(opts)

    Widget.new(
      :confirm,
      Map.merge(
        %{
          message: message,
          default: :yes
        },
        props
      ),
      [],
      constraint: constraint
    )
  end

  # ─── Layout y separadores ───────────────────────────────────────────────────

  @doc """
  Fixed status bar (usually at the bottom).

  ## Options

    * `:bg` — Background color
    * `:color` — Text color
  """
  @spec status_bar(term(), term(), term(), keyword()) :: Widget.t()
  def status_bar(left \\ nil, center \\ nil, right \\ nil, opts \\ []) do
    {constraint, props} = __extract_constraint__(opts)

    Widget.new(:status_bar, Map.merge(%{left: left, center: center, right: right}, props), [],
      constraint: constraint
    )
  end

  @doc """
  Horizontal or vertical separator.

  ## Options

    * `:orientation` — `:horizontal | :vertical` (default: `:horizontal`)
    * `:char` — Separator character (default: `"─"`)
    * `:color` — Line color
    * `:label` — Text centered on the separator
  """
  @spec separator(keyword()) :: Widget.t()
  def separator(opts \\ []) do
    {constraint, props} = __extract_constraint__(opts)

    Widget.new(:separator, Map.merge(%{orientation: :horizontal, char: "─"}, props), [],
      constraint: constraint
    )
  end

  @doc """
  Flexible spacer. Occupies available space.

  ## Parameters

    * `size` — Minimum size (0 = fully flexible, default: 0)
  """
  @spec gap(non_neg_integer()) :: Widget.t()
  def gap(size \\ 0) do
    Widget.new(:gap, %{size: size}, [],
      constraint: %Constraint{flex_grow: 1, min_height: size, min_width: size}
    )
  end

  # ─── Helpers internos ───────────────────────────────────────────────────────

  @doc false
  def __extract_constraint__(opts) do
    constraint_keys = [
      :width,
      :height,
      :min_width,
      :min_height,
      :max_width,
      :max_height,
      :flex,
      :flex_grow,
      :flex_shrink,
      :margin,
      :padding,
      :align_self
    ]

    {constraint_kw, rest_kw} = Keyword.split(opts, constraint_keys)

    constraint =
      if Enum.empty?(constraint_kw) do
        %Constraint{}
      else
        flex = Keyword.get(constraint_kw, :flex)
        flex_grow = Keyword.get(constraint_kw, :flex_grow, if(flex, do: flex, else: 0))

        %Constraint{
          width: Keyword.get(constraint_kw, :width),
          height: Keyword.get(constraint_kw, :height),
          min_width: Keyword.get(constraint_kw, :min_width, 0),
          min_height: Keyword.get(constraint_kw, :min_height, 0),
          max_width: Keyword.get(constraint_kw, :max_width, :infinity),
          max_height: Keyword.get(constraint_kw, :max_height, :infinity),
          flex_grow: flex_grow,
          flex_shrink: Keyword.get(constraint_kw, :flex_shrink, 1),
          padding: Keyword.get(constraint_kw, :padding, 0),
          margin: Keyword.get(constraint_kw, :margin, 0),
          align_self: Keyword.get(constraint_kw, :align_self, :stretch)
        }
      end

    props = Map.new(rest_kw) |> Map.drop([:id])
    {constraint, props}
  end
end

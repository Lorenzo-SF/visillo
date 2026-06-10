defmodule Visillo.Widget do
  @moduledoc """
  Widget — atomic unit of the declarative UI tree.

  A Widget describes WHAT should be shown, not HOW.
  The Layout Engine and Renderer interpret these descriptors.

  Widgets are normally created through the DSL (`Visillo.DSL`),
  not directly.

  ## Supported widget types

    * `:box` — Container with borders
    * `:text` — Single-line text
    * `:paragraph` — Multi-line text with wrapping
    * `:button` — Interactive button
    * `:input` — Text input field
    * `:list` — Scrollable list
    * `:table` — Interactive table
    * `:progress_bar` — Progress bar
    * `:spinner` — Animated loading indicator
    * `:menu` — Dropdown menu
    * `:tabs` — Navigation tabs
    * `:modal` — Modal overlay dialog
    * `:status_bar` — Status bar (fixed to bottom)
    * `:separator` — Horizontal/vertical separator line
    * `:gauge` — Gauge/dial indicator
    * `:stepper` — Multi-step assistant
    * `:breadcrumbs` — Navigation path
    * `:confirm` — Yes/No confirmation dialog
    * `:file_browser` — File browser
    * `:chart` — Charts (bar, sparkline)
    * `:grid` — Grid layout
    * `:scroll_view` — Scrollable container
    * `:image` — Image (kitty/iterm2/sixel/ascii)
    * `:gap` — Flexible spacer
    * `:raw` — Raw ANSI string (escape hatch)

  ## Props by type

  | Type | Main props |
  |------|-------------------|
  | `:box` | `border`, `title`, `title_align`, `padding`, `direction`, `bg` |
  | `:text` | `content`, `color`, `bg`, `bold`, `italic`, `underline`, `align`, `truncate` |
  | `:paragraph` | `content`, `wrap`, `max_lines`, `color`, `align` |
  | `:button` | `label`, `on_click`, `variant`, `disabled`, `shortcut` |
  | `:input` | `value`, `placeholder`, `password`, `max_length`, `on_change`, `on_submit` |
  | `:list` | `items`, `selected`, `on_select`, `scroll_offset`, `render_item` |
  | `:table` | `headers`, `rows`, `selected_row`, `borders`, `header_color`, `on_select` |
  | `:progress_bar` | `value`, `total`, `label`, `color`, `style` |
  | `:spinner` | `active`, `style`, `color`, `label` |
  | `:menu` | `items`, `selected`, `on_select`, `position` |
  | `:tabs` | `tabs`, `active`, `on_change`, `position` |
  | `:modal` | `title`, `visible`, `on_confirm`, `on_cancel`, `buttons` |
  | `:status_bar` | `left`, `center`, `right`, `color`, `bg` |
  | `:separator` | `char`, `color`, `orientation`, `label` |
  | `:gauge` | `value`, `min`, `max`, `label`, `color`, `segments` |
  | `:stepper` | `steps`, `current`, `orientation`, `show_labels` |
  | `:breadcrumbs` | `path`, `separator`, `on_click`, `color` |
  | `:confirm` | `message`, `on_yes`, `on_no`, `default` |
  | `:file_browser` | `path`, `filter`, `show_hidden`, `on_select`, `show_preview` |
  | `:chart` | `data`, `type`, `labels`, `colors`, `title` |
  | `:grid` | `columns`, `gap`, `children` |
  | `:scroll_view` | `scroll_x`, `scroll_y`, `viewport_width`, `viewport_height` |
  | `:image` | `path`, `protocol`, `width`, `height`, `fallback` |
  | `:gap` | `size` |
  | `:raw` | `content` |
  """

  alias Visillo.Layout.Constraint

  @widget_types [
    :box,
    :text,
    :paragraph,
    :button,
    :input,
    :list,
    :table,
    :progress_bar,
    :spinner,
    :menu,
    :tabs,
    :modal,
    :status_bar,
    :separator,
    :gauge,
    :stepper,
    :breadcrumbs,
    :confirm,
    :file_browser,
    :chart,
    :grid,
    :scroll_view,
    :image,
    :gap,
    :raw
  ]

  @type widget_type ::
          :box
          | :text
          | :paragraph
          | :button
          | :input
          | :list
          | :table
          | :progress_bar
          | :spinner
          | :menu
          | :tabs
          | :modal
          | :status_bar
          | :separator
          | :gauge
          | :stepper
          | :breadcrumbs
          | :confirm
          | :file_browser
          | :chart
          | :grid
          | :scroll_view
          | :image
          | :gap
          | :raw

  @type t :: %__MODULE__{
          type: widget_type(),
          id: atom() | String.t() | nil,
          props: map(),
          children: [t()],
          constraint: Constraint.t(),
          style: map()
        }

  defstruct type: :text,
            id: nil,
            props: %{},
            children: [],
            constraint: %Visillo.Layout.Constraint{},
            style: %{}

  @doc """
  Creates a new Widget.

  ## Parameters

    * `type` — Widget type (atom)
    * `props` — Widget properties (map or keyword)
    * `children` — List of child widgets
    * `opts` — Additional options: `:id`, `:constraint`, `:style`
  """
  @spec new(widget_type(), map() | keyword(), [t()], keyword()) :: t()
  def new(type, props \\ %{}, children \\ [], opts \\ [])
      when type in @widget_types do
    props_map = if is_list(props), do: Map.new(props), else: props

    %__MODULE__{
      type: type,
      id: Keyword.get(opts, :id),
      props: props_map,
      children: List.wrap(children) |> List.flatten() |> Enum.reject(&is_nil/1),
      constraint: Keyword.get(opts, :constraint, %Constraint{}),
      style: Keyword.get(opts, :style, %{})
    }
  end

  @doc "Lists all valid widget types."
  @spec valid_types() :: [widget_type()]
  def valid_types, do: @widget_types

  @doc "Returns `true` if the type is valid."
  @spec valid_type?(atom()) :: boolean()
  def valid_type?(type), do: type in @widget_types

  @doc """
  Applies a constraint to a widget. Returns a new widget with the given constraint.
  """
  @spec with_constraint(t(), Constraint.t() | keyword()) :: t()
  def with_constraint(%__MODULE__{} = w, %Constraint{} = c), do: %{w | constraint: c}

  def with_constraint(%__MODULE__{} = w, kw) when is_list(kw) do
    c = struct!(Constraint, kw)
    %{w | constraint: c}
  end

  @doc "Assigns an ID to the widget."
  @spec with_id(t(), atom() | String.t()) :: t()
  def with_id(%__MODULE__{} = w, id), do: %{w | id: id}

  @doc "Merges additional props to the widget."
  @spec with_props(t(), map() | keyword()) :: t()
  def with_props(%__MODULE__{} = w, extra) when is_list(extra) do
    %{w | props: Map.merge(w.props, Map.new(extra))}
  end

  def with_props(%__MODULE__{} = w, extra) when is_map(extra) do
    %{w | props: Map.merge(w.props, extra)}
  end

  @doc "Merges additional styles to the widget."
  @spec with_style(t(), map() | keyword()) :: t()
  def with_style(%__MODULE__{} = w, style) when is_list(style) do
    %{w | style: Map.merge(w.style, Map.new(style))}
  end

  def with_style(%__MODULE__{} = w, style) when is_map(style) do
    %{w | style: Map.merge(w.style, style)}
  end

  @doc "Adds children to the widget."
  @spec with_children(t(), [t()]) :: t()
  def with_children(%__MODULE__{} = w, children) do
    valid = List.wrap(children) |> List.flatten() |> Enum.reject(&is_nil/1)
    %{w | children: w.children ++ valid}
  end
end

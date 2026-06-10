defmodule Visillo.Widgets.Tabs do
  @moduledoc """
  Interactive tabs component.

  Renders a tab bar at the top and the content
  of the active tab below. Supports keyboard navigation.

  ## Usage as root component

      Visillo.App.run(Visillo.Widgets.Tabs,
        tabs: [
          %{label: "Editor", content: [text("Editor content...")]},
          %{label: "Preview", content: [text("Preview content...")]}
        ]
      )

  ## Usage from another component

  The parent component includes `Tabs` in its state and delegates rendering
  of the tab bar + active content:

      def render(state, theme) do
        Tabs.render(state.tabs, theme)
      end

  ## Events

  When a tab is changed (Ctrl+Tab / Ctrl+Shift+Tab), the component
  sends `{:tab_changed, idx, label}`.
  """

  use Visillo.Component

  defstruct [
    :tabs,
    :active,
    :focused
  ]

  @type tab :: %{label: String.t(), content: [Visillo.Widget.t()]}

  # ── Behaviour callbacks ─────────────────────────────────────────────────────

  @doc """
  Creates a new Tabs state from props.

  ## Props

    * `tabs` — List of maps `%{label: String.t(), content: [widget_tree]}` (required)
    * `active` — Index of the initially active tab (default: 0)
  """
  @impl true
  @spec init(keyword()) :: {:ok, %__MODULE__{}}
  def init(props) do
    tabs = Keyword.get(props, :tabs, [])
    active = Keyword.get(props, :active, 0)
    active = min(active, max(length(tabs) - 1, 0))

    {:ok,
     %__MODULE__{
       tabs: tabs,
       active: active,
       focused: false
     }}
  end

  @impl true
  @spec focusable?() :: true
  def focusable?, do: true

  @impl true
  @spec handle_focus(map()) :: {:ok, map()}
  def handle_focus(state), do: {:ok, %{state | focused: true}}

  @impl true
  @spec handle_blur(map()) :: {:ok, map()}
  def handle_blur(state), do: {:ok, %{state | focused: false}}

  @impl true
  @spec handle_key(String.t(), list(), map()) :: :ignore | {:send, term()} | {:quit, term()}
  def handle_key("tab", [:ctrl], state), do: cycle_tab(state, 1)
  def handle_key("tab", [:ctrl, :shift], state), do: cycle_tab(state, -1)
  def handle_key("left", [], state), do: cycle_tab(state, -1)
  def handle_key("right", [], state), do: cycle_tab(state, 1)
  def handle_key(_, _, _), do: :ignore

  defp cycle_tab(state, dir) do
    count = length(state.tabs)
    new_idx = rem(state.active + dir + count, count)
    label = state.tabs |> Enum.at(new_idx) |> Map.get(:label, "")
    {:send, {:tab_changed, new_idx, label}}
  end

  @impl true
  @spec update(term(), map()) :: {:ok, map()}
  def update({:tab_changed, idx, _label}, state), do: {:ok, %{state | active: idx}}
  def update(_, state), do: {:ok, state}

  @impl true
  @spec render(map(), map()) :: Visillo.Widget.t()
  def render(state, _theme) do
    box(border: :none, direction: :column) do
      [
        render_tab_bar(state),
        separator(),
        render_active_content(state)
      ]
    end
  end

  defp render_tab_bar(state) do
    box(border: :none, direction: :row) do
      state.tabs
      |> Enum.with_index()
      |> Enum.flat_map(fn {tab, idx} ->
        label = Map.get(tab, :label, "Tab #{idx + 1}")
        marker = if Map.get(tab, :modified, false), do: "● ", else: ""

        tab_widget =
          if idx == state.active do
            text(" #{marker}#{label} ", color: :background, bg: :foreground, bold: true)
          else
            text(" #{marker}#{label} ", color: :secondary)
          end

        if idx == 0, do: [tab_widget], else: [text("│", color: :info), tab_widget]
      end)
    end
  end

  defp render_active_content(state) do
    active_tab = Enum.at(state.tabs, state.active, nil)

    if active_tab do
      content = Map.get(active_tab, :content, [])

      if content == [] do
        text("(no content)", color: :info, italic: true)
      else
        box(border: :none, direction: :column) do
          content
        end
      end
    else
      text("(no content)", color: :info, italic: true)
    end
  end
end

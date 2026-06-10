defmodule Visillo.Widgets.SplitPane do
  @moduledoc """
  Horizontal or vertical split layout.

  Divides the available space into two panels separated by an adjustable
  divider. Useful for editor + sidebar type layouts.

  ## Usage

      Visillo.Widgets.SplitPane.new(
        direction: :horizontal,
        first: [text("Left panel")],
        second: [text("Right panel")],
        ratio: 0.3
      )

  ## Props

    * `direction` — `:horizontal` (left/right) or `:vertical` (top/bottom)
    * `first` — List of widgets for the first panel

  ## Events

  When the user moves the divider with the mouse, the component sends
  `{:ratio_changed, new_ratio}`.
  """

  use Visillo.Component

  defstruct [:direction, :first, :second, :ratio, :divider, :divider_width]

  # ── Behaviour callbacks ─────────────────────────────────────────────────────

  @impl true
  @spec init(keyword()) :: {:ok, %__MODULE__{}}
  def init(props) do
    {:ok,
     %__MODULE__{
       direction: Keyword.get(props, :direction, :horizontal),
       first: Keyword.get(props, :first, []),
       second: Keyword.get(props, :second, []),
       ratio: Keyword.get(props, :ratio, 0.3),
       divider: Keyword.get(props, :divider, nil),
       divider_width: Keyword.get(props, :divider_width, 1)
     }}
  end

  @impl true
  @spec focusable?() :: false
  def focusable?, do: false

  @impl true
  @spec render(map(), map()) :: Visillo.Widget.t()
  def render(state, _theme) do
    dir = state.direction
    div_w = state.divider_width
    total_flex = 1000
    first_flex = round(total_flex * state.ratio)
    second_flex = total_flex - first_flex - div_w

    div_char = state.divider || default_divider(dir)

    box(border: :none, direction: dir) do
      [
        box(border: :none, flex: max(first_flex, 1)) do
          state.first
        end,
        text(div_char, dim: true),
        box(border: :none, flex: max(second_flex, 1)) do
          state.second
        end
      ]
    end
  end

  defp default_divider(:horizontal), do: "│"
  defp default_divider(:vertical), do: "─"
end

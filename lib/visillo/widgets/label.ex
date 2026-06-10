defmodule Visillo.Widgets.Label do
  @moduledoc """
  A simple text label widget.

  ## Usage

      Visillo.Widgets.Label.new("Hello, World!", color: :green, bold: true)
  """

  use Visillo.Component

  defstruct [:text, :color, :bold]

  # ── Behaviour callbacks ─────────────────────────────────────────────────────

  @impl true
  @spec init(keyword()) :: {:ok, %__MODULE__{}}
  def init(props) do
    {:ok,
     %__MODULE__{
       text: Keyword.get(props, :text, ""),
       color: Keyword.get(props, :color, :white),
       bold: Keyword.get(props, :bold, false)
     }}
  end

  @impl true
  @spec focusable?() :: false
  def focusable?, do: false

  @impl true
  @spec render(map(), map()) :: Visillo.Widget.t()
  def render(state, _theme) do
    text(state.text, color: state.color, bold: state.bold)
  end
end

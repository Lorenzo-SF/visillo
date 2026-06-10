defmodule Visillo.Widgets.Button do
  @moduledoc """
  A clickable button widget.

  ## Usage

      Visillo.Widgets.Button.new("Submit", on_click: :submit)
  """

  use Visillo.Component

  defstruct [:label, :on_click, :focused, width: 0]

  # ── Behaviour callbacks ─────────────────────────────────────────────────────

  @impl true
  @spec init(keyword()) :: {:ok, %__MODULE__{}}
  def init(props) do
    {:ok,
     %__MODULE__{
       label: Keyword.get(props, :label, "Button"),
       on_click: Keyword.get(props, :on_click, :clicked),
       width: Keyword.get(props, :width, 20)
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
  def handle_key("enter", _mods, state), do: {:send, state.on_click}
  def handle_key(" ", _mods, state), do: {:send, state.on_click}
  def handle_key(_key, _mods, _state), do: :ignore

  @impl true
  @spec render(map(), map()) :: Visillo.Widget.t()
  def render(state, _theme) do
    text = String.pad_trailing(" #{state.label} ", state.width)

    if state.focused,
      do: text("[ #{text} ]", color: :cyan, bold: true),
      else: text("[ #{text} ]", dim: true)
  end
end

defmodule Visillo.Widgets.Checkbox do
  @moduledoc """
  A toggleable checkbox widget.

  ## Usage

      Visillo.Widgets.Checkbox.new(label: "Enable feature", checked: false)
  """

  use Visillo.Component

  defstruct [:label, :checked, :focused]

  # ── Behaviour callbacks ─────────────────────────────────────────────────────

  @impl true
  @spec init(keyword()) :: {:ok, %__MODULE__{}}
  def init(props) do
    {:ok,
     %__MODULE__{
       label: Keyword.get(props, :label, "Option"),
       checked: Keyword.get(props, :checked, false),
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
  def handle_key("enter", _mods, state), do: {:send, {:toggled, not state.checked}}
  def handle_key(" ", _mods, state), do: {:send, {:toggled, not state.checked}}
  def handle_key(_key, _mods, _state), do: :ignore

  @impl true
  @spec update(term(), map()) :: {:ok, map()}
  def update({:toggled, value}, state), do: {:ok, %{state | checked: value}}
  def update(_msg, state), do: {:ok, state}

  @impl true
  @spec render(map(), map()) :: Visillo.Widget.t()
  def render(state, _theme) do
    mark = if state.checked, do: "☑", else: "☐"
    prefix = if state.focused, do: "> ", else: "  "
    text("#{prefix}#{mark} #{state.label}")
  end
end

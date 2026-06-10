defmodule Visillo.Demo.Counter do
  @moduledoc """
  Simple counter demo — increment/decrement with keyboard.

  Controls:
    + / =   Increment
    - / _   Decrement
    r       Reset
    q       Quit

  Run: mix run lib/visillo/demo/counter.exs
  """

  use Visillo.Component

  defstruct [:count]

  @impl true
  def init(_props), do: {:ok, %__MODULE__{count: 0}}

  @impl true
  def focusable?, do: true

  @impl true
  def handle_key(key, _mods, _state) do
    case key do
      "+" -> {:send, :inc}
      "=" -> {:send, :inc}
      "-" -> {:send, :dec}
      "_" -> {:send, :dec}
      "r" -> {:send, :reset}
      "q" -> {:quit, :user}
      _ -> :ignore
    end
  end

  @impl true
  def update(:inc, state), do: {:ok, %{state | count: state.count + 1}}
  def update(:dec, state), do: {:ok, %{state | count: max(0, state.count - 1)}}
  def update(:reset, state), do: {:ok, %{state | count: 0}}
  def update(_msg, state), do: {:ok, state}

  @impl true
  def render(state, _theme) do
    box(border: :double, title: " Counter Demo ", padding: 1) do
      [
        text("Count: #{state.count}", color: :cyan, bold: true),
        text(""),
        text("[+] [=] Increment  [-] [_] Decrement  [r] Reset  [q] Quit", dim: true)
      ]
    end
  end
end

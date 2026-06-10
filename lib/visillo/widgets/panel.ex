defmodule Visillo.Widgets.Panel do
  @moduledoc """
  A bordered panel container.

  ## Usage

      Visillo.Widgets.Panel.new(title: "Status", children: [button, label])
  """

  use Visillo.Component

  defstruct [:title, :children]

  # ── Behaviour callbacks ─────────────────────────────────────────────────────

  @impl true
  @spec init(keyword()) :: {:ok, %__MODULE__{}}
  def init(props) do
    {:ok,
     %__MODULE__{
       title: Keyword.get(props, :title, ""),
       children: Keyword.get(props, :children, [])
     }}
  end

  @impl true
  @spec focusable?() :: false
  def focusable?, do: false

  @impl true
  @spec render(map(), map()) :: Visillo.Widget.t()
  def render(state, _theme) do
    box(border: :rounded, title: state.title, padding: 1) do
      for child <- state.children do
        child
      end
    end
  end
end

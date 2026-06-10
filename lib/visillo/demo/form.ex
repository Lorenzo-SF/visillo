defmodule Visillo.Demo.Form do
  @moduledoc """
  Simple form demo — text input + checkbox + submit.

  Controls:
    Tab       Move focus
    Enter     Activate / toggle
    Type      Enter text
    Backspace Delete
    q         Quit

  Run: mix run lib/visillo/demo/form.exs
  """

  use Visillo.Component

  defstruct [:name, :email, :subscribe, :focused_field]

  @impl true
  def init(_props) do
    {:ok, %__MODULE__{name: "", email: "", subscribe: false, focused_field: :name}}
  end

  @impl true
  def focusable?, do: true

  @impl true
  def handle_key("tab", _mods, state) do
    next =
      case state.focused_field do
        :name -> :email
        :email -> :subscribe
        :subscribe -> :submit
        :submit -> :name
      end

    {:send, {:focus_field, next}}
  end

  def handle_key("enter", _mods, %{focused_field: :submit} = state) do
    {:send, {:submit, state.name, state.email, state.subscribe}}
  end

  def handle_key("enter", _mods, %{focused_field: :subscribe}) do
    {:send, :toggle_subscribe}
  end

  def handle_key(key, _mods, %{focused_field: field})
      when field in [:name, :email] and byte_size(key) <= 4 do
    {:send, {:form_char, field, key}}
  end

  def handle_key("backspace", _mods, %{focused_field: field})
      when field in [:name, :email] do
    {:send, {:form_backspace, field}}
  end

  def handle_key("q", _mods, _state), do: {:quit, :user}
  def handle_key(_key, _mods, _state), do: :ignore

  @impl true
  def update({:focus_field, field}, state), do: {:ok, %{state | focused_field: field}}

  def update(:toggle_subscribe, state), do: {:ok, %{state | subscribe: not state.subscribe}}

  def update({:form_char, field, char}, state) do
    value = Map.get(state, field) || ""
    {:ok, Map.put(state, field, value <> char)}
  end

  def update({:form_backspace, field}, state) do
    value = Map.get(state, field) || ""
    new_value = if value != "", do: String.slice(value, 0..-2//1), else: ""
    {:ok, Map.put(state, field, new_value)}
  end

  def update({:submit, _name, _email, _sub}, state) do
    {:ok, %{state | name: "", email: "", subscribe: false, focused_field: :name}}
  end

  def update(_msg, state), do: {:ok, state}

  @impl true
  def render(state, _theme) do
    box(border: :rounded, title: " Registration Form ", padding: 1) do
      [
        text("#{focus_marker(:name, state)}Name: #{state.name}#{cursor(:name, state)}"),
        text("#{focus_marker(:email, state)}Email: #{state.email}#{cursor(:email, state)}"),
        text("#{focus_marker(:subscribe, state)}#{check_mark(state)} Subscribe to newsletter"),
        text(""),
        text("#{focus_marker(:submit, state)}[ Submit ]"),
        text(""),
        text("[Tab] Next field  [Enter] Activate  [Backspace] Delete  [q] Quit", dim: true)
      ]
    end
  end

  defp focus_marker(field, state), do: if(state.focused_field == field, do: "> ", else: "  ")
  defp cursor(field, state), do: if(state.focused_field == field, do: "█", else: "")
  defp check_mark(state), do: if(state.subscribe, do: "[x]", else: "[ ]")
end

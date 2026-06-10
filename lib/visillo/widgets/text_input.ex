defmodule Visillo.Widgets.TextInput do
  @moduledoc """
  A single-line text input widget with cursor.

  ## Usage

      Visillo.Widgets.TextInput.new(placeholder: "Enter name...", value: "")
  """

  use Visillo.Component

  defstruct [:value, :placeholder, :cursor, :focused, width: 30]

  # ── Behaviour callbacks ─────────────────────────────────────────────────────

  @impl true
  @spec init(keyword()) :: {:ok, %__MODULE__{}}
  def init(props) do
    value = Keyword.get(props, :value, "")

    {:ok,
     %__MODULE__{
       value: value,
       placeholder: Keyword.get(props, :placeholder, ""),
       cursor: String.length(value),
       focused: false,
       width: Keyword.get(props, :width, 30)
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
  @spec handle_key(String.t(), list(), map()) ::
          :ignore | {:send, term()} | {:ok, map()} | {:quit, term()}
  def handle_key("backspace", _mods, state) do
    if state.cursor > 0 do
      new_val =
        String.slice(state.value, 0, state.cursor - 1) <>
          String.slice(state.value, state.cursor..-1//1)

      {:send, {:text_changed, new_val, state.cursor - 1}}
    else
      :ignore
    end
  end

  def handle_key("delete", _mods, state) do
    if state.cursor < String.length(state.value) do
      new_val =
        String.slice(state.value, 0, state.cursor) <>
          String.slice(state.value, (state.cursor + 1)..-1//1)

      {:send, {:text_changed, new_val, state.cursor}}
    else
      :ignore
    end
  end

  # Ignorar teclas de navegación (byte_size <= 4 que no deben insertarse como texto)
  def handle_key("tab", _, _state), do: :ignore

  def handle_key("home", _, state), do: {:ok, %{state | cursor: 0}}

  def handle_key("end", _, state) do
    {:ok, %{state | cursor: String.length(state.value)}}
  end

  def handle_key("up", _, _state), do: :ignore
  def handle_key("down", _, _state), do: :ignore
  def handle_key("left", _, state), do: {:ok, %{state | cursor: max(0, state.cursor - 1)}}

  def handle_key("right", _, state),
    do: {:ok, %{state | cursor: min(String.length(state.value), state.cursor + 1)}}

  # Teclas de función (F1-F12)
  def handle_key("f" <> _, _, _state), do: :ignore

  def handle_key(key, _mods, state) when byte_size(key) <= 4 do
    new_val =
      String.slice(state.value, 0, state.cursor) <>
        key <> String.slice(state.value, state.cursor..-1//1)

    {:send, {:text_changed, new_val, state.cursor + 1}}
  end

  def handle_key(_key, _mods, _state), do: :ignore

  @impl true
  @spec update(term(), map()) :: {:ok, map()}
  def update({:text_changed, value, cursor}, state) do
    {:ok, %{state | value: value, cursor: cursor}}
  end

  def update(_msg, state), do: {:ok, state}

  @impl true
  @spec render(map(), map()) :: Visillo.Widget.t()
  def render(state, _theme) do
    display = if state.value == "", do: state.placeholder, else: state.value
    display = String.slice(display, 0, state.width)

    if state.focused do
      with_cursor =
        if state.cursor < String.length(display) do
          String.slice(display, 0, state.cursor) <>
            "█" <> String.slice(display, (state.cursor + 1)..-1//1)
        else
          display <> "█"
        end

      text(with_cursor, color: :white)
    else
      text(String.pad_trailing(display, state.width), dim: true)
    end
  end
end

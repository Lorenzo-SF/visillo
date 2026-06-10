defmodule Visillo.Widgets.TextInputTest do
  use ExUnit.Case, async: true

  alias Visillo.Widgets.TextInput

  describe "init/1" do
    test "creates with defaults" do
      {:ok, state} = TextInput.init([])
      assert state.value == ""
      assert state.placeholder == ""
      assert state.cursor == 0
      assert state.width == 30
    end

    test "creates with pre-filled value" do
      {:ok, state} = TextInput.init(value: "hello", placeholder: "Enter text")
      assert state.value == "hello"
      assert state.placeholder == "Enter text"
      assert state.cursor == 5
    end
  end

  describe "focusable?/0" do
    test "returns true" do
      assert TextInput.focusable?()
    end
  end

  describe "handle_key/3" do
    test "backspace removes character before cursor" do
      {:ok, state} = TextInput.init(value: "hello")
      state = %{state | cursor: 5}
      assert {:send, {:text_changed, "hell", 4}} = TextInput.handle_key("backspace", [], state)
    end

    test "backspace at cursor 0 does nothing" do
      {:ok, state} = TextInput.init(value: "hello")
      state = %{state | cursor: 0}
      assert :ignore = TextInput.handle_key("backspace", [], state)
    end

    test "delete removes character at cursor" do
      {:ok, state} = TextInput.init(value: "hello")
      state = %{state | cursor: 0}
      assert {:send, {:text_changed, "ello", 0}} = TextInput.handle_key("delete", [], state)
    end

    test "inserts characters" do
      {:ok, state} = TextInput.init(value: "heo")
      state = %{state | cursor: 2}
      assert {:send, {:text_changed, "hello", 3}} = TextInput.handle_key("ll", [], state)
    end

    test "home moves cursor to start" do
      {:ok, state} = TextInput.init(value: "hello")
      state = %{state | cursor: 3}
      assert {:ok, %{cursor: 0}} = TextInput.handle_key("home", [], state)
    end

    test "end moves cursor to end" do
      {:ok, state} = TextInput.init(value: "hello")
      state = %{state | cursor: 0}
      assert {:ok, %{cursor: 5}} = TextInput.handle_key("end", [], state)
    end

    test "left moves cursor back" do
      {:ok, state} = TextInput.init(value: "hello")
      state = %{state | cursor: 3}
      assert {:ok, %{cursor: 2}} = TextInput.handle_key("left", [], state)
    end

    test "right moves cursor forward" do
      {:ok, state} = TextInput.init(value: "hello")
      state = %{state | cursor: 3}
      assert {:ok, %{cursor: 4}} = TextInput.handle_key("right", [], state)
    end

    test "tab is ignored" do
      {:ok, state} = TextInput.init(value: "hello")
      assert :ignore = TextInput.handle_key("tab", [], state)
    end

    test "navigation keys are ignored" do
      {:ok, state} = TextInput.init(value: "")
      assert :ignore = TextInput.handle_key("up", [], state)
      assert :ignore = TextInput.handle_key("down", [], state)
    end

    test "function keys are ignored" do
      {:ok, state} = TextInput.init(value: "")
      assert :ignore = TextInput.handle_key("f1", [], state)
      assert :ignore = TextInput.handle_key("f12", [], state)
    end
  end

  describe "update/2" do
    test "handles :text_changed" do
      {:ok, state} = TextInput.init([])
      assert {:ok, %{value: "hi", cursor: 2}} = TextInput.update({:text_changed, "hi", 2}, state)
    end
  end

  describe "render/2" do
    test "returns a text widget" do
      {:ok, state} = TextInput.init(value: "test")
      theme = Visillo.Theme.default()
      widget = TextInput.render(state, theme)
      assert widget.type == :text
    end

    test "shows placeholder when empty and not focused" do
      {:ok, state} = TextInput.init(placeholder: "Enter name...")
      theme = Visillo.Theme.default()
      widget = TextInput.render(state, theme)
      assert widget.type == :text
    end
  end
end

defmodule Visillo.Widgets.ButtonTest do
  use ExUnit.Case, async: true

  alias Visillo.Widgets.Button

  describe "init/1" do
    test "creates with defaults" do
      {:ok, state} = Button.init([])
      assert state.label == "Button"
      assert state.on_click == :clicked
      assert state.width == 20
    end

    test "creates with custom options" do
      {:ok, state} = Button.init(label: "Submit", on_click: :submit, width: 30)
      assert state.label == "Submit"
      assert state.on_click == :submit
      assert state.width == 30
    end
  end

  describe "focusable?/0" do
    test "returns true" do
      assert Button.focusable?()
    end
  end

  describe "handle_focus/1 and handle_blur/1" do
    test "handle_focus sets focused true" do
      {:ok, state} = Button.init([])
      {:ok, new_state} = Button.handle_focus(state)
      assert new_state.focused == true
    end

    test "handle_blur sets focused false" do
      {:ok, state} = Button.init([])
      {:ok, focused} = Button.handle_focus(state)
      {:ok, blurred} = Button.handle_blur(focused)
      assert blurred.focused == false
    end
  end

  describe "handle_key/3" do
    test "enter triggers on_click" do
      {:ok, state} = Button.init(label: "OK", on_click: :ok)
      assert {:send, :ok} = Button.handle_key("enter", [], state)
    end

    test "space triggers on_click" do
      {:ok, state} = Button.init(label: "OK", on_click: :ok)
      assert {:send, :ok} = Button.handle_key(" ", [], state)
    end

    test "other keys are ignored" do
      {:ok, state} = Button.init([])
      assert :ignore = Button.handle_key("a", [], state)
      assert :ignore = Button.handle_key("escape", [], state)
    end
  end

  describe "render/2" do
    test "returns a text widget" do
      {:ok, state} = Button.init([])
      theme = Visillo.Theme.default()
      widget = Button.render(state, theme)
      assert widget.type == :text
    end

    test "renders focused state differently" do
      {:ok, state} = Button.init([])
      theme = Visillo.Theme.default()
      {:ok, focused} = Button.handle_focus(state)
      widget = Button.render(focused, theme)
      assert widget.type == :text
    end
  end
end

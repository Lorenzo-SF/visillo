defmodule Visillo.Widgets.CheckboxTest do
  use ExUnit.Case, async: true

  alias Visillo.Widgets.Checkbox

  describe "init/1" do
    test "creates with defaults" do
      {:ok, state} = Checkbox.init([])
      assert state.label == "Option"
      assert state.checked == false
      assert state.focused == false
    end

    test "creates with custom options" do
      {:ok, state} = Checkbox.init(label: "Enable", checked: true)
      assert state.label == "Enable"
      assert state.checked == true
    end
  end

  describe "focusable?/0" do
    test "returns true" do
      assert Checkbox.focusable?()
    end
  end

  describe "handle_key/3" do
    test "enter toggles checked" do
      {:ok, state} = Checkbox.init([])
      assert {:send, {:toggled, true}} = Checkbox.handle_key("enter", [], state)
    end

    test "space toggles checked" do
      {:ok, state} = Checkbox.init(label: "Test", checked: true)
      assert {:send, {:toggled, false}} = Checkbox.handle_key(" ", [], state)
    end

    test "other keys are ignored" do
      {:ok, state} = Checkbox.init([])
      assert :ignore = Checkbox.handle_key("x", [], state)
    end
  end

  describe "update/2" do
    test "handles :toggled message" do
      {:ok, state} = Checkbox.init([])
      assert {:ok, %{checked: true}} = Checkbox.update({:toggled, true}, state)
    end
  end

  describe "render/2" do
    test "returns a text widget" do
      {:ok, state} = Checkbox.init([])
      theme = Visillo.Theme.default()
      widget = Checkbox.render(state, theme)
      assert widget.type == :text
    end
  end
end

defmodule Visillo.Widgets.PanelTest do
  use ExUnit.Case, async: true

  alias Visillo.Widgets.Panel
  alias Visillo.Widget

  describe "init/1" do
    test "creates with defaults" do
      {:ok, state} = Panel.init([])
      assert state.title == ""
      assert state.children == []
    end

    test "creates with title and children" do
      child = Widget.new(:text, %{content: "child"})
      {:ok, state} = Panel.init(title: "Status", children: [child])
      assert state.title == "Status"
      assert length(state.children) == 1
    end
  end

  describe "focusable?/0" do
    test "returns false" do
      refute Panel.focusable?()
    end
  end

  describe "render/2" do
    test "returns a box widget" do
      {:ok, state} = Panel.init(title: "Test")
      theme = Visillo.Theme.default()
      widget = Panel.render(state, theme)
      assert widget.type == :box
      assert widget.props.title == "Test"
    end

    test "renders children inside box" do
      child = Widget.new(:text, %{content: "inside"})
      {:ok, state} = Panel.init(title: "Panel", children: [child])
      theme = Visillo.Theme.default()
      widget = Panel.render(state, theme)
      assert widget.type == :box
      assert length(widget.children) == 1
    end
  end
end

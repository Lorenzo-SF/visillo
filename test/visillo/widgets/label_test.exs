defmodule Visillo.Widgets.LabelTest do
  use ExUnit.Case, async: true

  alias Visillo.Widgets.Label

  describe "init/1" do
    test "creates with defaults" do
      {:ok, state} = Label.init([])
      assert state.text == ""
      assert state.color == :white
      assert state.bold == false
    end

    test "creates with custom options" do
      {:ok, state} = Label.init(text: "Hello", color: :green, bold: true)
      assert state.text == "Hello"
      assert state.color == :green
      assert state.bold == true
    end
  end

  describe "focusable?/0" do
    test "returns false" do
      refute Label.focusable?()
    end
  end

  describe "render/2" do
    test "returns a text widget" do
      {:ok, state} = Label.init(text: "Hello, World!")
      theme = Visillo.Theme.default()
      widget = Label.render(state, theme)
      assert widget.type == :text
      assert widget.props.content == "Hello, World!"
    end

    test "renders with color and bold" do
      {:ok, state} = Label.init(text: "Bold Green", color: :green, bold: true)
      theme = Visillo.Theme.default()
      widget = Label.render(state, theme)
      assert widget.props.color == :green
      assert widget.props.bold == true
    end
  end
end

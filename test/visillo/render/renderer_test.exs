defmodule Visillo.Render.RendererTest do
  use ExUnit.Case, async: true

  alias Visillo.Render.Renderer
  alias Alaja.Buffer
  alias Visillo.Widget

  describe "render/4" do
    test "renders a text widget into buffer" do
      w = Widget.new(:text, %{content: "Hello"})

      laid_out = %{
        widget: w,
        rect: %{x: 0, y: 0, width: 10, height: 1},
        children: []
      }

      buf = Buffer.new(10, 1)
      theme = Visillo.Theme.default()
      result = Renderer.render(laid_out, buf, theme)
      assert result.width == 10
    end

    test "renders empty widget tree" do
      laid_out = %{
        widget: Widget.new(:text, %{content: ""}),
        rect: %{x: 0, y: 0, width: 0, height: 0},
        children: []
      }

      buf = Buffer.new(5, 5)
      theme = Visillo.Theme.default()
      result = Renderer.render(laid_out, buf, theme)
      assert result.width == 5
      assert result.height == 5
    end

    test "handles nil focused_id" do
      w = Widget.new(:box, %{border: :rounded, title: "Test"})

      laid_out = %{
        widget: w,
        rect: %{x: 0, y: 0, width: 10, height: 5},
        children: []
      }

      buf = Buffer.new(10, 5)
      theme = Visillo.Theme.default()
      result = Renderer.render(laid_out, buf, theme, frame: 0, focused_id: nil)
      assert result.width == 10
    end

    test "renders button widget" do
      w = Widget.new(:button, %{label: "Click", variant: :primary})

      laid_out = %{
        widget: w,
        rect: %{x: 0, y: 0, width: 10, height: 1},
        children: []
      }

      buf = Buffer.new(10, 1)
      theme = Visillo.Theme.default()
      result = Renderer.render(laid_out, buf, theme)
      assert is_map(result)
    end

    test "renders separator widget" do
      w = Widget.new(:separator, %{})

      laid_out = %{
        widget: w,
        rect: %{x: 0, y: 0, width: 10, height: 1},
        children: []
      }

      buf = Buffer.new(10, 1)
      theme = Visillo.Theme.default()
      result = Renderer.render(laid_out, buf, theme)
      assert is_map(result)
    end

    test "renders progress_bar widget" do
      w = Widget.new(:progress_bar, %{value: 50, total: 100})

      laid_out = %{
        widget: w,
        rect: %{x: 0, y: 0, width: 20, height: 1},
        children: []
      }

      buf = Buffer.new(20, 1)
      theme = Visillo.Theme.default()
      result = Renderer.render(laid_out, buf, theme)
      assert is_map(result)
    end

    test "renders list widget" do
      w = Widget.new(:list, %{items: ["A", "B", "C"], selected: 1})

      laid_out = %{
        widget: w,
        rect: %{x: 0, y: 0, width: 20, height: 3},
        children: []
      }

      buf = Buffer.new(20, 3)
      theme = Visillo.Theme.default()
      result = Renderer.render(laid_out, buf, theme)
      assert is_map(result)
    end

    test "renders gauge widget" do
      w = Widget.new(:gauge, %{value: 50, min: 0, max: 100, label: "CPU"})

      laid_out = %{
        widget: w,
        rect: %{x: 0, y: 0, width: 20, height: 1},
        children: []
      }

      buf = Buffer.new(20, 1)
      theme = Visillo.Theme.default()
      result = Renderer.render(laid_out, buf, theme)
      assert is_map(result)
    end

    test "renders children recursively" do
      child = Widget.new(:text, %{content: "child"})
      parent = Widget.new(:box, %{border: :none}, [child])

      laid_out = %{
        widget: parent,
        rect: %{x: 0, y: 0, width: 10, height: 2},
        children: [
          %{
            widget: child,
            rect: %{x: 0, y: 0, width: 10, height: 1},
            children: []
          }
        ]
      }

      buf = Buffer.new(10, 2)
      theme = Visillo.Theme.default()
      result = Renderer.render(laid_out, buf, theme)
      assert is_map(result)
    end

    test "renders table widget" do
      w = Widget.new(:table, %{headers: ["Name", "Value"], rows: [["A", "1"], ["B", "2"]]})

      laid_out = %{
        widget: w,
        rect: %{x: 0, y: 0, width: 20, height: 5},
        children: []
      }

      buf = Buffer.new(20, 5)
      theme = Visillo.Theme.default()
      result = Renderer.render(laid_out, buf, theme)
      assert is_map(result)
    end
  end
end

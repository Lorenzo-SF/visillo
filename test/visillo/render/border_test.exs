defmodule Visillo.Render.BorderTest do
  use ExUnit.Case, async: true

  alias Visillo.Render.Border
  alias Alaja.Buffer

  describe "draw/7" do
    test "draws a border into buffer" do
      buf = Buffer.new(10, 5)
      rect = %{x: 0, y: 0, width: 10, height: 5}
      result = Border.draw(buf, rect, :rounded, nil)
      assert is_map(result)
      assert result.width == 10
      assert result.height == 5
    end

    test "draws with all border styles" do
      styles = [:none, :single, :double, :rounded, :bold, :dashed, :ascii]
      buf = Buffer.new(10, 5)
      rect = %{x: 0, y: 0, width: 10, height: 5}

      Enum.each(styles, fn style ->
        result = Border.draw(buf, rect, style, nil)
        assert is_map(result), "Border style #{style} should work"
      end)
    end

    test "draws with title" do
      buf = Buffer.new(15, 5)
      rect = %{x: 0, y: 0, width: 15, height: 5}
      result = Border.draw(buf, rect, :rounded, nil, "Title")
      assert is_map(result)
    end

    test "draws with title centered" do
      buf = Buffer.new(15, 5)
      rect = %{x: 0, y: 0, width: 15, height: 5}
      result = Border.draw(buf, rect, :rounded, nil, "Title", :center)
      assert is_map(result)
    end

    test "draws with title right-aligned" do
      buf = Buffer.new(15, 5)
      rect = %{x: 0, y: 0, width: 15, height: 5}
      result = Border.draw(buf, rect, :rounded, nil, "Title", :right)
      assert is_map(result)
    end

    test "returns buffer unchanged if rect too small" do
      buf = Buffer.new(1, 1)
      rect = %{x: 0, y: 0, width: 1, height: 1}
      result = Border.draw(buf, rect, :rounded, nil)
      assert result == buf
    end

    test "draws with background color" do
      buf = Buffer.new(10, 5)
      rect = %{x: 0, y: 0, width: 10, height: 5}
      result = Border.draw(buf, rect, :single, {255, 0, 0}, nil, :left, {0, 0, 0})
      assert is_map(result)
    end

    test "supports offset position" do
      buf = Buffer.new(20, 20)
      rect = %{x: 5, y: 5, width: 10, height: 5}
      result = Border.draw(buf, rect, :rounded, nil)
      assert is_map(result)
    end
  end

  describe "styles/0" do
    test "returns list of border styles" do
      styles = Border.styles()
      assert is_list(styles)
      assert :rounded in styles
      assert :single in styles
      assert :none in styles
    end
  end
end

defmodule Visillo.ScreenTest do
  use ExUnit.Case, async: true

  alias Visillo.Screen
  alias Alaja.{Buffer, Cell}

  describe "build_diff/3" do
    test "returns list for identical buffers" do
      buf = Buffer.new(3, 3)
      result = Screen.build_diff(buf, buf, false)
      assert is_list(result)
    end

    test "detects cell changes" do
      prev = Buffer.new(3, 3)
      curr = Buffer.new(3, 3)
      cell = Cell.new("X", {255, 0, 0})
      curr = Buffer.update_cell(curr, 1, 1, cell)

      result = Screen.build_diff(prev, curr, false)
      # Should contain ANSI sequences for the changed cell
      assert result != []
    end

    test "force_all returns all cells" do
      prev = Buffer.new(2, 2)
      curr = Buffer.new(2, 2)
      cell = Cell.new("A")
      curr = Buffer.update_cell(curr, 0, 0, cell)

      result = Screen.build_diff(prev, curr, true)
      # force_all should include the cell at 0,0 
      assert result != []
    end

    test "handles empty buffers" do
      prev = Buffer.new(0, 0)
      curr = Buffer.new(0, 0)
      assert Screen.build_diff(prev, curr, false) == []
    end

    test "handles different sized buffers" do
      prev = Buffer.new(5, 5)
      curr = Buffer.new(3, 3)
      assert is_list(Screen.build_diff(prev, curr, false))
    end
  end

  describe "public API functions" do
    test "set_title/1 returns :ok" do
      assert Screen.set_title("Test") == :ok
    end

    test "copy_to_clipboard/1 returns :ok" do
      assert Screen.copy_to_clipboard("text") == :ok
    end

    test "set_cursor_visible/1 returns :ok" do
      assert Screen.set_cursor_visible(true) == :ok
      assert Screen.set_cursor_visible(false) == :ok
    end
  end
end

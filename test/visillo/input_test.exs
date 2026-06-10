defmodule Visillo.InputTest do
  use ExUnit.Case, async: true

  alias Visillo.Input

  describe "enable_raw_mode/0" do
    test "returns :ok or {:error, _}" do
      result = Input.enable_raw_mode()
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "restore_terminal/0" do
    test "returns :ok or {:error, _}" do
      result = Input.restore_terminal()
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "mouse enable/disable" do
    test "enable_mouse returns :ok" do
      assert Input.enable_mouse() == :ok
    end

    test "disable_mouse returns :ok" do
      assert Input.disable_mouse() == :ok
    end
  end

  describe "focus events enable/disable" do
    test "enable_focus_events returns :ok" do
      assert Input.enable_focus_events() == :ok
    end

    test "disable_focus_events returns :ok" do
      assert Input.disable_focus_events() == :ok
    end
  end

  describe "bracketed paste enable/disable" do
    test "enable_bracketed_paste returns :ok" do
      assert Input.enable_bracketed_paste() == :ok
    end

    test "disable_bracketed_paste returns :ok" do
      assert Input.disable_bracketed_paste() == :ok
    end
  end

  describe "start_link/1" do
    test "requires opts" do
      # start_link should accept opts keyword list
      assert is_function(&Input.start_link/1)
    end
  end
end

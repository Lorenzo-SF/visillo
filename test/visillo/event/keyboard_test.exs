defmodule Visillo.Event.KeyboardTest do
  use ExUnit.Case, async: true

  alias Visillo.Event.Keyboard

  describe "parse/1" do
    test "parses arrow keys" do
      assert Keyboard.parse("\e[A") == {:key, "up", []}
      assert Keyboard.parse("\e[B") == {:key, "down", []}
      assert Keyboard.parse("\e[C") == {:key, "right", []}
      assert Keyboard.parse("\e[D") == {:key, "left", []}
    end

    test "parses tab and shift+tab" do
      assert Keyboard.parse("\t") == {:key, "tab", []}
      assert Keyboard.parse("\e[Z") == {:key, "tab", [:shift]}
    end

    test "parses enter" do
      assert Keyboard.parse("\r") == {:key, "enter", []}
      assert Keyboard.parse("\n") == {:key, "enter", []}
    end

    test "parses space" do
      assert Keyboard.parse(" ") == {:key, "space", []}
    end

    test "parses backspace" do
      assert Keyboard.parse("\x7F") == {:key, "backspace", []}
      assert Keyboard.parse("\b") == {:key, "backspace", []}
    end

    test "parses function keys" do
      assert Keyboard.parse("\eOP") == {:key, "f1", []}
      assert Keyboard.parse("\e[15~") == {:key, "f5", []}
    end

    test "parses navigation keys" do
      assert Keyboard.parse("\e[H") == {:key, "home", []}
      assert Keyboard.parse("\e[F") == {:key, "end", []}
      assert Keyboard.parse("\e[5~") == {:key, "page_up", []}
      assert Keyboard.parse("\e[6~") == {:key, "page_down", []}
      assert Keyboard.parse("\e[2~") == {:key, "insert", []}
      assert Keyboard.parse("\e[3~") == {:key, "delete", []}
    end

    test "parses ctrl+letter" do
      assert Keyboard.parse(<<1>>) == {:key, "a", [:ctrl]}
      assert Keyboard.parse(<<26>>) == {:key, "z", [:ctrl]}
    end

    test "parses ctrl+space" do
      assert Keyboard.parse(<<0>>) == {:key, "space", [:ctrl]}
    end

    test "parses escape alone" do
      assert Keyboard.parse(<<27>>) == {:key, "escape", []}
    end

    test "parses alt+key" do
      assert Keyboard.parse(<<27, "a">>) == {:key, "a", [:alt]}
    end

    test "parses arrow keys with modifiers" do
      assert Keyboard.parse("\e[1;2A") == {:key, "up", [:shift]}
      assert Keyboard.parse("\e[1;3B") == {:key, "down", [:alt]}
      assert Keyboard.parse("\e[1;5C") == {:key, "right", [:ctrl]}
      assert Keyboard.parse("\e[1;7D") == {:key, "left", [:ctrl, :alt]}
    end

    test "parses printable ASCII" do
      assert Keyboard.parse("a") == {:key, "a", []}
      assert Keyboard.parse("Z") == {:key, "Z", []}
      assert Keyboard.parse("1") == {:key, "1", []}
    end

    test "parses focus events" do
      assert Keyboard.parse("\e[I") == {:key, "focus_in", []}
      assert Keyboard.parse("\e[O") == {:key, "focus_out", []}
    end

    test "returns :unknown for unrecognized sequences" do
      assert Keyboard.parse(<<128>>) == {:unknown, <<128>>}
    end

    test "parses UTF-8 printable characters" do
      assert Keyboard.parse("ñ") == {:key, "ñ", []}
      assert Keyboard.parse("€") == {:key, "€", []}
    end

    test "handles SS3 arrow variants" do
      assert Keyboard.parse("\eOA") == {:key, "up", []}
      assert Keyboard.parse("\eOB") == {:key, "down", []}
      assert Keyboard.parse("\eOC") == {:key, "right", []}
      assert Keyboard.parse("\eOD") == {:key, "left", []}
    end

    test "parses ctrl+\\, ], ^, _" do
      assert Keyboard.parse(<<28>>) == {:key, "\\", [:ctrl]}
      assert Keyboard.parse(<<29>>) == {:key, "]", [:ctrl]}
      assert Keyboard.parse(<<30>>) == {:key, "^", [:ctrl]}
      assert Keyboard.parse(<<31>>) == {:key, "_", [:ctrl]}
    end
  end

  describe "format/1" do
    test "formats simple key" do
      assert Keyboard.format({:key, "up", []}) == "↑"
      assert Keyboard.format({:key, "a", []}) == "a"
    end

    test "formats key with modifiers" do
      assert Keyboard.format({:key, "c", [:ctrl]}) == "Ctrl+c"
      assert Keyboard.format({:key, "a", [:ctrl, :alt]}) == "Ctrl+Alt+a"
    end

    test "formats special keys" do
      assert Keyboard.format({:key, "enter", []}) == "↵"
      assert Keyboard.format({:key, "tab", []}) == "⇥"
      assert Keyboard.format({:key, "escape", []}) == "Esc"
    end
  end
end

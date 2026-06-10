defmodule Visillo.Event.MouseTest do
  use ExUnit.Case, async: true

  alias Visillo.Event.Mouse

  describe "parse/1" do
    test "parses SGR left button press" do
      # \e[<0;10;20M — left button at (10,20), press
      seq = "\e[<0;10;20M"
      assert {:ok, event} = Mouse.parse(seq)
      assert event.button == :left
      assert event.action == :press
      assert event.x == 9
      assert event.y == 19
    end

    test "parses SGR right button press" do
      # \e[<2;5;15M — right button at (5,15), press
      seq = "\e[<2;5;15M"
      assert {:ok, event} = Mouse.parse(seq)
      assert event.button == :right
      assert event.action == :press
      assert event.x == 4
      assert event.y == 14
    end

    test "parses SGR button release" do
      # \e[<0;10;20m — left button release at (10,20)
      seq = "\e[<0;10;20m"
      assert {:ok, event} = Mouse.parse(seq)
      assert event.button == :left
      assert event.action == :release
    end

    test "parses SGR scroll up" do
      # \e[<64;5;5M — scroll up (bit 6 set)
      seq = "\e[<64;5;5M"
      assert {:ok, event} = Mouse.parse(seq)
      assert event.button == :scroll_up
      assert event.action == :scroll
    end

    test "parses SGR scroll down" do
      # \e[<65;5;5M — scroll down (bit 6 set + bit 0)
      seq = "\e[<65;5;5M"
      assert {:ok, event} = Mouse.parse(seq)
      assert event.button == :scroll_down
      assert event.action == :scroll
    end

    test "parses SGR with modifiers" do
      # \e[<4;10;20M — left button + shift (bit 2 set)
      seq = "\e[<4;10;20M"
      assert {:ok, event} = Mouse.parse(seq)
      assert event.button == :left
      assert :shift in event.modifiers
    end

    test "parses X10 mouse" do
      # \e[M  x y — b=32 (left), x=37 (5), y=40 (8)
      seq = "\e[M" <> <<32, 37, 40>>
      assert {:ok, event} = Mouse.parse(seq)
      assert event.button == :left
      assert event.action == :press
      assert event.x == 5
      assert event.y == 8
    end

    test "returns error for invalid sequences" do
      assert Mouse.parse("") == {:error, :unknown}
      assert Mouse.parse("garbage") == {:error, :unknown}
      assert Mouse.parse("\e[<invalid") == {:error, :unknown}
    end

    test "parses SGR middle button" do
      seq = "\e[<1;15;25M"
      assert {:ok, event} = Mouse.parse(seq)
      assert event.button == :middle
      assert event.x == 14
      assert event.y == 24
    end

    test "parses SGR with ctrl modifier" do
      # \e[<16;10;20M — ctrl (bit 4 set)
      seq = "\e[<16;10;20M"
      assert {:ok, event} = Mouse.parse(seq)
      assert :ctrl in event.modifiers
    end
  end
end

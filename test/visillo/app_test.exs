defmodule Visillo.AppTest do
  use ExUnit.Case, async: true

  alias Visillo.App

  # A minimal component for testing App internals
  defmodule TestComponent do
    use Visillo.Component

    defstruct [:count]

    @impl true
    def init(_props), do: {:ok, %__MODULE__{count: 0}}

    @impl true
    def handle_key("q", _mods, _state), do: {:quit, :user}
    def handle_key("+", _mods, _state), do: {:send, :inc}
    def handle_key(_, _, _), do: :ignore

    @impl true
    def update(:inc, state), do: {:ok, %{state | count: state.count + 1}}
    def update(_msg, state), do: {:ok, state}

    @impl true
    def focusable?, do: true

    @impl true
    def render(state, _theme) do
      Visillo.DSL.text("Count: #{state.count}")
    end
  end

  describe "normalise_quit_keys/1" do
    test "normalizes single keys" do
      result = App.normalise_quit_keys(["q", "ctrl+c"])
      assert "q" in result
      # The key char is sorted among modifiers: c+ctrl
      assert "c+ctrl" in result
    end

    test "sorts modifiers and key together" do
      [result] = App.normalise_quit_keys(["ctrl+shift+c"])
      # Parts are sorted: ["c", "ctrl", "shift"] -> "c+ctrl+shift"
      assert result == "c+ctrl+shift"
    end

    test "downcases keys" do
      [result] = App.normalise_quit_keys(["Ctrl+C"])
      assert result == "c+ctrl"
    end

    test "handles empty list" do
      assert App.normalise_quit_keys([]) == []
    end
  end

  describe "dispatch_update/2" do
    test "handles {:ok, new_state} result" do
      {:ok, state} = TestComponent.init([])
      app_state = %{module: TestComponent, component_state: state, dirty: false}
      result = App.dispatch_update(app_state, :inc)
      assert result.dirty == true
    end
  end

  describe "execute_command/2" do
    test "handles {:focus, id}" do
      # execute_command needs state.focus (PID) — use mock
      result = App.execute_command(%{focus: nil, focused_id: nil, dirty: false}, {:focus, :my_id})
      assert result.dirty == true
      assert result.focused_id == :my_id
    end

    test "handles {:publish, topic, event}" do
      result = App.execute_command(%{event_bus: nil}, {:publish, :topic, :event})
      assert is_map(result)
    end

    test "handles {:copy, text}" do
      result = App.execute_command(%{}, {:copy, "hello"})
      assert result == %{}
    end

    test "handles unrecognized commands" do
      result = App.execute_command(%{}, {:unknown, :data})
      assert result == %{}
    end
  end

  describe "handle_component_result/2" do
    test ":ignore returns state unchanged" do
      result = App.handle_component_result(%{dirty: false}, :ignore)
      assert result.dirty == false
    end

    test "{:quit, reason} sends quit message" do
      App.handle_component_result(%{}, {:quit, :user})
      assert_receive {:input, {:quit, :user}}, 100
    end
  end
end

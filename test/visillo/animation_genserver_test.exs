defmodule Visillo.AnimationGenServerTest do
  use ExUnit.Case, async: false

  alias Visillo.Animation

  setup do
    {:ok, pid} =
      Animation.start_link(
        fps: 1000,
        name: :"anim_test_#{System.unique_integer()}"
      )

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    {:ok, server: pid}
  end

  describe "subscribe/1" do
    test "subscribes to animation ticks", %{server: server} do
      Animation.subscribe(self(), server)
      # With 1000 fps, we should get a tick quickly
      assert_receive {:tick, _frame}, 100
    end

    test "multiple subscribers receive ticks", %{server: server} do
      test_pid = self()

      spawn(fn ->
        Animation.subscribe(self(), server)

        receive do
          {:tick, _} -> send(test_pid, {:got_tick, 1})
        after
          200 -> send(test_pid, {:timeout, 1})
        end
      end)

      spawn(fn ->
        Animation.subscribe(self(), server)

        receive do
          {:tick, _} -> send(test_pid, {:got_tick, 2})
        after
          200 -> send(test_pid, {:timeout, 2})
        end
      end)

      # Wait for both subscribers to get their ticks
      assert_receive {:got_tick, _}, 300
      assert_receive {:got_tick, _}, 100
    end
  end

  describe "unsubscribe/1" do
    test "unsubscribed process stops receiving ticks", %{server: server} do
      Animation.subscribe(self(), server)
      assert_receive {:tick, _}, 100
      Animation.unsubscribe(self(), server)
      # Should not receive more ticks
      refute_receive {:tick, _}, 100
    end
  end

  describe "set_fps/2" do
    test "changes tick rate", %{server: server} do
      Animation.subscribe(self(), server)
      Animation.set_fps(10, server)
      # Should still receive ticks at the new rate
      assert_receive {:tick, _}, 500
    end
  end

  describe "current_frame/1" do
    test "returns current frame number", %{server: server} do
      frame = Animation.current_frame(server)
      assert is_integer(frame)
      assert frame >= 0
    end

    test "frame advances after ticks", %{server: server} do
      frame1 = Animation.current_frame(server)
      Process.sleep(50)
      frame2 = Animation.current_frame(server)
      assert frame2 >= frame1
    end
  end

  describe "dead subscriber cleanup" do
    test "dead subscribers are removed", %{server: server} do
      spawn(fn ->
        Animation.subscribe(self(), server)
        :ok
      end)

      # Give time for subscription and process death
      Process.sleep(50)
      # The dead PID should be cleaned up on next tick
      Animation.subscribe(self(), server)
      assert_receive {:tick, _}, 200
    end
  end
end

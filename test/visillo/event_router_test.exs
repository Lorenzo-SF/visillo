defmodule Visillo.EventRouterTest do
  use ExUnit.Case, async: false

  alias Visillo.EventRouter

  setup do
    app_pid = self()

    {:ok, pid} =
      EventRouter.start_link(
        app_pid: app_pid,
        quit_keys: ["q", "ctrl+c"],
        focus_keys: [],
        name: :"router_test_#{System.unique_integer()}"
      )

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    {:ok, router: pid, app: app_pid}
  end

  describe "quit key routing" do
    test "sends {:input, {:quit, :user}} on quit key match", %{router: router, app: _app} do
      send(router, {:raw_input, {:key, "q", []}})
      assert_receive {:input, {:quit, :user}}, 100
    end

    test "sends {:input, {:quit, :user}} on ctrl+c", %{router: router, app: _app} do
      send(router, {:raw_input, {:key, "c", [:ctrl]}})
      assert_receive {:input, {:quit, :user}}, 100
    end
  end

  describe "focus key routing" do
    test "when focus_keys is empty, Tab passes through to component", %{router: router, app: _app} do
      send(router, {:raw_input, {:key, "tab", []}})
      assert_receive {:input, {:key, "tab", []}}, 100
    end
  end

  describe "mouse routing" do
    test "mouse events bypass layers and go straight to app", %{router: router, app: _app} do
      mouse_event = %{button: :left, action: :press, x: 5, y: 10, modifiers: []}
      send(router, {:raw_input, {:mouse, mouse_event}})
      assert_receive {:input, {:mouse, ^mouse_event}}, 100
    end
  end

  describe "paste routing" do
    test "paste events go straight to app", %{router: router, app: _app} do
      send(router, {:raw_input, {:paste, "hello"}})
      assert_receive {:input, {:paste, "hello"}}, 100
    end
  end

  describe "key routing with focus_keys enabled" do
    test "Tab is intercepted when focus_keys contains tab", %{app: app} do
      {:ok, pid} =
        EventRouter.start_link(
          app_pid: app,
          quit_keys: ["q"],
          focus_keys: ["tab"],
          name: :"router_focus_test_#{System.unique_integer()}"
        )

      send(pid, {:raw_input, {:key, "tab", []}})
      assert_receive {:input, :focus_next}, 100
      GenServer.stop(pid)
    end

    test "Shift+Tab is intercepted when focus_keys contains tab", %{app: app} do
      {:ok, pid} =
        EventRouter.start_link(
          app_pid: app,
          quit_keys: ["q"],
          focus_keys: ["tab"],
          name: :"router_shift_test_#{System.unique_integer()}"
        )

      send(pid, {:raw_input, {:key, "tab", [:shift]}})
      assert_receive {:input, :focus_prev}, 100
      GenServer.stop(pid)
    end
  end

  describe "resize routing" do
    test "resize messages forwarded to app", %{router: router, app: _app} do
      send(router, {:input, {:resize, 100, 30}})
      assert_receive {:input, {:resize, 100, 30}}, 100
    end
  end

  describe "eof routing" do
    test "eof sends quit", %{router: router, app: _app} do
      send(router, {:raw_input, :eof})
      assert_receive {:input, {:quit, :eof}}, 100
    end
  end

  describe "unknown events" do
    test "unknown raw_input is silently ignored", %{router: router} do
      send(router, {:raw_input, {:unknown, "???"}})
      refute_receive _, 50
    end

    test "unknown messages are ignored", %{router: router} do
      send(router, :garbage)
      refute_receive _, 50
    end
  end
end

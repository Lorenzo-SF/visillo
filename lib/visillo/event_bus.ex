defmodule Visillo.EventBus do
  @moduledoc """
  Pub/sub event bus for communication between TUI components.

  Allows decoupled components to communicate without knowing each other directly.
  Messages arrive as `{:bus_event, topic, event}` to the subscribed process.

  ## Usage

      # Subscribe to a topic
      Visillo.EventBus.subscribe(:file_selected)

      # Publish an event
      Visillo.EventBus.publish(:file_selected, "/home/user/file.txt")

      # The subscribed process receives:
      # {:bus_event, :file_selected, "/home/user/file.txt"}
  """

  use GenServer

  # %{topic => MapSet.t(pid)}
  defstruct subscriptions: %{}

  # ─── API ────────────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Subscribes the current process to a topic."
  @spec subscribe(atom()) :: :ok
  def subscribe(topic) do
    GenServer.cast(__MODULE__, {:subscribe, topic, self()})
  end

  @doc "Subscribes a specific PID to a topic."
  @spec subscribe(atom(), pid()) :: :ok
  def subscribe(topic, pid) do
    GenServer.cast(__MODULE__, {:subscribe, topic, pid})
  end

  @doc "Unsubscribes the current process from a topic."
  @spec unsubscribe(atom()) :: :ok
  def unsubscribe(topic) do
    GenServer.cast(__MODULE__, {:unsubscribe, topic, self()})
  end

  @doc "Unsubscribes the current process from all topics."
  @spec unsubscribe_all() :: :ok
  def unsubscribe_all do
    GenServer.cast(__MODULE__, {:unsubscribe_all, self()})
  end

  @doc "Publishes an event to a topic. All subscribers will receive it."
  @spec publish(atom(), term()) :: :ok
  def publish(topic, event) do
    GenServer.cast(__MODULE__, {:publish, topic, event})
  end

  @doc "Returns the active subscribers for a topic."
  @spec subscribers(atom()) :: [pid()]
  def subscribers(topic) do
    GenServer.call(__MODULE__, {:subscribers, topic})
  end

  # ─── GenServer callbacks ─────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_cast({:subscribe, topic, pid}, state) do
    # Monitorear el proceso para auto-limpiar suscripciones muertas
    Process.monitor(pid)

    pids = Map.get(state.subscriptions, topic, MapSet.new())
    new_subs = Map.put(state.subscriptions, topic, MapSet.put(pids, pid))
    {:noreply, %{state | subscriptions: new_subs}}
  end

  def handle_cast({:unsubscribe, topic, pid}, state) do
    new_subs =
      case Map.get(state.subscriptions, topic) do
        nil -> state.subscriptions
        pids -> Map.put(state.subscriptions, topic, MapSet.delete(pids, pid))
      end

    {:noreply, %{state | subscriptions: new_subs}}
  end

  def handle_cast({:unsubscribe_all, pid}, state) do
    new_subs =
      state.subscriptions
      |> Enum.map(fn {topic, pids} -> {topic, MapSet.delete(pids, pid)} end)
      |> Map.new()

    {:noreply, %{state | subscriptions: new_subs}}
  end

  def handle_cast({:publish, topic, event}, state) do
    pids = Map.get(state.subscriptions, topic, MapSet.new())

    # Limpiar PIDs muertos mientras enviamos
    {alive, dead} =
      Enum.split_with(MapSet.to_list(pids), &Process.alive?/1)

    Enum.each(alive, &send(&1, {:bus_event, topic, event}))

    # Remover muertos
    new_pids = Enum.reduce(dead, MapSet.new(alive), &MapSet.delete(&2, &1))
    new_subs = Map.put(state.subscriptions, topic, new_pids)

    {:noreply, %{state | subscriptions: new_subs}}
  end

  @impl true
  def handle_call({:subscribers, topic}, _from, state) do
    pids =
      state.subscriptions
      |> Map.get(topic, MapSet.new())
      |> MapSet.to_list()
      |> Enum.filter(&Process.alive?/1)

    {:reply, pids, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Auto-limpiar suscripciones del proceso muerto
    new_subs =
      state.subscriptions
      |> Enum.map(fn {topic, pids} -> {topic, MapSet.delete(pids, pid)} end)
      |> Map.new()

    {:noreply, %{state | subscriptions: new_subs}}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end

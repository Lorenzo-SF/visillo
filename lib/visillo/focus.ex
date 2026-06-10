defmodule Visillo.Focus do
  @moduledoc """
  Focus manager for TUI components.

  Maintains an ordered list of focusable components and manages
  navigation between them with Tab / Shift+Tab.

  Only the focused component receives keyboard events directly.
  """

  use GenServer

  # [{id, tab_order}] ordenado
  defstruct focusables: [],
            current: nil

  # ─── API ────────────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Registers a component as focusable with a tab order.

  ## Parameters
    * `pid` — PID of the Focus GenServer (default: `__MODULE__`). 
      Use the session PID returned by `start_link/1`.
  """
  @spec register(atom() | String.t(), non_neg_integer(), pid()) :: :ok
  def register(id, tab_order \\ 0, pid \\ __MODULE__) do
    GenServer.cast(pid, {:register, id, tab_order})
  end

  @doc "Unregisters a component."
  @spec unregister(atom() | String.t(), pid()) :: :ok
  def unregister(id, pid \\ __MODULE__) do
    GenServer.cast(pid, {:unregister, id})
  end

  @doc "Moves focus to the next component in tab order."
  @spec next(pid()) :: atom() | String.t() | nil
  def next(pid \\ __MODULE__) do
    GenServer.call(pid, :next)
  end

  @doc "Moves focus to the previous component."
  @spec previous(pid()) :: atom() | String.t() | nil
  def previous(pid \\ __MODULE__) do
    GenServer.call(pid, :previous)
  end

  @doc "Sets focus to a specific component."
  @spec set(atom() | String.t(), pid()) :: :ok
  def set(id, pid \\ __MODULE__) do
    GenServer.cast(pid, {:set, id})
  end

  @doc "Removes focus from any component."
  @spec blur(pid()) :: :ok
  def blur(pid \\ __MODULE__) do
    GenServer.cast(pid, :blur)
  end

  @doc "Returns the ID of the currently focused component."
  @spec focused(pid()) :: atom() | String.t() | nil
  def focused(pid \\ __MODULE__) do
    GenServer.call(pid, :focused)
  end

  @doc "Returns whether a component is focused."
  @spec focused?(atom() | String.t(), pid()) :: boolean()
  def focused?(id, pid \\ __MODULE__) do
    focused(pid) == id
  end

  # ─── GenServer callbacks ─────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_cast({:register, id, tab_order}, state) do
    focusables =
      state.focusables
      |> Enum.reject(fn {fid, _} -> fid == id end)
      |> then(&[{id, tab_order} | &1])
      |> Enum.sort_by(fn {_, order} -> order end)

    current =
      if focusables == [],
        do: nil,
        else: elem(hd(focusables), 0)

    {:noreply, %{state | focusables: focusables, current: current}}
  end

  def handle_cast({:unregister, id}, state) do
    focusables = Enum.reject(state.focusables, fn {fid, _} -> fid == id end)

    current =
      if state.current == id do
        case focusables do
          [{first_id, _} | _] -> first_id
          [] -> nil
        end
      else
        state.current
      end

    {:noreply, %{state | focusables: focusables, current: current}}
  end

  def handle_cast({:set, id}, state) do
    {:noreply, %{state | current: id}}
  end

  def handle_cast(:blur, state) do
    {:noreply, %{state | current: nil}}
  end

  @impl true
  def handle_call(:focused, _from, state) do
    {:reply, state.current, state}
  end

  def handle_call(:next, _from, state) do
    new_current = cycle(state.focusables, state.current, :forward)
    {:reply, new_current, %{state | current: new_current}}
  end

  def handle_call(:previous, _from, state) do
    new_current = cycle(state.focusables, state.current, :backward)
    {:reply, new_current, %{state | current: new_current}}
  end

  # ─── Private ─────────────────────────────────────────────────────────────────

  defp cycle([], _current, _direction), do: nil

  defp cycle(focusables, current, direction) do
    ids = Enum.map(focusables, fn {id, _} -> id end)
    ids = if direction == :backward, do: Enum.reverse(ids), else: ids

    case Enum.find_index(ids, &(&1 == current)) do
      nil ->
        hd(ids)

      idx ->
        next_idx = rem(idx + 1, length(ids))
        Enum.at(ids, next_idx)
    end
  end
end

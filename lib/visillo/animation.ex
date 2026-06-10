defmodule Visillo.Animation do
  @moduledoc """
  Animation system based on frame ticks.

  Sends `{:tick, frame_number}` messages to the App runner at regular
  intervals based on the configured FPS.

  Components use ticks for:
  - Animating spinners
  - Updating progress bars
  - Transitions and effects
  - Any state that changes over time
  """

  use GenServer

  @default_fps 30

  defstruct [
    :timer_ref,
    :fps,
    :frame,
    subscribers: MapSet.new()
  ]

  # ─── API ────────────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Subscribes a process to animation ticks."
  @spec subscribe(pid()) :: :ok
  def subscribe(subscriber \\ self(), server \\ __MODULE__) do
    GenServer.cast(server, {:subscribe, subscriber})
  end

  @doc "Unsubscribes a process from the ticks."
  @spec unsubscribe(pid(), GenServer.server()) :: :ok
  def unsubscribe(subscriber \\ self(), server \\ __MODULE__) do
    GenServer.cast(server, {:unsubscribe, subscriber})
  end

  @doc "Changes the tick rate in FPS."
  @spec set_fps(pos_integer(), GenServer.server()) :: :ok
  def set_fps(fps, server \\ __MODULE__) when fps > 0 do
    GenServer.cast(server, {:set_fps, fps})
  end

  @doc "Returns the current frame number."
  @spec current_frame(GenServer.server()) :: non_neg_integer()
  def current_frame(server \\ __MODULE__) do
    GenServer.call(server, :current_frame)
  end

  @doc """
  Computes the frame index for an animation cycle.

  ## Example

      # Spinner with 4 frames, at 30 FPS → ~7.5 changes/second
      frame_index(frame, 4)
  """
  @spec frame_index(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def frame_index(frame, cycle_length) do
    rem(frame, cycle_length)
  end

  # ── Spinners pre-definidos ──────────────────────────────────────────────────

  @spinners %{
    dots: ["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"],
    dots2: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"],
    line: ["-", "\\", "|", "/"],
    moon: ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"],
    clock: ["🕐", "🕑", "🕒", "🕓", "🕔", "🕕", "🕖", "🕗", "🕘", "🕙", "🕚", "🕛"],
    pulse: ["█", "▓", "▒", "░"],
    bounce: ["⠁", "⠂", "⠄", "⡀", "⢀", "⠠", "⠐", "⠈"],
    braille: ["⠋", "⠙", "⠚", "⠞", "⠖", "⠦", "⠴", "⠲", "⠳", "⠓"],
    grow: ["▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"]
  }

  @doc "Returns the spinner character for the current frame."
  @spec spinner_char(atom(), non_neg_integer()) :: String.t()
  def spinner_char(style, frame) do
    frames = Map.get(@spinners, style, @spinners.dots)
    Enum.at(frames, rem(frame, length(frames)))
  end

  @doc "Lists available spinner styles."
  @spec spinner_styles() :: [atom()]
  def spinner_styles, do: Map.keys(@spinners)

  # ─── GenServer callbacks ─────────────────────────────────────────────────────

  @impl true
  def init(opts) do
    fps = Keyword.get(opts, :fps, @default_fps)
    timer_ref = schedule_tick(fps)

    {:ok, %__MODULE__{fps: fps, frame: 0, timer_ref: timer_ref}}
  end

  @impl true
  def handle_cast({:subscribe, pid}, state) do
    Process.monitor(pid)
    {:noreply, %{state | subscribers: MapSet.put(state.subscribers, pid)}}
  end

  def handle_cast({:unsubscribe, pid}, state) do
    {:noreply, %{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end

  def handle_cast({:set_fps, fps}, state) do
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)
    timer_ref = schedule_tick(fps)
    {:noreply, %{state | fps: fps, timer_ref: timer_ref}}
  end

  @impl true
  def handle_call(:current_frame, _from, state) do
    {:reply, state.frame, state}
  end

  @impl true
  def handle_info(:tick, state) do
    frame = state.frame + 1

    # Enviar tick a suscriptores vivos
    {alive, dead} =
      state.subscribers
      |> MapSet.to_list()
      |> Enum.split_with(&Process.alive?/1)

    Enum.each(alive, &send(&1, {:tick, frame}))

    # Limpiar muertos
    subs = Enum.reduce(dead, MapSet.new(alive), &MapSet.delete(&2, &1))

    timer_ref = schedule_tick(state.fps)
    {:noreply, %{state | frame: frame, subscribers: subs, timer_ref: timer_ref}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # ─── Private ─────────────────────────────────────────────────────────────────

  defp schedule_tick(fps) do
    interval = div(1000, fps)
    Process.send_after(self(), :tick, interval)
  end
end

defmodule Visillo.App do
  @moduledoc """
  Main orchestrator of the TUI session.

  Starts the `RuntimeSupervisor` with all subsystems, obtains their PIDs,
  and runs the event loop until the user exits.

  The App state holds the PIDs of all subsystems so that
  calls do not depend on global names (avoids conflicts
  between consecutive sessions).
  """

  alias Alaja.Buffer

  alias Visillo.{
    Layout,
    Screen,
    Animation,
    Theme,
    Focus,
    RuntimeSupervisor
  }

  alias Visillo.Render.Renderer

  # ── Estado ────────────────────────────────────────────────────────────────────

  defstruct [
    # módulo raíz del componente
    :module,
    # estado del componente raíz
    :component_state,
    :theme,
    :width,
    :height,
    :focused_id,
    :config,
    # PIDs de los subsistemas (no nombres globales)
    :sup,
    :screen,
    :focus,
    :event_bus,
    :animation,
    :router,
    frame: 0,
    dirty: true
  ]

  # ── API pública ───────────────────────────────────────────────────────────────

  @spec run(module(), keyword()) :: {:ok, term()} | {:error, term()}
  def run(root_module, opts) do
    props = Keyword.get(opts, :props, [])
    theme_name = Keyword.get(opts, :theme, :default)
    refresh_rate = Keyword.get(opts, :refresh_rate, 30)
    alt_screen = Keyword.get(opts, :alt_screen, true)
    mouse = Keyword.get(opts, :mouse, true)
    title = Keyword.get(opts, :title)
    quit_keys = opts |> Keyword.get(:quit_keys, ["q", "ctrl+c"]) |> normalise_quit_keys()
    focus_keys = Keyword.get(opts, :focus_keys, [])

    theme =
      case Theme.load(theme_name) do
        {:ok, t} -> t
        {:error, _} -> Theme.default()
      end

    case root_module.init(props) do
      {:error, reason} ->
        {:error, {:init_failed, reason}}

      {:ok, initial_state} ->
        config = %{
          refresh_rate: refresh_rate,
          alt_screen: alt_screen,
          mouse: mouse,
          title: title,
          quit_keys: quit_keys,
          focus_keys: focus_keys
        }

        run_session(root_module, initial_state, theme, config)
    end
  end

  @spec stop(pid() | atom()) :: :ok
  def stop(app \\ __MODULE__) do
    pid = if is_atom(app), do: Process.whereis(app), else: app
    if pid && Process.alive?(pid), do: send(pid, {:input, {:quit, :stop}})
    :ok
  end

  # ── Sesión ───────────────────────────────────────────────────────────────────

  defp run_session(root_module, initial_state, theme, config) do
    # Registrar con nombre para poder hacer stop/0 desde fuera.
    # Si ya existe (sesión anterior que no limpió), desregistrar primero.
    case Process.whereis(__MODULE__) do
      nil -> :ok
      old -> if Process.alive?(old), do: :ok, else: Process.unregister(__MODULE__)
    end

    try do
      Process.register(self(), __MODULE__)
    rescue
      # ya registrado y vivo — no es un problema
      _ -> :ok
    end

    Process.flag(:trap_exit, true)
    install_terminal_guard(config)

    result =
      try do
        # Arrancar el supervisor (sin nombre global — evita conflictos)
        {:ok, sup_pid} =
          RuntimeSupervisor.start_link(
            app_pid: self(),
            refresh_rate: config.refresh_rate,
            alt_screen: config.alt_screen,
            mouse: config.mouse,
            quit_keys: config.quit_keys,
            focus_keys: config.focus_keys
          )

        # Obtener PIDs de todos los hijos del supervisor
        pids = children_pids(sup_pid)

        if config.title, do: Screen.set_title(config.title)

        # Obtener dimensiones reales (raw mode ya activo)
        {w, h} = Screen.size(pids.screen)

        # Suscribir el App a los ticks de animación
        # IMPORTANTE: subscriber = self() (App PID), server = pids.animation (PID, no nombre global)
        Animation.subscribe(self(), pids.animation)

        # Notificar dimensiones reales al componente
        initial_state =
          case root_module.handle_resize(w, h, initial_state) do
            {:ok, s} -> s
            _ -> initial_state
          end

        state = %__MODULE__{
          module: root_module,
          component_state: initial_state,
          theme: theme,
          width: w,
          height: h,
          focused_id: nil,
          config: config,
          sup: sup_pid,
          screen: pids.screen,
          focus: pids.focus,
          event_bus: pids.event_bus,
          animation: pids.animation,
          router: pids.router
        }

        state = setup_subscriptions(state)

        # Register root component with Focus if it is focusable
        state =
          if root_module.focusable?() do
            Focus.register(:root, 0, state.focus)
            %{state | focused_id: :root}
          else
            state
          end

        state = render_if_dirty(state)

        event_loop(state)
      rescue
        e ->
          emergency_restore(config)
          {:error, {:exception, e, __STACKTRACE__}}
      catch
        :exit, reason ->
          emergency_restore(config)
          {:error, {:exit, reason}}
      end

    result
  end

  @doc false
  @spec children_pids(pid()) :: %{
          screen: pid() | nil,
          focus: pid() | nil,
          event_bus: pid() | nil,
          animation: pid() | nil,
          router: pid() | nil,
          input: pid() | nil
        }
  def children_pids(sup_pid) do
    children = Supervisor.which_children(sup_pid)
    find_pid = &find_child_pid(children, &1)

    %{
      screen: find_pid.(Visillo.Screen),
      focus: find_pid.(Visillo.Focus),
      event_bus: find_pid.(Visillo.EventBus),
      animation: find_pid.(Visillo.Animation),
      router: find_pid.(Visillo.EventRouter),
      input: find_pid.(Visillo.Input)
    }
  end

  defp find_child_pid(children, mod) do
    case Enum.find(children, fn {id, _, _, _} -> id == mod end) do
      {_, pid, _, _} when is_pid(pid) -> pid
      _ -> nil
    end
  end

  # ── Event loop ────────────────────────────────────────────────────────────────

  defp event_loop(state) do
    receive do
      {:input, {:key, key, mods}} ->
        state |> handle_key(key, mods) |> render_if_dirty() |> event_loop()

      {:input, {:mouse, event}} ->
        state |> handle_mouse(event) |> render_if_dirty() |> event_loop()

      {:input, {:resize, w, h}} ->
        state |> handle_resize(w, h) |> render_if_dirty() |> event_loop()

      {:input, {:paste, text}} ->
        state |> dispatch_update({:paste, text}) |> render_if_dirty() |> event_loop()

      {:input, :focus_next} ->
        state |> handle_focus_change(:next) |> render_if_dirty() |> event_loop()

      {:input, :focus_prev} ->
        state |> handle_focus_change(:prev) |> render_if_dirty() |> event_loop()

      {:input, {:quit, reason}} ->
        do_quit(state, reason)

      {:tick, frame} ->
        tick_state =
          try do
            %{state | frame: frame}
            |> handle_tick(frame)
          rescue
            e ->
              :logger.warning("[Visillo] handle_tick error: #{inspect(e)}")
              state
          end

        render_if_dirty(tick_state) |> event_loop()

      {:bus_event, topic, event} ->
        state |> dispatch_update({:bus_event, topic, event}) |> render_if_dirty() |> event_loop()

      {:send_msg, message} ->
        state |> dispatch_update(message) |> render_if_dirty() |> event_loop()

      {:EXIT, _pid, :normal} ->
        event_loop(state)

      {:EXIT, _pid, reason} ->
        emergency_restore(state.config)
        {:error, {:child_died, reason}}

      _unknown ->
        event_loop(state)
    after
      div(1000, state.config.refresh_rate) ->
        event_loop(state)
    end
  end

  # ── Handlers de eventos ───────────────────────────────────────────────────────

  defp handle_key(state, key, mods) do
    result = state.module.handle_key(key, mods, state.component_state)
    handle_component_result(state, result)
  end

  defp handle_mouse(state, event) do
    result = state.module.handle_mouse(event, state.component_state)
    handle_component_result(state, result)
  end

  defp handle_resize(state, w, h) do
    Screen.force_redraw(state.screen)

    new_cs =
      case state.module.handle_resize(w, h, state.component_state) do
        {:ok, s} -> s
        _ -> state.component_state
      end

    %{state | width: w, height: h, component_state: new_cs, dirty: true}
  end

  defp handle_tick(state, frame) do
    case state.module.handle_tick(frame, state.component_state) do
      {:ok, new_cs} -> %{state | component_state: new_cs, dirty: true}
      :noop -> state
    end
  end

  defp handle_focus_change(state, direction) do
    case state.module.handle_blur(state.component_state) do
      {:ok, new_cs} ->
        state = %{state | component_state: new_cs}
        state

      _ ->
        state
    end
    |> then(fn st ->
      new_id =
        case direction do
          :next -> GenServer.call(st.focus, :next)
          :prev -> GenServer.call(st.focus, :previous)
        end

      %{st | focused_id: new_id, dirty: true}
    end)
    |> then(fn st ->
      case st.module.handle_focus(st.component_state) do
        {:ok, new_cs} -> %{st | component_state: new_cs}
        _ -> st
      end
    end)
  end

  @doc false
  @spec handle_component_result(map(), term()) :: map()
  def handle_component_result(state, :ignore), do: state

  def handle_component_result(state, {:send, msg}), do: dispatch_update(state, msg)

  def handle_component_result(state, {:quit, reason}) do
    send(self(), {:input, {:quit, reason}})
    state
  end

  def handle_component_result(state, _), do: state

  # ── Update / comandos ─────────────────────────────────────────────────────────

  @doc false
  @spec dispatch_update(map(), term()) :: map()
  def dispatch_update(state, message) do
    case state.module.update(message, state.component_state) do
      {:ok, new_cs} ->
        %{state | component_state: new_cs, dirty: true}
        |> setup_subscriptions()

      {:ok, new_cs, command} ->
        %{state | component_state: new_cs, dirty: true}
        |> setup_subscriptions()
        |> execute_command(command)

      {:error, _} ->
        state
    end
  end

  @doc false
  @spec execute_command(map(), term()) :: map()
  def execute_command(state, {:quit, reason}) do
    send(self(), {:input, {:quit, reason}})
    state
  end

  def execute_command(state, {:focus, id}) do
    GenServer.cast(state.focus, {:set, id})
    %{state | focused_id: id, dirty: true}
  end

  def execute_command(state, {:publish, topic, event}) do
    GenServer.cast(state.event_bus, {:publish, topic, event})
    state
  end

  def execute_command(state, {:copy, text}) do
    Screen.copy_to_clipboard(text)
    state
  end

  def execute_command(state, {:after, ms, message}) do
    Process.send_after(self(), {:send_msg, message}, ms)
    state
  end

  def execute_command(state, {:engine_run, commands, opts}) do
    case Arrea.run(commands, opts) do
      {:ok, _} -> state
      _ -> state
    end
  end

  def execute_command(state, _), do: state

  # ── Render ────────────────────────────────────────────────────────────────────

  defp render_if_dirty(%{dirty: false} = state), do: state

  defp render_if_dirty(state) do
    try do
      {w, h} = Screen.size(state.screen)

      widget_tree = state.module.render(state.component_state, state.theme)
      laid_out = Layout.compute(widget_tree, w, h)

      buffer =
        Buffer.new(w, h)
        |> then(
          &Renderer.render(laid_out, &1, state.theme,
            frame: state.frame,
            focused_id: state.focused_id
          )
        )

      state = %{state | dirty: false}
      Screen.render(state.screen, buffer)
      position_cursor(state)
    rescue
      e ->
        :logger.warning("[Visillo] Render error: #{inspect(e)}")
        %{state | dirty: false}
    end
  end

  defp position_cursor(state) do
    pos =
      try do
        state.module.cursor(state.component_state)
      rescue
        _ -> nil
      end

    case pos do
      {col, row} when is_integer(col) and is_integer(row) and col >= 0 and row >= 0 ->
        IO.write("\e[#{row + 1};#{col + 1}H\e[?25h")

      _ ->
        IO.write("\e[?25l")
    end
  end

  # ── Subscriptions ─────────────────────────────────────────────────────────────

  defp setup_subscriptions(state) do
    topics = state.module.subscriptions(state.component_state)

    Enum.each(topics, fn topic ->
      GenServer.cast(state.event_bus, {:subscribe, topic, self()})
    end)

    state
  end

  # ── Quit ──────────────────────────────────────────────────────────────────────

  defp do_quit(state, reason) do
    try do
      state.module.cleanup(state.component_state)
    rescue
      _ -> :ok
    end

    # Detener el supervisor y todos sus hijos para evitar fugas de procesos
    try do
      Supervisor.stop(state.sup, :normal)
    rescue
      _ -> :ok
    end

    {:ok, reason}
  end

  # ── Cleanup de emergencia ─────────────────────────────────────────────────────

  defp install_terminal_guard(config) do
    app_pid = self()

    spawn(fn ->
      ref = Process.monitor(app_pid)

      receive do
        {:DOWN, ^ref, :process, ^app_pid, _} ->
          emergency_restore(config)
      end
    end)
  end

  defp emergency_restore(config) do
    try do
      IO.write(IO.ANSI.reset())
      IO.write("\e[?1006l\e[?1002l\e[?1000l\e[?1004l\e[?2004l\e[?25h")
      if Map.get(config, :alt_screen, true), do: IO.write("\e[?1049l")
      :io.setopts(:standard_io, [:echo, :icanon])
    rescue
      _ -> :ok
    end
  end

  # ── Helpers ───────────────────────────────────────────────────────────────────

  @doc false
  @spec normalise_quit_keys([String.t()]) :: [String.t()]
  def normalise_quit_keys(keys) do
    Enum.map(keys, fn key ->
      key |> String.downcase() |> String.split("+") |> Enum.sort() |> Enum.join("+")
    end)
  end
end

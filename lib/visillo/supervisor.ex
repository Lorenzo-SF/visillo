defmodule Visillo.RuntimeSupervisor do
  @moduledoc """
  Supervisor for the active TUI session.

  Uses `:rest_for_one` with children registered under unique session names,
  generated on each `start_link/1`. This avoids name conflicts between
  consecutive sessions (the usual problem when a session crashes and
  the next one tries to register the same names).

  ```
  RuntimeSupervisor  (:rest_for_one)
  ├── Screen         (buffer + diff renderer)
  ├── Focus          (Tab/Shift+Tab focus manager)
  ├── EventBus       (inter-component pub/sub)
  ├── Animation      (frame ticks)
  ├── EventRouter    (priority routing)
  └── Input          (raw mode stdin capture)
  ```
  """

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    # Sin nombre global: cada sesión tiene su propio supervisor anónimo.
    # Esto evita {:already_started, _} si una sesión anterior crasheó.
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl Supervisor
  def init(opts) do
    app_pid = Keyword.fetch!(opts, :app_pid)
    refresh_rate = Keyword.get(opts, :refresh_rate, 30)
    alt_screen = Keyword.get(opts, :alt_screen, true)
    mouse = Keyword.get(opts, :mouse, true)
    quit_keys = Keyword.get(opts, :quit_keys, ["q", "ctrl+c"])
    focus_keys = Keyword.get(opts, :focus_keys, [])

    # Nombres únicos de sesión basados en el PID del App.
    # Garantiza que no colisionan con sesiones anteriores aunque queden
    # nombres sin desregistrar por un crash.
    session = inspect(app_pid)
    screen_name = :"tui_screen_#{session}"
    focus_name = :"tui_focus_#{session}"
    bus_name = :"tui_bus_#{session}"
    anim_name = :"tui_anim_#{session}"
    router_name = :"tui_router_#{session}"
    input_name = :"tui_input_#{session}"

    children = [
      {Visillo.Screen, [alt_screen: alt_screen, name: screen_name]},
      {Visillo.Focus, [name: focus_name]},
      {Visillo.EventBus, [name: bus_name]},
      {Visillo.Animation, [fps: refresh_rate, name: anim_name]},
      {Visillo.EventRouter,
       [app_pid: app_pid, quit_keys: quit_keys, focus_keys: focus_keys, name: router_name]},
      {Visillo.Input, [router: router_name, mouse: mouse, name: input_name]}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end

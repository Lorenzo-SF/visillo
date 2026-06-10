defmodule Visillo.EventRouter do
  @moduledoc """
  Input event router with layered priority system.

  ## Routing flow

  Every event captured by `Input` arrives here as `{:raw_input, event}`.
  The router applies the following layers in strict order:

  ```
  {:raw_input, event}
        │
        ▼
  ┌─────────────────────────────────────────────────────────┐
  │ LAYER 1 — GLOBAL (quit keys)                            │
  │                                                         │
  │ The quit_keys configured in run/1 are absolute:         │
  │ no component can "steal" them. If the event             │
  │ matches → {:input, {:quit, :user}} to App. STOP.        │
  │                                                         │
  │ Examples: "q", "ctrl+c", "ctrl+q"                       │
  └──────────────────────┬──────────────────────────────────┘
                         │ not consumed
                         ▼
  ┌─────────────────────────────────────────────────────────┐
  │ LAYER 2 — SYSTEM (focus management)                     │
  │                                                         │
  │ Tab  → {:input, {:focus_next}} to App                   │
  │ S+Tab → {:input, {:focus_prev}} to App                  │
  │                                                         │
  │ App updates Focus and notifies handle_blur/focus         │
  │ to the component losing/gaining focus.                  │
  └──────────────────────┬──────────────────────────────────┘
                         │ not consumed
                         ▼
  ┌─────────────────────────────────────────────────────────┐
  │ LAYER 3 — COMPONENT (App event loop)                    │
  │                                                         │
  │ The event reaches App intact as {:input, event}.        │
  │ App delivers it to the component with active focus.     │
  │                                                         │
  │ Keyboard → focused component                            │
  │ Mouse    → component under cursor (hit-testing in App)  │
  │ Paste    → focused component                            │
  │ Resize   → all components (broadcast via App)           │
  │ EOF      → {:input, {:quit, :eof}} — terminal close     │
  └─────────────────────────────────────────────────────────┘
  ```

  ## Guarantees

  - A keyboard event is consumed by EXACTLY ONE layer.
  - Mouse, paste, resize and eof events bypass layers
    1 and 2 and go directly to layer 3.
  - Quit keys cannot be overridden by components.
  - The router is stateless with respect to component state —
    it only knows quit_keys and the App PID.
  """

  use GenServer

  @enforce_keys [:app_pid, :quit_keys]
  defstruct [:app_pid, :quit_keys, :focus_keys]

  # ── API ───────────────────────────────────────────────────────────────────────

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  # ── GenServer callbacks ───────────────────────────────────────────────────────

  @impl GenServer
  def init(opts) do
    app_pid = Keyword.fetch!(opts, :app_pid)
    quit_keys = opts |> Keyword.get(:quit_keys, ["q", "ctrl+c"]) |> MapSet.new()
    focus_keys = opts |> Keyword.get(:focus_keys, []) |> MapSet.new()

    {:ok, %__MODULE__{app_pid: app_pid, quit_keys: quit_keys, focus_keys: focus_keys}}
  end

  @impl GenServer
  def handle_info({:raw_input, event}, state) do
    route(event, state)
    {:noreply, state}
  end

  # resize llega del poller de Resize directamente como {:input, {:resize, w, h}}
  def handle_info({:input, {:resize, _, _}} = msg, state) do
    send(state.app_pid, msg)
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # ── Routing ───────────────────────────────────────────────────────────────────

  # EOF — cierre del terminal
  defp route(:eof, state) do
    to_app(state, {:quit, :eof})
  end

  # Ratón, paste y resize van directamente al App (bypass capas 1 y 2)
  defp route({:mouse, _} = event, state), do: to_app(state, event)
  defp route({:paste, _} = event, state), do: to_app(state, event)
  defp route({:resize, _, _} = event, state), do: to_app(state, event)

  # Teclado — aplica las tres capas en orden
  defp route({:key, key, mods} = event, state) do
    key_str = key_to_string(key, mods)

    cond do
      # ── Capa 1: global (quit keys) ─────────────────────────────────────────
      MapSet.member?(state.quit_keys, key_str) ->
        to_app(state, {:quit, :user})

      # ── Capa 2: sistema (foco) ─────────────────────────────────────────────
      # Solo intercepta Tab si está en focus_keys (configurable por demo).
      # focus_keys: [] → Tab pasa al componente; focus_keys: ["tab"] → Tab mueve foco.
      MapSet.member?(state.focus_keys, "tab") and key == "tab" and mods == [] ->
        to_app(state, :focus_next)

      MapSet.member?(state.focus_keys, "tab") and key == "tab" and mods == [:shift] ->
        to_app(state, :focus_prev)

      # ── Capa 3: componente ─────────────────────────────────────────────────
      true ->
        to_app(state, event)
    end
  end

  defp route(_unknown, _state), do: :ok

  defp to_app(state, event), do: send(state.app_pid, {:input, event})

  # Normaliza {key, mods} a string canónico comparable con quit_keys.
  # Los modificadores se ordenan para que "ctrl+shift+c" == "shift+ctrl+c".
  # Ejemplos:
  #   key="c", mods=[:ctrl]        → "ctrl+c"
  #   key="q", mods=[]             → "q"
  #   key="c", mods=[:shift,:ctrl] → "ctrl+shift+c"
  defp key_to_string(key, []), do: key

  defp key_to_string(key, mods) do
    prefix =
      mods
      |> Enum.map(&to_string/1)
      |> Enum.sort()
      |> Enum.join("+")

    "#{prefix}+#{key}"
  end
end

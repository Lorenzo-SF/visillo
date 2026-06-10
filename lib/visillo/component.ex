defmodule Visillo.Component do
  @moduledoc """
  Base behaviour for declarative TUI components.

  Follows The Elm Architecture: Model (state), Update (messages), View (render).

  ## Usage

      defmodule MyCounter do
        use Visillo.Component

        defstruct [:count]

        @impl true
        def init(_props), do: {:ok, %__MODULE__{count: 0}}

        @impl true
        def focusable?, do: true

        @impl true
        def handle_key("+", _mods, _state), do: {:send, :inc}
        def handle_key("q", _mods, _state), do: {:quit, :user}
        def handle_key(_, _, _), do: :ignore

        @impl true
        def update(:inc, state), do: {:ok, %{state | count: state.count + 1}}

        @impl true
        def render(state, _theme) do
          box(border: :rounded, title: "Counter") do
            text("Count: \#{state.count}")
          end
        end
      end

  ## Required callbacks

    * `init/1` — Initializes the component state
    * `render/2` — Returns the widget tree for the current state

  ## Optional callbacks (with defaults)

    * `update/2` — Handles messages
    * `handle_key/3` — Handles keyboard events
    * `handle_mouse/2` — Handles mouse events
    * `handle_resize/3` — Handles terminal resize
    * `handle_focus/1` — Component gains focus
    * `handle_blur/1` — Component loses focus
    * `handle_tick/2` — Animation tick (frame_number, state)
    * `cleanup/1` — Cleanup on unmount
    * `focusable?/0` — Whether it accepts focus (default: false)
    * `subscriptions/1` — Subscriptions to EventBus topics
  """

  # ─── Callbacks ──────────────────────────────────────────────────────────────

  @doc "Initializes the component state from props."
  @callback init(props :: keyword()) :: {:ok, state :: term()} | {:error, reason :: term()}

  @doc "Renders the component to a widget tree."
  @callback render(state :: term(), theme :: map()) :: Visillo.Widget.t()

  @doc """
  Handles a message and returns the new state.

  Can return:
    * `{:ok, new_state}` — updates state
    * `{:ok, new_state, command}` — updates and executes command
    * `{:error, reason}` — error (state unchanged)
  """
  @callback update(message :: term(), state :: term()) ::
              {:ok, new_state :: term()}
              | {:ok, new_state :: term(), command :: term()}
              | {:error, reason :: term()}

  @doc """
  Handles a keyboard event. Returns:
    * `:ignore` — unhandled event
    * `{:send, message}` — send message to `update/2`
    * `{:quit, reason}` — quit the application
  """
  @callback handle_key(key :: String.t(), modifiers :: [atom()], state :: term()) ::
              :ignore
              | {:send, message :: term()}
              | {:quit, reason :: term()}

  @doc "Handles a mouse event."
  @callback handle_mouse(event :: map(), state :: term()) ::
              :ignore | {:send, message :: term()}

  @doc "Handles a terminal resize event."
  @callback handle_resize(width :: pos_integer(), height :: pos_integer(), state :: term()) ::
              {:ok, new_state :: term()}

  @doc "Called when the component gains focus."
  @callback handle_focus(state :: term()) :: {:ok, new_state :: term()}

  @doc "Called when the component loses focus."
  @callback handle_blur(state :: term()) :: {:ok, new_state :: term()}

  @doc "Animation tick. `frame` is the global frame number."
  @callback handle_tick(frame :: non_neg_integer(), state :: term()) ::
              {:ok, new_state :: term()} | :noop

  @doc "Called when the component is unmounted."
  @callback cleanup(state :: term()) :: :ok

  @doc """
  Returns the visible text cursor position in screen coordinates.

  Use it in components that have a text field or editing area.
  Returns `{col, row}` (0-indexed) or `nil` if no cursor is visible.

  The App uses this information to position the physical terminal cursor.
  """
  @callback cursor(state :: term()) :: {non_neg_integer(), non_neg_integer()} | nil

  @doc "Returns true if the component accepts keyboard focus."
  @callback focusable?() :: boolean()

  @doc """
  Subscriptions to EventBus topics.

  Returns a list of topics the component wants to subscribe to.
  Messages arrive as `{:bus_event, topic, event}` to `update/2`.
  """
  @callback subscriptions(state :: term()) :: [atom()]

  @optional_callbacks update: 2,
                      handle_key: 3,
                      handle_mouse: 2,
                      handle_resize: 3,
                      handle_focus: 1,
                      handle_blur: 1,
                      handle_tick: 2,
                      cleanup: 1,
                      cursor: 1,
                      focusable?: 0,
                      subscriptions: 1

  # ─── Macro `use` ────────────────────────────────────────────────────────────

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour Visillo.Component

      import Visillo.DSL

      # ── Defaults opcionales ────────────────────────────────────────

      @impl true
      def update(_msg, state), do: {:ok, state}

      @impl true
      def handle_key(_key, _mods, _state), do: :ignore

      @impl true
      def handle_mouse(_event, _state), do: :ignore

      @impl true
      def handle_resize(_w, _h, state), do: {:ok, state}

      @impl true
      def handle_focus(state), do: {:ok, state}

      @impl true
      def handle_blur(state), do: {:ok, state}

      @impl true
      def handle_tick(_frame, state), do: {:ok, state}

      @impl true
      def cleanup(_state), do: :ok

      @impl true
      def cursor(_state), do: nil

      @impl true
      def focusable?, do: false

      @impl true
      def subscriptions(_state), do: []

      defoverridable update: 2,
                     handle_key: 3,
                     handle_mouse: 2,
                     handle_resize: 3,
                     handle_focus: 1,
                     handle_blur: 1,
                     handle_tick: 2,
                     cleanup: 1,
                     cursor: 1,
                     focusable?: 0,
                     subscriptions: 1
    end
  end
end

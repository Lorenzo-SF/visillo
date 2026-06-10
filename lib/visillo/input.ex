defmodule Visillo.Input do
  @moduledoc """
  Terminal input capture using native OTP 28 raw mode.

  ## Mechanism

  OTP 28 introduced `:shell.start_interactive({:noshell, :raw})` as the official API
  to activate raw mode on the terminal. Unlike `:io.setopts/2` (which operates
  on Erlang's IO server and fails in Mix tasks), this function activates raw mode
  at the TTY driver level via `prim_tty`, the same internal mechanism used by
  the Erlang shell.

  Once activated:
  - Terminal echo is disabled
  - Line buffering (`icanon`) is disabled
  - `IO.getn/2` returns immediately when data is available
  - ANSI sequences (arrows, mouse) arrive complete in a single read

  ## Architecture

      :shell.start_interactive({:noshell, :raw})
                │
      reader_loop (proceso hijo)
          │ IO.getn("", 1024) — devuelve chunk de bytes
          ▼
      Input (GenServer)
          │ acumula buffer, parsea Keyboard/Mouse
          ▼
      EventRouter (nombre registrado)

  ## Cleanup

  In `terminate/2`, `:shell.start_interactive({:noshell, :cooked})` is called
  to restore normal terminal mode. Additionally, the Mix task registers a
  `System.at_exit/1` as a safety net in case of abrupt shutdown.

  ## Requirements

  OTP 28.0 or higher. NOT compatible with OTP 27 or earlier.
  """

  use GenServer, restart: :transient

  alias Visillo.Event.{Keyboard, Mouse, Resize}

  # Tiempo máximo esperando el resto de una secuencia de escape incompleta
  @esc_timeout_ms 50

  @enforce_keys [:router]
  defstruct [
    # nombre o PID del EventRouter
    :router,
    # PID del proceso hijo que lee stdin
    :reader_pid,
    # referencia del timer de ESC pendiente
    :esc_timer_ref,
    :mouse_enabled,
    buffer: <<>>,
    # Buffer para acumular bytes UTF-8 multi-byte hasta String.valid?/1
    utf8_buf: <<>>,
    in_paste: false,
    paste_buffer: <<>>
  ]

  # ── API pública ───────────────────────────────────────────────────────────────

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec enable_mouse() :: :ok
  def enable_mouse do
    IO.write("\e[?1000h\e[?1002h\e[?1006h")
    :ok
  end

  @spec disable_mouse() :: :ok
  def disable_mouse do
    IO.write("\e[?1006l\e[?1002l\e[?1000l")
    :ok
  end

  @spec enable_focus_events() :: :ok
  def enable_focus_events,
    do:
      (
        IO.write("\e[?1004h")
        :ok
      )

  @spec disable_focus_events() :: :ok
  def disable_focus_events,
    do:
      (
        IO.write("\e[?1004l")
        :ok
      )

  @spec enable_bracketed_paste() :: :ok
  def enable_bracketed_paste,
    do:
      (
        IO.write("\e[?2004h")
        :ok
      )

  @spec disable_bracketed_paste() :: :ok
  def disable_bracketed_paste,
    do:
      (
        IO.write("\e[?2004l")
        :ok
      )

  @doc """
  Activa raw mode en el terminal usando la API oficial de OTP 28.
  Requiere OTP >= 28.0.
  """
  @spec enable_raw_mode() :: :ok | {:error, term()}
  def enable_raw_mode do
    # Deshabilitar control de flujo por software (Ctrl+S/Ctrl+Q) para que
    # esas combinaciones lleguen a la aplicación como teclas normales.
    System.cmd("stty", ["-ixon"], stderr_to_stdout: true)
    :shell.start_interactive({:noshell, :raw})
  end

  @doc """
  Restaura el terminal a cooked mode.
  Útil para limpieza manual en caso de cierre abrupto desde el Mix task.
  """
  @spec restore_terminal() :: :ok | {:error, term()}
  def restore_terminal do
    :shell.start_interactive({:noshell, :cooked})
  end

  # ── GenServer ─────────────────────────────────────────────────────────────────

  @impl GenServer
  def init(opts) do
    router = Keyword.get(opts, :router, Visillo.EventRouter)
    mouse = Keyword.get(opts, :mouse, true)

    # ── Raw mode nativo OTP 28 ──────────────────────────────────────────────
    # :shell.start_interactive({:noshell, :raw}) es la API oficial introducida
    # en OTP 28 (PR #8962). Activa raw mode en el terminal usando prim_tty,
    # el mismo mecanismo del shell de Erlang. Funciona en Mix tasks, escripts,
    # mix run, e iex (cuando no hay un shell previo iniciado).
    #
    # A diferencia de :io.setopts/2, esta función opera a nivel del driver TTY
    # mediante ioctl, por lo que el cambio es efectivo independientemente de
    # cómo esté configurado el IO server de Erlang.
    case enable_raw_mode() do
      :ok ->
        :ok

      {:error, reason} ->
        :logger.error("[Visillo.Input] raw mode failed: #{inspect(reason)}")
        {:stop, {:raw_mode_failed, reason}}
    end

    if mouse do
      enable_mouse()
      enable_focus_events()
    end

    enable_bracketed_paste()
    Resize.install_handler(router)
    Process.flag(:trap_exit, true)

    reader_pid = spawn_link(__MODULE__, :reader_loop, [self()])

    {:ok,
     %__MODULE__{
       router: router,
       reader_pid: reader_pid,
       mouse_enabled: mouse
     }}
  end

  # ── Mensajes del proceso lector ───────────────────────────────────────────────

  @impl GenServer
  def handle_info({:tty_data, byte}, state) do
    state = state |> cancel_esc_timer() |> process_byte(byte)
    {:noreply, state}
  end

  def handle_info({:tty_chunk, data}, state) do
    # Procesar un chunk completo de bytes (enviado por reader_loop)
    # para evitar inundar el mailbox con mensajes individuales.
    state = cancel_esc_timer(state)

    state =
      for <<byte::binary-1 <- data>>, reduce: state do
        acc -> process_byte(acc, byte)
      end

    {:noreply, state}
  end

  def handle_info({:tty_closed}, state) do
    dispatch(state, :eof)
    {:stop, :normal, state}
  end

  def handle_info({:tty_error, reason}, state) do
    :logger.warning("[Visillo.Input] stdin error: #{inspect(reason)}")
    {:noreply, state}
  end

  def handle_info(:esc_timeout, state) do
    state = flush_escape(%{state | esc_timer_ref: nil})
    {:noreply, state}
  end

  def handle_info({:EXIT, pid, :normal}, %{reader_pid: pid} = state) do
    dispatch(state, :eof)
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, pid, reason}, %{reader_pid: pid} = state) do
    :logger.error("[Visillo.Input] reader died: #{inspect(reason)}")
    {:stop, {:reader_died, reason}, state}
  end

  def handle_info({:EXIT, _pid, _reason}, state), do: {:noreply, state}
  def handle_info(_msg, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, state) do
    do_cleanup(state)
    :ok
  end

  # ── Proceso lector ────────────────────────────────────────────────────────────

  @doc false
  def reader_loop(input_pid) do
    case IO.getn("", 1024) do
      :eof ->
        send(input_pid, {:tty_closed})

      {:error, reason} ->
        send(input_pid, {:tty_error, reason})

      data when is_binary(data) and data != "" ->
        # Enviar chunks completos en lugar de byte a byte para evitar
        # inundar el mailbox del GenServer con miles de mensajes.
        # El GenServer procesa el chunk completo en process_chunk/2.
        send(input_pid, {:tty_chunk, data})
        reader_loop(input_pid)

      _ ->
        reader_loop(input_pid)
    end
  end

  # ── Cleanup ───────────────────────────────────────────────────────────────────

  defp do_cleanup(state) do
    disable_bracketed_paste()

    if state.mouse_enabled do
      disable_focus_events()
      disable_mouse()
    end

    restore_terminal()
    IO.write("\e[?25h\e[0m")
  rescue
    _ -> :ok
  end

  # ── ESC timer ─────────────────────────────────────────────────────────────────
  #
  # NOTA: Con raw mode nativo las secuencias de escape llegan completas en un
  # mismo chunk de IO.getn (ej: "\e[A" aparece completo, no byte a byte).
  # El timer sigue siendo útil como safety net para secuencias que queden
  # truncadas por límites de buffer.

  defp schedule_esc_timer(state) do
    ref = Process.send_after(self(), :esc_timeout, @esc_timeout_ms)
    %{state | esc_timer_ref: ref}
  end

  defp cancel_esc_timer(%{esc_timer_ref: nil} = state), do: state

  defp cancel_esc_timer(%{esc_timer_ref: ref} = state) do
    Process.cancel_timer(ref)
    %{state | esc_timer_ref: nil}
  end

  defp flush_escape(%{buffer: <<>>} = state), do: state

  defp flush_escape(%{buffer: <<27>>} = state) do
    # Solo ESC → tecla Escape
    dispatch(state, {:key, "escape", []})
    %{state | buffer: <<>>, utf8_buf: <<>>}
  end

  defp flush_escape(%{buffer: buf} = state) do
    state2 = parse_and_dispatch(buf, state)
    %{state2 | buffer: <<>>, utf8_buf: <<>>}
  end

  # ── Procesamiento byte a byte ─────────────────────────────────────────────────

  defp process_byte(%{in_paste: true} = state, byte) do
    buf = state.paste_buffer <> byte

    if String.ends_with?(buf, "\e[201~") do
      text_len = byte_size(buf) - byte_size("\e[201~")
      text = binary_part(buf, 0, text_len)
      dispatch(state, {:paste, text})
      %{state | in_paste: false, paste_buffer: <<>>}
    else
      %{state | paste_buffer: buf}
    end
  end

  defp process_byte(state, byte) do
    buf = state.buffer <> byte

    cond do
      # Inicio de bracketed paste
      buf == "\e[200~" ->
        %{state | buffer: <<>>, in_paste: true, paste_buffer: <<>>}

      # El byte forma parte de una secuencia de escape → acumular + timer
      String.starts_with?(buf, "\e") ->
        state
        |> Map.put(:buffer, buf)
        |> schedule_esc_timer()

      # ── UTF-8 multi-byte: acumular hasta String.valid?/1 ──────────
      # La reader_loop envía bytes individuales. Los caracteres UTF-8
      # multi-byte (ñ=2B, €=3B, emoji=4B) llegan byte a byte y deben
      # acumularse en utf8_buf hasta formar un String válido.
      utf8_in_progress?(state, byte) ->
        new_utf8 = state.utf8_buf <> byte

        if String.valid?(new_utf8) do
          # Carácter UTF-8 completo → parsear y despachar
          state = %{state | utf8_buf: <<>>}
          state2 = parse_and_dispatch(new_utf8, state)
          %{state2 | buffer: <<>>}
        else
          # Aún faltan bytes → seguir acumulando
          %{state | utf8_buf: new_utf8}
        end

      # Byte normal (ASCII) → parsear y despachar inmediatamente
      true ->
        state2 = parse_and_dispatch(buf, state)
        %{state2 | buffer: <<>>}
    end
  end

  # ¿Estamos en medio de una secuencia UTF-8 multi-byte?
  # Si ya tenemos bytes acumulados (utf8_buf != <<>>) O el byte actual
  # es el inicio de una secuencia multi-byte (0xC2..0xF4).
  defp utf8_in_progress?(%{utf8_buf: buf}, _byte) when buf != <<>>, do: true
  defp utf8_in_progress?(_, <<byte>>) when byte >= 0xC2 and byte <= 0xF4, do: true
  defp utf8_in_progress?(_, _), do: false

  # ── Parseo y despacho ─────────────────────────────────────────────────────────

  defp parse_and_dispatch(buf, state) do
    cond do
      String.starts_with?(buf, "\e[<") ->
        handle_sgr_mouse(buf, state)

      String.starts_with?(buf, "\e[M") and byte_size(buf) >= 6 ->
        handle_x10_mouse(buf, state)

      String.starts_with?(buf, "\e") ->
        handle_escape_sequence(buf, state)

      true ->
        handle_normal_char(buf, state)
    end
  end

  defp handle_sgr_mouse(buf, state) do
    case extract_sgr_mouse(buf) do
      {:ok, event, rest} ->
        dispatch(state, {:mouse, event})
        forward_remaining(state, rest)

      :incomplete ->
        %{state | buffer: buf}
    end
  end

  defp handle_x10_mouse(buf, state) do
    <<_::binary-size(3), b, x, y, rest::binary>> = buf

    case Mouse.parse(<<"\e[M", b, x, y>>) do
      {:ok, event} ->
        dispatch(state, {:mouse, event})
        forward_remaining(state, rest)

      {:error, _} ->
        state
    end
  end

  defp forward_remaining(state, <<>>), do: state
  defp forward_remaining(state, rest), do: process_byte(state, rest)

  defp handle_escape_sequence(buf, state) do
    case Keyboard.parse(buf) do
      {:key, _, _} = event -> dispatch(state, event)
      {:unknown, _} -> :ok
    end

    state
  end

  defp handle_normal_char(buf, state) do
    case Keyboard.parse(buf) do
      {:key, _, _} = event -> dispatch(state, event)
      {:unknown, _} -> :ok
    end

    state
  end

  # ── SGR mouse ─────────────────────────────────────────────────────────────────

  defp extract_sgr_mouse(bytes) do
    sz = byte_size(bytes)

    case :binary.match(bytes, ["M", "m"], scope: {3, sz - 3}) do
      :nomatch ->
        :incomplete

      {pos, 1} ->
        seq = binary_part(bytes, 0, pos + 1)
        rest = binary_part(bytes, pos + 1, sz - pos - 1)

        case Mouse.parse(seq) do
          {:ok, event} -> {:ok, event, rest}
          {:error, _} -> :incomplete
        end
    end
  end

  # ── Despacho al EventRouter ───────────────────────────────────────────────────

  defp dispatch(state, event) do
    send(state.router, {:raw_input, event})
  end
end

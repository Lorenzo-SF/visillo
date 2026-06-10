defmodule Visillo.Event.Keyboard do
  @moduledoc """
  Parses VT100/xterm/kitty keyboard sequences into normalized events.

  Produces `{:key, key_name, modifiers}` tuples where:
    - `key_name`  :: String.t()  — canonical key name
    - `modifiers` :: [atom()]    — list of active modifiers

  ## Canonical key names

  Special keys: "escape", "enter", "tab", "backspace", "delete",
  "insert", "home", "end", "page_up", "page_down", "up", "down",
  "left", "right", "f1".."f12", "space"

  Printable characters: the character itself ("a", "A", "ñ", "€"...)

  Ctrl+letter keys: the letter name ("a".."z") with :ctrl modifier

  ## Modifiers

  `:ctrl`, `:alt`, `:shift`, `:meta`
  """

  import Bitwise

  @type key_name :: String.t()
  @type modifiers :: [:ctrl | :alt | :shift | :meta]
  @type key_event :: {:key, key_name(), modifiers()}

  # ── Secuencias de escape → {tecla, modificadores} ───────────────────────────

  # Tabla de secuencias CSI/SS3 conocidas.
  # Formato: {secuencia_binaria, key_name, modificadores_base}
  @sequences [
    # Flechas — ANSI estándar
    {"\e[A", "up", []},
    {"\e[B", "down", []},
    {"\e[C", "right", []},
    {"\e[D", "left", []},
    # Flechas — SS3 (vt100)
    {"\eOA", "up", []},
    {"\eOB", "down", []},
    {"\eOC", "right", []},
    {"\eOD", "left", []},
    # Navegación
    {"\e[H", "home", []},
    {"\e[F", "end", []},
    {"\eOH", "home", []},
    {"\eOF", "end", []},
    {"\e[1~", "home", []},
    {"\e[4~", "end", []},
    {"\e[2~", "insert", []},
    {"\e[3~", "delete", []},
    {"\e[5~", "page_up", []},
    {"\e[6~", "page_down", []},
    # Teclas de función — xterm
    {"\eOP", "f1", []},
    {"\eOQ", "f2", []},
    {"\eOR", "f3", []},
    {"\eOS", "f4", []},
    {"\e[11~", "f1", []},
    {"\e[12~", "f2", []},
    {"\e[13~", "f3", []},
    {"\e[14~", "f4", []},
    {"\e[15~", "f5", []},
    {"\e[17~", "f6", []},
    {"\e[18~", "f7", []},
    {"\e[19~", "f8", []},
    {"\e[20~", "f9", []},
    {"\e[21~", "f10", []},
    {"\e[23~", "f11", []},
    {"\e[24~", "f12", []},
    # Flechas con modificadores — formato CSI 1;Nm
    {"\e[1;2A", "up", [:shift]},
    {"\e[1;2B", "down", [:shift]},
    {"\e[1;2C", "right", [:shift]},
    {"\e[1;2D", "left", [:shift]},
    {"\e[1;3A", "up", [:alt]},
    {"\e[1;3B", "down", [:alt]},
    {"\e[1;3C", "right", [:alt]},
    {"\e[1;3D", "left", [:alt]},
    {"\e[1;5A", "up", [:ctrl]},
    {"\e[1;5B", "down", [:ctrl]},
    {"\e[1;5C", "right", [:ctrl]},
    {"\e[1;5D", "left", [:ctrl]},
    {"\e[1;7A", "up", [:ctrl, :alt]},
    {"\e[1;7B", "down", [:ctrl, :alt]},
    {"\e[1;7C", "right", [:ctrl, :alt]},
    {"\e[1;7D", "left", [:ctrl, :alt]},
    # Tab / Shift+Tab
    {"\t", "tab", []},
    {"\e[Z", "tab", [:shift]},
    # Enter
    {"\r", "enter", []},
    {"\n", "enter", []},
    # Espacio
    {" ", "space", []},
    # Backspace (ASCII 127 y ASCII 8)
    {"\x7F", "backspace", []},
    {"\b", "backspace", []},
    # Focus events
    {"\e[I", "focus_in", []},
    {"\e[O", "focus_out", []}
  ]

  # Construir mapa en tiempo de compilación para O(1) lookup
  @seq_map Map.new(@sequences, fn {seq, key, mods} -> {seq, {key, mods}} end)

  # ── API pública ──────────────────────────────────────────────────────────────

  @doc """
  Parses a raw binary sequence into a keyboard event.

  Returns:
    * `{:key, name, mods}` — recognized event
    * `{:unknown, bytes}` — unrecognized sequence (silently ignore)
  """
  @spec parse(binary()) :: key_event() | {:unknown, binary()}
  def parse(bytes) when is_binary(bytes) do
    case Map.get(@seq_map, bytes) do
      {key, mods} -> {:key, key, mods}
      nil -> parse_raw(bytes)
    end
  end

  @doc """
  Formats a keyboard event to a human-readable string.

  ## Examples

      iex> format({:key, "a", [:ctrl]})
      "Ctrl+a"

      iex> format({:key, "up", []})
      "↑"
  """
  @spec format(key_event()) :: String.t()
  def format({:key, key, mods}) do
    mod_str = Enum.map_join(mods, "+", &mod_label/1)
    key_str = display_key(key)
    if mod_str == "", do: key_str, else: "#{mod_str}+#{key_str}"
  end

  # ── Parseo de secuencias no tabuladas ────────────────────────────────────────

  # Ctrl + letra (bytes 1..26 → Ctrl+a..Ctrl+z)
  defp parse_raw(<<byte>>) when byte >= 1 and byte <= 26 do
    {:key, <<byte + ?a - 1>>, [:ctrl]}
  end

  # Ctrl+Space (byte 0)
  defp parse_raw(<<0>>), do: {:key, "space", [:ctrl]}

  # Escape solo (byte 27 sin secuencia adicional)
  defp parse_raw(<<27>>), do: {:key, "escape", []}

  # Ctrl+\ Ctrl+] Ctrl+^ Ctrl+_
  defp parse_raw(<<28>>), do: {:key, "\\", [:ctrl]}
  defp parse_raw(<<29>>), do: {:key, "]", [:ctrl]}
  defp parse_raw(<<30>>), do: {:key, "^", [:ctrl]}
  defp parse_raw(<<31>>), do: {:key, "_", [:ctrl]}

  # Delete (127) — ya tabulado, pero por si acaso
  defp parse_raw(<<127>>), do: {:key, "backspace", []}

  # Alt + tecla: ESC seguido de algo
  defp parse_raw(<<27, rest::binary>>) when byte_size(rest) >= 1 do
    case parse(rest) do
      {:key, k, mods} -> {:key, k, [:alt | mods]}
      other -> other
    end
  end

  # Secuencia CSI con modificador numérico: \e[1;Nm{dir}
  defp parse_raw(<<"\e[1;", rest::binary>>) do
    parse_csi_modifier(rest)
  end

  # Carácter ASCII imprimible
  defp parse_raw(<<byte>> = bytes) when byte >= 32 and byte <= 126 do
    {:key, bytes, []}
  end

  # UTF-8 multibyte (carácter imprimible)
  defp parse_raw(bytes) when byte_size(bytes) > 1 do
    if String.valid?(bytes) do
      {:key, bytes, []}
    else
      {:unknown, bytes}
    end
  end

  defp parse_raw(bytes), do: {:unknown, bytes}

  # ── CSI modifier ─────────────────────────────────────────────────────────────

  # Mapa de código numérico → modificadores (formato xterm)
  @csi_mod_map %{
    "2" => [:shift],
    "3" => [:alt],
    "4" => [:shift, :alt],
    "5" => [:ctrl],
    "6" => [:ctrl, :shift],
    "7" => [:ctrl, :alt],
    "8" => [:ctrl, :shift, :alt]
  }

  @csi_dir_map %{"A" => "up", "B" => "down", "C" => "right", "D" => "left"}

  defp parse_csi_modifier(rest) do
    case Regex.run(~r/^(\d+)([A-D])$/, rest) do
      [_, mod_code, dir] ->
        mods = Map.get(@csi_mod_map, mod_code, [])
        key = Map.get(@csi_dir_map, dir, dir)
        {:key, key, mods}

      _ ->
        {:unknown, <<"\e[1;", rest::binary>>}
    end
  end

  # ── Helpers de visualización ──────────────────────────────────────────────────

  defp mod_label(:ctrl), do: "Ctrl"
  defp mod_label(:alt), do: "Alt"
  defp mod_label(:shift), do: "Shift"
  defp mod_label(:meta), do: "Meta"

  defp display_key("up"), do: "↑"
  defp display_key("down"), do: "↓"
  defp display_key("left"), do: "←"
  defp display_key("right"), do: "→"
  defp display_key("enter"), do: "↵"
  defp display_key("tab"), do: "⇥"
  defp display_key("backspace"), do: "⌫"
  defp display_key("delete"), do: "Del"
  defp display_key("escape"), do: "Esc"
  defp display_key("space"), do: "Space"
  defp display_key("page_up"), do: "PgUp"
  defp display_key("page_down"), do: "PgDn"
  defp display_key("home"), do: "Home"
  defp display_key("end"), do: "End"
  defp display_key(k), do: k
end

defmodule Visillo.Event.Mouse do
  @moduledoc """
  Parses SGR and X10 mouse sequences into normalized events.

  Supports:
    * **SGR** (recommended): `\\e[<B;X;YM` (press/drag) and `\\e[<B;X;Ym` (release)
    * **X10** (basic): `\\e[M bxy` (3-byte payload)
  """

  import Bitwise

  @type button :: :left | :middle | :right | :scroll_up | :scroll_down | :none
  @type action :: :press | :release | :move | :drag | :scroll
  @type modifiers :: [:shift | :alt | :ctrl]

  @type t :: %{
          button: button(),
          action: action(),
          x: non_neg_integer(),
          y: non_neg_integer(),
          modifiers: modifiers()
        }

  @doc """
  Parses a mouse binary sequence.

  Returns `{:ok, event}` or `{:error, :unknown}`.
  """
  @spec parse(binary()) :: {:ok, t()} | {:error, :unknown}
  def parse(bytes)

  # SGR: \e[<B;X;YM (press) o \e[<B;X;Ym (release)
  def parse(<<"\e[<", rest::binary>>) do
    with [b_str, x_str, y_str_with_action] <- String.split(rest, ";", parts: 3),
         {b, ""} <- Integer.parse(b_str),
         {x, ""} <- Integer.parse(x_str),
         <<y_str::binary-size(byte_size(y_str_with_action) - 1), action_byte>> <-
           y_str_with_action,
         {y, ""} <- Integer.parse(y_str),
         action_char when action_char in [?M, ?m] <- action_byte do
      decode_sgr(b, x - 1, y - 1, action_char)
    else
      _ -> {:error, :unknown}
    end
  end

  # X10: \e[M b x y
  def parse(<<"\e[M", b, x, y>>) when b >= 32 do
    decode_x10(b - 32, x - 32, y - 32)
  end

  def parse(_), do: {:error, :unknown}

  # ── Decodificación SGR ───────────────────────────────────────────────────────

  defp decode_sgr(b, x, y, action_byte) do
    mods = decode_mods(b)

    {button, action} =
      cond do
        # Scroll wheel: bits 6 set
        band(b, 64) != 0 ->
          btn = if band(b, 1) == 0, do: :scroll_up, else: :scroll_down
          {btn, :scroll}

        # Motion / drag: bit 5 set
        band(b, 32) != 0 ->
          btn = decode_button(band(b, 3))
          act = if btn == :none, do: :move, else: :drag
          {btn, act}

        # Press / release
        true ->
          btn = decode_button(band(b, 3))
          act = if action_byte == ?M, do: :press, else: :release
          {btn, act}
      end

    {:ok, %{button: button, action: action, x: x, y: y, modifiers: mods}}
  end

  # ── Decodificación X10 ───────────────────────────────────────────────────────

  defp decode_x10(b, x, y) when x >= 0 and y >= 0 do
    mods = decode_mods(b)
    button = decode_button(band(b, 3))
    {:ok, %{button: button, action: :press, x: x, y: y, modifiers: mods}}
  end

  defp decode_x10(_, _, _), do: {:error, :unknown}

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp decode_button(0), do: :left
  defp decode_button(1), do: :middle
  defp decode_button(2), do: :right
  defp decode_button(3), do: :none
  defp decode_button(_), do: :none

  defp decode_mods(b) do
    []
    |> then(fn m -> if band(b, 4) != 0, do: [:shift | m], else: m end)
    |> then(fn m -> if band(b, 8) != 0, do: [:alt | m], else: m end)
    |> then(fn m -> if band(b, 16) != 0, do: [:ctrl | m], else: m end)
  end
end

defmodule Visillo.Event.Resize do
  @moduledoc """
  Terminal resize detection.

  Uses `stty size` which operates on the controlling terminal regardless
  of whether stdin is a tty or a pipe (Mix context case).
  """

  @doc """
  Returns the current terminal dimensions as `{width, height}`.
  """
  @spec current_size() :: {pos_integer(), pos_integer()}
  def current_size do
    # :io.rows() y :io.columns() funcionan correctamente en OTP 26+ con raw mode activo.
    # Son la forma canónica de obtener las dimensiones del terminal en Erlang/Elixir.
    with {:ok, rows} <- :io.rows(),
         {:ok, cols} <- :io.columns(),
         true <- rows > 0 and cols > 0 do
      {cols, rows}
    else
      _ -> {80, 24}
    end
  rescue
    _ -> {80, 24}
  end

  @doc """
  Installs a resize poller that notifies `notify_pid` when the terminal
  changes size.

  The poller dies automatically when `notify_pid` dies.
  """
  @spec install_handler(pid()) :: :ok
  def install_handler(notify_pid) do
    spawn(fn ->
      Process.monitor(notify_pid)
      poll(notify_pid, current_size())
    end)

    :ok
  end

  defp poll(pid, prev_size) do
    receive do
      {:DOWN, _ref, :process, ^pid, _} -> :ok
    after
      200 ->
        size = current_size()

        if size != prev_size do
          send(pid, {:input, {:resize, elem(size, 0), elem(size, 1)}})
        end

        poll(pid, size)
    end
  end
end

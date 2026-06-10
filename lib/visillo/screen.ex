defmodule Visillo.Screen do
  @moduledoc """
  Screen manager — screen buffer, diff renderer, and ANSI output.

  Maintains two buffers:
    1. `previous` — The previous frame (for calculating the diff)
    2. The new frame arrives on each cast {:render, buffer}

  Only cells that changed between frames are sent to the terminal,
  minimizing output and eliminating flicker (diff renderer).

  Features:
    * Alternate buffer (`\\e[?1049h`) — preserves original content
    * Diff renderer — only writes modified cells
    * Run-length encoding — groups consecutive cells with the same style
    * Invisible cursor during rendering
    * Automatic restoration on exit (even on exceptions)
  """

  use GenServer

  alias Alaja.{Buffer, Cell}

  @hide_cursor "\e[?25l"
  @show_cursor "\e[?25h"
  @alt_screen_on "\e[?1049h"
  @alt_screen_off "\e[?1049l"
  @clear_screen "\e[2J"
  @home "\e[H"

  defstruct [:width, :height, :previous, :alt_screen, dirty_all: true]

  # ─── API pública ─────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec render(pid() | atom(), Buffer.t()) :: :ok
  def render(pid \\ __MODULE__, buffer), do: GenServer.cast(pid, {:render, buffer})

  @spec force_redraw(pid() | atom()) :: :ok
  def force_redraw(pid \\ __MODULE__), do: GenServer.cast(pid, :force_redraw)

  @spec size(pid() | atom()) :: {pos_integer(), pos_integer()}
  def size(pid \\ __MODULE__), do: GenServer.call(pid, :size)

  @spec set_title(String.t()) :: :ok
  def set_title(title),
    do:
      (
        IO.write("\e]0;#{title}\a")
        :ok
      )

  @spec copy_to_clipboard(String.t()) :: :ok
  def copy_to_clipboard(text),
    do:
      (
        IO.write("\e]52;c;#{Base.encode64(text)}\a")
        :ok
      )

  @spec set_cursor_visible(boolean()) :: :ok
  def set_cursor_visible(true),
    do:
      (
        IO.write(@show_cursor)
        :ok
      )

  def set_cursor_visible(false),
    do:
      (
        IO.write(@hide_cursor)
        :ok
      )

  # ─── GenServer callbacks ──────────────────────────────────────────────────────

  @impl true
  def init(opts) do
    alt_screen = Keyword.get(opts, :alt_screen, true)
    {w, h} = terminal_size()

    if alt_screen, do: IO.write(@alt_screen_on)
    IO.write(@hide_cursor <> @clear_screen <> @home)

    {:ok,
     %__MODULE__{
       width: w,
       height: h,
       previous: Buffer.new(w, h),
       alt_screen: alt_screen,
       dirty_all: true
     }}
  end

  @impl true
  def handle_cast({:render, new_buffer}, state) do
    {w, h} = terminal_size()

    state =
      if w != state.width or h != state.height do
        %{state | width: w, height: h, previous: Buffer.new(w, h), dirty_all: true}
      else
        state
      end

    output = build_diff(state.previous, new_buffer, state.dirty_all)
    IO.write(output)

    {:noreply, %{state | previous: new_buffer, dirty_all: false}}
  end

  def handle_cast(:force_redraw, state), do: {:noreply, %{state | dirty_all: true}}

  @impl true
  def handle_call(:size, _from, state), do: {:reply, {state.width, state.height}, state}

  @impl true
  def terminate(_reason, state) do
    IO.write(IO.ANSI.reset() <> @show_cursor)
    if state.alt_screen, do: IO.write(@alt_screen_off)
    :ok
  end

  # ─── Diff renderer ────────────────────────────────────────────────────────────

  # Calcula el diff entre dos buffers y produce iodata ANSI optimizado.
  # Solo escribe las celdas que cambiaron (o todas si force_all es true).
  @doc false
  def build_diff(prev, curr, force_all) do
    max_y = min(prev.height, curr.height) - 1
    max_x = min(prev.width, curr.width) - 1

    if max_y < 0 or max_x < 0 do
      []
    else
      # Construimos la salida como iolist para eficiencia, luego reset final
      rows = build_rows(prev, curr, 0, max_y, max_x, force_all)
      [rows, IO.ANSI.reset()]
    end
  end

  # Itera filas (tail-recursive mediante reduce)
  defp build_rows(prev, curr, start_y, max_y, max_x, force) do
    Enum.reduce(start_y..max_y//1, [], fn y, acc ->
      [build_row(prev, curr, max_x, y, force) | acc]
    end)
    |> Enum.reverse()
  end

  # Construye una fila usando reduce_while para evitar recursión profunda
  defp build_row(prev, curr, max_x, y, force) do
    segments =
      Enum.reduce_while(0..max_x//1, {[], 0}, fn
        _x, {_segments, x} when x > max_x ->
          {:halt, {[], x}}

        x, {segments, _x} ->
          curr_cell = Buffer.get(curr, x, y)
          prev_cell = if force, do: Cell.empty(), else: Buffer.get(prev, x, y)

          if Cell.equal?(curr_cell, prev_cell) do
            {:cont, {segments, x + 1}}
          else
            {run_chars, next_x} = collect_run(prev, curr, x + 1, max_x, y, force, curr_cell, [])

            move = "\e[#{y + 1};#{x + 1}H"
            cell_ansi = render_cell_with_run(curr_cell, run_chars)

            {:cont, {segments ++ [move, cell_ansi], next_x}}
          end
      end)
      |> elem(0)

    segments
  end

  # Recoge celdas cambiadas consecutivas con el mismo estilo ANSI (RLE).
  # Devuelve {lista_de_chars, next_x}.
  # IMPORTANTE: acc es una lista de strings (graphemes), NO un binario acumulado.
  defp collect_run(_prev, _curr, x, max_x, _y, _force, _base, acc) when x > max_x do
    {Enum.reverse(acc), x}
  end

  defp collect_run(prev, curr, x, max_x, y, force, base_cell, acc) do
    curr_cell = Buffer.get(curr, x, y)
    prev_cell = if force, do: Cell.empty(), else: Buffer.get(prev, x, y)

    same_style = same_style?(base_cell, curr_cell)
    changed = not Cell.equal?(curr_cell, prev_cell)

    if changed and same_style do
      # Mismo estilo y cambió: añadir a la run, guardando el char como string seguro
      safe_char = safe_char(curr_cell.char)
      collect_run(prev, curr, x + 1, max_x, y, force, base_cell, [safe_char | acc])
    else
      # Cambió de estilo o no cambió: fin de la run
      {Enum.reverse(acc), x}
    end
  end

  # Renderiza la celda base más los chars de la run como iodata ANSI
  defp render_cell_with_run(cell, extra_chars) do
    prefix = Cell.to_ansi_prefix(cell)
    base = safe_char(cell.char)
    reset = if prefix == [], do: [], else: IO.ANSI.reset()
    [prefix, base | extra_chars] ++ [reset]
  end

  # Garantiza que el char sea siempre un string binario válido.
  # Cell.char puede ser un codepoint integer en celdas creadas sin init correcto.
  defp safe_char(char) when is_binary(char), do: char

  defp safe_char(char) when is_integer(char) do
    # Convertir codepoint a UTF-8 string
    case :unicode.characters_to_binary([char]) do
      bin when is_binary(bin) -> bin
      _ -> " "
    end
  end

  defp safe_char(_), do: " "

  defp same_style?(a, b) do
    a.fg == b.fg and a.bg == b.bg and a.effects == b.effects
  end

  defp terminal_size do
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
end

defmodule Visillo.Render.Buffer do
  @moduledoc """
  Adapter between the TUI renderer and `Alaja.Buffer`.

  Provides the API that the Renderer needs on top of `Alaja.Buffer`,
  while ensuring full compatibility without duplicating implementation.

  ## Functions

    * `new/2` — Creates an empty buffer of the given dimensions
    * `put_cell/5` — Writes a cell at coordinates (x, y)
    * `get/3` — Reads a cell at coordinates (x, y)
    * `fill/8` — Fills a rectangular area with a character and style
    * `overlay/4` — Overlays one buffer on top of another

  ## Relationship to Alaja.Buffer

  This module does NOT replace `Alaja.Buffer`. It is a thin wrapper that:
    - Re-exposes functions with the naming convention used by the TUI renderer
    - Keeps full backward compatibility

  Screen uses `Alaja.Buffer` directly for diff-based rendering.
  """

  alias Alaja.{Buffer, Cell}

  @doc "Creates an empty buffer of `width` × `height`."
  @spec new(pos_integer(), pos_integer()) :: Buffer.t()
  defdelegate new(width, height), to: Buffer

  @doc """
  Writes a cell to the buffer at position `(x, y)`.

  Returns the modified buffer. If coordinates are out of range,
  returns the buffer unchanged.
  """
  @spec put_cell(Buffer.t(), non_neg_integer(), non_neg_integer(), Cell.t()) :: Buffer.t()
  def put_cell(buffer, x, y, %Cell{} = cell) do
    Buffer.update_cell(buffer, x, y, cell)
  end

  @doc "Reads the cell at `(x, y)`. Returns `Cell.empty()` if out of range."
  @spec get(Buffer.t(), non_neg_integer(), non_neg_integer()) :: Cell.t()
  defdelegate get(buffer, x, y), to: Buffer

  @doc """
  Fills a rectangular area of the buffer with the given character and style.

  Useful for clearing areas or drawing colored backgrounds.
  """
  @spec fill(
          Buffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          tuple() | nil,
          tuple() | nil
        ) :: Buffer.t()
  def fill(buffer, x, y, width, height, char \\ " ", fg \\ nil, bg \\ nil) do
    for dy <- 0..(height - 1), dx <- 0..(width - 1), reduce: buffer do
      buf ->
        cx = x + dx
        cy = y + dy

        if cx < buf.width and cy < buf.height do
          cell = Cell.new(char, fg, bg)
          Buffer.update_cell(buf, cx, cy, cell)
        else
          buf
        end
    end
  end

  @doc """
  Overlays `overlay` on top of `base` at position `(x, y)`.

  Overlay cells that are `Cell.empty()` are transparent
  (they do not overwrite the base).
  """
  @spec overlay(Buffer.t(), Buffer.t(), non_neg_integer(), non_neg_integer()) :: Buffer.t()
  def overlay(base, overlay_buf, offset_x \\ 0, offset_y \\ 0) do
    for y <- 0..(overlay_buf.height - 1),
        x <- 0..(overlay_buf.width - 1),
        reduce: base do
      buf ->
        cell = Buffer.get(overlay_buf, x, y)
        bx = offset_x + x
        by = offset_y + y

        if not Cell.equal?(cell, Cell.empty()) and bx < buf.width and by < buf.height do
          Buffer.update_cell(buf, bx, by, cell)
        else
          buf
        end
    end
  end
end

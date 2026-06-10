defmodule Visillo.Render.Border do
  @moduledoc """
  Utility for drawing borders on the buffer.
  Supports multiple border styles and optional titles.
  """

  alias Alaja.{Buffer, Cell}

  @borders %{
    none: %{tl: " ", tr: " ", bl: " ", br: " ", h: " ", v: " "},
    single: %{tl: "┌", tr: "┐", bl: "└", br: "┘", h: "─", v: "│"},
    double: %{tl: "╔", tr: "╗", bl: "╚", br: "╝", h: "═", v: "║"},
    rounded: %{tl: "╭", tr: "╮", bl: "╰", br: "╯", h: "─", v: "│"},
    bold: %{tl: "┏", tr: "┓", bl: "┗", br: "┛", h: "━", v: "┃"},
    dashed: %{tl: "┌", tr: "┐", bl: "└", br: "┘", h: "╌", v: "╎"},
    ascii: %{tl: "+", tr: "+", bl: "+", br: "+", h: "-", v: "|"}
  }

  @spec draw(Buffer.t(), map(), atom(), tuple() | nil, String.t() | nil, atom(), tuple() | nil) ::
          Buffer.t()
  def draw(buffer, rect, style, color, title \\ nil, title_align \\ :left, bg \\ nil) do
    b = Map.get(@borders, style, @borders.rounded)

    if rect.width < 2 or rect.height < 2 do
      buffer
    else
      draw_opts = %{color: color, title: title, title_align: title_align, bg: bg}
      do_draw(buffer, b, rect, draw_opts)
    end
  end

  defp do_draw(buffer, b, rect, draw_opts) do
    %{color: color, title: title, title_align: title_align, bg: bg} = draw_opts
    x = rect.x
    y = rect.y
    w = rect.width
    h = rect.height
    inner_w = w - 2

    buffer
    |> fill_background(x, y, w, h, bg)
    |> do_put_cell(x, y, b.tl, color)
    |> do_put_cell(x + w - 1, y, b.tr, color)
    |> do_put_cell(x, y + h - 1, b.bl, color)
    |> do_put_cell(x + w - 1, y + h - 1, b.br, color)
    |> then(fn buf ->
      write_row(
        buf,
        x + 1,
        y,
        inner_w,
        build_top_line(b.h, inner_w, title, title_align),
        color,
        nil
      )
    end)
    |> then(fn buf ->
      write_row(buf, x + 1, y + h - 1, inner_w, String.duplicate(b.h, inner_w), color, nil)
    end)
    |> then(fn buf ->
      Enum.reduce(1..(h - 2), buf, fn dy, acc ->
        acc
        |> do_put_cell(x, y + dy, b.v, color)
        |> do_put_cell(x + w - 1, y + dy, b.v, color)
      end)
    end)
  end

  defp fill_background(buffer, _x, _y, _w, _h, nil), do: buffer

  defp fill_background(buffer, x, y, w, h, bg) do
    Enum.reduce(1..(h - 2), buffer, fn dy, buf ->
      write_row(buf, x + 1, y + dy, w - 2, String.duplicate(" ", w - 2), nil, bg)
    end)
  end

  defp build_top_line(h_char, inner_w, nil, _align), do: String.duplicate(h_char, inner_w)

  defp build_top_line(h_char, inner_w, title, align) do
    td = " #{title} "
    tl = String.length(td)

    if tl >= inner_w do
      String.slice(td, 0, inner_w)
    else
      rem = inner_w - tl

      case align do
        :center ->
          String.duplicate(h_char, div(rem, 2)) <>
            td <> String.duplicate(h_char, rem - div(rem, 2))

        :right ->
          String.duplicate(h_char, rem) <> td

        _ ->
          td <> String.duplicate(h_char, rem)
      end
    end
  end

  defp write_row(buffer, x, y, width, content, fg, bg) do
    content
    |> String.graphemes()
    |> Enum.take(width)
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, i}, buf -> do_put_cell(buf, x + i, y, char, fg, bg) end)
  end

  defp do_put_cell(buffer, x, y, char, fg, bg \\ nil) do
    if x >= 0 and y >= 0 and x < buffer.width and y < buffer.height do
      Buffer.update_cell(buffer, x, y, Cell.new(char, fg, bg))
    else
      buffer
    end
  end

  @spec styles() :: [atom()]
  def styles, do: Map.keys(@borders)
end

defmodule Visillo.Render.TextWrap do
  @moduledoc "Text wrapping for the :paragraph widget."

  @spec wrap(String.t(), pos_integer(), atom()) :: [String.t()]
  def wrap(text, width, mode \\ :word)
  def wrap(text, _w, :none), do: String.split(text, "\n")

  def wrap(text, width, :char) do
    text
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      line |> String.graphemes() |> Enum.chunk_every(width) |> Enum.map(&Enum.join/1)
    end)
  end

  def wrap(text, width, :word) do
    text |> String.split("\n") |> Enum.flat_map(&wrap_line(&1, width))
  end

  defp wrap_line("", _w), do: [""]
  defp wrap_line(line, width), do: wrap_words(String.split(line, " "), width, [], [])

  defp wrap_words([], _w, cur, acc) do
    Enum.reverse([Enum.join(Enum.reverse(cur), " ") | acc])
  end

  defp wrap_words([word | rest], width, cur, acc) do
    current = Enum.join(Enum.reverse(cur), " ")
    tentative = if current == "", do: word, else: current <> " " <> word

    cond do
      String.length(tentative) <= width ->
        wrap_words(rest, width, [word | cur], acc)

      String.length(word) > width ->
        acc2 = if current != "", do: [current | acc], else: acc
        {chunks, tail} = break_long_word(word, width)

        wrap_words(
          rest,
          width,
          if(tail == "", do: [], else: [tail]),
          Enum.reverse(chunks) ++ acc2
        )

      true ->
        acc2 = if current != "", do: [current | acc], else: acc
        wrap_words(rest, width, [word], acc2)
    end
  end

  defp break_long_word(word, width) do
    chunks = word |> String.graphemes() |> Enum.chunk_every(width) |> Enum.map(&Enum.join/1)
    {Enum.drop(chunks, -1), List.last(chunks, "")}
  end
end

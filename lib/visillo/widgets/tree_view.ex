defmodule Visillo.Widgets.TreeView do
  @moduledoc """
  Interactive directory tree browser (TreeView).

  Renders the file and directory hierarchy with indentation,
  allows expanding/collapsing directories and selecting files.

  ## Usage as root component

      Visillo.App.run(Visillo.Widgets.TreeView,
        root: "/Users/user/projects",
        show_hidden: false
      )

  ## Usage from another component

  The parent component includes `TreeView` in its state and renders:

      def render(state, theme) do
        TreeView.render(state.tree, theme)
      end

  ## Events

    * `{:file_selected, path}` — Enter on a file
    * `{:dir_expanded, path}` — Directory expanded
    * `{:dir_collapsed, path}` — Directory collapsed
    * `{:selection_changed, idx, path}` — Selection changed
  """

  use Visillo.Component

  @type entry :: %{
          depth: non_neg_integer(),
          type: :dir | :file | :link,
          name: String.t(),
          path: String.t(),
          expanded: boolean()
        }

  defstruct [
    :root_path,
    :entries,
    :selected,
    :scroll_offset,
    :show_hidden,
    :focused
  ]

  # ── Behaviour callbacks ─────────────────────────────────────────────────────

  @doc """
  Creates a new TreeView state from props.

  ## Props

    * `root` — Root path to explore (required, default: ".")
    * `show_hidden` — Show hidden files (default: false)
    * `selected` — Initial selected index (default: 0)
  """
  @impl true
  @spec init(keyword()) :: {:ok, %__MODULE__{}}
  def init(props) do
    root = Keyword.get(props, :root, ".")
    show_hidden = Keyword.get(props, :show_hidden, false)
    selected = Keyword.get(props, :selected, 0)

    root = Path.expand(root)

    entries = build_entries(root, 0, show_hidden)

    {:ok,
     %__MODULE__{
       root_path: root,
       entries: entries,
       selected: min(selected, max(length(entries) - 1, 0)),
       scroll_offset: 0,
       show_hidden: show_hidden,
       focused: false
     }}
  end

  @impl true
  @spec focusable?() :: true
  def focusable?, do: true

  @impl true
  @spec handle_focus(map()) :: {:ok, map()}
  def handle_focus(state), do: {:ok, %{state | focused: true}}

  @impl true
  @spec handle_blur(map()) :: {:ok, map()}
  def handle_blur(state), do: {:ok, %{state | focused: false}}

  @impl true
  @spec handle_key(String.t(), list(), map()) ::
          :ignore | {:send, term()} | {:ok, map()} | {:quit, term()}
  def handle_key("up", [], state) do
    new_idx = max(state.selected - 1, 0)
    scroll = compute_scroll(new_idx, state.scroll_offset, 20)
    {:ok, %{state | selected: new_idx, scroll_offset: scroll}}
  end

  def handle_key("down", [], state) do
    new_idx = min(state.selected + 1, length(state.entries) - 1)
    scroll = compute_scroll(new_idx, state.scroll_offset, 20)
    {:ok, %{state | selected: new_idx, scroll_offset: scroll}}
  end

  def handle_key("enter", [], state) do
    entry = Enum.at(state.entries, state.selected)

    if entry do
      case entry.type do
        :dir ->
          if entry.expanded do
            {:send, {:dir_collapsed, entry.path}}
          else
            {:send, {:dir_expanded, entry.path}}
          end

        :file ->
          {:send, {:file_selected, entry.path}}

        :link ->
          {:send, {:file_selected, entry.path}}
      end
    else
      :ignore
    end
  end

  def handle_key("right", [], %{entries: entries, selected: selected}) do
    entry = Enum.at(entries, selected)

    if entry && entry.type == :dir && !entry.expanded do
      {:send, {:dir_expanded, entry.path}}
    else
      :ignore
    end
  end

  def handle_key("left", [], %{entries: entries, selected: selected}) do
    entry = Enum.at(entries, selected)

    if entry && entry.type == :dir && entry.expanded do
      {:send, {:dir_collapsed, entry.path}}
    else
      :ignore
    end
  end

  def handle_key("home", [], state) do
    {:ok, %{state | selected: 0, scroll_offset: 0}}
  end

  def handle_key("end", [], state) do
    new_idx = length(state.entries) - 1
    {:ok, %{state | selected: max(new_idx, 0), scroll_offset: max(new_idx - 20, 0)}}
  end

  def handle_key("page_up", [], state) do
    new_idx = max(state.selected - 20, 0)
    {:ok, %{state | selected: new_idx, scroll_offset: max(new_idx - 5, 0)}}
  end

  def handle_key("page_down", [], state) do
    new_idx = min(state.selected + 20, length(state.entries) - 1)
    {:ok, %{state | selected: new_idx, scroll_offset: max(new_idx - 15, 0)}}
  end

  def handle_key(_, _, _), do: :ignore

  # ── Update handlers ────────────────────────────────────────────

  @impl true
  @spec update(term(), map()) :: {:ok, map()}
  def update({:dir_expanded, path}, state) do
    entries = expand_dir(state.entries, path, state.show_hidden)
    {:ok, %{state | entries: entries}}
  end

  def update({:dir_collapsed, path}, state) do
    entries = collapse_dir(state.entries, path)
    selected = min(state.selected, length(entries) - 1)
    {:ok, %{state | entries: entries, selected: selected}}
  end

  def update(_, state), do: {:ok, state}

  # ── Render ─────────────────────────────────────────────────────

  @impl true
  @spec render(map(), map()) :: Visillo.Widget.t()
  def render(state, _theme) do
    visible = Enum.slice(state.entries, state.scroll_offset, 20)

    box(border: :none, direction: :column) do
      visible
      |> Enum.with_index()
      |> Enum.map(fn {entry, i} ->
        abs_idx = state.scroll_offset + i
        is_selected = abs_idx == state.selected

        render_entry(entry, is_selected, state.focused)
      end)
    end
  end

  defp render_entry(entry, is_selected, focused) do
    indent = String.duplicate("  ", entry.depth)
    icon = entry_icon(entry)
    expanded_marker = entry_expanded_marker(entry)

    display = "#{indent}#{expanded_marker}#{icon}#{entry.name}"

    cond do
      is_selected and focused ->
        text(display, color: :background, bg: :foreground, bold: true)

      is_selected ->
        text(display, color: :background, bg: :focus_bg)

      entry.type == :dir ->
        text(display, color: :primary)

      true ->
        text(display, color: :foreground)
    end
  end

  defp entry_icon(%{type: :dir}), do: "[D] "
  defp entry_icon(%{type: :link}), do: "[L] "
  defp entry_icon(_), do: "    "

  defp entry_expanded_marker(%{type: :dir, expanded: true}), do: "- "
  defp entry_expanded_marker(%{type: :dir, expanded: false}), do: "+ "
  defp entry_expanded_marker(_), do: "  "

  # ── Build / expand / collapse ──────────────────────────────────

  @doc false
  @spec build_entries(String.t(), non_neg_integer(), boolean()) :: [map()]
  def build_entries(path, depth, show_hidden) do
    case File.ls(path) do
      {:ok, names} ->
        names
        |> Enum.reject(fn n -> !show_hidden and String.starts_with?(n, ".") end)
        |> Enum.sort()
        |> Enum.flat_map(fn name ->
          full_path = Path.join(path, name)

          type =
            cond do
              File.dir?(full_path) -> :dir
              true -> :file
            end

          # Always add self
          entry = %{
            depth: depth,
            type: type,
            name: name,
            path: full_path,
            expanded: false
          }

          [entry]
        end)

      {:error, _} ->
        [
          %{
            depth: depth,
            type: :file,
            name: "(error reading: #{path})",
            path: path,
            expanded: false
          }
        ]
    end
  end

  @doc false
  @spec expand_dir([map()], String.t(), boolean()) :: [map()]
  def expand_dir(entries, path, show_hidden) do
    {before, after_incl} = split_at_path(entries, path)

    case after_incl do
      [dir | rest] ->
        children = build_entries(dir.path, dir.depth + 1, show_hidden)
        before ++ [%{dir | expanded: true}] ++ children ++ rest

      [] ->
        entries
    end
  end

  @doc false
  @spec collapse_dir([map()], String.t()) :: [map()]
  def collapse_dir(entries, path) do
    {before, after_incl} = split_at_path(entries, path)

    case after_incl do
      [dir | rest] ->
        # Remove all children until we find an entry with depth <= dir.depth
        remaining = drop_children(rest, dir.depth)
        before ++ [%{dir | expanded: false}] ++ remaining

      [] ->
        entries
    end
  end

  defp split_at_path(entries, path) do
    idx = Enum.find_index(entries, fn e -> e.path == path end)

    if idx do
      {Enum.take(entries, idx), Enum.drop(entries, idx)}
    else
      {entries, []}
    end
  end

  defp drop_children(entries, parent_depth) do
    Enum.drop_while(entries, fn e -> e.depth > parent_depth end)
  end

  defp compute_scroll(selected, scroll, viewport) do
    cond do
      selected < scroll -> selected
      selected >= scroll + viewport -> selected - viewport + 1
      true -> scroll
    end
  end
end

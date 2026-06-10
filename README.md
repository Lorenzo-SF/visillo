# Visillo — Declarative TUI Framework for Elixir

[![Elixir](https://img.shields.io/badge/Elixir-%7E%3E%201.19-purple)](https://elixir-lang.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.md)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/Lorenzo-SF/visillo)

Visillo is a declarative framework for building interactive Terminal User Interfaces (TUIs) in Elixir. It follows The Elm Architecture (TEA) — Model, Update, View — with a composable widget DSL, flexbox layout engine, diff-based rendering, keyboard/mouse events, animations, and a built-in theme system.

> **Ecosystem**: Visillo builds on three sibling libraries:
> - **[Alaja](https://github.com/lorenzo-sf/alaja)** — terminal cell buffer, ANSI drivers, and rendering primitives (`Buffer`, `Cell`, ANSI, Printer)
> - **[Pote](https://github.com/lorenzo-sf/pote)** — color parsing, harmonies, gradients, and palettes
> - **[Arrea](https://github.com/lorenzo-sf/arrea)** — process orchestration for parallel workloads

## Quick Start

```elixir
defmodule MyApp.TUI do
  use Visillo.Component

  defstruct [:count]

  @impl true
  def init(_props), do: {:ok, %__MODULE__{count: 0}}

  @impl true
  def focusable?, do: true

  @impl true
  def handle_key("+", [], state), do: {:send, :increment}
  def handle_key("-", [], state), do: {:send, :decrement}
  def handle_key("q",  [], _state), do: {:quit, :user}
  def handle_key(_, _, _), do: :ignore

  @impl true
  def update(:increment, state), do: {:ok, %{state | count: state.count + 1}}
  def update(:decrement, state), do: {:ok, %{state | count: state.count - 1}}

  @impl true
  def render(state, theme) do
    box(border: :rounded, title: "Counter", title_align: :center) do
      [
        text("Count: #{state.count}", bold: true, color: theme.primary, align: :center),
        separator(),
        text("Press + / - to count, q to quit", color: :info, align: :center, italic: true)
      ]
    end
  end
end

Visillo.App.run(MyApp.TUI, theme: :default)
```

## Features

- **Declarative Widget DSL** — compose UIs with `box`, `text`, `button`, `input`, `list`, `table`, `tabs`, `menu`, `modal`, `chart`, `tree_view`, `split_pane`, `panel`, and more
- **Composite Widget Library** — pre-built interactive components: `Tabs`, `TreeView`, `SplitPane`, `TextInput`, `Button`, `Checkbox`, `Label`, `Panel` — each usable as a standalone component or embedded in another
- **Flexbox Layout Engine** — column, row, grid, scroll containers with `flex_grow`, `flex_shrink`, `padding`, `margin`, and alignment
- **Focus Management** — Tab / Shift+Tab navigation across focusable components, managed by `Visillo.Focus`
- **Keyboard Events** — raw key capture with modifier detection (Ctrl, Alt, Shift), ANSI escape sequence parsing, and three-layer routing (global → system → component)
- **Mouse Events** — SGR mouse protocol support for click, drag, and scroll events
- **Animation System** — frame-based tick engine with 9 built-in spinner styles (`:dots`, `:line`, `:moon`, `:clock`, `:pulse`, `:bounce`, `:braille`, `:grow`, `:dots2`) and support for custom frame sequences
- **Theme System** — 6 built-in themes (default, dracula, tokyo_night, gruvbox, catppuccin, nord) with semantic color palette (primary, secondary, success, error, warning, info, focus, border, etc.)
- **Diff Renderer** — compares consecutive frame buffers and emits only changed cells with run-length encoding for minimal ANSI output and zero flicker
- **Component Lifecycle** — init → render → update → cleanup, with optional `handle_key`, `handle_mouse`, `handle_resize`, `handle_focus`, `handle_blur`, `handle_tick`, and `subscriptions` callbacks
- **Event Bus** — pub/sub for decoupled inter-component communication
- **Rich Text** — color, background, bold, italic, underline, strikethrough, dim effects, text alignment, and truncation
- **The Elm Architecture** — ready for implementing the elm-watch style of development
- **Mix Task Demos** — 8 built-in demo applications accessible via Mix tasks

## Architecture

```
Visillo.App.run/2
  │
  ├── Visillo.RuntimeSupervisor (:rest_for_one)
  │   ├── Visillo.Screen         (GenServer — buffer + diff renderer)
  │   ├── Visillo.Focus          (GenServer — Tab/Shift+Tab navigation)
  │   ├── Visillo.EventBus       (GenServer — pub/sub inter-component)
  │   ├── Visillo.Animation      (GenServer — frame ticks at configurable FPS)
  │   ├── Visillo.EventRouter    (GenServer — 3-layer input routing)
  │   └── Visillo.Input          (GenServer — raw stdin capture, ANSI parsing)
  │
  ├── Visillo.Layout             (flexbox engine with constraint solving)
  │   └── Visillo.Layout.Constraint  (width, height, flex, margin, padding)
  │
  ├── Visillo.Render.Renderer    (pure functions: widget tree → Alaja.Buffer)
  │   ├── Visillo.Render.Border  (box drawing: rounded, single, double, bold, ascii)
  │   └── Visillo.Render.TextWrap    (word wrap and char wrap)
  │
  ├── Visillo.Theme              (color palette and ANSI helpers)
  ├── Visillo.Widget             (widget descriptor struct)
  ├── Visillo.DSL                (macro-based declarative syntax)
  └── Visillo.Component          (behaviour + default callbacks)
```

### Event Flow

```
stdin → Visillo.Input (byte-by-byte raw mode)
           │
           ▼
      Visillo.EventRouter
           │
           ├── Layer 1: GLOBAL (quit keys: "q", "ctrl+c")
           ├── Layer 2: SYSTEM  (Tab → focus_next, Shift+Tab → focus_prev)
           └── Layer 3: COMPONENT → handle_key/3 or handle_mouse/2
                    │
                    ▼
              Visillo.App (event loop + state management)
                    │
                    ├── update/2  (messages: {:send, msg})
                    ├── render/2  (state, theme → widget tree)
                    │       │
                    │       ▼
                    │   Visillo.Layout.compute/3
                    │   Visillo.Render.Renderer.render/4
                    │       │
                    │       ▼
                    │   Visillo.Screen.render/2 (diff + ANSI output)
                    │
                    └── handle_tick/2 (frame animation, 30 FPS default)
```

## API Reference

### Visillo.Component

The core behaviour. `use Visillo.Component` injects `Visillo.DSL` imports and provides default implementations for all optional callbacks.

| Callback | Signature | Default |
|---|---|---|
| `init/1` | `(props) → {:ok, state} \| {:error, reason}` | **required** |
| `render/2` | `(state, theme) → Widget.t()` | **required** |
| `update/2` | `(msg, state) → {:ok, state} \| {:ok, state, cmd}` | `{:ok, state}` |
| `handle_key/3` | `(key, mods, state) → :ignore \| {:send, msg} \| {:quit, reason}` | `:ignore` |
| `handle_mouse/2` | `(event, state) → :ignore \| {:send, msg}` | `:ignore` |
| `handle_resize/3` | `(width, height, state) → {:ok, state}` | `{:ok, state}` |
| `handle_focus/1` | `(state) → {:ok, state}` | `{:ok, state}` |
| `handle_blur/1` | `(state) → {:ok, state}` | `{:ok, state}` |
| `handle_tick/2` | `(frame, state) → {:ok, state} \| :noop` | `{:ok, state}` |
| `cleanup/1` | `(state) → :ok` | `:ok` |
| `cursor/1` | `(state) → {col, row} \| nil` | `nil` |
| `focusable?/0` | `() → boolean()` | `false` |
| `subscriptions/1` | `(state) → [topic]` | `[]` |

**Commands** returned from `update/2`:
- `{:quit, reason}` — exit the application
- `{:focus, id}` — set focus to a specific component
- `{:publish, topic, event}` — publish to the EventBus
- `{:copy, text}` — copy text to system clipboard
- `{:after, ms, message}` — delayed message to self
- `{:engine_run, commands, opts}` — run parallel tasks via Arrea

### Visillo.DSL (Widget DSL)

#### Containers

| Widget | Description |
|---|---|
| `box(opts, do: children)` | Container with optional border (`:rounded`, `:single`, `:double`, `:bold`, `:ascii`, `:none`), title, padding, and direction (`:column` / `:row`) |
| `grid(opts, do: children)` | Grid layout with configurable columns and gap |
| `scroll_view(opts, do: children)` | Scrollable container with `scroll_x` / `scroll_y` offsets |

#### Display

| Widget | Description |
|---|---|
| `text(content, opts)` | Single-line text with color, effects, alignment, and truncation |
| `paragraph(content, opts)` | Multi-line text with word/char wrapping and max_lines |
| `image(path, opts)` | Terminal image rendering via kitty/iterm2/sixel/ascii protocols |
| `raw(content)` | Escape hatch — writes raw ANSI content directly |

#### Interactive

| Widget | Description |
|---|---|
| `button(label, opts)` | Clickable button with variant (`:primary`, `:secondary`, `:danger`, `:ghost`), keyboard shortcut, and icon |
| `input(opts)` | Text input field with placeholder, password masking, label, max_length, on_change, and on_submit |
| `list(items, opts)` | Scrollable selectable list with custom render_item, on_select, and on_confirm |
| `table(headers, rows, opts)` | Interactive table with header highlighting, row selection, and border styles |
| `menu(items, opts)` | Dropdown menu with open/close state and on_select |
| `tabs(tab_list, opts)` | Tab navigation with content switching on_change |
| `file_browser(path, opts)` | Interactive file system browser with icons and preview |

#### Navigation

| Widget | Description |
|---|---|
| `breadcrumbs(path, opts)` | Navigation breadcrumbs with configurable separator and dimmed ancestors |
| `stepper(steps, current, opts)` | Multi-step wizard with step indicators, connectors, and labels |

#### Feedback

| Widget | Description |
|---|---|
| `progress_bar(value, total, opts)` | Progress bar with label, percentage, and bar/block/dot styles |
| `spinner(opts)` | Animated loading indicator with 9 styles and optional label |
| `gauge(value, min, max, opts)` | Segmented gauge/dial indicator |
| `chart(data, opts)` | Bar charts, sparklines, and line charts with configurable colors |

#### Overlays

| Widget | Description |
|---|---|
| `modal(title, opts, do: content)` | Centered modal overlay with semi-transparent background and configurable buttons |
| `confirm(message, opts)` | Yes/No confirmation dialog with on_yes/on_no callbacks |

#### Layout

| Widget | Description |
|---|---|
| `separator(opts)` | Horizontal or vertical separator with optional centered label |
| `status_bar(left, center, right, opts)` | Fixed status bar with left/center/right content |
| `gap(size)` | Flexible spacer for distributing available space |

#### Constraint Options

All widgets accept these constraint options for the flexbox layout:

| Option | Description |
|---|---|
| `width` / `height` | Fixed dimensions |
| `min_width` / `min_height` | Minimum dimensions |
| `max_width` / `max_height` | Maximum dimensions |
| `flex` / `flex_grow` | Flex grow factor (0 = fixed, 1+ = proportional) |
| `flex_shrink` | Flex shrink factor |
| `padding` | Inner padding (integer or `{vertical, horizontal}`) |
| `margin` | Outer margin (integer or `{vertical, horizontal}`) |
| `align_self` | Override alignment: `:start`, `:center`, `:end`, `:stretch` |

### Composite Widgets (Visillo.Widgets)

Pre-built interactive components that can be used as standalone app components or embedded in other components.

| Widget | Module | Description | Focusable | Key Events |
|---|---|---|---|---|
| **Tabs** | `Visillo.Widgets.Tabs` | Interactive tab bar with content switching | Yes | Left/Right, Ctrl+Tab / Ctrl+Shift+Tab |
| **TreeView** | `Visillo.Widgets.TreeView` | File/directory tree browser with expand/collapse | Yes | Up/Down, Enter, Left/Right, Home/End, PageUp/PageDown |
| **SplitPane** | `Visillo.Widgets.SplitPane` | Split layout (horizontal/vertical) with adjustable ratio | No | — |
| **TextInput** | `Visillo.Widgets.TextInput` | Single-line text input with cursor and placeholder | Yes | Type, Backspace, Delete, Home, End, Left/Right |
| **Button** | `Visillo.Widgets.Button` | Clickable button with focus highlight | Yes | Enter, Space |
| **Checkbox** | `Visillo.Widgets.Checkbox` | Toggleable checkbox with label | Yes | Enter, Space |
| **Label** | `Visillo.Widgets.Label` | Simple text label with color and bold | No | — |
| **Panel** | `Visillo.Widgets.Panel` | Bordered container with title | No | — |

**Usage examples:**

```elixir
# Tabs: standalone component
Visillo.App.run(Visillo.Widgets.Tabs,
  tabs: [
    %{label: "Editor", content: [text("Edit here...")]},
    %{label: "Preview", content: [text("Preview here...")]}
  ]
)

# TreeView: file browser
{:ok, tree} = Visillo.Widgets.TreeView.init(root: "/home/user", show_hidden: false)

# SplitPane: embed in render
Visillo.Widgets.SplitPane.new(
  direction: :horizontal,
  first: [text("Left panel")],
  second: [text("Right panel")],
  ratio: 0.3
)

# TextInput: embedded widget
Visillo.Widgets.TextInput.new(placeholder: "Enter name...", value: "")

# Button: embedded widget
Visillo.Widgets.Button.new("Submit", on_click: :submit)

# Checkbox: embedded widget
Visillo.Widgets.Checkbox.new(label: "Enable feature", checked: false)

# Label: embedded widget
Visillo.Widgets.Label.new("Hello, World!", color: :green, bold: true)

# Panel: embedded container
Visillo.Widgets.Panel.new(title: "Status", children: [text("All systems OK")])
```

### Visillo.App

```elixir
Visillo.App.run(MyComponent, opts)
```

| Option | Default | Description |
|---|---|---|
| `:theme` | `:default` | Theme name (`:default`, `:dracula`, `:tokyo_night`, `:gruvbox`, `:catppuccin`, `:nord`) |
| `:props` | `[]` | Props passed to `init/1` |
| `:refresh_rate` | `30` | Animation FPS |
| `:alt_screen` | `true` | Use terminal alternate screen buffer |
| `:mouse` | `true` | Enable SGR mouse tracking |
| `:title` | `nil` | Terminal window title |
| `:quit_keys` | `["q", "ctrl+c"]` | Global quit keys (cannot be overridden by components) |
| `:focus_keys` | `[]` | Set to `["tab"]` to enable Tab/Shift+Tab focus navigation. If empty, Tab/Shift+Tab are NOT handled system-wide and pass through to the component. |

```elixir
Visillo.App.stop()  # gracefully stops the current session
```

### Visillo.Theme

```elixir
{:ok, theme} = Visillo.Theme.load(:dracula)
Visillo.Theme.list()          # → [:default, :dracula, :tokyo_night, :gruvbox, :catppuccin, :nord]
Visillo.Theme.color(theme, :primary)  # → {r, g, b}
Visillo.Theme.fg({100, 149, 237})     # → ANSI foreground sequence
Visillo.Theme.bg({45, 50, 70})        # → ANSI background sequence
Visillo.Theme.default()               # fallback theme
Visillo.Theme.merge(base, overrides)  # merge custom overrides
```

### Visillo.Animation

```elixir
Visillo.Animation.spinner_char(:dots, frame)  # → "⣾"
Visillo.Animation.frame_index(frame, 4)      # → 0..3 cycling
Visillo.Animation.spinner_styles()           # → [:dots, :dots2, :line, :moon, :clock, :pulse, :bounce, :braille, :grow]
Visillo.Animation.subscribe(pid)             # subscribe to ticks
Visillo.Animation.set_fps(60)                # change tick rate
```

### Visillo.Focus

```elixir
Visillo.Focus.next()       # → next focusable component id
Visillo.Focus.previous()   # → previous focusable component id
Visillo.Focus.set(:my_id)  # focus a specific component
Visillo.Focus.blur()       # remove focus
Visillo.Focus.focused?(:id) # check if focused
```

### Visillo.EventBus

```elixir
Visillo.EventBus.subscribe(:topic)              # current process
Visillo.EventBus.subscribe(:topic, some_pid)    # specific pid
Visillo.EventBus.publish(:topic, event)         # broadcast
Visillo.EventBus.unsubscribe(:topic)            # stop receiving
```

### Visillo.Screen

```elixir
Visillo.Screen.set_title("My App Title")
Visillo.Screen.copy_to_clipboard("text")
Visillo.Screen.set_cursor_visible(true)
Visillo.Screen.force_redraw()  # mark all cells dirty for full re-render
```

## Leveraging the Ecosystem

### Rendering with Alaja

Visillo's render pipeline produces `Alaja.Buffer` instances — a 2D grid of `Alaja.Cell` structs with character, foreground/background color, and effects. The `Visillo.Screen` GenServer diffs consecutive buffers and emits ANSI sequences for only the changed cells.

For custom rendering beyond the widget DSL, you can use Alaja directly:

```elixir
# Inside your component — a custom canvas-style render
@impl true
def render(state, _theme) do
  # Use raw() to inject pre-formatted ANSI content
  raw(Alaja.Cell.to_ansi(cell))
end
```

Rich text features (gradients, harmonies) come from Pote:

```elixir
# Pote colours are used throughout — theme colors are {r, g, b} tuples
handle_key("enter", [], state) do
  # Colors can be specified as atoms (looked up in theme), hex strings, or tuples
  {:send, {:show, :success}}
end
```

### Process Orchestration with Arrea

For async workloads within a TUI (file I/O, network requests, database queries), use Arrea's parallel execution:

```elixir
def update(:fetch_data, state) do
  commands = [
    fn -> {:endpoint_a, HTTPClient.get("/api/a")} end,
    fn -> {:endpoint_b, HTTPClient.get("/api/b")} end
  ]

  {:ok, state, {:engine_run, commands, workers: 2, timeout: 5000}}
end
```

Components can subscribe to `EventBus` topics to receive results asynchronously.

```elixir
@impl true
def subscriptions(_state), do: [:data_fetched]

def update({:bus_event, :data_fetched, result}, state) do
  {:ok, %{state | data: result}}
end
```

## Installation

Add `visillo` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:visillo, "~> 1.0.0"},
    # Visillo requires its sibling libraries:
    {:alaja, "~> 1.0.0"},
    {:pote,  "~> 1.0.0"},
    {:arrea, "~> 1.0.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Built-in Demos

Visillo includes 8 demo applications accessible via Mix tasks:

| Mix Task | Module | Description |
|---|---|---|
| `mix visillo.demo.chat` | `Visillo.Demo.Chat` | Interactive chat with `/` commands (help, list, multi-select, animated onboarding) |
| `mix visillo.demo.counter` | `Visillo.Demo.Counter` | Simple counter — increment/decrement/reset with keyboard |
| `mix visillo.demo.dashboard` | `Visillo.Demo.Dashboard` | System monitor (btop-like) with live CPU/memory/disk gauges, sparkline charts, process table, and tab switching |
| `mix visillo.demo.editor` | `Visillo.Demo.MicroEditor` | Micro/nano-style text editor with multi-buffer tabs, sidebar (Ctrl+E), word wrap (`wrap: true`), undo/redo, save, open file dialog |
| `mix visillo.demo.form` | `Visillo.Demo.Form` | Registration form with text fields, checkbox, and submit |
| `mix visillo.demo.installer` | `Visillo.Demo.Installer` | Multi-step wizard with stepper, form validation, spinner, progress bar, installation log |
| `mix visillo.demo.menu` | `Visillo.Demo.MenuApp` | Multi-screen menu with search filtering, breadcrumbs, list selection, detail views, config panel, help screen |
| `mix visillo.demo.unified` | `Visillo.Demo.Unified` | ALL-IN-ONE: file browser (TreeView) + editor (MicroEditor) + chat (assistant) + dashboard (system monitor) — tabbed navigation with Ctrl+Tab |

To run any demo:

```bash
mix visillo.demo.chat
mix visillo.demo.counter
mix visillo.demo.dashboard
mix visillo.demo.editor
mix visillo.demo.form
mix visillo.demo.installer
mix visillo.demo.menu
mix visillo.demo.unified
```

Or directly via `mix run`:

```bash
mix run -e 'Visillo.App.run(Visillo.Demo.MenuApp, theme: :dracula)'
mix run -e 'Visillo.App.run(Visillo.Demo.MicroEditor, theme: :tokyo_night)'
mix run -e 'Visillo.App.run(Visillo.Demo.Dashboard, theme: :catppuccin)'
mix run -e 'Visillo.App.run(Visillo.Demo.Installer, theme: :gruvbox)'
```

## License

MIT License. See [LICENSE](LICENSE).

Copyright (c) 2025 Lorenzo Sanchez

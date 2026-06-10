defmodule Visillo.WidgetTest do
  use ExUnit.Case, async: true

  alias Visillo.Widget
  alias Visillo.Layout.Constraint

  describe "Widget.new/4" do
    test "creates a widget with type and empty defaults" do
      w = Widget.new(:text)
      assert w.type == :text
      assert w.props == %{}
      assert w.children == []
      assert w.id == nil
    end

    test "creates a widget with props as keyword list" do
      w = Widget.new(:text, content: "Hello", bold: true)
      assert w.props == %{content: "Hello", bold: true}
    end

    test "creates a widget with props as map" do
      w = Widget.new(:button, %{label: "OK", variant: :primary})
      assert w.props.label == "OK"
    end

    test "creates a widget with children" do
      child = Widget.new(:text, %{content: "child"})
      parent = Widget.new(:box, %{}, [child])
      assert length(parent.children) == 1
      assert hd(parent.children).type == :text
    end

    test "filters nil children" do
      child = Widget.new(:text)
      parent = Widget.new(:box, %{}, [nil, child, nil])
      assert length(parent.children) == 1
    end

    test "flattens nested child lists" do
      c1 = Widget.new(:text)
      c2 = Widget.new(:text)
      parent = Widget.new(:box, %{}, [[c1], [c2]])
      assert length(parent.children) == 2
    end

    test "assigns id from opts" do
      w = Widget.new(:input, %{}, [], id: :my_input)
      assert w.id == :my_input
    end
  end

  describe "Widget.with_constraint/2" do
    test "applies a Constraint struct" do
      c = %Constraint{flex_grow: 1, min_height: 5}
      w = Widget.new(:text) |> Widget.with_constraint(c)
      assert w.constraint.flex_grow == 1
      assert w.constraint.min_height == 5
    end

    test "applies a keyword constraint" do
      w = Widget.new(:text) |> Widget.with_constraint(flex_grow: 2, width: 40)
      assert w.constraint.flex_grow == 2
      assert w.constraint.width == 40
    end
  end

  describe "Widget.valid_type?/1" do
    test "returns true for valid types" do
      assert Widget.valid_type?(:box)
      assert Widget.valid_type?(:text)
      assert Widget.valid_type?(:button)
      assert Widget.valid_type?(:modal)
    end

    test "returns false for invalid types" do
      refute Widget.valid_type?(:unknown)
      refute Widget.valid_type?(:div)
    end
  end
end

defmodule Visillo.DSLTest do
  use ExUnit.Case, async: true

  import Visillo.DSL
  alias Visillo.Widget

  describe "text/2" do
    test "creates a text widget" do
      w = text("Hello")
      assert w.type == :text
      assert w.props.content == "Hello"
    end

    test "applies text options" do
      w = text("Bold", bold: true, color: :primary, align: :center)
      assert w.props.bold == true
      assert w.props.color == :primary
      assert w.props.align == :center
    end

    test "extracts flex constraint" do
      w = text("x", flex: 1)
      assert w.constraint.flex_grow == 1
    end
  end

  describe "separator/1" do
    test "creates a separator widget" do
      w = separator()
      assert w.type == :separator
      assert w.props.orientation == :horizontal
    end

    test "supports vertical orientation" do
      w = separator(orientation: :vertical)
      assert w.props.orientation == :vertical
    end
  end

  describe "button/2" do
    test "creates a button with label" do
      w = button("Click me")
      assert w.type == :button
      assert w.props.label == "Click me"
      assert w.props.variant == :primary
    end

    test "supports variant option" do
      w = button("Delete", variant: :danger)
      assert w.props.variant == :danger
    end
  end

  describe "input/1" do
    test "creates an input widget" do
      w = input(value: "hello", placeholder: "type here")
      assert w.type == :input
      assert w.props.value == "hello"
      assert w.props.placeholder == "type here"
    end
  end

  describe "list/2" do
    test "creates a list widget" do
      w = list(["a", "b", "c"])
      assert w.type == :list
      assert w.props.items == ["a", "b", "c"]
      assert w.props.selected == 0
    end
  end

  describe "progress_bar/3" do
    test "creates a progress bar" do
      w = progress_bar(75, 100)
      assert w.type == :progress_bar
      assert w.props.value == 75
      assert w.props.total == 100
    end
  end

  describe "gap/1" do
    test "creates a flexible gap" do
      w = gap()
      assert w.type == :gap
      assert w.constraint.flex_grow == 1
    end

    test "creates a sized gap" do
      w = gap(2)
      assert w.props.size == 2
      assert w.constraint.min_height == 2
    end
  end

  describe "breadcrumbs/2" do
    test "creates a breadcrumbs widget" do
      w = breadcrumbs(["Home", "Items", "Detail"])
      assert w.type == :breadcrumbs
      assert w.props.path == ["Home", "Items", "Detail"]
      assert w.props.separator == " › "
    end
  end

  describe "status_bar/4" do
    test "creates a status bar" do
      w = status_bar("Left", "Center", "Right")
      assert w.type == :status_bar
      assert w.props.left == "Left"
      assert w.props.center == "Center"
      assert w.props.right == "Right"
    end
  end

  describe "spinner/1" do
    test "creates a spinner widget" do
      w = spinner(style: :dots, active: true)
      assert w.type == :spinner
      assert w.props.style == :dots
      assert w.props.active == true
    end
  end

  describe "gauge/4" do
    test "creates a gauge widget" do
      w = gauge(50, 0, 100, label: "CPU")
      assert w.type == :gauge
      assert w.props.value == 50
      assert w.props.min == 0
      assert w.props.max == 100
      assert w.props.label == "CPU"
    end
  end

  describe "chart/2" do
    test "creates a chart widget" do
      w = chart([1, 2, 3, 4, 5], type: :bar)
      assert w.type == :chart
      assert w.props.data == [1, 2, 3, 4, 5]
      assert w.props.type == :bar
    end
  end

  describe "stepper/3" do
    test "creates a stepper widget" do
      w = stepper(["Step 1", "Step 2", "Step 3"], 1)
      assert w.type == :stepper
      assert w.props.steps == ["Step 1", "Step 2", "Step 3"]
      assert w.props.current == 1
    end
  end
end

defmodule Visillo.LayoutTest do
  use ExUnit.Case, async: true

  alias Visillo.{Layout, Widget}
  import Visillo.DSL

  describe "Layout.compute/4" do
    test "assigns root rect to root widget" do
      root = Widget.new(:box)
      result = Layout.compute(root, 80, 24)
      assert result.rect.x == 0
      assert result.rect.y == 0
      assert result.rect.width == 80
      assert result.rect.height == 24
    end

    test "lays out text children in column by default" do
      root =
        Widget.new(:box, %{border: :none}, [
          Widget.new(:text, %{content: "A"}),
          Widget.new(:text, %{content: "B"}),
          Widget.new(:text, %{content: "C"})
        ])

      result = Layout.compute(root, 80, 24)
      assert length(result.children) == 3

      # Each text is 1 line tall, stacked vertically
      [a, b, c] = result.children
      assert a.rect.y == 0
      assert b.rect.y == 1
      assert c.rect.y == 2
    end

    test "respects fixed height constraints" do
      child =
        Widget.new(:text, %{content: "x"})
        |> Widget.with_constraint(height: 5)

      root = Widget.new(:box, %{border: :none}, [child])
      result = Layout.compute(root, 80, 24)
      assert hd(result.children).rect.height == 5
    end

    test "handles empty children" do
      root = Widget.new(:box)
      result = Layout.compute(root, 80, 24)
      assert result.children == []
    end
  end
end

defmodule Visillo.ThemeTest do
  use ExUnit.Case, async: true

  alias Visillo.Theme

  describe "Theme.load/1" do
    test "loads default theme by atom" do
      assert {:ok, theme} = Theme.load(:default)
      assert is_map(theme)
      assert Map.has_key?(theme, :background)
      assert Map.has_key?(theme, :foreground)
      assert Map.has_key?(theme, :primary)
    end

    test "loads dracula theme" do
      assert {:ok, theme} = Theme.load(:dracula)
      assert theme.name == "Dracula"
    end

    test "loads tokyo_night theme" do
      assert {:ok, _theme} = Theme.load(:tokyo_night)
    end

    test "returns error for unknown theme" do
      assert {:error, :not_found} = Theme.load(:nonexistent)
    end

    test "accepts a map directly" do
      custom = %{background: {0, 0, 0}, foreground: {255, 255, 255}}
      assert {:ok, ^custom} = Theme.load(custom)
    end
  end

  describe "Theme.fg/1" do
    test "generates ANSI foreground sequence" do
      assert Theme.fg({255, 0, 0}) == "\e[38;2;255;0;0m"
      assert Theme.fg({0, 255, 0}) == "\e[38;2;0;255;0m"
    end

    test "returns empty for nil" do
      assert Theme.fg(nil) == ""
    end
  end

  describe "Theme.bg/1" do
    test "generates ANSI background sequence" do
      assert Theme.bg({0, 0, 255}) == "\e[48;2;0;0;255m"
    end

    test "returns empty for nil" do
      assert Theme.bg(nil) == ""
    end
  end

  describe "Theme.list/0" do
    test "returns list of available theme names" do
      themes = Theme.list()
      assert :default in themes
      assert :dracula in themes
      assert :tokyo_night in themes
      assert :gruvbox in themes
      assert :catppuccin in themes
      assert :nord in themes
    end
  end

  describe "Theme.merge/2" do
    test "merges overrides into base theme" do
      {:ok, base} = Theme.load(:default)
      overrides = %{primary: {255, 0, 0}}
      merged = Theme.merge(base, overrides)
      assert merged.primary == {255, 0, 0}
      assert merged.background == base.background
    end
  end
end

defmodule Visillo.AnimationTest do
  use ExUnit.Case, async: true

  alias Visillo.Animation

  describe "Animation.spinner_char/2" do
    test "returns a char for dots spinner" do
      char = Animation.spinner_char(:dots, 0)
      assert is_binary(char)
      assert String.length(char) >= 1
    end

    test "cycles through frames" do
      chars = Enum.map(0..7, &Animation.spinner_char(:dots, &1))
      assert length(Enum.uniq(chars)) > 1
    end

    test "supports all built-in styles" do
      Enum.each(Animation.spinner_styles(), fn style ->
        char = Animation.spinner_char(style, 0)
        assert is_binary(char), "Style #{style} should return a binary"
      end)
    end
  end

  describe "Animation.frame_index/2" do
    test "returns index within cycle length" do
      assert Animation.frame_index(0, 4) == 0
      assert Animation.frame_index(3, 4) == 3
      # wraps
      assert Animation.frame_index(4, 4) == 0
      assert Animation.frame_index(7, 4) == 3
    end
  end
end

defmodule Visillo.Render.TextWrapTest do
  use ExUnit.Case, async: true

  alias Visillo.Render.TextWrap

  describe "wrap/3 with :none" do
    test "splits on newlines only" do
      result = TextWrap.wrap("Hello\nWorld", 10, :none)
      assert result == ["Hello", "World"]
    end
  end

  describe "wrap/3 with :char" do
    test "breaks at character boundaries" do
      result = TextWrap.wrap("ABCDE", 3, :char)
      assert result == ["ABC", "DE"]
    end
  end

  describe "wrap/3 with :word (default)" do
    test "wraps at word boundaries" do
      result = TextWrap.wrap("Hello World Test", 10, :word)
      assert Enum.all?(result, &(String.length(&1) <= 10))
    end

    test "returns single line if it fits" do
      result = TextWrap.wrap("Hello", 20, :word)
      assert result == ["Hello"]
    end

    test "handles empty string" do
      result = TextWrap.wrap("", 10, :word)
      assert result == [""]
    end

    test "handles very long words" do
      long_word = String.duplicate("a", 20)
      result = TextWrap.wrap(long_word, 5, :word)
      assert Enum.all?(result, &(String.length(&1) <= 5))
    end

    test "respects newlines in input" do
      result = TextWrap.wrap("Line 1\nLine 2", 20, :word)
      assert "Line 1" in result
      assert "Line 2" in result
    end
  end
end

defmodule Visillo.EventBusTest do
  use ExUnit.Case, async: false

  alias Visillo.EventBus

  setup do
    {:ok, pid} = EventBus.start_link()
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    {:ok, bus: pid}
  end

  test "subscribe and receive events" do
    EventBus.subscribe(:test_topic)
    EventBus.publish(:test_topic, "hello")

    assert_receive {:bus_event, :test_topic, "hello"}, 500
  end

  test "multiple subscribers receive the same event" do
    test_pid = self()

    spawn(fn ->
      EventBus.subscribe(:multi_topic)

      receive do
        {:bus_event, :multi_topic, _} = msg ->
          send(test_pid, {:got, msg})
      end
    end)

    EventBus.subscribe(:multi_topic)
    Process.sleep(10)
    EventBus.publish(:multi_topic, "broadcast")

    assert_receive {:bus_event, :multi_topic, "broadcast"}, 500
  end

  test "unsubscribe stops receiving events" do
    EventBus.subscribe(:unsub_topic)
    EventBus.unsubscribe(:unsub_topic)
    EventBus.publish(:unsub_topic, "should_not_arrive")

    refute_receive {:bus_event, :unsub_topic, _}, 100
  end

  test "unsubscribe_all removes from all topics" do
    EventBus.subscribe(:topic_a)
    EventBus.subscribe(:topic_b)
    EventBus.unsubscribe_all()
    EventBus.publish(:topic_a, "a")
    EventBus.publish(:topic_b, "b")

    refute_receive {:bus_event, _, _}, 100
  end

  test "subscribers/1 returns active subscribers" do
    EventBus.subscribe(:subs_test)
    subs = EventBus.subscribers(:subs_test)
    assert self() in subs
  end
end

defmodule Visillo.FocusTest do
  use ExUnit.Case, async: false

  alias Visillo.Focus

  setup do
    {:ok, pid} = Focus.start_link()
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    :ok
  end

  test "no focus initially" do
    assert Focus.focused() == nil
  end

  test "register component and it gets focus" do
    Focus.register(:comp_a, 0)
    assert Focus.focused() == :comp_a
  end

  test "registers multiple components and focuses first" do
    Focus.register(:comp_b, 1)
    Focus.register(:comp_a, 0)
    # After sorting, comp_a (order 0) should be focused
    assert Focus.focused() == :comp_a
  end

  test "focus_next cycles to next component" do
    Focus.register(:comp_1, 0)
    Focus.register(:comp_2, 1)
    assert Focus.focused() == :comp_1
    next = Focus.next()
    assert next == :comp_2
  end

  test "focus_previous cycles backwards" do
    Focus.register(:first, 0)
    Focus.register(:second, 1)
    Focus.set(:second)
    prev = Focus.previous()
    assert prev == :first
  end

  test "focus wraps around on next" do
    Focus.register(:only, 0)
    next = Focus.next()
    assert next == :only
  end

  test "set changes focused component" do
    Focus.register(:a, 0)
    Focus.register(:b, 1)
    Focus.set(:b)
    assert Focus.focused() == :b
  end

  test "blur removes focus" do
    Focus.register(:x, 0)
    Focus.blur()
    assert Focus.focused() == nil
  end

  test "unregister removes component" do
    Focus.register(:rem_a, 0)
    Focus.register(:rem_b, 1)
    Focus.unregister(:rem_a)
    assert Focus.focused() == :rem_b
  end

  test "focused?/1 returns true for focused component" do
    Focus.register(:check, 0)
    assert Focus.focused?(:check)
    refute Focus.focused?(:other)
  end
end

defmodule Visillo.ComponentBehaviourTest do
  use ExUnit.Case, async: true

  # Módulo minimal que implementa el behaviour
  defmodule MinimalComponent do
    use Visillo.Component

    def init(_props), do: {:ok, %{value: 0}}

    def render(state, _theme) do
      text("Value: #{state.value}")
    end
  end

  # Módulo que sobreescribe todos los callbacks
  defmodule FullComponent do
    use Visillo.Component

    def init(_props), do: {:ok, %{count: 0}}

    def handle_key("q", [], _state), do: {:quit, :user}
    def handle_key("+", [], _state), do: {:send, :inc}
    def handle_key(_, _, _), do: :ignore

    def update(:inc, state), do: {:ok, %{state | count: state.count + 1}}

    def focusable?, do: true

    def render(state, _theme) do
      box(border: :rounded, title: "Counter") do
        text("#{state.count}")
      end
    end
  end

  describe "MinimalComponent" do
    test "init returns ok" do
      assert {:ok, state} = MinimalComponent.init([])
      assert state.value == 0
    end

    test "has default update/2" do
      {:ok, state} = MinimalComponent.init([])
      assert {:ok, ^state} = MinimalComponent.update(:anything, state)
    end

    test "has default handle_key/3 that returns :ignore" do
      {:ok, state} = MinimalComponent.init([])
      assert :ignore = MinimalComponent.handle_key("a", [], state)
    end

    test "has default focusable? returning false" do
      refute MinimalComponent.focusable?()
    end

    test "render returns a Widget" do
      {:ok, state} = MinimalComponent.init([])
      theme = Visillo.Theme.default()
      widget = MinimalComponent.render(state, theme)
      assert %Visillo.Widget{} = widget
    end
  end

  describe "FullComponent" do
    test "init returns ok" do
      assert {:ok, state} = FullComponent.init([])
      assert state.count == 0
    end

    test "focusable? returns true" do
      assert FullComponent.focusable?()
    end

    test "handle_key dispatches correctly" do
      {:ok, state} = FullComponent.init([])
      assert {:quit, :user} = FullComponent.handle_key("q", [], state)
      assert {:send, :inc} = FullComponent.handle_key("+", [], state)
      assert :ignore = FullComponent.handle_key("x", [], state)
    end

    test "update increments count" do
      {:ok, state} = FullComponent.init([])
      assert {:ok, %{count: 1}} = FullComponent.update(:inc, state)
    end

    test "render returns a box widget with text child" do
      {:ok, state} = FullComponent.init([])
      theme = Visillo.Theme.default()
      widget = FullComponent.render(state, theme)
      assert widget.type == :box
      assert length(widget.children) == 1
      assert hd(widget.children).type == :text
    end
  end
end

defmodule Visillo.SplitPaneTest do
  use ExUnit.Case, async: true

  alias Visillo.Widgets.SplitPane

  describe "init/1" do
    test "creates split pane with defaults" do
      {:ok, state} = SplitPane.init([])
      assert state.direction == :horizontal
      assert state.ratio == 0.3
      assert state.first == []
      assert state.second == []
    end

    test "creates split pane with custom options" do
      {:ok, state} =
        SplitPane.init(
          direction: :vertical,
          ratio: 0.5,
          first: [Visillo.Widget.new(:text)],
          second: [Visillo.Widget.new(:text)]
        )

      assert state.direction == :vertical
      assert state.ratio == 0.5
    end

    test "render returns a box widget" do
      {:ok, state} =
        SplitPane.init(first: [Visillo.Widget.new(:text)], second: [Visillo.Widget.new(:text)])

      theme = Visillo.Theme.default()
      widget = SplitPane.render(state, theme)
      assert widget.type == :box
    end
  end
end

defmodule Visillo.TabsWidgetTest do
  use ExUnit.Case, async: true

  alias Visillo.Widgets.Tabs

  describe "init/1" do
    test "creates tabs with defaults" do
      {:ok, state} = Tabs.init(tabs: [%{label: "Tab1", content: [Visillo.Widget.new(:text)]}])
      assert state.active == 0
      assert length(state.tabs) == 1
    end

    test "handles tab cycling" do
      {:ok, state} = Tabs.init(tabs: [%{label: "A", content: []}, %{label: "B", content: []}])
      assert {:send, {:tab_changed, 1, "B"}} = Tabs.handle_key("tab", [:ctrl], state)
      assert {:send, {:tab_changed, 1, "B"}} = Tabs.handle_key("tab", [:ctrl, :shift], state)
    end

    test "render returns a box" do
      {:ok, state} = Tabs.init(tabs: [%{label: "X", content: [Visillo.Widget.new(:text)]}])
      theme = Visillo.Theme.default()
      widget = Tabs.render(state, theme)
      assert widget.type == :box
    end
  end
end

defmodule Visillo.TreeViewWidgetTest do
  use ExUnit.Case, async: true

  alias Visillo.Widgets.TreeView

  describe "init/1" do
    test "initializes with root path" do
      {:ok, state} = TreeView.init(root: "/etc", show_hidden: false)
      assert state.root_path == "/etc"
      assert state.selected == 0
    end

    test "navigation works" do
      {:ok, state} = TreeView.init(root: "/etc", show_hidden: false)

      if length(state.entries) > 1 do
        {:ok, s2} = TreeView.handle_key("down", [], state)
        assert s2.selected == 1
        {:ok, s3} = TreeView.handle_key("up", [], s2)
        assert s3.selected == 0
      end
    end
  end
end

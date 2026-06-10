defmodule Visillo.MixProject do
  use Mix.Project

  def project do
    [
      app: :visillo,
      version: "1.0.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Visillo",
      description:
        "Declarative TUI (Terminal User Interface) framework for Elixir following The Elm Architecture (Model-Update-View) — composable widget DSL, flexbox layout, diff-based rendering, animations, themes, and keyboard/mouse events.",
      source_url: "https://github.com/Lorenzo-SF/visillo",
      homepage_url: "https://github.com/Lorenzo-SF/visillo",
      package: [
        name: :visillo,
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/Lorenzo-SF/visillo"},
        maintainers: ["Lorenzo Sánchez"]
      ],
      docs: docs(),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: "https://github.com/Lorenzo-SF/visillo",
      homepage_url: "https://github.com/Lorenzo-SF/visillo",
      extras: ["README.md", "README_ES.md", "LICENSE.md"],
      groups_for_modules: [
        Core: [Visillo.App, Visillo.Supervisor, Visillo.Component, Visillo.Widget],
        DSL: [Visillo.Dsl, Visillo.Demo],
        "Event System": [
          Visillo.EventBus,
          Visillo.EventRouter,
          Visillo.Event.Keyboard,
          Visillo.Input,
          Visillo.Focus
        ],
        "Render Engine": [
          Visillo.Layout,
          Visillo.Screen,
          Visillo.Render.Renderer,
          Visillo.Render.Buffer,
          Visillo.Render.Border
        ],
        Animation: [Visillo.Animation],
        Themes: [Visillo.Theme],
        Widgets: [
          Visillo.Widgets.Button,
          Visillo.Widgets.Checkbox,
          Visillo.Widgets.Label,
          Visillo.Widgets.Panel,
          Visillo.Widgets.SplitPane,
          Visillo.Widgets.Tabs,
          Visillo.Widgets.TextInput,
          Visillo.Widgets.TreeView
        ],
        "Mix Tasks": [
          Mix.Tasks.Visillo.Demo.Chat,
          Mix.Tasks.Visillo.Demo.Counter,
          Mix.Tasks.Visillo.Demo.Dashboard,
          Mix.Tasks.Visillo.Demo.Editor,
          Mix.Tasks.Visillo.Demo.Form,
          Mix.Tasks.Visillo.Demo.Installer,
          Mix.Tasks.Visillo.Demo.Menu,
          Mix.Tasks.Visillo.Demo.Unified
        ]
      ]
    ]
  end

  defp deps do
    [
      {:arrea, git: "git@github.com:Lorenzo-SF/arrea.git"},
      {:jason, "~> 1.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp aliases do
    [
      qa: [
        "format",
        "compile",
        "dialyzer",
        "cmd sh -c 'MIX_ENV=test mix test --cover'",
        "cmd sh -c 'alaja json \"$(mix credo --strict --format=json)\"'"
      ]
    ]
  end
end

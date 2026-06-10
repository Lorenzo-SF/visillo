defmodule Mix.Tasks.Visillo.Demo.Editor do
  use Mix.Task

  @shortdoc "Runs the Visillo MicroEditor demo — multi-buffer, sidebar (Ctrl+E), word wrap (wrap: true)"
  def run(_args) do
    Mix.Task.run("app.start")

    System.at_exit(fn _ ->
      Visillo.Input.restore_terminal()
    end)

    Visillo.App.run(Visillo.Demo.MicroEditor,
      title: "Micro Editor",
      theme: :default,
      quit_keys: [],
      focus_keys: []
    )
  end
end

defmodule Mix.Tasks.Visillo.Demo.Unified do
  use Mix.Task

  @shortdoc "Runs the unified Visillo demo — file browser, editor, chat, dashboard"
  def run(_args) do
    Mix.Task.run("app.start")

    System.at_exit(fn _ ->
      Visillo.Input.restore_terminal()
    end)

    Visillo.App.run(Visillo.Demo.Unified,
      title: "Visillo Unified",
      theme: :default,
      quit_keys: [],
      focus_keys: []
    )
  end
end

defmodule Mix.Tasks.Visillo.Demo.Counter do
  use Mix.Task

  @shortdoc "Runs the Visillo Counter demo TUI"
  def run(_args) do
    Mix.Task.run("app.start")

    # Safety net: si el proceso muere sin hacer cleanup, restaurar terminal
    System.at_exit(fn _ ->
      Visillo.Input.restore_terminal()
    end)

    Visillo.App.run(Visillo.Demo.Counter,
      title: "Counter Demo",
      theme: :default,
      quit_keys: ["q", "ctrl+c"]
    )
  end
end

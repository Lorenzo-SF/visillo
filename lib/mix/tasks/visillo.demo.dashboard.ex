defmodule Mix.Tasks.Visillo.Demo.Dashboard do
  use Mix.Task

  @shortdoc "Runs the Visillo Dashboard demo (btop-like system monitor)"
  def run(_args) do
    Mix.Task.run("app.start")

    System.at_exit(fn _ ->
      Visillo.Input.restore_terminal()
    end)

    Visillo.App.run(Visillo.Demo.Dashboard,
      title: "System Dashboard",
      theme: :default,
      quit_keys: ["q"]
    )
  end
end

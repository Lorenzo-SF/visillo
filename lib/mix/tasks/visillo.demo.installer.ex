defmodule Mix.Tasks.Visillo.Demo.Installer do
  use Mix.Task

  @shortdoc "Runs the Visillo Installer demo (multi-step wizard)"
  def run(_args) do
    Mix.Task.run("app.start")

    System.at_exit(fn _ ->
      Visillo.Input.restore_terminal()
    end)

    Visillo.App.run(Visillo.Demo.Installer,
      title: "Installer",
      theme: :default,
      quit_keys: [],
      focus_keys: []
    )
  end
end

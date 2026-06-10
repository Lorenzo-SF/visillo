defmodule Mix.Tasks.Visillo.Demo.Menu do
  use Mix.Task

  @shortdoc "Runs the Visillo MenuApp demo (multi-screen navigation)"
  def run(_args) do
    Mix.Task.run("app.start")

    System.at_exit(fn _ ->
      Visillo.Input.restore_terminal()
    end)

    Visillo.App.run(Visillo.Demo.MenuApp, title: "MenuApp Demo", theme: :default, quit_keys: [])
  end
end

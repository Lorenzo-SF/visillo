defmodule Mix.Tasks.Visillo.Demo.Chat do
  use Mix.Task

  @shortdoc "Runs the Visillo Chat demo with /commands"
  def run(_args) do
    Mix.Task.run("app.start")

    System.at_exit(fn _ ->
      Visillo.Input.restore_terminal()
    end)

    Visillo.App.run(Visillo.Demo.Chat, title: "Chat Demo", theme: :default, quit_keys: [])
  end
end

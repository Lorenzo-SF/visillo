defmodule Mix.Tasks.Visillo.Demo.Form do
  use Mix.Task

  @shortdoc "Runs the Visillo Registration Form demo TUI"
  def run(_args) do
    Mix.Task.run("app.start")

    Visillo.App.run(Visillo.Demo.Form,
      title: "Registration Form",
      theme: :default,
      quit_keys: ["q", "ctrl+c"]
    )
  end
end

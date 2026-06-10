# Registration Form Demo — Visillo TUI
#
# Run:
#   mix run lib/visillo/demo/form.exs
#
# Controls:
#   Tab       Move focus between fields
#   Enter     Activate button / toggle checkbox
#   Type      Enter text in fields
#   Backspace Delete character
#   q         Quit

Visillo.App.run(Visillo.Demo.Form,
  title: "Registration Form",
  theme: :default,
  quit_keys: ["q", "ctrl+c"]
)

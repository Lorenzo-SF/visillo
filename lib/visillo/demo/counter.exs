# Counter Demo — Visillo TUI
#
# Run:
#   mix run lib/visillo/demo/counter.exs
#
# Controls:
#   + / =   Increment
#   - / _   Decrement
#   r       Reset
#   q       Quit

Visillo.App.run(Visillo.Demo.Counter,
  title: "Counter Demo",
  theme: :default,
  quit_keys: ["q", "ctrl+c"]
)

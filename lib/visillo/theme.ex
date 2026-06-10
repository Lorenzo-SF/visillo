defmodule Visillo.Theme do
  @moduledoc """
  Theme management for Visillo.

  A theme defines the color palette for all components.
  Compatible with existing {Alaja themes.

  ## Available themes

    * `:default` — Standard theme (blue/gray)
    * `:dracula` — Dracula theme (purple/green)
    * `:tokyo_night` — Tokyo Night theme (deep blue)
    * `:gruvbox` — Gruvbox theme (brown/orange)
    * `:catppuccin` — Catppuccin Mocha theme (lavender)
    * `:nord` — Nord theme (blue/white)
    * `:monokai` — Monokai theme (colorful)

  ## Theme colors

  Each theme defines:
    - Base colors (background, foreground, primary, secondary)
    - Semantic colors (success, error, warning, info)
    - Focus and selection colors
    - Component-specific colors
  """

  @type color :: {0..255, 0..255, 0..255}

  @type t :: %{
          name: String.t(),
          type: :dark | :light,
          # Base
          background: color(),
          foreground: color(),
          primary: color(),
          secondary: color(),
          # Foco y selección
          focus: color(),
          focus_bg: color(),
          border: color(),
          border_focus: color(),
          selection: color(),
          selection_bg: color(),
          # Semánticos
          success: color(),
          error: color(),
          warning: color(),
          info: color(),
          # Componentes
          button_primary: color(),
          button_secondary: color(),
          button_danger: color(),
          button_ghost: color(),
          input_bg: color(),
          input_fg: color(),
          input_cursor: color(),
          modal_overlay: color(),
          status_bar_bg: color(),
          status_bar_fg: color(),
          progress_fill: color(),
          progress_empty: color(),
          list_selected_bg: color(),
          list_selected_fg: color(),
          tab_active: color(),
          tab_inactive: color(),
          header_bg: color(),
          header_fg: color(),
          # Syntax
          keyword: color(),
          string: color(),
          number: color(),
          comment: color()
        }

  # ─── Temas built-in ──────────────────────────────────────────────────────────

  @themes %{
    default: %{
      name: "Default",
      type: :dark,
      background: {28, 28, 35},
      foreground: {220, 220, 230},
      primary: {100, 149, 237},
      secondary: {70, 200, 180},
      focus: {255, 190, 80},
      focus_bg: {45, 50, 70},
      border: {70, 80, 110},
      border_focus: {100, 149, 237},
      selection: {220, 220, 230},
      selection_bg: {50, 80, 130},
      success: {80, 200, 120},
      error: {240, 80, 80},
      warning: {240, 180, 60},
      info: {80, 180, 240},
      button_primary: {100, 149, 237},
      button_secondary: {70, 80, 110},
      button_danger: {200, 70, 70},
      button_ghost: {90, 100, 130},
      input_bg: {38, 40, 55},
      input_fg: {220, 220, 230},
      input_cursor: {100, 149, 237},
      modal_overlay: {20, 20, 28},
      status_bar_bg: {20, 22, 32},
      status_bar_fg: {150, 160, 190},
      progress_fill: {100, 149, 237},
      progress_empty: {45, 50, 70},
      list_selected_bg: {50, 80, 130},
      list_selected_fg: {220, 220, 230},
      tab_active: {100, 149, 237},
      tab_inactive: {90, 100, 130},
      header_bg: {38, 40, 55},
      header_fg: {100, 149, 237},
      keyword: {189, 147, 249},
      string: {80, 200, 120},
      number: {240, 180, 60},
      comment: {100, 110, 140}
    },
    dracula: %{
      name: "Dracula",
      type: :dark,
      background: {40, 42, 54},
      foreground: {248, 248, 242},
      primary: {189, 147, 249},
      secondary: {139, 233, 253},
      focus: {255, 184, 108},
      focus_bg: {68, 71, 90},
      border: {98, 114, 164},
      border_focus: {189, 147, 249},
      selection: {248, 248, 242},
      selection_bg: {68, 71, 90},
      success: {80, 250, 123},
      error: {255, 85, 85},
      warning: {241, 250, 140},
      info: {139, 233, 253},
      button_primary: {189, 147, 249},
      button_secondary: {98, 114, 164},
      button_danger: {255, 85, 85},
      button_ghost: {68, 71, 90},
      input_bg: {68, 71, 90},
      input_fg: {248, 248, 242},
      input_cursor: {189, 147, 249},
      modal_overlay: {30, 31, 40},
      status_bar_bg: {68, 71, 90},
      status_bar_fg: {248, 248, 242},
      progress_fill: {80, 250, 123},
      progress_empty: {68, 71, 90},
      list_selected_bg: {68, 71, 90},
      list_selected_fg: {248, 248, 242},
      tab_active: {189, 147, 249},
      tab_inactive: {98, 114, 164},
      header_bg: {68, 71, 90},
      header_fg: {189, 147, 249},
      keyword: {255, 121, 198},
      string: {241, 250, 140},
      number: {189, 147, 249},
      comment: {98, 114, 164}
    },
    tokyo_night: %{
      name: "Tokyo Night",
      type: :dark,
      background: {26, 27, 38},
      foreground: {192, 202, 245},
      primary: {122, 162, 247},
      secondary: {158, 206, 106},
      focus: {224, 175, 104},
      focus_bg: {36, 40, 59},
      border: {51, 59, 91},
      border_focus: {122, 162, 247},
      selection: {192, 202, 245},
      selection_bg: {40, 56, 99},
      success: {158, 206, 106},
      error: {247, 118, 142},
      warning: {224, 175, 104},
      info: {125, 207, 255},
      button_primary: {122, 162, 247},
      button_secondary: {51, 59, 91},
      button_danger: {247, 118, 142},
      button_ghost: {36, 40, 59},
      input_bg: {30, 33, 53},
      input_fg: {192, 202, 245},
      input_cursor: {122, 162, 247},
      modal_overlay: {20, 22, 30},
      status_bar_bg: {22, 23, 35},
      status_bar_fg: {122, 162, 247},
      progress_fill: {122, 162, 247},
      progress_empty: {36, 40, 59},
      list_selected_bg: {40, 56, 99},
      list_selected_fg: {192, 202, 245},
      tab_active: {122, 162, 247},
      tab_inactive: {89, 98, 148},
      header_bg: {30, 33, 53},
      header_fg: {122, 162, 247},
      keyword: {187, 154, 247},
      string: {158, 206, 106},
      number: {255, 158, 100},
      comment: {89, 98, 148}
    },
    gruvbox: %{
      name: "Gruvbox Dark",
      type: :dark,
      background: {40, 40, 40},
      foreground: {235, 219, 178},
      primary: {131, 165, 152},
      secondary: {184, 187, 38},
      focus: {250, 189, 47},
      focus_bg: {60, 56, 54},
      border: {80, 73, 69},
      border_focus: {131, 165, 152},
      selection: {235, 219, 178},
      selection_bg: {80, 73, 69},
      success: {184, 187, 38},
      error: {204, 36, 29},
      warning: {215, 153, 33},
      info: {131, 165, 152},
      button_primary: {131, 165, 152},
      button_secondary: {80, 73, 69},
      button_danger: {204, 36, 29},
      button_ghost: {60, 56, 54},
      input_bg: {50, 48, 47},
      input_fg: {235, 219, 178},
      input_cursor: {250, 189, 47},
      modal_overlay: {29, 32, 33},
      status_bar_bg: {50, 48, 47},
      status_bar_fg: {235, 219, 178},
      progress_fill: {250, 189, 47},
      progress_empty: {60, 56, 54},
      list_selected_bg: {80, 73, 69},
      list_selected_fg: {235, 219, 178},
      tab_active: {250, 189, 47},
      tab_inactive: {80, 73, 69},
      header_bg: {50, 48, 47},
      header_fg: {250, 189, 47},
      keyword: {204, 36, 29},
      string: {184, 187, 38},
      number: {250, 189, 47},
      comment: {124, 111, 100}
    },
    catppuccin: %{
      name: "Catppuccin Mocha",
      type: :dark,
      background: {30, 30, 46},
      foreground: {205, 214, 244},
      primary: {137, 180, 250},
      secondary: {166, 227, 161},
      focus: {249, 226, 175},
      focus_bg: {49, 50, 68},
      border: {88, 91, 112},
      border_focus: {137, 180, 250},
      selection: {205, 214, 244},
      selection_bg: {49, 50, 68},
      success: {166, 227, 161},
      error: {243, 139, 168},
      warning: {249, 226, 175},
      info: {137, 220, 235},
      button_primary: {137, 180, 250},
      button_secondary: {88, 91, 112},
      button_danger: {243, 139, 168},
      button_ghost: {49, 50, 68},
      input_bg: {24, 24, 37},
      input_fg: {205, 214, 244},
      input_cursor: {137, 180, 250},
      modal_overlay: {17, 17, 27},
      status_bar_bg: {24, 24, 37},
      status_bar_fg: {137, 180, 250},
      progress_fill: {137, 180, 250},
      progress_empty: {49, 50, 68},
      list_selected_bg: {49, 50, 68},
      list_selected_fg: {205, 214, 244},
      tab_active: {137, 180, 250},
      tab_inactive: {88, 91, 112},
      header_bg: {24, 24, 37},
      header_fg: {137, 180, 250},
      keyword: {203, 166, 247},
      string: {166, 227, 161},
      number: {250, 179, 135},
      comment: {88, 91, 112}
    },
    nord: %{
      name: "Nord",
      type: :dark,
      background: {46, 52, 64},
      foreground: {236, 239, 244},
      primary: {136, 192, 208},
      secondary: {163, 190, 140},
      focus: {235, 203, 139},
      focus_bg: {59, 66, 82},
      border: {67, 76, 94},
      border_focus: {136, 192, 208},
      selection: {236, 239, 244},
      selection_bg: {67, 76, 94},
      success: {163, 190, 140},
      error: {191, 97, 106},
      warning: {235, 203, 139},
      info: {129, 161, 193},
      button_primary: {136, 192, 208},
      button_secondary: {67, 76, 94},
      button_danger: {191, 97, 106},
      button_ghost: {59, 66, 82},
      input_bg: {59, 66, 82},
      input_fg: {236, 239, 244},
      input_cursor: {136, 192, 208},
      modal_overlay: {36, 41, 51},
      status_bar_bg: {59, 66, 82},
      status_bar_fg: {216, 222, 233},
      progress_fill: {136, 192, 208},
      progress_empty: {67, 76, 94},
      list_selected_bg: {67, 76, 94},
      list_selected_fg: {236, 239, 244},
      tab_active: {136, 192, 208},
      tab_inactive: {76, 86, 106},
      header_bg: {59, 66, 82},
      header_fg: {136, 192, 208},
      keyword: {180, 142, 173},
      string: {163, 190, 140},
      number: {208, 135, 112},
      comment: {76, 86, 106}
    }
  }

  # ─── API ────────────────────────────────────────────────────────────────────

  @doc "Loads a theme by name or returns the given theme if it is already a map."
  @spec load(atom() | String.t() | map()) :: {:ok, t()} | {:error, :not_found}
  def load(name) when is_atom(name) do
    case Map.get(@themes, name) do
      nil -> {:error, :not_found}
      theme -> {:ok, theme}
    end
  end

  def load(name) when is_binary(name) do
    load(String.to_existing_atom(name))
  rescue
    ArgumentError -> {:error, :not_found}
  end

  def load(theme) when is_map(theme), do: {:ok, theme}

  @doc "Lists available themes."
  @spec list() :: [atom()]
  def list, do: Map.keys(@themes)

  @doc "Gets a color from the theme by key."
  @spec color(t(), atom()) :: color() | nil
  def color(theme, key), do: Map.get(theme, key)

  @doc """
  Convierte un color a secuencia ANSI de foreground.
  """
  @spec fg(color()) :: String.t()
  def fg({r, g, b}), do: "\e[38;2;#{r};#{g};#{b}m"
  def fg(nil), do: ""

  @doc """
  Convierte un color a secuencia ANSI de background.
  """
  @spec bg(color()) :: String.t()
  def bg({r, g, b}), do: "\e[48;2;#{r};#{g};#{b}m"
  def bg(nil), do: ""

  @doc "ANSI color reset."
  @spec reset() :: String.t()
  def reset, do: "\e[0m"

  @doc "Returns the default theme."
  @spec default() :: t()
  def default, do: @themes.default

  @doc "Merges two themes, the second overrides the first."
  @spec merge(t(), map()) :: t()
  def merge(base, overrides), do: Map.merge(base, overrides)
end

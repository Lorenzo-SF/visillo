# Documentación CLI — Zaguan

> Referencia completa de comandos, subcomandos y argumentos del CLI `zaguan`.

---

## Índice

1. [Invocación y flags de nivel raíz](#1-invocación-y-flags-de-nivel-raíz)
2. [Opciones globales compartidas](#2-opciones-globales-compartidas)
3. [zaguan show](#3-zaguan-show)
   - [show message](#31-show-message)
   - [show success/error/warning/info/debug/notice/critical/alert/emergency/happy/sad](#32-show-mensajes-tipados)
   - [show header](#33-show-header)
   - [show separator](#34-show-separator)
   - [show gradient](#35-show-gradient)
   - [show table](#36-show-table)
   - [show json](#37-show-json)
   - [show bar](#38-show-bar)
   - [show animated-bar](#39-show-animated-bar)
   - [show breadcrumbs](#310-show-breadcrumbs)
   - [show animate](#311-show-animate)
   - [show image](#312-show-image)
   - [show list](#313-show-list)
   - [show ask](#314-show-ask)
   - [show menu](#315-show-menu)
   - [show yesno](#316-show-yesno)
4. [zaguan run](#4-zaguan-run)
5. [zaguan color](#5-zaguan-color)
6. [zaguan action](#6-zaguan-action)
7. [zaguan config](#7-zaguan-config)
8. [Formatos de color aceptados](#8-formatos-de-color-aceptados)

---

## 1. Invocación y flags de nivel raíz

**Módulo:** `Zaguan.CLI` — `main/1`

```
zaguan [--help | -h]
zaguan [--version | -v]
zaguan <command> [args...]
zaguan <command> --help
```

| Patrón | Acción interna | Función |
|---|---|---|
| `zaguan` (sin args) | Muestra resumen de comandos | `Zaguan.CLI.Help.summary/1` |
| `zaguan --help` / `-h` | Muestra referencia completa | `Zaguan.CLI.Help.full/0` |
| `zaguan --version` / `-v` | Imprime `"zaguan <version>"` | Versión extraída de `Mix.Project.config()[:version]` |
| `zaguan <cmd>` | Despacha al módulo del comando | `Map.fetch(@commands, cmd)` → `module.run(rest)` |
| `zaguan <cmd> --help` | Muestra ayuda del comando | `module.help/0` |

Si el comando no existe, imprime `"zaguan: unknown command '<cmd>'"` en stderr y termina con código 1.

---

## 2. Opciones globales compartidas

**Módulo:** `Zaguan.CLI.GlobalOpts` — `parse/1`

Estas opciones son reconocidas por **todos los subcomandos** antes del parseo específico. Se extraen del array de argumentos de forma transparente; los argumentos no reconocidos se pasan al comando.

| Opción | Alias | Tipo | Default | Descripción | Procesamiento interno |
|---|---|---|---|---|---|
| `--help` | `-h` | boolean | `false` | Mostrar ayuda del comando | Campo `help: true` en el struct |
| `--raw` | `-r` | boolean | `false` | Modo de posicionamiento de coordenadas absolutas | Campo `raw: true` |
| `--pos-x N` | — | integer | `0` | Coordenada X (requiere `--raw`) | `Integer.parse(val)` → `pos_x` |
| `--pos-y N` | — | integer | `0` | Coordenada Y (requiere `--raw`) | `Integer.parse(val)` → `pos_y` |
| `--align TYPE` | `-a` | string | `left` | Alineación: `left`, `center`, `right` | `parse_align/1` → átomo |
| `--verbose` | `-v` | boolean | `false` | Retornar string ANSI en lugar de imprimir | Campo `verbose: true` |
| `--box` | — | boolean | `false` | Envolver la salida en una caja con borde | Campo `box: true` |
| `--box-title TEXT` | — | string | `nil` | Título de la caja (requiere `--box`) | Campo `box_title` |
| `--box-border TYPE` | — | string | `rounded` | Estilo de borde: `rounded`, `single`, `double`, `bold`, `none` | `String.to_atom(val)` → `box_border` |
| `--box-color COLOR` | — | string | `nil` | Color del borde (requiere `--box`) | `Orchestrator.parse_color/1` → `box_color` |
| `--quiet` | `-q` | boolean | `false` | Suprimir output de progreso | Campo `quiet: true` |
| `--stdin` | `-s` | boolean | `false` | Leer desde stdin | Campo `stdin: true` |

---

## 3. `zaguan show`

**Módulo:** `Zaguan.CLI.Commands.Show` — `run/1`

Dispatcher principal. Enruta al submodulo correcto según el primer argumento.

```
zaguan show <subcommand> [args...] [global-opts]
zaguan show --help
```

Los subcomandos tipados (`success`, `error`, `warning`, `info`, `debug`, `notice`, `critical`, `alert`, `emergency`, `happy`, `sad`) se detectan antes de la búsqueda en el mapa de módulos y se despachan a `Show.Message.run_typed/2`.

---

### 3.1 `show message`

**Módulo:** `Zaguan.CLI.Commands.Show.Message` — `run/1`

Muestra un mensaje formateado con control total sobre colores, efectos y estructura de chunks.

```
zaguan show message <text> [options]
zaguan show message --text <text> [options]
zaguan show message --chunk "texto|clave:valor" [--chunk ...] [options]
```

#### Argumentos posicionales

| Argumento | Requerido | Descripción |
|---|---|---|
| `<text>` | Sí* | Texto a mostrar. Se unen todos los posicionales con espacio. Ignorado si se usa `--chunk`. |

#### Opciones de color y estilo

| Opción | Tipo | Descripción | Función interna |
|---|---|---|---|
| `--text TEXT` | string | Alternativa explícita al argumento posicional | `Keyword.get(opts, :text)` |
| `--color COLOR` | string | Color del texto | `Parser.parse_color_opt/1` → `{r,g,b}` |
| `--bg-color COLOR` | string | Color de fondo del texto | `Parser.parse_color_opt/1` → `{r,g,b}` |
| `--bold` | boolean | Texto en negrita | Añade `:bold` a la lista de efectos |
| `--italic` | boolean | Texto en cursiva | Añade `:italic` |
| `--underline` | boolean | Texto subrayado | Añade `:underline` |
| `--dim` | boolean | Texto atenuado | Añade `:dim` |
| `--blink` | boolean | Texto parpadeante | Añade `:blink` |
| `--reverse` | boolean | Invertir fg/bg | Añade `:reverse` |
| `--hidden` | boolean | Texto oculto | Añade `:hidden` |
| `--strikethrough` | boolean | Texto tachado | Añade `:strikethrough` |

#### Opciones de formato

| Opción | Tipo | Valores | Default | Descripción | Función interna |
|---|---|---|---|---|---|
| `--align TYPE` | string | `left`, `center`, `right` | `left` | Alineación del texto | `parse_align/1` → átomo |
| `--padding N` | integer | 0+ | `0` | Espacios de padding alrededor del texto | `Keyword.get(opts, :padding, 0)` |
| `--addline WHEN` | string | `before`, `after`, `both`, `none` | `none` | Añadir líneas en blanco | `parse_addline/1` → átomo |

#### Modo multi-chunk

| Opción | Tipo | Descripción | Función interna |
|---|---|---|---|
| `--chunk SPEC` | string, repetible | Define un fragmento de texto con estilos inline. Formato: `"texto\|clave:valor\|clave:valor"`. Claves válidas: `color`, `bg`/`bg_color`, `bold`, `italic`, `underline`, `dim`, `blink`, `reverse`, `hidden`, `strikethrough`. | `Keyword.get_values(opts, :chunk)` → `parse_chunk/1` por cada spec → `%ChunkText{}` |

**Flujo interno completo:**
1. `GlobalOpts.parse(args)` → extrae opciones globales
2. `OptionParser.parse(rest, switches: [...])` → extrae switches específicos
3. Si hay `--chunk`: `parse_chunk/1` por cada spec, construye lista de `%ChunkText{}`
4. Si no: construye un único `%ChunkText{}` con el texto y efectos
5. Construye `%MessageInfo{}` con chunks, align, padding, add_line
6. Si `global.box`: convierte chunks a string ANSI y envuelve con `Box.render/2`
7. `Printer.print/2` con opts de global (raw, pos_x, pos_y, verbose)

---

### 3.2 `show` Mensajes tipados

**Módulo:** `Zaguan.CLI.Commands.Show.Message` — `run_typed/2`

Los siguientes subcomandos son alias directos con icono y color predefinidos:

```
zaguan show success <texto>
zaguan show error <texto>
zaguan show warning <texto>
zaguan show info <texto>
zaguan show debug <texto>
zaguan show notice <texto>
zaguan show critical <texto>
zaguan show alert <texto>
zaguan show emergency <texto>
zaguan show happy <texto>
zaguan show sad <texto>
```

| Subcomando | Función interna | Color/icono |
|---|---|---|
| `success` | `Printer.Basics.print_success/2` | Verde + ✓ |
| `error` | `Printer.Basics.print_error/2` | Rojo + ✗ |
| `warning` | `Printer.Basics.print_warning/2` | Amarillo + ⚠ |
| `info` | `Printer.Basics.print_info/2` | Cyan + ℹ |
| `debug` | `Printer.Basics.print_debug/2` | Gris |
| `notice` | `Printer.Basics.print_notice/2` | Azul |
| `critical` | `Printer.Basics.print_critical/2` | Magenta |
| `alert` | `Printer.Basics.print_alert/2` | Rojo |
| `emergency` | `Printer.Basics.print_emergency/2` | Rojo |
| `happy` | `Printer.Basics.print_happy/2` | Verde |
| `sad` | `Printer.Basics.print_sad/2` | Azul |

**Flujo interno:** los argumentos restantes se unen con espacio como texto; se llama la función tipada de `Printer.Basics` con `global_opts_to_printer(global)`.

---

### 3.3 `show header`

**Módulo:** `Zaguan.CLI.Commands.Show.Header` — `run/1`

```
zaguan show header <título> [options]
```

| Argumento / Opción | Tipo | Default | Descripción | Función interna |
|---|---|---|---|---|
| `<título>` | posicional | — | Texto del header (posicionales unidos) | `Enum.join(positional, " ")` |
| `--subtitle TEXT` | string | — | Subtítulo bajo el título | `Keyword.get(opts, :subtitle)` |
| `--size TYPE` | string | `medium` | `small`, `medium`, `large` | `String.to_atom/1` |
| `--color COLOR` | string | — | Color del título | `Orchestrator.parse_color/1` |
| `--subtitle-color COLOR` | string | — | Color del subtítulo | `Orchestrator.parse_color/1` |
| `--width N` | integer | `80` | Ancho total del header | `Keyword.get(opts, :width, 80)` |

**Flujo:** `HeaderComp.render(title, opts)` → `Printer.print_raw/2`

---

### 3.4 `show separator`

**Módulo:** `Zaguan.CLI.Commands.Show.Separator` — `run/1`

```
zaguan show separator [options]
```

| Opción | Tipo | Default | Descripción | Función interna |
|---|---|---|---|---|
| `--char TEXT` | string | `"─"` | Carácter de la línea | `Keyword.get(opts, :char, "─")` |
| `--width N` | integer | `60` | Ancho de la línea | `Keyword.get(opts, :width, 60)` |
| `--text TEXT` | string | — | Texto centrado en la línea | `Keyword.get(opts, :text)` |
| `--color COLOR` | string | — | Color de la línea | `Orchestrator.parse_color/1` |

**Flujo:** `SepComp.render(text, opts)` → `Printer.print_raw/2`

---

### 3.5 `show gradient`

**Módulo:** `Zaguan.CLI.Commands.Show.Gradient` — `run/1`

```
zaguan show gradient <texto> --from COLOR --to COLOR [options]
zaguan show gradient <texto> --colors "C1;C2;C3" [options]
```

| Argumento / Opción | Tipo | Default | Descripción | Función interna |
|---|---|---|---|---|
| `<texto>` | posicional | — | Texto a colorear | Primer elemento de positional |
| `--from COLOR` | string | `"#FF0000"` | Color inicial del gradiente | `Orchestrator.parse_color/1` |
| `--to COLOR` | string | `"#0000FF"` | Color final del gradiente | `Orchestrator.parse_color/1` |
| `--colors "C1;C2;..."` | string | — | Gradiente multi-color (sobreescribe `--from/--to`) | `Parser.parse_color_list/1` → si ≥2 colores: `Gradients.multicolor/2` |
| `--direction DIR` | string | `left_to_right` | `left_to_right`, `right_to_left` | `String.to_atom/1` |
| `--bg` | boolean | `false` | Aplicar gradiente al fondo | `Gradients.apply_bg_to_text/4` |
| `--text-color COLOR` | string | — | Color de texto con `--bg` | `Parser.parse_color_opt/1` |

**Flujo:**
1. Si `--colors` con ≥2 colores: `Gradients.multicolor(colors, String.length(text))` → aplica color por carácter
2. Si no: `Gradients.apply_to_text/4` (fg) o `Gradients.apply_bg_to_text/4` (bg)
3. Si `global.box`: `Box.render/2`
4. `Printer.print_raw/2`

---

### 3.6 `show table`

**Módulo:** `Zaguan.CLI.Commands.Show.Table` — `run/1`

```
zaguan show table --headers "H1;H2;H3" --rows "A;B;C" [options]
zaguan show table --headers "H1;H2" --rows "A;B" --rows "C;D" [options]
```

| Opción | Tipo | Default | Descripción | Función interna |
|---|---|---|---|---|
| `--headers LIST` | string | `""` | Cabeceras separadas por `;` | `String.split(str, ";")` |
| `--rows LIST` | string, repetible | — | Filas: celdas por `;`, filas múltiples por `\|`. Repetible. | `Keyword.get_values(opts, :rows)` → split por `\|` → split por `;` |
| `--border TYPE` | string | `normal` | `normal`, `rounded`, `double`, `single`, `none` | `String.to_atom/1` |
| `--padding N` | integer | `1` | Padding de celdas | `Keyword.get(opts, :padding, 1)` |
| `--border-color COLOR` | string | — | Color del borde | `Parser.parse_color_opt/1` |
| `--border-effects EFFS` | string | — | Efectos del borde: `bold`, `underline`, `italic` (separados por `,`) | Split por `,` → `String.to_atom/1` |
| `--table-align TYPE` | string | — | Alineación del bloque de tabla | `String.to_atom/1` |
| `--headers-color COLORS` | string | — | Color(es) de cabeceras; uno = todos, varios = por columna (separados por `;`) | `Parser.parse_color_list/1` |
| `--headers-align ALIGNS` | string | — | Alineación por columna de cabecera (separados por `,`) | Split por `,` → átomo |
| `--headers-effects EFFS` | string | — | Efectos de cabeceras | Split por `,` → átomo |
| `--rows-color COLORS` | string | — | Color(es) de filas | `Parser.parse_color_list/1` |
| `--rows-align ALIGNS` | string | — | Alineación por columna de filas | Split por `,` → átomo |
| `--rows-effects EFFS` | string | — | Efectos de filas | Split por `,` → átomo |

**Flujo:** `TableComp.render([headers | rows], table_opts)` → `Printer.print_raw/2`

---

### 3.7 `show json`

**Módulo:** `Zaguan.CLI.Commands.Show.Json` — `run/1`

```
zaguan show json '<json_string>' [options]
```

| Argumento / Opción | Tipo | Default | Descripción | Función interna |
|---|---|---|---|---|
| `<json_string>` | posicional | — | JSON como string (posicionales unidos) | `Jason.decode/1` para validar |
| `--indent N` | integer | `2` | Espacios de indentación | `Keyword.get(opts, :indent)` |
| `--key-color COLOR` | string | — | Color de claves de objetos | `Orchestrator.parse_color/1` |
| `--string-color COLOR` | string | — | Color de strings | `Orchestrator.parse_color/1` |
| `--number-color COLOR` | string | — | Color de números | `Orchestrator.parse_color/1` |
| `--boolean-color COLOR` | string | — | Color de booleanos | `Orchestrator.parse_color/1` |
| `--null-color COLOR` | string | — | Color de null | `Orchestrator.parse_color/1` |

**Validación:** si `Jason.decode/1` falla, imprime `"Invalid JSON: <input>"` en stderr.

**Flujo:** `Jason.decode/1` → `JsonComp.render(data, json_opts)` → `Printer.print_raw/2`

---

### 3.8 `show bar`

**Módulo:** `Zaguan.CLI.Commands.Show.Bar` — `run/1`

```
zaguan show bar <value> [options]
```

| Argumento / Opción | Tipo | Default | Descripción | Función interna |
|---|---|---|---|---|
| `<value>` | posicional | — | Valor actual (integer) | `String.to_integer/1` |
| `--max N` | integer | `100` | Valor máximo | `Keyword.get(opts, :max, 100)` |
| `--label TEXT` | string | — | Etiqueta junto a la barra | `Keyword.get(opts, :label)` |
| `--width N` | integer | `40` | Ancho en caracteres | `Keyword.get(opts, :width, 40)` |
| `--filled-char CHAR` | string | `▓` | Carácter de relleno | `Keyword.get(opts, :filled_char)` |
| `--empty-char CHAR` | string | `░` | Carácter vacío | `Keyword.get(opts, :empty_char)` |
| `--filled-color COLOR` | string | — | Color de la parte rellena | `Orchestrator.parse_color/1` |
| `--empty-color COLOR` | string | — | Color de la parte vacía | `Orchestrator.parse_color/1` |
| `--show-percent BOOL` | boolean | `true` | Mostrar porcentaje | `Keyword.get(opts, :show_percent, true)` |

**Flujo:** `BarComp.render(value, max, bar_opts)` → `Printer.print_raw/2`

---

### 3.9 `show animated-bar`

**Módulo:** `Zaguan.CLI.Commands.Show.AnimatedBar` — `run/1`

```
zaguan show animated-bar <value> [options]
zaguan show animated-bar --value N [options]
```

| Argumento / Opción | Tipo | Default | Descripción | Función interna |
|---|---|---|---|---|
| `<value>` | posicional | — | Valor actual (integer) | `Integer.parse/1` |
| `--value N` | integer | — | Alternativa al posicional | `Keyword.get(opts, :value)` |
| `--max N` | integer | `100` | Valor máximo | `Keyword.get(opts, :max, 100)` |
| `--text TEXT` | string | — | Texto junto a la barra | `Keyword.get(opts, :text)` |
| `--type TYPE` | string | `spinner` | `spinner`, `kitt` | `parse_type/1` → `:spinner` o `:kitt` |
| `--width N` | integer | `40` | Ancho (mapeado a `:length`) | `Keyword.get(opts, :width, 40)` |
| `--filled-char CHAR` | string | — | Carácter de relleno | `Keyword.get(opts, :filled_char)` |
| `--empty-char CHAR` | string | — | Carácter vacío | `Keyword.get(opts, :empty_char)` |
| `--filled-color COLOR` | string | — | Color parte rellena | `Orchestrator.parse_color/1` |
| `--empty-color COLOR` | string | — | Color parte vacía | `Orchestrator.parse_color/1` |
| `--animation-color COLOR` | string | — | Color del indicador de animación | `Orchestrator.parse_color/1` |
| `--speed N` | integer | `100` | ms por frame | `Keyword.get(opts, :speed, 100)` |
| `--duration N` | integer | `5` | Segundos de animación | `Keyword.get(opts, :duration, 5)` |
| `--show-percent BOOL` | boolean | `true` | Mostrar porcentaje | `Keyword.get(opts, :show_percent, true)` |
| `--kitt-width N` | integer | `3` | Ancho del scanner KITT | `Keyword.get(opts, :kitt_width, 3)` |

**Flujo:** `iterations = div(duration * 1000, speed)`. En modo normal: `IO.write("\\r#{frame}")` + `Process.sleep(speed)`. En `--verbose`: `IO.puts/1` por cada frame. Delega frame a `ABComp.render_frame(current, max, f, bar_opts)`.

---

### 3.10 `show breadcrumbs`

**Módulo:** `Zaguan.CLI.Commands.Show.Breadcrumbs` — `run/1`

```
zaguan show breadcrumbs <item1> [item2 ...] [options]
```

| Argumento / Opción | Tipo | Default | Descripción | Función interna |
|---|---|---|---|---|
| `<items>` | posicionales | — | Elementos del path | Argumento `items` de `OptionParser` |
| `--separator TEXT` | string | `›` | Separador entre items | `Keyword.get(opts, :separator)` |
| `--color COLOR` | string | cyan | Color de los items | `Orchestrator.parse_color/1` → `:item_color` |
| `--current-color COLOR` | string | white | Color del último item | `Orchestrator.parse_color/1` → `:current_color` |
| `--separator-color COLOR` | string | gray | Color del separador | `Orchestrator.parse_color/1` → `:separator_color` |

**Flujo:** `BCComp.render(items, bc_opts)` → `Printer.print_raw/2`

---

### 3.11 `show animate`

**Módulo:** `Zaguan.CLI.Commands.Show.Animate` — `run/1`

```
zaguan show animate [options]
```

| Opción | Tipo | Default | Descripción | Función interna |
|---|---|---|---|---|
| `--type TYPE` | string | `spinner` | `spinner`, `dots`, `bar`, `moon`, `clock`, `pulse`, `kitt` | `Map.get(@frames, type)` |
| `--duration N` | integer | `3` | Duración en segundos | `iterations = duration * div(1000, speed)` |
| `--text TEXT` | string | `Loading` | Texto junto a la animación | `Keyword.get(opts, :text, "Loading")` |
| `--speed N` | integer | `100` | ms por frame | `Keyword.get(opts, :speed, 100)` |
| `--chars CHARS` | string | — | Frames personalizados separados por `,` | Sobreescribe `--type` |
| `--color COLOR` | string | cyan | Color de la animación (o lista separada por `;`) | `parse_colors/2` → lista de `{r,g,b}` |
| `--colors LIST` | string | — | Mismo que `--color`, acepta múltiples | `parse_colors/2` |

**Flujo:** si tipo es `kitt` → `run_kitt/6`; si no → `run_animation/6`. En modo normal: `\\r` para reescribir la línea. En `--verbose`: una línea por frame.

**Tipos de animación predefinidos:**

| Tipo | Frames |
|---|---|
| `spinner` | ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏ |
| `dots` | ⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷ |
| `bar` | ▏ ▎ ▍ ▌ ▋ ▊ ▉ █ ... |
| `moon` | 🌑 🌒 🌓 🌔 🌕 🌖 🌗 🌘 |
| `clock` | 🕐 … 🕛 |
| `pulse` | █ ▓ ▒ ░ ▒ ▓ |
| `kitt` | Efecto scanner izquierda-derecha con degradado |

---

### 3.12 `show image`

**Módulo:** `Zaguan.CLI.Commands.Show.Image` — `run/1`

```
zaguan show image --path <file> [options]
```

| Opción | Tipo | Default | Descripción | Función interna |
|---|---|---|---|---|
| `--path FILE` | string | — | Ruta al archivo (requerido) | `Keyword.get(opts, :path)` → `File.exists?/1` |
| `--width N` | integer | `40` | Ancho objetivo en celdas | `Keyword.get(opts, :width, 40)` |
| `--height N` | integer | `20` | Alto objetivo en celdas | `Keyword.get(opts, :height, 20)` |
| `--protocol TYPE` | string | auto | `kitty`, `iterm2`, `sixel`, `ascii` | `String.to_atom/1` |

**Validaciones:**
- Si `--path` no se especifica o el archivo no existe, muestra error
- Si `--raw` activo pero `pos_x` y `pos_y` son ambos 0, muestra error

**Flujo:** si `global.raw` → escribe secuencia ANSI de posicionamiento (`\\e[row;colH`). `ImageRenderer.render_file(path, render_opts)` con `:align`, `:width`, `:height`, `:protocol` (si se especificó).

---

### 3.13 `show list`

**Módulo:** `Zaguan.CLI.Commands.Show.List` — `run/1`

```
zaguan show list <item1> [item2 ...] [options]
zaguan show list --header TEXT <item1> [item2 ...] [options]
```

| Argumento / Opción | Tipo | Default | Descripción | Función interna |
|---|---|---|---|---|
| `<items>` | posicionales | — | Items de la lista | Argumento `items` de `OptionParser` |
| `--header TEXT` | string | — | Título de la lista | Si presente: `Printer.Interactive.menu/3`; si no: itera con `%ChunkText{}` y bullet `"  • "` |
| `--color COLOR` | string | — | Color del texto y bullets | `Orchestrator.parse_color/1` |
| `--align TYPE` | string | `left` | Alineación (de GlobalOpts) | `global.align` |

---

### 3.14 `show ask`

**Módulo:** `Zaguan.CLI.Commands.Show.Ask` — `run/1`

```
zaguan show ask <question> [options]
```

| Argumento / Opción | Tipo | Default | Descripción | Función interna |
|---|---|---|---|---|
| `<question>` | posicional | — | Texto de la pregunta (posicionales unidos) | `Enum.join(positional, " ")` |
| `--color COLOR` | string | — | Color de la pregunta | `Orchestrator.parse_color/1` |
| `--align TYPE` | string | `left` | Alineación | `String.to_atom/1` |

**Flujo:** `Printer.Interactive.question(question, color: color, align: align)` → `IO.write(answer)`

La respuesta del usuario se escribe en stdout.

---

### 3.15 `show menu`

**Módulo:** `Zaguan.CLI.Commands.Show.Menu` — `run/1`

```
zaguan show menu <header> <item1> [item2 ...] [options]
zaguan show menu --header TEXT <item1> [item2 ...] [options]
```

| Argumento / Opción | Tipo | Default | Descripción | Función interna |
|---|---|---|---|---|
| `<header>` | posicional[0] | — | Primer posicional como header (si no se usa `--header`) | `Enum.at(items, 0)` |
| `<items>` | posicionales[1+] | — | Opciones del menú | `Enum.drop(items, 1)` si no hay `--header` |
| `--header TEXT` | string | — | Header explícito (todos los posicionales son items) | `Keyword.get(opts, :header)` |
| `--color COLOR` | string | — | Color de los items | `Orchestrator.parse_color/1` |
| `--align TYPE` | string | `left` | Alineación | `String.to_atom/1` |

**Flujo:** items → `Enum.map(fn item -> {item, item} end)` → `Printer.Interactive.question_with_options("Selection", options, opts)` → `IO.write(to_string(answer))`

La selección del usuario se escribe en stdout.

---

### 3.16 `show yesno`

**Módulo:** `Zaguan.CLI.Commands.Show.YesNo` — `run/1`

```
zaguan show yesno <question> [options]
```

| Argumento / Opción | Tipo | Default | Descripción | Función interna |
|---|---|---|---|---|
| `<question>` | posicional | — | Texto de la pregunta | `Enum.join(positional, " ")` |
| `--default TYPE` | string | `no` | `yes`, `y` → `:yes`; cualquier otro → `:no` | Comparación de string → átomo |
| `--color COLOR` | string | — | Color de la pregunta | `Orchestrator.parse_color/1` |
| `--align TYPE` | string | `left` | Alineación | `String.to_atom/1` |

**Flujo:** `Printer.Interactive.yesno(question, default: default, color: color, align: align)` → escribe `"yes"` o `"no"` en stdout.

---

## 4. `zaguan run`

**Módulo:** `Zaguan.CLI.Commands.Run` — `run/1`

Ejecuta comandos shell con animación de progreso y soporte de paralelismo.

```
zaguan run --command "cmd1" [--command "cmd2" ...] [options]
```

### Argumentos

| Opción | Tipo | Default | Descripción | Función interna |
|---|---|---|---|---|
| `--command CMD` | string, **repetible** | — | Comando a ejecutar (requerido al menos uno) | `Parser.collect_repeated(args, "--command")` |
| `--parallel N` | integer | `1` | Máx. workers concurrentes | `Keyword.get(opts, :parallel, 1)` |
| `--timeout MS` | integer | `30000` | Timeout por comando en ms | `Keyword.get(opts, :timeout, 30_000)` |
| `--quiet / -q` | boolean | `false` | Suprimir output de progreso | `global.quiet or Enum.any?(args, ...)` |
| `--log` | boolean | `false` | Habilitar logging | `Keyword.get(opts, :log)` |
| `--shell PATH` | string | `sh` | Shell a usar | `validate_shell/1` → `File.exists?/1` |
| `--cd PATH` | string | cwd | Directorio de trabajo | `Keyword.get(opts, :cd)` |
| `--env KEY=VAL` | string, **repetible** | — | Variables de entorno | `Parser.collect_repeated(args, "--env")` → `Parser.parse_env_pair/1` → `Map.new/1` |
| `--shell-config PATH` | string | — | Archivo de config del shell | `Keyword.get(opts, :shell_config)` |
| `--header TEXT` | string | `"Zaguan Run"` | Texto del header | `Keyword.get(opts, :header, "Zaguan Run")` |
| `--header-color COLOR` | string | — | Color del header | `parse_color/1` |
| `--subtitle TEXT` | string | `"N command(s)"` | Subtítulo | `Keyword.get(opts, :subtitle, ...)` |
| `--subtitle-color COLOR` | string | — | Color del subtítulo | `parse_color/1` |
| `--align TYPE` | string | `left` | Alineación de la salida | `Parser.parse_align/1` |
| `--animation-type TYPE` | string | `spinner` | Tipo de animación: `spinner`, `dots`, `bar`, `moon`, `clock`, `pulse`, `kitt` | `Map.get(@animation_frames, type)` |
| `--animation-color COLOR` | string | cyan | Color(es) de animación, separados por `;` o `,` | `parse_anim_colors/1` → lista de `{r,g,b}` |
| `--animation-chars CHARS` | string | — | Frames personalizados separados por `,` | Sobreescribe `--animation-type` |
| `--asdf-elixir VERSION` | string | — | Versión Elixir con ASDF | `Keyword.get(opts, :asdf_elixir)` |
| `--asdf-erlang VERSION` | string | — | Versión Erlang con ASDF | `Keyword.get(opts, :asdf_erlang)` |
| `--asdf-node VERSION` | string | — | Versión Node con ASDF | `Keyword.get(opts, :asdf_node)` |

### Validación y flujo interno

1. **Recolección de comandos:** `Parser.collect_repeated(args, "--command")` — soporta `--command "cmd"` y `--command=cmd`. Si la lista está vacía → error + `System.halt(1)`.
2. **Validación de seguridad:** `Validator.validate_commands(commands)` — si retorna `{:error, errors}`, imprime cada error con índice y `System.halt(1)`.
3. **Ejecución:**
   - Modo normal (`--quiet` = false): `execute_animated/3` — lanza todas las tareas con `Task.async/1`, renderiza un loop de animación con `anim_loop/2` que reescribe la terminal (`\\e[NA` para mover cursor + `\\r\\e[K` por línea). Al finalizar, muestra resumen de resultados.
   - Modo silencioso (`--quiet` = true): `execute_quiet/2` — spawn por comando, `IO.puts/1` del stdout si el exit code es 0.
4. **Ejecución de cada comando:** `Command.execute(cmd, cmd_opts)` retorna `{:ok, %{exit_code: N, stdout: S, duration_ms: N}}` o `{:error, reason}`.

---

## 5. `zaguan color`

**Módulo:** `Zaguan.CLI.Commands.Color` — `run/1`

Análisis de colores, armonías, conversiones y manipulación de tono.

```
zaguan color <color> [options]
zaguan color --colors [cols...]
```

### Argumentos

| Argumento / Opción | Tipo | Default | Descripción | Función interna |
|---|---|---|---|---|
| `<color>` | posicional | — | Color a analizar (cualquier formato soportado) | `Validator.validate/1` → `Orchestrator.parse_color/1` |
| `--harmony TYPE` | string | — | Tipo de armonía | `parse_harmony/1`: normaliza, reemplaza `-` por `_` → átomo |
| `--darken N` | integer | — | Oscurecer N pasos (1-10) | `Harmonies.darker(rgb, N * 0.1)` |
| `--lighten N` | integer | — | Aclarar N pasos (1-10) | `Harmonies.lighter(rgb, N * 0.1)` |
| `--colors [COLS...]` | boolean + posicionales | — | Listar colores del tema activo | `Zaguan.Config.Colours.current_colors()` |
| `--lab` | boolean | `false` | Incluir valores CIELAB | `Conversions.rgb_to_lab/1` |
| `--xyz` | boolean | `false` | Incluir valores CIE XYZ | `Conversions.rgb_to_xyz/1` |
| `--kelvin` | boolean | `false` | Incluir temperatura de color | `Conversions.rgb_to_kelvin/1` |
| `--pantone` | boolean | `false` | Mostrar aproximación Pantone | `Conversions.rgb_to_pantone_approx/1` |
| `--contrast COLOR` | string | — | Contraste WCAG y ΔE vs otro color | `Conversions.contrast_ratio/2`, `Conversions.delta_e/2` |

### Tipos de armonía

| Valor | Átomo | Descripción |
|---|---|---|
| `triad` | `:triad` | 3 colores a 120° |
| `complementary` | `:complementary` | Color opuesto (180°) |
| `analogous` | `:analogous` | Colores adyacentes (±30°) |
| `square` | `:square` | 4 colores a 90° |
| `monochromatic` | `:monochromatic` | Variaciones del mismo color |
| `compound` | `:compound` | Complementario + análogos |
| `split-complementary` | `:split_complementary` | Complementario flanqueado ±30° |

### Columnas opcionales para `--colors`

`rgb`, `argb`, `hsl`, `hsv`, `hwb`, `cmyk`, `xterm`, `lab`, `xyz`, `kelvin`, `pantone`, `luminance`, `all` (todas las columnas)

### Flujo interno

1. Si `--colors`: `show_all_colors(global, positional)` — lee `Config.Colours.current_colors()`, construye tabla con columnas solicitadas
2. Si no: `analyze(color_str, opts, global)`:
   - Valida con `Validator.validate/1`
   - Parsea con `Orchestrator.parse_color/1`
   - Aplica `apply_tone/2` (darken/lighten)
   - Si `global.verbose`: `output_raw_json/2` (serializa a JSON con Jason)
   - Si no: `render_visual/3` — construye tabla de conversiones + rueda de color
3. Si el terminal soporta imágenes: `ColorWheel.render_png_wheel/1`; si no: `ColorWheel.get_ascii_wheel_lines/2` con layout side-by-side

---

## 6. `zaguan action`

**Módulo:** `Zaguan.CLI.Commands.Action` — `run/1`

Ejecuta comandos Zaguan a partir de entrada JSON.

```
zaguan action --file FILE
zaguan action --data JSON
zaguan action --stdin
echo '{"command": "show", "args": ["success", "OK"]}' | zaguan action
```

### Opciones

| Opción | Alias | Tipo | Descripción | Función interna |
|---|---|---|---|---|
| `--file PATH` | `-f` | string | Leer JSON desde archivo | `File.read!/1` (valida existencia) |
| `--data JSON` | `-d` | string | JSON inline como string | Uso directo del valor |
| `--stdin` | `-s` | boolean | Forzar lectura desde stdin | `IO.binread(:stdio, :eof)` con fallback |
| `--quiet` | `-q` | boolean | Modo silencioso | `Keyword.get(opts, :quiet)` |

### Prioridad de fuente JSON

`--stdin` > `--file` > `--data` > (sin flags → stdin implícito)

### Esquema JSON soportado

**Acción única:**
```json
{
  "command": "show",
  "args": ["success", "Operación completada"]
}
```

**Acciones en lote:**
```json
{
  "verbose": true,
  "quiet": false,
  "actions": [
    {"command": "show", "args": ["info", "Paso 1"], "order": 0},
    {"command": "show", "args": ["success", "Completado"], "order": 1}
  ]
}
```

Campos alternativos: `"action"` en lugar de `"command"`, `"params"` en lugar de `"args"`.

### Flujo interno

1. `get_json(opts)` — obtiene el JSON según la fuente
2. `Jason.decode/1` — si falla: error + `System.halt(1)`
3. Si tiene `"actions"` array: ordena por `"order"`, ejecuta cada mapa
4. Si es objeto único: extrae globals, ejecuta el objeto
5. Por cada acción (`execute/2`):
   - Extrae `"command"` y `"args"`
   - Si comando contiene espacios: `String.split/2`
   - Aplica opciones globales: `verbose: true` en show/color → añade `"--verbose"`; `quiet: true` en run → añade `"--quiet"`
   - **Validación de seguridad:** si el primer token es `"run"`, llama `Validator.validate_commands/1`; si falla: error + `System.halt(1)`
   - Llama `Zaguan.CLI.main(full_args)`

---

## 7. `zaguan config`

**Módulo:** `Zaguan.CLI.Commands.Config` — `run/1`

Gestión de configuración de Zaguan y temas.

```
zaguan config <action> [args]
zaguan config --show
```

### Subcomandos

#### `zaguan config init`
Crea la estructura de directorios y archivos de configuración por defecto.

**Proceso:**
1. `File.mkdir_p("~/.config/zaguan")` y `"~/.config/zaguan/themes"`
2. Escribe 5 archivos JSON de tema si no existen: `default.json`, `dracula.json`, `monokai.json`, `nord.json`, `light.json`
3. Escribe `zaguan.conf` con valores por defecto si no existe

**Función interna:** `init_config/0`

---

#### `zaguan config get <key>`
Lee un valor de configuración.

**Validación:** la clave debe estar en `@config_keys = [:color_depth, :theme_active, :refresh_rate, :double_buffer, :max_workers, :default_policy]`. Si no: error en stderr + lista de claves válidas.

**Función interna:** `Zaguan.Config.Global.get(key)` → imprime `"  key: value"`

---

#### `zaguan config set <key> <value>`
Establece un valor de configuración.

**Validaciones por clave:**

| Clave | Validación | Valores aceptados |
|---|---|---|
| `color_depth` | `String.to_atom(v) in [:truecolor, :xterm256, :ansi16]` | `truecolor`, `xterm256`, `ansi16` |
| `refresh_rate` | `Integer.parse(v)` → rango 1–120 | Entero 1–120 |
| `double_buffer` | `parse_bool/1` | `true`, `false`, `1`, `0` |
| `max_workers` | `Integer.parse(v)` → rango 1–1000 | Entero 1–1000 |
| `default_policy` | `String.to_atom(v) in [:retry, :fail_fast, :noop]` | `retry`, `fail_fast`, `noop` |
| `theme_active` | Verifica existencia del archivo de tema | Nombre de tema existente |

**Flujo:** `Global.set(key, value)` → `Loader.set_config_value(key, value)`

---

#### `zaguan config theme list`
Lista los temas disponibles en `~/.config/zaguan/themes/`. Marca el tema activo con `← active`.

**Función interna:** `list_themes/0` → `File.ls/1` → filtra `.json` → `show_themes/1`

---

#### `zaguan config theme set <name>`
Establece el tema activo.

**Validación:** verifica que exista `~/.config/zaguan/themes/<name>.json`.

**Flujo:**
1. `Application.put_env(:zaguan, :theme_active, String.to_atom(name))`
2. `Loader.set_config_value(:theme_active, name)`
3. `apply_theme(name)` → `Loader.load_theme(name)` → extrae `"colors"` → `Application.put_env(:zaguan, :theme_colors, colors)` + `Global.set(:theme_active, atom)`

---

#### `zaguan config --show`
Imprime la configuración actual completa.

**Claves mostradas:** `color_depth`, `theme_active`, `refresh_rate`, `double_buffer`, `max_workers`, `default_policy`, `config_path`

**Función interna:** `show_config/0` — `Global.get/1` por cada clave

---

## 8. Formatos de color aceptados

Todos los parámetros de tipo `COLOR` en cualquier comando aceptan los siguientes formatos, procesados por `Zaguan.Drawer.Colour.Orchestrator.parse_color/1`:

| Formato | Ejemplo |
|---|---|
| Hex 6 dígitos | `#BADA55`, `#FF0000` |
| Hex 3 dígitos | `#F00`, `#0F0` |
| RGB funcional | `rgb(255, 0, 0)` |
| RGB tuple | `255,0,0` |
| Nombre CSS | `red`, `blue`, `cyan`, `magenta`, `yellow`, `green`, `white`, `black`, `gray` |
| Nombre Zaguan | `primary`, `secondary`, `success`, `error`, `warning`, `info` |
| Nombre de tema | `theme:primary`, `theme:secondary` |
| XTerm 256 | `xterm:196` |
| HSL | `hsl(120, 100%, 50%)` |
| HSV | `hsv(120, 100%, 50%)` |
| ARGB | `argb(255, 255, 0, 0)` |
| Átomo Elixir | `:red`, `:blue` (en contextos internos) |

Los colores se normalizan siempre a tuplas `{r, g, b}` donde cada componente es un byte (0–255).

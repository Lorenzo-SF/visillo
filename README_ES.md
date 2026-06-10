# Visillo — Framework Declarativo de TUIs para Elixir

[![Elixir](https://img.shields.io/badge/Elixir-%7E%3E%201.19-purple)](https://elixir-lang.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Visillo es un framework declarativo para crear Interfaces de Usuario de Terminal (TUIs) interactivas en Elixir. Sigue The Elm Architecture (TEA) — Modelo, Actualización, Vista — con un DSL de widgets componible, motor de layout flexbox, renderizado por diff, eventos de teclado/ratón, animaciones y un sistema de temas integrado.

> **Ecosistema**: Visillo se apoya en tres librerías hermanas:
> - **[Alaja](https://github.com/lorenzo-sf/alaja)** — buffer de celdas de terminal, drivers ANSI y primitivas de renderizado (`Buffer`, `Cell`, ANSI, Printer)
> - **[Pote](https://github.com/lorenzo-sf/pote)** — parseo de colores, armonías, gradientes y paletas
> - **[Arrea](https://github.com/lorenzo-sf/arrea)** — orquestación de procesos para cargas de trabajo paralelas

## Inicio Rápido

```elixir
defmodule MiApp.TUI do
  use Visillo.Component

  defstruct [:contador]

  @impl true
  def init(_props), do: {:ok, %__MODULE__{contador: 0}}

  @impl true
  def focusable?, do: true

  @impl true
  def handle_key("+", [], state), do: {:send, :incrementar}
  def handle_key("-", [], state), do: {:send, :decrementar}
  def handle_key("q",  [], _state), do: {:quit, :usuario}
  def handle_key(_, _, _), do: :ignore

  @impl true
  def update(:incrementar, state), do: {:ok, %{state | contador: state.contador + 1}}
  def update(:decrementar, state), do: {:ok, %{state | contador: state.contador - 1}}

  @impl true
  def render(state, theme) do
    box(border: :rounded, title: "Contador", title_align: :center) do
      [
        text("Cuenta: #{state.contador}", bold: true, color: theme.primary, align: :center),
        separator(),
        text("Pulsa + / - para contar, q para salir", color: :info, align: :center, italic: true)
      ]
    end
  end
end

Visillo.App.run(MiApp.TUI, theme: :default)
```

## Características

- **DSL Declarativo de Widgets** — compone interfaces con `box`, `text`, `button`, `input`, `list`, `table`, `tabs`, `menu`, `modal`, `chart`, `tree_view`, `split_pane`, `panel` y más
- **Librería de Widgets Compuestos** — componentes pre-construidos: `Tabs`, `TreeView`, `SplitPane`, `TextInput`, `Button`, `Checkbox`, `Label`, `Panel` — cada uno usable como componente independiente o incrustado en otro
- **Motor de Layout Flexbox** — contenedores en columna, fila, grid y scroll con `flex_grow`, `flex_shrink`, `padding`, `margin` y alineación
- **Gestión de Foco** — navegación Tab / Shift+Tab entre componentes focusables, gestionada por `Visillo.Focus`
- **Eventos de Teclado** — captura raw de teclas con detección de modificadores (Ctrl, Alt, Shift), parseo de secuencias de escape ANSI y enrutamiento en tres capas (global → sistema → componente)
- **Eventos de Ratón** — soporte del protocolo SGR para click, arrastre y scroll
- **Sistema de Animación** — motor de ticks por frame con 9 estilos de spinner integrados (`:dots`, `:line`, `:moon`, `:clock`, `:pulse`, `:bounce`, `:braille`, `:grow`, `:dots2`) y soporte para secuencias de frames personalizadas
- **Sistema de Temas** — 6 temas integrados (default, dracula, tokyo_night, gruvbox, catppuccin, nord) con paleta de colores semántica (primary, secondary, success, error, warning, info, focus, border, etc.)
- **Renderizador por Diff** — compara buffers de frames consecutivos y emite solo las celdas modificadas con codificación run-length para mínima salida ANSI y cero parpadeo
- **Ciclo de Vida de Componentes** — init → render → update → cleanup, con callbacks opcionales `handle_key`, `handle_mouse`, `handle_resize`, `handle_focus`, `handle_blur`, `handle_tick` y `subscriptions`
- **Bus de Eventos** — pub/sub para comunicación desacoplada entre componentes
- **Texto Enriquecido** — color, fondo, negrita, cursiva, subrayado, tachado, atenuado, alineación y truncado
- **Arquitectura Elm** — siguiendo el patrón Model-Update-View de The Elm Architecture
- **Demos vía Mix Tasks** — 8 aplicaciones de demostración accesibles mediante tareas Mix

## Arquitectura

```
Visillo.App.run/2
  │
  ├── Visillo.RuntimeSupervisor (:rest_for_one)
  │   ├── Visillo.Screen         (GenServer — buffer + renderizador diff)
  │   ├── Visillo.Focus          (GenServer — navegación Tab/Shift+Tab)
  │   ├── Visillo.EventBus       (GenServer — pub/sub entre componentes)
  │   ├── Visillo.Animation      (GenServer — ticks de frame a FPS configurable)
  │   ├── Visillo.EventRouter    (GenServer — enrutamiento de input en 3 capas)
  │   └── Visillo.Input          (GenServer — captura raw de stdin, parseo ANSI)
  │
  ├── Visillo.Layout             (motor flexbox con resolución de constraints)
  │   └── Visillo.Layout.Constraint  (ancho, alto, flex, margen, padding)
  │
  ├── Visillo.Render.Renderer    (funciones puras: árbol de widgets → Alaja.Buffer)
  │   ├── Visillo.Render.Border  (dibujo de cajas: rounded, single, double, bold, ascii)
  │   └── Visillo.Render.TextWrap    (wrap por palabra y por carácter)
  │
  ├── Visillo.Theme              (paleta de colores y helpers ANSI)
  ├── Visillo.Widget             (struct descriptor de widgets)
  ├── Visillo.DSL                (sintaxis declarativa basada en macros)
  └── Visillo.Component          (behaviour + callbacks por defecto)
```

### Flujo de Eventos

```
stdin → Visillo.Input (modo raw byte a byte)
           │
           ▼
      Visillo.EventRouter
           │
           ├── Capa 1: GLOBAL (teclas de salida: "q", "ctrl+c")
           ├── Capa 2: SISTEMA  (Tab → focus_next, Shift+Tab → focus_prev)
           └── Capa 3: COMPONENTE → handle_key/3 o handle_mouse/2
                    │
                    ▼
              Visillo.App (event loop + gestión de estado)
                    │
                    ├── update/2  (mensajes: {:send, msg})
                    ├── render/2  (estado, tema → árbol de widgets)
                    │       │
                    │       ▼
                    │   Visillo.Layout.compute/3
                    │   Visillo.Render.Renderer.render/4
                    │       │
                    │       ▼
                    │   Visillo.Screen.render/2 (diff + salida ANSI)
                    │
                    └── handle_tick/2 (animación por frame, 30 FPS por defecto)
```

## Referencia de la API

### Visillo.Component

El behaviour principal. `use Visillo.Component` inyecta los imports de `Visillo.DSL` y provee implementaciones por defecto para todos los callbacks opcionales.

| Callback | Firma | Por defecto |
|---|---|---|
| `init/1` | `(props) → {:ok, state} \| {:error, reason}` | **obligatorio** |
| `render/2` | `(state, theme) → Widget.t()` | **obligatorio** |
| `update/2` | `(msg, state) → {:ok, state} \| {:ok, state, cmd}` | `{:ok, state}` |
| `handle_key/3` | `(key, mods, state) → :ignore \| {:send, msg} \| {:quit, reason}` | `:ignore` |
| `handle_mouse/2` | `(event, state) → :ignore \| {:send, msg}` | `:ignore` |
| `handle_resize/3` | `(width, height, state) → {:ok, state}` | `{:ok, state}` |
| `handle_focus/1` | `(state) → {:ok, state}` | `{:ok, state}` |
| `handle_blur/1` | `(state) → {:ok, state}` | `{:ok, state}` |
| `handle_tick/2` | `(frame, state) → {:ok, state} \| :noop` | `{:ok, state}` |
| `cleanup/1` | `(state) → :ok` | `:ok` |
| `cursor/1` | `(state) → {col, row} \| nil` | `nil` |
| `focusable?/0` | `() → boolean()` | `false` |
| `subscriptions/1` | `(state) → [topic]` | `[]` |

**Comandos** retornables desde `update/2`:
- `{:quit, reason}` — salir de la aplicación
- `{:focus, id}` — establecer el foco en un componente específico
- `{:publish, topic, event}` — publicar en el EventBus
- `{:copy, text}` — copiar texto al portapapeles del sistema
- `{:after, ms, message}` — mensaje diferido al propio componente
- `{:engine_run, commands, opts}` — ejecutar tareas paralelas vía Arrea

### Visillo.DSL (DSL de Widgets)

#### Contenedores

| Widget | Descripción |
|---|---|
| `box(opts, do: children)` | Contenedor con borde opcional (`:rounded`, `:single`, `:double`, `:bold`, `:ascii`, `:none`), título, padding y dirección (`:column` / `:row`) |
| `grid(opts, do: children)` | Layout en cuadrícula con columnas y espaciado configurables |
| `scroll_view(opts, do: children)` | Contenedor con scroll mediante offsets `scroll_x` / `scroll_y` |

#### Visualización

| Widget | Descripción |
|---|---|
| `text(content, opts)` | Texto de una línea con color, efectos, alineación y truncado |
| `paragraph(content, opts)` | Texto multilínea con wrap por palabra/carácter y líneas máximas |
| `image(path, opts)` | Renderizado de imágenes en terminal vía protocolos kitty/iterm2/sixel/ascii |
| `raw(content)` | Vía de escape — escribe contenido ANSI raw directamente |

#### Interactivos

| Widget | Descripción |
|---|---|
| `button(label, opts)` | Botón clickable con variante (`:primary`, `:secondary`, `:danger`, `:ghost`), atajo de teclado e icono |
| `input(opts)` | Campo de entrada con placeholder, enmascaramiento de contraseña, etiqueta, longitud máxima, on_change y on_submit |
| `list(items, opts)` | Lista desplazable con selección, render_item personalizado, on_select y on_confirm |
| `table(headers, rows, opts)` | Tabla interactiva con resaltado de cabeceras, selección de fila y estilos de bordes |
| `menu(items, opts)` | Menú desplegable con estado abierto/cerrado y on_select |
| `tabs(tab_list, opts)` | Navegación por pestañas con cambio de contenido vía on_change |
| `file_browser(path, opts)` | Navegador de archivos interactivo con iconos y vista previa |

#### Navegación

| Widget | Descripción |
|---|---|
| `breadcrumbs(path, opts)` | Ruta de navegación con separador configurable y ancestros atenuados |
| `stepper(steps, current, opts)` | Asistente multi-paso con indicadores, conectores y etiquetas |

#### Indicadores

| Widget | Descripción |
|---|---|
| `progress_bar(value, total, opts)` | Barra de progreso con etiqueta, porcentaje y estilos bar/block/dot |
| `spinner(opts)` | Indicador de carga animado con 9 estilos y etiqueta opcional |
| `gauge(value, min, max, opts)` | Indicador tipo gauge/dial segmentado |
| `chart(data, opts)` | Gráficos de barras, sparklines y líneas con colores configurables |

#### Superposiciones

| Widget | Descripción |
|---|---|
| `modal(title, opts, do: content)` | Modal centrado con fondo semitransparente y botones configurables |
| `confirm(message, opts)` | Diálogo de confirmación Sí/No con callbacks on_yes/on_no |

#### Layout

| Widget | Descripción |
|---|---|
| `separator(opts)` | Separador horizontal o vertical con etiqueta centrada opcional |
| `status_bar(left, center, right, opts)` | Barra de estado fija con contenido izquierda/centro/derecha |
| `gap(size)` | Espaciador flexible para distribuir el espacio disponible |

#### Opciones de Constraint

Todos los widgets aceptan estas opciones de constraint para el layout flexbox:

| Opción | Descripción |
|---|---|
| `width` / `height` | Dimensiones fijas |
| `min_width` / `min_height` | Dimensiones mínimas |
| `max_width` / `max_height` | Dimensiones máximas |
| `flex` / `flex_grow` | Factor de crecimiento flex (0 = fijo, 1+ = proporcional) |
| `flex_shrink` | Factor de encogimiento flex |
| `padding` | Relleno interno (entero o `{vertical, horizontal}`) |
| `margin` | Margen externo (entero o `{vertical, horizontal}`) |
| `align_self` | Sobreescribe la alineación: `:start`, `:center`, `:end`, `:stretch` |

### Widgets Compuestos (Visillo.Widgets)

Componentes pre-construidos que pueden usarse como aplicación independiente o incrustados en otros componentes.

| Widget | Módulo | Descripción | Focusable | Eventos de Tecla |
|---|---|---|---|---|
| **Tabs** | `Visillo.Widgets.Tabs` | Barra de pestañas interactiva con cambio de contenido | Sí | Izq/Der, Ctrl+Tab / Ctrl+Shift+Tab |
| **TreeView** | `Visillo.Widgets.TreeView` | Navegador de árbol de directorios con expandir/colapsar | Sí | Arriba/Abajo, Enter, Izq/Der, Inicio/Fin, RePág/AvPág |
| **SplitPane** | `Visillo.Widgets.SplitPane` | Layout partido (horizontal/vertical) con proporción ajustable | No | — |
| **TextInput** | `Visillo.Widgets.TextInput` | Campo de texto de una línea con cursor y placeholder | Sí | Escribir, Backspace, Supr, Inicio, Fin, Izq/Der |
| **Button** | `Visillo.Widgets.Button` | Botón clickable con resaltado de foco | Sí | Enter, Espacio |
| **Checkbox** | `Visillo.Widgets.Checkbox` | Casilla de verificación con etiqueta | Sí | Enter, Espacio |
| **Label** | `Visillo.Widgets.Label` | Etiqueta de texto simple con color y negrita | No | — |
| **Panel** | `Visillo.Widgets.Panel` | Contenedor con borde y título | No | — |

**Ejemplos de uso:**

```elixir
# Tabs: componente independiente
Visillo.App.run(Visillo.Widgets.Tabs,
  tabs: [
    %{label: "Editor", content: [text("Editar aquí...")]},
    %{label: "Vista Previa", content: [text("Previsualizar aquí...")]}
  ]
)

# TreeView: navegador de archivos
{:ok, tree} = Visillo.Widgets.TreeView.init(root: "/home/usuario", show_hidden: false)

# SplitPane: incrustar en render
Visillo.Widgets.SplitPane.new(
  direction: :horizontal,
  first: [text("Panel izquierdo")],
  second: [text("Panel derecho")],
  ratio: 0.3
)

# TextInput: widget incrustado
Visillo.Widgets.TextInput.new(placeholder: "Introduce nombre...", value: "")

# Button: widget incrustado
Visillo.Widgets.Button.new("Enviar", on_click: :enviar)

# Checkbox: widget incrustado
Visillo.Widgets.Checkbox.new(label: "Activar función", checked: false)

# Label: widget incrustado
Visillo.Widgets.Label.new("¡Hola, Mundo!", color: :green, bold: true)

# Panel: contenedor incrustado
Visillo.Widgets.Panel.new(title: "Estado", children: [text("Todo correcto")])
```

### Visillo.App

```elixir
Visillo.App.run(MiComponente, opts)
```

| Opción | Por defecto | Descripción |
|---|---|---|
| `:theme` | `:default` | Nombre del tema (`:default`, `:dracula`, `:tokyo_night`, `:gruvbox`, `:catppuccin`, `:nord`) |
| `:props` | `[]` | Props pasadas a `init/1` |
| `:refresh_rate` | `30` | FPS de animación |
| `:alt_screen` | `true` | Usar el buffer de pantalla alternativo del terminal |
| `:mouse` | `true` | Activar seguimiento de ratón SGR |
| `:title` | `nil` | Título de la ventana del terminal |
| `:quit_keys` | `["q", "ctrl+c"]` | Teclas de salida globales (no pueden ser sobrescritas por componentes) |
| `:focus_keys` | `[]` | Si está vacío, Tab/Shift+Tab se manejan a nivel de sistema |

```elixir
Visillo.App.stop()  # detiene la sesión actual de forma controlada
```

### Visillo.Theme

```elixir
{:ok, theme} = Visillo.Theme.load(:dracula)
Visillo.Theme.list()          # → [:default, :dracula, :tokyo_night, :gruvbox, :catppuccin, :nord]
Visillo.Theme.color(theme, :primary)  # → {r, g, b}
Visillo.Theme.fg({100, 149, 237})     # → secuencia ANSI de foreground
Visillo.Theme.bg({45, 50, 70})        # → secuencia ANSI de background
Visillo.Theme.default()               # tema de respaldo
Visillo.Theme.merge(base, overrides)  # mezcla personalizaciones
```

### Visillo.Animation

```elixir
Visillo.Animation.spinner_char(:dots, frame)  # → "⣾"
Visillo.Animation.frame_index(frame, 4)      # → 0..3 cíclico
Visillo.Animation.spinner_styles()           # → [:dots, :dots2, :line, :moon, :clock, :pulse, :bounce, :braille, :grow]
Visillo.Animation.subscribe(pid)             # suscribirse a los ticks
Visillo.Animation.set_fps(60)                # cambiar tasa de ticks
```

### Visillo.Focus

```elixir
Visillo.Focus.next()       # → siguiente id de componente focusable
Visillo.Focus.previous()   # → anterior id de componente focusable
Visillo.Focus.set(:mi_id)  # enfocar un componente específico
Visillo.Focus.blur()       # quitar el foco
Visillo.Focus.focused?(:id) # verificar si tiene el foco
```

### Visillo.EventBus

```elixir
Visillo.EventBus.subscribe(:topico)              # proceso actual
Visillo.EventBus.subscribe(:topico, otro_pid)    # pid específico
Visillo.EventBus.publish(:topico, evento)        # difundir
Visillo.EventBus.unsubscribe(:topico)            # dejar de recibir
```

### Visillo.Screen

```elixir
Visillo.Screen.set_title("Título de Mi App")
Visillo.Screen.copy_to_clipboard("texto")
Visillo.Screen.set_cursor_visible(true)
Visillo.Screen.force_redraw()  # marcar todas las celdas para re-renderizado completo
```

## Aprovechando el Ecosistema

### Renderizado con Alaja

El pipeline de renderizado de Visillo produce instancias de `Alaja.Buffer` — una cuadrícula 2D de structs `Alaja.Cell` con carácter, color de frente/fondo y efectos. El GenServer `Visillo.Screen` aplica diff entre buffers consecutivos y emite secuencias ANSI solo para las celdas modificadas.

Para renderizado personalizado más allá del DSL de widgets, puedes usar Alaja directamente:

```elixir
# Dentro de tu componente — un render estilo canvas personalizado
@impl true
def render(state, _theme) do
  raw(Alaja.Cell.to_ansi(celda))
end
```

Las capacidades de texto enriquecido (gradientes, armonías) provienen de Pote:

```elixir
# Los colores de Pote se usan en todo el framework — los colores del tema son tuplas {r, g, b}
handle_key("enter", [], state) do
  # Los colores se pueden especificar como átomos (buscados en el tema), strings hex o tuplas
  {:send, {:mostrar, :success}}
end
```

### Orquestación de Procesos con Arrea

Para cargas de trabajo asíncronas dentro de una TUI (I/O de archivos, peticiones de red, consultas a base de datos), usa la ejecución paralela de Arrea:

```elixir
def update(:cargar_datos, state) do
  commands = [
    fn -> {:api_a, HTTPClient.get("/api/a")} end,
    fn -> {:api_b, HTTPClient.get("/api/b")} end
  ]

  {:ok, state, {:engine_run, commands, workers: 2, timeout: 5000}}
end
```

Los componentes pueden suscribirse a tópicos del `EventBus` para recibir resultados de forma asíncrona.

```elixir
@impl true
def subscriptions(_state), do: [:datos_cargados]

def update({:bus_event, :datos_cargados, resultado}, state) do
  {:ok, %{state | datos: resultado}}
end
```

## Instalación

Añade `visillo` a las dependencias de tu `mix.exs`:

```elixir
def deps do
  [
    {:visillo, "~> 1.0.0"},
    # Visillo requiere sus librerías hermanas:
    {:alaja, "~> 1.0.0"},
    {:pote,  "~> 1.0.0"},
    {:arrea, "~> 1.0.0"}
  ]
end
```

Luego ejecuta:

```bash
mix deps.get
```

## Demos Incluidas

Visillo incluye 8 aplicaciones de demostración accesibles mediante tareas Mix:

| Tarea Mix | Módulo | Descripción |
|---|---|---|
| `mix visillo.demo.chat` | `Visillo.Demo.Chat` | Chat interactivo con comandos `/` (ayuda, lista, multi-selección, onboarding animado) |
| `mix visillo.demo.counter` | `Visillo.Demo.Counter` | Contador simple — incrementar/decrementar/reiniciar con teclado |
| `mix visillo.demo.dashboard` | `Visillo.Demo.Dashboard` | Monitor del sistema (tipo btop) con medidores de CPU/memoria/disco en vivo, gráficos sparkline, tabla de procesos y cambio de pestañas |
| `mix visillo.demo.editor` | `Visillo.Demo.MicroEditor` | Editor de texto tipo micro/nano con pestañas multi-buffer, barra lateral (Ctrl+E), word wrap (`wrap: true`), deshacer/rehacer, guardar, diálogo de abrir archivo |
| `mix visillo.demo.form` | `Visillo.Demo.Form` | Formulario de registro con campos de texto, casilla de verificación y envío |
| `mix visillo.demo.installer` | `Visillo.Demo.Installer` | Asistente multi-paso con stepper, validación de formularios, spinner, barra de progreso, log de instalación |
| `mix visillo.demo.menu` | `Visillo.Demo.MenuApp` | Menú multi-pantalla con filtro de búsqueda, breadcrumbs, selección de lista, vistas de detalle, panel de configuración, pantalla de ayuda |
| `mix visillo.demo.unified` | `Visillo.Demo.Unified` | TODO-EN-UNO: navegador de archivos (TreeView) + editor (MicroEditor) + chat (asistente) + dashboard (monitor del sistema) — navegación por pestañas con Ctrl+Tab |

Para ejecutar cualquier demo:

```bash
mix visillo.demo.chat
mix visillo.demo.counter
mix visillo.demo.dashboard
mix visillo.demo.editor
mix visillo.demo.form
mix visillo.demo.installer
mix visillo.demo.menu
mix visillo.demo.unified
```

O directamente vía `mix run`:

```bash
mix run -e 'Visillo.App.run(Visillo.Demo.MenuApp, theme: :dracula)'
mix run -e 'Visillo.App.run(Visillo.Demo.MicroEditor, theme: :tokyo_night)'
mix run -e 'Visillo.App.run(Visillo.Demo.Dashboard, theme: :catppuccin)'
mix run -e 'Visillo.App.run(Visillo.Demo.Installer, theme: :gruvbox)'
```

## Licencia

Licencia MIT. Consulta [LICENSE](LICENSE).

Copyright (c) 2025 Lorenzo Sanchez

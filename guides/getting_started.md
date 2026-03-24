# Getting Started

`SpriteEx` works best when you treat SVG assets as compile-time inputs.

## 1. Add the dependency

```elixir
def deps do
  [
    {:sprite_ex, "~> 0.1.0"}
  ]
end
```

Register the SpriteEx compiler after the default Mix compilers:

```elixir
def project do
  [
    app: :my_app,
    version: "0.1.0",
    elixir: "~> 1.19",
    compilers: Mix.compilers() ++ [:sprite_ex_icons],
    deps: deps()
  ]
end
```

## 2. Configure your icon source and output paths

```elixir
import Config

config :sprite_ex,
  source_root: Path.expand("../priv/icons", __DIR__),
  build_path: Path.expand("../priv/static/sprites", __DIR__),
  public_path: "/sprites"
```

`source_root` is where your source SVG files live. `build_path` is where
SpriteEx writes generated sprite sheets. `public_path` is the URL prefix used
inside generated sprite refs.

## 3. Serve the generated sprite sheets

SpriteEx does not serve files for you. If you write sprite sheets to
`priv/static/sprites`, make sure your Phoenix endpoint serves them from the
matching `/sprites` URL path.

## 4. Import SpriteEx in a component module

```elixir
defmodule MyAppWeb.IconComponents do
  use Phoenix.Component
  use SpriteEx
end
```

That gives you:

- `<.svg>` for rendering
- `sprite_ref/1` and `sprite_ref/2` for sprite-backed SVGs
- `inline_ref/1` for inline SVG markup

## 5. Pick the rendering mode per icon

Use a sprite-backed ref when you want the page to reference a shared generated
sheet:

```elixir
<.svg ref={sprite_ref("regular/xmark")} class="size-4" />
```

Use an inline ref when you want the full SVG markup in the document:

```elixir
<.svg ref={inline_ref("regular/xmark")} class="size-4" />
```

Both ref macros require compile-time literal icon names so the compiler can
discover the assets ahead of time.

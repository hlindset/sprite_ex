defmodule SvgSpriteEx do
  @moduledoc """
  Public entrypoint for SvgSpriteEx in Phoenix component modules.

  `use SvgSpriteEx` imports:

  - the `<.svg>` component from `SvgSpriteEx.Svg`
  - the `sprite_ref/1`, `sprite_ref/2`, and `inline_ref/1` macros from
    `SvgSpriteEx.Ref`
  """

  @doc ~S'''
  Imports the SvgSpriteEx component and compile-time ref helpers into the caller.

  ## Examples

  ```elixir
  defmodule MyAppWeb.IconComponents do
    use Phoenix.Component
    use SvgSpriteEx

    def close_icon(assigns) do
      ~H"""
      <.svg ref={sprite_ref("regular/xmark")} class="size-4" />
      """
    end
  end
  ```
  '''
  defmacro __using__(_opts) do
    quote do
      import SvgSpriteEx.Svg
      use SvgSpriteEx.Ref
    end
  end
end

defmodule SpriteEx do
  @moduledoc """
  Public entrypoint for SpriteEx in Phoenix component modules.

  `use SpriteEx` imports:

  - the `<.svg>` component from `SpriteEx.Svg`
  - the `sprite_ref/1`, `sprite_ref/2`, and `inline_ref/1` macros from
    `SpriteEx.Ref`
  """

  @doc ~S'''
  Imports the SpriteEx component and compile-time ref helpers into the caller.

  ## Examples

  ```elixir
  defmodule MyAppWeb.IconComponents do
    use Phoenix.Component
    use SpriteEx

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
      import SpriteEx.Svg
      use SpriteEx.Ref
    end
  end
end

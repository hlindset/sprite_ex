defmodule SpriteEx do
  @moduledoc """
  Convenience entrypoint for SVG rendering and sprite refs.
  """

  defmacro __using__(_opts) do
    quote do
      import SpriteEx.Svg
      use SpriteEx.Ref
    end
  end
end

defmodule SpriteEx.SpriteRef do
  @moduledoc """
  Compile-time sprite-backed SVG reference.
  """

  @enforce_keys [:name, :sheet, :sprite_id, :href]
  defstruct [:name, :sheet, :sprite_id, :href]

  @type t :: %__MODULE__{
          name: String.t(),
          sheet: String.t(),
          sprite_id: String.t(),
          href: String.t()
        }
end

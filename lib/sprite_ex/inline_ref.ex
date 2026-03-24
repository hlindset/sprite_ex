defmodule SpriteEx.InlineRef do
  @moduledoc """
  Compile-time inline SVG reference.
  """

  @enforce_keys [:name, :registry]
  defstruct [:name, :registry]

  @type t :: %__MODULE__{
          name: String.t(),
          registry: module()
        }
end

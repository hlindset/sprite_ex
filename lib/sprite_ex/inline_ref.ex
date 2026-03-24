defmodule SpriteEx.InlineRef do
  @moduledoc """
  Compile-time inline SVG reference.

  `inline_ref/1` returns this struct for consumption by `<.svg>`.
  """

  @enforce_keys [:name, :registry]
  defstruct [:name, :registry]

  @type t :: %__MODULE__{
          name: String.t(),
          registry: module()
        }
end

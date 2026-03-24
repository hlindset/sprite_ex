defmodule SvgSpriteEx.InlineAsset do
  @moduledoc false

  @enforce_keys [:attributes, :inner_content]
  defstruct [:attributes, :inner_content]

  @type t :: %__MODULE__{
          attributes: %{optional(String.t()) => String.t()},
          inner_content: String.t()
        }
end

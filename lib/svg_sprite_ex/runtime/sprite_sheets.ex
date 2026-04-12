defmodule SvgSpriteEx.Runtime.SpriteSheets do
  @moduledoc false

  alias SvgSpriteEx.Runtime.RuntimeData

  def sprite_sheets, do: RuntimeData.sprite_sheets()
  def sprite_sheet(name), do: RuntimeData.sprite_sheet(name)
  def sprites_in_sheet(name), do: RuntimeData.sprites_in_sheet(name)
end

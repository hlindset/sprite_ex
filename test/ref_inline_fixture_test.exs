defmodule SpriteEx.RefInlineFixture do
  use SpriteEx

  def icon_ref, do: inline_ref("regular/xmark")
  def duplicate_ref, do: inline_ref("regular/xmark")
end

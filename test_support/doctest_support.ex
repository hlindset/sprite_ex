defmodule SpriteEx.DocTestSupport do
  defmodule DefaultExample do
    use SpriteEx

    def icon_ref, do: sprite_ref("regular/xmark")
  end

  defmodule SheetedExample do
    use SpriteEx

    def icon_ref, do: sprite_ref("regular/xmark", sheet: "Dashboard")
  end

  defmodule InlineExample do
    use SpriteEx

    def icon_ref, do: inline_ref("regular/xmark")
  end

  def default_sprite_ref, do: DefaultExample.icon_ref()
  def sheeted_sprite_ref, do: SheetedExample.icon_ref()
  def inline_ref, do: InlineExample.icon_ref()
end

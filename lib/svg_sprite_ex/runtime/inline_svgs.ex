defmodule SvgSpriteEx.Runtime.InlineSvgs do
  @moduledoc false

  alias SvgSpriteEx.Runtime.RuntimeData

  def inline_svgs, do: RuntimeData.inline_svgs()
  def inline_svg(name), do: RuntimeData.inline_svg(name)
end

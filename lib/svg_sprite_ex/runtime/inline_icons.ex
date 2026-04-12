defmodule SvgSpriteEx.Runtime.InlineIcons do
  @moduledoc false

  alias SvgSpriteEx.Runtime.RuntimeData

  def fetch(name), do: RuntimeData.fetch_inline_asset(name)
  def names, do: RuntimeData.inline_names()
end

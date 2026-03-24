defmodule SvgSpriteEx.SpriteSheet do
  @moduledoc false

  alias SvgSpriteEx.Source

  @passthrough_attribute_exclusions MapSet.new(["height", "viewBox", "width", "xmlns"])

  @doc """
  Builds a deterministic `<svg>` sprite sheet from logical SVG asset paths.
  """
  def build(paths, opts \\ []) when is_list(paths) do
    source_root = Keyword.fetch!(opts, :source_root)

    paths
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(&Source.read!(&1, source_root))
    |> ensure_unique_sprite_ids!()
    |> Enum.map(&build_symbol!/1)
    |> wrap_sprite_sheet()
  end

  @doc """
  Returns the source attributes that should be copied through to `<symbol>`.

  Enforced sprite attributes such as `viewBox`, `width`, `height`, and `xmlns`
  are excluded.
  """
  def symbol_attributes(attributes) when is_map(attributes) do
    attributes
    |> Enum.reject(fn {name, _value} ->
      MapSet.member?(@passthrough_attribute_exclusions, name)
    end)
    |> Enum.into(%{})
  end

  defp build_symbol!(%Source{
         name: normalized_name,
         attributes: attributes,
         inner_content: inner_content
       }) do
    # `inner_content` comes from `Source.read!/2`, which already parsed the SVG subtree.

    view_box = Map.get(attributes, "viewBox")
    sprite_id = Source.sprite_id_from_normalized(normalized_name)
    rendered_symbol_attrs = render_symbol_attrs(attributes)

    if is_nil(view_box) or view_box == "" do
      raise ArgumentError, "svg asset #{inspect(normalized_name)} is missing a viewBox"
    end

    escaped_view_box = escape_xml_attr(view_box)

    """
    <symbol id="#{sprite_id}" viewBox="#{escaped_view_box}"#{rendered_symbol_attrs}>
    #{inner_content}
    </symbol>
    """
  end

  defp wrap_sprite_sheet([]) do
    "<svg xmlns=\"http://www.w3.org/2000/svg\">\n</svg>\n"
  end

  defp wrap_sprite_sheet(symbols) do
    IO.iodata_to_binary([
      "<svg xmlns=\"http://www.w3.org/2000/svg\">\n",
      Enum.join(symbols, "\n"),
      "\n</svg>\n"
    ])
  end

  defp ensure_unique_sprite_ids!(sources) do
    collisions =
      sources
      |> Enum.group_by(&Source.sprite_id_from_normalized(&1.name))
      |> Enum.filter(fn {_sprite_id, sprite_paths} -> length(sprite_paths) > 1 end)

    if collisions == [] do
      sources
    else
      details =
        Enum.map_join(collisions, "; ", fn {sprite_id, sprite_sources} ->
          "#{sprite_id}: #{Enum.join(Enum.map(sprite_sources, & &1.file_path), ", ")}"
        end)

      raise ArgumentError, "sprite ID collisions detected: #{details}"
    end
  end

  defp render_symbol_attrs(attributes) do
    attributes
    |> symbol_attributes()
    |> Enum.sort_by(fn {name, _value} -> name end)
    |> Enum.map_join("", fn {name, value} -> ~s( #{name}="#{escape_xml_attr(value)}") end)
  end

  defp escape_xml_attr(value) do
    value
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end

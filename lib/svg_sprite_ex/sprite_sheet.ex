defmodule SvgSpriteEx.SpriteSheet do
  @moduledoc false

  require Record

  alias SvgSpriteEx.Source

  Record.defrecordp(
    :xml_attribute,
    Record.extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl")
  )

  Record.defrecordp(
    :xml_element,
    Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")
  )

  @passthrough_attribute_exclusions MapSet.new(["height", "viewBox", "width", "xmlns"])
  @local_fragment_href_attrs MapSet.new(["href", "xlink:href"])
  @local_url_reference_pattern ~r/url\(\s*(['"]?)#([^)'" ]+)\1\s*\)/

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
         content_nodes: content_nodes
       }) do
    view_box = Map.get(attributes, "viewBox")
    sprite_id = Source.sprite_id_from_normalized(normalized_name)
    rendered_symbol_attrs = render_symbol_attrs(attributes)

    if is_nil(view_box) or view_box == "" do
      raise ArgumentError, "svg asset #{inspect(normalized_name)} is missing a viewBox"
    end

    escaped_view_box = escape_xml_attr(view_box)
    rewritten_content = rewrite_content_nodes!(normalized_name, content_nodes, sprite_id)

    """
    <symbol id="#{sprite_id}" viewBox="#{escaped_view_box}"#{rendered_symbol_attrs}>
    #{rewritten_content}
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

  defp rewrite_content_nodes!(normalized_name, content_nodes, sprite_id) do
    id_map =
      content_nodes
      |> collect_local_ids()
      |> Map.new(fn id -> {id, "#{sprite_id}-#{id}"} end)

    content_nodes
    |> rewrite_nodes!(normalized_name, id_map)
    |> render_content_nodes()
  end

  defp collect_local_ids(nodes, acc \\ MapSet.new())

  defp collect_local_ids([], acc), do: acc

  defp collect_local_ids([node | rest], acc) do
    acc =
      if is_tuple(node) and tuple_size(node) > 0 and elem(node, 0) == :xmlElement do
        node
        |> xml_element(:attributes)
        |> collect_ids_from_attributes(acc)
        |> then(&collect_local_ids(xml_element(node, :content), &1))
      else
        acc
      end

    collect_local_ids(rest, acc)
  end

  defp collect_ids_from_attributes(attributes, acc) do
    Enum.reduce(attributes, acc, fn attribute, collected_ids ->
      if attribute_name(attribute) == "id" do
        case attribute_value(attribute) do
          "" -> collected_ids
          value -> MapSet.put(collected_ids, value)
        end
      else
        collected_ids
      end
    end)
  end

  defp rewrite_nodes!(nodes, normalized_name, id_map) do
    Enum.map(nodes, &rewrite_node!(&1, normalized_name, id_map))
  end

  defp rewrite_node!(node, normalized_name, id_map) do
    if is_tuple(node) and tuple_size(node) > 0 and elem(node, 0) == :xmlElement do
      updated_attributes =
        node
        |> xml_element(:attributes)
        |> Enum.map(&rewrite_attribute!(&1, normalized_name, id_map))

      updated_content =
        node
        |> xml_element(:content)
        |> rewrite_nodes!(normalized_name, id_map)

      xml_element(node, attributes: updated_attributes, content: updated_content)
    else
      node
    end
  end

  defp rewrite_attribute!(attribute, normalized_name, id_map) do
    name = attribute_name(attribute)
    value = attribute_value(attribute)

    rewritten_value =
      cond do
        name == "id" ->
          rewrite_local_id!(value, normalized_name, id_map)

        MapSet.member?(@local_fragment_href_attrs, name) ->
          rewrite_fragment_href!(value, name, normalized_name, id_map)

        true ->
          rewrite_url_references!(value, name, normalized_name, id_map)
      end

    if rewritten_value == value do
      attribute
    else
      xml_attribute(attribute, value: String.to_charlist(rewritten_value))
    end
  end

  defp rewrite_local_id!("", _normalized_name, _id_map), do: ""

  defp rewrite_local_id!(value, normalized_name, id_map) do
    Map.fetch!(id_map, value)
  rescue
    KeyError ->
      raise ArgumentError,
            "svg asset #{inspect(normalized_name)} references unknown local id #{inspect(value)}"
  end

  defp rewrite_fragment_href!(value, attr_name, normalized_name, id_map) do
    trimmed_value = String.trim(value)

    cond do
      trimmed_value == "" ->
        value

      String.starts_with?(trimmed_value, "#") ->
        "#" <>
          rewrite_reference_target!(
            String.trim_leading(trimmed_value, "#"),
            attr_name,
            normalized_name,
            id_map
          )

      true ->
        raise_unsupported_reference!(normalized_name, attr_name, value)
    end
  end

  defp rewrite_url_references!(value, _attr_name, _normalized_name, _id_map)
       when not is_binary(value),
       do: value

  defp rewrite_url_references!(value, attr_name, normalized_name, id_map) do
    if String.contains?(value, "url(") do
      unsupported_url_references =
        Regex.replace(@local_url_reference_pattern, value, "")

      if String.contains?(unsupported_url_references, "url(") do
        raise_unsupported_reference!(normalized_name, attr_name, value)
      end

      rewritten_value =
        Regex.replace(@local_url_reference_pattern, value, fn _, quote, target ->
          escaped_quote = if quote == "", do: "", else: quote

          "url(" <>
            escaped_quote <>
            "#" <>
            rewrite_reference_target!(target, attr_name, normalized_name, id_map) <>
            escaped_quote <> ")"
        end)

      rewritten_value
    else
      value
    end
  end

  defp rewrite_reference_target!(target, attr_name, normalized_name, id_map) do
    case Map.fetch(id_map, target) do
      {:ok, rewritten_target} ->
        rewritten_target

      :error ->
        raise ArgumentError,
              "svg asset #{inspect(normalized_name)} references unknown local id #{inspect(target)} " <>
                "from #{attr_name}"
    end
  end

  defp raise_unsupported_reference!(normalized_name, attr_name, value) do
    raise ArgumentError,
          "svg asset #{inspect(normalized_name)} contains an unsupported reference in #{attr_name}: #{inspect(value)}"
  end

  defp render_content_nodes(nodes) do
    nodes
    |> :xmerl.export_simple_content(:xmerl_xml)
    |> IO.iodata_to_binary()
    |> String.trim()
  end

  defp render_symbol_attrs(attributes) do
    attributes
    |> symbol_attributes()
    |> Enum.sort_by(fn {name, _value} -> name end)
    |> Enum.map_join("", fn {name, value} -> ~s( #{name}="#{escape_xml_attr(value)}") end)
  end

  defp attribute_name(attribute) do
    attribute
    |> xml_attribute(:name)
    |> Atom.to_string()
  end

  defp attribute_value(attribute) do
    attribute
    |> xml_attribute(:value)
    |> IO.iodata_to_binary()
  end

  defp escape_xml_attr(value) do
    value
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end

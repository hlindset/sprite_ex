defmodule SpriteEx.SpriteSheetTest do
  use ExUnit.Case, async: true

  alias SpriteEx.Source
  alias SpriteEx.SpriteSheet

  test "build escapes viewBox values in generated symbols" do
    svg_source_root = unique_tmp_dir!("view-box")
    File.mkdir_p!(Path.join(svg_source_root, "icons"))

    File.write!(
      Path.join(svg_source_root, "icons/alert.svg"),
      """
      <svg viewBox="0 0 24 24 &quot; onclick=&quot;alert(1)">
        <path d="M0 0h24v24H0z" />
      </svg>
      """
    )

    sprite_sheet = SpriteSheet.build(["icons/alert"], source_root: svg_source_root)

    assert sprite_sheet =~ "viewBox=\"0 0 24 24 &quot; onclick=&quot;alert(1)\""
    refute sprite_sheet =~ "viewBox=\"0 0 24 24 \" onclick=\"alert(1)\""
  end

  test "build escapes non-viewBox symbol attributes" do
    svg_source_root = unique_tmp_dir!("symbol-attrs")
    File.mkdir_p!(Path.join(svg_source_root, "icons"))

    File.write!(
      Path.join(svg_source_root, "icons/badge.svg"),
      """
      <svg viewBox="0 0 24 24" data-label="Tom &amp; Jerry &lt;tag&gt; &quot;double&quot; &apos;single&apos;">
        <path d="M0 0h24v24H0z" />
      </svg>
      """
    )

    sprite_sheet = SpriteSheet.build(["icons/badge"], source_root: svg_source_root)

    assert sprite_sheet =~
             "data-label=\"Tom &amp; Jerry &lt;tag&gt; &quot;double&quot; &#39;single&#39;\""

    refute sprite_sheet =~ "data-label=\"Tom & Jerry <tag> \"double\" 'single'\""
  end

  test "build returns an empty sprite sheet for empty input" do
    assert SpriteSheet.build([], source_root: unique_tmp_dir!("empty")) ==
             "<svg xmlns=\"http://www.w3.org/2000/svg\">\n</svg>\n"
  end

  test "build sorts and de-duplicates source paths" do
    svg_source_root = unique_tmp_dir!("sorted")
    File.mkdir_p!(Path.join(svg_source_root, "icons"))

    File.write!(
      Path.join(svg_source_root, "icons/alpha.svg"),
      """
      <svg viewBox="0 0 24 24">
        <path d="M1 1h22v22H1z" />
      </svg>
      """
    )

    File.write!(
      Path.join(svg_source_root, "icons/beta.svg"),
      """
      <svg viewBox="0 0 24 24" width="24" height="24" xmlns="http://www.w3.org/2000/svg">
        <path d="M2 2h20v20H2z" />
      </svg>
      """
    )

    sprite_sheet =
      SpriteSheet.build(["icons/beta", "icons/alpha", "icons/beta"],
        source_root: svg_source_root
      )

    alpha_id = Source.sprite_id("icons/alpha", svg_source_root)
    beta_id = Source.sprite_id("icons/beta", svg_source_root)

    assert count_occurrences(sprite_sheet, "<symbol id=") == 2
    assert String.contains?(sprite_sheet, ~s(<symbol id="#{alpha_id}"))
    assert String.contains?(sprite_sheet, ~s(<symbol id="#{beta_id}"))
    assert symbol_position(sprite_sheet, alpha_id) < symbol_position(sprite_sheet, beta_id)
    refute sprite_sheet =~ ~s( width="24")
    refute sprite_sheet =~ ~s( height="24")
    refute sprite_sheet =~ ~r/<symbol[^>]* xmlns=/
  end

  test "build raises when a source svg is missing a viewBox" do
    svg_source_root = unique_tmp_dir!("missing-viewbox")
    File.mkdir_p!(Path.join(svg_source_root, "icons"))

    File.write!(
      Path.join(svg_source_root, "icons/no_viewbox.svg"),
      """
      <svg>
        <path d="M0 0h24v24H0z" />
      </svg>
      """
    )

    assert_raise ArgumentError, ~r/is missing a viewBox/, fn ->
      SpriteSheet.build(["icons/no_viewbox"], source_root: svg_source_root)
    end
  end

  defp count_occurrences(haystack, needle) do
    haystack
    |> String.split(needle)
    |> length()
    |> Kernel.-(1)
  end

  defp symbol_position(sprite_sheet, sprite_id) do
    sprite_sheet
    |> :binary.match(~s(<symbol id="#{sprite_id}"))
    |> elem(0)
  end

  defp unique_tmp_dir!(suffix) do
    path =
      System.tmp_dir!()
      |> Path.join("sprite_ex_test_#{suffix}_#{System.unique_integer([:positive])}")
      |> Path.expand()

    File.mkdir_p!(path)
    ExUnit.Callbacks.on_exit(fn -> File.rm_rf!(path) end)
    path
  end
end

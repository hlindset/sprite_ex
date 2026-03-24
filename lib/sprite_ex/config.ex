defmodule SpriteEx.Config do
  @moduledoc """
  Compile-time configuration accessors for SpriteEx.

  These helpers raise if a required `:sprite_ex` setting is missing or invalid.
  """

  @source_root Application.compile_env(:sprite_ex, :source_root)
  @build_path Application.compile_env(:sprite_ex, :build_path)
  @public_path Application.compile_env(:sprite_ex, :public_path)
  @default_sheet Application.compile_env(:sprite_ex, :default_sheet, "sprites")

  @doc """
  Returns the source root used to resolve SVG assets.

  This now validates early that the configured path is nonblank and points to an
  existing directory.
  """
  def source_root! do
    fetch_directory!(@source_root, ":source_root")
  end

  @doc "Returns the build directory used for generated sprite sheets."
  def build_path! do
    fetch_binary!(@build_path, ":build_path")
  end

  @doc "Returns the public path used to reference generated sprite sheets."
  def public_path! do
    fetch_binary!(@public_path, ":public_path")
  end

  @doc "Returns the default sprite sheet name."
  def default_sheet! do
    fetch_binary!(@default_sheet, ":default_sheet")
  end

  defp fetch_binary!(value, _key) when is_binary(value) do
    value
  end

  defp fetch_binary!(_value, key) do
    raise ArgumentError, "missing config :sprite_ex, #{key}"
  end

  defp fetch_directory!(value, key) when is_binary(value) do
    cond do
      String.trim(value) == "" ->
        raise ArgumentError, "invalid config :sprite_ex, #{key} must not be blank"

      File.dir?(Path.expand(value)) ->
        value

      true ->
        raise ArgumentError,
              "invalid config :sprite_ex, #{key} must point to an existing directory: #{inspect(value)}"
    end
  end

  defp fetch_directory!(_value, key) do
    raise ArgumentError, "missing config :sprite_ex, #{key}"
  end
end

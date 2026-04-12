defmodule Test.Support.CompileHelpers do
  import ExUnit.Assertions, only: [flunk: 1]

  def compile_fixture_modules!(manifest_path, source_dir, compile_path) do
    override = compiler_state_path(manifest_path)
    previous_override = Application.get_env(:svg_sprite_ex, :compiler_state_path_override)
    Application.put_env(:svg_sprite_ex, :compiler_state_path_override, override)

    try do
      # Note: This intentionally uses Mix's internal compile/7 API for test
      # infrastructure. If the signature changes on Elixir upgrade, update this
      # helper.
      case Mix.Compilers.Elixir.compile(
             manifest_path,
             [source_dir],
             compile_path,
             {:svg_sprite_ex_test, source_dir},
             [],
             [],
             []
           ) do
        {:ok, _diagnostics} ->
          :ok

        {:noop, _diagnostics} ->
          :ok

        {:error, diagnostics} ->
          flunk("fixture modules failed to compile: #{inspect(diagnostics)}")
      end
    after
      if is_nil(previous_override) do
        Application.delete_env(:svg_sprite_ex, :compiler_state_path_override)
      else
        Application.put_env(:svg_sprite_ex, :compiler_state_path_override, previous_override)
      end
    end
  end

  def compiler_state_path(manifest_path) do
    manifest_path
    |> Path.dirname()
    |> Path.join("svg_sprite_ex")
  end
end

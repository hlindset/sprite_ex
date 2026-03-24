defmodule Mix.Tasks.Compile.SvgSpriteExIcons do
  @moduledoc false

  use Mix.Task.Compiler

  @recursive true
  @shortdoc "Builds application SVG sprite sheets"
  @manifest_vsn 1

  alias SvgSpriteEx.Config
  alias SvgSpriteEx.Ref
  alias SvgSpriteEx.Source
  alias SvgSpriteEx.SpriteSheet

  @inline_registry_module SvgSpriteEx.Generated.InlineIcons

  @impl Mix.Task.Compiler
  def run(_args) do
    compile_sprite_artifacts!(
      compile_path: Mix.Project.compile_path(),
      compiler_manifest_path: compiler_manifest_path(),
      elixir_manifest_path: elixir_manifest_path(),
      generated_source_path: generated_source_path(),
      inline_registry_module: @inline_registry_module,
      build_path: Config.build_path!(),
      source_root: Config.source_root!()
    )
  end

  @impl Mix.Task.Compiler
  def manifests do
    [compiler_manifest_path()]
  end

  @impl Mix.Task.Compiler
  def clean do
    compiler_manifest_path = compiler_manifest_path()

    cleanup_inline_registry(
      Mix.Project.compile_path(),
      generated_source_path(),
      @inline_registry_module
    )

    compiler_manifest_path
    |> read_compiler_manifest()
    |> cleanup_artifact_paths()

    File.rm(compiler_manifest_path)
    :ok
  end

  def compile_sprite_artifacts!(opts) do
    compile_path = Keyword.fetch!(opts, :compile_path)
    elixir_manifest_path = Keyword.get(opts, :elixir_manifest_path, elixir_manifest_path())

    compiler_manifest_path =
      Keyword.get(opts, :compiler_manifest_path, compiler_manifest_path(elixir_manifest_path))

    generated_source_path =
      Keyword.get(opts, :generated_source_path, generated_source_path(elixir_manifest_path))

    inline_registry_module = Keyword.get(opts, :inline_registry_module, @inline_registry_module)
    build_path = Keyword.fetch!(opts, :build_path)
    source_root = Keyword.fetch!(opts, :source_root)

    modules = project_modules(compile_path, elixir_manifest_path)

    sprite_refs = collect_project_refs(modules, &sprite_refs/1)
    inline_refs = collect_project_refs(modules, &inline_refs/1)
    inline_sources = load_inline_sources(inline_refs, source_root)
    sprite_builds = build_sprite_outputs(sprite_refs, build_path, source_root)

    File.mkdir_p!(build_path)

    sprite_result = write_sprite_sheets(sprite_builds)

    inline_result =
      write_inline_registry(
        compile_path,
        generated_source_path,
        inline_registry_module,
        inline_sources
      )

    active_artifact_paths =
      active_artifact_paths(
        sprite_builds,
        compile_path,
        generated_source_path,
        inline_sources,
        inline_registry_module
      )

    manifest_cleanup_result =
      compiler_manifest_path
      |> read_compiler_manifest()
      |> Enum.reject(&(&1 in active_artifact_paths))
      |> cleanup_artifact_paths()

    manifest_write_result = write_compiler_manifest(compiler_manifest_path, active_artifact_paths)

    if Enum.all?(
         [
           sprite_result,
           inline_result,
           manifest_cleanup_result,
           manifest_write_result
         ],
         &(&1 == :noop)
       ),
       do: :noop,
       else: :ok
  end

  defp project_modules(compile_path, elixir_manifest_path) do
    Code.prepend_path(compile_path)

    elixir_manifest_path
    |> Mix.Compilers.Elixir.read_manifest()
    |> elem(0)
    |> manifest_modules()
    |> Enum.filter(&Code.ensure_loaded?/1)
    |> Enum.sort_by(&Atom.to_string/1)
  end

  defp collect_project_refs(modules, extractor) do
    modules
    |> Enum.flat_map(extractor)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp build_sprite_outputs(sprite_refs, build_path, source_root) do
    sprite_refs
    |> Enum.group_by(fn {sheet, _name} -> sheet end, fn {_sheet, name} -> name end)
    |> Enum.into(%{}, fn {sheet, names} ->
      {Ref.sheet_build_path(sheet, build_path),
       SpriteSheet.build(names, source_root: source_root)}
    end)
  end

  defp load_inline_sources(inline_refs, source_root) do
    Enum.map(inline_refs, fn name ->
      Source.read!(name, source_root)
    end)
  end

  defp active_artifact_paths(
         sprite_builds,
         compile_path,
         generated_source_path,
         inline_sources,
         inline_registry_module
       ) do
    sprite_artifacts = Map.keys(sprite_builds)

    inline_artifacts =
      inline_registry_artifact_paths(
        compile_path,
        generated_source_path,
        inline_sources,
        inline_registry_module
      )

    (sprite_artifacts ++ inline_artifacts)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp manifest_modules(modules) when is_map(modules), do: Map.keys(modules)
  defp manifest_modules(modules) when is_list(modules), do: modules
  defp manifest_modules(_modules), do: []

  defp sprite_refs(module) do
    if function_exported?(module, :__sprite_refs__, 0) do
      module.__sprite_refs__()
    else
      []
    end
  end

  defp inline_refs(module) do
    if function_exported?(module, :__inline_refs__, 0) do
      module.__inline_refs__()
    else
      []
    end
  end

  defp write_sprite_sheets(sprite_builds) do
    sprite_builds
    |> Enum.map(fn {output_path, sprite_sheet} ->
      current_sprite =
        case File.read(output_path) do
          {:ok, contents} -> contents
          {:error, :enoent} -> nil
        end

      if current_sprite == sprite_sheet do
        :noop
      else
        File.write!(output_path, sprite_sheet)
        :ok
      end
    end)
    |> changed()
  end

  defp write_inline_registry(
         compile_path,
         generated_source_path,
         inline_registry_module,
         []
       ) do
    cleanup_inline_registry(compile_path, generated_source_path, inline_registry_module)
  end

  defp write_inline_registry(
         compile_path,
         generated_source_path,
         inline_registry_module,
         inline_sources
       ) do
    source = build_inline_registry_source(inline_registry_module, inline_sources)
    write_status = write_generated_source(generated_source_path, source)

    compile_status =
      compile_inline_registry(
        compile_path,
        generated_source_path,
        inline_registry_module,
        write_status
      )

    changed([write_status, compile_status])
  end

  defp write_generated_source(path, source) do
    write_if_changed(path, source)
  end

  defp compile_inline_registry(
         compile_path,
         generated_source_path,
         inline_registry_module,
         write_status
       ) do
    beam_path = generated_beam_path(compile_path, inline_registry_module)

    if write_status == :noop and File.exists?(beam_path) do
      :noop
    else
      unload_generated_module(inline_registry_module)

      case Kernel.ParallelCompiler.compile_to_path([generated_source_path], compile_path,
             return_diagnostics: true
           ) do
        {:ok, _modules, _warnings} ->
          unload_generated_module(inline_registry_module)
          :ok

        {:error, errors, warnings} ->
          diagnostics =
            Enum.map(List.wrap(errors), &diagnostic_message/1) ++ warning_messages(warnings)

          raise Mix.Error,
            message:
              "failed to compile generated inline registry:\n#{Enum.join(diagnostics, "\n")}"
      end
    end
  end

  defp cleanup_inline_registry(compile_path, generated_source_path, inline_registry_module) do
    unload_generated_module(inline_registry_module)

    changed([
      rm_if_exists(generated_source_path),
      rm_if_exists(generated_beam_path(compile_path, inline_registry_module))
    ])
  end

  defp inline_registry_artifact_paths(
         _compile_path,
         _generated_source_path,
         [],
         _inline_registry_module
       ),
       do: []

  defp inline_registry_artifact_paths(
         compile_path,
         generated_source_path,
         _inline_sources,
         inline_registry_module
       ) do
    [generated_source_path, generated_beam_path(compile_path, inline_registry_module)]
  end

  defp build_inline_registry_source(inline_registry_module, inline_sources) do
    inline_registry_module
    |> build_inline_registry_ast(inline_sources)
    |> Macro.to_string()
    |> Kernel.<>("\n")
  end

  defp build_inline_registry_ast(inline_registry_module, inline_sources) do
    external_resource_asts =
      Enum.map(inline_sources, fn %Source{file_path: file_path} ->
        quote do
          @external_resource unquote(file_path)
        end
      end)

    fetch_clause_asts =
      Enum.map(inline_sources, fn %Source{
                                    name: name,
                                    attributes: attributes,
                                    inner_content: inner_content
                                  } ->
        attrs_ast = literal_map_ast(attributes)

        quote do
          def fetch(unquote(name)) do
            {:ok,
             %InlineAsset{
               attributes: unquote(attrs_ast),
               inner_content: unquote(inner_content)
             }}
          end
        end
      end)

    inline_names = Enum.map(inline_sources, & &1.name)

    quote do
      defmodule unquote(inline_registry_module) do
        @moduledoc false

        alias SvgSpriteEx.InlineAsset

        unquote_splicing(external_resource_asts)

        @spec fetch(String.t()) :: {:ok, InlineAsset.t()} | :error
        unquote_splicing(fetch_clause_asts)
        def fetch(_name), do: :error

        @spec names() :: [String.t()]
        def names, do: unquote(inline_names)
      end
    end
  end

  defp generated_beam_path(compile_path, inline_registry_module) do
    Path.join(compile_path, Atom.to_string(inline_registry_module) <> ".beam")
  end

  defp generated_source_path do
    generated_source_path(elixir_manifest_path())
  end

  defp compiler_manifest_path do
    compiler_manifest_path(elixir_manifest_path())
  end

  defp compiler_manifest_path(elixir_manifest_path) do
    elixir_manifest_path
    |> Path.dirname()
    |> Path.join("compile.svg_sprite_ex_icons")
  end

  defp generated_source_path(elixir_manifest_path) do
    elixir_manifest_path
    |> Path.dirname()
    |> Path.join("svg_sprite_ex_generated_inline_icons.ex")
  end

  defp unload_generated_module(inline_registry_module) do
    :code.purge(inline_registry_module)
    :code.delete(inline_registry_module)
    :ok
  end

  defp warning_messages(%{compile_warnings: compile_warnings, runtime_warnings: runtime_warnings}) do
    Enum.map(compile_warnings ++ runtime_warnings, &diagnostic_message/1)
  end

  defp warning_messages(_warnings), do: []

  defp diagnostic_message(%{message: message}), do: message
  defp diagnostic_message(message) when is_binary(message), do: message
  defp diagnostic_message(other), do: inspect(other)

  defp literal_map_ast(map) do
    {:%{}, [], Enum.map(Enum.sort(map), fn {key, value} -> {key, value} end)}
  end

  defp read_compiler_manifest(path) do
    case File.read(path) do
      {:ok, binary} ->
        case :erlang.binary_to_term(binary, [:safe]) do
          %{vsn: @manifest_vsn, artifact_paths: artifact_paths} when is_list(artifact_paths) ->
            artifact_paths

          _other ->
            []
        end

      {:error, :enoent} ->
        []
    end
  end

  defp write_compiler_manifest(path, artifact_paths) do
    manifest =
      %{vsn: @manifest_vsn, artifact_paths: artifact_paths}
      |> :erlang.term_to_binary()

    write_if_changed(path, manifest)
  end

  defp cleanup_artifact_paths([]), do: :noop

  defp cleanup_artifact_paths(paths) do
    paths
    |> Enum.map(&rm_if_exists/1)
    |> changed()
  end

  defp write_if_changed(path, contents) do
    current_contents =
      case File.read(path) do
        {:ok, binary} -> binary
        {:error, :enoent} -> nil
      end

    if current_contents == contents do
      :noop
    else
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, contents)
      :ok
    end
  end

  defp rm_if_exists(path) do
    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :noop
    end
  end

  defp changed(results) do
    if Enum.any?(results, &(&1 == :ok)), do: :ok, else: :noop
  end

  defp elixir_manifest_path do
    Mix.Tasks.Compile.Elixir.manifests()
    |> List.first()
  end
end

defmodule Mix.Tasks.Verify.CrosswakeProviderFeedbackDocs do
  @moduledoc false
  use Mix.Task

  @shortdoc "Verify the selected CrossWake provider-feedback documentation contract"

  @docs_authority "priv/adoption/crosswake-provider-feedback-docs-selected-sha"
  @physical_authority "priv/mobile_proof/crosswake-selected-sha"
  @remote "https://github.com/szTheory/crosswake.git"
  @docs_ref "refs/heads/phase-104-provider-feedback-recipe-truth"
  @physical_ref "refs/heads/resume/chimeway-notification-physical-proof"
  @frozen_physical_sha "3165ab6938fa673f8a289c27699658bb78650ef3"

  @readme "examples/phoenix_host/README.md"
  @registry "examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex"
  @focused_test "examples/phoenix_host/test/crosswake_example/chimeway/provider_feedback_recipe_test.exs"
  @focused_test_from_host "test/crosswake_example/chimeway/provider_feedback_recipe_test.exs"

  @impl Mix.Task
  def run([]) do
    case verify() do
      :ok -> Mix.shell().info("crosswake_provider_feedback_docs_verified")
      :error -> exit({:shutdown, 70})
    end
  end

  def run(_args), do: exit({:shutdown, 64})

  @doc false
  def verify(overrides \\ []) do
    opts = Keyword.merge(default_options(), overrides)

    with {:ok, docs_sha} <- strict_sha(opts[:docs_authority]),
         {:ok, @frozen_physical_sha} <- strict_sha(opts[:physical_authority]),
         {:ok, ^docs_sha} <- opts[:advertised_head].(@remote, @docs_ref),
         {:ok, @frozen_physical_sha} <- opts[:advertised_head].(@remote, @physical_ref),
         {:ok, root} <- opts[:checkout].(docs_sha) do
      try do
        verify_checkout(root, docs_sha, opts)
      after
        opts[:cleanup].(root)
      end
    else
      _ -> :error
    end
  end

  defp default_options do
    [
      docs_authority: @docs_authority,
      physical_authority: @physical_authority,
      advertised_head: &advertised_head/2,
      checkout: &fresh_checkout/1,
      command: &System.cmd/3,
      focused_test: &run_focused_test/1,
      cleanup: &File.rm_rf/1
    ]
  end

  defp strict_sha(path) do
    with {:ok, value} <- File.read(path),
         sha = String.trim(value),
         true <- value == sha <> "\n",
         true <- Regex.match?(~r/\A[0-9a-f]{40}\z/, sha) do
      {:ok, sha}
    else
      _ -> :error
    end
  end

  defp advertised_head(remote, ref) do
    case System.cmd("git", ["ls-remote", remote, ref], stderr_to_stdout: true) do
      {output, 0} ->
        case String.split(output, "\n", trim: true) do
          [line] ->
            case String.split(line, "\t", parts: 2) do
              [sha, ^ref] when byte_size(sha) == 40 -> {:ok, sha}
              _ -> :error
            end

          _ ->
            :error
        end

      _ ->
        :error
    end
  end

  defp fresh_checkout(sha) do
    root =
      Path.join(
        System.tmp_dir!(),
        "chimeway-crosswake-docs-#{System.unique_integer([:positive])}"
      )

    with {_, 0} <-
           System.cmd("git", ["clone", "--quiet", "--no-checkout", @remote, root],
             stderr_to_stdout: true
           ),
         {_, 0} <-
           System.cmd("git", ["fetch", "--quiet", "origin", @docs_ref],
             cd: root,
             stderr_to_stdout: true
           ),
         {_, 0} <-
           System.cmd("git", ["checkout", "--quiet", "--detach", sha],
             cd: root,
             stderr_to_stdout: true
           ) do
      {:ok, root}
    else
      _ ->
        File.rm_rf(root)
        :error
    end
  end

  defp verify_checkout(root, sha, opts) do
    command = opts[:command]

    with {^sha <> "\n", 0} <-
           command.("git", ["rev-parse", "HEAD"], cd: root, stderr_to_stdout: true),
         {"", 0} <-
           command.("git", ["status", "--porcelain"], cd: root, stderr_to_stdout: true),
         :ok <- source_contract(root),
         :ok <- opts[:focused_test].(root) do
      :ok
    else
      _ -> :error
    end
  end

  defp source_contract(root) do
    with {:ok, readme} <- read(root, @readme),
         {:ok, registry} <- read(root, @registry),
         {:ok, focused_test} <- read(root, @focused_test),
         true <- not String.contains?(readme, "Contracts.ProviderFeedback.from_attrs"),
         {:ok, recipe} <- provider_feedback_recipe(readme),
         true <- remote_call?(recipe, :Redaction, :feedback_from_provider_attrs),
         true <- remote_call?(recipe, :Registry, :apply_provider_feedback),
         true <- String.contains?(recipe, "authenticated_provider_feedback_opts!"),
         true <- required_readme_scope?(readme),
         true <- registry_scope_contract?(registry),
         true <- executable_focused_test?(focused_test) do
      :ok
    else
      _ -> :error
    end
  end

  defp read(root, relative) do
    path = Path.join(root, relative)
    if File.regular?(path), do: File.read(path), else: :error
  end

  defp provider_feedback_recipe(readme) do
    case Regex.run(
           ~r/Provider feedback handling example:\s+```elixir\n(?<recipe>.*?)\n```/s,
           readme,
           capture: ["recipe"]
         ) do
      [recipe] -> {:ok, recipe}
      _ -> :error
    end
  end

  defp required_readme_scope?(readme) do
    Enum.all?(
      [
        "authenticated_context",
        "binding_ref",
        "installation_ref",
        "app_identity_ref",
        "session_ref",
        "session_version",
        "session-scoped",
        "installation-scoped",
        "corroborating evidence only",
        "never authenticates"
      ],
      &String.contains?(readme, &1)
    )
  end

  defp registry_scope_contract?(registry) do
    Enum.all?(
      [
        "defp provider_feedback_scope",
        ":authenticated_context",
        ":binding_ref",
        ":installation_ref",
        ":app_identity_ref",
        ":session_ref",
        ":session_version",
        ":invalid_provider_feedback_scope"
      ],
      &String.contains?(registry, &1)
    )
  end

  defp executable_focused_test?(source) do
    with {:ok, ast} <- Code.string_to_quoted(source) do
      ast
      |> module_proof_graphs()
      |> Enum.any?(&proof_graph_complete?/1)
    else
      _ -> false
    end
  end

  defp module_proof_graphs(ast) do
    ast
    |> ast_forms()
    |> Enum.flat_map(fn
      {:defmodule, _, [_module, body]} ->
        case keyword_do(body) do
          nil -> []
          module_body -> [{exunit_roots(module_body), local_definitions(module_body)}]
        end

      _other ->
        []
    end)
  end

  defp exunit_roots(module_body) do
    module_body
    |> ast_forms()
    |> Enum.flat_map(&declaration_roots/1)
  end

  defp declaration_roots({name, _, args}) when name in [:setup, :setup_all, :test] do
    case keyword_do(args) do
      nil -> []
      body -> [body]
    end
  end

  defp declaration_roots({:describe, _, args}) do
    case keyword_do(args) do
      nil -> []
      body -> exunit_roots(body)
    end
  end

  defp declaration_roots(_other), do: []

  defp local_definitions(module_body) do
    module_body
    |> ast_forms()
    |> Enum.reduce(%{}, fn
      {kind, _, [head, body]}, definitions when kind in [:def, :defp] ->
        with {name, arity} <- local_definition_key(head),
             definition_body when not is_nil(definition_body) <- keyword_do(body) do
          Map.update(definitions, {name, arity}, [definition_body], &[definition_body | &1])
        else
          _ -> definitions
        end

      _other, definitions ->
        definitions
    end)
  end

  defp local_definition_key({:when, _, [head | _guards]}), do: local_definition_key(head)

  defp local_definition_key({name, _, args}) when is_atom(name) and is_list(args),
    do: {name, length(args)}

  defp local_definition_key({name, _, nil}) when is_atom(name), do: {name, 0}
  defp local_definition_key(_head), do: nil

  defp proof_graph_complete?({roots, definitions}) when roots != [] do
    {markers, _visited} = walk_reachable(roots, definitions, MapSet.new(), MapSet.new())

    MapSet.member?(markers, :compile) and
      MapSet.member?(markers, :conversion) and
      (MapSet.member?(markers, :registry) or MapSet.member?(markers, :worker))
  end

  defp proof_graph_complete?(_graph), do: false

  defp walk_reachable([], _definitions, markers, visited), do: {markers, visited}

  defp walk_reachable([expression | rest], definitions, markers, visited) do
    {markers, calls} = scan_reachable_expression(expression, markers, MapSet.new())

    {definition_bodies, visited} =
      Enum.reduce(calls, {[], visited}, fn key, {bodies, seen} ->
        if MapSet.member?(seen, key) do
          {bodies, seen}
        else
          {Map.get(definitions, key, []) ++ bodies, MapSet.put(seen, key)}
        end
      end)

    walk_reachable(rest ++ definition_bodies, definitions, markers, visited)
  end

  defp scan_reachable_expression({:quote, _, _args}, markers, calls), do: {markers, calls}
  defp scan_reachable_expression({:fn, _, _clauses}, markers, calls), do: {markers, calls}
  defp scan_reachable_expression({:&, _, _capture}, markers, calls), do: {markers, calls}

  defp scan_reachable_expression(
         {{:., _, [{:__aliases__, _, aliases}, function]}, _, args},
         markers,
         calls
       )
       when is_list(args) do
    markers = record_remote_marker(markers, List.last(aliases), function)
    scan_reachable_expression(args, markers, calls)
  end

  defp scan_reachable_expression(
         {:apply, _, [{:__aliases__, _, aliases}, :perform, args]},
         markers,
         calls
       ) do
    markers =
      if List.last(aliases) == :ChimewayProviderFeedbackWorker do
        MapSet.put(markers, :worker)
      else
        markers
      end

    scan_reachable_expression(args, markers, calls)
  end

  defp scan_reachable_expression({name, _, args}, markers, calls)
       when is_atom(name) and is_list(args) do
    calls = MapSet.put(calls, {name, length(args)})
    scan_reachable_expression(args, markers, calls)
  end

  defp scan_reachable_expression(list, markers, calls) when is_list(list) do
    Enum.reduce(list, {markers, calls}, fn child, {found, local_calls} ->
      scan_reachable_expression(child, found, local_calls)
    end)
  end

  defp scan_reachable_expression(tuple, markers, calls) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> scan_reachable_expression(markers, calls)
  end

  defp scan_reachable_expression(_literal, markers, calls), do: {markers, calls}

  defp record_remote_marker(markers, :Code, :compile_string),
    do: MapSet.put(markers, :compile)

  defp record_remote_marker(markers, :Redaction, :feedback_from_provider_attrs),
    do: MapSet.put(markers, :conversion)

  defp record_remote_marker(markers, :Registry, :apply_provider_feedback),
    do: MapSet.put(markers, :registry)

  defp record_remote_marker(markers, _module, _function), do: markers

  defp ast_forms({:__block__, _, forms}), do: forms
  defp ast_forms(form), do: [form]

  defp keyword_do(arguments) when is_list(arguments) do
    if Keyword.keyword?(arguments) do
      Keyword.get(arguments, :do)
    else
      arguments
      |> Enum.reverse()
      |> Enum.find_value(fn
        keyword when is_list(keyword) -> Keyword.get(keyword, :do)
        _other -> nil
      end)
    end
  end

  defp keyword_do(_arguments), do: nil

  defp remote_call?(source, module, function) do
    with {:ok, ast} <- Code.string_to_quoted(source) do
      {_ast, found?} =
        Macro.prewalk(ast, false, fn
          {{:., _, [{:__aliases__, _, aliases}, ^function]}, _, _args} = node, found? ->
            {node, found? or List.last(aliases) == module}

          node, found? ->
            {node, found?}
        end)

      found?
    else
      _ -> false
    end
  end

  defp run_focused_test(root) do
    host = Path.join(root, "examples/phoenix_host")
    env = crosswake_test_env()

    with {_, 0} <-
           System.cmd("mix", ["deps.get"], cd: host, stderr_to_stdout: true, env: env),
         {_, 0} <-
           System.cmd(
             "mix",
             ["test", @focused_test_from_host, "--max-failures", "1", "--warnings-as-errors"],
             cd: host,
             stderr_to_stdout: true,
             env: env
           ) do
      :ok
    else
      _ -> :error
    end
  end

  defp crosswake_test_env do
    [
      {"MIX_ENV", "test"},
      {"ASDF_ERLANG_VERSION", "27.3.4.15"},
      {"ASDF_ELIXIR_VERSION", "1.19.5-otp-27"}
    ]
  end
end

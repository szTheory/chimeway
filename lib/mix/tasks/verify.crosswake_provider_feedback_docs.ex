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
    remote_call?(source, :Code, :compile_string) and
      remote_call?(source, :Redaction, :feedback_from_provider_attrs) and
      (remote_call?(source, :Registry, :apply_provider_feedback) or worker_perform_call?(source))
  end

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

  defp worker_perform_call?(source) do
    with {:ok, ast} <- Code.string_to_quoted(source) do
      {_ast, found?} =
        Macro.prewalk(ast, false, fn
          {:apply, _, [{:__aliases__, _, aliases}, :perform, _args]} = node, found? ->
            {node, found? or List.last(aliases) == :ChimewayProviderFeedbackWorker}

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

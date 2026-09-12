defmodule Chimeway.CrosswakeProviderFeedbackDocsContractTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Verify.CrosswakeProviderFeedbackDocs

  @docs_sha String.duplicate("a", 40)
  @physical_sha "3165ab6938fa673f8a289c27699658bb78650ef3"

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "crosswake-docs-contract-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(root)
    write_valid_fixture!(root)

    docs_authority = Path.join(root, "docs-selected-sha")
    physical_authority = Path.join(root, "physical-selected-sha")
    File.write!(docs_authority, @docs_sha <> "\n")
    File.write!(physical_authority, @physical_sha <> "\n")

    on_exit(fn -> File.rm_rf(root) end)

    opts = [
      docs_authority: docs_authority,
      physical_authority: physical_authority,
      advertised_head: fn
        _remote, "refs/heads/phase-104-provider-feedback-recipe-truth" -> {:ok, @docs_sha}
        _remote, "refs/heads/resume/chimeway-notification-physical-proof" -> {:ok, @physical_sha}
      end,
      checkout: fn @docs_sha -> {:ok, root} end,
      command: fn
        "git", ["rev-parse", "HEAD"], _opts -> {@docs_sha <> "\n", 0}
        "git", ["status", "--porcelain"], _opts -> {"", 0}
      end,
      focused_test: fn ^root ->
        send(self(), :focused_test_executed)
        :ok
      end,
      cleanup: fn ^root -> :ok end
    ]

    %{root: root, opts: opts}
  end

  test "accepts exact authorities, executable source, and a reached focused proof", %{opts: opts} do
    assert :ok = CrosswakeProviderFeedbackDocs.verify(opts)
    assert_received :focused_test_executed
  end

  test "rejects the nonexistent conversion API", %{root: root, opts: opts} do
    mutate!(root, readme_path(), fn source ->
      String.replace(
        source,
        "Redaction.feedback_from_provider_attrs(feedback_attrs)",
        "Contracts.ProviderFeedback.from_attrs(feedback_attrs)"
      )
    end)

    assert :error = CrosswakeProviderFeedbackDocs.verify(opts)
    refute_received :focused_test_executed
  end

  for key <- ~w(authenticated_context binding_ref installation_ref app_identity_ref) do
    test "rejects README authority scope without #{key}", %{root: root, opts: opts} do
      mutate!(root, readme_path(), &String.replace(&1, unquote(key), "missing_scope_key"))

      assert :error = CrosswakeProviderFeedbackDocs.verify(opts)
      refute_received :focused_test_executed
    end
  end

  test "rejects missing session authority guidance", %{root: root, opts: opts} do
    mutate!(root, readme_path(), fn source ->
      source
      |> String.replace("session_ref", "missing_session_reference")
      |> String.replace("session_version", "missing_session_counter")
    end)

    assert :error = CrosswakeProviderFeedbackDocs.verify(opts)
  end

  test "rejects an absent focused test", %{root: root, opts: opts} do
    File.rm!(Path.join(root, focused_test_path()))
    assert :error = CrosswakeProviderFeedbackDocs.verify(opts)
  end

  test "rejects a focused test that mentions but does not call the public boundaries", %{
    root: root,
    opts: opts
  } do
    File.write!(
      Path.join(root, focused_test_path()),
      ~S'''
      defmodule VacuousProof do
        def markers do
          [
            "Code.compile_string(recipe)",
            "Redaction.feedback_from_provider_attrs(attrs)",
            "Registry.apply_provider_feedback(feedback, opts)"
          ]
        end
      end
      '''
    )

    assert :error = CrosswakeProviderFeedbackDocs.verify(opts)
    refute_received :focused_test_executed
  end

  test "rejects either missing executable boundary call", %{root: root, opts: opts} do
    focused = Path.join(root, focused_test_path())
    original = File.read!(focused)

    for call <- [
          "Redaction.feedback_from_provider_attrs(attrs)",
          "Registry.apply_provider_feedback(feedback, opts)"
        ] do
      File.write!(focused, String.replace(original, call, ":not_executed"))
      assert :error = CrosswakeProviderFeedbackDocs.verify(opts)
      refute_received :focused_test_executed
    end
  end

  test "rejects physical authority movement independently of docs authority", %{opts: opts} do
    moved = String.duplicate("b", 40)

    opts =
      Keyword.put(opts, :advertised_head, fn
        _remote, "refs/heads/phase-104-provider-feedback-recipe-truth" -> {:ok, @docs_sha}
        _remote, "refs/heads/resume/chimeway-notification-physical-proof" -> {:ok, moved}
      end)

    assert :error = CrosswakeProviderFeedbackDocs.verify(opts)
    refute_received :focused_test_executed
  end

  test "rejects malformed and substituted selected authorities without fallback", %{
    root: root,
    opts: opts
  } do
    docs_authority = Keyword.fetch!(opts, :docs_authority)
    physical_authority = Keyword.fetch!(opts, :physical_authority)

    File.write!(docs_authority, "not-a-sha\n")
    assert :error = CrosswakeProviderFeedbackDocs.verify(opts)

    File.write!(docs_authority, @docs_sha <> "\n")
    File.write!(physical_authority, String.duplicate("c", 40) <> "\n")
    assert :error = CrosswakeProviderFeedbackDocs.verify(opts)

    refute_received :focused_test_executed
    assert File.dir?(root)
  end

  defp write_valid_fixture!(root) do
    write!(
      root,
      readme_path(),
      ~S'''
      Provider feedback handling example:
      ```elixir
      def perform(%Oban.Job{args: %{"feedback" => feedback_attrs}}) do
        with {:ok, feedback} <- Redaction.feedback_from_provider_attrs(feedback_attrs),
             opts <- authenticated_provider_feedback_opts!(feedback),
             {:ok, _result} <- Registry.apply_provider_feedback(feedback, opts) do
          :ok
        end
      end
      ```
      authenticated_context binding_ref installation_ref app_identity_ref
      A session-scoped binding also requires session_ref and session_version.
      installation-scoped authority omits both session keys.
      Provider tokens are corroborating evidence only and never authenticates invalidation.
      '''
    )

    write!(
      root,
      registry_path(),
      ~S'''
      defmodule Registry do
        defp provider_feedback_scope(opts) do
          opts[:authenticated_context]
          opts[:binding_ref]
          opts[:installation_ref]
          opts[:app_identity_ref]
          opts[:session_ref]
          opts[:session_version]
          {:error, :invalid_provider_feedback_scope}
        end
      end
      '''
    )

    write!(
      root,
      focused_test_path(),
      ~S'''
      defmodule ExecutableProof do
        def run(recipe, attrs, feedback, opts) do
          Code.compile_string(recipe)
          Redaction.feedback_from_provider_attrs(attrs)
          Registry.apply_provider_feedback(feedback, opts)
        end
      end
      '''
    )
  end

  defp mutate!(root, relative, mutation) do
    path = Path.join(root, relative)
    File.write!(path, mutation.(File.read!(path)))
  end

  defp write!(root, relative, content) do
    path = Path.join(root, relative)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end

  defp readme_path, do: "examples/phoenix_host/README.md"

  defp registry_path,
    do: "examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex"

  defp focused_test_path,
    do: "examples/phoenix_host/test/crosswake_example/chimeway/provider_feedback_recipe_test.exs"
end

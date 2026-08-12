defmodule Chimeway.Install.PrefixContractTest do
  use ExUnit.Case, async: true

  @moduledoc false

  @prefixed_root "test/fixtures/installer_golden_prefixed/tree/priv/repo/migrations"
  @mix_exs "mix.exs"
  @ci_yml ".github/workflows/ci.yml"

  @bare_ecto_patterns [
    {~r/\b(?:create|alter|drop)\s+(?:table|index|unique_index)\(:chimeway_[a-z0-9_]+/,
     "bare create/alter/drop operation"},
    {~r/\b(?:table|index|unique_index)\(:chimeway_[a-z0-9_]+/, "bare table/index helper call"},
    {~r/\breferences\(:chimeway_[a-z0-9_]+/, "bare references call"}
  ]

  @bare_sql_patterns [
    {~r/\b(?:UPDATE|FROM|JOIN|INTO|DELETE\s+FROM|ALTER\s+TABLE)\s+"?chimeway_[a-z0-9_]+/i,
     "bare raw SQL relation"}
  ]

  setup_all do
    files =
      @prefixed_root
      |> Path.join("*.exs")
      |> Path.wildcard()
      |> Enum.sort()

    assert length(files) == 32

    {:ok, files: files}
  end

  test "prefixed generated fixtures declare the chimeway prefix sentinel", %{files: files} do
    for path <- files do
      content = File.read!(path)

      assert content =~ ~s(@chimeway_prefix "chimeway"),
             "#{path} must render the dedicated chimeway prefix sentinel"

      refute content =~ "@chimeway_prefix false",
             "#{path} must not render public-mode prefix sentinel"

      refute content =~ "prefix: false",
             "#{path} must not emit unsafe false-prefix Ecto opts"
    end
  end

  test "prefixed generated Ecto operations are helper-qualified", %{files: files} do
    assert_no_matches(files, @bare_ecto_patterns)
  end

  test "prefixed generated raw SQL relation references are helper-qualified", %{files: files} do
    assert_no_matches(files, @bare_sql_patterns)

    joined =
      files
      |> Enum.map_join("\n", &File.read!/1)

    assert joined =~ "chimeway_relation(:chimeway_delivery_attempts)"
    assert joined =~ "chimeway_relation(:chimeway_workflow_runs)"
    assert joined =~ "chimeway_relation(:chimeway_deliveries)"
    assert joined =~ ~S|~s("#{@chimeway_prefix}"."#{name}")|
  end

  test "prefixed generated rollback keeps the no destructive schema cleanup contract", %{
    files: files
  } do
    for path <- files do
      content = File.read!(path)

      refute Regex.match?(~r/\bDROP\s+SCHEMA\b/i, content),
             "#{path} must not generate DROP SCHEMA rollback SQL"

      refute Regex.match?(~r/\bCASCADE\b/i, content),
             "#{path} must not generate destructive CASCADE cleanup"
    end
  end

  test "local and CI installer gates run the same verify.install_golden proof" do
    mix_exs = File.read!(@mix_exs)
    ci_yml = File.read!(@ci_yml)
    job_block = extract_ci_job_block(ci_yml, "install_golden_contract")

    assert Regex.match?(~r/"verify\.install_golden":\s*\[/, mix_exs),
           "mix.exs must define verify.install_golden"

    assert mix_exs =~ "test/chimeway/install/golden_diff_test.exs"
    assert mix_exs =~ "test/chimeway/install/idempotency_test.exs"
    assert mix_exs =~ "test/chimeway/install/prefix_contract_test.exs"
    assert mix_exs =~ "test/chimeway/migration_contract_test.exs"

    assert Regex.match?(~r/"ci\.install_golden":\s*\[\s*"verify\.install_golden"\s*\]/s, mix_exs),
           "ci.install_golden must invoke verify.install_golden instead of drifting"

    assert job_block =~ "postgres:15"
    assert job_block =~ "DATABASE_URL"
    assert job_block =~ "mix ecto.create"
    assert job_block =~ "mix ecto.migrate"
    assert job_block =~ "mix verify.install_golden"
    # Fixture-path coverage (public + prefixed) is asserted structurally above via the
    # verify.install_golden alias wiring (this prefix_contract_test uses the prefixed
    # fixtures; golden_diff/idempotency use the public tree). The CI job delegates to
    # `mix verify.install_golden` rather than inlining fixture paths (Phase 80-03 refactor),
    # so the job block intentionally no longer names the fixture directories.
  end

  defp assert_no_matches(files, patterns) do
    failures =
      for path <- files,
          {pattern, label} <- patterns,
          {line, line_number} <- File.read!(path) |> String.split("\n") |> Enum.with_index(1),
          Regex.match?(pattern, line) do
        "#{path}:#{line_number}: #{label}: #{String.trim(line)}"
      end

    assert failures == [],
           "prefixed generated output contains unqualified Chimeway references:\n" <>
             Enum.join(failures, "\n")
  end

  defp extract_ci_job_block(ci_yml, job_id) do
    case Regex.run(
           ~r/\n  #{Regex.escape(job_id)}:\n(?<block>.*?)(?=\n  [a-zA-Z0-9_-]+:\n|\z)/s,
           ci_yml,
           capture: ["block"]
         ) do
      [block] -> block
      _ -> flunk("Could not extract #{job_id} job from ci.yml")
    end
  end
end

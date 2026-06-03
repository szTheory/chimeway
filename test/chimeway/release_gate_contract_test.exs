defmodule Chimeway.ReleaseGateContractTest do
  use ExUnit.Case, async: true

  @moduledoc false

  @maintaining "MAINTAINING.md"
  @mix_exs "mix.exs"
  @ci_yml ".github/workflows/ci.yml"
  @release_yml ".github/workflows/release.yml"
  @manifest ".release-please-manifest.json"
  @publish_hex_yml ".github/workflows/publish-hex.yml"
  @ci_gate_lanes ~w(lint test verify_gates verify_docs verify_example verify_journeys verify_mailglass verify_accrue verify_inbox verify_threadline verify_sigra)

  @pre_ship_verify_commands [
    {"verify.example", "verify_example", "mix verify.example"},
    {"verify.journeys", "verify_journeys", "mix verify.journeys"},
    {"verify.mailglass", "verify_mailglass", "mix verify.mailglass"},
    {"verify.accrue", "verify_accrue", "mix verify.accrue"},
    {"verify.inbox", "verify_inbox", "mix verify.inbox"},
    {"verify.threadline", "verify_threadline", "mix verify.threadline"},
    {"verify.sigra", "verify_sigra", "mix verify.sigra"}
  ]

  describe "release gate parity doc contract (GATE-05)" do
    setup do
      maintaining = File.read!(@maintaining)
      mix_exs = File.read!(@mix_exs)
      ci_yml = File.read!(@ci_yml)
      pre_ship_block = extract_pre_ship_block(maintaining)

      %{
        maintaining: maintaining,
        mix_exs: mix_exs,
        ci_yml: ci_yml,
        pre_ship_block: pre_ship_block
      }
    end

    for {_alias, slug, command} <- @pre_ship_verify_commands do
      test "MAINTAINING pre-ship block lists #{slug} gate", %{pre_ship_block: pre_ship_block} do
        assert String.contains?(pre_ship_block, unquote(command)),
               "MAINTAINING.md pre-ship block must list #{unquote(command)}"
      end
    end

    test "MAINTAINING documents ten-gate pre-ship requirement", %{maintaining: maintaining} do
      assert Regex.match?(~r/All ten must pass/i, maintaining),
             "MAINTAINING.md must state all ten verify gates must pass before publishing"
    end

    test "MAINTAINING documents ACCRUE_PATH sibling checkout", %{maintaining: maintaining} do
      assert String.contains?(maintaining, "ACCRUE_PATH"),
             "MAINTAINING.md must document ACCRUE_PATH for local Accrue verify runs"
    end

    test "MAINTAINING documents THREADLINE_PATH sibling checkout", %{maintaining: maintaining} do
      assert String.contains?(maintaining, "THREADLINE_PATH"),
             "MAINTAINING.md must document THREADLINE_PATH for local Threadline verify runs"
    end

    test "MAINTAINING documents SIGRA_PATH sibling checkout", %{maintaining: maintaining} do
      assert String.contains?(maintaining, "SIGRA_PATH"),
             "MAINTAINING.md must document SIGRA_PATH for local Sigra verify runs"
    end

    for {alias_name, slug, command} <- @pre_ship_verify_commands do
      test "mix.exs defines #{slug} alias for pre-ship gate", %{mix_exs: mix_exs} do
        assert Regex.match?(~r/"#{Regex.escape(unquote(alias_name))}":\s*\[/, mix_exs),
               "mix.exs must define \"#{unquote(alias_name)}\" alias matching #{unquote(command)}"
      end
    end

    for {_alias, job_id, command} <- @pre_ship_verify_commands do
      test "ci.yml #{job_id} job runs pre-ship gate command", %{ci_yml: ci_yml} do
        assert Regex.match?(~r/#{unquote(job_id)}:/, ci_yml),
               "ci.yml must define #{unquote(job_id)} job"

        job_block = extract_ci_job_block(ci_yml, unquote(job_id))

        if unquote(job_id) == "verify_sigra" do
          assert String.contains?(job_block, unquote(command)) or
                   (String.contains?(
                      job_block,
                      "test/chimeway/integrations/sigra_auth_lifecycle_test.exs"
                    ) and
                      String.contains?(job_block, "test/demo_host_web/sigra_auth_proof_test.exs") and
                      String.contains?(job_block, "CHIMEWAY_SKIP_THREADLINE_DEP")),
                 "verify_sigra job must run #{unquote(command)} or its explicit root/demo proof lanes"
        else
          assert String.contains?(job_block, unquote(command)),
                 "#{unquote(job_id)} job must run #{unquote(command)}"
        end
      end
    end

    test "verify_accrue job checks out szTheory/accrue with ACCRUE_PATH", %{ci_yml: ci_yml} do
      job_block = extract_ci_job_block(ci_yml, "verify_accrue")

      assert String.contains?(job_block, "szTheory/accrue"),
             "verify_accrue job must checkout szTheory/accrue sibling repo"

      assert String.contains?(job_block, "ACCRUE_PATH"),
             "verify_accrue job must set ACCRUE_PATH for sibling checkout"

      assert String.contains?(job_block, "236fa2f1649e771f3b515603495436badeed3c7b"),
             "verify_accrue job must pin Accrue integration ref"
    end

    test "verify_threadline job checks out szTheory/threadline with THREADLINE_PATH", %{
      ci_yml: ci_yml
    } do
      job_block = extract_ci_job_block(ci_yml, "verify_threadline")

      assert String.contains?(job_block, "szTheory/threadline"),
             "verify_threadline job must checkout szTheory/threadline sibling repo"

      assert String.contains?(job_block, "THREADLINE_PATH"),
             "verify_threadline job must set THREADLINE_PATH for sibling checkout"
    end

    test "verify_sigra job checks out szTheory/sigra with SIGRA_PATH", %{ci_yml: ci_yml} do
      job_block = extract_ci_job_block(ci_yml, "verify_sigra")

      assert String.contains?(job_block, "szTheory/sigra"),
             "verify_sigra job must checkout szTheory/sigra sibling repo"

      assert String.contains?(job_block, "SIGRA_PATH"),
             "verify_sigra job must set SIGRA_PATH for sibling checkout"
    end
  end

  describe "release pipeline contract (GATE-06)" do
    setup do
      ci_yml = File.read!(@ci_yml)
      release_yml = File.read!(@release_yml)
      maintaining = File.read!(@maintaining)
      publish_hex_yml = File.read!(@publish_hex_yml)

      %{
        ci_yml: ci_yml,
        release_yml: release_yml,
        maintaining: maintaining,
        publish_hex_yml: publish_hex_yml
      }
    end

    test "verify_gates job runs mix ci.verify_gates", %{ci_yml: ci_yml} do
      job_block = extract_ci_job_block(ci_yml, "verify_gates")
      assert String.contains?(job_block, "mix ci.verify_gates")
    end

    test "verify_docs job runs mix ci.docs", %{ci_yml: ci_yml} do
      job_block = extract_ci_job_block(ci_yml, "verify_docs")
      assert String.contains?(job_block, "mix ci.docs")
    end

    test "ci-gate aggregates 11 required lanes", %{ci_yml: ci_yml} do
      needs = extract_ci_gate_needs(ci_yml)

      for lane <- @ci_gate_lanes do
        assert lane in needs, "ci-gate must need #{lane}"
      end
    end

    test "install_golden_contract outside ci-gate needs", %{ci_yml: ci_yml} do
      needs = extract_ci_gate_needs(ci_yml)
      refute "install_golden_contract" in needs
    end

    test "docs.yml retired" do
      refute File.exists?(".github/workflows/docs.yml")
    end

    test "manifest version matches mix.exs @version" do
      manifest_content = File.read!(@manifest)
      mix_exs = File.read!(@mix_exs)

      manifest_version =
        case Regex.run(~r/"\."\s*:\s*"([^"]+)"/, manifest_content) do
          [_, version] -> version
          _ -> flunk("Could not parse version from #{@manifest}")
        end

      assert Regex.match?(~r/@version\s+"#{Regex.escape(manifest_version)}"/, mix_exs),
             "manifest #{manifest_version} must match mix.exs @version"
    end

    test "release.yml contains gate-ci-green and ci-gate poll", %{release_yml: release_yml} do
      assert String.contains?(release_yml, "gate-ci-green")
      assert String.contains?(release_yml, "ci-gate")
    end

    test "release.yml pre-publish replay includes verify_gates and docs", %{
      release_yml: release_yml
    } do
      assert String.contains?(release_yml, "mix ci.verify_gates")
      assert String.contains?(release_yml, "mix ci.docs")
    end

    test "release.yml publish-hex needs gate-ci-green", %{release_yml: release_yml} do
      publish_block = extract_ci_job_block(release_yml, "publish-hex")
      assert String.contains?(publish_block, "gate-ci-green")
    end

    test "MAINTAINING documents Release Please automated path", %{maintaining: maintaining} do
      assert String.contains?(maintaining, "Release Please")
    end

    test "publish-hex recovery exists and gates on ci-gate only", %{
      publish_hex_yml: publish_hex_yml
    } do
      assert String.contains?(publish_hex_yml, "ci-gate")
      refute String.contains?(publish_hex_yml, "requiredPrefixes")
    end
  end

  describe "verify-lane test-count floor (WARNING-2)" do
    test "each verify lane declares at least its expected integration-test count" do
      sigra_root = count_tests([
        "test/chimeway/integrations/sigra_auth_harness_test.exs",
        "test/chimeway/integrations/sigra_auth_lifecycle_test.exs"
      ])
      sigra_demo = count_tests(["examples/chimeway_demo_host/test/demo_host_web/sigra_auth_proof_test.exs"])
      accrue = count_tests([
        "test/chimeway/integrations/accrue_dunning_harness_test.exs",
        "test/chimeway/integrations/accrue_dunning_lifecycle_test.exs"
      ])
      threadline = count_tests([
        "test/chimeway/integrations/threadline_telemetry_harness_test.exs",
        "test/chimeway/integrations/threadline_telemetry_lifecycle_test.exs"
      ])

      assert sigra_root >= 5, "sigra root lane must have >= 5 integration tests (found #{sigra_root})"
      assert sigra_demo >= 2, "sigra demo-host lane must have >= 2 integration tests (found #{sigra_demo})"
      assert accrue >= 11, "accrue lane must have >= 11 integration tests (found #{accrue})"
      assert threadline >= 7, "threadline lane must have >= 7 integration tests (found #{threadline})"
    end
  end

  defp count_tests(files) do
    Enum.reduce(files, 0, fn file, acc ->
      content = File.read!(file)
      count = Regex.scan(~r/^\s*test "/m, content) |> length()
      acc + count
    end)
  end

  defp extract_pre_ship_block(maintaining) do
    ~r/```bash\n(.*?)```/s
    |> Regex.scan(maintaining)
    |> Enum.find_value(fn [_, block] ->
      if String.starts_with?(block, "mix ci\n") or String.starts_with?(block, "mix ci\r\n") do
        block
      end
    end)
    |> case do
      nil -> flunk("MAINTAINING.md must contain a pre-ship ```bash fenced block with mix ci")
      block -> block
    end
  end

  defp extract_ci_job_block(yml, job_id) do
    case Regex.run(~r/#{job_id}:(.*?)(?:\n  [a-z_]+:|\z)/s, yml) do
      [_, block] -> block
      _ -> flunk("Could not extract #{job_id} job block from #{yml}")
    end
  end

  defp extract_ci_gate_needs(ci_yml) do
    case Regex.run(~r/ci-gate:.*?needs:\s*\[(.*?)\]/s, ci_yml) do
      [_, needs_str] ->
        needs_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      _ ->
        flunk("Could not extract ci-gate needs from ci.yml")
    end
  end
end

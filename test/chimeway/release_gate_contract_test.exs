defmodule Chimeway.ReleaseGateContractTest do
  use ExUnit.Case, async: true

  @moduledoc false

  @maintaining "MAINTAINING.md"
  @mix_exs "mix.exs"
  @ci_yml ".github/workflows/ci.yml"
  @release_yml ".github/workflows/release.yml"
  @manifest ".release-please-manifest.json"
  @publish_hex_yml ".github/workflows/publish-hex.yml"
  @readme "README.md"
  @changelog "CHANGELOG.md"
  @canonical_repo_url "https://github.com/szTheory/chimeway"
  @legacy_repo_url "https://github.com/jonlunsford/chimeway"
  @package_facing_source_files ~w(mix.exs README.md CHANGELOG.md .github/workflows/release.yml .github/workflows/publish-hex.yml)
  @release_please_config "release-please-config.json"
  @sibling_packages ~w(chimeway_admin chimeway_inbox)
  @ci_gate_lanes ~w(lint test verify_gates verify_docs verify_example verify_runtime_prefix verify_journeys verify_mailglass verify_accrue verify_inbox verify_threadline verify_sigra verify_admin install_golden_contract)
  @pr_gate_lanes ~w(lint test verify_gates verify_docs)

  @pre_ship_verify_commands [
    {"verify.example", "verify_example", "mix verify.example"},
    {"verify.runtime_prefix", "verify_runtime_prefix", "mix verify.runtime_prefix"},
    {"verify.journeys", "verify_journeys", "mix verify.journeys"},
    {"verify.mailglass", "verify_mailglass", "mix verify.mailglass"},
    {"verify.accrue", "verify_accrue", "mix verify.accrue"},
    {"verify.inbox", "verify_inbox", "mix verify.inbox"},
    {"verify.threadline", "verify_threadline", "mix verify.threadline"},
    {"verify.sigra", "verify_sigra", "mix verify.sigra"},
    {"verify.admin", "verify_admin", "mix verify.admin"}
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

    test "MAINTAINING documents twelve-gate pre-ship requirement", %{maintaining: maintaining} do
      assert Regex.match?(~r/All twelve must pass/i, maintaining),
             "MAINTAINING.md must state all twelve verify gates must pass before publishing"
    end

    test "MAINTAINING documents storage-prefix gate responsibilities", %{
      maintaining: maintaining
    } do
      for required <- [
            "mix verify.runtime_prefix",
            "configured-schema runtime behavior",
            "public-schema legacy compatibility",
            "mix verify.install_golden",
            "mix ci.install_golden",
            "path-gated"
          ] do
        assert String.contains?(maintaining, required),
               "MAINTAINING.md must document storage gate copy: #{required}"
      end
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

    test "mix.exs defines installer golden local and CI aliases", %{mix_exs: mix_exs} do
      assert Regex.match?(~r/"verify\.install_golden":\s*\[/, mix_exs),
             "mix.exs must define verify.install_golden"

      assert Regex.match?(~r/"ci\.install_golden":\s*\[/, mix_exs),
             "mix.exs must define ci.install_golden"
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
                      "test/support/sigra/ci_proof_runner.exs"
                    ) and
                      String.contains?(job_block, "test/demo_host_web/sigra_auth_proof_test.exs") and
                      String.contains?(job_block, "CHIMEWAY_SKIP_THREADLINE_DEP") and
                      String.contains?(job_block, "CHIMEWAY_SKIP_MAILGLASS_DEP") and
                      String.contains?(job_block, "CHIMEWAY_SKIP_ACCRUE_DEP") and
                      String.contains?(job_block, "CHIMEWAY_SKIP_SIGRA_TRANSITIVE_DEP") and
                      String.contains?(job_block, "CHIMEWAY_FORCE_SIGRA_TEST_REPO_SETUP") and
                      String.contains?(job_block, "CHIMEWAY_MANUAL_REPO_START") and
                      String.contains?(job_block, "CHIMEWAY_SKIP_OBAN") and
                      String.contains?(job_block, "PGUSER: postgres") and
                      String.contains?(job_block, "POSTGRES_USER: postgres") and
                      String.contains?(job_block, "Prepare root test database") and
                      String.contains?(job_block, "timeout 600s mix ecto.create") and
                      String.contains?(job_block, "timeout 300s elixir $(") and
                      String.contains?(job_block, "find _build/test/lib") and
                      String.contains?(job_block, "timeout 600s mix deps.compile") and
                      String.contains?(job_block, "timeout 300s mix compile") and
                      String.contains?(job_block, "timeout 300s mix test")),
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

    test "ci-gate aggregates 14 required lanes", %{ci_yml: ci_yml} do
      needs = extract_ci_gate_needs(ci_yml)

      assert length(needs) == length(@ci_gate_lanes)

      for lane <- @ci_gate_lanes do
        assert lane in needs, "ci-gate must need #{lane}"
      end
    end

    test "install_golden_contract exists, runs installer proof, and is folded into ci-gate", %{
      ci_yml: ci_yml
    } do
      job_block = extract_ci_job_block(ci_yml, "install_golden_contract")
      needs = extract_ci_gate_needs(ci_yml)

      assert String.contains?(job_block, "mix verify.install_golden")
      assert "install_golden_contract" in needs
    end

    test "pr-gate aggregates exactly the fast subset lanes (CI-01)", %{ci_yml: ci_yml} do
      needs = extract_pr_gate_needs(ci_yml)

      assert length(needs) == length(@pr_gate_lanes)

      for lane <- @pr_gate_lanes do
        assert lane in needs, "pr-gate must need #{lane}"
      end

      for lane <- needs do
        assert lane in @pr_gate_lanes,
               "pr-gate must not need lane outside the fast subset: #{lane}"
      end
    end

    test "pr-gate feeding lanes carry no path filter (CI-03 anti-pending lock)", %{
      ci_yml: ci_yml
    } do
      for lane <- @pr_gate_lanes do
        job_block = extract_ci_job_block(ci_yml, lane)

        refute String.contains?(job_block, "paths:"),
               "#{lane} job must not carry a paths: filter (would strand required pr-gate)"

        refute String.contains?(job_block, "paths-ignore:"),
               "#{lane} job must not carry a paths-ignore: filter (would strand required pr-gate)"
      end
    end

    test "ci-gate is push/dispatch-only and keeps its literal name (CI-02)", %{ci_yml: ci_yml} do
      job_block = extract_ci_job_block(ci_yml, "ci-gate")

      assert String.contains?(job_block, "github.event_name != 'pull_request'"),
             "ci-gate must be guarded off pull_request events"

      assert String.contains?(job_block, "name: ci-gate"),
             "ci-gate job name must stay literally ci-gate (release/publish/automerge poll it by name)"
    end

    test "install_golden_contract is PR-exempt and keeps its detect-step pattern (D-04)", %{
      ci_yml: ci_yml
    } do
      job_block = extract_ci_job_block(ci_yml, "install_golden_contract")

      assert String.contains?(job_block, "if: github.event_name != 'pull_request'"),
             "install_golden_contract must carry the job-level PR-exemption guard"

      assert String.contains?(job_block, "steps.detect.outputs.run == 'true'"),
             "install_golden_contract must keep its detect-step conditional pattern"

      assert String.contains?(job_block, "mix verify.install_golden"),
             "install_golden_contract must keep running the installer proof"
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
      sigra_root =
        count_tests([
          "test/chimeway/integrations/sigra_auth_harness_test.exs",
          "test/chimeway/integrations/sigra_auth_lifecycle_test.exs"
        ])

      sigra_demo =
        count_tests(["examples/chimeway_demo_host/test/demo_host_web/sigra_auth_proof_test.exs"])

      accrue =
        count_tests([
          "test/chimeway/integrations/accrue_dunning_harness_test.exs",
          "test/chimeway/integrations/accrue_dunning_lifecycle_test.exs"
        ])

      threadline =
        count_tests([
          "test/chimeway/integrations/threadline_telemetry_harness_test.exs",
          "test/chimeway/integrations/threadline_telemetry_lifecycle_test.exs"
        ])

      assert sigra_root >= 5,
             "sigra root lane must have >= 5 integration tests (found #{sigra_root})"

      assert sigra_demo >= 2,
             "sigra demo-host lane must have >= 2 integration tests (found #{sigra_demo})"

      assert accrue >= 11, "accrue lane must have >= 11 integration tests (found #{accrue})"

      assert threadline >= 7,
             "threadline lane must have >= 7 integration tests (found #{threadline})"
    end
  end

  describe "root package and source truth (TRUTH-01/TRUTH-02, D-01/D-03)" do
    setup do
      %{
        mix_exs: File.read!(@mix_exs),
        readme: File.read!(@readme),
        changelog: File.read!(@changelog),
        manifest: File.read!(@manifest),
        version: root_version!()
      }
    end

    test "root package release identity uses package SemVer refs", ctx do
      version = ctx.version

      # SemVer shape guard: root @version is a package SemVer, not a planning label.
      assert Regex.match?(~r/^\d+\.\d+\.\d+/, version),
             "root @version must be package SemVer such as 1.0.0 (found #{inspect(version)})"

      # Release Please manifest agrees on the single root package version.
      manifest = Jason.decode!(ctx.manifest)

      assert Map.keys(manifest) == ["."],
             "manifest must contain exactly the root \".\" package entry"

      assert manifest["."] == version,
             "manifest root version #{inspect(manifest["."])} must equal mix.exs @version #{inspect(version)}"

      # CHANGELOG has a package release heading for the current version.
      assert Regex.match?(~r/^##\s+#{Regex.escape(version)}\b/m, ctx.changelog),
             "CHANGELOG.md must contain a `## #{version}` package release heading"

      # HexDocs source ref stays pinned to the tagged package version.
      assert String.contains?(ctx.mix_exs, ~S(source_ref: "v#{@version}")),
             "mix.exs must keep source_ref: \"v\#{@version}\" so HexDocs points at the release tag"

      # README install constraint is derived from the current MAJOR.MINOR.
      [major, minor | _] = String.split(version, ".")
      constraint = ~s({:chimeway, "~> #{major}.#{minor}"})

      assert String.contains?(ctx.readme, constraint),
             "README.md must show install constraint #{constraint} derived from @version"
    end

    test "package-facing repository and source URLs use the canonical repository", ctx do
      for file <- @package_facing_source_files do
        content = File.read!(file)

        refute String.contains?(content, @legacy_repo_url),
               "#{file} must not reference the legacy repository URL #{@legacy_repo_url}"
      end

      # mix.exs package metadata and HexDocs source both point at the canonical repo.
      assert String.contains?(
               ctx.mix_exs,
               ~s(links: %{"GitHub" => "#{@canonical_repo_url}"})
             ),
             "mix.exs package links must use #{@canonical_repo_url}"

      assert String.contains?(ctx.mix_exs, ~s(source_url: "#{@canonical_repo_url}")),
             "mix.exs docs source_url must use #{@canonical_repo_url}"

      # README CI badge links to the canonical repository Actions workflow.
      assert String.contains?(
               ctx.readme,
               "#{@canonical_repo_url}/actions/workflows/ci.yml"
             ),
             "README.md CI badge must link to #{@canonical_repo_url}/actions/workflows/ci.yml"
    end
  end

  describe "root-only Release Please and publish workflows (D-02)" do
    setup do
      %{
        release_please_config: File.read!(@release_please_config),
        release_yml: File.read!(@release_yml),
        publish_hex_yml: File.read!(@publish_hex_yml)
      }
    end

    test "Release Please config stays root-only", ctx do
      config = Jason.decode!(ctx.release_please_config)

      assert Map.keys(config["packages"]) == ["."],
             "release-please-config.json must contain exactly the root \".\" package"

      root = config["packages"]["."]

      assert root["changelog-path"] == "CHANGELOG.md",
             "root package changelog-path must be CHANGELOG.md"

      assert root["include-v-in-tag"] == true,
             "root package include-v-in-tag must be true for v-prefixed package tags"
    end

    test "release workflow builds and publishes the root package from the release tag", ctx do
      release_yml = ctx.release_yml

      for required <- [
            "config-file: release-please-config.json",
            "manifest-file: .release-please-manifest.json",
            "needs.release-please.outputs.tag_name",
            ~S(grep -n "@version \"${RELEASE_VERSION}\"" mix.exs),
            "mix ci.verify_gates",
            "mix ci.docs",
            "mix hex.build"
          ] do
        assert String.contains?(release_yml, required),
               "release.yml must include release truth marker: #{required}"
      end

      # HEX_API_KEY is scoped to Hex publish steps, never the Release Please job.
      assert String.contains?(release_yml, "secrets.HEX_API_KEY"),
             "release.yml must reference secrets.HEX_API_KEY for Hex publish"

      # Scope to the release-please job body: from its job header to the next
      # top-level job (job names contain hyphens, so split on the header text).
      # This excludes the file-level comment header that names the secret.
      release_please_block =
        release_yml
        |> String.split("\n  release-please:", parts: 2)
        |> List.last()
        |> String.split("\n  bootstrap-release-pr-ci:", parts: 2)
        |> List.first()

      refute String.contains?(release_please_block, "HEX_API_KEY"),
             "release-please job must not carry HEX_API_KEY"

      for sibling <- @sibling_packages do
        refute String.contains?(release_yml, sibling),
               "release.yml must not add a #{sibling} publish lane"
      end
    end

    test "recovery publish workflow stays rooted on the chimeway package", ctx do
      publish_hex_yml = ctx.publish_hex_yml

      for required <- [
            "workflow_dispatch:",
            "release_version:",
            "tag must be a 40-character commit SHA or an existing git tag",
            ~S(grep -n "@version \"${RELEASE_VERSION}\"" mix.exs),
            "mix ci.verify_gates",
            "mix ci.docs",
            "mix hex.build",
            "mix hex.publish --dry-run --yes",
            "mix hex.publish --yes"
          ] do
        assert String.contains?(publish_hex_yml, required),
               "publish-hex.yml must include recovery truth marker: #{required}"
      end

      for sibling <- @sibling_packages do
        refute String.contains?(publish_hex_yml, sibling),
               "publish-hex.yml must not add a #{sibling} publish lane"
      end
    end
  end

  describe "unpacked Hex package artifact truth (TRUTH-01/TRUTH-02/TRUTH-03, D-08)" do
    setup do
      output = build_unpacked_package!()
      on_exit(fn -> File.rm_rf(output) end)
      %{output: output, root: unpacked_package_root!(output)}
    end

    test "unpacked Hex package contains the package file whitelist", %{root: root} do
      entries = top_level_entries(root)

      # Mirrors files: ~w(lib priv guides CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs) in mix.exs
      whitelist = ~w(lib priv guides CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs)

      for entry <- whitelist do
        assert entry in entries,
               "unpacked package root must contain whitelist entry #{entry} (found: #{inspect(entries)})"
      end

      # Hex adds hex_metadata.config to every unpacked artifact; ignore only that
      # generated file and require the root to carry exactly the mix.exs whitelist,
      # so stray/untracked additions to the package also fail the release gate.
      extra = (entries -- whitelist) -- ["hex_metadata.config"]

      assert extra == [],
             "unpacked package root must not contain files outside the whitelist (unexpected: #{inspect(extra)})"
    end

    test "unpacked Hex package carries package truth docs and source links", %{root: root} do
      mix_exs = File.read!(Path.join(root, @mix_exs))
      readme = File.read!(Path.join(root, @readme))

      admin_guide =
        File.read!(Path.join(root, "guides/introduction/admin-console-integration.md"))

      inbox_guide = File.read!(Path.join(root, "guides/introduction/inbox-integration.md"))

      # Canonical package/source links reach Hex consumers; the legacy owner never does.
      assert String.contains?(mix_exs, @canonical_repo_url),
             "unpacked mix.exs must carry the canonical repository URL #{@canonical_repo_url}"

      refute String.contains?(mix_exs, @legacy_repo_url),
             "unpacked mix.exs must not carry the legacy repository URL #{@legacy_repo_url}"

      refute String.contains?(readme, @legacy_repo_url),
             "unpacked README.md must not carry the legacy repository URL #{@legacy_repo_url}"

      # Root install constraint is carried in the packaged README.
      assert String.contains?(readme, ~S({:chimeway, "~> 1.0"})),
             "unpacked README.md must carry the root install constraint {:chimeway, \"~> 1.0\"}"

      # ADPT-01 / D-07: the DOCS-14/15/16 public-story invariants must survive Hex
      # packaging. Marker strings are byte-identical to the source-tree README
      # contract (doc_contract_test.exs @readme_decision_markers + @required), so
      # the packaged and source contracts stay in lockstep.
      for marker <- [
            "local-first",
            "## Non-goals",
            "## Host-owned boundaries",
            "in-repo preview/path package",
            "Chimeway.Traces.explain_delivery"
          ] do
        assert String.contains?(readme, marker),
               "unpacked README.md must carry the public-story marker #{marker}"
      end

      # Sibling preview/path status reaches Hex consumers, no current-Hex install claim.
      for {guide, name} <- [{admin_guide, "admin"}, {inbox_guide, "inbox"}] do
        assert String.contains?(guide, "in-repo preview/path package"),
               "unpacked #{name} guide must state in-repo preview/path status"

        assert String.contains?(guide, "not published on Hex yet"),
               "unpacked #{name} guide must state the sibling is not published on Hex yet"
      end

      refute String.contains?(admin_guide, ~S({:chimeway_admin, "~> 1.0"})),
             "unpacked admin guide must not carry a current-Hex chimeway_admin install claim"

      refute String.contains?(inbox_guide, ~S({:chimeway_inbox, "~> 1.0"})),
             "unpacked inbox guide must not carry a current-Hex chimeway_inbox install claim"
    end
  end

  # Builds the default root Hex package into a unique temp dir and unpacks it.
  # Runs in a separate OS process under MIX_ENV=prod: the prod package build omits
  # the dev/test-only Sigra override, so `mix hex.build` succeeds exactly as it does
  # at release time (no CHIMEWAY_SKIP_SIGRA_DEP).
  defp build_unpacked_package! do
    output =
      Path.join(System.tmp_dir!(), "chimeway_release_gate_#{System.unique_integer([:positive])}")

    File.rm_rf!(output)

    {out, status} =
      System.cmd("mix", ["hex.build", "--unpack", "--output", output],
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "prod"}]
      )

    assert status == 0,
           "mix hex.build --unpack must succeed for the default root package under MIX_ENV=prod (exit #{status}):\n#{out}"

    output
  end

  # Hex task output shape varies by version: files may land directly in the
  # output dir, or under a single `chimeway-*` child that contains mix.exs.
  defp unpacked_package_root!(output) do
    if File.exists?(Path.join(output, @mix_exs)) do
      output
    else
      case Path.wildcard(Path.join(output, "chimeway-*")) do
        [child] ->
          if File.exists?(Path.join(child, @mix_exs)),
            do: child,
            else: flunk("unpacked package child #{child} does not contain #{@mix_exs}")

        candidates ->
          flunk(
            "could not locate unpacked package root under #{output} (candidates: #{inspect(candidates)})"
          )
      end
    end
  end

  defp top_level_entries(root) do
    root |> File.ls!() |> Enum.sort()
  end

  defp root_version! do
    mix_exs = File.read!(@mix_exs)

    case Regex.run(~r/@version\s+"([^"]+)"/, mix_exs) do
      [_, version] -> version
      _ -> flunk("Could not parse @version from #{@mix_exs}")
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

  defp extract_pr_gate_needs(ci_yml) do
    case Regex.run(~r/pr-gate:.*?needs:\s*\[(.*?)\]/s, ci_yml) do
      [_, needs_str] ->
        needs_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      _ ->
        flunk("Could not extract pr-gate needs from ci.yml")
    end
  end
end

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
  @ci_gate_lanes ~w(lint test verify_gates verify_docs verify_example verify_runtime_prefix verify_journeys verify_mailglass verify_accrue verify_inbox verify_threadline verify_sigra install_golden_contract test_floor_1_17)
  @pr_gate_lanes ~w(lint test verify_gates verify_docs)

  # (job_id, lane slug) for the eight lanes that compile examples/chimeway_demo_host
  # and therefore carry a per-lane demo-host mix cache (CI-05, D-11).
  @demo_host_cache_lanes [
    {"verify_example", "example"},
    {"verify_journeys", "journeys"},
    {"verify_mailglass", "mailglass"},
    {"verify_accrue", "accrue"},
    {"verify_inbox", "inbox"},
    {"verify_threadline", "threadline"},
    {"verify_sigra", "sigra"},
    {"verify_admin", "admin"}
  ]

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
          # CI-04 / D-09 / D-14: the Sigra proof runner was extracted to
          # scripts/ci/sigra-proof.sh. The proof commands and their env-var
          # contract now live in the script; the job block must call it. This
          # stays at least as strict as before — every load-bearing string is
          # re-asserted, either against the script (proof commands + proof env)
          # or against the job block (job-level env + db-prep step it kept).
          sigra_script = File.read!("scripts/ci/sigra-proof.sh")

          assert String.contains?(job_block, "scripts/ci/sigra-proof.sh"),
                 "verify_sigra job must call scripts/ci/sigra-proof.sh for the proof lanes"

          for marker <- [
                "test/support/sigra/ci_proof_runner.exs",
                "find _build/test/lib",
                "timeout 300s elixir $(",
                "test/demo_host_web/sigra_auth_proof_test.exs",
                "timeout 600s mix deps.compile",
                "timeout 300s mix compile",
                "timeout 300s mix test",
                "CHIMEWAY_SKIP_THREADLINE_DEP",
                "CHIMEWAY_SKIP_MAILGLASS_DEP",
                "CHIMEWAY_SKIP_ACCRUE_DEP",
                "CHIMEWAY_SKIP_SIGRA_TRANSITIVE_DEP",
                "CHIMEWAY_FORCE_SIGRA_TEST_REPO_SETUP",
                "CHIMEWAY_MANUAL_REPO_START",
                "CHIMEWAY_SKIP_OBAN"
              ] do
            assert String.contains?(sigra_script, marker),
                   "scripts/ci/sigra-proof.sh must carry load-bearing Sigra proof string #{marker}"
          end

          for marker <- [
                "PGUSER: postgres",
                "POSTGRES_USER: postgres",
                "Prepare root test database",
                "timeout 600s mix ecto.create"
              ] do
            assert String.contains?(job_block, marker),
                   "verify_sigra job block must keep #{marker}"
          end
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

  describe "pipeline tiering contract (TIER-01..04, Phase 90)" do
    setup do
      %{ci_yml: File.read!(@ci_yml)}
    end

    test "on: block declares the nightly schedule and run_nightly dispatch input", %{
      ci_yml: ci_yml
    } do
      assert String.contains?(ci_yml, ~S(cron: "0 7 * * *")),
             "ci.yml must declare the nightly schedule cron"

      dispatch_input = extract_ci_job_block(ci_yml, "run_nightly")

      assert String.contains?(dispatch_input, "type: boolean"),
             "run_nightly input must be type: boolean"

      assert String.contains?(dispatch_input, "default: false"),
             "run_nightly input must default to false"
    end

    test "concurrency group keys on event_name and only PRs cancel-in-progress", %{
      ci_yml: ci_yml
    } do
      group_line =
        ci_yml
        |> String.split("\n")
        |> Enum.find(&String.contains?(&1, "group:"))

      assert group_line && String.contains?(group_line, "github.event_name"),
             "concurrency group: must interpolate github.event_name"

      cancel_line =
        ci_yml
        |> String.split("\n")
        |> Enum.find(&String.contains?(&1, "cancel-in-progress:"))

      assert cancel_line &&
               String.contains?(cancel_line, "github.event_name == 'pull_request'"),
             "cancel-in-progress must be scoped to pull_request only"
    end

    test "resolve_tiers is a bare setup job emitting all three tier outputs", %{ci_yml: ci_yml} do
      job_block = extract_ci_job_block(ci_yml, "resolve_tiers")

      assert String.contains?(job_block, "outputs:")
      assert String.contains?(job_block, "run_nightly:")
      assert String.contains?(job_block, "otp_matrix:")

      assert String.contains?(job_block, "run_floor:"),
             "resolve_tiers must emit run_floor (QUAL-05/D-14) so test_floor_1_17 can run on push+nightly"

      refute String.contains?(job_block, "actions/checkout"),
             "resolve_tiers must stay a bare job with no checkout (Pitfall 3)"
    end

    test "run_floor is true iff the event is not a pull_request (QUAL-05/D-15 vacuous-pass guard)",
         %{ci_yml: ci_yml} do
      job_block = extract_ci_job_block(ci_yml, "resolve_tiers")

      assert String.contains?(
               job_block,
               ~S(if [ "${{ github.event_name }}" != "pull_request" ]; then)
             ) &&
               String.contains?(job_block, "run_floor=true") &&
               String.contains?(job_block, "run_floor=false"),
             "run_floor must be true iff event != pull_request — identical to ci-gate's run " <>
               "condition, so the floor is never `skipped` when ci-gate evaluates TEST_FLOOR_1_17 " <>
               "(structural PR-skip-as-pass, never a softened aggregate-gate.sh)"
    end

    test "test job's OTP matrix is driven by resolve_tiers via fromJSON", %{ci_yml: ci_yml} do
      job_block = extract_ci_job_block(ci_yml, "test")

      assert String.contains?(job_block, "needs: [resolve_tiers]")

      assert String.contains?(job_block, "fromJSON(needs.resolve_tiers.outputs.otp_matrix)"),
             "test's matrix.otp must consume resolve_tiers.outputs.otp_matrix via fromJSON"
    end

    test "nightly_cold_build is gated on the nightly tier and restores no cache (TIER-01)", %{
      ci_yml: ci_yml
    } do
      job_block = extract_ci_job_block(ci_yml, "nightly_cold_build")

      assert String.contains?(job_block, "needs: [resolve_tiers]"),
             "nightly_cold_build must depend on resolve_tiers"

      assert String.contains?(
               job_block,
               "if: needs.resolve_tiers.outputs.run_nightly == 'true'"
             ),
             "nightly_cold_build must be gated on the nightly-tier output"

      refute String.contains?(job_block, "actions/cache"),
             "nightly_cold_build must never restore a cache — it is the cold-build backstop (TIER-01)"
    end

    test "test_floor_1_17 pins the 1.17/OTP-27 floor with its own test-floor cache (TIER-01)", %{
      ci_yml: ci_yml
    } do
      job_block = extract_ci_job_block(ci_yml, "test_floor_1_17")

      assert String.contains?(
               job_block,
               "if: needs.resolve_tiers.outputs.run_floor == 'true'"
             ),
             "test_floor_1_17 must be gated on the run_floor output (QUAL-05/D-14: push+nightly, off for PRs)"

      assert String.contains?(job_block, ~S(elixir-version: "1.17")),
             "test_floor_1_17 must pin elixir-version 1.17 (mix.exs's ~> 1.17 floor)"

      assert String.contains?(job_block, ~S(otp-version: "27")),
             "test_floor_1_17 must pin otp-version 27 (matches release.yml/publish-hex.yml)"

      assert String.contains?(job_block, "test-floor-"),
             "test_floor_1_17 must use its own test-floor- cache-key namespace"
    end

    test "nightly-gate aggregates the four nightly lanes via aggregate-gate.sh (TIER-04)", %{
      ci_yml: ci_yml
    } do
      job_block = extract_ci_job_block(ci_yml, "nightly-gate")

      assert String.contains?(job_block, "scripts/ci/aggregate-gate.sh"),
             "nightly-gate must reuse scripts/ci/aggregate-gate.sh"

      assert String.contains?(
               job_block,
               "needs: [resolve_tiers, nightly_cold_build, test, test_floor_1_17, verify_admin]"
             ),
             "nightly-gate needs must be exactly [resolve_tiers, nightly_cold_build, test, test_floor_1_17, verify_admin]"

      for lane <- ~w(nightly_cold_build test test_floor_1_17 verify_admin) do
        assert String.contains?(job_block, lane),
               "nightly-gate must reference the #{lane} lane in its needs/env"
      end

      assert String.contains?(
               job_block,
               "aggregate-gate.sh NIGHTLY_COLD_BUILD TEST TEST_FLOOR_1_17 VERIFY_ADMIN"
             ),
             "nightly-gate must pass the four uppercase lane tokens to aggregate-gate.sh"
    end

    test "ci-gate needs stays 14 lanes and excludes the nightly-only jobs (T-90-03/QUAL-05)", %{
      ci_yml: ci_yml
    } do
      # Use the specialized ci-gate needs extractor, NOT the generic block
      # extractor — ci-gate is hyphenated, so the generic extractor would
      # over-capture past ci-gate into nightly-gate's own body.
      needs = extract_ci_gate_needs(ci_yml)

      assert length(needs) == 14,
             "ci-gate needs must remain exactly 14 lanes (verify_admin removed in 90-02; " <>
               "test_floor_1_17 added in 91-03 to close the CI<->release Elixir skew, D-15)"

      assert "test_floor_1_17" in needs,
             "ci-gate must need test_floor_1_17 so the 1.17 floor genuinely gates on push (D-15)"

      for excluded <- ~w(nightly-gate nightly_cold_build verify_admin) do
        refute excluded in needs,
               "ci-gate must not need the nightly-only job #{excluded}"
      end
    end
  end

  describe "CI cache coverage (CI-05)" do
    setup do
      %{ci_yml: File.read!(@ci_yml)}
    end

    test "verify_admin caches npm via setup-node built-in cache", %{ci_yml: ci_yml} do
      job_block = extract_ci_job_block(ci_yml, "verify_admin")

      assert String.contains?(job_block, "cache: 'npm'"),
             "verify_admin setup-node must enable cache: 'npm'"

      assert String.contains?(job_block, "cache-dependency-path: package-lock.json"),
             "verify_admin setup-node must key the npm cache on package-lock.json"
    end

    test "verify_admin caches Playwright browsers keyed on package-lock.json", %{ci_yml: ci_yml} do
      job_block = extract_ci_job_block(ci_yml, "verify_admin")

      assert String.contains?(job_block, "~/.cache/ms-playwright"),
             "verify_admin must cache the Playwright browser path ~/.cache/ms-playwright"

      assert String.contains?(
               job_block,
               "${{ runner.os }}-playwright-${{ hashFiles('package-lock.json') }}"
             ),
             "verify_admin Playwright cache must key on hashFiles('package-lock.json')"
    end

    test "nested admin/inbox mix caches key on their own lockfiles", %{ci_yml: ci_yml} do
      admin_block = extract_ci_job_block(ci_yml, "verify_admin")
      inbox_block = extract_ci_job_block(ci_yml, "verify_inbox")

      assert String.contains?(admin_block, "chimeway_admin/deps")
      assert String.contains?(admin_block, "chimeway_admin/_build")

      assert String.contains?(admin_block, "hashFiles('chimeway_admin/mix.lock')"),
             "verify_admin nested cache must key on chimeway_admin/mix.lock"

      assert String.contains?(inbox_block, "chimeway_inbox/deps")
      assert String.contains?(inbox_block, "chimeway_inbox/_build")

      assert String.contains?(inbox_block, "hashFiles('chimeway_inbox/mix.lock')"),
             "verify_inbox nested cache must key on chimeway_inbox/mix.lock"
    end

    for {job_id, slug} <- @demo_host_cache_lanes do
      test "#{job_id} caches demo host per-lane keyed on demo-host mix.lock", %{ci_yml: ci_yml} do
        job_block = extract_ci_job_block(ci_yml, unquote(job_id))

        assert String.contains?(job_block, "examples/chimeway_demo_host/deps"),
               "#{unquote(job_id)} must cache examples/chimeway_demo_host/deps"

        assert String.contains?(job_block, "examples/chimeway_demo_host/_build"),
               "#{unquote(job_id)} must cache examples/chimeway_demo_host/_build"

        assert String.contains?(
                 job_block,
                 "${{ runner.os }}-mix-demo-#{unquote(slug)}-${{ hashFiles('examples/chimeway_demo_host/mix.lock') }}"
               ),
               "#{unquote(job_id)} must use a per-lane demo-host key with slug #{unquote(slug)}"
      end
    end

    test "no shared/lane-agnostic demo-host cache key exists (D-11)", %{ci_yml: ci_yml} do
      slugs =
        ~r/runner\.os }}-mix-demo-([a-z]+)-/
        |> Regex.scan(ci_yml)
        |> Enum.map(fn [_, slug] -> slug end)

      known = for {_job_id, slug} <- @demo_host_cache_lanes, do: slug

      assert slugs != [], "expected demo-host cache keys to exist"

      for slug <- slugs do
        assert slug in known,
               "demo-host cache key slug #{slug} is not one of the known per-lane slugs (shared/lane-agnostic key?)"
      end
    end

    test "every cache hashFiles() references a lockfile only (D-12)", %{ci_yml: ci_yml} do
      args =
        ~r/hashFiles\('([^']+)'\)/
        |> Regex.scan(ci_yml)
        |> Enum.map(fn [_, arg] -> arg end)

      assert args != [], "expected cache steps to use hashFiles()"

      for arg <- args do
        assert String.ends_with?(arg, "mix.lock") or String.ends_with?(arg, "package-lock.json"),
               "cache hashFiles must reference a mix.lock or package-lock.json (source-keyed cache?), got: #{arg}"
      end
    end
  end

  describe "CI verification extraction (CI-04)" do
    @detect_script "scripts/ci/detect-installer-changes.sh"
    @aggregate_script "scripts/ci/aggregate-gate.sh"
    @sigra_script "scripts/ci/sigra-proof.sh"

    setup do
      %{ci_yml: File.read!(@ci_yml)}
    end

    test "all three extracted CI scripts exist" do
      for path <- [@detect_script, @aggregate_script, @sigra_script] do
        assert File.exists?(path), "expected extracted CI script #{path} to exist"
      end
    end

    test "ci.yml references each extracted script", %{ci_yml: ci_yml} do
      for path <- [@detect_script, @aggregate_script, @sigra_script] do
        assert String.contains?(ci_yml, path), "ci.yml must call #{path}"
      end
    end

    test "detect script carries the verbatim installer regex core" do
      detect = File.read!(@detect_script)

      # Representative verbatim triggers — paraphrasing the regex fails the gate.
      for marker <- [
            "priv/chimeway_migrations/",
            "installer_golden_prefixed",
            "installer_golden_public",
            "installer_fixture",
            "migration_contract_test"
          ] do
        assert String.contains?(detect, marker),
               "#{@detect_script} must carry installer regex trigger #{marker}"
      end
    end

    test "install_golden detect step calls the detect script", %{ci_yml: ci_yml} do
      job_block = extract_ci_job_block(ci_yml, "install_golden_contract")

      assert String.contains?(job_block, @detect_script),
             "install_golden_contract detect step must call #{@detect_script}"

      # The detect-step conditional pattern is preserved (pending-safety, D-07).
      assert String.contains?(job_block, "steps.detect.outputs.run == 'true'"),
             "install_golden_contract must keep its detect-step conditional"
    end

    test "aggregate script fails on non-success and both gates call it", %{ci_yml: ci_yml} do
      aggregate = File.read!(@aggregate_script)

      # Mirrors the required-lane loop: compares each lane against `success`.
      assert String.contains?(aggregate, "!= \"success\""),
             "#{@aggregate_script} must fail any lane whose result is not success"

      pr_gate = extract_ci_job_block(ci_yml, "pr-gate")
      ci_gate = extract_ci_job_block(ci_yml, "ci-gate")

      assert String.contains?(pr_gate, @aggregate_script),
             "pr-gate must call #{@aggregate_script}"

      assert String.contains?(ci_gate, @aggregate_script),
             "ci-gate must call #{@aggregate_script}"
    end

    test "verify_sigra job calls the extracted Sigra proof script", %{ci_yml: ci_yml} do
      job_block = extract_ci_job_block(ci_yml, "verify_sigra")

      assert String.contains?(job_block, @sigra_script),
             "verify_sigra must call #{@sigra_script} for its proof lanes"
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

      # CHANGELOG has a package release heading for the current version. Accept both
      # the bare `## 1.0.0` form (release-please's first release) and the linked
      # `## [1.1.0](compare-url)` form it uses for every subsequent release.
      assert Regex.match?(~r/^##\s+\[?#{Regex.escape(version)}\b/m, ctx.changelog),
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

      # Root install constraint is carried in the packaged README, aligned with the
      # packaged @version's MAJOR.MINOR (derive it — don't hardcode, or every release
      # bump breaks this gate).
      [_, pkg_version] = Regex.run(~r/@version "([^"]+)"/, mix_exs)
      [pkg_major, pkg_minor, _patch] = String.split(pkg_version, ".")
      expected_constraint = ~s({:chimeway, "~> #{pkg_major}.#{pkg_minor}"})

      assert String.contains?(readme, expected_constraint),
             "unpacked README.md must carry the root install constraint #{expected_constraint}"

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
    # Boundary char class includes 0-9 so digit-bearing job ids (e.g.
    # test_floor_1_17) are recognized as block boundaries and don't cause an
    # over-capture into the following job. Hyphenated gate jobs (ci-gate,
    # nightly-gate) are intentionally still not boundaries.
    case Regex.run(~r/#{job_id}:(.*?)(?:\n  [a-z0-9_]+:|\z)/s, yml) do
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

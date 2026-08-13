defmodule Chimeway.ReleaseGateContractTest do
  use ExUnit.Case, async: false

  alias Chimeway.Test.ArtifactConsumerFixture

  Code.require_file("priv/adoption_proof/artifact_archive.ex")

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
  @adoption_run_assertion "scripts/ci/assert-adoption-run.sh"
  @adoption_run_fixture "test/fixtures/ci/adoption_run_success.json"
  @sibling_packages ~w(chimeway_admin chimeway_inbox)
  @ci_gate_lanes ~w(lint test verify_gates verify_docs verify_example verify_runtime_prefix verify_journeys verify_mailglass verify_accrue verify_inbox verify_threadline verify_sigra install_golden_contract verify_adoption_paths test_floor_1_17)
  @pr_gate_lanes ~w(lint test verify_gates verify_docs verify_adoption_paths verify_inbox)

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

    test "ci.test skips partner repo setup owned by excluded verify lanes", %{mix_exs: mix_exs} do
      [_, ci_test] = Regex.run(~r/"ci\.test":\s*\[(.*?)\n\s*\],/s, mix_exs)

      assert ci_test =~ "CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1"
      assert mix_exs =~ "test_ignore_filters: [~r{^test/fixtures/}]"

      for excluded <- ~w(mailglass accrue threadline sigra) do
        assert ci_test =~ "--exclude #{excluded}"
      end
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

    test "verify_inbox is an unfiltered required PR lane", %{ci_yml: ci_yml} do
      needs = extract_pr_gate_needs(ci_yml)
      inbox_block = extract_ci_job_block(ci_yml, "verify_inbox")

      assert "verify_inbox" in needs

      refute String.contains?(inbox_block, "if: github.event_name != 'pull_request'"),
             "verify_inbox must run on pull requests so pr-gate never accepts a skipped Inbox lane"
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

    test "nightly-gate aggregates the five nightly lanes via aggregate-gate.sh (TIER-04/REL-03)",
         %{
           ci_yml: ci_yml
         } do
      job_block = extract_ci_job_block(ci_yml, "nightly-gate")

      assert String.contains?(job_block, "scripts/ci/aggregate-gate.sh"),
             "nightly-gate must reuse scripts/ci/aggregate-gate.sh"

      assert String.contains?(
               job_block,
               "needs: [resolve_tiers, nightly_cold_build, test, test_floor_1_17, verify_admin, test_seed_zero]"
             ),
             "nightly-gate needs must be exactly [resolve_tiers, nightly_cold_build, test, test_floor_1_17, verify_admin, test_seed_zero]"

      for lane <- ~w(nightly_cold_build test test_floor_1_17 verify_admin test_seed_zero) do
        assert String.contains?(job_block, lane),
               "nightly-gate must reference the #{lane} lane in its needs/env"
      end

      assert String.contains?(
               job_block,
               "aggregate-gate.sh NIGHTLY_COLD_BUILD TEST TEST_FLOOR_1_17 VERIFY_ADMIN TEST_SEED_ZERO"
             ),
             "nightly-gate must pass the five uppercase lane tokens to aggregate-gate.sh"
    end

    test "ci-gate needs stays 15 lanes and excludes the nightly-only jobs (T-90-03/QUAL-05)", %{
      ci_yml: ci_yml
    } do
      # Use the specialized ci-gate needs extractor, NOT the generic block
      # extractor — ci-gate is hyphenated, so the generic extractor would
      # over-capture past ci-gate into nightly-gate's own body.
      needs = extract_ci_gate_needs(ci_yml)

      assert length(needs) == 15,
             "ci-gate needs must remain exactly 15 lanes after the bounded adoption proof lane joins " <>
               "the non-PR release gate"

      assert "test_floor_1_17" in needs,
             "ci-gate must need test_floor_1_17 so the 1.17 floor genuinely gates on push (D-15)"

      for excluded <- ~w(nightly-gate nightly_cold_build verify_admin test_seed_zero) do
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

      # Mirrors files: ~w(lib priv guides scripts/prove-accrue-consumer.exs CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs) in mix.exs.
      # The package-owned Accrue proof runner lives under scripts/.
      whitelist =
        ~w(lib priv guides scripts CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs)

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

  describe "unpacked artifact Core adopter proof (PROOF-01/PROOF-02/PROOF-03/CORE-01)" do
    # Serialization is intentional: the artifact build and temporary PostgreSQL
    # lifecycle are expensive shared external resources. The fixture still gives
    # every invocation unique filesystem and database identities.
    setup do
      output = build_unpacked_package!()
      on_exit(fn -> File.rm_rf(output) end)
      %{root: unpacked_package_root!(output)}
    end

    @tag timeout: 120_000
    test "a clean consumer proves one public Core lifecycle from only the unpacked artifact", %{
      root: root
    } do
      proof = ArtifactConsumerFixture.prove_core!(root)

      assert proof.output =~ "CHIMEWAY_CORE_PROOF"
      assert proof.output =~ "artifact_consumer.core_trace"
      assert proof.output =~ "notification_version=1"
      assert proof.output =~ "status=succeeded"
      assert proof.output =~ "last_attempt_outcome=succeeded"

      assert Map.keys(proof.evidence) |> Enum.sort() ==
               [
                 :channel,
                 :delivery_id,
                 :last_attempt_number,
                 :last_attempt_outcome,
                 :notification_key,
                 :notification_version,
                 :outcome_classification,
                 :provider_handoff,
                 :render_key,
                 :render_version,
                 :status,
                 :timeline_events
               ]

      assert length(Regex.scan(~r/Chimeway\.Traces\.explain_delivery\(/, proof.proof_source)) == 1

      assert proof.proof_source =~
               "explain_delivery(delivery_id, tenant_id: \"artifact-proof-tenant\")"

      assert proof.proof_source =~ "Chimeway.Repo.get_dynamic_repo()"
      assert proof.proof_source =~ "Chimeway.Repo.put_dynamic_repo(ArtifactConsumer.Repo)"

      proof_source_without_dynamic_repo_handoff =
        proof.proof_source
        |> String.replace("Chimeway.Repo.get_dynamic_repo()", "")
        |> String.replace("Chimeway.Repo.put_dynamic_repo(ArtifactConsumer.Repo)", "")
        |> String.replace("Chimeway.Repo.put_dynamic_repo(previous_repo)", "")

      for forbidden <- [
            "Chimeway.Repo.",
            "Ecto.Query",
            "Repo.get",
            "Repo.one",
            "Ecto.Adapters.SQL",
            "payload",
            "recipient_identity",
            "email",
            "phone",
            "provider_response",
            "DATABASE_URL",
            "password",
            "secret"
          ] do
        refute proof_source_without_dynamic_repo_handoff =~ forbidden
        refute proof.output =~ forbidden
      end

      refute File.exists?(proof.identity.root)
      assert proof.cleanup == %{root_removed?: true, database_down?: true}

      assert :ok =
               Ecto.Adapters.Postgres.storage_up(
                 ArtifactConsumerFixture.database_config(proof.identity.database)
               )

      assert :ok =
               Ecto.Adapters.Postgres.storage_down(
                 ArtifactConsumerFixture.database_config(proof.identity.database)
               )
    end

    @tag timeout: 120_000
    test "a clean consumer proves one host-owned Mailglass transaction from only the unpacked artifact",
         %{
           root: root
         } do
      proof = ArtifactConsumerFixture.prove_mailglass!(root)

      assert proof.output =~ "CHIMEWAY_MAILGLASS_PROOF"
      assert proof.output =~ "provider_handoff=accepted"

      assert Map.keys(proof.evidence) |> Enum.sort() ==
               [
                 :channel,
                 :delivery_id,
                 :last_attempt_number,
                 :last_attempt_outcome,
                 :notification_key,
                 :notification_version,
                 :outcome_classification,
                 :provider_handoff,
                 :render_key,
                 :render_version,
                 :status,
                 :timeline_events
               ]

      assert proof.evidence.channel == "email"
      assert proof.evidence.notification_key == "artifact_consumer.mailglass_proof"
      assert proof.evidence.notification_version == "1"
      assert proof.evidence.render_key == "artifact_consumer.mailglass_proof.email"
      assert proof.evidence.render_version == "1"
      assert proof.evidence.status == "succeeded"
      assert proof.evidence.outcome_classification == "succeeded"
      assert proof.evidence.last_attempt_outcome == "succeeded"
      assert proof.evidence.provider_handoff == "accepted"
      assert proof.evidence.last_attempt_number == "1"

      assert length(Regex.scan(~r/Chimeway\.Traces\.explain_delivery\(/, proof.proof_source)) == 1

      assert proof.proof_source =~
               "explain_delivery(delivery_id, tenant_id: \"artifact-proof-tenant\")"

      assert proof.proof_source =~ "Mailglass.Adapters.Fake.checkout()"
      assert proof.proof_source =~ "Mailglass.Adapters.Fake.set_shared(self())"
      assert proof.proof_source =~ "length(Mailglass.Adapters.Fake.deliveries()) == 1"
      assert proof.migration_source =~ "Mailglass.Migration.up()"
      assert proof.migration_source =~ "Mailglass.Migration.down()"
      assert proof.mix_source =~ "{:mailglass, \"~> 1.3\"}"

      assert proof.topology == ArtifactConsumerFixture.mailglass_repo_topology()

      assert proof.config_source =~
               "config :artifact_consumer, ecto_repos: [ArtifactConsumer.Repo]"

      assert proof.config_source =~ "config :chimeway, repo: ArtifactConsumer.Repo"
      assert proof.config_source =~ "config :mailglass, repo: ArtifactConsumer.Repo"
      refute proof.config_source =~ "config :chimeway, Chimeway.Repo"
      assert proof.mix_source =~ "included_applications: [:chimeway]"
      assert proof.application_source =~ "Supervisor.start_link([ArtifactConsumer.Repo]"
      refute proof.application_source =~ "Chimeway.Repo"
      assert proof.proof_source =~ "Chimeway.Repo.put_dynamic_repo(ArtifactConsumer.Repo)"
      assert proof.proof_source =~ "Process.whereis(ArtifactConsumer.Repo)"
      assert proof.proof_source =~ "Process.whereis(Chimeway.Repo) == nil"

      for forbidden <- [
            "ArtifactConsumer.Repo",
            "Chimeway.Repo",
            "Ecto.Query",
            "Repo.get",
            "Repo.one",
            "Ecto.Adapters.SQL",
            "recipient",
            "subject",
            "html_body",
            "text_body",
            "assigns",
            "password",
            "secret",
            "provider_response",
            "metadata"
          ] do
        refute proof.output =~ forbidden
      end

      refute File.exists?(proof.identity.root)
      assert proof.cleanup == %{root_removed?: true, database_down?: true}
    end

    test "provenance validation accepts only one unpacked artifact dependency" do
      unpacked_root = Path.join(System.tmp_dir!(), "artifact-unpacked")
      source = "defp deps, do: [{:chimeway, path: #{inspect(unpacked_root)}}]"

      assert :ok =
               ArtifactConsumerFixture.validate_artifact_dependency!(
                 source,
                 unpacked_root,
                 "/repo/root"
               )

      assert_raise RuntimeError, ~r/repository source root/, fn ->
        ArtifactConsumerFixture.validate_artifact_dependency!(
          source,
          unpacked_root,
          unpacked_root
        )
      end

      assert_raise RuntimeError, ~r/exactly one :chimeway dependency/, fn ->
        ArtifactConsumerFixture.validate_artifact_dependency!(
          source <> ", {:chimeway, path: \"/other\"}",
          unpacked_root,
          "/repo/root"
        )
      end

      assert_raise RuntimeError, ~r/unpacked artifact root/, fn ->
        ArtifactConsumerFixture.validate_artifact_dependency!(
          "defp deps, do: [{:chimeway, path: \"/other\"}]",
          unpacked_root,
          "/repo/root"
        )
      end
    end

    test "public evidence rejects empty or incomplete trace data" do
      complete = %Chimeway.Traces.Explanation{
        delivery_id: "delivery-id",
        status: :succeeded,
        last_attempt: %{outcome: :succeeded, attempt_number: 1},
        timeline:
          Enum.map(
            [:event_created, :notification_created, :delivery_planned, :attempt_recorded],
            &%{event: &1}
          )
      }

      assert %{notification_key: "artifact_consumer.core_trace"} =
               ArtifactConsumerFixture.build_safe_evidence!(
                 Chimeway.ReleaseGateContractTest.CoreProofNotifier,
                 complete
               )

      assert_raise RuntimeError, ~r/delivery ID/, fn ->
        ArtifactConsumerFixture.build_safe_evidence!(
          Chimeway.ReleaseGateContractTest.CoreProofNotifier,
          %{complete | delivery_id: ""}
        )
      end

      assert_raise RuntimeError, ~r/non-empty explanation timeline/, fn ->
        ArtifactConsumerFixture.build_safe_evidence!(
          Chimeway.ReleaseGateContractTest.CoreProofNotifier,
          %{complete | timeline: []}
        )
      end

      assert_raise RuntimeError, ~r/last attempt outcome/, fn ->
        ArtifactConsumerFixture.build_safe_evidence!(
          Chimeway.ReleaseGateContractTest.CoreProofNotifier,
          %{complete | last_attempt: nil}
        )
      end
    end

    test "subprocess evidence rejects unknown and duplicate string keys without atomizing them" do
      unknown_key = "untrusted_key_#{System.unique_integer([:positive])}"
      atom_count = :erlang.system_info(:atom_count)

      assert_raise RuntimeError, ~r/unknown evidence key/, fn ->
        ArtifactConsumerFixture.parse_evidence!("CHIMEWAY_CORE_PROOF #{unknown_key}=value")
      end

      assert_raise ArgumentError, fn -> String.to_existing_atom(unknown_key) end
      assert :erlang.system_info(:atom_count) == atom_count

      duplicate =
        "CHIMEWAY_CORE_PROOF notification_key=one notification_key=two " <>
          "notification_version=1 delivery_id=id status=succeeded " <>
          "last_attempt_outcome=succeeded timeline_events=attempt_recorded"

      assert_raise RuntimeError, ~r/duplicate evidence key/, fn ->
        ArtifactConsumerFixture.parse_evidence!(duplicate)
      end
    end

    test "core proof accepts only validated safe lifecycle and handoff facts" do
      complete =
        "CHIMEWAY_CORE_PROOF notification_key=artifact_consumer.core_trace " <>
          "notification_version=1 delivery_id=2f1c8b94-3a5e-4d70-8c16-2e3a4b5c6d7e " <>
          "channel=in_app render_key=artifact_consumer.core_trace.in_app render_version=1 " <>
          "status=succeeded outcome_classification=succeeded last_attempt_outcome=succeeded " <>
          "last_attempt_number=1 provider_handoff=not_applicable " <>
          "timeline_events=event_created,notification_created,delivery_planned,attempt_recorded"

      assert %{provider_handoff: "not_applicable", outcome_classification: "succeeded"} =
               ArtifactConsumerFixture.parse_evidence!(complete)

      for {key, value} <- [
            {"notification_key", "recipient@example.test"},
            {"delivery_id", "raw-device-token-sentinel"},
            {"render_key", "https://private.example.test/open"},
            {"outcome_classification", "opened"},
            {"provider_handoff", "raw-provider-body-sentinel"}
          ] do
        assert_raise RuntimeError, ~r/invalid #{key}/, fn ->
          ArtifactConsumerFixture.parse_evidence!(
            Regex.replace(~r/(^|\s)#{Regex.escape(key)}=[^\s]*/, complete, "\\1#{key}=#{value}")
          )
        end
      end
    end

    test "proof source projects safe facts and limits provider acceptance to handoff" do
      source = File.read!("priv/adoption_proof/artifact_consumer_fixture.ex")

      assert source =~ "Chimeway.SafeEvidence.proof"
      assert source =~ "provider_handoff"
      refute source =~ "adapter_module: explanation.last_attempt.adapter_module"
      refute source =~ "transport: \"fake\""

      for forbidden <- ["display", "opened", "seen", "read", "engagement"] do
        refute source =~ "provider_handoff=#{forbidden}"
      end
    end

    test "Mailglass proof evidence accepts only one complete safe allowlist without atomizing keys" do
      complete = mailglass_evidence_line()

      assert Map.keys(ArtifactConsumerFixture.parse_mailglass_evidence!(complete)) |> Enum.sort() ==
               [
                 :channel,
                 :delivery_id,
                 :last_attempt_number,
                 :last_attempt_outcome,
                 :notification_key,
                 :notification_version,
                 :outcome_classification,
                 :provider_handoff,
                 :render_key,
                 :render_version,
                 :status,
                 :timeline_events
               ]

      unknown_key = "untrusted_mailglass_key_#{System.unique_integer([:positive])}"

      assert_raise RuntimeError, ~r/unknown evidence key/, fn ->
        ArtifactConsumerFixture.parse_mailglass_evidence!(complete <> " #{unknown_key}=value")
      end

      assert_raise ArgumentError, fn -> String.to_existing_atom(unknown_key) end

      assert_raise RuntimeError, ~r/duplicate evidence key/, fn ->
        ArtifactConsumerFixture.parse_mailglass_evidence!(complete <> " status=succeeded")
      end

      assert_raise RuntimeError, ~r/exactly the safe evidence allowlist/, fn ->
        ArtifactConsumerFixture.parse_mailglass_evidence!(
          String.replace(complete, " provider_handoff=accepted", "")
        )
      end

      assert_raise RuntimeError, ~r/malformed evidence/, fn ->
        ArtifactConsumerFixture.parse_mailglass_evidence!(complete <> " malformed")
      end

      assert_raise RuntimeError, ~r/multiple CHIMEWAY_MAILGLASS_PROOF lines/, fn ->
        ArtifactConsumerFixture.parse_mailglass_evidence!(complete <> "\n" <> complete)
      end

      assert_raise RuntimeError, ~r/unknown evidence key/, fn ->
        ArtifactConsumerFixture.parse_mailglass_evidence!(complete <> " transport=live")
      end
    end

    test "Mailglass proof evidence accepts the canonical schema but rejects recipient-shaped delivery IDs" do
      complete = mailglass_evidence_line()

      assert %{delivery_id: "2f1c8b94-3a5e-4d70-8c16-2e3a4b5c6d7e"} =
               ArtifactConsumerFixture.parse_mailglass_evidence!(complete)

      assert_raise RuntimeError, ~r/delivery_id/, fn ->
        ArtifactConsumerFixture.parse_mailglass_evidence!(
          replace_mailglass_evidence_value(complete, "delivery_id", "recipient@example.test")
        )
      end
    end

    test "Mailglass proof evidence rejects every sensitive output category" do
      for unsafe_key <- [
            "recipient",
            "to",
            "subject",
            "body",
            "html_body",
            "text_body",
            "assigns",
            "password",
            "secret",
            "credential",
            "api_key",
            "token",
            "endpoint",
            "trusted_link",
            "raw_mailglass",
            "provider_id",
            "provider_body",
            "provider_response",
            "metadata"
          ] do
        assert_raise RuntimeError, ~r/unknown evidence key/, fn ->
          ArtifactConsumerFixture.parse_mailglass_evidence!(
            mailglass_evidence_line() <> " #{unsafe_key}=private"
          )
        end
      end
    end

    test "Mailglass proof evidence rejects forged values beneath every allowlisted key" do
      complete = mailglass_evidence_line()

      mutations = [
        {"notification_key", "recipient@example.test"},
        {"notification_version", "2"},
        {"delivery_id", "provider-message-123"},
        {"channel", "sms"},
        {"render_key", "recipient@example.test"},
        {"render_version", "2"},
        {"status", "failed"},
        {"last_attempt_outcome", "failed"},
        {"last_attempt_number", "2"},
        {"outcome_classification", "opened"}
      ]

      for {key, value} <- mutations do
        assert_raise RuntimeError, ~r/invalid #{key}/, fn ->
          ArtifactConsumerFixture.parse_mailglass_evidence!(
            replace_mailglass_evidence_value(complete, key, value)
          )
        end
      end

      for forged_handoff <- ["device_displayed", "opened", "seen", "read", "engagement"] do
        assert_raise RuntimeError, ~r/invalid provider_handoff/, fn ->
          ArtifactConsumerFixture.parse_mailglass_evidence!(
            replace_mailglass_evidence_value(complete, "provider_handoff", forged_handoff)
          )
        end
      end
    end

    test "Mailglass proof evidence requires canonical numeric values and a UUID-shaped delivery ID" do
      complete = mailglass_evidence_line()

      for key <- ["notification_version", "render_version", "last_attempt_number"],
          value <- ["0", "-1", "+1", "01", "1.0", "one", "2"] do
        assert_raise RuntimeError, ~r/invalid #{key}/, fn ->
          ArtifactConsumerFixture.parse_mailglass_evidence!(
            replace_mailglass_evidence_value(complete, key, value)
          )
        end
      end

      for malformed_id <- [
            "recipient@example.test",
            "provider-message-123",
            "2f1c8b94-3a5e-4d70-8c16-2e3a4b5c6d7",
            "2f1c8b94-3a5e-4d70-8c16-2e3a4b5c6d7e0",
            "2f1c8b943a5e4d708c162e3a4b5c6d7e"
          ] do
        assert_raise RuntimeError, ~r/invalid delivery_id/, fn ->
          ArtifactConsumerFixture.parse_mailglass_evidence!(
            replace_mailglass_evidence_value(complete, "delivery_id", malformed_id)
          )
        end
      end
    end

    test "Mailglass proof evidence accepts only the canonical ordered binary timeline without atomizing it" do
      complete = mailglass_evidence_line()
      unknown_token = "untrusted_timeline_#{System.unique_integer([:positive])}"

      for timeline <- [
            "event_created,notification_created,delivery_planned,recipient@example.test",
            "event_created,notification_created,delivery_planned,provider-secret",
            "event_created,notification_created,delivery_planned,#{unknown_token}",
            "event_created,,delivery_planned,attempt_recorded",
            "event_created,notification_created,attempt_recorded",
            "event_created,notification_created,delivery_planned,delivery_planned,attempt_recorded",
            "notification_created,event_created,delivery_planned,attempt_recorded"
          ] do
        assert_raise RuntimeError, ~r/invalid timeline_events/, fn ->
          ArtifactConsumerFixture.parse_mailglass_evidence!(
            replace_mailglass_evidence_value(complete, "timeline_events", timeline)
          )
        end
      end

      assert_raise ArgumentError, fn -> String.to_existing_atom(unknown_token) end
    end

    test "timeline evidence allows interposed public events but enforces required order" do
      required = [:event_created, :notification_created, :delivery_planned, :attempt_recorded]

      assert ArtifactConsumerFixture.ordered_subsequence?(required, [
               :event_created,
               :notification_created,
               :deferred,
               :delivery_planned,
               :webhook_received,
               :attempt_recorded
             ])

      refute ArtifactConsumerFixture.ordered_subsequence?(required, [
               :event_created,
               :delivery_planned,
               :notification_created,
               :attempt_recorded
             ])

      refute ArtifactConsumerFixture.ordered_subsequence?(required, [
               :event_created,
               :notification_created,
               :delivery_planned
             ])
    end

    test "fixture resources have VM-safe namespaces and cleanup accepts only fixture-owned identities" do
      first = ArtifactConsumerFixture.resource_identity("vm_one")
      second = ArtifactConsumerFixture.resource_identity("vm_two")
      refute first.root == second.root
      refute first.database == second.database
      assert first.root =~ "chimeway_artifact_consumer_vm_one_"
      assert second.root =~ "chimeway_artifact_consumer_vm_two_"

      forged = %{first | root: Path.join(System.tmp_dir!(), "not_fixture_owned")}

      assert_raise ArgumentError, ~r/fixture-owned resource identity/, fn ->
        ArtifactConsumerFixture.prove_core!(System.tmp_dir!(),
          identity: forged,
          fail_before_commands: true
        )
      end

      assert_raise RuntimeError, ~r/pre-command validation failure/, fn ->
        ArtifactConsumerFixture.prove_core!(System.tmp_dir!(),
          identity: first,
          fail_before_commands: true
        )
      end

      refute File.exists?(first.root)

      assert :ok =
               Ecto.Adapters.Postgres.storage_up(
                 ArtifactConsumerFixture.database_config(first.database)
               )

      assert :ok =
               Ecto.Adapters.Postgres.storage_down(
                 ArtifactConsumerFixture.database_config(first.database)
               )
    end

    test "fixture database identities retain entropy within PostgreSQL's 63-byte identifier limit" do
      identity = ArtifactConsumerFixture.resource_identity(String.duplicate("vm_boundary_", 12))

      assert byte_size(identity.database) <= 63
      assert identity.database =~ ~r/^chimeway_artifact_consumer_[a-z2-7]+$/
      assert identity.root =~ "chimeway_artifact_consumer_vm_boundary_"
    end

    test "a database teardown failure fails closed and still removes the fixture tree" do
      identity = ArtifactConsumerFixture.resource_identity("cleanup_failure")

      assert_raise RuntimeError, ~r/database cleanup failed/, fn ->
        ArtifactConsumerFixture.prove_core!(System.tmp_dir!(),
          identity: identity,
          fail_before_commands: true,
          storage_down: fn _config -> {:error, :controlled_failure} end
        )
      end

      refute File.exists?(identity.root)
    end

    test "Mailglass proof failure cleans its temporary filesystem and database resources" do
      identity = ArtifactConsumerFixture.resource_identity("mailglass_cleanup_failure")

      assert_raise RuntimeError, ~r/pre-command validation failure/, fn ->
        ArtifactConsumerFixture.prove_mailglass!(System.tmp_dir!(),
          identity: identity,
          fail_before_commands: true
        )
      end

      refute File.exists?(identity.root)

      assert :ok =
               Ecto.Adapters.Postgres.storage_up(
                 ArtifactConsumerFixture.database_config(identity.database)
               )

      assert :ok =
               Ecto.Adapters.Postgres.storage_down(
                 ArtifactConsumerFixture.database_config(identity.database)
               )
    end

    @tag :accrue_artifact_proof
    @tag timeout: 600_000
    test "a clean consumer proves the Accrue payment failure to payment success lifecycle", %{
      root: root
    } do
      proof = ArtifactConsumerFixture.prove_accrue!(root)

      assert proof.output =~ "CHIMEWAY_ACCRUE_PROOF"

      assert %{
               provenance: "released_package",
               accrue_version: "1.3.0",
               workflow_key: "accrue.dunning",
               waiting_state: "waiting",
               waiting_reason: "waiting_for_step_progression",
               outcome_event: "invoice.paid",
               outcome_state: "active",
               outcome_reason: "signal_received",
               timeline_reasons: "waiting_for_step_progression,signal_received"
             } = proof.evidence

      assert proof.cleanup == %{root_removed?: true, database_down?: true}
      refute File.exists?(proof.identity.root)
    end

    @tag :accrue_artifact_proof
    @tag timeout: 600_000
    test "a clean consumer classifies only the exact immutable Accrue checkout as compatibility",
         %{
           root: root
         } do
      proof = ArtifactConsumerFixture.prove_accrue!(root, accrue_source: :compatibility)

      assert %{
               provenance: "compatibility",
               accrue_ref: "236fa2f1649e771f3b515603495436badeed3c7b",
               workflow_key: "accrue.dunning",
               waiting_state: "waiting",
               outcome_state: "active"
             } = proof.evidence

      refute Map.has_key?(proof.evidence, :accrue_version)
      refute Map.has_key?(proof.evidence, :chimeway_version)
      assert proof.provenance_source == :compatibility
      assert proof.cleanup == %{root_removed?: true, database_down?: true}
      refute File.exists?(proof.identity.root)
    end

    @tag :accrue_artifact_proof
    test "Accrue provenance rejects an unselected source before it can emit a proof" do
      identity = ArtifactConsumerFixture.resource_identity("accrue_invalid_provenance")

      assert_raise RuntimeError, ~r/provenance source/, fn ->
        ArtifactConsumerFixture.prove_accrue!(System.tmp_dir!(),
          identity: identity,
          accrue_source: :source_checkout
        )
      end

      refute File.exists?(identity.root)
    end

    @tag :accrue_artifact_proof
    test "Accrue evidence accepts only fixed lifecycle and released-package provenance" do
      line = accrue_evidence_line()

      assert %{
               provenance: "released_package",
               accrue_version: "1.3.0",
               workflow_key: "accrue.dunning"
             } =
               ArtifactConsumerFixture.parse_accrue_evidence!(line)

      for {key, value} <- [
            {"waiting_state", "active"},
            {"waiting_reason", "completed"},
            {"outcome_event", "invoice.failed"},
            {"outcome_state", "terminal"},
            {"outcome_reason", "completed"},
            {"timeline_reasons", "signal_received,waiting_for_step_progression"},
            {"accrue_version", "1.3.1"}
          ] do
        assert_raise RuntimeError, fn ->
          ArtifactConsumerFixture.parse_accrue_evidence!(
            replace_accrue_evidence_value(line, key, value)
          )
        end
      end
    end

    @tag :accrue_artifact_proof
    test "Accrue evidence rejects unknown, duplicate, mixed, and atomizing records" do
      line = accrue_evidence_line()
      unknown = "untrusted_accrue_key_#{System.unique_integer([:positive])}"

      for forged <- [
            line <> " #{unknown}=value",
            line <> " outcome_state=active",
            line <> " accrue_ref=236fa2f1649e771f3b515603495436badeed3c7b",
            String.replace(line, " chimeway_version=1.0.0", ""),
            line <> "\n" <> line,
            line <> " customer_id=private",
            line <> " payload=private",
            line <> " credential=private"
          ] do
        assert_raise RuntimeError, fn ->
          ArtifactConsumerFixture.parse_accrue_evidence!(forged)
        end
      end

      assert_raise ArgumentError, fn -> String.to_existing_atom(unknown) end
    end

    @tag :accrue_artifact_proof
    test "Accrue compatibility is SHA-only and proof source is event-to-signal shaped" do
      compatibility =
        "CHIMEWAY_ACCRUE_PROOF provenance=compatibility accrue_ref=236fa2f1649e771f3b515603495436badeed3c7b " <>
          "workflow_key=accrue.dunning workflow_version=1 waiting_state=waiting " <>
          "waiting_reason=waiting_for_step_progression outcome_event=invoice.paid " <>
          "outcome_state=active outcome_reason=signal_received " <>
          "timeline_reasons=waiting_for_step_progression,signal_received"

      assert %{provenance: "compatibility"} =
               ArtifactConsumerFixture.parse_accrue_evidence!(compatibility)

      assert_raise RuntimeError, fn ->
        ArtifactConsumerFixture.parse_accrue_evidence!(compatibility <> " accrue_version=1.3.0")
      end

      runner = File.read!("scripts/prove-accrue-consumer.exs")

      assert runner =~ "--artifact-archive"
      assert runner =~ "--sha256"
      refute runner =~ "--artifact-root"

      assert File.read!("priv/adoption_proof/artifact_consumer_fixture.ex") =~
               "Accrue.Test.trigger_event(:invoice_payment_failed"

      assert File.read!("priv/adoption_proof/artifact_consumer_fixture.ex") =~
               "Accrue.Test.trigger_event(:invoice_paid"

      refute direct_accrue_proof_record_write?(runner)

      assert direct_accrue_proof_record_write?(
               String.replace(
                 runner,
                 "IO.puts(proof.output)",
                 "IO.puts(\"CHIMEWAY_ACCRUE_PROOF forged=true\")",
                 global: false
               )
             )

      proof_source = File.read!("priv/adoption_proof/artifact_consumer_fixture.ex")

      for marker <- [
            "\"scm\" => accrue_dep.scm",
            "\"lock\" => lock",
            "\"application_version\" => to_string(Application.spec(:accrue, :vsn))",
            "descriptor[\"scm\"] == Hex.SCM",
            "descriptor[\"scm\"] == Mix.SCM.Git",
            "descriptor[\"metadata\"][<<\"version\">>] == <<\"1.3.0\">>",
            "module_source == integration_source"
          ] do
        assert proof_source =~ marker,
               "generated consumer provenance descriptor must validate #{marker}"
      end
    end

    @tag :accrue_artifact_proof
    test "Accrue parser rejects every sensitive boundary key and malformed lifecycle pair" do
      line = accrue_evidence_line()

      for unsafe_key <- ~w[
            workflow_id delivery_id signal_id tenant_id customer_id subscription_id invoice_id
            recipient email amount currency payload context metadata secret token credential
            raw_struct inspect sql ecto_result database_result
          ] do
        assert_raise RuntimeError, ~r/unknown evidence key/, fn ->
          ArtifactConsumerFixture.parse_accrue_evidence!(line <> " #{unsafe_key}=private")
        end
      end

      for malformed <- [
            "CHIMEWAY_ACCRUE_PROOF",
            "CHIMEWAY_ACCRUE_PROOF malformed",
            String.replace(line, "provenance=released_package", "provenance=unknown"),
            String.replace(
              line,
              "timeline_reasons=waiting_for_step_progression,signal_received",
              "timeline_reasons=waiting_for_step_progression,signal_received,signal_received"
            ),
            String.replace(
              line,
              "workflow_key=accrue.dunning",
              "workflow_key=accrue.dunning.completed"
            )
          ] do
        assert_raise RuntimeError, fn ->
          ArtifactConsumerFixture.parse_accrue_evidence!(malformed)
        end
      end
    end
  end

  describe "packaged Accrue archive proof CLI (ACCR-01/ACCR-02)" do
    @tag :accrue_packaged_cli
    @tag timeout: 600_000
    test "runs only from a verified archive with package-owned proof support" do
      archive = build_package_archive!()
      on_exit(fn -> File.rm_rf(Path.dirname(archive)) end)
      digest = sha256!(archive)
      unpacked = build_unpacked_package!()
      on_exit(fn -> File.rm_rf(unpacked) end)
      root = unpacked_package_root!(unpacked)
      metadata = File.read!(Path.join(root, "hex_metadata.config"))

      assert metadata =~ "scripts/prove-accrue-consumer.exs"
      assert metadata =~ "priv/adoption_proof/artifact_consumer_fixture.ex"
      refute metadata =~ "test/"

      {deps_output, deps_status} =
        System.cmd("mix", ["deps.get"],
          cd: root,
          stderr_to_stdout: true,
          env: [{"MIX_ENV", "prod"}]
        )

      assert deps_status == 0, deps_output

      {output, status} = packaged_accrue_cli(root, archive, digest)
      assert status == 0, output

      lines = Regex.scan(~r/^CHIMEWAY_ACCRUE_PROOF .+$/m, output) |> List.flatten()
      assert [line] = lines

      assert %{provenance: "released_package"} =
               ArtifactConsumerFixture.parse_accrue_evidence!(line)

      refute output =~ "test/support"
      refute File.read!(Path.join(root, "scripts/prove-accrue-consumer.exs")) =~ "../test/support"
    end

    @tag :accrue_packaged_cli
    @tag timeout: 600_000
    test "rejects malformed archive provenance without a proof line" do
      archive = build_package_archive!()
      on_exit(fn -> File.rm_rf(Path.dirname(archive)) end)

      altered = Path.join(Path.dirname(archive), "altered.tar")
      File.cp!(archive, altered)
      File.write!(altered, "tampered", [:append])

      for argv <- [
            [],
            ["--artifact-archive", ".", "--sha256", String.duplicate("a", 64)],
            ["--artifact-archive", File.cwd!(), "--sha256", String.duplicate("a", 64)],
            {"relative.tar", String.duplicate("a", 64)},
            {archive, String.duplicate("0", 64)},
            {archive, "ABC"},
            {altered, sha256!(altered)}
          ] do
        argv =
          case argv do
            {path, digest} -> ["--artifact-archive", path, "--sha256", digest]
            arguments -> arguments
          end

        {output, status} = invalid_packaged_accrue_cli(argv)
        assert status != 0
        refute output =~ "CHIMEWAY_ACCRUE_PROOF"
        refute output =~ File.cwd!()
        refute output =~ "password"
      end
    end

    @tag :accrue_packaged_cli
    test "redacts every archive validator failure to one fixed provenance diagnostic" do
      archive = build_package_archive!()
      malformed = Path.join(Path.dirname(archive), "malformed.tar")
      File.write!(malformed, "not a Hex package archive")
      on_exit(fn -> File.rm_rf(Path.dirname(archive)) end)

      for {path, digest} <- [
            {archive, String.duplicate("0", 64)},
            {malformed, sha256!(malformed)}
          ] do
        {output, status} =
          invalid_packaged_accrue_cli(["--artifact-archive", path, "--sha256", digest])

        assert status == 65
        assert output == "Accrue package proof: archive validation failed\n"
        assert output |> String.split("\n", trim: true) |> length() == 1
        refute output =~ "WithClauseError"
        refute output =~ "stacktrace"
        refute output =~ path
        refute output =~ digest
        refute Regex.match?(~r/^CHIMEWAY_ACCRUE_PROOF /m, output)
      end
    end
  end

  test "test-support fixture compilation tracks its package-owned source" do
    support_source = File.read!("test/support/artifact_consumer_fixture.ex")

    assert support_source =~ "@external_resource"
    assert support_source =~ "priv/adoption_proof/artifact_consumer_fixture.ex"
  end

  describe "adoption paths tracer (GATE-01/D-05..D-08)" do
    @tag :adoption_paths_tracer
    test "ships a strict Core adoption command and shared archive seam" do
      task = "lib/mix/tasks/verify.adoption_paths.ex"
      runner = "scripts/prove-adoption-paths.exs"
      archive = "priv/adoption_proof/artifact_archive.ex"

      assert File.regular?(task)
      assert File.regular?(runner)
      assert File.regular?(archive)
      assert File.read!("mix.exs") =~ "scripts/prove-adoption-paths.exs"
      assert File.read!(task) =~ "OptionParser.parse"
      assert File.read!(task) =~ "AdoptionProofRunner"
    end

    @tag :adoption_paths_tracer
    test "rejects invalid adoption selectors before any proof record is emitted" do
      for argv <- [
            ["--only", "unknown"],
            ["--only", "core", "--only", "core"],
            ["--only"],
            ["core"],
            ["--unexpected", "core"]
          ] do
        {output, status} =
          System.cmd("mix", ["verify.adoption_paths" | argv], stderr_to_stdout: true)

        assert status != 0
        refute output =~ "CHIMEWAY_"
      end
    end
  end

  describe "adoption archive security (CR-01/T-96-11..T-96-14)" do
    @unsupported_tar_types [?1, ?2, ?3, ?4, ?6, ?7, ?g, ?x, ?L, ?K, ?S]

    @tag :adoption_archive_security
    test "rejects a valid-digest symbolic-link directory before it can escape scratch" do
      outside = temporary_path!("outside-created.txt")
      File.write!(outside, "unchanged")
      on_exit(fn -> File.rm_rf(Path.dirname(outside)) end)

      archive =
        malicious_package_archive!([
          {"escape", ?2, "../outside-created.txt", <<>>},
          {"escape/payload.txt", ?0, "", "owned"}
        ])

      on_exit(fn -> File.rm_rf(Path.dirname(archive)) end)

      assert {:error, _} =
               Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
                 archive,
                 sha256!(archive),
                 fn _root -> send(self(), :callback_invoked) end
               )

      refute_received :callback_invoked
      assert File.read!(outside) == "unchanged"
    end

    @tag :adoption_archive_security
    test "rejects a required-file symbolic link before validation can read or load its target" do
      outside = temporary_path!("outside-marker.ex")
      marker = temporary_path!("outside-marker.txt")
      File.write!(outside, "File.write!(#{inspect(marker)}, \"loaded\")")
      on_exit(fn -> File.rm_rf(Path.dirname(outside)) end)

      archive =
        malicious_package_archive!([
          {"mix.exs", ?2, outside, <<>>},
          {"priv/adoption_proof/artifact_consumer_fixture.ex", ?0, "", "# fixture"}
        ])

      on_exit(fn -> File.rm_rf(Path.dirname(archive)) end)

      assert {:error, _} =
               Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
                 archive,
                 sha256!(archive),
                 fn _root -> send(self(), :callback_invoked) end
               )

      refute_received :callback_invoked
      refute File.exists?(marker)
    end

    @tag :adoption_archive_security
    test "materializes a regular production-shaped archive and invokes its callback once" do
      archive =
        malicious_package_archive!([
          {"mix.exs", ?0, "", "@version \"0.0.1\"\n"},
          {"scripts/prove-accrue-consumer.exs", ?0, "", "# runner\n"},
          {"priv/adoption_proof/artifact_consumer_fixture.ex", ?0, "", "# fixture\n"}
        ])

      on_exit(fn -> File.rm_rf(Path.dirname(archive)) end)

      assert {:ok, :validated} =
               Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
                 archive,
                 sha256!(archive),
                 fn root ->
                   send(self(), :callback_invoked)
                   assert File.regular?(Path.join(root, "mix.exs"))
                   :validated
                 end
               )

      assert_received :callback_invoked
      refute_received :callback_invoked
    end

    @tag :adoption_archive_security
    test "rejects correctly digested hostile metadata without interning atoms or invoking its callback" do
      warm_archive = malicious_package_archive!(valid_proof_entries())
      on_exit(fn -> File.rm_rf(Path.dirname(warm_archive)) end)

      assert {:ok, :warmed} =
               Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
                 warm_archive,
                 sha256!(warm_archive),
                 fn _root -> :warmed end
               )

      tokens = hostile_atom_tokens(300)

      metadata =
        default_metadata() <>
          ~s({<<"hostile">>, [#{Enum.join(tokens, ", ")}]} .\n)

      archive =
        valid_proof_entries()
        |> malicious_package_archive!(metadata)

      on_exit(fn -> File.rm_rf(Path.dirname(archive)) end)

      before_count = :erlang.system_info(:atom_count)

      assert {:error, _} =
               Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
                 archive,
                 sha256!(archive),
                 fn _root -> send(self(), :hostile_callback_invoked) end
               )

      assert :erlang.system_info(:atom_count) == before_count
      refute_received :hostile_callback_invoked

      for token <- Enum.take_every(tokens, 50) do
        assert_raise ArgumentError, fn -> String.to_existing_atom(token) end
      end
    end

    @tag :adoption_archive_security
    test "accepts bounded canonical unknown metadata values while retaining only proof fields" do
      metadata =
        default_metadata() <>
          ~s({<<"links">>, [{<<"GitHub">>, <<"https://github.com/szTheory/chimeway">>}]} .\n) <>
          ~s({<<"retired">>, false}.\n) <>
          ~s({<<"labels">>, [<<"atom_looking_value">>, <<"still_binary">>]}.\n)

      archive = malicious_package_archive!(valid_proof_entries(), metadata)
      on_exit(fn -> File.rm_rf(Path.dirname(archive)) end)

      assert {:ok, :validated} =
               Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
                 archive,
                 sha256!(archive),
                 fn _root -> :validated end
               )
    end

    @tag :adoption_archive_security
    test "rejects unsupported metadata syntax, duplicate selected fields, and parser limit breaches" do
      oversized_version = :binary.copy("v", 256)

      invalid_metadata = [
        ~s({<<"unknown">>, bare_atom}.\n),
        ~s({<<"unknown">>, 'quoted_atom'}.\n),
        ~s({<<"unknown">>, Variable}.\n),
        ~s({<<"unknown">>, 1}.\n),
        ~s({<<"unknown">>, [<<"value">> | <<"tail">>]}.\n),
        ~s({<<"name">>, <<"chimeway">>}.\n),
        ~s({<<"unknown">>, <<"unterminated>>}.\n),
        ~s({<<"unknown">>, <<"value">>}. trailing),
        ~s({<<"version">>, <<"#{oversized_version}">>}.\n),
        :binary.copy(" ", 1 * 1024 * 1024 + 1)
      ]

      for suffix <- invalid_metadata do
        archive = malicious_package_archive!(valid_proof_entries(), default_metadata() <> suffix)
        on_exit(fn -> File.rm_rf(Path.dirname(archive)) end)

        assert {:error, "package metadata is malformed"} =
                 Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
                   archive,
                   sha256!(archive),
                   fn _root -> flunk("metadata rejection must precede callback") end
                 )
      end
    end

    @tag :adoption_archive_security
    test "validates a freshly built Hex archive through the metadata parser exactly once" do
      archive = build_package_archive!()
      on_exit(fn -> File.rm_rf(Path.dirname(archive)) end)

      assert {:ok, :validated} =
               Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
                 archive,
                 sha256!(archive),
                 fn root ->
                   assert File.regular?(Path.join(root, "mix.exs"))
                   assert File.regular?(Path.join(root, "scripts/prove-accrue-consumer.exs"))

                   assert File.regular?(
                            Path.join(root, "priv/adoption_proof/artifact_consumer_fixture.ex")
                          )

                   send(self(), :real_archive_callback)
                   :validated
                 end
               )

      assert_received :real_archive_callback
      refute_received :real_archive_callback
    end

    @tag :adoption_archive_security
    test "keeps archive metadata away from source parsers, evaluators, and atom creators" do
      source = File.read!("priv/adoption_proof/artifact_archive.ex")

      for forbidden <- [
            ":file.consult",
            ":erl_scan",
            ":erl_parse",
            "Code.string_to_quoted",
            "String.to_atom",
            "List.to_atom"
          ] do
        refute source =~ forbidden, "archive parser must not use #{forbidden}"
      end

      assert source =~ "@max_metadata_bytes 1 * 1024 * 1024"
      assert source =~ "parse_metadata!"
      assert source =~ "secure_equal?"
    end

    @tag :adoption_archive_security
    test "enforces metadata nesting and selected files boundaries before callback" do
      accepted_metadata =
        default_metadata() <>
          ~s({<<"nested">>, #{nested_metadata_value(30)}}.\n)

      accepted_archive = malicious_package_archive!(valid_proof_entries(), accepted_metadata)
      on_exit(fn -> File.rm_rf(Path.dirname(accepted_archive)) end)

      assert {:ok, :nested_boundary} =
               Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
                 accepted_archive,
                 sha256!(accepted_archive),
                 fn _root -> :nested_boundary end
               )

      for metadata <- [
            default_metadata() <> ~s({<<"nested">>, #{nested_metadata_value(33)}}.\n),
            metadata_with_files(4_097)
          ] do
        archive = malicious_package_archive!(valid_proof_entries(), metadata)
        on_exit(fn -> File.rm_rf(Path.dirname(archive)) end)

        assert {:error, "package metadata is malformed"} =
                 Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
                   archive,
                   sha256!(archive),
                   fn _root -> flunk("metadata limit must precede callback") end
                 )
      end
    end

    @tag :adoption_archive_security
    test "rejects hard links, devices, FIFOs, and extension records before callback or scratch writes" do
      outside = temporary_path!("outside-special.txt")
      File.write!(outside, "unchanged")
      on_exit(fn -> File.rm_rf(Path.dirname(outside)) end)

      for type <- @unsupported_tar_types do
        archive = malicious_package_archive!([{"special-#{type}", type, outside, <<>>}])
        on_exit(fn -> File.rm_rf(Path.dirname(archive)) end)

        assert {:error, _} =
                 Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
                   archive,
                   sha256!(archive),
                   fn _root -> send(self(), {:callback_invoked, type}) end
                 )

        refute_received {:callback_invoked, ^type}
        assert File.read!(outside) == "unchanged"
      end
    end

    @tag :adoption_archive_security
    test "allows directory parents but rejects duplicate, conflicting, and traversal output paths" do
      valid =
        malicious_package_archive!([
          {"priv", ?5, "", <<>>},
          {"priv/adoption_proof", ?5, "", <<>>},
          {"mix.exs", ?0, "", "@version \"0.0.1\"\n"},
          {"scripts/prove-accrue-consumer.exs", ?0, "", "# runner\n"},
          {"priv/adoption_proof/artifact_consumer_fixture.ex", ?0, "", "# fixture\n"}
        ])

      on_exit(fn -> File.rm_rf(Path.dirname(valid)) end)

      assert {:ok, :valid_directory_tree} =
               Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
                 valid,
                 sha256!(valid),
                 fn _root -> :valid_directory_tree end
               )

      for entries <- [
            [{"mix.exs", ?0, "", "one"}, {"mix.exs", ?0, "", "two"}],
            [{"mix.exs", ?0, "", "one"}, {"mix.exs/file", ?0, "", "two"}],
            [{"../mix.exs", ?0, "", "outside"}],
            [{"/mix.exs", ?0, "", "outside"}]
          ] do
        archive = malicious_package_archive!(entries)
        on_exit(fn -> File.rm_rf(Path.dirname(archive)) end)

        assert {:error, _} =
                 Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
                   archive,
                   sha256!(archive),
                   fn _root -> flunk("callback must not run for conflicting archive paths") end
                 )
      end
    end

    @tag :adoption_archive_security
    test "fails closed on truncated or checksum-invalid contents before the callback" do
      complete = raw_tar([{"mix.exs", ?0, "", "@version \"0.0.1\"\n"}])
      truncated = binary_part(complete, 0, byte_size(complete) - 1024)
      invalid_checksum = put_tar_field(complete, 124, 12, "99999999999\0")

      for contents <- [truncated, invalid_checksum] do
        archive = malicious_package_archive_from_contents!(contents)
        on_exit(fn -> File.rm_rf(Path.dirname(archive)) end)

        assert {:error, _} =
                 Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
                   archive,
                   sha256!(archive),
                   fn _root -> flunk("callback must not run for malformed archive contents") end
                 )
      end
    end
  end

  describe "adoption archive immutable-byte validation (T-96-16)" do
    @tag :adoption_archive_toctou
    test "binds the accepted digest and outer extraction to the opened archive when its pathname is replaced" do
      archive_a =
        malicious_package_archive!([
          {"mix.exs", ?0, "", "@version \"0.0.1\"\n# archive-a\n"},
          {"scripts/prove-accrue-consumer.exs", ?0, "", "# runner\n"},
          {"priv/adoption_proof/artifact_consumer_fixture.ex", ?0, "", "# fixture\n"}
        ])

      archive_b =
        malicious_package_archive!([
          {"mix.exs", ?0, "", "@version \"0.0.1\"\n# archive-b\n"},
          {"scripts/prove-accrue-consumer.exs", ?0, "", "# runner\n"},
          {"priv/adoption_proof/artifact_consumer_fixture.ex", ?0, "", "# fixture\n"}
        ])

      replacement = archive_a <> ".replacement"
      File.cp!(archive_b, replacement)
      accepted_digest = sha256!(archive_a)
      replacement_digest = sha256!(replacement)
      parent = self()

      on_exit(fn ->
        File.rm_rf(Path.dirname(archive_a))
        File.rm_rf(Path.dirname(archive_b))
      end)

      validator =
        Task.async(fn ->
          Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
            archive_a,
            accepted_digest,
            fn root ->
              source = File.read!(Path.join(root, "mix.exs"))
              assert source =~ "archive-a"
              refute source =~ "archive-b"
              :archive_a
            end,
            archive_opened: fn ->
              send(parent, {:archive_opened, self()})

              receive do
                :resume_archive_read -> :ok
              after
                5_000 -> raise "timed out waiting to resume archive read"
              end
            end
          )
        end)

      assert_receive {:archive_opened, validator_pid}, 5_000
      assert :ok = File.rename(replacement, archive_a)
      assert sha256!(archive_a) == replacement_digest
      send(validator_pid, :resume_archive_read)

      assert {:ok, :archive_a} =
               Task.await(validator, 15_000)

      source = File.read!("priv/adoption_proof/artifact_archive.ex")

      assert source =~ "read_bounded_archive!"
      assert source =~ ":erl_tar.extract({:binary, archive_binary}, [:memory])"
      refute source =~ ":erl_tar.extract(String.to_charlist(archive), [:memory])"
    end
  end

  describe "adoption archive resource limits (T-96-17..T-96-19)" do
    @tag :adoption_archive_limits
    test "names pre-materialization budgets for every caller-controlled archive dimension" do
      source = File.read!("priv/adoption_proof/artifact_archive.ex")

      for required <- [
            "@max_outer_archive_bytes 32 * 1024 * 1024",
            "@max_compressed_contents_bytes 16 * 1024 * 1024",
            "@max_decompressed_contents_bytes 64 * 1024 * 1024",
            "@max_members 4_096",
            "@max_regular_member_bytes 8 * 1024 * 1024",
            "inflate_contents!",
            "safeInflate"
          ] do
        assert source =~ required
      end

      refute source =~ ":zlib.gunzip(contents)"
    end

    @tag :adoption_archive_limits
    test "fails closed one byte or member past every archive budget before the callback" do
      outer = malicious_package_archive!([])
      on_exit(fn -> File.rm_rf(Path.dirname(outer)) end)
      File.write!(outer, :binary.copy(<<0>>, 32 * 1024 * 1024 + 1), [:append])

      compressed =
        package_archive_from_compressed_contents!(:crypto.strong_rand_bytes(16 * 1024 * 1024 + 1))

      expanded =
        malicious_package_archive_from_contents!(:binary.copy(<<0>>, 64 * 1024 * 1024 + 1))

      member_count =
        malicious_package_archive!(for index <- 1..4_097, do: {"members/#{index}", ?0, "", <<>>})

      member_size =
        malicious_package_archive!([
          {"large.bin", ?0, "", :binary.copy(<<0>>, 8 * 1024 * 1024 + 1)}
        ])

      for archive <- [outer, compressed, expanded, member_count, member_size] do
        on_exit(fn -> File.rm_rf(Path.dirname(archive)) end)

        assert {:error, _} =
                 Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
                   archive,
                   sha256!(archive),
                   fn _root -> send(self(), :callback_invoked) end
                 )

        refute_received :callback_invoked
      end
    end

    @tag :adoption_archive_limits
    test "permits a regular member exactly at the documented 8 MiB limit" do
      archive =
        malicious_package_archive!([
          {"mix.exs", ?0, "", "@version \"0.0.1\"\n"},
          {"scripts/prove-accrue-consumer.exs", ?0, "", "# runner\n"},
          {"priv/adoption_proof/artifact_consumer_fixture.ex", ?0, "", "# fixture\n"},
          {"large.bin", ?0, "", :binary.copy(<<0>>, 8 * 1024 * 1024)}
        ])

      on_exit(fn -> File.rm_rf(Path.dirname(archive)) end)

      assert {:ok, :validated} =
               Chimeway.AdoptionProof.ArtifactArchive.with_validated_archive(
                 archive,
                 sha256!(archive),
                 fn _root -> :validated end
               )
    end
  end

  describe "adoption paths contract (GATE-01/D-05..D-08)" do
    @tag :adoption_paths_contract
    # The required verify_adoption_paths CI lane owns this expensive subprocess
    # proof. General/release-contract lanes exclude only :adoption_paths_e2e so
    # PR coverage stays singular while direct test runs retain the E2E contract.
    @tag :adoption_paths_e2e
    @tag timeout: 900_000
    test "runs the complete packaged proof once in Core, Mailglass, Accrue order" do
      {output, status} = System.cmd("mix", ["verify.adoption_paths"], stderr_to_stdout: true)

      assert status == 0

      assert Regex.scan(~r/\[adoption:(core|mailglass|accrue)\] START/, output) == [
               ["[adoption:core] START", "core"],
               ["[adoption:mailglass] START", "mailglass"],
               ["[adoption:accrue] START", "accrue"]
             ]

      for path <- ["CORE", "MAILGLASS", "ACCRUE"] do
        assert length(Regex.scan(~r/CHIMEWAY_#{path}_PROOF /, output)) == 1
      end
    end

    @tag :adoption_paths_contract
    test "keeps the runner bounded to fixture dispatch and redacted proof framing" do
      runner = File.read!("scripts/prove-adoption-paths.exs")

      for required <- ["prove_core!", "prove_mailglass!", "prove_accrue!", "[adoption:"] do
        assert runner =~ required
      end

      for forbidden <- [
            "verify.mailglass",
            "verify.accrue",
            "sibling checkout",
            "path dependency",
            "docker compose",
            "matrix",
            "Task.async"
          ] do
        refute runner =~ forbidden
      end
    end
  end

  describe "adoption selector package and command contract (ADPT-01/ADPT-02/DOCS-01)" do
    @tag :adoption_paths_docs_contract
    test "ships the selector and runner as explicit package surfaces with exact bounded symbols" do
      mix_exs = File.read!("mix.exs")
      selector = File.read!("guides/introduction/adoption-paths.md")
      task = File.read!("lib/mix/tasks/verify.adoption_paths.ex")
      runner = File.read!("scripts/prove-adoption-paths.exs")

      assert mix_exs =~ "guides/introduction/adoption-paths.md"
      assert mix_exs =~ "scripts/prove-adoption-paths.exs"
      assert task =~ "Mix.Tasks.Verify.AdoptionPaths"
      assert task =~ "OptionParser.parse"
      assert runner =~ "Chimeway.AdoptionProofRunner"

      for {path, prefix, guide} <- [
            {"core", "CHIMEWAY_CORE_PROOF", "golden-path.md"},
            {"mailglass", "CHIMEWAY_MAILGLASS_PROOF", "mailglass-integration.md"},
            {"accrue", "CHIMEWAY_ACCRUE_PROOF", "accrue-dunning-integration.md"}
          ] do
        assert selector =~ "mix verify.adoption_paths --only #{path}"
        assert selector =~ prefix
        assert selector =~ guide
      end
    end

    @tag :adoption_paths_docs_contract
    test "makes renamed command, missing package surface, or duplicate unsafe selector evidence observable" do
      task = File.read!("lib/mix/tasks/verify.adoption_paths.ex")
      mix_exs = File.read!("mix.exs")
      selector = File.read!("guides/introduction/adoption-paths.md")

      refute String.contains?(
               String.replace(task, "verify.adoption_paths", "verify.paths", global: false),
               "verify.adoption_paths"
             )

      refute String.contains?(
               String.replace(mix_exs, "scripts/prove-adoption-paths.exs", "", global: false),
               "scripts/prove-adoption-paths.exs"
             )

      for prefix <- ~w(CHIMEWAY_CORE_PROOF CHIMEWAY_MAILGLASS_PROOF CHIMEWAY_ACCRUE_PROOF) do
        assert length(:binary.matches(selector, prefix)) == 1
        assert length(:binary.matches(selector <> " " <> prefix, prefix)) == 2
      end
    end
  end

  describe "adoption paths CI contract (GATE-02/DOCS-01)" do
    @tag :adoption_paths_ci_contract
    test "runs exactly one bounded PostgreSQL aggregate proof lane on every CI event" do
      ci_yml = File.read!(@ci_yml)
      job = extract_ci_job_block(ci_yml, "verify_adoption_paths")

      assert length(Regex.scan(~r/^  verify_adoption_paths:/m, ci_yml)) == 1

      for required <- [
            "timeout-minutes: 30",
            "image: postgres:15",
            "--health-cmd pg_isready",
            "- 5432:5432",
            "DATABASE_URL: postgres://postgres:postgres@localhost/chimeway_test",
            "name: Run adoption proof paths",
            "mix verify.adoption_paths"
          ] do
        assert job =~ required, "adoption proof job must contain #{required}"
      end

      for forbidden <- [
            "matrix:",
            "verify.mailglass",
            "verify.accrue",
            "ACCRUE_PATH",
            "THREADLINE_PATH",
            "SIGRA_PATH",
            "docker compose",
            "registry",
            "github.event_name != 'pull_request'"
          ] do
        refute job =~ forbidden, "adoption proof job must not contain #{forbidden}"
      end
    end

    @tag :adoption_paths_ci_contract
    test "couples the lane to both aggregate gates in every required place" do
      ci_yml = File.read!(@ci_yml)
      ci_gate = extract_ci_job_block(ci_yml, "ci-gate")
      pr_gate = extract_ci_job_block(ci_yml, "pr-gate")

      assert "verify_adoption_paths" in extract_ci_gate_needs(ci_yml)
      assert "verify_adoption_paths" in extract_pr_gate_needs(ci_yml)
      assert ci_gate =~ "VERIFY_ADOPTION_PATHS: ${{ needs.verify_adoption_paths.result }}"
      assert ci_gate =~ "aggregate-gate.sh"
      assert ci_gate =~ "VERIFY_ADOPTION_PATHS"
      assert pr_gate =~ "VERIFY_ADOPTION_PATHS: ${{ needs.verify_adoption_paths.result }}"

      assert pr_gate =~
               "aggregate-gate.sh LINT TEST VERIFY_GATES VERIFY_DOCS VERIFY_ADOPTION_PATHS"

      for mutated <- [
            String.replace(ci_yml, "verify_adoption_paths:", "verify_adoption_path:",
              global: false
            ),
            replace_adoption_job(
              ci_yml,
              &String.replace(&1, "image: postgres:15", "", global: false)
            ),
            replace_adoption_job(
              ci_yml,
              &String.replace(&1, "timeout-minutes: 30", "", global: false)
            ),
            replace_adoption_job(
              ci_yml,
              &String.replace(&1, "mix verify.adoption_paths", "", global: false)
            ),
            String.replace(ci_yml, "VERIFY_ADOPTION_PATHS", "", global: false)
          ] do
        refute ci_topology_intact?(mutated)
      end
    end

    @tag :adoption_paths_ci_contract
    test "asserts one exact-SHA successful PR run without leaking environment secrets" do
      {syntax_output, syntax_status} =
        System.cmd("bash", ["-n", @adoption_run_assertion], stderr_to_stdout: true)

      assert syntax_status == 0, syntax_output

      executable_source =
        @adoption_run_assertion
        |> File.read!()
        |> String.split("\n")
        |> Enum.reject(&String.starts_with?(String.trim_leading(&1), "#"))
        |> Enum.join("\n")

      refute executable_source =~ "eval"

      {output, status} =
        run_adoption_assertion!(@adoption_run_fixture,
          extra_env: [
            {"GH_TOKEN", "phase-96-secret-token"},
            {"DATABASE_URL", "postgres://user:phase-96-secret@localhost/db"}
          ]
        )

      assert status == 0, output

      assert output ==
               "ADOPTION_RUN_PROOF sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa " <>
                 "run_id=42424242 adoption=success pr_gate=success " <>
                 "url=https://github.com/szTheory/chimeway/actions/runs/42424242\n"

      refute output =~ "phase-96-secret"
      refute output =~ "DATABASE_URL"
    end

    @tag :adoption_paths_ci_contract
    test "fails closed when live-run identity, completion, proof, or gate evidence is absent" do
      fixture = @adoption_run_fixture |> File.read!() |> Jason.decode!()

      mutations = [
        {"wrong SHA", fn payload -> Map.put(payload, "headSha", String.duplicate("b", 40)) end},
        {"wrong event", fn payload -> Map.put(payload, "event", "push") end},
        {"pending run", fn payload -> Map.put(payload, "status", "in_progress") end},
        {"failed run", fn payload -> Map.put(payload, "conclusion", "failure") end},
        {"missing adoption job",
         fn payload ->
           Map.update!(
             payload,
             "jobs",
             &Enum.reject(&1, fn job -> job["name"] == "Adoption proof paths" end)
           )
         end},
        {"failed adoption job",
         fn payload ->
           update_adoption_job(payload, &Map.put(&1, "conclusion", "failure"))
         end},
        {"skipped proof step",
         fn payload ->
           update_adoption_job(payload, fn job ->
             Map.update!(job, "steps", fn [step] -> [Map.put(step, "conclusion", "skipped")] end)
           end)
         end},
        {"failed pr-gate",
         fn payload ->
           Map.update!(payload, "jobs", fn jobs ->
             Enum.map(jobs, fn
               %{"name" => "pr-gate"} = job -> Map.put(job, "conclusion", "failure")
               job -> job
             end)
           end)
         end}
      ]

      for {label, mutate} <- mutations do
        fixture_path = write_adoption_run_fixture!(mutate.(fixture))
        {output, status} = run_adoption_assertion!(fixture_path)

        assert status != 0, "#{label} must fail closed:\n#{output}"
        assert output =~ "adoption run proof failed:"
      end
    end
  end

  defmodule CoreProofNotifier do
    def notification_key, do: "artifact_consumer.core_trace"
    def version, do: 1
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

  defp build_package_archive! do
    output =
      Path.join(
        System.tmp_dir!(),
        "chimeway_release_archive_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(output)
    archive = Path.join(output, "chimeway.tar")

    {out, status} =
      System.cmd("mix", ["hex.build", "--output", archive],
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "prod"}]
      )

    assert status == 0, out
    archive
  end

  defp sha256!(path), do: :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)

  defp malicious_package_archive!(contents_entries, metadata \\ default_metadata()) do
    contents_entries |> raw_tar() |> malicious_package_archive_from_contents!(metadata)
  end

  defp malicious_package_archive_from_contents!(contents, metadata \\ default_metadata()) do
    package_archive_from_compressed_contents!(:zlib.gzip(contents), metadata)
  end

  defp package_archive_from_compressed_contents!(contents, metadata \\ default_metadata()) do
    output = temporary_path!("archive")
    File.mkdir_p!(output)
    archive = Path.join(output, "malicious.tar")

    File.write!(
      archive,
      raw_tar([{"metadata.config", ?0, "", metadata}, {"contents.tar.gz", ?0, "", contents}])
    )

    archive
  end

  defp default_metadata do
    ~s({<<"name">>, <<"chimeway">>}.\n{<<"version">>, <<"0.0.1">>}.\n{<<"files">>, [<<"scripts/prove-accrue-consumer.exs">>, <<"priv/adoption_proof/artifact_consumer_fixture.ex">>]}.\n)
  end

  defp valid_proof_entries do
    [
      {"mix.exs", ?0, "", "@version \"0.0.1\"\n"},
      {"scripts/prove-accrue-consumer.exs", ?0, "", "# runner\n"},
      {"priv/adoption_proof/artifact_consumer_fixture.ex", ?0, "", "# fixture\n"}
    ]
  end

  defp hostile_atom_tokens(count) do
    for index <- 1..count do
      "chimeway_archive_atom_#{System.unique_integer([:positive])}_#{index}"
    end
  end

  defp nested_metadata_value(depth),
    do: String.duplicate("[", depth) <> "<<\"leaf\">>" <> String.duplicate("]", depth)

  defp metadata_with_files(count) do
    files =
      ["scripts/prove-accrue-consumer.exs", "priv/adoption_proof/artifact_consumer_fixture.ex"] ++
        Enum.map(1..(count - 2), &"file-#{&1}")

    ~s({<<"name">>, <<"chimeway">>}.\n{<<"version">>, <<"0.0.1">>}.\n{<<"files">>, [#{Enum.map_join(files, ", ", &"<<\"#{&1}\">>")}]}.\n)
  end

  defp raw_tar(entries) do
    Enum.map_join(entries, &raw_tar_entry/1) <> :binary.copy(<<0>>, 1024)
  end

  defp raw_tar_entry({name, type, link_name, body}) do
    header = :binary.copy(<<0>>, 512)
    header = put_tar_field(header, 0, 100, name)
    header = put_tar_field(header, 100, 8, "0000644\0")
    header = put_tar_field(header, 108, 8, "0000000\0")
    header = put_tar_field(header, 116, 8, "0000000\0")
    header = put_tar_field(header, 124, 12, tar_octal(byte_size(body), 12))
    header = put_tar_field(header, 136, 12, "00000000000\0")
    header = put_tar_field(header, 148, 8, "        ")
    header = put_tar_field(header, 156, 1, <<type>>)
    header = put_tar_field(header, 157, 100, link_name)
    header = put_tar_field(header, 257, 6, "ustar\0")
    header = put_tar_field(header, 263, 2, "00")
    checksum = header |> :binary.bin_to_list() |> Enum.sum() |> tar_checksum()
    header = put_tar_field(header, 148, 8, checksum)
    padding = rem(512 - rem(byte_size(body), 512), 512)
    header <> body <> :binary.copy(<<0>>, padding)
  end

  defp put_tar_field(binary, offset, width, value) do
    value = IO.iodata_to_binary(value)

    binary_part(value, 0, min(byte_size(value), width))
    |> then(fn truncated ->
      :binary.part(binary, 0, offset) <>
        truncated <>
        :binary.copy(<<0>>, width - byte_size(truncated)) <>
        :binary.part(binary, offset + width, byte_size(binary) - offset - width)
    end)
  end

  defp tar_octal(value, width) do
    value |> Integer.to_string(8) |> String.pad_leading(width - 1, "0") |> Kernel.<>("\0")
  end

  defp tar_checksum(value) do
    value |> Integer.to_string(8) |> String.pad_leading(6, "0") |> Kernel.<>(<<0, 32>>)
  end

  defp temporary_path!(suffix) do
    Path.join(
      System.tmp_dir!(),
      "chimeway_adoption_security_#{System.unique_integer([:positive])}_#{suffix}"
    )
  end

  defp packaged_accrue_cli(root, archive, digest) do
    System.cmd(
      "mix",
      [
        "run",
        "--no-start",
        "scripts/prove-accrue-consumer.exs",
        "--",
        "--artifact-archive",
        archive,
        "--sha256",
        digest
      ],
      cd: root,
      stderr_to_stdout: true,
      env: [{"MIX_ENV", "prod"}]
    )
  end

  defp invalid_packaged_accrue_cli(argv) do
    System.cmd("elixir", ["scripts/prove-accrue-consumer.exs", "--" | argv],
      stderr_to_stdout: true
    )
  end

  defp direct_accrue_proof_record_write?(source) do
    Regex.match?(~r/IO\.(?:puts|binwrite)\([^\n]*["']CHIMEWAY_ACCRUE_PROOF /, source)
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

  defp mailglass_evidence_line do
    "CHIMEWAY_MAILGLASS_PROOF " <>
      "notification_key=artifact_consumer.mailglass_proof " <>
      "notification_version=1 delivery_id=2f1c8b94-3a5e-4d70-8c16-2e3a4b5c6d7e channel=email " <>
      "render_key=artifact_consumer.mailglass_proof.email render_version=1 " <>
      "status=succeeded outcome_classification=succeeded last_attempt_outcome=succeeded " <>
      "last_attempt_number=1 provider_handoff=accepted " <>
      "timeline_events=event_created,notification_created,delivery_planned,attempt_recorded,webhook_received"
  end

  defp replace_mailglass_evidence_value(line, key, value) do
    Regex.replace(~r/(^|\s)#{Regex.escape(key)}=[^\s]*/, line, "\\1#{key}=#{value}")
  end

  defp accrue_evidence_line do
    "CHIMEWAY_ACCRUE_PROOF provenance=released_package accrue_version=1.3.0 chimeway_version=1.0.0 " <>
      "workflow_key=accrue.dunning workflow_version=1 waiting_state=waiting " <>
      "waiting_reason=waiting_for_step_progression outcome_event=invoice.paid outcome_state=active " <>
      "outcome_reason=signal_received timeline_reasons=waiting_for_step_progression,signal_received"
  end

  defp replace_accrue_evidence_value(line, key, value) do
    Regex.replace(~r/(^|\s)#{Regex.escape(key)}=[^\s]*/, line, "\\1#{key}=#{value}")
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

  defp ci_topology_intact?(ci_yml) do
    with job when is_binary(job) <- ci_job_block(ci_yml, "verify_adoption_paths"),
         gate when is_binary(gate) <- ci_job_block(ci_yml, "ci-gate"),
         pr_gate when is_binary(pr_gate) <- ci_job_block(ci_yml, "pr-gate") do
      job =~ "timeout-minutes: 30" and job =~ "image: postgres:15" and
        job =~ "mix verify.adoption_paths" and
        not (job =~ "github.event_name != 'pull_request'") and
        "verify_adoption_paths" in extract_ci_gate_needs(ci_yml) and
        "verify_adoption_paths" in extract_pr_gate_needs(ci_yml) and
        gate =~ "VERIFY_ADOPTION_PATHS: ${{ needs.verify_adoption_paths.result }}" and
        gate =~ "INSTALL_GOLDEN VERIFY_ADOPTION_PATHS TEST_FLOOR_1_17" and
        pr_gate =~ "VERIFY_ADOPTION_PATHS: ${{ needs.verify_adoption_paths.result }}" and
        pr_gate =~ "VERIFY_GATES VERIFY_DOCS VERIFY_ADOPTION_PATHS"
    else
      _ -> false
    end
  end

  defp ci_job_block(yml, job_id) do
    case Regex.run(~r/^  #{job_id}:(.*?)(?:\n  [a-z0-9_]+:|\z)/ms, yml) do
      [_, block] -> block
      _ -> nil
    end
  end

  defp replace_adoption_job(ci_yml, replace) do
    job = extract_ci_job_block(ci_yml, "verify_adoption_paths")
    String.replace(ci_yml, job, replace.(job), global: false)
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

  defp run_adoption_assertion!(fixture_path, opts \\ []) do
    env =
      [
        {"ADOPTION_RUN_JSON", fixture_path},
        {"GITHUB_REPOSITORY", "szTheory/chimeway"}
      ] ++ Keyword.get(opts, :extra_env, [])

    System.cmd(
      "bash",
      [@adoption_run_assertion, String.duplicate("a", 40)],
      stderr_to_stdout: true,
      env: env
    )
  end

  defp write_adoption_run_fixture!(payload) do
    directory =
      Path.join(
        System.tmp_dir!(),
        "chimeway_adoption_run_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)

    path = Path.join(directory, "run.json")
    File.write!(path, Jason.encode!(payload))
    path
  end

  defp update_adoption_job(payload, update) do
    Map.update!(payload, "jobs", fn jobs ->
      Enum.map(jobs, fn
        %{"name" => "Adoption proof paths"} = job -> update.(job)
        job -> job
      end)
    end)
  end
end

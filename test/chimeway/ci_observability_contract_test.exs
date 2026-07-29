defmodule Chimeway.CIObservabilityContractTest do
  use ExUnit.Case, async: true

  @moduledoc false

  @ci_yml ".github/workflows/ci.yml"
  @compile_cold_log "test/fixtures/ci/compile_cold.log"
  @compile_warm_log "test/fixtures/ci/compile_warm.log"
  @jobs_api_sample "test/fixtures/ci/jobs_api_sample.json"
  @obs_recompile_sh "scripts/ci/obs-recompile.sh"
  @obs_summary_sh "scripts/ci/obs-summary.sh"
  @runner_name "GitHub Actions 2"
  @ci_perf_baseline ".planning/CI-PERF-BASELINE.md"

  # Mirrors @ci_gate_lanes in release_gate_contract_test.exs — the 14 build
  # lanes that must each carry a stable cache id: and a trailing obs-summary
  # step (OBS-01/02/03 fleet-wide fan-out).
  @build_lanes ~w(lint test verify_gates verify_docs verify_example verify_runtime_prefix verify_journeys verify_mailglass verify_accrue verify_inbox verify_threadline verify_sigra verify_admin install_golden_contract)

  setup do
    %{ci_yml: File.read!(@ci_yml)}
  end

  describe "obs-recompile.sh parser (OBS-02)" do
    test "warm-cache log (no Compiling lines) reports 0 0" do
      {deps_n, app_n} = run_recompile_probe!(@compile_warm_log, @compile_warm_log)

      assert deps_n == 0
      assert app_n == 0
    end

    test "cold-cache log reports the fixture's known nonzero counts" do
      {deps_n, app_n} = run_recompile_probe!(@compile_cold_log, @compile_cold_log)

      assert deps_n == 260
      assert app_n == 260
    end
  end

  describe "obs-summary.sh cache classification (OBS-01)" do
    test "cache-hit true renders EXACT HIT" do
      summary =
        run_summary_probe!(%{
          "CACHE_MAIN_HIT" => "true",
          "CACHE_MAIN_MATCHED" => "Linux-mix-abc123",
          "CACHE_MAIN_PRIMARY" => "Linux-mix-abc123"
        })

      assert summary =~ "EXACT HIT"
      refute summary =~ "PARTIAL"
      refute summary =~ "| MAIN | MISS |"
    end

    test "non-empty matched key without exact hit renders PARTIAL" do
      summary =
        run_summary_probe!(%{
          "CACHE_MAIN_HIT" => "false",
          "CACHE_MAIN_MATCHED" => "Linux-mix-",
          "CACHE_MAIN_PRIMARY" => "Linux-mix-abc123"
        })

      assert summary =~ "PARTIAL"
      refute summary =~ "EXACT HIT"
    end

    test "non-true hit with no matched key renders MISS" do
      # Note: CACHE_MAIN_MATCHED is deliberately omitted rather than passed as
      # "" — erlang's port env list does not reliably export empty-string
      # values to the child process (OTP/OS-dependent), so an unset var
      # (which the script defaults via `${!name:-}`) is the reliable way to
      # simulate a GitHub Actions cache-matched-key output of "".
      summary =
        run_summary_probe!(%{
          "CACHE_MAIN_HIT" => "false",
          "CACHE_MAIN_PRIMARY" => "Linux-mix-abc123"
        })

      assert summary =~ "MISS"
      refute summary =~ "EXACT HIT"
      refute summary =~ "PARTIAL"
    end
  end

  describe "obs-summary.sh timing rows (OBS-03)" do
    test "fixture jobs JSON renders step timing rows" do
      summary =
        run_summary_probe!(
          %{
            "CACHE_MAIN_HIT" => "true",
            "CACHE_MAIN_MATCHED" => "Linux-mix-abc123",
            "CACHE_MAIN_PRIMARY" => "Linux-mix-abc123"
          },
          obs_jobs_json: @jobs_api_sample
        )

      assert summary =~ "### Step timing"
      assert summary =~ ~r/\| Set up job \| \d+s \|/
      assert summary =~ ~r/\| Checkout \| \d+s \|/
      refute summary =~ "timing unavailable"
    end

    test "missing jobs JSON degrades gracefully to timing unavailable with a zero exit" do
      tmp = mk_runner_temp!()

      env = [
        {"RUNNER_TEMP", tmp},
        {"GITHUB_STEP_SUMMARY", Path.join(tmp, "step-summary.md")},
        {"RUN_URL", "https://example.com/run/1"},
        {"OBS_JOBS_JSON", Path.join(tmp, "does-not-exist.json")},
        {"CACHE_MAIN_HIT", "true"},
        {"CACHE_MAIN_MATCHED", "Linux-mix-abc123"},
        {"CACHE_MAIN_PRIMARY", "Linux-mix-abc123"}
      ]

      {out, status} = System.cmd("bash", [@obs_summary_sh], stderr_to_stdout: true, env: env)

      assert status == 0,
             "obs-summary.sh must exit 0 even when timing data is unavailable:\n#{out}"

      summary = File.read!(Path.join(tmp, "step-summary.md"))
      assert summary =~ "timing unavailable"
    end
  end

  describe "obs-summary.sh secret hygiene" do
    test "rendered summary never leaks raw env or token values" do
      summary =
        run_summary_probe!(
          %{
            "CACHE_MAIN_HIT" => "true",
            "CACHE_MAIN_MATCHED" => "Linux-mix-abc123",
            "CACHE_MAIN_PRIMARY" => "Linux-mix-abc123"
          },
          obs_jobs_json: @jobs_api_sample,
          gh_token: "super-secret-token-value"
        )

      refute summary =~ "super-secret-token-value"
      refute summary =~ "DATABASE_URL"
    end
  end

  describe "OBS-04 baseline (baseline doc)" do
    test "baseline doc exists" do
      assert File.exists?(@ci_perf_baseline),
             "#{@ci_perf_baseline} must exist and be committed (OBS-04)"
    end

    test "baseline doc carries a durable actions/runs/ permalink" do
      baseline = File.read!(@ci_perf_baseline)

      assert baseline =~ ~r{actions/runs/\d+},
             "#{@ci_perf_baseline} must contain a real numeric actions/runs/<digits> permalink, " <>
               "not a placeholder"
    end

    test "baseline doc contains the four pre-optimization baseline facts" do
      baseline = File.read!(@ci_perf_baseline)

      # ci-gate wall-clock (~373-395s)
      assert baseline =~ "395", "baseline doc must record the wall-clock baseline figure (~395s)"
      # install_golden job (373s) / hidden compile in ecto.create (~135s)
      assert baseline =~ "373",
             "baseline doc must record the install_golden baseline figure (373s)"

      assert baseline =~ "135",
             "baseline doc must record the hidden ecto.create compile figure (~135s)"

      # dep recompile across 3 identical-lock runs: dead-flat (cache never warms)
      assert baseline =~ "dead-flat",
             "baseline doc must record the dead-flat recompile finding across identical-lock runs"
    end

    test "baseline doc includes a delta-ledger table for later phases to append to" do
      baseline = File.read!(@ci_perf_baseline)

      assert baseline =~ "Phase 88 after",
             "baseline doc must include a delta-ledger column for Phase 88+ to append after-values to"
    end
  end

  describe "lint lane wiring (OBS-01 lint-scoped)" do
    test "cache step carries a stable id: cache_main", %{ci_yml: ci_yml} do
      lint_block = extract_ci_job_block(ci_yml, "lint")

      assert String.contains?(lint_block, "id: cache_main"),
             "lint lane's cache step must carry a stable id: cache_main"
    end

    test "lint lane invokes scripts/ci/obs-recompile.sh", %{ci_yml: ci_yml} do
      lint_block = extract_ci_job_block(ci_yml, "lint")

      assert String.contains?(lint_block, "scripts/ci/obs-recompile.sh"),
             "lint lane must run scripts/ci/obs-recompile.sh"
    end

    test "lint lane has a trailing obs-summary.sh step gated on if: always()", %{ci_yml: ci_yml} do
      lint_block = extract_ci_job_block(ci_yml, "lint")

      assert String.contains?(lint_block, "scripts/ci/obs-summary.sh"),
             "lint lane must run scripts/ci/obs-summary.sh"

      # The observability summary step must be the LAST step and must never
      # gate mix ci.lint — assert its `if: always()` appears after the
      # obs-recompile probe and before the obs-summary.sh invocation, and that
      # nothing in the lane runs after it.
      [_before, after_summary_name] =
        String.split(lint_block, "name: CI observability summary", parts: 2)

      assert after_summary_name =~ "if: always()"
      assert after_summary_name =~ "scripts/ci/obs-summary.sh"

      refute after_summary_name
             |> String.split("run: scripts/ci/obs-summary.sh", parts: 2)
             |> List.last()
             |> String.contains?("- name:"),
             "the observability summary step must be the LAST step in the lint lane"
    end
  end

  describe "all build lanes carry cache id + trailing obs-summary (OBS-01/02/03 fan-out)" do
    for lane <- @build_lanes do
      test "#{lane} carries a cache id and a trailing obs-summary step", %{ci_yml: ci_yml} do
        lane_block = extract_ci_job_block(ci_yml, unquote(lane))

        assert String.contains?(lane_block, "id: cache_main"),
               "#{unquote(lane)} must carry a stable id: cache_main on its root cache step"

        assert String.contains?(lane_block, "scripts/ci/obs-summary.sh"),
               "#{unquote(lane)} must run scripts/ci/obs-summary.sh"

        assert String.contains?(lane_block, "if: always()"),
               "#{unquote(lane)} obs-summary step must be gated on if: always()"
      end
    end

    test "install_golden_contract obs-summary step also gates on steps.detect.outputs.run",
         %{ci_yml: ci_yml} do
      lane_block = extract_ci_job_block(ci_yml, "install_golden_contract")

      [_before, after_summary_name] =
        String.split(lane_block, "name: CI observability summary", parts: 2)

      assert after_summary_name =~ "if: always() && steps.detect.outputs.run == 'true'",
             "install_golden_contract's obs-summary step must never run when the lane body is skipped"
    end

    test "no build-lane observability step introduces --warnings-as-errors (CACHE-03 exempts install_golden_contract only)",
         %{ci_yml: ci_yml} do
      # D-14: CACHE-03 adds an explicit `mix compile --warnings-as-errors` to
      # install_golden_contract only. The refute still fires for the other 13
      # lanes so the flag cannot leak into the shared obs-recompile.sh probe or
      # into Phase 89's separate ci.test --warnings-as-errors (CONC-03).
      for lane <- @build_lanes -- ["install_golden_contract"] do
        lane_block = extract_ci_job_block(ci_yml, lane)

        refute String.contains?(lane_block, "--warnings-as-errors"),
               "#{lane}'s recompile probe must stay a plain compile — the compile-warnings " <>
                 "upgrade is CACHE-03's sanctioned exception, scoped to install_golden_contract only"
      end
    end

    test "install_golden_contract runs the CACHE-03 warnings-as-errors compile before ecto.create (D-13)",
         %{ci_yml: ci_yml} do
      lane_block = extract_ci_job_block(ci_yml, "install_golden_contract")

      assert String.contains?(lane_block, "mix compile --warnings-as-errors"),
             "install_golden_contract must run the explicit CACHE-03 compile --warnings-as-errors gate"

      assert String.contains?(lane_block, "mix ecto.create"),
             "install_golden_contract must still run mix ecto.create"

      {compile_idx, _} = :binary.match(lane_block, "mix compile --warnings-as-errors")
      {ecto_idx, _} = :binary.match(lane_block, "mix ecto.create")

      assert compile_idx < ecto_idx,
             "the CACHE-03 warnings-as-errors compile must appear BEFORE mix ecto.create (D-13)"
    end
  end

  defp run_recompile_probe!(deps_fixture, app_fixture) do
    tmp = mk_runner_temp!()
    deps_log = Path.join(tmp, "obs-deps.log")
    app_log = Path.join(tmp, "obs-app.log")
    File.cp!(deps_fixture, deps_log)
    File.cp!(app_fixture, app_log)

    env = [
      {"RUNNER_TEMP", tmp},
      {"OBS_SKIP_COMPILE", "1"},
      {"OBS_DEPS_LOG", deps_log},
      {"OBS_APP_LOG", app_log}
    ]

    {out, status} = System.cmd("bash", [@obs_recompile_sh], stderr_to_stdout: true, env: env)

    assert status == 0, "obs-recompile.sh must exit 0 in OBS_SKIP_COMPILE=1 mode:\n#{out}"

    [deps_n, app_n] =
      tmp
      |> Path.join("obs-recompile.txt")
      |> File.read!()
      |> String.trim()
      |> String.split(" ")
      |> Enum.map(&String.to_integer/1)

    {deps_n, app_n}
  end

  defp run_summary_probe!(cache_env, opts \\ []) do
    tmp = mk_runner_temp!()
    step_summary = Path.join(tmp, "step-summary.md")

    base_env = [
      {"RUNNER_TEMP", tmp},
      {"GITHUB_STEP_SUMMARY", step_summary},
      {"RUN_URL", "https://github.com/szTheory/chimeway/actions/runs/1/attempts/1"},
      {"RUNNER_NAME", @runner_name},
      {"GH_TOKEN", Keyword.get(opts, :gh_token, "unused-token")}
    ]

    jobs_json_env =
      case Keyword.get(opts, :obs_jobs_json) do
        nil -> []
        path -> [{"OBS_JOBS_JSON", path}]
      end

    env = base_env ++ jobs_json_env ++ Enum.into(cache_env, [])

    {out, status} = System.cmd("bash", [@obs_summary_sh], stderr_to_stdout: true, env: env)

    assert status == 0, "obs-summary.sh must exit 0:\n#{out}"

    File.read!(step_summary)
  end

  defp mk_runner_temp! do
    tmp = Path.join(System.tmp_dir!(), "obs_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)
    tmp
  end

  defp extract_ci_job_block(yml, job_id) do
    case Regex.run(~r/#{job_id}:(.*?)(?:\n  [a-z_]+:|\z)/s, yml) do
      [_, block] -> block
      _ -> flunk("Could not extract #{job_id} job block from #{yml}")
    end
  end
end

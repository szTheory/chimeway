defmodule Chimeway.CIReliabilityContractTest do
  use ExUnit.Case, async: true

  @moduledoc false

  @reliability_sh "scripts/ci/reliability-report.sh"
  @run_list_sample "test/fixtures/ci/run_list_sample.json"

  describe "reliability-report.sh script shape" do
    test "bash -n reports no syntax error" do
      {out, status} = System.cmd("bash", ["-n", @reliability_sh], stderr_to_stdout: true)

      assert status == 0, "bash -n #{@reliability_sh} must report no syntax error:\n#{out}"
    end

    test "the script never evals a gh-derived string" do
      non_comment_lines =
        @reliability_sh
        |> File.read!()
        |> String.split("\n")
        |> Enum.reject(&String.starts_with?(String.trim_leading(&1), "#"))
        |> Enum.join("\n")

      refute String.contains?(non_comment_lines, "eval"),
             "#{@reliability_sh} must not eval any gh-derived string — parse with jq only"
    end
  end

  describe "fixture-backed parser (committed run_list_sample.json)" do
    test "classifies the mixed sample: cancelled excluded, 0 real failures, streak meets the bar" do
      {out, status} = run_probe!(runs_json: @run_list_sample)

      assert status == 0,
             "reliability-report.sh must exit 0 on the committed mixed sample:\n#{out}"

      assert out =~ "failures=0 excluded=1 rate=0% streak=5"
    end
  end

  describe "REL-01 boundary: failure_rate threshold (integer arithmetic, exactly 10% FAILS)" do
    test "exactly 10% (5 failures / 50) exits nonzero" do
      conclusions = List.duplicate("success", 45) ++ List.duplicate("failure", 5)
      fixture = build_runs_fixture!(conclusions)

      {out, status} = run_probe!(runs_json: fixture)

      assert status != 0,
             "an exactly-10% failure rate (5/50) must exit nonzero (strict boundary):\n#{out}"

      assert out =~ "rate=10%"
    end

    test "just-under 10% (4 failures / 50) exits 0" do
      conclusions = List.duplicate("success", 46) ++ List.duplicate("failure", 4)
      fixture = build_runs_fixture!(conclusions)

      {out, status} = run_probe!(runs_json: fixture)

      assert status == 0,
             "a strictly-under-10% failure rate (4/50) must exit 0:\n#{out}"
    end
  end

  describe "REL-01 boundary: consecutive-green streak (streak of 4 FAILS, 5 PASSES)" do
    test "streak of exactly 4 exits nonzero (rate held well under 10%)" do
      # 4 greens, then a failure closes the streak; 15 trailing runs keep the
      # rate well under 10% so only the streak dimension can fail the bar.
      conclusions = List.duplicate("success", 4) ++ ["failure"] ++ List.duplicate("success", 15)
      fixture = build_runs_fixture!(conclusions)

      {out, status} = run_probe!(runs_json: fixture)

      assert status != 0, "a streak of exactly 4 must exit nonzero:\n#{out}"
      assert out =~ "streak=4"
    end

    test "streak of exactly 5 exits 0 (rate held well under 10%)" do
      conclusions = List.duplicate("success", 5) ++ ["failure"] ++ List.duplicate("success", 15)
      fixture = build_runs_fixture!(conclusions)

      {out, status} = run_probe!(runs_json: fixture)

      assert status == 0, "a streak of exactly 5 must exit 0:\n#{out}"
      assert out =~ "streak=5"
    end
  end

  describe "REL-01 adjacency: excluded runs never break or extend the streak" do
    test "a cancelled run interleaved between greens is skipped, not counted as a break" do
      # most-recent-first: success, success, cancelled, success, success, success
      conclusions = ["success", "success", "cancelled", "success", "success", "success"]
      fixture = build_runs_fixture!(conclusions)

      {out, status} = run_probe!(runs_json: fixture)

      assert status == 0, "a cancelled run between greens must not break the streak:\n#{out}"
      assert out =~ "streak=5"
      assert out =~ "excluded=1"
      assert out =~ "failures=0"
    end
  end

  describe "secret hygiene" do
    test "rendered summary never leaks a fake token or DATABASE_URL" do
      {out, status} =
        run_probe!(
          runs_json: @run_list_sample,
          extra_env: [
            {"GH_TOKEN", "super-secret-token-value"},
            {"DATABASE_URL", "postgres://user:super-secret-password@localhost/db"}
          ]
        )

      assert status == 0

      refute out =~ "super-secret-token-value"
      refute out =~ "DATABASE_URL"
      refute out =~ "super-secret-password"
    end
  end

  # --- helpers -----------------------------------------------------------

  defp build_runs_fixture!(conclusions) do
    tmp = mk_runner_temp!()
    fixture_path = Path.join(tmp, "runs.json")

    entries =
      conclusions
      |> Enum.with_index()
      |> Enum.map(fn {conclusion, idx} ->
        %{"databaseId" => 90_000_000 - idx, "gate_conclusion" => conclusion}
      end)

    File.write!(fixture_path, Jason.encode!(entries))
    fixture_path
  end

  defp run_probe!(opts) do
    tmp = mk_runner_temp!()
    step_summary = Path.join(tmp, "step-summary.md")
    runs_json = Keyword.fetch!(opts, :runs_json)
    extra_env = Keyword.get(opts, :extra_env, [])

    env =
      [
        {"RUNNER_TEMP", tmp},
        {"GITHUB_STEP_SUMMARY", step_summary},
        {"GITHUB_REPOSITORY", "szTheory/chimeway"},
        {"RELIABILITY_RUNS_JSON", runs_json}
      ] ++ extra_env

    System.cmd("bash", [@reliability_sh], stderr_to_stdout: true, env: env)
  end

  defp mk_runner_temp! do
    tmp = Path.join(System.tmp_dir!(), "reliability_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)
    tmp
  end
end

---
phase: 87-ci-observability-cache-diagnostics
verified: 2026-07-29T00:00:00Z
status: passed
score: 13/13 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 87: CI Observability & Cache Diagnostics Verification Report

**Phase Goal:** Make cache hit/miss, recompile-count, and per-step timing visible in every job summary, and record the pre-optimization baseline — so every later optimization in this milestone is provable by a run-link delta rather than a feeling.
**Verified:** 2026-07-29
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Every build lane's job summary shows a cache hit/miss line for `_build`/`deps` caches via `$GITHUB_STEP_SUMMARY` | ✓ VERIFIED | `scripts/ci/obs-summary.sh` classifies each `CACHE_<id>_HIT/MATCHED/PRIMARY` triple into `EXACT HIT`/`PARTIAL`/`MISS` and appends a `### Cache` table to `$GITHUB_STEP_SUMMARY`. `grep -c "id: cache_main" .github/workflows/ci.yml` = 14 (one per build lane). Contract test `obs-summary.sh cache classification (OBS-01)` (3 tests) passes all three classification branches. Live run 30416472070, job "Lint" (id 90463971778) log confirms the step executed with `CACHE_MAIN_HIT: true` correctly wired from `steps.cache_main.outputs.cache-hit`. |
| 2 | Every build lane's job summary reports a recompiled-file count (deps vs. app split), captured immediately after `deps.get`/`mix compile` | ✓ VERIFIED | `scripts/ci/obs-recompile.sh` runs `mix deps.compile` then `mix compile`, tees to logs, sums `Compiling N files` via `PIPESTATUS`-safe parsing, writes `deps_n app_n` to `$RUNNER_TEMP/obs-recompile.txt`. `grep -c "scripts/ci/obs-recompile.sh" .github/workflows/ci.yml` = 14. Contract test `obs-recompile.sh parser (OBS-02)`: warm log → `0 0`, cold fixture → `260 260` (both pass). Placed before `mix ecto.create --quiet` (or the DB-less lane's real work) in every lane, verified by direct `sed` inspection of `verify_accrue` (replaces its former `mix deps.compile` step) and `verify_sigra` (placed before "Prepare root test database", the lane's only ecto step). |
| 3 | Every lane writes a per-step timing table (step name + duration) to `$GITHUB_STEP_SUMMARY` | ✓ VERIFIED | `scripts/ci/obs-summary.sh` queries `/repos/.../actions/runs/.../jobs` via `gh api --paginate`, renders `\| step \| Ns \|` rows, and degrades to a single `\| _timing unavailable_ \| — \|` row (zero exit, never fails the lane) on any failure or missing `OBS_JOBS_JSON`. Contract tests `obs-summary.sh timing rows (OBS-03)` (2 tests: fixture renders rows; missing jobs JSON degrades gracefully with `status == 0`) both pass. |
| 4 | The pre-optimization baseline (~373–395s wall-clock, 373s `install_golden`, 135s hidden `ecto.create` compile, dead-flat compile across 3 identical-lock runs) is committed with a run link | ✓ VERIFIED | `.planning/CI-PERF-BASELINE.md` exists, contains all four facts verbatim (`373`, `135`, `395`, `dead-flat`) and a `Metric \| Baseline \| Phase 88 after \| Δ` delta-ledger table. Run link `https://github.com/szTheory/chimeway/actions/runs/30410779443` independently confirmed via `gh api repos/szTheory/chimeway/actions/runs/30410779443` — `head_sha: 8ce347e`, branch `main`, event `push`, `conclusion: success`, matching the doc's stated commit/branch. Contract test `OBS-04 baseline (baseline doc)` (4 tests) asserts existence, permalink regex, all four numeric markers, and the delta-ledger column — all pass. |

### Plan-Level Must-Have Truths (supplementary detail)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 5 | Warm-cache compile log renders `0 0`, not blank/error | ✓ VERIFIED | Contract test + direct fixture inspection (`compile_warm.log` has zero `Compiling` lines). |
| 6 | Partial cache restoration (cache-hit≠true, matched-key non-empty) classified `PARTIAL`, distinct from `EXACT HIT`/`MISS` | ✓ VERIFIED | `obs-summary.sh` lines 58-64 implement the three-way branch; contract test "non-empty matched key without exact hit renders PARTIAL" passes. |
| 7 | `obs-recompile.sh` survives `pipefail`+`tee` via `PIPESTATUS`, never aborts on a warm-cache grep miss | ✓ VERIFIED | Script opens `set -uo pipefail` (no `-e`); `${PIPESTATUS[0]}` captured for both `mix` invocations; `count()` helper's grep chain is `|| true` guarded. Confirmed by direct source read and passing warm-log contract test (exit 0). |
| 8 | Summary emits only cache keys, counts, durations, run URL — never secret env values | ✓ VERIFIED | Contract test "rendered summary never leaks raw env or token values" (`gh_token: "super-secret-token-value"` fed in, asserted absent from output) passes. Live run log for the Lint job's "CI observability summary" step shows `GH_TOKEN: ***` (GitHub's own masking) and the script source only ever echoes cache ids/state/keys, deps/app counts, timing rows, and `RUN_URL`. |
| 9 | All 14 build lanes carry a stable cache `id:` and a trailing `if: always()` observability summary step | ✓ VERIFIED | Per-lane Python block-scan confirms `id: cache_main`, `scripts/ci/obs-recompile.sh`, `scripts/ci/obs-summary.sh`, `if: always()` present in all 14 lanes (lint, verify_gates, verify_docs, test, verify_example, verify_runtime_prefix, verify_journeys, verify_mailglass, verify_accrue, verify_inbox, verify_threadline, verify_sigra, verify_admin, install_golden_contract). Step-order scan confirms "CI observability summary" is the literal LAST step in every one of the 14 lanes. |
| 10 | Instrumentation never gates/slows real verify work (plain `mix compile`, trailing `if: always()`, no `needs:` gate) | ✓ VERIFIED | `grep -c "warnings-as-errors" .github/workflows/ci.yml` = 0. Contract test "no build-lane observability step introduces --warnings-as-errors" (parametrized over all 14 lanes) passes. Summary step confirmed last-in-lane (see #9), never referenced by any `needs:`. |
| 11 | Recompile probe replaces the compile hidden inside `mix ecto.create` (explicit `deps.compile`+`compile`, deps/app split) | ✓ VERIFIED | Direct source inspection: probe step placed immediately before `mix ecto.create --quiet` in all DB lanes; `verify_accrue`'s prior bare `mix deps.compile` step is replaced in place (comment preserved); `verify_sigra`'s probe placed before its only DB step ("Prepare root test database"). |
| 12 | `install_golden_contract`'s observability steps mirror the lane's `if: steps.detect.outputs.run == 'true'` guard | ✓ VERIFIED | Direct source inspection: `id: cache_main` cache step, the obs-recompile step, and the trailing summary step all carry `if: steps.detect.outputs.run == 'true'` (summary as `if: always() && steps.detect.outputs.run == 'true'`). Contract test "install_golden_contract obs-summary step also gates on steps.detect.outputs.run" passes. |
| 13 | The `test` lane's two OTP matrix legs (26, 27) each write their own job summary without clobbering | ✓ VERIFIED | Single job definition, GitHub Actions matrix semantics guarantee one job instance (and one `$GITHUB_STEP_SUMMARY`) per leg. Live run 30416472070 job list independently confirms two separate jobs — "Test (Elixir 1.19 / OTP 26)" and "Test (Elixir 1.19 / OTP 27)" — both `conclusion: success`. Human checkpoint (87-03 Task 2) explicitly confirmed no clobbering, approved 2026-07-29. |

**Score:** 13/13 truths verified (0 present-but-behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/ci/obs-recompile.sh` | Recompile probe, `set -uo pipefail`, executable | ✓ VERIFIED | `bash -n` clean, executable, matches full spec (env contract, `OBS_SKIP_COMPILE`, `PIPESTATUS` capture) |
| `scripts/ci/obs-summary.sh` | Cache/recompile/timing renderer, `set -euo pipefail`, executable | ✓ VERIFIED | `bash -n` clean, executable, single consolidated write to `$GITHUB_STEP_SUMMARY` |
| `test/chimeway/ci_observability_contract_test.exs` | ExUnit contract covering both scripts + all 14 lanes + OBS-04 baseline | ✓ VERIFIED | 328 lines, `mix test` → 31 tests, 0 failures |
| `test/fixtures/ci/compile_cold.log`, `compile_warm.log`, `jobs_api_sample.json` | Offline parser fixtures | ✓ VERIFIED | All three present, well-formed, drive the passing contract-test assertions |
| `.github/workflows/ci.yml` | All 14 build lanes instrumented | ✓ VERIFIED | `grep -c "id: cache_main"` = 14, `grep -c "scripts/ci/obs-summary.sh"` = 14, `grep -c "scripts/ci/obs-recompile.sh"` = 14, YAML parses valid, `mix format --check-formatted` clean |
| `.planning/CI-PERF-BASELINE.md` | Baseline doc with permalink + 4 facts + delta ledger | ✓ VERIFIED | Present, matches `actions/runs/\d+`, all four facts present, delta-ledger table present |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `ci.yml` cache steps | `obs-summary.sh` | `CACHE_<id>_HIT/MATCHED/PRIMARY` env triples sourced from `steps.<id>.outputs.*` | ✓ WIRED | Confirmed per-lane in source; live-run log shows `CACHE_MAIN_HIT: true` correctly populated for the Lint job |
| `obs-recompile.sh` | `obs-summary.sh` | `$RUNNER_TEMP/obs-recompile.txt` (`deps_n app_n`) | ✓ WIRED | `obs-summary.sh` line 77-83 reads the file with a `0 0` default when absent |
| `ci.yml` build lanes | `obs-recompile.sh`/`obs-summary.sh` | direct `run:` invocation as instrumented steps | ✓ WIRED | 14/14 lanes, confirmed by grep counts and per-lane block scan |
| `.planning/CI-PERF-BASELINE.md` | pre-optimization run | `actions/runs/30410779443` permalink | ✓ WIRED | Independently resolved via `gh api` — real run, `head_sha 8ce347e`, `main`, `push`, `success`, matching the doc's `**Commit:**` field |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Contract test suite green | `mix test test/chimeway/ci_observability_contract_test.exs` | 31 tests, 0 failures | ✓ PASS |
| `obs-recompile.sh` warm→`0 0`, cold→`260 260` | contract test | both pass | ✓ PASS |
| `obs-summary.sh` cache classification (HIT/PARTIAL/MISS) | contract test | all 3 pass | ✓ PASS |
| `obs-summary.sh` timing rows + graceful fallback | contract test | both pass | ✓ PASS |
| No `--warnings-as-errors` introduced anywhere | `grep -c warnings-as-errors ci.yml` | 0 | ✓ PASS |
| YAML validity of `ci.yml` after all edits | `python3 -c "yaml.safe_load(...)"` | valid | ✓ PASS |
| `mix format --check-formatted` on touched files | direct run | clean | ✓ PASS |
| Live run 30416472070 all-green | `gh api .../runs/30416472070` + `.../jobs` | 16/16 jobs `success` | ✓ PASS |
| Live "CI observability summary" step executed correctly on Lint job | `gh run view --log --job 90463971778` | `CACHE_MAIN_HIT: true`, `GH_TOKEN: ***` (masked), step completed | ✓ PASS |
| Baseline run 30410779443 resolves to a real pre-Phase-87 run | `gh api .../runs/30410779443` | `head_sha 8ce347e`, `main`, `push`, `success` | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| OBS-01 | 87-01, 87-02 | Maintainer sees per-lane cache hit/miss in job summary for every build lane | ✓ SATISFIED | `obs-summary.sh` cache classification + 14/14 lane wiring, contract tests pass, REQUIREMENTS.md marked `[x]` |
| OBS-02 | 87-01, 87-02 | Maintainer sees recompiled-file count (deps+app) exposed after `deps.get` | ✓ SATISFIED | `obs-recompile.sh` + 14/14 lane wiring, contract tests pass (warm `0 0`, cold `260 260`), REQUIREMENTS.md marked `[x]` |
| OBS-03 | 87-01, 87-02 | Maintainer sees per-step timing summary written to `$GITHUB_STEP_SUMMARY` | ✓ SATISFIED | `obs-summary.sh` REST `/jobs` timing renderer + graceful fallback, contract tests pass, REQUIREMENTS.md marked `[x]` |
| OBS-04 | 87-03 | Pre-optimization baseline recorded with run link for before/after deltas | ✓ SATISFIED | `.planning/CI-PERF-BASELINE.md` committed, run link independently resolved and confirmed accurate, contract test asserts content, REQUIREMENTS.md marked `[x]` |

No orphaned requirements — REQUIREMENTS.md maps only OBS-01..04 to Phase 87, and all four appear in plan frontmatter `requirements:` fields.

### Anti-Patterns Found

None. Scanned `scripts/ci/obs-recompile.sh`, `scripts/ci/obs-summary.sh`, `test/chimeway/ci_observability_contract_test.exs`, `.planning/CI-PERF-BASELINE.md`, and `.github/workflows/ci.yml` for `TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER` and placeholder-language patterns — zero matches.

### Human Verification Required

None outstanding. The phase's own `checkpoint:human-verify` (87-03 Task 2) was completed and approved by the user during execution (documented in 87-03-SUMMARY.md, approved 2026-07-29), and this verification independently corroborated its claims via live GitHub API queries against run `30416472070` (all 16 jobs green; the Lint job's "CI observability summary" step confirmed to have executed with correctly wired cache-output env and properly masked secrets) and run `30410779443` (the baseline run, confirmed to be a real, successful, pre-Phase-87 `main` push at commit `8ce347e`).

### Gaps Summary

No gaps found. All 4 ROADMAP Success Criteria and all 9 plan-level supplementary must-haves are verified against the codebase: the shared `obs-recompile.sh`/`obs-summary.sh` machinery is real (not stubbed), wired into all 14 build lanes (including the five special lanes with lane-specific handling — accrue's `deps.compile` replacement, sigra's pre-DB-step ordering, admin's four-cache summary, install_golden_contract's conditional guard, and the test lane's independent-per-leg matrix summaries), proven offline by a 31-test ExUnit contract suite (0 failures), and proven live by a green push-to-main CI run whose job logs this verification independently inspected. The OBS-04 baseline doc is committed with a real, independently-resolved run permalink, the four measured facts, and a delta-ledger table ready for Phase 88 to append to.

---

*Verified: 2026-07-29*
*Verifier: Claude (gsd-verifier)*

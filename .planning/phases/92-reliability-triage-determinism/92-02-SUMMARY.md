---
phase: 92-reliability-triage-determinism
plan: 02
subsystem: infra
tags: [ci, gh-cli, jq, bash, exunit, reliability-measurement]

requires:
  - phase: 92-reliability-triage-determinism
    provides: 92-01 EnvHelper capture/restore pattern precedent (no direct dependency, same phase)
provides:
  - scripts/ci/reliability-report.sh — re-runnable push-on-main ci-gate reliability classifier (REL-01)
  - test/fixtures/ci/run_list_sample.json — committed fixture for the parser contract test
  - test/chimeway/ci_reliability_contract_test.exs — boundary + adjacency + secret-hygiene proof
  - .planning/CI-RELIABILITY-REPORT.md — committed live snapshot (failures=2 excluded=0 rate=6% streak=10)
affects: [92-03-nightly-seed-zero-and-backlog-closure]

tech-stack:
  added: []
  patterns:
    - "gh run list/gh run view + jq classification mirroring obs-summary.sh's gh/jq/$GITHUB_STEP_SUMMARY shape"
    - "RELIABILITY_RUNS_JSON test-hook env var short-circuits live gh calls for offline fixture-backed testing (obs-summary OBS_JOBS_JSON precedent)"
    - "Strict integer-arithmetic threshold comparison (real_failures*10 vs denominator) to avoid float-rounding boundary drift"

key-files:
  created:
    - scripts/ci/reliability-report.sh
    - test/fixtures/ci/run_list_sample.json
    - test/chimeway/ci_reliability_contract_test.exs
    - .planning/CI-RELIABILITY-REPORT.md

key-decisions:
  - "[92-02]: Classification is strictly the ci-gate JOB conclusion (success/failure/cancelled/skipped) on event=push, branch=main runs — never the run-level conclusion, never workflow_dispatch/release-please-branch/nightly-dispatch runs."
  - "[92-02]: Streak counts consecutive success scanning most-recent-first, skipping excluded (cancelled/skipped) runs without breaking or extending the streak, and stops at the first real failure."
  - "[92-02]: Pass bar uses integer arithmetic only (real_failures*10 >= denominator fails; exactly 10% fails, streak of exactly 4 fails, exactly 5 passes) — no float rounding can shift the boundary."
  - "[92-02]: Live measurement (30 push-on-main runs) surfaced a documented counting nuance: run 30502247481's overall run conclusion is 'cancelled' (superseded), but its ci-gate JOB conclusion resolves to 'failure' — per REL-01's job-level-only population definition this correctly counts as a real failure in the strict classification the script implements, and is called out explicitly in CI-RELIABILITY-REPORT.md so a future re-run isn't misread as a script bug."

requirements-completed: [REL-01]

coverage:
  - id: D1
    description: "scripts/ci/reliability-report.sh classifies push-on-main ci-gate JOB conclusions (success/failure/cancelled|skipped) and computes failure_rate + most-recent-first consecutive-green streak"
    requirement: "REL-01"
    verification:
      - kind: unit
        ref: "test/chimeway/ci_reliability_contract_test.exs#classifies the mixed sample: cancelled excluded, 0 real failures, streak meets the bar"
        status: pass
    human_judgment: false
  - id: D2
    description: "Strict boundary: exactly-10% failure rate (5/50) exits nonzero; strictly-under-10% (4/50) exits 0 — integer arithmetic, no float rounding"
    requirement: "REL-01"
    verification:
      - kind: unit
        ref: "test/chimeway/ci_reliability_contract_test.exs#exactly 10% (5 failures / 50) exits nonzero"
        status: pass
      - kind: unit
        ref: "test/chimeway/ci_reliability_contract_test.exs#just-under 10% (4 failures / 50) exits 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "Streak boundary: exactly 4 consecutive greens exits nonzero, exactly 5 exits 0"
    requirement: "REL-01"
    verification:
      - kind: unit
        ref: "test/chimeway/ci_reliability_contract_test.exs#streak of exactly 4 exits nonzero (rate held well under 10%)"
        status: pass
      - kind: unit
        ref: "test/chimeway/ci_reliability_contract_test.exs#streak of exactly 5 exits 0 (rate held well under 10%)"
        status: pass
    human_judgment: false
  - id: D4
    description: "A cancelled run interleaved between greens is skipped from the streak, not counted as a break, and excluded from the denominator"
    requirement: "REL-01"
    verification:
      - kind: unit
        ref: "test/chimeway/ci_reliability_contract_test.exs#a cancelled run interleaved between greens is skipped, not counted as a break"
        status: pass
    human_judgment: false
  - id: D5
    description: "Rendered output/summary never leaks GH_TOKEN or DATABASE_URL values"
    requirement: "REL-01"
    verification:
      - kind: unit
        ref: "test/chimeway/ci_reliability_contract_test.exs#rendered summary never leaks a fake token or DATABASE_URL"
        status: pass
    human_judgment: false
  - id: D6
    description: "scripts/ci/reliability-report.sh has no syntax error and never evals a gh-derived string"
    requirement: "REL-01"
    verification:
      - kind: unit
        ref: "test/chimeway/ci_reliability_contract_test.exs#bash -n reports no syntax error"
        status: pass
      - kind: unit
        ref: "test/chimeway/ci_reliability_contract_test.exs#the script never evals a gh-derived string"
        status: pass
    human_judgment: false
  - id: D7
    description: "Live measurement against the last 30 push-on-main runs meets the reliability bar (<10% failure, >=5 consecutive green) and is committed with permalinks"
    requirement: "REL-01"
    verification:
      - kind: integration
        ref: "scripts/ci/reliability-report.sh live run (2026-07-30): failures=2 excluded=0 rate=6% streak=10, exit 0 — recorded in .planning/CI-RELIABILITY-REPORT.md"
        status: pass
    human_judgment: false

duration: 15 min
completed: 2026-07-30
status: complete
---

# Phase 92 Plan 02: CI Reliability Measurement Summary

**Re-runnable `scripts/ci/reliability-report.sh` classifies push-on-main `ci-gate` JOB conclusions (11 boundary-tested guarantees) and proves the current bar met: 6% failure rate, 10-run consecutive-green streak.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-07-30T18:20:00Z
- **Completed:** 2026-07-30T18:35:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- `scripts/ci/reliability-report.sh` classifies `ci-gate` JOB conclusions on `event=push, branch=main` runs (success/failure/cancelled|skipped), computing `failure_rate` and a most-recent-first consecutive-green `streak` with strict integer-arithmetic boundaries (no float rounding can shift the 10%/streak-5 bar).
- A committed fixture (`test/fixtures/ci/run_list_sample.json`) and offline-testable `RELIABILITY_RUNS_JSON` env-var seam (mirroring `obs-summary.sh`'s `OBS_JOBS_JSON` precedent) let the parser run without live `gh` calls.
- `test/chimeway/ci_reliability_contract_test.exs` (9 tests) proves the exact boundary edges: exactly-10% failure rate fails, strictly-under passes; streak of 4 fails, 5 passes; a cancelled run interleaved between greens is skipped (not a break); secret hygiene (no token/`DATABASE_URL` leakage); no syntax error; no `eval` of gh-derived strings.
- Ran the script live against the last 30 push-on-main runs and committed the durable snapshot to `.planning/CI-RELIABILITY-REPORT.md`: `failures=2 excluded=0 rate=6% streak=10` — bar met (exit 0), with every classified run's `actions/runs/<id>` permalink recorded so the signal survives GitHub log retention.
- Documented a real counting nuance discovered during the live run: run `30502247481`'s overall workflow-run conclusion is `cancelled` (superseded by a subsequent push), but its `ci-gate` JOB conclusion resolves to `failure` (GitHub reports a dependent aggregate job as `failure`, not `cancelled`, when its `needs` were cancelled). Per REL-01's job-level-only population definition this correctly counts as a real failure — recorded explicitly in the doc so it isn't misread as a script defect on a future re-run.

## Task Commits

Each task was committed atomically:

1. **Task 1: reliability-report.sh + fixture + fixture-backed parser contract test** - `596361f` (feat)
2. **Task 2: measure live main history and commit the durable snapshot** - `5bcb05f` (docs)

## Files Created/Modified

- `scripts/ci/reliability-report.sh` - Classifies push-on-main `ci-gate` JOB conclusions, computes rate/streak, emits a whitelist-only table + summary to stdout and `$GITHUB_STEP_SUMMARY`, exits nonzero when the bar is missed.
- `test/fixtures/ci/run_list_sample.json` - Canonical mixed fixture (5 success + 1 cancelled) used by the parser contract test's happy-path assertion.
- `test/chimeway/ci_reliability_contract_test.exs` - 9 tests: fixture-backed classification, rate/streak boundaries, cancelled-run adjacency, secret hygiene, syntax/`eval` guards.
- `.planning/CI-RELIABILITY-REPORT.md` - Committed live snapshot: population definition, per-run permalinks, measured `failures=2 excluded=0 rate=6% streak=10`, and the documented counting-nuance note for run `30502247481`.

## Decisions Made

- Classification strictly follows the `ci-gate` JOB's own conclusion field (never the overall run conclusion), matching the plan's must-haves verbatim — even when a live run showed the two concepts diverge (see the `30502247481` note above).
- Streak logic skips excluded runs without breaking or extending the count, verified with an explicit interleaved-cancelled-run test.
- Threshold comparisons use only integer arithmetic (`real_failures * 10 >= denominator`) so the exactly-10%/streak-of-4 boundaries are provably strict, never subject to floating-point rounding.

## Deviations from Plan

None - plan executed exactly as written. The live measurement surfaced a real-world classification nuance (run-level `cancelled` vs. job-level `failure` on run `30502247481`), but this is the script correctly implementing the plan's specified job-level classification rule, not a deviation from it — documented in the SUMMARY and the committed report for transparency.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

None. The live `gh run view` loop (30 sequential API calls) took longer than the default 120s shell timeout and was moved to background execution by the harness; it completed successfully with the expected output.

## User Setup Required

None - no external service configuration required. Live measurement used the existing `gh auth status`-authenticated session (already scoped with `repo`/`actions:read`-equivalent permissions).

## Next Phase Readiness

Ready for 92-03. REL-01 is satisfied: the measured completed-run failure rate on `main` `ci-gate` is 6% (< 10% bar) with a 10-run consecutive-green streak (>= 5 bar), proven by a re-runnable, fixture-tested script and a committed snapshot with permalinks. `mix ci.test` (full default suite, `--warnings-as-errors`) is green: 1253 tests, 0 failures.

---

## Self-Check: PASSED

- Found `scripts/ci/reliability-report.sh` (executable, `bash -n` clean, no `eval`).
- Found `test/fixtures/ci/run_list_sample.json`.
- Found `test/chimeway/ci_reliability_contract_test.exs` — `MIX_ENV=test mix test test/chimeway/ci_reliability_contract_test.exs --warnings-as-errors` → 9 tests, 0 failures.
- Found `.planning/CI-RELIABILITY-REPORT.md` with a real `actions/runs/<digits>` permalink and the measured `streak`/`rate` figures (`grep -Eq 'actions/runs/[0-9]+'` + `grep -Eiq 'streak'` both matched — `DOC_OK`).
- Found task commits `596361f` and `5bcb05f` in `git log --oneline`.
- `scripts/ci/reliability-report.sh` exits 0 on live `main` history (verified this run).
- `mix ci.test` (full default suite, `--warnings-as-errors`): 1253 tests, 0 failures.
- No tracked file deletions were introduced by either task commit.

---
*Phase: 92-reliability-triage-determinism*
*Completed: 2026-07-30*

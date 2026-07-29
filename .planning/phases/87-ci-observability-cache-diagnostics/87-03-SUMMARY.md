---
phase: 87-ci-observability-cache-diagnostics
plan: 03
subsystem: infra
tags: [github-actions, ci, observability, baseline, exunit]

requires:
  - phase: 87-ci-observability-cache-diagnostics
    provides: 87-02 fan-out of cache/recompile/timing observability to all 14 build lanes
provides:
  - "Committed pre-optimization CI performance baseline (.planning/CI-PERF-BASELINE.md) with a durable actions/runs/ permalink, the four measured baseline facts, and a delta-ledger table for Phase 88+ to append after-values to."
  - "OBS-04 contract assertion in ci_observability_contract_test.exs enforcing the baseline doc's existence, permalink shape, and numeric content."
  - "Human-verified live-render confirmation that all 14 instrumented build lanes visibly emit their Cache/Recompile/Step-timing job-summary tables on a real push-to-main CI run."
affects: [phase-88-cache-correctness-fix (cites this baseline's rows for its before/after delta)]

tech-stack:
  added: []
  patterns:
    - "Baseline doc header carries Recorded/Commit/Run fields; the Run permalink is the pre-Phase-87 main head run (8ce347e), fixed for the milestone and never overwritten by later phases — those append new rows/links, not new headers."
    - "Delta-ledger table (Metric | Baseline | Phase 88 after | Δ) is the single anchor every later v1.16 phase appends its proof-of-win row to."

key-files:
  created:
    - .planning/CI-PERF-BASELINE.md
    - .planning/phases/87-ci-observability-cache-diagnostics/87-03-SUMMARY.md
  modified:
    - test/chimeway/ci_observability_contract_test.exs

key-decisions:
  - "[87-03]: Baseline run permalink is the pre-Phase-87 main run at commit 8ce347e (https://github.com/szTheory/chimeway/actions/runs/30410779443), obtained via `gh run list` and never re-derived — Task 1 committed the already-measured four facts verbatim, no new measurement taken."
  - "[87-03]: The live-render human-verify checkpoint (Task 2) used the POST-instrumentation confirmation run (30416472070, Phase 87 push 8ce347e..2d9af89, all 16 jobs green) purely to prove the observability tables render — that run's link is NOT written into CI-PERF-BASELINE.md, which continues to point at the fixed pre-optimization baseline run. Keeping these two run links distinct preserves the baseline as an unmoving pre-optimization reference point."

requirements-completed: [OBS-04]

coverage:
  - id: D1
    description: "CI-PERF-BASELINE.md is committed with a durable actions/runs/ permalink, the four baseline facts (373s install_golden, ~135s hidden ecto.create compile, ~373-395s wall-clock, dead-flat compile across 3 identical-lock runs), and a delta-ledger table with a Phase 88 after column"
    requirement: "OBS-04"
    verification:
      - kind: unit
        ref: "test/chimeway/ci_observability_contract_test.exs#OBS-04 baseline (baseline doc)"
        status: pass
      - kind: other
        ref: "grep -Eq 'actions/runs/[0-9]+' .planning/CI-PERF-BASELINE.md"
        status: pass
    human_judgment: false
  - id: D2
    description: "On a live push-to-main run with the Phase 87 instrumentation active, every sampled build lane's job summary visibly renders the Cache/Recompile/Step-timing tables, and the two test OTP legs (26, 27) each render their own summary without clobbering"
    requirement: "OBS-04"
    verification:
      - kind: manual_procedural
        ref: "Human-verified CI run https://github.com/szTheory/chimeway/actions/runs/30416472070 (Phase 87 push 8ce347e..2d9af89) — all 16 jobs green; lint, test (OTP 26 + OTP 27 as independent summaries), verify_example, and verify_admin job Summary pages confirmed to render the Cache/Recompile/Step-timing tables"
        status: pass
    human_judgment: true
    rationale: "Job-summary rendering on a live GitHub Actions run cannot be asserted by an offline contract test (no live runner in this harness); this deliverable was the explicit `type=\"checkpoint:human-verify\" gate=\"blocking\"` Task 2 of this plan, approved by the user 2026-07-29."

duration: 6min
completed: 2026-07-29
status: complete
---

# Phase 87 Plan 03: CI Performance Baseline + Live Render Verification Summary

**Committed the durable pre-optimization CI baseline (373s install_golden, ~135s hidden ecto.create compile, ~373-395s wall-clock, dead-flat dep-cache across 3 identical-lock runs) with a delta-ledger table and an `actions/runs/30410779443` permalink, asserted it by contract test, and got human confirmation that all 14 instrumented build lanes render their observability tables on a real push-to-main run.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-29T02:07:56Z
- **Completed:** 2026-07-29T02:13:26Z (Task 1); checkpoint approved 2026-07-29 (Task 2)
- **Tasks:** 2 (1 auto + 1 checkpoint:human-verify)
- **Files modified:** 2 created/modified in Task 1; 0 additional file changes in Task 2 (verification-only, no baseline-link edit needed)

## Accomplishments

- Created `.planning/CI-PERF-BASELINE.md`: header (`Recorded`/`Commit`/`Run`), the four already-measured pre-optimization baseline facts, a `Metric | Baseline | Phase 88 after | Δ` delta-ledger table, and a "How later phases use this delta ledger" note anchoring Phase 88+ appends.
- Extended `test/chimeway/ci_observability_contract_test.exs` with an `OBS-04 baseline` describe block asserting the doc exists, matches `actions/runs/\d+`, and contains all four baseline markers (373, 135, dead-flat, 395/wall-clock).
- Obtained and verified the human-verify checkpoint (Task 2): Phase 87 (8ce347e..2d9af89) pushed to `main`, CI run `30416472070` executed with the full instrumentation active, all 16 jobs (14 build lanes + pr-gate + ci-gate) green. User visually confirmed on the run's Summary page that Cache/Recompile/Step-timing tables render per job across a representative sample (lint, test OTP 26, test OTP 27, verify_example, verify_admin), with the two `test` OTP legs rendering independent, non-clobbering summaries.
- Confirmed the baseline-of-record run link in `CI-PERF-BASELINE.md` (`actions/runs/30410779443`, the PRE-optimization run at `main` head `8ce347e`) remains correct and unchanged — no alternate URL was supplied by the user, so per plan step 4 the existing link stands as final.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create the baseline doc + OBS-04 contract assertion** - `2d9af89` (feat)
2. **Task 2: Human-verify the live render + finalize the baseline run link** - checkpoint approved by user, no additional file changes (baseline link confirmed correct as committed in Task 1); no separate task commit required.

**Plan metadata:** committed alongside this SUMMARY (see final metadata commit below).

## Files Created/Modified

- `.planning/CI-PERF-BASELINE.md` - The committed OBS-04 baseline doc: four pre-optimization facts, delta-ledger table, and durable `actions/runs/30410779443` permalink.
- `test/chimeway/ci_observability_contract_test.exs` - Extended with the `OBS-04 baseline` describe block (file existence, permalink regex, four numeric markers).
- `.planning/phases/87-ci-observability-cache-diagnostics/87-03-SUMMARY.md` - This summary.

## Decisions Made

- Baseline run permalink is the pre-Phase-87 `main` run at commit `8ce347e` (`https://github.com/szTheory/chimeway/actions/runs/30410779443`), resolved via `gh run list` — a real numeric run id, never a placeholder.
- The Task 2 live-render confirmation used a separate, POST-instrumentation CI run (`30416472070`) purely to prove the observability tables render on a live runner. That run's link was deliberately NOT written into `CI-PERF-BASELINE.md` — the baseline doc's `Run:` field stays fixed at the pre-optimization reference point for the whole v1.16 milestone, per the plan's explicit "Do not overwrite... those are the fixed pre-optimization reference point" instruction.

## Deviations from Plan

None - plan executed exactly as written. The checkpoint's "if Task 1 left the link pending, provide the correct baseline run URL now" branch was not needed since Task 1 had already resolved a real numeric run id.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

OBS-04 is satisfied — all four Phase 87 observability requirements (OBS-01..04) are now complete. Phase 88 (CACHE-05 cache-correctness fix) can cite `.planning/CI-PERF-BASELINE.md`'s delta-ledger rows and append its own after-values/Δ sourced from the now-proven-live instrumentation. No blockers.

## Known Stubs

None. Stub-pattern scan of `.planning/CI-PERF-BASELINE.md` and the extended contract test found no placeholder/TODO/FIXME content — both baseline facts and run link are real, committed values.

## Self-Check: PASSED

- FOUND: `.planning/CI-PERF-BASELINE.md` (contains `actions/runs/30410779443` and all four baseline facts).
- FOUND: commit `2d9af89` in `git log --oneline --all`.
- PASS: `mix test test/chimeway/ci_observability_contract_test.exs` — 31 tests, 0 failures.
- Human-verify checkpoint evidence (CI run `30416472070`, all 16 jobs green, tables rendered) recorded above per the resume instructions; not independently re-verifiable offline by this continuation agent, consistent with the checkpoint's `human_judgment: true` classification.

---
*Phase: 87-ci-observability-cache-diagnostics*
*Completed: 2026-07-29*

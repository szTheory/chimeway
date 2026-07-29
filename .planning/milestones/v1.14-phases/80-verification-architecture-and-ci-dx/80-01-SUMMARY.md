---
phase: 80-verification-architecture-and-ci-dx
plan: 01
subsystem: ci-dx
tags: [github-actions, ci, release-gate, contract-test, topology]
requires:
  - phase: 78-release-and-package-truth
    provides: release_gate_contract_test.exs truth anchor + ci-gate 13-lane baseline
provides:
  - Fast always-on pr-gate aggregate for pull_request events (CI-01)
  - Push/dispatch-only ci-gate aggregating 14 lanes incl. install_golden_contract (CI-02)
  - Anti-pending topology (event guards, no path filters on required-feeding lanes) (CI-03)
  - Contract-test lock for the two-aggregate topology
affects:
  - phase-80-plan-02-caching
  - phase-80-plan-03-scripts-extraction
  - phase-80-plan-04-docs-and-branch-protection
tech-stack:
  added: []
  patterns:
    - Two-aggregate CI topology (pr-gate for PRs, ci-gate for release)
    - Job-level EVENT guard (github.event_name != 'pull_request') instead of paths filters
    - Detect-step pattern preserved so PR-exempt lanes fold pending-safe into ci-gate
key-files:
  created:
    - .planning/phases/80-verification-architecture-and-ci-dx/80-01-SUMMARY.md
  modified:
    - .github/workflows/ci.yml
    - test/chimeway/release_gate_contract_test.exs
decisions:
  - "[80-01]: pr-gate placed before verify_example so the contract block extractor bounds it via the next underscore-named job"
  - "[80-01]: install_golden_contract is both PR-exempt (D-04) and folded into ci-gate needs (D-05); detect-step pattern kept for pending-safety (D-07)"
  - "[80-01]: Heavy lanes use event guards, never paths filters, to avoid the required-check pending trap (CI-03)"
metrics:
  duration: 4 min
  completed: 2026-07-03
  tasks: 3
  files_modified: 2
requirements-completed: [CI-01, CI-02, CI-03]
status: complete
---

# Phase 80 Plan 01: Verification Architecture — Two-Aggregate CI Topology Summary

**Restructured `ci.yml` into a fast always-on `pr-gate` for PRs plus a push/dispatch-only `ci-gate` that now aggregates 14 lanes (including `install_golden_contract`), with the new topology locked by `release_gate_contract_test.exs`.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-07-03T16:18Z
- **Completed:** 2026-07-03T16:23Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- Added a `pr-gate` aggregate job (`name: pr-gate`, `if: always()`, inline `needs: [lint, test, verify_gates, verify_docs]`) placed immediately after `test:` and before `verify_example:` so the contract block extractor bounds it correctly. Its step mirrors the `ci-gate` aggregate shape (per-lane result env vars, `set -euo pipefail`, bash loop failing on any non-`success`). No event guard and no path filter (CI-01).
- Event-guarded the nine heavy lanes (`verify_example`, `verify_runtime_prefix`, `verify_journeys`, `verify_mailglass`, `verify_accrue`, `verify_inbox`, `verify_threadline`, `verify_sigra`, `verify_admin`) plus `install_golden_contract` off `pull_request` with `if: github.event_name != 'pull_request'` (ten job-level guards) (D-04).
- Preserved `install_golden_contract`'s detect step and step-level `if: steps.detect.outputs.run == 'true'` conditions so it reports `success` (not `skipped`) on push/dispatch, keeping the ci-gate fold pending-safe (D-05/D-07).
- Hardened `ci-gate` to `if: always() && github.event_name != 'pull_request'` (push/dispatch-only), kept its literal `name: ci-gate` and inline `needs` bracket form, folded `install_golden_contract` into `needs` (14 lanes), and added `INSTALL_GOLDEN` to both the step env block and the required-lane loop (CI-02, D-03, D-05).
- Extended the release-gate contract: `@ci_gate_lanes` → 14 lanes, added `@pr_gate_lanes`, updated the lane-count test to 14, inverted the install_golden assertion to `assert "install_golden_contract" in needs`, and added new tests + an `extract_pr_gate_needs` helper for pr-gate needs, no-path-filter, ci-gate guard/name, and install_golden PR-exemption + detect markers.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add pr-gate + event-guard heavy lanes (incl. install_golden_contract)** — `68bc275` (feat)
2. **Task 2: Harden ci-gate — event guard + fold install_golden_contract into needs** — `87a4f48` (feat)
3. **Task 3: Lock the new topology in release_gate_contract_test.exs** — `05810bd` (test)

## Files Created/Modified

- `.github/workflows/ci.yml` — new `pr-gate` job; ten job-level event guards; `ci-gate` guarded push/dispatch-only and folding `install_golden_contract` into needs/env/loop.
- `test/chimeway/release_gate_contract_test.exs` — 14-lane `@ci_gate_lanes`, `@pr_gate_lanes`, inverted install_golden needs assertion, new pr-gate / no-path-filter / ci-gate-guard / install_golden PR-exemption tests, `extract_pr_gate_needs` helper.
- `.planning/phases/80-verification-architecture-and-ci-dx/80-01-SUMMARY.md` — this summary.

## Decisions Made

- Placed `pr-gate` before `verify_example` (not adjacent to `ci-gate`) so the `extract_ci_job_block` boundary regex (`\n  [a-z_]+:`) bounds the hyphenated pr-gate job via the next underscore-named job.
- Treated D-04 (which event install_golden runs on) and D-05/D-07 (how it stays pending-safe when folded) as simultaneously satisfied, not conflicting.
- Used job-level EVENT guards for all heavy lanes rather than `paths:` filters, eliminating the required-check pending trap.

## Verification

- PASS: Task 1 automated — `awk` confirms `pr-gate` block carries `needs: [lint, test, verify_gates, verify_docs]`; event-guard count = 10 (≥10).
- PASS: Task 2 automated — `ci-gate` carries `if: always() && github.event_name != 'pull_request'`; inline `needs:` contains `install_golden_contract`; `INSTALL_GOLDEN` present.
- PASS: `python3 yaml.safe_load` parses `ci.yml` after each task.
- PASS: `mix ci.verify_gates` — 510 tests, 0 failures (runs doc_contract_test + release_gate_contract_test).
- PASS: `mix format` on the contract test.
- PASS: No changes to `release.yml`, `publish-hex.yml`, or `release-pr-automerge.yml` (scope boundary held).

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed.

## Threat Mitigations Applied

- T-80-01 (ci-gate strictness): install_golden_contract folded into needs; contract asserts 14 lanes and each lane present.
- T-80-02 (pending trap): pr-gate always runs on PRs and reports a conclusion; contract asserts pr-gate exists with the fast subset.
- T-80-03 (path filter on required-feeding lane): contract asserts the four pr-gate lanes carry no `paths:`/`paths-ignore:`.
- T-80-04 (untrusted PR reaching release matrix): ci-gate and heavy lanes event-guarded off pull_request; release JS untouched.

## Known Stubs

None. Stub-pattern scan found no placeholder/TODO/FIXME or runtime/UI stub content in the modified files.

## User Setup Required

None for this plan. Note: the D-08 branch-protection required-check swap (from `ci-gate` to `pr-gate` on PRs) is a GitHub settings change documented in Plan 04, not applied here.

## Next Phase Readiness

Ready for Plan 02 (caching). The two-aggregate topology is in place and contract-locked; caching, scripts extraction (Plan 03), and docs/branch-protection (Plan 04) build on it.

## Self-Check: PASSED

- Found modified file: `.github/workflows/ci.yml`.
- Found modified file: `test/chimeway/release_gate_contract_test.exs`.
- Found task commits: `68bc275`, `87a4f48`, `05810bd`.
- `mix ci.verify_gates` green (510 tests, 0 failures).
- No release/publish/automerge workflow modified.

---
*Phase: 80-verification-architecture-and-ci-dx*
*Completed: 2026-07-03*

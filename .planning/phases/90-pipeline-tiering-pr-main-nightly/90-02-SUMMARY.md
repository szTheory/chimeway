---
phase: 90-pipeline-tiering-pr-main-nightly
plan: 02
subsystem: ci
tags: [ci, github-actions, tiering, verify_admin, ci-gate, playwright]
requires:
  - phase: 90-pipeline-tiering-pr-main-nightly
    provides: 90-01 resolve_tiers job with run_nightly / otp_matrix outputs
provides:
  - verify_admin gated on the nightly tier (needs.resolve_tiers.outputs.run_nightly == 'true')
  - ci-gate needs-list + aggregate-gate.sh args reduced to 13 required lanes (verify_admin removed)
  - release_gate_contract_test.exs @ci_gate_lanes = 13 with renamed lane-count contract test
affects:
  - phase-90-plan-03 (nightly_cold_build / test_floor_1_17 / nightly-gate build on this tier gating)
tech-stack:
  added: []
  patterns:
    - Heavy non-matrix lanes gate on resolve_tiers.outputs.run_nightly, not on a bare pull_request exclusion
    - A skipped nightly-only lane must be absent from ci-gate's needs-list and aggregate-gate.sh args (Pitfall 1)
key-files:
  created:
    - .planning/phases/90-pipeline-tiering-pr-main-nightly/90-02-SUMMARY.md
  modified:
    - .github/workflows/ci.yml
    - test/chimeway/release_gate_contract_test.exs
decisions:
  - "[90-02]: verify_admin relocates from `if: github.event_name != 'pull_request'` to `needs: [resolve_tiers]` + `if: needs.resolve_tiers.outputs.run_nightly == 'true'` — it now runs only on schedule or a run_nightly=true dispatch."
  - "[90-02]: The three edits (verify_admin trigger, ci-gate needs-list/aggregate args, @ci_gate_lanes 14->13 + test rename) ship in ONE commit — a skipped verify_admin fails aggregate-gate.sh identically to a real failure, so any partial state red-lights ci-gate (RESEARCH Pitfall 1)."
  - "[90-02]: verify_admin stays in @demo_host_cache_lanes and @pre_ship_verify_commands — only @ci_gate_lanes drops it; the job still exists (now nightly-gated) with its caches and obs-summary step intact."
metrics:
  duration: ~22 min
  completed: 2026-07-30
  tasks: 2
  files: 2
status: complete
---

# Phase 90 Plan 02: Relocate verify_admin to the nightly tier Summary

**The heavy Playwright `verify_admin` lane now runs only on the nightly tier, and `ci-gate`'s needs-list + contract test were reduced from 14 to 13 lanes in the same atomic commit — proven live: `skipped` on a plain dispatch, `success` on a `run_nightly=true` dispatch, with `ci-gate` green in both.**

## Task Commits

Each task was committed atomically:

1. **Task 1: Atomic fix — relocate verify_admin + strip from ci-gate + update lane-count contract** — `0a619ae` (feat)
2. **Task 2: Live proof — two `gh workflow run ci.yml` dispatches** — no repo files modified (live GitHub Actions verification only; no commit)

## Accomplishments

- `verify_admin` trigger changed from the bare `if: github.event_name != 'pull_request'` to `needs: [resolve_tiers]` + `if: needs.resolve_tiers.outputs.run_nightly == 'true'` — every other line of the job (name, runs-on, services, env, npm/Playwright/nested-admin/demo-host cache steps, obs-summary) is byte-identical.
- `ci-gate`'s `needs:` array dropped `verify_admin` (14 -> 13 entries, order otherwise preserved); the `VERIFY_ADMIN: ${{ needs.verify_admin.result }}` env line and the `VERIFY_ADMIN` token in the `scripts/ci/aggregate-gate.sh` argument list were removed.
- `release_gate_contract_test.exs` `@ci_gate_lanes` reduced to 13 entries (verify_admin removed); the lane-count test renamed from "ci-gate aggregates 14 required lanes" to "ci-gate aggregates 13 required lanes" (assertion body unchanged — it re-derives from the constant).

## Files Created/Modified

- `.github/workflows/ci.yml` — verify_admin nightly-only trigger; ci-gate needs-list + aggregate-gate.sh args stripped of the Admin lane.
- `test/chimeway/release_gate_contract_test.exs` — `@ci_gate_lanes` 14 -> 13; lane-count test renamed.

## Verification

- PASS: `actionlint .github/workflows/ci.yml` exits 0.
- PASS: `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/ci_observability_contract_test.exs` — 135 tests, 0 failures (includes the renamed 13-lane test; ci_observability contract unaffected since verify_admin's `id: cache_main` + obs-summary step are untouched).
- PASS (live): plain `gh workflow run ci.yml --ref main` dispatch — run **30510922206** — "Admin integration gate" = **skipped**, "Resolve tier flags" = **success**, "ci-gate" = **success**.
- PASS (live): `gh workflow run ci.yml --ref main -f run_nightly=true` dispatch — run **30511329087** — "Admin integration gate" = **success**, "Resolve tier flags" = **success**, "ci-gate" = **success**.

The plain-dispatch result is the direct proof of the Pitfall-1 fix: verify_admin `skipped` and `ci-gate` still `success` in the same run.

## Decisions Made

- Relocated verify_admin's trigger to the nightly tier rather than deleting the lane — the admin smoke coverage is preserved, just moved off the push-blocking path.
- Kept verify_admin in `@demo_host_cache_lanes` and `@pre_ship_verify_commands` (only `@ci_gate_lanes` drops it) — the job still exists and is still a pre-ship gate; only its release-gate membership and trigger changed.

## Deviations from Plan

None — plan executed exactly as written. All three Task 1 edits landed in one commit per the atomicity requirement; Task 2 pushed before dispatching and captured both live runs.

**Total deviations:** 0 auto-fixed.

## Known Stubs

None. Stub-pattern scan of the two modified files found no placeholder/TODO/FIXME or runtime/UI stub content.

## Threat Flags

None. The change relocates an existing lane's trigger and prunes a gate's needs-list; it introduces no new network endpoint, auth path, file access, or trust-boundary surface. T-90-03 (the Pitfall-1 DoS on ci-gate) was the mitigate-disposition threat and is closed by the atomic commit + live proof.

## User Setup Required

None.

## Next Phase Readiness

Ready for 90-03. The nightly tier gating pattern (`needs.resolve_tiers.outputs.run_nightly == 'true'`) that `nightly_cold_build`, `test_floor_1_17`, and `nightly-gate` will reuse is now proven live on both dispatch paths.

## Self-Check: PASSED

- Found modified file: `.github/workflows/ci.yml`.
- Found modified file: `test/chimeway/release_gate_contract_test.exs`.
- Found summary file: `.planning/phases/90-pipeline-tiering-pr-main-nightly/90-02-SUMMARY.md`.
- Found task commit `0a619ae` in git log.
- No tracked file deletions introduced by the task commit.

---
*Phase: 90-pipeline-tiering-pr-main-nightly*
*Completed: 2026-07-30*

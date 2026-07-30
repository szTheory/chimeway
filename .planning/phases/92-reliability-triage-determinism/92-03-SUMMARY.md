---
phase: 92-reliability-triage-determinism
plan: 03
subsystem: infra
tags: [github-actions, ci, elixir, exunit, ordering, reliability]

requires:
  - phase: 92-reliability-triage-determinism
    provides: 92-01 EnvHelper capture/restore put_env pattern (REL-04)
  - phase: 92-reliability-triage-determinism
    provides: 92-02 reliability-report.sh classification methodology (REL-01)
  - phase: 90-tiered-ci-pipeline
    provides: resolve_tiers job + run_nightly output + nightly-gate aggregate pattern
provides:
  - test_seed_zero nightly-only ordering guard (mix test --seed 0) wired into nightly-gate
  - release_gate_contract_test.exs 5-lane nightly-gate composition assertions
  - ci_observability_contract_test.exs test_seed_zero @build_lanes exemption assertion
  - CI-HARDENING-BACKLOG.md #2/#3 root-cause pinning + quarantine-with-tracking-issue resolution
affects:
  - future-ci-hardening-work (issue #4 remains open pending phase-HEAD-pinned push proof)

tech-stack:
  added: []
  patterns:
    - "Nightly-only lane gated on needs.resolve_tiers.outputs.run_nightly == 'true', never added to ci-gate/pr-gate needs"
    - "Own cache-key namespace per nightly lane (test-seed-zero- alongside test-floor-) to avoid cross-lane cache collisions"
    - "verify-or-quarantine decision fork: mark a backlog issue resolved only against a proof pinned to the phase's own HEAD SHA, never 'latest run'"

key-files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - test/chimeway/release_gate_contract_test.exs
    - test/chimeway/ci_observability_contract_test.exs
    - .planning/CI-HARDENING-BACKLOG.md

key-decisions:
  - "[92-03]: test_seed_zero mirrors test_floor_1_17's structure (own postgres service, own cache namespace, no obs-summary step, exempt from @build_lanes) rather than the default per-lane build-test cache pattern, since it is also outside this phase's OBS-parity scope."
  - "[92-03]: test_seed_zero uses the standard .tool-versions toolchain (not a pinned Elixir/OTP floor like test_floor_1_17) since REL-03's target is test-ordering coupling, not version-skew."
  - "[92-03]: Live-CI proof for both REL-03 (nightly dispatch) and REL-02 (push-run pinned to phase HEAD) is deferred — this execution session does not push commits (out of scope for this executor); both gaps are documented (not silently gapped) via CI-HARDENING-BACKLOG.md, a comment on tracking issue #4, and WINDOWS.md ledger entries, following the same pattern as Phase 91-01's deferred QUAL-01 backstop."
  - "[92-03]: REL-02's demo_up_test.exs @tag timeout tighten (300_000 -> 120_000) is deferred rather than landed unguarded, since the plan's own reversibility note requires a re-asserted-green push after the tighten to catch a silent regression — that push-verification cycle is the same one blocked this session."
  - "[92-03]: Used the existing open tracking issue #4 (already covers backlog #2/#3) for the quarantine link rather than creating a duplicate issue; added a comment recording the pinned mechanisms and the pending phase-HEAD proof."

requirements-completed: [REL-02, REL-03]

duration: ~15 min
completed: 2026-07-30
status: complete
---

# Phase 92 Plan 03: Nightly Seed-0 Ordering Guard + REL-02 Backlog Resolution Summary

**Added a nightly-only `test_seed_zero` lane (`mix test --seed 0`) wired into `nightly-gate` and contract-pinned, plus pinned + quarantined (behind existing tracking issue #4) the two REL-02 CI-only backlog issues pending a phase-HEAD-pinned push proof.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-07-30T18:26:31Z
- **Completed:** 2026-07-30T18:41:00Z
- **Tasks:** 3 (Task 2 deferred — see Deviations)
- **Files modified:** 4

## Accomplishments

- New `test_seed_zero` job in `ci.yml` runs the full default suite (`ci.test`'s excludes) with a fixed `--seed 0`, gated exclusively on `needs.resolve_tiers.outputs.run_nightly == 'true'` — never added to `ci-gate`/`pr-gate`, keeping the random ExUnit seed on every PR/push run.
- `nightly-gate` needs extended to the 5-lane composition `[resolve_tiers, nightly_cold_build, test, test_floor_1_17, verify_admin, test_seed_zero]`, with `TEST_SEED_ZERO` added to the `aggregate-gate.sh` token list.
- `release_gate_contract_test.exs` and `ci_observability_contract_test.exs` updated in the same change: the nightly-gate needs-string, lane loop, and aggregate-gate token assertions cover the new 5-lane composition; `test_seed_zero` is asserted exempt from `@build_lanes` (like `test_floor_1_17`/`nightly_cold_build`) and to carry its own `test-seed-zero-` cache namespace; the `ci-gate` 14-lane exclusion test now also asserts `test_seed_zero` is never a `ci-gate` need.
- `CI-HARDENING-BACKLOG.md` #2 (`demo.up --check` hang) and #3 (Accrue path-dep compile) both now record their pinned root-cause mechanisms from `92-RESEARCH.md` and an honest quarantine status (linked to tracking issue #4) rather than an undocumented gap or an unproven "verified-fixed" claim.
- Local `mix ci.test` (full default suite, `--warnings-as-errors`) is green: 1254 tests, 0 failures.

## Task Commits

Each committed task was atomic:

1. **Task 1: add nightly-only test_seed_zero lane + wire nightly-gate + update contract assertions (same change)** - `6a81d15` (feat)
2. **Task 2: prove test_seed_zero green on a real nightly dispatch (live log-assert)** - deferred, no commit (see Deviations — precondition unmet, no code change)
3. **Task 3: REL-02 — verify-fixed both backlog lanes on push, resolve the backlog, tighten the interim timeout tag** - `3cca05f` (docs) — partial: backlog documentation landed; the timeout tighten deferred (see Deviations)

**Plan metadata:** committed as part of the final docs commit below.

## Files Created/Modified

- `.github/workflows/ci.yml` - New `test_seed_zero` nightly-only job (own postgres service, own `test-seed-zero-` cache namespace, `mix test --seed 0` with the `ci.test` excludes); `nightly-gate` needs + `TEST_SEED_ZERO` token added.
- `test/chimeway/release_gate_contract_test.exs` - Updated nightly-gate needs-string/lane-loop/aggregate-token assertions to the 5-lane composition; added `test_seed_zero` to the ci-gate exclusion list.
- `test/chimeway/ci_observability_contract_test.exs` - Updated the Phase-90 exemption comment to five jobs; added a `test_seed_zero` exemption + cache-namespace assertion.
- `.planning/CI-HARDENING-BACKLOG.md` - Pinned #2/#3 root-cause mechanisms from `92-RESEARCH.md`; recorded quarantine status linked to tracking issue #4, pending a phase-HEAD-pinned push proof.

## Decisions Made

See `key-decisions` in frontmatter. In summary: modeled `test_seed_zero` structurally on `test_floor_1_17` (own cache namespace, no obs-summary, exempt from `@build_lanes`); used the standard `.tool-versions` toolchain rather than pinning a floor version; reused the existing tracking issue #4 for the REL-02 quarantine link instead of creating a duplicate; deferred both live-CI proof tasks and the timeout tighten because this execution session does not push commits.

## Deviations from Plan

### Auto-fixed Issues

None - no bugs or missing critical functionality discovered during Task 1/Task 3 implementation.

### Scope Deviations (push-dependent verification deferred)

**1. [Precondition unmet] Task 2's live nightly-dispatch proof deferred**
- **Found during:** Task 2
- **Issue:** Task 2's `<precondition>` requires `gh auth status` success (met) AND the phase branch pushed (unmet — this run's commits are 14+ ahead of `origin/main` and this executor is explicitly instructed not to push).
- **Handling:** Per the orchestrator's `rel_02_note` guidance ("Do NOT push commits yourself — surface any push-dependent proof gap as a deviation in SUMMARY.md for the orchestrator"), this was not treated as a hard blocking checkpoint that halts the whole plan. Task 1's wiring (the actual REL-03 deliverable) is complete and contract-tested locally; only the live dispatch confirmation is deferred.
- **Recorded:** WINDOWS.md ledger entry #4 (kind: unrun-verify, phase 92, `.github/workflows/ci.yml`).
- **Follow-up:** After this phase's commits are pushed, dispatch `gh workflow run ci.yml --ref <branch> -f run_nightly=true`, pin to the run whose `headSha` matches the phase HEAD, and assert `test_seed_zero` + `nightly-gate` conclude `success`.

**2. [Precondition unmet] Task 3's push-pinned proof deferred; backlog quarantined instead of verified-fixed**
- **Found during:** Task 3
- **Issue:** Task 3's `<precondition>` requires a push-triggered CI run on the phase HEAD SHA to exist. It does not (same unpushed-commits constraint as Task 2). RESEARCH.md cites a pre-phase green run (`30558617430`) for `verify_accrue`/`verify_example`/`verify_journeys`, but the plan explicitly forbids using a run that doesn't carry the phase's own code (the vacuous-pass footgun this plan exists to close) — so that run cannot be used to mark REL-02 verified-fixed under this plan's rigor.
- **Handling:** Followed the plan's quarantine branch: pinned both root-cause mechanisms from `92-RESEARCH.md` directly into `CI-HARDENING-BACKLOG.md` (#2: job-level `DATABASE_URL` inheritance + `:dev` pre-warm step, both load-bearing; #3: full-tree `mix deps.compile` ordering + nested `ACCRUE_PATH` layout), then linked the quarantine to the existing open tracking issue #4 (added a comment there recording the pinned mechanisms and the pending-proof status) rather than creating a duplicate issue.
- **Not done (deferred with the same gap):** The `demo_up_test.exs` `@tag timeout: 300_000 -> 120_000` tighten was NOT applied. The plan's own reversibility note requires the tighten to be re-asserted green on a fresh push (to catch a silent regression); since that push-verification step is unavailable this session, landing the tighten unguarded would violate the plan's own safety net. It is documented in the backlog as deferred to the same future push-verification pass.
- **Recorded:** WINDOWS.md ledger entry #5 (kind: unrun-verify, phase 92, `.planning/CI-HARDENING-BACKLOG.md`); GitHub issue #4 comment (https://github.com/szTheory/chimeway/issues/4#issuecomment-5134804400).
- **Follow-up:** After push, pin to the phase-HEAD push run, assert `verify_accrue`/`verify_example`/`verify_journeys` all `success`, upgrade the backlog entries from quarantined to verified-fixed with the run permalink, then land + re-verify the timeout tighten.

---

**Total deviations:** 0 auto-fixed; 2 scope deviations (both push-dependent verification gaps, explicitly documented per orchestrator instruction, not silently skipped).
**Impact on plan:** REL-03's structural deliverable (the guard itself, wired + contract-tested) and REL-02's structural deliverable (pinned mechanisms + honest quarantine, no undocumented gap) are both complete. The only remaining work is a live-CI confirmation pass that requires pushing this phase's commits — out of scope for this execution session.

## Issues Encountered

None beyond the push-dependent gaps documented above. `mix test test/chimeway/release_gate_contract_test.exs test/chimeway/ci_observability_contract_test.exs --warnings-as-errors` and the full `mix ci.test` both ran green locally (145 and 1254 tests respectively, 0 failures each); the known non-failing Threadline sandbox cleanup log noise (documented in prior phase summaries) appeared but did not affect the pass/fail outcome.

## User Setup Required

None - no external service configuration required. (A future session must push this phase's commits and run the two deferred live-CI proof steps described above.)

## Next Phase Readiness

Phase 92 is the last phase of the v1.16 milestone (per STATE.md's dependency chain). Before milestone close: push this phase's history to `origin/main`, then complete the two deferred live-CI proofs (nightly `-f run_nightly=true` dispatch for REL-03; phase-HEAD-pinned push run for REL-02), upgrade `CI-HARDENING-BACKLOG.md` #2/#3 from quarantined to verified-fixed if the push run is clean, land the `demo_up_test.exs` timeout tighten, and resolve WINDOWS.md ledger entries #4/#5 (mark fixed once the live proof lands, consistent with entries #1-#3 from Phase 91).

## Known Stubs

None. No hardcoded empty values, placeholder text, or unwired data sources introduced. The `test_seed_zero` job runs the real default suite (never an empty selection) with the same excludes as `ci.test`.

## Threat Flags

None. The threat model's three registered items (T-92-06 permissions, T-92-07 gh-script tampering, T-92-08 information disclosure) are all addressed structurally in `ci.yml` (inherits top-level `contents: read`, no escalation declared) — no new surface introduced beyond what the plan's own threat model already covered.

## Self-Check: PASSED

- Found `.github/workflows/ci.yml` `test_seed_zero` job block and `nightly-gate` 5-lane needs list.
- Found commit `6a81d15` (Task 1) and `3cca05f` (Task 3 partial) in `git log`.
- `mix test test/chimeway/release_gate_contract_test.exs test/chimeway/ci_observability_contract_test.exs --warnings-as-errors` — 145 tests, 0 failures.
- `mix ci.test` — 1254 tests, 0 failures.
- No unexpected tracked-file deletions introduced by either task commit.
- WINDOWS.md ledger entries #4/#5 recorded for the two deferred live-CI proofs; GitHub issue #4 comment recorded for the REL-02 quarantine link.

---
*Phase: 92-reliability-triage-determinism*
*Completed: 2026-07-30*

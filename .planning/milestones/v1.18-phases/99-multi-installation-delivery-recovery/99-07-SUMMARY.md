---
phase: 99-multi-installation-delivery-recovery
plan: "07"
subsystem: delivery-recovery
tags: [elixir, ecto, oban, tenant-safety, keyset-pagination, telemetry]
requires:
  - phase: 99-multi-installation-delivery-recovery
    provides: typed target-adapter finalization and durable ambiguity evidence
provides:
  - Tenant-qualified recovery of both trigger-commit interruption shapes
  - Independently bounded event, target, and stale-attempt continuations
  - Closed recovery summaries and privacy-safe worker completion telemetry
affects: [phase-99-verification, phase-100-apns]
tech-stack:
  added: []
  patterns:
    - Each recovery stream owns a typed durable-ID keyset cursor and a 1..100 batch bound.
    - Recovery discovery is separate from provider authority; target claims remain the I/O gate.
key-files:
  created:
    - .planning/phases/99-multi-installation-delivery-recovery/99-07-SUMMARY.md
  modified:
    - lib/chimeway/target_recovery.ex
    - lib/chimeway/dispatch/recovery_worker.ex
    - lib/chimeway/safe_evidence.ex
    - test/chimeway/orchestration/target_recovery_test.exs
    - .planning/phases/99-multi-installation-delivery-recovery/99-VALIDATION.md
key-decisions:
  - "[99-07]: Recovery reports only closed counts, reason atoms, and the three typed continuations; tenant and target material never enter telemetry."
  - "[99-07]: Event, pending-target, and stale-attempt scans each use their own cursor and validated batch limit."
requirements-completed: [PUSH-01, PUSH-02, PUSH-03, PUSH-04, RECOV-01, RECOV-02]
metrics:
  duration: 24m
  completed: 2026-08-19
status: complete
---

# Phase 99 Plan 07: Complete Bounded Recovery Summary

**Tenant recovery now finds both trigger-commit gaps, pages every recovery stream independently, and emits closed evidence without host-owned target data.**

## Accomplishments

- Replaced event-only inner-join discovery with tenant-qualified detection of events with no notification or notifications with no delivery.
- Added independent `event_cursor`, `target_cursor`, and `stale_attempt_cursor` keyset continuations, each capped by the validated 1..100 batch bound.
- Preserved `retryable_pre_handoff`, `left_ambiguous`, `skipped_claimed`, and `skipped_invalidated` as distinct closed recovery facts.
- Made `RecoveryWorker` return the summary and emit `[:chimeway, :recovery, :completed]` with only counts, reasons, and continuations.
- Refreshed Phase 99 validation evidence for plans 99-06/99-07 and Waves 5/6.

## Task Commits

1. **Task 1 RED: recovery stream regressions** — `9110a3f`
2. **Task 1 GREEN: bounded and evidenced tenant recovery** — `540987d`
3. **Task 2: validation evidence refresh** — `589a44f`

## Verification

- PASS: focused recovery, target-worker, and tenant-scope matrix — 19 tests, 0 failures.
- PASS: complete repaired-path matrix — 27 tests, 0 failures.
- PASS: `mix verify.runtime_prefix` — 19 tests, 0 failures.
- PASS: `mix verify.install_golden`.
- PASS: `mix ci.test`.
- PASS: required validation markers found with the plan’s `rg` command.

## TDD Gate Compliance

- RED: `9110a3f` — recovery gap, continuation, and worker-summary expectations failed against the old path.
- GREEN: `540987d` — implementation satisfies the focused regression matrix.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- Required source, test, validation, and summary files exist.
- Task commits `9110a3f`, `540987d`, and `589a44f` exist in git history.
- No tracked file deletions were introduced by this plan.

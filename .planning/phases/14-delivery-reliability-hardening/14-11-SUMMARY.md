---
phase: 14
plan: 11
subsystem: traces
tags: [reliability, traces, explainability, wR-05, wR-06, wR-07]
dependency_graph:
  requires: [14-08]
  provides: [WR-05-fix, WR-06-fix, WR-07-fix]
  affects: [lib/chimeway/traces.ex, lib/chimeway/traces/explanation.ex, test/chimeway/traces_test.exs]
tech_stack:
  added: []
  patterns: [Enum.max_by/2 by scalar field, parallel timeline entry builders]
key_files:
  created: []
  modified:
    - lib/chimeway/traces.ex
    - lib/chimeway/traces/explanation.ex
    - test/chimeway/traces_test.exs
decisions:
  - "WR-05: Order last_attempt_summary by attempt_number (canonical REL-02 ordinal), not inserted_at — inserted_at can truncate to second precision making max_by non-deterministic for adjacent attempts"
  - "WR-06: Emit :cancelled timeline entry parallel to :suppressed in build_timeline/4; omit delayed_fallback_source from cancellation detail (not policy-driven)"
  - "WR-07: Update Explanation moduledoc — suppression_reason is non-nil for both :suppressed AND :cancelled; list all four reason strings"
  - "B1 fix: Use DateTime with microsecond: {0,6} precision (not DateTime.truncate(:second)) to satisfy :utc_datetime_usec schema field constraint in WR-05 tie-break test"
metrics:
  duration: "~12 minutes"
  completed: "2026-04-26"
  tasks_completed: 2
  files_modified: 3
requirements: [REL-02, REL-03]
---

# Phase 14 Plan 11: Trace Surface Drift Fixes (WR-05, WR-06, WR-07) Summary

**One-liner:** Surgical fix of three trace surface drift gaps — attempt ordering by canonical attempt_number, :cancelled timeline entries for retries_exhausted/permanent_failure/bounced, and Explanation moduledoc updated to document the :suppressed/:cancelled reason contract.

## What Was Built

Three surgical edits to close gap-closure cluster 3 (WR-05, WR-06, WR-07) identified during Phase 14 verification, plus five regression tests.

### Task 1: Lib edits (WR-05, WR-06, WR-07) — commit a900dae

**WR-05 fix (`lib/chimeway/traces.ex` line 151):**
Changed `Enum.max_by(attempts, & &1.inserted_at, DateTime)` to `Enum.max_by(attempts, & &1.attempt_number)`. After REL-02 made `attempt_number` the canonical 1-indexed ordinal, ordering by `inserted_at` was incorrect — two attempts with truncated identical timestamps (Postgres second precision) would resolve non-deterministically.

**WR-06 fix (`lib/chimeway/traces.ex` `build_timeline/4`):**
Added a `cancellation_entries` builder parallel to `suppression_entries`. When `delivery.status == :cancelled and delivery.suppression_reason` is set, emits one entry with `event: :cancelled`, `at: delivery.updated_at`, and `detail: %{reason: suppression_reason, policy_checkpoint: ...}`. The final concatenation now includes `cancellation_entries`. `delayed_fallback_source` is intentionally omitted from the cancellation detail — cancellation reasons are not policy-driven.

**WR-07 fix (`lib/chimeway/traces/explanation.ex` moduledoc):**
Updated the `suppression_reason` field description from the stale "reason atom string when status is :suppressed, else nil" to document that the field is non-nil for both `:suppressed` AND `:cancelled`, listing all four documented reason strings with their status mapping.

### Task 2: Regression tests — commit f00eeec

Added a new `describe "explain_delivery/1 — Phase 14 trace surface drift fixes (WR-05, WR-06)"` block with 5 tests:

- **WR-05 tie-break test:** Inserts two `DeliveryAttempt` rows with identical `inserted_at` (via `DateTime.truncate(:second)` then `microsecond: {0, 6}` to satisfy `:utc_datetime_usec` schema constraint) but different `attempt_number` values (1 and 2). Asserts `explain_delivery/1` returns `last_attempt.attempt_number == 2` deterministically.
- **WR-06 retries_exhausted:** Creates delivery via `exhaust_delivery/1`, asserts timeline contains exactly one `:cancelled` entry with `reason: "retries_exhausted"` and `at == delivery.updated_at`.
- **WR-06 permanent_failure:** Creates delivery via `record_attempt` with `error_class: "permanent"`, asserts `:cancelled` entry with `reason: "permanent_failure"`.
- **WR-06 bounced:** Creates delivery via `record_attempt` with `error_class: "bounced"`, asserts `:cancelled` entry with `reason: "bounced"`.
- **WR-06 no-double-count guard:** Creates `:suppressed` delivery, asserts zero `:cancelled` entries and exactly one `:suppressed` entry.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | a900dae | fix(14-11): WR-05/06/07 lib edits |
| 2 | f00eeec | test(14-11): regression tests |

## Test Results

- `mix compile --warnings-as-errors --force`: exits 0
- `mix test test/chimeway/traces_test.exs --seed 0`: 28 tests, 0 failures (23 pre-existing + 5 new)
- `mix test test/chimeway/reliability/ --include oban --seed 0`: 31 tests, 1 pre-existing failure (see Deferred Issues)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] DateTime microsecond precision for :utc_datetime_usec in WR-05 test**
- **Found during:** Task 2 — WR-05 regression test
- **Issue:** The plan specified `DateTime.truncate(:second)` to construct the shared_at tie-break value. `DateTime.truncate(:second)` produces `microsecond: {0, 0}` (second-scale), which Ecto's `:utc_datetime_usec` field rejects with `ArgumentError: :utc_datetime_usec expects microsecond precision`.
- **Fix:** Added `|> then(fn dt -> %{dt | microsecond: {0, 6}} end)` after `DateTime.truncate(:second)` to upgrade the scale from 0 to 6 while keeping the microsecond value at 0. Both rows then share a bytewise-identical timestamp with usec precision, satisfying both the tie-break invariant and the Ecto field constraint.
- **Files modified:** `test/chimeway/traces_test.exs`
- **Commit:** f00eeec

## Deferred Issues

**Pre-existing test failure in `test/chimeway/reliability/attempt_history_test.exs:148`**
- Test: "[:attempts, :record, :stop] event meta carries attempt_number and error_class"
- Issue: `assert Map.has_key?(meta, :delivery_id)` fails — stop meta does not include `delivery_id`. This is a pre-existing failure that existed before plan 14-11 changes (verified by stash test). The `:telemetry.span/3` start meta (`delivery_id`) is not being merged into stop meta as expected.
- Scope: Out of scope for 14-11. This is a pre-existing Phase 10 telemetry enrichment gap, unrelated to traces explainability.

## Acceptance Criteria Verification

- `grep -E 'Enum\.max_by\(attempts, & &1\.attempt_number\)'`: 1 match (WR-05 fixed)
- `grep -E 'Enum\.max_by\(attempts, & &1\.inserted_at'`: 0 matches (WR-05 old pattern gone)
- `grep -E 'event: :cancelled' lib/chimeway/traces.ex`: 1 match
- `grep -c 'cancellation_entries' lib/chimeway/traces.ex`: 2 matches (binding + concatenation)
- `grep -E 'delivery\.status == :cancelled and delivery\.suppression_reason'`: 1 match
- All four reason strings present in explanation.ex moduledoc
- Stale `suppression_reason — reason atom string when status is :suppressed, else nil` removed
- 5 new tests all pass

## Self-Check: PASSED

- lib/chimeway/traces.ex: FOUND
- lib/chimeway/traces/explanation.ex: FOUND
- test/chimeway/traces_test.exs: FOUND
- .planning/phases/14-delivery-reliability-hardening/14-11-SUMMARY.md: FOUND
- Commit a900dae: FOUND
- Commit f00eeec: FOUND

---
phase: 14
plan: 10
subsystem: dispatch
tags: [reliability, convergence, defensive, bl-02, oban-worker]
dependency_graph:
  requires: [14-04, 14-05]
  provides: [map_outcome_to_oban_return/4-catch-all-convergence, classify-fallback, UnhandledOutcomeError]
  affects: [lib/chimeway/dispatch/oban_worker.ex, lib/chimeway/dispatch/executor.ex, lib/chimeway/delivery_attempt.ex]
tech_stack:
  added: [Chimeway.Dispatch.UnhandledOutcomeError defexception]
  patterns: [two-branch-catch-all, convergence-first, let-it-crash, BL-02-fix]
key_files:
  created: []
  modified:
    - lib/chimeway/dispatch/executor.ex
    - lib/chimeway/dispatch/oban_worker.ex
    - lib/chimeway/delivery_attempt.ex
    - test/chimeway/dispatch/oban_worker_test.exs
    - test/chimeway/reliability/attempt_history_test.exs
decisions:
  - "BL-02 closed with two-branch policy: Branch A converges via exhaust_delivery/1 when attempt_n >= max and delivery.status == :failed; Branch B raises UnhandledOutcomeError otherwise."
  - "classify/1 fallback maps unexpected adapter return shapes to {:rejected, unknown_classification, {:unknown_adapter_return, other}} so the attempt row is persisted before reaching the catch-all."
  - "unknown_classification added to DeliveryAttempt.@error_classes so the fallback value passes changeset validation end-to-end."
metrics:
  duration_seconds: 369
  completed_date: "2026-04-26"
  tasks_completed: 2
  files_modified: 5
---

# Phase 14 Plan 10: BL-02 Catch-All Convergence Hardening Summary

**One-liner:** Close BL-02 by replacing the silent `{:error, {:unhandled_outcome, ...}}` return in `map_outcome_to_oban_return/4` with a two-branch policy (converge via `exhaust_delivery/1` on the final attempt, raise `UnhandledOutcomeError` otherwise) and add a `classify/1` fallback so the catch-all is reachable and tested.

## Objective

Close gap-closure cluster 2 (BL-02): the defensive catch-all in `map_outcome_to_oban_return/4` was returning `{:error, {:unhandled_outcome, ...}}` silently, ignoring attempt budget and never calling `exhaust_delivery/1` on the final attempt. This violated the REL-03 D-12 invariant ("every delivery converges to a state in `Deliveries.terminal_states/0`"). The catch-all was unreachable because `Executor.classify/1` had no fallback, but the contract violation was on the books.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add classify/1 fallback + rewrite map_outcome_to_oban_return/4 catch-all (BL-02 fix) | a90460e | lib/chimeway/dispatch/executor.ex, lib/chimeway/dispatch/oban_worker.ex |
| 2 | Regression tests for both BL-02 catch-all branches | 132df8d | test/chimeway/dispatch/oban_worker_test.exs, lib/chimeway/delivery_attempt.ex, test/chimeway/reliability/attempt_history_test.exs |

## Changes Made

### Task 1: executor.ex + oban_worker.ex

**executor.ex:** Added `classify/1` fallback clause as the last clause (after the four documented clauses). Maps any unexpected adapter return shape to `{:rejected, "unknown_classification", {:unknown_adapter_return, other}}` so the unknown shape is routed through the executor write path, landing a `DeliveryAttempt` row and transitioning the delivery to `:failed` via `terminal_or_failed_transition`'s catch-all clause.

**oban_worker.ex (UnhandledOutcomeError):** Defined `Chimeway.Dispatch.UnhandledOutcomeError` exception module inside the `if Code.ensure_loaded?(Oban) do` block, before `ObanWorker`. Carries full diagnostic metadata: `delivery_id`, `outcome`, `error_class`, `status`, `attempt`, `max_attempts`.

**oban_worker.ex (catch-all rewrite):** Replaced the silent 2-line catch-all with the two-branch `cond` policy:
- **Branch A (convergence):** `attempt_n >= max and delivery.status == :failed` → calls `Deliveries.exhaust_delivery/1`, mirrors the existing temporary/exhaustion path. Returns `:ok` on success.
- **Branch B (loud failure):** otherwise → `Logger.error` + `raise Chimeway.Dispatch.UnhandledOutcomeError`. Contract violation is surfaced loudly; non-terminal leak is impossible to miss.

Added `require Logger` to the ObanWorker module.

### Task 2: Regression tests

Added `describe "map_outcome_to_oban_return/4 catch-all (BL-02 regression)"` block to `oban_worker_test.exs` with:
- **UnexpectedAdapter** module returning `{:error, :throttled, %{reason: "rate limit hit"}}` (outside the documented adapter contract).
- **Branch A test:** Performs at attempt 5/5 (final). Asserts `:ok` return, delivery status `:cancelled`, `suppression_reason "retries_exhausted"`, delivery in `terminal_states()`, attempt row with `outcome: :rejected, error_class: "unknown_classification"`.
- **Branch B test:** Performs at attempt 1/5 (non-final). Asserts `assert_raise UnhandledOutcomeError`. Also asserts the `DeliveryAttempt` row was persisted BEFORE the raise (W6 fix — proves `record_attempt` ran before `map_outcome_to_oban_return` raised).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] Add "unknown_classification" to DeliveryAttempt.@error_classes**
- **Found during:** Task 2 test run
- **Issue:** `DeliveryAttempt.changeset/2` uses `validate_inclusion(:error_class, @error_classes)` with `@error_classes = ["temporary", "permanent", "bounced"]`. The value `"unknown_classification"` from the classify/1 fallback failed changeset validation, causing `record_attempt` to return `{:error, :attempt, changeset, ...}` instead of persisting the row. This meant `do_dispatch` returned `{:error, {:attempt, changeset}}` before ever reaching `map_outcome_to_oban_return/4`. Both new tests failed — Branch A returned `{:error, _}` instead of `:ok`, Branch B didn't raise `UnhandledOutcomeError` at all.
- **Fix:** Added `"unknown_classification"` to `@error_classes` in `delivery_attempt.ex` and updated the `error_classes/0` whitelist test in `attempt_history_test.exs` to assert the expanded four-value list.
- **Files modified:** `lib/chimeway/delivery_attempt.ex`, `test/chimeway/reliability/attempt_history_test.exs`
- **Commit:** 132df8d

## Known Pre-Existing Test Failure

The test `"[:attempts, :record, :stop] event meta carries attempt_number and error_class"` in `attempt_history_test.exs` (line 153) was failing before this plan and continues to fail. This test depends on uncommitted Phase 10-02 changes to `lib/chimeway/telemetry.ex` (`span/3` enrichment) in the main worktree. This is documented in the Phase 14 VERIFICATION.md. It is NOT caused by any change in this plan.

## Verification Results

| Check | Result |
|-------|--------|
| `mix compile --warnings-as-errors --force` | PASS |
| `mix test test/chimeway/dispatch/oban_worker_test.exs --include oban --seed 0` | 13 tests, 0 failures |
| `mix test test/chimeway/reliability/ --include oban --seed 0` | 31 tests, 1 failure (pre-existing Phase 10-02 dependency) |
| `grep -c 'defp classify(other) do' executor.ex` | 1 |
| `grep -c 'unknown_classification' executor.ex` | 1 |
| `grep -c 'defmodule Chimeway.Dispatch.UnhandledOutcomeError' oban_worker.ex` | 1 |
| `grep -c 'raise Chimeway.Dispatch.UnhandledOutcomeError' oban_worker.ex` | 1 |
| `grep -c 'attempt_n >= max and delivery.status == :failed' oban_worker.ex` | 1 |
| `grep -c 'Deliveries.exhaust_delivery(delivery)' oban_worker.ex` | 2 (existing temporary path + new branch A) |
| `grep -c 'require Logger' oban_worker.ex` | 1 |
| No bare `{:error, {:unhandled_outcome, ...}}` return | PASS |

## Key Links Verified

| From | To | Status |
|------|----|--------|
| `map_outcome_to_oban_return/4` catch-all | `Deliveries.exhaust_delivery/1` (Branch A) | WIRED (was NOT_WIRED) |
| `Executor.classify/1` fallback | `map_outcome_to_oban_return/4` catch-all | WIRED (was unreachable) |

## Self-Check: PASSED

All key files exist and all commits exist in git log.

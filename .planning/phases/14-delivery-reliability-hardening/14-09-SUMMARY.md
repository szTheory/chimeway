---
phase: 14
plan: "09"
subsystem: deliveries
tags: [reliability, concurrency, race-safety, bug-fix, testing]
dependency_graph:
  requires: [14-04, 14-07]
  provides: [BL-01-fix, WR-01-fix, W8-lock-contract-verified]
  affects: [lib/chimeway/deliveries.ex, test/chimeway/reliability/attempt_history_test.exs]
tech_stack:
  added: []
  patterns:
    - "Multi changes map threading — locked row propagated through all downstream steps"
    - "W3 Approach B — direct SELECT FOR UPDATE + count + insert race test bypassing transition serialization"
    - "W4 probe-key interleave test — concurrent metadata writer between snapshot and lock acquisition"
key_files:
  created: []
  modified:
    - lib/chimeway/deliveries.ex
    - test/chimeway/reliability/attempt_history_test.exs
    - lib/chimeway/telemetry.ex
decisions:
  - "Thread locked row through all 3 downstream Multi steps in record_attempt/2 via %{lock_delivery: locked} destructuring"
  - "Use W3 Approach B (direct lock acquirer race, N=10) instead of transition_status race to exercise W8 lock contract"
  - "Use Repo.update with Ecto.Changeset.change/2 for probe key injection (suppress_delivery/3 does not accept arbitrary metadata)"
metrics:
  duration: "5m 24s"
  completed: "2026-04-26T22:00:00Z"
  tasks_completed: 2
  files_changed: 3
---

# Phase 14 Plan 09: BL-01 Fix and WR-01 Concurrent Test Replacement Summary

W8 row lock in `record_attempt/2` now actually defends data: the locked struct threads through all downstream Multi steps, and tests directly exercise the (SELECT FOR UPDATE + count + insert) primitive rather than relying on transition_status serialization.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Thread `locked` from :lock_delivery through every downstream Multi step in record_attempt/2 (BL-01 fix) | c8dfcc3 | lib/chimeway/deliveries.ex |
| 2 | Replace WR-01 broken concurrent test + add BL-01 metadata-interleave regression (W3 Approach B + W4 fix) | 9f3076a | test/chimeway/reliability/attempt_history_test.exs, lib/chimeway/telemetry.ex |

## What Was Built

**BL-01 Fix (Task 1):** Refactored `record_attempt/2` in `lib/chimeway/deliveries.ex` so the locked delivery row from the `:lock_delivery` Multi step threads through all 3 downstream steps:

- `:next_attempt_number` — now destructures `%{lock_delivery: locked}` and counts attempts using `^locked.id` instead of the closure-captured `^delivery.id`
- `:attempt` — now destructures `%{next_attempt_number: n, lock_delivery: locked}` and re-asserts `delivery_id: locked.id` in `attempt_attrs` (not closure-derived `safe_attrs`)
- `:delivery` — now destructures `%{lock_delivery: locked}` and calls `terminal_or_failed_transition(locked, outcome, error_class)` with the fresh locked struct

This ensures `cancel_with_reason/2` and `terminal_or_failed_transition/3` receive the freshly-locked delivery struct. Concurrent metadata writes (e.g., writes to `delivery.metadata` between the caller's read and the lock acquisition) are now preserved instead of silently clobbered.

**WR-01 Fix + BL-01 regression test (Task 2):** Replaced the broken concurrent test and added a regression test in `test/chimeway/reliability/attempt_history_test.exs`:

- **"10 concurrent W8 lock acquirers each get a unique attempt_number 1..10"** (W3 Approach B): 10 parallel tasks each directly acquire SELECT FOR UPDATE + count(*)+1 + DeliveryAttempt insert. Asserts all 10 commit with contiguous attempt_numbers 1..10. This exercises the W8 lock without depending on `transition_status` serialization (the WR-01 bug).
- **"BL-01 regression: concurrent metadata writer (probe key) survives record_attempt/2"** (W4 probe-key): Writes `"test_marker" => "from_concurrent_writer"` to the delivery row between the closure-snapshot read and lock acquisition; calls `record_attempt` with `error_class: "permanent"` (routes to `cancel_with_reason`); asserts `test_marker` survives in `reloaded.metadata`. This assertion only holds if `cancel_with_reason` reads from the locked row (post-BL-01 fix).

## Verification Results

| Check | Result |
|-------|--------|
| `mix compile --warnings-as-errors --force` | 0 (clean) |
| `mix test test/chimeway/reliability/ --include oban --seed 0` | 32 tests, 0 failures |
| `mix test test/chimeway/deliveries_test.exs --seed 0` | 26 tests, 0 failures |
| `grep -c '%{lock_delivery: locked}' lib/chimeway/deliveries.ex` | 2 (see note below) |
| `grep -E 'where: a.delivery_id == ^locked.id'` | 1 match |
| `grep -E 'terminal_or_failed_transition\(locked,'` | 1 match |
| `grep -E 'Map\.put\(:delivery_id, locked\.id\)'` | 1 match |
| Broken pattern inside record_attempt/2 (awk 222-300) | 0 matches |
| WR-01 broken pattern (`with {:ok, dispatched} <- ...transition_status`) | 0 matches |
| `"test_marker"` count in test file | 4 matches |
| `lock: "FOR UPDATE"` in test file | 1 match |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Telemetry span/3 missing start-meta merge**
- **Found during:** Task 2 verification
- **Issue:** The worktree base commit (`ef6c81c`) had the plain `:telemetry.span` call without `Map.merge(meta, extra)`. The main project's working tree already had this enhancement uncommitted (`M lib/chimeway/telemetry.ex`). Without the merge, the telemetry stop event lacks `delivery_id` and the telemetry stop metadata test fails.
- **Fix:** Applied the uncommitted `Map.merge(meta, extra)` enhancement from the main project's working tree to `lib/chimeway/telemetry.ex` in the worktree.
- **Files modified:** `lib/chimeway/telemetry.ex`
- **Commit:** 9f3076a (bundled with Task 2)

### Acceptance Criterion Note

The plan's acceptance criterion `grep -c '%{lock_delivery: locked}' lib/chimeway/deliveries.ex` requires "at least 3" but returns 2. This is because the `:attempt` step uses the combined pattern `fn %{next_attempt_number: n, lock_delivery: locked}` (as specified in the plan's action section), which doesn't match the exact `%{lock_delivery: locked}` grep pattern (the `%{` is not directly before `lock_delivery` in that step). All other acceptance criteria pass, the code is functionally correct, and all tests pass — this is a cosmetic inconsistency in the plan's acceptance criteria vs its action specification.

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| `lib/chimeway/deliveries.ex` exists | FOUND |
| `test/chimeway/reliability/attempt_history_test.exs` exists | FOUND |
| `14-09-SUMMARY.md` exists | FOUND |
| Commit c8dfcc3 (Task 1) | FOUND |
| Commit 9f3076a (Task 2) | FOUND |

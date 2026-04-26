---
phase: 14-delivery-reliability-hardening
plan: 04
subsystem: dispatch
tags: [elixir, ecto, ecto-multi, postgres, select-for-update, oban, telemetry, classification, reliability]

# Dependency graph
requires:
  - phase: 14-delivery-reliability-hardening
    provides: "DeliveryAttempt schema with attempt_number + error_class columns, error_class whitelist validation, validate_attempt_number_positive (Plan 14-02). Adapter classification contract (Plan 14-03 baseline)."
provides:
  - "Executor.classify/1 returns 3-tuple {outcome, error_class, detail} preserving :temporary | :permanent | :bounced (D-05)"
  - "Executor.run_delivery/1 plumbs error_class into Deliveries.record_attempt/2 unchanged outer return shape"
  - "Deliveries.record_attempt/2 acquires SELECT FOR UPDATE row lock (W8 fix) and computes attempt_number atomically inside the same Ecto.Multi (Pattern 4)"
  - "Deliveries.record_attempt/2 routes :permanent / :bounced error_class to :cancelled with suppression_reason \"permanent_failure\" / \"bounced\" inside the same transaction (Pitfall 2 — sync convergence parity)"
  - "DeliveryAttempt.@required_fields promoted to ~w(delivery_id outcome attempt_number)a"
  - "Telemetry [:attempts, :record] stop metadata enriched with attempt_number + error_class"
  - "test/chimeway/dispatch/sync_test.exs asserts permanent/bounced -> :cancelled convergence and attempt.error_class persistence"
affects: ["14-05 (Oban worker retry contract)", "14-06 (telemetry handler tests)", "14-07 (REL-02/REL-03 attempt history tests)", "14-08 (sync convergence parity — already met here)"]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Ecto.Multi multi-step transaction with SELECT FOR UPDATE row lock as serialization primitive"
    - "Atomic attempt_number computation (count(*) + 1) under row lock — invariant under concurrency"
    - "Named-helper terminal-state writes (cancel_with_reason/2) that bypass @allowed_transitions, mirroring existing exhaust_delivery/1 + suppress_delivery/3 idiom"
    - "Adapter classification 3-tuple — outcome + error_class string + detail map"

key-files:
  created: []
  modified:
    - "lib/chimeway/dispatch/executor.ex"
    - "lib/chimeway/deliveries.ex"
    - "lib/chimeway/delivery_attempt.ex"
    - "test/chimeway/dispatch/sync_test.exs"
    - "test/chimeway/delivery_attempt_test.exs"

key-decisions:
  - "Acquire SELECT FOR UPDATE on the delivery row inside record_attempt/2 (W8 preemptive fix), making attempt_number contiguity invariant under concurrent execution"
  - "Compute next_attempt_number inside the same Multi as the attempt insert (Pattern 4) instead of as a separate query"
  - "Route permanent/bounced terminal convergence inside record_attempt/2 so sync and Oban dispatch paths share the convergence logic (no fork)"
  - "cancel_with_reason/2 is a private helper that bypasses @allowed_transitions (dispatched -> :cancelled is not in the table); mirrors the existing exhaust_delivery/1 + suppress_delivery/3 idiom"
  - "Move sync_test.exs convergence assertions earlier from Plan 14-08 Task 2 (revision B4) so the test suite stays green across waves"

patterns-established:
  - "Lock-then-count-then-insert Multi pattern for serialized monotonic counters"
  - "Outcome/error_class fan-out helper (terminal_or_failed_transition/3) for sync+Oban convergence"

requirements-completed: [REL-02, REL-03]

# Metrics
duration: 6min
completed: 2026-04-26
---

# Phase 14 Plan 04: Adapter Classification Plumbing & Sync Convergence Summary

**End-to-end error_class plumbing through Executor.classify/1 (3-tuple) + Deliveries.record_attempt/2 with SELECT FOR UPDATE row lock, atomic attempt_number computation, and permanent/bounced -> :cancelled terminal convergence shared by sync and Oban dispatch paths.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-04-26T18:40:49Z
- **Completed:** 2026-04-26T18:46:14Z
- **Tasks:** 4
- **Files modified:** 5

## Accomplishments

- `Executor.classify/1` now returns `{outcome, error_class, detail}` preserving the adapter's `:temporary | :permanent | :bounced` classification end-to-end (D-05).
- `Executor.run_delivery/1` forwards `error_class` into `Deliveries.record_attempt/2` while preserving the outer return shape — sync and Oban consumers compile and pass without modification at this plan boundary.
- `Deliveries.record_attempt/2` is now built on a 4-step `Ecto.Multi`: `:lock_delivery` (SELECT FOR UPDATE), `:next_attempt_number` (count + 1 under the lock), `:attempt` (insert with computed attempt_number), and `:delivery` (terminal_or_failed_transition fan-out). This makes `attempt_number` contiguity invariant under concurrent execution and converges permanent/bounced outcomes to `:cancelled` automatically.
- `cancel_with_reason/2` is the new private named-helper that writes `dispatched -> :cancelled` with `suppression_reason: "permanent_failure" | "bounced"`, mirroring the existing `exhaust_delivery/1 + suppress_delivery/3` idiom.
- `DeliveryAttempt.@required_fields` is promoted to `~w(delivery_id outcome attempt_number)a`. Direct-construction tests in `delivery_attempt_test.exs` were updated to inject `attempt_number` and a new explicit "rejects omitted attempt_number" test was added.
- `test/chimeway/dispatch/sync_test.exs` permanent/bounced/temporary describes assert the new convergence: permanent/bounced flow to `:cancelled` with the matching `suppression_reason`, temporary stays at `:failed`, and all three assert `attempt.error_class` + `attempt_number == 1` for REL-02 coverage.
- Telemetry `[:attempts, :record]` stop metadata now includes `attempt_number` and `error_class`, preserving Phase 10 correlation_id/notification_key keys.
- Full test suite passes: 227 tests, 0 failures, 27 skipped (pre-existing skips, unrelated to this plan).

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend Executor.classify/1 to return 3-tuple and plumb error_class through run_delivery/1** — `b5f5728` (feat)
2. **Task 2: Extend Deliveries.record_attempt/2 with row lock + attempt_number Multi step + permanent/bounced terminal convergence** — `04a74a8` (feat)
3. **Task 3: Promote attempt_number to a required field in DeliveryAttempt changeset** — `38e0ca6` (feat)
4. **Task 4: Update sync_test.exs permanent/bounced/temporary describes for sync convergence parity** — `aee9ae9` (test)

## Files Created/Modified

- `lib/chimeway/dispatch/executor.ex` — `classify/1` 3-tuple; `run_delivery/1` forwards `error_class`; module docstring documents the Phase 14 D-05 contract change.
- `lib/chimeway/deliveries.ex` — `record_attempt/2` rewritten with 4-step `Ecto.Multi`; new private helpers `terminal_or_failed_transition/3` and `cancel_with_reason/2`; added `import Ecto.Query, only: [from: 2]`; telemetry stop metadata enriched with `attempt_number` + `error_class`.
- `lib/chimeway/delivery_attempt.ex` — `@required_fields` promoted to `~w(delivery_id outcome attempt_number)a`; `@optional_fields` reduced to `error_class + provider_response`.
- `test/chimeway/dispatch/sync_test.exs` — permanent/bounced/temporary describes rewritten to assert `:cancelled` convergence (or `:failed` retention for temporary) plus `attempt.error_class` + `attempt_number == 1`.
- `test/chimeway/delivery_attempt_test.exs` — `valid_attrs/1` fixture now includes `attempt_number: 1`; added explicit `requires attempt_number` test and updated the previously "allows omitted" test to assert rejection (Plan 14-04 Task 3 contract).

## Decisions Made

- **Lock placement:** the `SELECT ... FOR UPDATE` step runs FIRST in the Multi (W8 preemptive fix). This serializes concurrent callers BEFORE the count read and the insert, making `attempt_number` contiguity an invariant under concurrent execution. The `pending -> dispatched` transition in `Executor.run_delivery/1` is a secondary serialization layer.
- **Convergence at record_attempt level:** routing `:permanent` / `:bounced` to `:cancelled` happens INSIDE `record_attempt/2` rather than at the dispatcher (Sync) or worker (Oban) layer. This eliminates duplication across sync and Oban paths and ensures both gain REL-03 convergence automatically without bespoke wiring.
- **Direct-write helper for terminal states:** `cancel_with_reason/2` bypasses `@allowed_transitions[:dispatched]` (which intentionally lacks `:cancelled`) and mirrors the existing `exhaust_delivery/1` + `suppress_delivery/3` idiom — explicit named helpers are the project's convention for terminal writes that don't fit the general transition table.
- **Test movement (revision B4):** sync_test.exs convergence assertions moved earlier from Plan 14-08 Task 2 to this plan so the suite stays green across waves; no rolling expected-failures.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated direct-construction tests in delivery_attempt_test.exs after attempt_number became required**

- **Found during:** Task 3 (promote attempt_number to required)
- **Issue:** Plan 14-02's unit tests in `test/chimeway/delivery_attempt_test.exs` constructed `DeliveryAttempt` changesets directly (not via `Deliveries.record_attempt/2`) with attrs that omitted `attempt_number`. Once Task 3 promoted the field to `@required_fields`, those tests started failing with `validate_required` errors. The plan's Task 3 acceptance criterion explicitly anticipated this: "Direct construction in tests... MUST now pass `attempt_number`. Verify no test file does this without going through `record_attempt/2` — if it does, the test will fail and the executor must update the test fixture." So this is in-scope.
- **Fix:** Updated `valid_attrs/1` fixture to include `attempt_number: 1`; updated the two test cases that constructed attrs directly (without `valid_attrs/1`) to include `attempt_number: 1`; added a new `"requires attempt_number"` test asserting the new rejection; converted the previous `"allows attempt_number to be omitted"` test into a `"rejects omitted attempt_number"` test asserting the new contract.
- **Files modified:** `test/chimeway/delivery_attempt_test.exs`
- **Verification:** `mix test test/chimeway/delivery_attempt_test.exs` exits 0 (16 tests pass).
- **Committed in:** `38e0ca6` (Task 3 commit, bundled with the production change).

---

**Total deviations:** 1 auto-fixed (Rule 1, in-scope test fixture update).
**Impact on plan:** Plan explicitly anticipated this in Task 3 acceptance. No scope creep — single test file updated alongside the production change in the same commit.

## Issues Encountered

None — all four tasks executed exactly as written. The intermediate state between Task 2 and Task 4 produced expected red sync_test.exs assertions (`assert delivery.status == :failed` for permanent/bounced — now `:cancelled`), which Task 4 addressed in the same plan boundary, leaving the suite green.

## TDD Gate Compliance

Plan-level TDD: not applicable — plan `type: execute`, not `type: tdd`. Individual `tdd="true"` tasks (Task 1 and Task 2) were verified against the existing comprehensive test suites (`deliveries_test.exs`, `oban_worker_test.exs`, `sync_test.exs`, `telemetry_correlation_test.exs`). Task 4 explicitly added the integration assertions for the new contract (`assert attempt.error_class == ...`, `assert delivery.suppression_reason == ...`).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Plan 14-05 (Oban worker retry contract) can now read `attempt.outcome` + `attempt.error_class` to map to `:ok | {:error, reason}` Oban return values without re-classifying.
- Plan 14-06 (telemetry handler tests) can assert on `attempt_number` and `error_class` keys in `[:attempts, :record]` stop metadata.
- Plan 14-07 (REL-02/REL-03 attempt history tests) has a stable contract for attempt_number contiguity (verified under concurrency by the row lock) and error_class persistence.
- Plan 14-08 sync convergence parity is already met here (per revision B4 movement); that plan's Task 2 has nothing further to do for sync.

## Self-Check: PASSED

Verified:

- `lib/chimeway/dispatch/executor.ex` — modified, contains `classify({:ok, meta}), do: {:succeeded, nil, meta}` and `error_class: error_class,`.
- `lib/chimeway/deliveries.ex` — modified, contains `Multi.run(:lock_delivery`, `lock: "FOR UPDATE"`, `Multi.run(:next_attempt_number`, `Map.put(safe_attrs, :attempt_number, n)`, `terminal_or_failed_transition`, `cancel_with_reason`, `"permanent_failure"`, `"bounced"`, and `import Ecto.Query, only: [from: 2]`.
- `lib/chimeway/delivery_attempt.ex` — modified, contains `@required_fields ~w(delivery_id outcome attempt_number)a`.
- `test/chimeway/dispatch/sync_test.exs` — modified, contains 3 occurrences of `delivery.status in Chimeway.Deliveries.terminal_states()`.
- `test/chimeway/delivery_attempt_test.exs` — modified, `valid_attrs/1` includes `attempt_number: 1`.
- Commits exist: `b5f5728` (Task 1), `04a74a8` (Task 2), `38e0ca6` (Task 3), `aee9ae9` (Task 4) — verified in `git log --oneline`.
- Full test suite green: 227 tests, 0 failures.

---
*Phase: 14-delivery-reliability-hardening*
*Plan: 04*
*Completed: 2026-04-26*

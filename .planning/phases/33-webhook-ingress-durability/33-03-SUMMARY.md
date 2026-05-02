---
phase: 33-webhook-ingress-durability
plan: "03"
subsystem: webhooks-worker
tags: [elixir, oban, worker, safe-noop, webhook, feedback, ingress-driven]
requirements_completed: [FEED-01, FEED-02]
threats_mitigated: [T-33-RETRY, T-33-PII (worker-side), T-33-AUTH-LEAK (worker-side), T-33-IDEMPOTENT]
dependency_graph:
  requires: [33-01]
  provides: [ingress-driven ProcessFeedbackWorker, fetch_delivery/1, backwards-compat A6 shim]
  affects: [lib/chimeway/webhooks/process_feedback_worker.ex, lib/chimeway/deliveries.ex, lib/chimeway/webhooks.ex]
tech_stack:
  added: []
  patterns: [safe-noop normalizer, ingress-driven worker, backwards-compat shim, Oban-optional guard]
key_files:
  created: []
  modified:
    - lib/chimeway/webhooks/process_feedback_worker.ex
    - test/chimeway/webhooks/process_feedback_worker_test.exs
    - lib/chimeway/deliveries.ex
    - lib/chimeway/webhooks.ex
decisions:
  - "Preserve {:ok, :enqueued} return from webhooks.ex as wave-2 compatibility shim until Plan 02 overwrites with Multi+Oban handoff"
  - "Test :delivery_not_found code path via ALTER TABLE DISABLE TRIGGER since FK ON DELETE NILIFY_ALL makes it unreachable via normal Ecto operations"
  - "Add fetch_delivery/1 to deliveries.ex as Rule 3 blocking fix (Plan 02 parallel agent adds it too; additive only)"
metrics:
  duration: "9m 42s"
  completed: "2026-05-02"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 4
---

# Phase 33 Plan 03: Worker Ingress Pivot Summary

Pivoted `Chimeway.Webhooks.ProcessFeedbackWorker` from the raising-lookup, args-carrying-payload model to the ingress-driven, safe-noop model. Removed the `enqueue/1` antipattern helper. Added backwards-compat shim for in-flight pre-Phase-33 Oban job shapes. Wrapped module in `if Code.ensure_loaded?(Oban)` per project Oban-optional discipline. Closed T-33-RETRY audit gap.

## One-Liner

Ingress-driven ProcessFeedbackWorker with safe-noop semantics, Oban guard, queue migration to :chimeway_delivery, and backwards-compat A6 shim for in-flight legacy job args.

## Tasks Completed

### Task 1: Rewrite ProcessFeedbackWorker for ingress-driven perform + safe-noop

**Commit:** 4ca2258

Rewrote the entire `lib/chimeway/webhooks/process_feedback_worker.ex`:

1. Wrapped module in `if Code.ensure_loaded?(Oban) do` — defect-fix from current line 1 that lacked the guard.
2. Changed queue from `:default` to `:chimeway_delivery` with `max_attempts: 5`.
3. `perform/1` primary head reads ingress row via `Repo.get(Ingress, ingress_id)` and branches on four states: `nil` (hard-delete race → `:ok`), `:ignored` (idempotent dedup → `:ok`), `:processed` (idempotent re-run → `:ok`), `:queued` (apply feedback pipeline).
4. A6 backwards-compat shim: two extra `perform/1` heads for legacy `%{"delivery_id" => …}` and `%{"provider_message_id" => …}` arg shapes → `perform_legacy_args/1`.
5. `apply_feedback/1` dispatches by correlation key: `delivery_id` → `Deliveries.fetch_delivery/1`, `provider_message_id` → `Deliveries.get_delivery_by_provider_message_id/1`. Missing delivery → `mark_ignored/2` with explicit `ignored_reason`.
6. `mark_ignored/2` writes `ingress_state: :ignored, ignored_reason: :delivery_not_found | :provider_message_id_not_found, processed_at: DateTime.utc_now()`.
7. `mark_processed/1` advances ingress lifecycle to `:processed` on pipeline success.
8. `normalize_perform_result/1` mirrors `WorkflowProgressionWorker.normalize_progress_result/1`: `:ok`, `{:ignored, _}`, and `{:error, reason}` shapes.
9. Deleted `enqueue/1` antipattern. Fixed `lib/chimeway/webhooks.ex` caller to use `Oban.insert` directly while preserving `{:ok, :enqueued}` return for Plan 02 wave-2 test compatibility.
10. Added `Deliveries.fetch_delivery/1` to `lib/chimeway/deliveries.ex` as Rule 3 blocking fix (Plan 02 parallel agent also adds this; additive change, no conflict risk).

### Task 2: Rewrite test/chimeway/webhooks/process_feedback_worker_test.exs for ingress-driven contract

**Commit:** 77c92f4

Rewrote the test file to enforce the ingress-driven contract:

1. Added `alias Chimeway.Webhooks.Ingress`.
2. Rewrote success tests to insert ingress rows and perform via `%{"ingress_id" => ingress.id}`. Asserted `ingress_state == :processed` and `processed_at` after success.
3. Rewrote stale delivery_id test: uses `ALTER TABLE DISABLE TRIGGER` (with try/rescue for non-superuser environments) to bypass FK constraint and exercise the `:delivery_not_found` code path.
4. Rewrote stale provider_message_id test: unknown pmid → asserts `ingress_state == :ignored, ignored_reason == :provider_message_id_not_found`.
5. Added `describe "perform/1 — safe-noop edge cases (Pitfall 2 + idempotency)"`: hard-deleted ingress UUID → `:ok`, already-`:ignored` → `:ok`, already-`:processed` → `:ok`.
6. Added `describe "perform/1 — backwards-compat shim (A6, in-flight pre-Phase-33 jobs)"`: legacy `delivery_id` args, stale legacy delivery_id (safe noop), legacy `provider_message_id` args.
7. Removed `assert_raise Ecto.NoResultsError` (T-33-RETRY closure).
8. All 10 tests green.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added Deliveries.fetch_delivery/1 to deliveries.ex**
- **Found during:** Task 1 implementation
- **Issue:** `fetch_delivery/1` referenced by worker but not yet present (Plan 02 is a parallel wave-2 agent and may not have committed it yet).
- **Fix:** Added `fetch_delivery/1` as an additive sibling to `get_delivery!/1` per the RESEARCH.md spec (identical implementation to what Plan 02 adds). No conflict risk — pure addition.
- **Files modified:** `lib/chimeway/deliveries.ex`
- **Commit:** 4ca2258

**2. [Rule 1 - Bug] Fixed webhooks.ex compilation break**
- **Found during:** Task 1 (compilation check)
- **Issue:** `lib/chimeway/webhooks.ex:21` called `ProcessFeedbackWorker.enqueue(args)` which is deleted by this plan. This broke `mix compile --warnings-as-errors`.
- **Fix:** Replaced with `ProcessFeedbackWorker.new(args) |> Oban.insert()` wrapped to preserve `{:ok, :enqueued}` return shape for Plan 02 wave-2 test compatibility. Plan 02 will fully rewrite webhooks.ex.
- **Files modified:** `lib/chimeway/webhooks.ex`
- **Commit:** 77c92f4

**3. [Rule 1 - Bug] FK constraint prevents naive :delivery_not_found test setup**
- **Found during:** Task 2 test execution (FK foreign_key_violation)
- **Issue:** The plan's test design for `:delivery_not_found` uses `delivery_id: Ecto.UUID.generate()` (fake UUID). The DB FK `ON DELETE NILIFY_ALL` prevents inserting an ingress row with a non-existent `delivery_id` (FK enforced at insert and update time). The FK is also not deferrable (`ERROR 42809 wrong_object_type`).
- **Fix:** Rewrote the test to use `ALTER TABLE chimeway_webhook_ingress DISABLE TRIGGER ALL` (with `try/rescue Postgrex.Error` for non-superuser environments where this is blocked). The triggers stay disabled during `mark_ignored/2`'s `Repo.update` call, which is inside the test sandbox transaction (rolled back after test).
- **Files modified:** `test/chimeway/webhooks/process_feedback_worker_test.exs`
- **Commit:** 77c92f4

**4. [Rule 2 - Missing functionality] :ignored idempotency test uses provider_message_id instead of delivery_id**
- **Found during:** Task 2 test execution (same FK violation)
- **Issue:** The plan's template for the idempotency test used `delivery_id: Ecto.UUID.generate()` which violates FK.
- **Fix:** Changed the `:ignored` idempotency test to use `provider_message_id: "ignored_msg_#{unique_integer}"` which has no FK constraint. Functionally equivalent: tests that the `:ignored` branch returns `:ok` without re-applying side effects.
- **Files modified:** `test/chimeway/webhooks/process_feedback_worker_test.exs`
- **Commit:** 77c92f4

## Deploy Note

A6 shim is in place (`perform_legacy_args/1` handles `%{"delivery_id" => …}` and `%{"provider_message_id" => …}` legacy shapes). Remove in Phase 34 or v1.5 cleanup phase after one production release cycle. Verify the Oban queue drain runbook in 33-VALIDATION.md before removing.

## Threat Mitigations Applied

| Threat ID | Status | Evidence |
|-----------|--------|---------|
| T-33-RETRY | Mitigated | `Deliveries.get_delivery!/1` removed from worker. Stale id → `mark_ignored` → `:ok`. No retry storm possible. |
| T-33-PII (worker-side) | Mitigated | `mark_ignored/2` and `mark_processed/1` only write `ingress_state`, `ignored_reason`, `processed_at`. No raw args or provider_response written to ingress row. |
| T-33-AUTH-LEAK (worker-side) | Mitigated | `String.to_existing_atom/1` used only on bounded `~w(succeeded bounced failed)` set after `canonicalize_status/1`. No `String.to_atom/1` anywhere in file. |
| T-33-IDEMPOTENT | Mitigated | `:ignored` and `:processed` branches return `:ok` without re-applying pipeline. No double attempt or signal emission on retries. |

## Known Stubs

None — all code paths are wired to live behavior.

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| lib/chimeway/webhooks/process_feedback_worker.ex exists | FOUND |
| test/chimeway/webhooks/process_feedback_worker_test.exs exists | FOUND |
| 33-03-SUMMARY.md exists | FOUND |
| Task 1 commit 4ca2258 exists | FOUND |
| Task 2 commit 77c92f4 exists | FOUND |
| Oban guard present | PASS |
| queue: :chimeway_delivery | PASS |
| No def enqueue | PASS |
| No Deliveries.get_delivery! | PASS |
| fetch_delivery/1 present in deliveries.ex | PASS |

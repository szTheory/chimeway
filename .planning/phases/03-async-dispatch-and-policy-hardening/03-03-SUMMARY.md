---
phase: 03-async-dispatch-and-policy-hardening
plan: "03-03"
subsystem: testing
tags: [oban, policy, integration, delayed-fallback, idempotency]
dependency_graph:
  depends_on: ["03-01", "03-02"]
  enables: ["phase-03-complete"]
tech_stack: [elixir, oban, ecto, exunit]
key_files:
  - test/support/chimeway/dispatch_helpers.ex
  - test/chimeway/dispatch/oban_worker_test.exs
  - test/chimeway/policy/delayed_fallback_test.exs
  - test/chimeway/dispatch/oban_transactional_test.exs
key_decisions:
  - Used Chimeway.Test.ObanWorkerFailingAdapter to avoid collision with Chimeway.FailingTestAdapter in oban_test.exs
  - Kept all Oban tests async:false to prevent Application.put_env races across test processes
requirements_closed: [DLVR-04, POLC-02, POLC-03, INTG-03]
duration: ~10 min
completed_at: "2026-04-24T09:28:50Z"
---

Added integration test coverage for the async Oban dispatch path, delayed fallback policy suppression, and transactional enqueue guarantees, closing DLVR-04, POLC-02, POLC-03, and INTG-03.

## Tasks

### 03-03-01: Test support helpers and ObanWorker failure-mode tests — DONE
- Created `test/support/chimeway/dispatch_helpers.ex` with `create_pending_delivery/1` and `mark_notification_read/1`
- Created `test/chimeway/dispatch/oban_worker_test.exs` covering: success path (1 attempt row, :succeeded), idempotency (2 performs → 1 attempt), all three terminal short-circuits (:succeeded, :suppressed, :cancelled return :ok with no adapter call), adapter error path (:failed with 1 attempt), retry after failure (2 attempt rows, :succeeded)
- All 7 tests pass

### 03-03-02: Delayed fallback end-to-end tests — DONE
- Created `test/chimeway/policy/delayed_fallback_test.exs` covering all four scenarios: unread notification (proceeds), read notification (`:already_read` suppression, 0 attempt rows, adapter not called), preference disabled post-enqueue (`:channel_disabled` suppression), sync dispatcher parity (POLC-02 sync path also suppresses on read state)
- All 5 tests pass

### 03-03-03: Transactional enqueue and rollback correctness tests — DONE
- Created `test/chimeway/dispatch/oban_transactional_test.exs` covering: committed multi makes job visible via `assert_enqueued`, rolled-back multi confirmed absent via `refute_enqueued`, duplicate dispatch idempotency (1 delivery row), sync dispatcher produces zero Oban jobs
- All 4 tests pass

## Verification

- [x] `mix test test/chimeway/dispatch/oban_worker_test.exs --seed 0` — 7/7 pass
- [x] `mix test test/chimeway/policy/delayed_fallback_test.exs --seed 0` — 5/5 pass
- [x] `mix test test/chimeway/dispatch/oban_transactional_test.exs --seed 0` — 4/4 pass
- [x] Security gate TM-03-03-TEST-ADAPTER-LEAK: `Adapters.Test.clear()` present in all setup blocks
- [x] Security gate TM-03-03-SHARED-APP-ENV: `async: false` in all three test modules
- [x] `mix test --seed 0` — 99 tests, 0 failures

## Deviations

None — plan executed as specified. The linter auto-formatted helper and test files during creation; final content matches plan requirements exactly.

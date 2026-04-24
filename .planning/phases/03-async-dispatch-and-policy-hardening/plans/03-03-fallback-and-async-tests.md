---
plan: 03-03
phase: 3
title: Add Delayed Fallback Behavior Tests and Async Failure-Mode Verification
status: not_started
requirements: [DLVR-04, POLC-02, POLC-03, INTG-03]
depends_on: [03-01, 03-02]
---

# Plan 03-03: Add Delayed Fallback Behavior Tests and Async Failure-Mode Verification

## Goal
Verify the correctness of the async Oban path, late policy suppression, and delayed fallback behavior through dedicated integration and property tests, ensuring idempotency, trace completeness, and suppression accuracy are confirmed before the phase is considered done.

## Context
After 03-01 and 03-02, the system has: a `Chimeway.Dispatch` behaviour with sync and Oban implementations, an `ObanWorker` with perform-time policy evaluation, a `NotificationPreference` schema, `Chimeway.Policy.evaluate/2` at both pipeline checkpoints, `delay_fallback` on delivery rows, and `suppression_reason` persistence. What does not yet exist is a systematic test suite for the async worker failure modes, idempotency under retry, the full delayed-fallback scenario from trigger to suppression, and a contract test confirming the Oban integration seam matches the documented guide. This plan adds those tests without adding new production modules.

## Tasks

### Task 1: Async Worker Idempotency and Failure-Mode Tests
**What**: Write a test module `test/chimeway/dispatch/oban_worker_test.exs` that uses `Oban.Testing` helpers (`use Oban.Testing, repo: Chimeway.Repo`) to exercise the worker directly via `perform_job/2`. Cover these scenarios: (1) worker succeeds and creates exactly one attempt row; (2) worker is run a second time for the same delivery (simulate a retry) — confirm no duplicate attempt row is created and the delivery status is not regressed from a terminal state; (3) worker runs against a delivery already in `:suppressed` or `:succeeded` state — confirm it returns `:ok` immediately without calling the adapter; (4) adapter returns an error — confirm attempt row is created with `status: :failed` and delivery transitions to a failed state, allowing Oban retry; (5) adapter raises an exception — confirm Oban retries the job and the delivery row does not get corrupted. Use `Mox` for the adapter and assert call counts.

**Where**:
- `test/chimeway/dispatch/oban_worker_test.exs` — new test file; uses `Oban.Testing`, `Mox`, and the test Repo
- `test/support/test_helpers.ex` (or equivalent) — add helpers for creating seeded delivery fixtures in dispatchable and terminal states

**Acceptance criteria**:
- [ ] Re-running the worker for the same delivery ID creates exactly one attempt row total (idempotency under retry)
- [ ] Worker called on a `:succeeded` delivery returns `:ok` without adapter call (confirmed via Mox `expect` 0 calls)
- [ ] Worker called on a `:suppressed` delivery returns `:ok` without adapter call
- [ ] Adapter error causes delivery to transition to `:failed` and Oban to allow retry
- [ ] Adapter exception does not leave delivery in inconsistent state
- [ ] All assertions confirmed in CI with `mix test --only oban_integration` or tagged equivalent

**Done when**: Five worker failure scenarios are covered by passing tests under `Oban.Testing` sandbox mode.

---

### Task 2: Delayed Fallback End-to-End Tests
**What**: Write a test module `test/chimeway/policy/delayed_fallback_test.exs` that exercises the full delayed-fallback suppression path end-to-end. Cover: (1) trigger with `delay_fallback: true` delivery -> notification is NOT read -> Oban job performs -> adapter is called (normal send path); (2) trigger with `delay_fallback: true` delivery -> simulate user reading the notification (set `read_at` on the `notify_notifications` row) -> Oban job performs -> delivery is suppressed with reason `:already_read`, adapter is NOT called; (3) trigger with `delay_fallback: true` delivery -> preference is disabled after enqueue -> Oban job performs -> delivery is suppressed with preference reason, adapter NOT called; (4) sync dispatcher with `delay_fallback: true` and read in-app state — confirm sync path also suppresses. Each test must assert the suppression reason on the delivery row, confirm the attempt count is zero for suppressed cases, and confirm the adapter mock call count.

**Where**:
- `test/chimeway/policy/delayed_fallback_test.exs` — new test file using the full stack (Repo, Oban sandbox, Mox adapter)
- `test/support/notification_factories.ex` (or equivalent) — factory helpers for creating notifications with controlled `read_at` state

**Acceptance criteria**:
- [ ] Unread notification + delay_fallback: adapter receives call, delivery status is `:succeeded`
- [ ] Read notification + delay_fallback: adapter receives NO call, delivery `suppression_reason` is `:already_read`
- [ ] Preference disabled after enqueue + delay_fallback job: adapter receives NO call, suppression reason is preference-related
- [ ] Sync dispatcher: same read-state suppression behavior confirmed (POLC-02 sync path)
- [ ] All four scenarios pass in CI

**Done when**: All four delayed-fallback scenarios are covered by passing integration tests that assert on delivery state, suppression reason, and adapter call counts.

---

### Task 3: Transactional Enqueue and Rollback Tests
**What**: Write tests in `test/chimeway/dispatch/oban_transactional_test.exs` that confirm the transactional enqueue contract (INTG-03). Cover: (1) successful transaction — delivery row and Oban job are both visible after commit; (2) transaction rollback — neither delivery row nor Oban job is visible after rollback; (3) trigger two identical events with the same idempotency key in separate transactions — second transaction results in idempotency suppression with no duplicate delivery row or duplicate job; (4) confirm that when `Chimeway.Dispatch.Sync` is configured, no Oban job insertion happens (Oban job table has no new rows).

**Where**:
- `test/chimeway/dispatch/oban_transactional_test.exs` — new test file using `Ecto.Multi` and `Oban.Testing`

**Acceptance criteria**:
- [ ] Committed `Ecto.Multi` makes both delivery row and Oban job queryable
- [ ] Rolled-back `Ecto.Multi` leaves neither delivery row nor Oban job in the database
- [ ] Duplicate idempotency key does not create a second delivery row or job
- [ ] `Chimeway.Dispatch.Sync` configuration results in zero Oban job inserts
- [ ] All assertions pass under `Oban.Testing` sandbox

**Done when**: Transactional enqueue correctness is confirmed: commit and rollback semantics are both verified, and idempotency under double-trigger is confirmed at the job layer.

## Verification
**This plan is complete when**:
- [ ] `Chimeway.Dispatch.ObanWorker` idempotency is verified: repeated perform of same delivery creates exactly one attempt row
- [ ] Terminal-state short-circuit is verified: worker returns `:ok` on already-succeeded/suppressed deliveries without adapter call
- [ ] Delayed fallback suppression (POLC-03) is verified end-to-end for both Oban and sync dispatch paths
- [ ] Transactional rollback removes both delivery row and Oban job (INTG-03)
- [ ] Idempotency under duplicate trigger does not create duplicate jobs
- [ ] All tasks done conditions are met
- [ ] `mix test` passes for this plan's scope

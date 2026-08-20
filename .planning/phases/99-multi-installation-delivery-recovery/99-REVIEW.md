---
phase: 99-multi-installation-delivery-recovery
reviewed: 2026-08-20T01:59:13Z
depth: standard
files_reviewed: 23
files_reviewed_list:
  - lib/chimeway/delivery_planning.ex
  - lib/chimeway/delivery_targets.ex
  - lib/chimeway/dispatch/executor.ex
  - lib/chimeway/dispatch/oban.ex
  - lib/chimeway/dispatch/oban_worker.ex
  - lib/chimeway/dispatch/recovery_worker.ex
  - lib/chimeway/dispatch/sync.ex
  - lib/chimeway/safe_evidence.ex
  - lib/chimeway/target_adapter.ex
  - lib/chimeway/target_recovery.ex
  - lib/chimeway/traces.ex
  - priv/chimeway_migrations/035_create_chimeway_delivery_targets.exs
  - priv/repo/migrations/20260819000001_create_chimeway_delivery_targets.exs
  - test/chimeway/delivery_target_test.exs
  - test/chimeway/dispatch/target_worker_test.exs
  - test/chimeway/install/golden_diff_test.exs
  - test/chimeway/install/prefix_contract_test.exs
  - test/chimeway/migration_contract_test.exs
  - test/chimeway/orchestration/target_recovery_test.exs
  - test/chimeway/runtime_prefix_integration_test.exs
  - test/chimeway/tenant_scope_contract_test.exs
  - test/chimeway/traces_target_test.exs
  - test/support/prefixed_runtime_case.ex
findings:
  critical: 4
  warning: 2
  info: 0
  total: 6
status: issues_found
---

# Phase 99: Code Review Report

**Reviewed:** 2026-08-20T01:59:13Z
**Depth:** standard
**Files Reviewed:** 23
**Status:** issues_found

## Summary

The copied and direct migrations are materially equivalent and the focused Phase 99 tests pass, but the dispatch/recovery implementation still has shipping blockers. In particular, the synchronous dispatcher does not fan out, queued push work can bypass a newly terminal parent delivery, and target retry/claim logic can either run past its configured Oban budget or overwrite an ambiguity decision.

## Critical Issues

### CR-01: Sync push dispatch sends to only one selected installation

**File:** `lib/chimeway/dispatch/sync.ex:113-117`

**Issue (BLOCKER):** The push branch calls `Executor.run_target(delivery)` once. `begin_target_attempt/2` deliberately selects only the first pending target when no `:target_id` is supplied (`delivery_targets.ex:109-118`). Consequently a resolver returning two eligible bindings produces two durable targets, but synchronous dispatch sends only the first and returns the parent delivery as succeeded; the remaining target stays pending indefinitely. The included sync test uses a single-target resolver and cannot expose the failure.

**Fix:** For a push delivery, load all tenant-qualified pending targets and execute each by ID (or make `Executor.run_target/2` fan out atomically at the dispatcher boundary). Recompute/return the parent only after all selected targets have reached their appropriate state, and add a two-target sync test.

### CR-02: Queued target job can send after the logical delivery is suppressed, cancelled, or deferred

**File:** `lib/chimeway/dispatch/oban_worker.ex:121-129`

**Issue (BLOCKER):** The target-job clause obtains the parent through `fetch_target_delivery/2` and immediately calls `run_target/2`. Neither this worker nor `begin_target_attempt/2` verifies that the parent is still `status: :pending` and `orchestration_state: :ready`. A job enqueued while the delivery was eligible will therefore still call the provider after a concurrent policy suppression, cancellation, or deferral. `record_target_result/4` can then overwrite the parent with `:succeeded`.

**Fix:** Claim the target through a single transaction/query that joins and locks the delivery and requires its tenant, pending status, and ready orchestration state. Return a non-disclosing noop when that predicate no longer holds. Add race coverage for suppress/cancel/defer between enqueue and perform.

### CR-03: Target retries are unbounded after Oban exhausts the job

**File:** `lib/chimeway/dispatch/oban_worker.ex:121-129`

**Issue (BLOCKER):** A `:pre_handoff_retryable` result is persisted by the executor as a `:pending` target and returned as `{:error, :pre_handoff_retryable}`. Unlike the delivery-id worker, the target-id worker does not inspect `attempt`/`max_attempts` or call `DeliveryTargets.exhaust_target/3` on its final execution. Oban discards the job after five tries, but the target remains pending; every future recovery scan (`target_recovery.ex:87-101`) invokes the provider again. This defeats the bounded retry contract and can create unlimited provider requests.

**Fix:** Include `attempt` and `max_attempts` in the target-worker clause. On a retryable pre-handoff result at the final attempt, atomically transition that exact target to `:retry_exhausted`, append the terminal evidence, recompute the delivery, and return `:ok`. Add a max-attempts test which proves recovery does not resend it.

### CR-04: A late provider success can overwrite a stale-handoff ambiguity decision

**File:** `lib/chimeway/delivery_targets.ex:302-325`

**Issue (BLOCKER):** `record_target_result/4` updates the caller-supplied target and attempt structs without reloading/locking them or requiring `target.status == :claimed` and `attempt.outcome == :attempt_started`. If the provider call exceeds the 60-second lease, recovery can lock the rows and close them as `:ambiguous_handoff` (`close_stale_started_attempt/2` at lines 178-217). When the original provider call subsequently returns success, this method writes the stale structs back as `:provider_accepted`, erasing the deliberately conservative ambiguity and potentially racing a policy-authorized redrive.

**Fix:** Mirror `record_target_failure/4`: in one transaction, tenant-qualify and lock the target and attempt, require the claimed/open states and the expected IDs, then update them. If they are no longer eligible, return a noop/conflict without changing the recovered evidence. Add an interleaving test for lease expiry/closeout followed by a late adapter response.

## Warnings

### WR-01: Recovery records arbitrary executor/database errors as target invalidation

**File:** `lib/chimeway/target_recovery.ex:186-191`

**Issue (WARNING):** The catch-all `{:error, _}` treats all failures as `:skipped_invalidated`. This includes persistence failures while closing an attempt, unsafe-result validation failures, and other internal errors that have no relationship to binding invalidation. The recovery summary consequently gives operators a false reason and hides actionable failures.

**Fix:** Match only a documented invalidation/not-found result as `:skipped_invalidated`; preserve all other errors as a distinct closed recovery reason (for example `:recovery_failed`) and emit safe error-class evidence/counters.

### WR-02: Most operator trace APIs silently omit target and target-attempt history

**File:** `lib/chimeway/traces.ex:140-145`

**Issue (WARNING):** `get_trace/2` preloads target history, but `find_traces_for_recipient/2` and `find_traces_by_correlation_id/2` preload only delivery attempts (lines 140-145 and 174-182). `explain_delivery/2` likewise preloads only parent attempts (line 211) and its timeline does not include target attempts. `SafeEvidence.trace_notification/1` maps an unloaded `targets` association to an empty list, so these normal operator views misleadingly show no installation-level truth for push deliveries.

**Fix:** Use the same tenant-qualified target/target-attempt preload used by `get_trace/2` in every trace projection, and extend the delivery explanation/timeline with safe target-attempt entries. Cover recipient, correlation, and explanation calls with a push delivery containing multiple targets.

---

_Reviewed: 2026-08-20T01:59:13Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_

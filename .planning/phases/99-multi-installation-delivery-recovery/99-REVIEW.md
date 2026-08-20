---
phase: 99-multi-installation-delivery-recovery
reviewed: 2026-08-20T00:38:07Z
depth: standard
files_reviewed: 22
files_reviewed_list:
  - lib/chimeway/delivery_planning.ex
  - lib/chimeway/delivery_targets.ex
  - lib/chimeway/dispatch/executor.ex
  - lib/chimeway/dispatch/oban.ex
  - lib/chimeway/dispatch/oban_worker.ex
  - lib/chimeway/dispatch/recovery_worker.ex
  - lib/chimeway/dispatch/sync.ex
  - lib/chimeway/safe_evidence.ex
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

**Reviewed:** 2026-08-20T00:38:07Z
**Depth:** standard
**Files Reviewed:** 22
**Status:** issues_found

## Summary

The target claim itself is transactionally serialized, but the recovery implementation does not meet its durable, bounded recovery contract. It misses the stated trigger-without-notification interruption, cannot paginate event and target streams correctly, scans stale work without a bound, and discards the recovery evidence it claims to record. Target adapter failures also leave a started attempt indefinitely claimed instead of recording an honest terminal or retryable outcome.

## Critical Issues

### CR-01: Trigger-committed events with no notification are never recovered

**Classification:** BLOCKER

**File:** `lib/chimeway/target_recovery.ex:51-59`

**Issue:** `discover_stranded_events/2` uses an inner join to `Notification`. The required interruption is precisely an event committed before any notification is planned; such an event has no matching notification and is removed before `having: count(d.id) == 0` can consider it. It will remain stranded forever.

**Fix:** Start from the tenant-scoped event with a left join to notifications (and deliveries), then explicitly select events with no notifications or with notifications that have no deliveries. Add a test that inserts only the committed event and proves recovery creates its notification/delivery exactly once.

### CR-02: One target cursor is incorrectly used to page the independent event stream

**Classification:** BLOCKER

**File:** `lib/chimeway/target_recovery.ex:23-25,49,65,76,90`

**Issue:** `recover_tenant/2` passes the same opaque `:cursor` to both discovery queries but returns only `targets.cursor`. Event and target IDs are separate UUID streams, so a returned target ID can skip stranded events whose IDs sort below it. Conversely, when the target page is empty the returned cursor is nil, so a tenant with more than one page of stranded events can never advance past the first page. This makes bounded event recovery incomplete.

**Fix:** Use independent, typed cursors (for example `%{event: event_id, target: target_id}` encoded as an opaque validated token) and return both next cursors, or run exactly one stream per worker/job with a cursor bound to that stream. Test more than a batch of event-only gaps and interleaved UUID order across both tables.

### CR-03: Recovery is unbounded because stale-attempt closure ignores its page limit

**Classification:** BLOCKER

**File:** `lib/chimeway/target_recovery.ex:113-133`

**Issue:** Every `recover_tenant/2` run loads all expired started attempts for the tenant and loops through all of them. `close_stale_attempts/2` ignores the supplied batch size and cursor, so one worker invocation can perform unbounded database mutations despite the advertised hard maximum of 100. A large tenant can monopolize recovery workers and prevents the required bounded recovery behavior.

**Fix:** Make stale-attempt discovery a separately keyset-paginated query with the same validated maximum, and include its cursor in the recovery continuation contract. Claim/close only the bounded selected IDs in deterministic order.

### CR-04: Target adapter errors leave the target claimed with only an open attempt

**Classification:** BLOCKER

**File:** `lib/chimeway/dispatch/executor.ex:68-78`

**Issue:** Once `begin_target_attempt/2` succeeds, any `{:error, ...}` or unexpected return from `target_adapter().deliver/2` exits the `with` directly. No result, failure, retry, or ambiguity transition is written, so the target remains `:claimed` until the lease expires. Subsequent Oban retries receive `{:noop, :no_eligible_target}` and do not retry delivery; later recovery can only classify the unknown handoff as ambiguous. Definite provider failures are therefore silently stranded and the recorded lifecycle is incomplete.

**Fix:** Wrap the adapter call and atomically finalize the claimed target attempt on every outcome. Preserve the conservative rule by marking unclassifiable/post-handoff errors `:ambiguous_handoff`; for explicitly retryable/pre-handoff failures, persist a closed retryable state and schedule a controlled retry. Add failure-path tests asserting no open claimed target remains.

## Warnings

### WR-01: Recovery worker discards the only closed recovery summary

**Classification:** WARNING

**File:** `lib/chimeway/dispatch/recovery_worker.ex:16-17`

**Issue:** `TargetRecovery.recover_tenant/2` constructs a safe summary, but the worker assigns it to `_result` and returns `:ok`. No durable record, telemetry event, trace entry, or log receives the claimed/skipped/ambiguous result. This violates the phase requirement that recovery decisions be explainable and makes operational diagnosis impossible after the job completes.

**Fix:** Emit the `SafeEvidence.recovery_summary/1` result through a closed telemetry/evidence seam (or persist a tenant-scoped recovery record), and test that every worker outcome records only the approved fields.

### WR-02: Recovery reports adapter errors as invalidation

**Classification:** WARNING

**File:** `lib/chimeway/target_recovery.ex:136-153`

**Issue:** Any `Executor.run_target/2` error is summarized as `:skipped_invalidated`. An adapter outage, database failure, and malformed target are materially different states; relabeling all of them as invalidation produces false recovery evidence and hides failures that require attention.

**Fix:** Return a closed, accurate reason for each known executor outcome (and a distinct approved failure token for unknown/internal failures), while keeping the externally visible DTO non-disclosing.

---

_Reviewed: 2026-08-20T00:38:07Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_

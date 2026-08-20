---
phase: 99-multi-installation-delivery-recovery
reviewed: 2026-08-20T00:00:00Z
depth: standard
files_reviewed: 24
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
  - lib/chimeway/traces/explanation.ex
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
  critical: 2
  warning: 0
  info: 0
  total: 2
status: issues_found
---

# Phase 99: Code Review Report

**Reviewed:** 2026-08-20T00:00:00Z
**Depth:** standard
**Files Reviewed:** 24
**Status:** issues_found

## Summary

The target lifecycle generally scopes queries by tenant and projects evidence through the closed trace seam. However, the Oban entry point does not converge an empty target snapshot, and the stale-recovery path reverses the required parent/target lock order. Both defects violate the Phase 99 no-stranding and race-safe recovery contracts. The focused target, worker, recovery, and tenant suites passed (33 tests), but do not exercise either interleaving.

## Critical Issues

### BL-01: Oban push dispatch strands deliveries with an empty target snapshot

**Classification:** BLOCKER

**File:** `/Users/jon/projects/chimeway/lib/chimeway/dispatch/oban.ex:108-122`

**Issue:** `enqueue_delivery/1` enumerates pending push targets and returns `{:ok, []}` when there are none. `dispatch_delivery/2` normalizes that as success, but no job is created and the delivery remains `:pending`; it is never given the required `no_eligible_targets` suppression reason. This public entry point can be reached with an existing/canonical push delivery (including a partial or interrupted planning flow), so it permanently strands work and makes its explanation incorrect. Sync correctly invokes `recompute_delivery/2` for the same condition.

**Fix:** When `actionable_targets/1` is empty, atomically recompute the tenant-qualified parent before returning. Require the resulting status to be `:suppressed` with `no_eligible_targets`; otherwise surface an error instead of reporting a successful enqueue.

### BL-02: Stale closeout reverses the parent/target lock order and can crash recovery on a deadlock

**Classification:** BLOCKER

**File:** `/Users/jon/projects/chimeway/lib/chimeway/delivery_targets.ex:183-225`

**Issue:** `close_stale_started_attempt/2` locks the target first (lines 184-192) and then calls `recompute_delivery/2`, which locks its parent (lines 579-585). `begin_target_attempt/2` and `record_target_result/4` acquire those same rows in the opposite parent-then-target order (lines 94-116 and 335-353). A late adapter finalizer racing recovery can therefore form a PostgreSQL deadlock. Further, this function's result `case` only handles `{:ok, _}` and `{:error, :not_found}` (lines 229-232), so a deadlock/transaction error raises `CaseClauseError` and aborts the bounded recovery pass rather than yielding a safe, retryable outcome.

**Fix:** Lock the tenant-qualified parent first, then its target and started attempt, matching all claim/finalization transitions; calculate and persist the aggregate within that guarded transaction. Also return `{:error, reason}` for non-`not_found` transaction failures (or convert only explicitly retryable database conflicts to a non-disclosing retry result), and add a deterministic closeout-versus-finalizer concurrency test.

---

_Reviewed: 2026-08-20T00:00:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_

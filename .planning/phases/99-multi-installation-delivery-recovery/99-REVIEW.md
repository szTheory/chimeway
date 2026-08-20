---
phase: 99-multi-installation-delivery-recovery
reviewed: 2026-08-20T14:42:25Z
depth: standard
files_reviewed: 25
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
  - test/chimeway/dispatch/oban_test.exs
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
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---

# Phase 99: Code Review Report

**Reviewed:** 2026-08-20T14:42:25Z
**Depth:** standard
**Files Reviewed:** 25
**Status:** issues_found

## Summary

The submitted delivery-target state machine, dispatch paths, recovery worker, migrations, and operator projections were reviewed. Target terminal-state integrity is not enforced by the public transition API, allowing an already accepted target to be made eligible for another provider handoff. The target tables also allow cross-tenant foreign-key relationships at the database layer, despite tenant ownership being a core boundary.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Generic retry transition can resend an already accepted target

**File:** `lib/chimeway/delivery_targets.ex:640`

**Issue:** `schedule_retry/3` delegates to `transition_target/4`, but the latter only checks the target ID and tenant (lines 645-650). It does not require a retryable source state. Consequently, any caller holding the tenant-qualified delivery can call `schedule_retry/3` for a `:provider_accepted` target, which changes it to `:pending` (line 657). The next sync, Oban, or recovery pass treats that row as actionable and calls the provider again, producing a duplicate delivery after a previously durable success. The same unrestricted primitive also permits `expire_target/3` and `invalidate_target/3` to rewrite terminal outcomes.

**Fix:** Make transitions explicit and enforce an allowed source-state matrix under the row lock. In particular, only allow `:failed` (or another documented retryable state) to move to `:pending`; require the separate policy-authorized redrive path for `:ambiguous_handoff`; reject terminal accepted/exhausted states.

```elixir
where:
  t.id == ^target_id and t.delivery_id == ^delivery.id and
    t.tenant_id == ^tenant_id and t.status in ^allowed_from_states(status)

if is_nil(target), do: Repo.rollback(:invalid_transition)
```

Define `allowed_from_states/1` per operation rather than exposing a generic arbitrary-status mutator, and add a test that attempting to retry a `:provider_accepted` target neither changes it nor invokes the adapter.

## Warnings

### WR-01: Migrations permit cross-tenant target and attempt relationships

**File:** `priv/chimeway_migrations/035_create_chimeway_delivery_targets.exs:12`

**Issue:** The target table stores `tenant_id` independently but its foreign key to `chimeway_deliveries` is only `delivery_id` (lines 12-16). The attempt table has the same issue for `delivery_target_id` (lines 39-43), and `prior_attempt_id` is unconstrained to the same target or tenant (line 50). The generated public migration repeats this at `priv/repo/migrations/20260819000001_create_chimeway_delivery_targets.exs:9` and `:30`. Application query filters hide many malformed rows, but the database accepts them; a bad write can poison a tenant's lifecycle history or block the global `(delivery_id, binding_revision_ref)` target identity constraint with a different tenant.

**Fix:** Enforce ownership structurally. Add unique keys on `(tenant_id, id)` for the parent tables and composite foreign keys from `(tenant_id, delivery_id)` to deliveries and from `(tenant_id, delivery_target_id)` to targets. For `prior_attempt_id`, either validate it belongs to the same target in a trigger/transaction or model a composite reference that includes the target identity. Add migration-contract tests that cross-tenant inserts fail with a foreign-key violation.

---

_Reviewed: 2026-08-20T14:42:25Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_

---
phase: 97-tenant-identity-compatible-upgrade
reviewed: 2026-08-12T16:14:19Z
depth: standard
files_reviewed: 44
files_reviewed_list:
  - chimeway_admin/lib/chimeway_admin/context.ex
  - chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex
  - chimeway_admin/lib/chimeway_admin/live/definitions_live.ex
  - chimeway_admin/lib/chimeway_admin/live/feed_live.ex
  - chimeway_admin/lib/chimeway_admin/live/health_live.ex
  - chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex
  - chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex
  - chimeway_admin/lib/chimeway_admin/live_auth.ex
  - chimeway_admin/test/chimeway_admin/live/definitions_live_test.exs
  - chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs
  - chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs
  - chimeway_inbox/lib/chimeway_inbox/auth.ex
  - chimeway_inbox/lib/chimeway_inbox/live/bell_dropdown_live.ex
  - chimeway_inbox/lib/chimeway_inbox/live_auth.ex
  - examples/chimeway_demo_host/lib/demo_host/inbox_auth.ex
  - examples/chimeway_demo_host/lib/demo_host/seeds.ex
  - lib/chimeway.ex
  - lib/chimeway/admin.ex
  - lib/chimeway/deliveries.ex
  - lib/chimeway/events/event.ex
  - lib/chimeway/inbox.ex
  - lib/chimeway/notifications/notification.ex
  - lib/chimeway/reconciliation.ex
  - lib/chimeway/tenant_scope.ex
  - lib/chimeway/traces.ex
  - lib/chimeway/trigger.ex
  - lib/mix/tasks/chimeway.reconcile_tenants.ex
  - priv/chimeway_migrations/032_add_tenant_identity_to_events_and_notifications.exs
  - priv/repo/migrations/20260812000000_add_tenant_identity_to_events_and_notifications.exs
  - test/chimeway/admin_test.exs
  - test/chimeway/inbox_query_test.exs
  - test/chimeway/inbox_state_transition_test.exs
  - test/chimeway/install/migrations_test.exs
  - test/chimeway/migration_contract_test.exs
  - test/chimeway/mix/tasks/reconcile_tenants_test.exs
  - test/chimeway/orchestration/recovery_test.exs
  - test/chimeway/reconciliation_test.exs
  - test/chimeway/tenant_identity_test.exs
  - test/chimeway/tenant_scope_contract_test.exs
  - test/chimeway/traces_test.exs
  - test/fixtures/installer_golden_prefixed/tree/priv/repo/migrations/TIMESTAMP_add_tenant_identity_to_events_and_notifications.exs
  - test/fixtures/installer_golden_public/tree/priv/repo/migrations/TIMESTAMP_add_tenant_identity_to_events_and_notifications.exs
  - test/support/chimeway/dispatch_helpers.ex
  - test/support/data_case.ex
findings:
  critical: 1
  warning: 2
  info: 0
  total: 3
status: issues_found
---

# Phase 97: Code Review Report

**Reviewed:** 2026-08-12T16:14:19Z
**Depth:** standard
**Files Reviewed:** 44
**Status:** issues_found

## Summary

The tenant scope is generally propagated through the new read and recovery paths, but the submitted migration cannot be rolled back after valid multi-tenant activity. Tenant identity is also normalized inconsistently at the trigger write boundary, and an authorized inbox LiveView can crash instead of denying access when its resolved identity changes.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Tenant migration rollback fails after valid cross-tenant idempotency use

**File:** `priv/repo/migrations/20260812000000_add_tenant_identity_to_events_and_notifications.exs:33`

**Issue:** The `up` migration intentionally permits the same `idempotency_key` in different tenants by replacing the global unique index with `(tenant_id, idempotency_key)`. After two such valid events exist, `down` tries to create the old globally-unique index before removing tenant data. PostgreSQL rejects that index creation because duplicate `idempotency_key` values already exist, making rollback impossible precisely after normal use of the new feature. The installer migration has the same defect at `priv/chimeway_migrations/032_add_tenant_identity_to_events_and_notifications.exs:36`.

**Fix:** Make the migration explicitly irreversible after tenant-scoped idempotency is enabled (raise a clear migration error in `down`), or define and document a deterministic, loss-aware downgrade procedure that removes or remaps conflicting rows before recreating the global index. Apply the same behavior to both migration artifacts and add a migration test with two tenants sharing one key.

## Warnings

### WR-01: Trigger persists an uncanonical tenant identity that all scoped readers cannot resolve

**File:** `lib/chimeway/trigger.ex:141-163`

**Issue:** `validate_tenant_id/1` accepts a tenant such as `" tenant-a "`, but it returns only `:ok`; `do_trigger/7` subsequently persists the original whitespace-padded value to events and notifications. Every scoped read uses `TenantScope.resolve/1`, which trims the same input to `"tenant-a"` (`lib/chimeway/tenant_scope.ex:19-23`). Consequently, a valid trigger call can create a lifecycle tree that cannot be found, read, or recovered with that tenant identity. It also creates a distinct composite-idempotency namespace for the padded spelling.

**Fix:** Have `fetch_tenant_id/1` (or `validate_tenant_id/1`) return `{:ok, String.trim(tenant_id)}` and pass that normalized value through the trigger and dispatch options. Add a regression test that triggers with padded input and can retrieve the resulting trace with the canonical tenant ID.

### WR-02: Inbox authorization crashes for a valid but changed recipient or tenant

**File:** `chimeway_inbox/lib/chimeway_inbox/live_auth.ex:39-48`

**Issue:** `ensure_authorized/2` handles a matching resolved context and an error result, but has no clause for `{:ok, recipient_identity, tenant_id}` when either value differs from the original socket assignment. That valid tuple causes `CaseClauseError`, terminating the LiveView instead of redirecting/denying access. This is reachable when a user changes active tenant or authenticates as a different user while a LiveView remains connected.

**Fix:** Add a catch-all valid-context branch that redirects as unauthorized, for example:

```elixir
      {:ok, _recipient_identity, _tenant_id} ->
        {:error, redirect(socket, to: unauthorized_redirect())}
```

Add a LiveView test covering both recipient and tenant changes during an event handler.

---

_Reviewed: 2026-08-12T16:14:19Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_

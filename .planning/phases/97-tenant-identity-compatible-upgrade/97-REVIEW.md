---
phase: 97-tenant-identity-compatible-upgrade
reviewed: 2026-08-12T17:14:06Z
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
  critical: 3
  warning: 1
  info: 0
  total: 4
status: issues_found
---

# Phase 97: Code Review Report

**Reviewed:** 2026-08-12T17:14:06Z
**Depth:** standard
**Files Reviewed:** 44
**Status:** issues_found

## Summary

The tenant scope is applied to most top-level reads and new trigger writes, but the implementation permits inconsistent tenant identities within a lifecycle tree and then exposes or silently breaks those rows in admin and reconciliation paths. One admin event handler also skips the stated per-event authorization check. Focused tenant tests passed, but they do not cover these paths.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Reconciliation assigns a partial lifecycle tree and can create cross-tenant ownership

**File:** `lib/chimeway/reconciliation.ex:95`

**Issue:** The reconciliation transaction locks and checks only notifications, then updates only the event and notification rows (lines 95-117). Deliveries already have `tenant_id` from the earlier delivery migration, but are neither checked nor updated. On an upgrade, assigning a legacy event/notification tree to the host-selected tenant can leave its deliveries owned by a different tenant (commonly the historical default). Tenant-scoped traces and recovery then omit those deliveries, while admin joins can associate them with the newly assigned event. This breaks the durable lifecycle spine and tenant isolation immediately after the supported reconciliation operation.

**Fix:** Lock the event's deliveries as part of the same transaction. Either reject any delivery whose tenant differs from the requested tenant with `:ownership_conflict`, or, if the documented migration policy permits it, update only `NULL` delivery tenants atomically and include delivery counts in the report/result. Add a test containing an event and notification with `NULL` ownership plus a delivery with a conflicting tenant.

### CR-02: Admin read models join children without requiring the same tenant

**File:** `lib/chimeway/admin.ex:43`

**Issue:** Several admin queries scope only one level of the lifecycle chain: `recent_problem_deliveries/1` scopes only `d` (lines 43-46), `feed/1` scopes only `n` (119-123), `recovery_candidates/1` scopes either only `d` or only `e` (181-215), and `definitions/1` scopes only `e` (80-84). The database does not enforce that a delivery's tenant matches its notification/event tenant, and `Deliveries.plan_delivery/3` accepts an arbitrary `tenant_id` for a notification. A malformed or partially reconciled row therefore lets a tenant's operator see another tenant's recipient, event key, correlation ID, or counts through these joins.

**Fix:** Add `n.tenant_id == ^tenant_id` and `e.tenant_id == ^tenant_id` predicates to every delivery-root query, and equivalent child predicates to event/notification-root queries. Prefer join conditions that also assert tenant equality (`d.tenant_id == n.tenant_id`, `n.tenant_id == e.tenant_id`) as defense in depth. Add adversarial tests using the existing cross-tenant linked-row pattern from `tenant_scope_contract_test.exs` for every admin DTO.

### CR-03: Feed Debug bypasses the required event-time authorization gate

**File:** `chimeway_admin/lib/chimeway_admin/live/feed_live.ex:15`

**Issue:** `handle_event("search", ...)` reads and returns tenant data without calling `ChimewayAdmin.LiveAuth.ensure_authorized/3`. This contradicts `LiveAuth`'s contract that event handlers are re-checked after mount, and differs from Trace Search and Recovery. An actor whose `:view_feed` permission is revoked while the LiveView remains connected can continue to query recipient histories until disconnect.

**Fix:** Wrap the handler in `with {:ok, socket} <- LiveAuth.ensure_authorized(socket, :view_feed)` and return the redirected socket on failure, matching `TraceSearchLive.handle_event/3`. Add a LiveView test whose auth module allows mount but denies the subsequent `:view_feed` check.

## Warnings

### WR-01: Tenant/recipient changes crash the inbox LiveView instead of denying access

**File:** `chimeway_inbox/lib/chimeway_inbox/live_auth.ex:39`

**Issue:** The `case` handles only an exact successful identity/tenant match and `{:error, _}`. If the host auth module successfully resolves a different recipient or tenant (for example after an account/tenant switch), neither clause matches and `ensure_authorized/2` raises `CaseClauseError`. The documented fail-closed behavior should redirect rather than crash the LiveView.

**Fix:** Add a catch-all success clause, e.g. `{:ok, _recipient_identity, _tenant_id} -> {:error, redirect(socket, to: unauthorized_redirect())}`, and cover it with an authorization-change test.

---

_Reviewed: 2026-08-12T17:14:06Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_

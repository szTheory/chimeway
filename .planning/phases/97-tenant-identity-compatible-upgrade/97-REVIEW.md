---
phase: 97-tenant-identity-compatible-upgrade
reviewed: 2026-08-12T00:00:00Z
depth: standard
files_reviewed: 70
files_reviewed_list:
  - .github/workflows/ci.yml
  - AGENTS.md
  - chimeway_admin/lib/chimeway_admin/context.ex
  - chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex
  - chimeway_admin/lib/chimeway_admin/live/definitions_live.ex
  - chimeway_admin/lib/chimeway_admin/live/feed_live.ex
  - chimeway_admin/lib/chimeway_admin/live/health_live.ex
  - chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex
  - chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex
  - chimeway_admin/lib/chimeway_admin/live_auth.ex
  - chimeway_admin/test/chimeway_admin/live/definitions_live_test.exs
  - chimeway_admin/test/chimeway_admin/live/design_system_live_test.exs
  - chimeway_admin/test/chimeway_admin/live/feed_live_test.exs
  - chimeway_admin/test/chimeway_admin/live/privacy_leak_live_test.exs
  - chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs
  - chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs
  - chimeway_admin/test/chimeway_admin/live_auth_test.exs
  - chimeway_inbox/lib/chimeway_inbox/auth.ex
  - chimeway_inbox/lib/chimeway_inbox/live/bell_dropdown_live.ex
  - chimeway_inbox/lib/chimeway_inbox/live_auth.ex
  - chimeway_inbox/test/chimeway_inbox/live/bell_dropdown_live_test.exs
  - chimeway_inbox/test/support/allow_auth.ex
  - chimeway_inbox/test/support/deny_auth.ex
  - chimeway_inbox/test/support/fixtures.ex
  - examples/chimeway_demo_host/lib/demo_host/inbox_auth.ex
  - examples/chimeway_demo_host/lib/demo_host/seeds.ex
  - examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs
  - examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs
  - examples/chimeway_demo_host/test/support/storage_prefix_support.ex
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
  - priv/chimeway_migrations/033_make_chimeway_delivery_tenant_nullable.exs
  - priv/repo/migrations/20260812000000_add_tenant_identity_to_events_and_notifications.exs
  - priv/repo/migrations/20260812000001_make_chimeway_delivery_tenant_nullable.exs
  - test/chimeway/admin_test.exs
  - test/chimeway/generated_prefixed_runtime_proof_test.exs
  - test/chimeway/inbox_query_test.exs
  - test/chimeway/inbox_state_transition_test.exs
  - test/chimeway/install/golden_diff_test.exs
  - test/chimeway/install/idempotency_test.exs
  - test/chimeway/install/migrations_test.exs
  - test/chimeway/install/prefix_contract_test.exs
  - test/chimeway/migration_contract_test.exs
  - test/chimeway/mix/tasks/reconcile_tenants_test.exs
  - test/chimeway/orchestration/recovery_test.exs
  - test/chimeway/reconciliation_test.exs
  - test/chimeway/release_gate_contract_test.exs
  - test/chimeway/runtime_prefix_integration_test.exs
  - test/chimeway/tenant_identity_test.exs
  - test/chimeway/tenant_scope_contract_test.exs
  - test/chimeway/traces_test.exs
  - test/fixtures/installer_golden_prefixed/STDOUT.txt
  - test/fixtures/installer_golden_prefixed/tree/priv/repo/migrations/TIMESTAMP_add_tenant_identity_to_events_and_notifications.exs
  - test/fixtures/installer_golden_prefixed/tree/priv/repo/migrations/TIMESTAMP_make_chimeway_delivery_tenant_nullable.exs
  - test/fixtures/installer_golden_public/STDOUT.txt
  - test/fixtures/installer_golden_public/tree/priv/repo/migrations/TIMESTAMP_add_tenant_identity_to_events_and_notifications.exs
  - test/fixtures/installer_golden_public/tree/priv/repo/migrations/TIMESTAMP_make_chimeway_delivery_tenant_nullable.exs
  - test/support/chimeway/dispatch_helpers.ex
  - test/support/data_case.ex
  - test/support/generated_prefixed_runtime_case.ex
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---

# Phase 97: Code Review Report

**Reviewed:** 2026-08-12T00:00:00Z
**Depth:** standard
**Files Reviewed:** 70
**Status:** issues_found

## Summary

The phase adds comprehensive read-side tenant predicates, migration templates, reconciliation, and PR-gate coverage. However, the delivery-planning write path can still create a delivery whose tenant disagrees with its notification, including via its new implicit `"default"` fallback. That breaks the durable tenant spine and can feed a foreign notification into dispatch/recovery paths. The Admin recovery aggregate also counts foreign deliveries when deciding whether a tenant's event is recoverable.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Delivery planning can write a child under a different tenant than its notification

**File:** `lib/chimeway/delivery_planning.ex:110`
**Issue:** `plan_one_channel/5` passes `Keyword.get(opts, :tenant_id, "default")` rather than the notification's durable owner. `Deliveries.plan_delivery/3` then accepts that value and inserts it without loading or checking the notification owner ([`lib/chimeway/deliveries.ex:301`](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:301), [`lib/chimeway/deliveries.ex:327`](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:327)). Consequently, a caller of `DeliveryPlanning.plan_notification(notification, [])` creates a `"default"` delivery for a non-default notification, and any caller with a notification ID can supply a different tenant. Tenant-scoped trace/Admin queries correctly hide that malformed child, but recovery and dispatch operate on delivery rows and can still act on it. This defeats the phase's lifecycle-wide tenant coherence guarantee.

**Fix:** Remove the default and derive tenant identity from the notification; reject missing or unequal explicit values before insertion. Also enforce the invariant at the `Deliveries.plan_delivery/3` boundary in a transaction/query, so future callers cannot bypass the planner.

```elixir
with ^tenant_id <- notification.tenant_id,
     {:ok, delivery} <- Deliveries.plan_delivery(notification.id, channel,
       Keyword.put(opts, :tenant_id, tenant_id)
     ) do
  {:ok, delivery}
else
  _ -> {:error, :tenant_mismatch}
end
```

Add regression coverage for a non-default notification planned without opts and for an explicit cross-tenant tenant ID; both must fail without inserting a delivery.

## Warnings

### WR-01: Recovery candidates treat a foreign delivery as this tenant's planned delivery

**File:** `lib/chimeway/admin.ex:220`
**Issue:** The event recovery-candidate query constrains Event and Notification to the requested tenant, but its left Delivery join has no `d.tenant_id == ^tenant_id` predicate. The subsequent `having count(d.id) == 0` therefore suppresses a tenant A event whenever a malformed/legacy tenant B delivery references one of its notifications. The equivalent core recovery query scopes its delivery join, so Admin and core recovery disagree.

**Fix:** Scope the optional join itself and add a split-tenant regression fixture.

```elixir
|> join(:left, [_e, n], d in assoc(n, :deliveries), on: d.tenant_id == ^tenant_id)
```

---

_Reviewed: 2026-08-12T00:00:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_

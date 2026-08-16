---
phase: 98-privacy-safe-delivery-evidence
reviewed: 2026-08-15T21:27:30Z
depth: standard
files_reviewed: 43
files_reviewed_list:
  - chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex
  - chimeway_admin/lib/chimeway_admin/redaction.ex
  - chimeway_admin/test/chimeway_admin/live/privacy_leak_live_test.exs
  - lib/chimeway/admin.ex
  - lib/chimeway/deliveries.ex
  - lib/chimeway/delivery_planning.ex
  - lib/chimeway/dispatch/executor.ex
  - lib/chimeway/dispatch/oban_worker.ex
  - lib/chimeway/inbox.ex
  - lib/chimeway/privacy.ex
  - lib/chimeway/render_context_resolver.ex
  - lib/chimeway/safe_evidence.ex
  - lib/chimeway/telemetry.ex
  - lib/chimeway/traces.ex
  - lib/chimeway/trigger.ex
  - lib/chimeway/workflows.ex
  - priv/adoption_proof/artifact_consumer_fixture.ex
  - priv/chimeway_migrations/034_privacy_safe_delivery_evidence.exs
  - priv/repo/migrations/20260813000000_privacy_safe_delivery_evidence.exs
  - test/chimeway/admin_test.exs
  - test/chimeway/deliveries_test.exs
  - test/chimeway/dispatch/executor_mailglass_adapter_test.exs
  - test/chimeway/dispatch/executor_test.exs
  - test/chimeway/dispatch/oban_worker_test.exs
  - test/chimeway/inbox_query_test.exs
  - test/chimeway/inbox_state_transition_test.exs
  - test/chimeway/install/migrations_test.exs
  - test/chimeway/integration/delivery_lifecycle_test.exs
  - test/chimeway/integrations/sigra_auth_lifecycle_test.exs
  - test/chimeway/migration_contract_test.exs
  - test/chimeway/orchestration/delivery_planning_test.exs
  - test/chimeway/orchestration/digest_explainability_test.exs
  - test/chimeway/privacy_boundary_test.exs
  - test/chimeway/privacy_test.exs
  - test/chimeway/release_gate_contract_test.exs
  - test/chimeway/runtime_prefix_integration_test.exs
  - test/chimeway/telemetry_integration_test.exs
  - test/chimeway/tenant_identity_test.exs
  - test/chimeway/traces_test.exs
  - test/chimeway/trigger_sanitization_test.exs
  - test/chimeway/workflows_test.exs
  - test/fixtures/installer_golden_prefixed/tree/priv/repo/migrations/TIMESTAMP_privacy_safe_delivery_evidence.exs
  - test/fixtures/installer_golden_public/tree/priv/repo/migrations/TIMESTAMP_privacy_safe_delivery_evidence.exs
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 98: Code Review Report

**Reviewed:** 2026-08-15T21:27:30Z
**Depth:** standard
**Files Reviewed:** 43
**Status:** issues_found

## Summary

The new evidence projections correctly close the previously exposed nested trace and struct-redaction paths, but deferred-delivery state transitions still bypass the tenant ownership boundary. A caller with a foreign delivery UUID can resume or cancel that tenant's deferred delivery.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Deferred delivery transitions are not tenant-scoped

**File:** `lib/chimeway/deliveries.ex:748-767` and `lib/chimeway/deliveries.ex:797-813`
**Issue:** `resume_deferred_delivery/2` and `cancel_deferred_delivery/3` load the delivery and update it by UUID alone. Neither resolves `TenantScope` from `opts` nor constrains its fetch/update query with `d.tenant_id`. Consequently, a host-facing caller that knows a different tenant's delivery UUID can move that row from `:deferred` to `:ready`, or cancel it with a chosen suppression reason. This violates the application's required tenancy and host-ownership boundary.
**Fix:** Resolve the tenant before both operations, fetch with the tenant constraint, and add the same constraint to `Repo.update_all/2`. Treat missing or foreign IDs as not found/noop. For example:

```elixir
with {:ok, tenant_id} <- TenantScope.resolve(opts),
     %Delivery{} = delivery <- Repo.get_by(Delivery, id: delivery_id, tenant_id: tenant_id) do
  Repo.update_all(
    from(d in Delivery,
      where: d.id == ^delivery_id and d.tenant_id == ^tenant_id and
        d.status == :pending and d.orchestration_state == :deferred
    ),
    set: [...]
  )
end
```

Add cross-tenant regression tests for both APIs, asserting they cannot mutate the foreign row.

---

_Reviewed: 2026-08-15T21:27:30Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_

---
phase: 99-multi-installation-delivery-recovery
reviewed: 2026-08-20T00:00:00Z
depth: standard
files_reviewed: 27
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
  - priv/chimeway_migrations/036_enforce_delivery_target_tenant_integrity.exs
  - priv/repo/migrations/20260819000001_create_chimeway_delivery_targets.exs
  - priv/repo/migrations/20260820000000_enforce_delivery_target_tenant_integrity.exs
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
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Phase 99: Code Review Report

**Reviewed:** 2026-08-20T00:00:00Z
**Depth:** standard
**Files Reviewed:** 27
**Status:** issues_found

## Summary

Reviewed the target lifecycle, tenant-integrity migrations, dispatch/recovery paths, trace projections, installer contracts, and their tests. The database constraints correctly bind target and attempt tenant ownership, but recovery accepts an unvalidated UUID cursor from durable Oban arguments and then interpolates it into UUID comparisons. A malformed job can therefore crash the worker rather than produce the documented bounded recovery result.

`mix compile --warnings-as-errors` passed. The focused database tests could not be started because the shared PostgreSQL server rejected connections with `FATAL 53300 (too_many_connections)`.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Recovery cursors are not validated as UUIDs before querying UUID columns

**File:** `lib/chimeway/target_recovery.ex:232-240` (untrusted values enter through `lib/chimeway/dispatch/recovery_worker.ex:14-16`)

**Issue:** `opaque_cursor/1` accepts every non-empty binary. The three cursor query branches then compare a UUID primary-key column to that binary. A malformed Oban argument such as `"event_cursor" => "not-a-uuid"` raises during Ecto/PostgreSQL UUID casting, causing the recovery job to fail and retry instead of returning the normal non-disclosing summary. This makes a corrupt or manually-enqueued recovery job repeatedly noisy and prevents its other recovery streams from running.

**Fix:** Accept only castable UUID cursors (or make malformed values `nil`) before building the query, and add worker-level coverage for malformed event/target/stale cursors. For example:

```elixir
defp opaque_cursor(value) when is_binary(value) do
  case Ecto.UUID.cast(value) do
    {:ok, uuid} -> uuid
    :error -> nil
  end
end

defp opaque_cursor(_value), do: nil
```

---

_Reviewed: 2026-08-20T00:00:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_

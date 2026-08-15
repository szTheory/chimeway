---
phase: 98-privacy-safe-delivery-evidence
reviewed: 2026-08-15T23:12:53Z
depth: standard
files_reviewed: 34
files_reviewed_list:
  - chimeway_admin/lib/chimeway_admin/redaction.ex
  - chimeway_admin/test/chimeway_admin/live/privacy_leak_live_test.exs
  - lib/chimeway/admin.ex
  - lib/chimeway/deliveries.ex
  - lib/chimeway/delivery_attempt.ex
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
  - test/chimeway/admin_test.exs
  - test/chimeway/deliveries_test.exs
  - test/chimeway/dispatch/executor_mailglass_adapter_test.exs
  - test/chimeway/dispatch/executor_test.exs
  - test/chimeway/dispatch/oban_worker_test.exs
  - test/chimeway/inbox_query_test.exs
  - test/chimeway/inbox_state_transition_test.exs
  - test/chimeway/integration/delivery_lifecycle_test.exs
  - test/chimeway/orchestration/delivery_planning_test.exs
  - test/chimeway/privacy_boundary_test.exs
  - test/chimeway/privacy_test.exs
  - test/chimeway/release_gate_contract_test.exs
  - test/chimeway/telemetry_integration_test.exs
  - test/chimeway/tenant_scope_contract_test.exs
  - test/chimeway/traces_test.exs
  - test/chimeway/trigger_sanitization_test.exs
  - test/chimeway/workflows_test.exs
findings:
  critical: 3
  warning: 1
  info: 0
  total: 4
status: issues_found
---

# Phase 98: Code Review Report

**Reviewed:** 2026-08-15T23:12:53Z
**Depth:** standard
**Files Reviewed:** 34
**Status:** issues_found

## Summary

The new closed evidence constructors substantially reduce newly persisted sensitive fields, but three public mutation/query paths still permit cross-tenant corruption or disclosure. The focused privacy tests pass, but they do not cover these paths.

## Critical Issues

### CR-01: Provider-message webhook lookup is ambiguous across adapters and tenants

**File:** `lib/chimeway/deliveries.ex:497`
**Issue:** `get_delivery_by_provider_message_id/1` selects the first attempt matching only `provider_message_id`. The persisted safe reference is a hash of the provider ID alone; it does not include an adapter or tenant namespace. Two provider accounts/adapters can therefore use the same upstream message ID, and the webhook worker will record its outcome against whichever delivery PostgreSQL returns first. This can mutate another tenant's delivery and emit its workflow signal.
**Fix:** Scope the lookup with a trusted adapter and tenant/account identity from the verified webhook boundary, and make that identity part of the persisted lookup key. For example, accept `adapter_module` and `tenant_id` in this function and include both in the `where`; reject an ingress that cannot supply a tenant-scoped match.

### CR-02: Signal payload can forge a workflow transition's delivery relationship

**File:** `lib/chimeway/workflows.ex:424`
**Issue:** `route_signal/1` copies the caller-controlled `signal.payload["delivery_id"]` directly into the transition FK. `Signal.track/4` accepts arbitrary maps, and no check establishes that this delivery belongs to the matched run, notification, or tenant. A host entry point that submits a signal with another tenant's UUID can create a cross-tenant relationship; a malformed/nonexistent UUID instead rolls back the workflow transition and makes the worker retry indefinitely.
**Fix:** Resolve the delivery inside the transaction and require it to have the matched tenant and notification/workflow linkage before writing it. Treat a missing or invalid optional delivery ID as `nil` (or a deliberate ignored signal), never as a transaction-failing untrusted FK.

### CR-03: Public trace APIs still expose legacy raw sensitive columns

**File:** `lib/chimeway/traces.ex:53`
**Issue:** `get_trace/2`, `find_traces_for_recipient/2`, and correlation lookup return full Ecto event/notification/delivery/attempt schemas and preload their associations (`lib/chimeway/traces.ex:69-74`, `118-121`, `153-156`). Those schemas include `payload`, `render_assigns`, `render_data`, and `provider_response`. The Phase 98 write path only protects future rows; existing rows and any direct inserts remain readable through this public operator query API, bypassing `SafeEvidence` and the admin DTO layer.
**Fix:** Return explicit safe trace DTOs from public query functions (or make raw schema access private/internal and expose a separate, clearly privileged API). Apply `SafeEvidence` to every returned event, notification, delivery, and attempt field, and add regression fixtures containing legacy raw values.

## Warnings

### WR-01: Inbox lifecycle transitions claim success even when required signal persistence fails

**File:** `lib/chimeway/inbox.ex:215`
**Issue:** `emit_inbox_signal/4` discards the result of `Signal.track/4` and always returns `:ok`. A notification can be marked seen/read while the corresponding workflow signal was not inserted/enqueued (for example, an Oban/database failure), permanently losing the transition because subsequent calls are idempotent and do not emit it again.
**Fix:** Propagate `Signal.track/4` failures and perform the notification update plus signal insert in a single transaction, or persist a durable outbox/retry marker before returning success.

---

_Reviewed: 2026-08-15T23:12:53Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_

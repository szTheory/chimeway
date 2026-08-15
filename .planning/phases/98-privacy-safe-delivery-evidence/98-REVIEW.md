---
phase: 98-privacy-safe-delivery-evidence
reviewed: 2026-08-15T23:38:48Z
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
  critical: 4
  warning: 1
  info: 0
  total: 5
status: issues_found
---

# Phase 98: Code Review Report

**Reviewed:** 2026-08-15T23:38:48Z
**Depth:** standard
**Files Reviewed:** 34
**Status:** issues_found

## Summary

The reviewed code adds useful redaction and tenant checks, but four shipping blockers remain: public raw trace reads, two cross-tenant relationship paths, and a generated adoption proof that cannot pass the new recipient contract. Focused tests do not exercise those failure paths.

## Critical Issues

### CR-01: Provider-message webhook lookup is ambiguous across adapters and tenants

**File:** `lib/chimeway/deliveries.ex:497`

**Issue:** `get_delivery_by_provider_message_id/1` selects the first attempt matching only `provider_message_id`. The persisted safe reference is a hash of the provider ID alone; it has no adapter or tenant namespace. Two provider accounts/adapters can therefore use the same upstream message ID, and the webhook worker can record its outcome against whichever delivery PostgreSQL returns first. This mutates another tenant's delivery and can emit its workflow signal.

**Fix:** Scope the lookup with a trusted adapter and tenant/account identity from the verified webhook boundary, and include both in the query (and persisted lookup key). Reject ingress that cannot supply one unambiguous tenant-scoped match.

### CR-02: Signal payload can forge a workflow transition's delivery relationship

**File:** `lib/chimeway/workflows.ex:424`

**Issue:** `route_signal/1` copies caller-controlled `signal.payload["delivery_id"]` directly into the transition FK. No check establishes that the delivery belongs to the matched run, notification, or tenant. A signal with another tenant's UUID can create a cross-tenant relationship; a malformed or nonexistent UUID rolls back the transition and makes the signal worker retry.

**Fix:** Resolve the optional delivery inside the transaction and require it to match the signal tenant and matched notification/workflow linkage before writing it. Treat invalid or absent optional IDs as `nil` (or a deliberate ignored signal), never as an untrusted FK.

### CR-03: Public trace APIs still expose legacy raw sensitive columns

**File:** `lib/chimeway/traces.ex:53`

**Issue:** `get_trace/2`, `find_traces_for_recipient/2`, and correlation lookup return full Ecto schemas and preload associations (`lib/chimeway/traces.ex:69-74`, `118-121`, `153-156`). These schemas include `payload`, `render_assigns`, `render_data`, and `provider_response`. The Phase 98 write path protects future rows, but existing rows and direct inserts remain readable through this public operator API, bypassing `SafeEvidence` and the admin DTO layer.

**Fix:** Return explicit safe trace DTOs from public query functions, or make raw schema access private/internal and expose a separately privileged API. Apply `SafeEvidence` to every event, notification, delivery, and attempt field, with legacy raw-value regression fixtures.

### CR-04: Generated adoption proofs submit recipients rejected by the new persistence boundary

**File:** `priv/adoption_proof/artifact_consumer_fixture.ex:507`

**Issue:** The generated Core proof notifier returns `recipient_identity: "proof-user"`; the generated Mailglass notifier does the same with `"user:proof@example.test"` at line 553. Both fail `SafeEvidence.recipient_reference/1`, which accepts only `cw_...` opaque references or the UUID compatibility form. Consequently `Chimeway.trigger/3` returns `{:error, :unsafe_evidence}`, so neither adoption proof can reach its asserted lifecycle evidence.

**Fix:** Generate an opaque `recipient_ref` for both notifiers. For Mailglass, retain the raw email only as the transient `recipient_identity` alongside that ref, e.g. `%{recipient_ref: "cw_recipient_artifact_mailglass", recipient_identity: "user:proof@example.test", recipient_type: "user"}`; use only the opaque ref for the in-app proof.

## Warnings

### WR-01: Inbox lifecycle transitions claim success even when required signal persistence fails

**File:** `lib/chimeway/inbox.ex:215`

**Issue:** `emit_inbox_signal/4` discards the result of `Signal.track/4` and always returns `:ok`. A notification can be marked seen/read while its workflow signal was not inserted or enqueued (for example, after an Oban/database failure). Subsequent calls are idempotent and will not emit the lost signal.

**Fix:** Propagate `Signal.track/4` failures and persist the notification update plus signal insert in one transaction, or write a durable outbox/retry marker before reporting success.

---

_Reviewed: 2026-08-15T23:38:48Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_

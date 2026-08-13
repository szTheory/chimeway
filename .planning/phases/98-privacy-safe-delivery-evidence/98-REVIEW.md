---
phase: 98-privacy-safe-delivery-evidence
reviewed: 2026-08-13T19:44:45Z
depth: standard
files_reviewed: 31
files_reviewed_list:
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
findings:
  critical: 2
  warning: 0
  info: 0
  total: 2
status: issues_found
---

# Phase 98: Code Review Report

**Reviewed:** 2026-08-13T19:44:45Z
**Depth:** standard
**Files Reviewed:** 31
**Status:** issues_found

## Summary

The new privacy boundary successfully blocks the tested email/token cases, but two untested paths violate its durable-evidence and lifecycle guarantees. A queued email that cannot reconstruct its host context is retried without a durable failure state, and a raw slug-like recipient identifier is stored unchanged despite the opaque-reference contract.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Missing render context leaves queued emails permanently pending with no evidence

**File:** `/Users/jon/projects/chimeway/lib/chimeway/dispatch/oban_worker.ex:187`

**Issue:** `do_dispatch/3` returns the hydration error directly. `hydrate_execution_delivery/1` intentionally turns every resolver/render failure into `{:error, :render_context_unavailable}` at `lib/chimeway/delivery_planning.ex:63-64`, before `Executor.run_delivery/1` can create a `DeliveryAttempt` or transition the delivery. Oban will retry and eventually discard the job, while the delivery remains `:pending`/`:ready` and has no attempt or suppression reason. That loses the required explainable lifecycle state and leaves a stale row eligible for recovery/re-enqueue loops.

**Fix:** Convert hydration failure into a durable, bounded execution outcome before returning to Oban. For example, record a rejected attempt with a safe `"render_context_unavailable"` class/reason and transition the delivery to a terminal/suppressed state, or explicitly reschedule with persisted retry metadata. Add a worker test that removes the resolver, exhausts retries, and asserts the final delivery state and timeline entry.

### CR-02: Recipient sanitizer persists raw slug-like identities as “opaque” references

**File:** `/Users/jon/projects/chimeway/lib/chimeway/safe_evidence.ex:115`

**Issue:** `recipient_reference/1` accepts any `opaque_id?/1` string unchanged. That predicate only checks `/^[a-z][a-z0-9_-]*$/`; values such as `"alex-smith"` satisfy it even though `opaque_ref(:recipient, "alex-smith")` correctly rejects them. `Trigger.insert_notifications/6` writes this result to `notifications.recipient_identity` (`lib/chimeway/trigger.ex:244`), so notifier-provided PII-like identities are retained durably rather than projected to `cw_recipient_<hash>`. The tested email case does not cover this bypass.

**Fix:** Only preserve explicitly namespaced opaque references (`cw_...`) and the documented non-PII `user:<opaque-id>` form; hash every other input. Remove the permissive `opaque_id?/1` branch from `recipient_reference/1` (or require a dedicated opaque prefix) and add tests asserting `"alex-smith"` and similar raw identifiers are persisted only as a `cw_recipient_` projection.

---

_Reviewed: 2026-08-13T19:44:45Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_

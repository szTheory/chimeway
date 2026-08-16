---
phase: 98-privacy-safe-delivery-evidence
reviewed: 2026-08-15T20:42:00Z
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
  warning: 0
  info: 0
  total: 3
status: issues_found
---

# Phase 98: Code Review Report

**Reviewed:** 2026-08-15T20:42:00Z
**Depth:** standard
**Files Reviewed:** 34
**Status:** issues_found

## Summary

The phase establishes useful closed-field evidence paths and the exercised core/admin tests pass, but three boundary failures remain. Two allow sensitive values to bypass the newly introduced redaction/safe-evidence contracts; the other lets a caller mutate another tenant's deferred delivery when it knows its UUID.

## Critical Issues

### CR-01: Struct values bypass the recursive privacy redactor

**File:** `lib/chimeway/privacy.ex:18`

**Issue:** The first clause returns every struct unchanged. This is the opposite of a recursive redactor for untrusted terms: a host-defined struct containing `token`, `recipient`, `body`, or similar fields is returned intact. In particular, `SafeEvidence.proof/1` delegates directly to `Privacy.redact/1` at `lib/chimeway/safe_evidence.ex:390`, so an artifact/diagnostic caller can publish a struct carrying sensitive fields despite the advertised privacy boundary.

**Fix:** Convert non-scalar structs to maps and recurse through their fields (while retaining only explicitly safe scalar structs such as `DateTime` if their representation must be preserved), for example:

```elixir
def redact(%DateTime{} = value), do: value
def redact(value) when is_struct(value), do: value |> Map.from_struct() |> redact()
```

Add regression coverage using a small local struct with a mixed-case forbidden field.

### CR-02: Deferred-delivery mutation APIs are not tenant-scoped

**File:** `lib/chimeway/deliveries.ex:740-773` and `lib/chimeway/deliveries.ex:789-819`

**Issue:** `resume_deferred_delivery/2` and `cancel_deferred_delivery/3` fetch and update solely by `delivery_id`. They neither resolve a tenant from `opts` nor constrain either query by `d.tenant_id`. A host-facing caller that can obtain/guess another tenant's delivery UUID can therefore resume it or cancel it with an arbitrary suppression reason. This violates the project's host ownership and tenancy boundary.

**Fix:** Resolve `TenantScope.resolve(opts)` before reading, and add `d.tenant_id == ^tenant_id` to the fetch and `update_all` queries. Return `{:noop, nil}`/`{:error, :not_found}` for an absent or foreign row rather than using `get_delivery!/1`. Add cross-tenant tests for both APIs.

### CR-03: `SafeEvidence.trace/1` passes raw nested diagnostic data through unchanged

**File:** `lib/chimeway/safe_evidence.ex:254-276`

**Issue:** Despite being the closed evidence constructor, `trace/1` validates its scalar fields but copies `:last_attempt` and `:timeline` directly from caller input. For example, a map whose `last_attempt` contains `%{provider_response: %{token: "..."}}`, or whose timeline detail contains a rendered body, is returned with that data intact. This makes the public safe-evidence facade unsafe as a serialization boundary and creates an easy future privacy regression when a caller uses it for an operator surface.

**Fix:** Build `last_attempt` through `trace_attempt/1` and validate/project each timeline entry into a closed `%{at: safe_datetime(at), event: allowed_event, detail: timeline_detail(detail)}` shape; omit invalid entries. Add hostile nested-data tests that assert those values cannot survive `trace/1`.

---

_Reviewed: 2026-08-15T20:42:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_

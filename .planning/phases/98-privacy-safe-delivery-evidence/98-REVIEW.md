---
phase: 98-privacy-safe-delivery-evidence
reviewed: 2026-08-13T02:55:40Z
depth: standard
files_reviewed: 24
files_reviewed_list:
  - chimeway_admin/lib/chimeway_admin/redaction.ex
  - chimeway_admin/test/chimeway_admin/live/privacy_leak_live_test.exs
  - lib/chimeway/admin.ex
  - lib/chimeway/deliveries.ex
  - lib/chimeway/dispatch/executor.ex
  - lib/chimeway/inbox.ex
  - lib/chimeway/privacy.ex
  - lib/chimeway/safe_evidence.ex
  - lib/chimeway/telemetry.ex
  - lib/chimeway/traces.ex
  - lib/chimeway/trigger.ex
  - priv/adoption_proof/artifact_consumer_fixture.ex
  - test/chimeway/admin_test.exs
  - test/chimeway/dispatch/executor_test.exs
  - test/chimeway/inbox_query_test.exs
  - test/chimeway/inbox_state_transition_test.exs
  - test/chimeway/orchestration/delivery_planning_test.exs
  - test/chimeway/privacy_boundary_test.exs
  - test/chimeway/privacy_test.exs
  - test/chimeway/release_gate_contract_test.exs
  - test/chimeway/telemetry_integration_test.exs
  - test/chimeway/tenant_scope_contract_test.exs
  - test/chimeway/traces_test.exs
  - test/chimeway/trigger_sanitization_test.exs
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---

# Phase 98: Code Review Report

**Reviewed:** 2026-08-13T02:55:40Z
**Depth:** standard
**Files Reviewed:** 24
**Status:** issues_found

## Summary

The new safe-evidence and operator projection paths are broadly wired through the intended persistence and trace callers. However, the value validation is not strong enough to uphold the phase's privacy guarantee: user-controlled text under approved field names is persisted and later rendered as operator evidence. A digest delivery also loses its lifecycle status in the safe projection.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Approved evidence keys permit raw secrets and PII into persistence and trace output

**File:** `/Users/jon/projects/chimeway/lib/chimeway/safe_evidence.ex:85`
**Issue:** `event_payload/1`, `notification_metadata/1`, and planning context intentionally retain fields such as `reason`, but `closed_facts/2` accepts any binary of up to 160 bytes (line 441). `Privacy.redact/1` only removes sensitive *keys*, so input such as `%{"reason" => "alex@example.test; reset-token=abc"}` is persisted by `Trigger.event_changeset/5` (line 185). The same unvalidated reason can become `digest_flush_reason`, then `Traces.source_digest_context/2` and `resolution_entries/2` project it into the operator explanation (lines 851-907); `safe_digest/1` merely redacts keys and does not allowlist nested digest fields (line 388). This defeats the stated safe-evidence boundary: sensitive values under innocuous keys reach durable records and operator surfaces.

**Fix:** Separate trusted, enumerated reason codes from untrusted text and validate every retained string against a safe identifier grammar (or an explicit enum) before persistence/projection. Build digest output with its own closed map rather than `Privacy.redact/1` alone. For example:

```elixir
defp safe_reason?(value) when is_binary(value) do
  byte_size(value) in 1..80 and String.match?(value, ~r/^[a-z][a-z0-9_]*$/)
end

defp safe_reason?(_), do: false

defp safe_scalar?(value) when is_binary(value), do: safe_reason?(value)
```

Apply field-specific validators instead of the generic `safe_scalar?/1` where values have different valid formats, and add regression tests that submit email/token text under `reason` and `digest_flush_reason`, then assert it is absent from the stored rows and `Traces.explain_delivery/2`.

## Warnings

### WR-01: Digested deliveries are projected with a nil status

**File:** `/Users/jon/projects/chimeway/lib/chimeway/safe_evidence.ex:373`
**Issue:** `SafeEvidence.trace/1` projects the delivery's status via `safe_status/1`, but that allowlist omits `:digested`. Consequently, `Traces.explain_delivery/2` passes a real `:digested` status (line 214) and receives `status: nil`, even while it retains digest details. Operator consumers cannot accurately tell that the delivery reached the digested terminal state.

**Fix:** Include `:digested` in the closed status set and add an explanation assertion for a digest-held source delivery:

```elixir
defp safe_status(value)
     when value in [:succeeded, :failed, :suppressed, :pending, :cancelled, :dispatched, :digested],
     do: value
```

---

_Reviewed: 2026-08-13T02:55:40Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_

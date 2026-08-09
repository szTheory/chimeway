---
phase: 94-mailglass-transactional-email-proof
reviewed: 2026-08-09T12:20:00-04:00
depth: standard
files_reviewed: 4
files_reviewed_list:
  - test/support/artifact_consumer_fixture.ex
  - test/chimeway/release_gate_contract_test.exs
  - guides/introduction/mailglass-integration.md
  - test/chimeway/doc_contract_test.exs
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 94: Code Review Report

**Reviewed:** 2026-08-09T12:20:00-04:00
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

The corrected single-host-repository topology is consistently represented in the generated fixture, release-gate contract, and guide. The scoped contract suites pass, although they log pre-existing Threadline sandbox ownership errors during teardown. A blocker remains at the proof-output trust boundary: the parser allowlists field names but accepts arbitrary values for every field other than `transport`, so it can return spoofed trace facts or sensitive values supplied under an allowlisted key.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Mailglass evidence parser does not validate allowlisted field values

**File:** `test/support/artifact_consumer_fixture.ex:539-567`
**Issue:** The subprocess output is explicitly an untrusted boundary, but `parse_evidence_pairs!/3` only checks field names, duplicates, and non-empty values. `parse_mailglass_evidence!/1` then validates only `transport` (lines 530-535). Consequently, input such as `delivery_id=recipient@example.test`, `status=failed`, or `adapter_module=provider-secret` is accepted and returned as supposedly safe evidence. This permits both evidence spoofing and sensitive-data disclosure under an approved key, defeating the safe-projection guarantee.
**Fix:** Validate the full fixed proof schema after parsing: require the exact stable notification/render/channel/status/adapter values, numeric versions and attempt number, a UUID-shaped delivery ID, and an allowed ordered timeline. Reject values containing whitespace or characters outside each field's expected format. Add negative contracts that replace each allowlisted value with recipient, credential, provider-response, and incorrect lifecycle values.

```elixir
defp validate_mailglass_evidence!(evidence) do
  expected = %{
    notification_key: "artifact_consumer.mailglass_proof",
    notification_version: "1",
    channel: "email",
    render_key: "artifact_consumer.mailglass_proof.email",
    render_version: "1",
    status: "succeeded",
    last_attempt_outcome: "succeeded",
    last_attempt_number: "1",
    adapter_module: "Chimeway.Adapters.Mailglass"
  }

  unless Map.take(evidence, Map.keys(expected)) == expected and
           match?({:ok, _}, Ecto.UUID.cast(evidence.delivery_id)) do
    raise "artifact consumer Mailglass proof emitted unsafe or invalid evidence values"
  end
end
```

---

_Reviewed: 2026-08-09T12:20:00-04:00_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_

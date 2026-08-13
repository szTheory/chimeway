---
phase: 98-privacy-safe-delivery-evidence
reviewed: 2026-08-13T15:30:07Z
depth: standard
files_reviewed: 27
files_reviewed_list:
  - chimeway_admin/lib/chimeway_admin/redaction.ex
  - chimeway_admin/test/chimeway_admin/live/privacy_leak_live_test.exs
  - lib/chimeway/admin.ex
  - lib/chimeway/deliveries.ex
  - lib/chimeway/delivery_planning.ex
  - lib/chimeway/dispatch/executor.ex
  - lib/chimeway/inbox.ex
  - lib/chimeway/privacy.ex
  - lib/chimeway/safe_evidence.ex
  - lib/chimeway/telemetry.ex
  - lib/chimeway/traces.ex
  - lib/chimeway/trigger.ex
  - lib/chimeway/workflows.ex
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
  - test/chimeway/workflows_test.exs
findings:
  critical: 3
  warning: 1
  info: 0
  total: 4
status: issues_found
---

# Phase 98: Code Review Report

**Reviewed:** 2026-08-13T15:30:07Z
**Depth:** standard
**Files Reviewed:** 27
**Status:** issues_found

## Summary

The privacy projections for stored evidence and admin/telemetry surfaces are generally narrow, but the new rendering and recipient handoff crosses those boundaries incorrectly. Rendered content can be made durable, sensitive transient values are returned from the public trigger API, and the recipient handoff disappears before an Oban worker executes.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Caller-controlled “trusted” rendering bypass persists rendered content

**File:** `lib/chimeway/delivery_planning.ex:117`
**Issue:** The presence of an entry in the public `:precomputed_rendering` option sets `trusted_render_data?`, then passes the complete rendered map through to `Deliveries.plan_delivery/3` (lines 128-142). `normalize_optional_render_data/2` explicitly returns that map without `SafeEvidence` projection when the flag is true (`lib/chimeway/deliveries.ex:427`), and `apply_render_result/2` unconditionally uses the same bypass (`lib/chimeway/deliveries.ex:618-628`). Rendered subject/body/recipient data therefore becomes durable in `deliveries.render_data`; it is also exposed by the public `Traces.get_trace/2` preload. The boolean is not a trust boundary: any caller of these public APIs can supply it or a matching precomputed map.

**Fix:** Never persist rendered payloads in `render_data`. Retain only validated render identity durably, and pass the rendered map to the adapter through a non-persistent execution context. Remove the public `trusted_render_data` bypass; if a privileged internal capability is genuinely necessary, make it unforgeable and still apply a closed safe projection before any database write.

### CR-02: Oban delivery loses the only email recipient before execution

**File:** `lib/chimeway/delivery_planning.ex:120`
**Issue:** The address is attached only to the in-memory virtual field at lines 145 and 573-574. Oban enqueues only `delivery_id` and later reloads the delivery (`lib/chimeway/dispatch/oban.ex:82-83` and `lib/chimeway/dispatch/oban_worker.ex:126`), so `recipient_address` is nil at adapter execution. Because the new privacy flow also stores an opaque recipient identity, Mailglass reaches `resolve_recipient/1` without an address and records `:missing_recipient`. Thus mail notifications planned through the supported async dispatcher cannot be sent.

**Fix:** Define an execution-time host recipient resolver keyed by the opaque recipient reference (or a similarly non-sensitive, authenticated handoff service), and invoke it in the worker immediately before adapter delivery. Do not rely on a virtual field across a queued job; add an Oban integration test proving the resolver receives the address while the delivery row and job arguments do not contain it.

### CR-03: Transient recipient and rendered payload are leaked in the public trigger result

**File:** `lib/chimeway/trigger.ex:313`
**Issue:** `normalize_trigger_result/4` copies both `precomputed_rendering` and `recipient_handoffs` into the returned trigger map (lines 335-336). `dispatch_after_trigger/4` then returns the same map after dispatch (lines 520-534). This makes exact email addresses and complete rendered messages observable to every `Trigger.trigger/3` caller and likely application logs, contrary to the stated transient handoff boundary.

**Fix:** Keep these values in a private, short-lived dispatch context instead of the public result. After dispatch, construct the returned map from an allowlist (or explicitly `Map.drop/2` the two internal keys on every success/error path) and add a regression test asserting no recipient address or rendered content is present in the trigger return.

## Warnings

### WR-01: Provider evidence accepts ambiguous atom/string duplicate fields

**File:** `lib/chimeway/safe_evidence.ex:388`
**Issue:** `fetch_known/3` silently prefers a string key over the atom key when both are present. This differs from `closed_facts/2`, whose `fact_value/2` deliberately drops duplicate logical keys. An adapter can therefore submit conflicting `:provider_code` and `"provider_code"` (or the other provider fields) and select which diagnostic fact becomes durable, weakening the claimed closed evidence contract.

**Fix:** Use a single duplicate-aware lookup for maps and keyword lists that returns `:missing`/an error unless exactly one logical key is supplied. Apply it to `provider_facts/1`, `attempt_attrs/1`, and `render_channels/1`, then add atom/string duplicate cases to the privacy boundary tests.

---

_Reviewed: 2026-08-13T15:30:07Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_

---
phase: 98-privacy-safe-delivery-evidence
verified: 2026-08-13T02:59:28Z
status: gaps_found
score: 7/11 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "Operators can explain delivery behavior without Chimeway retaining or emitting sensitive endpoint, credential, identity, or content data."
    status: failed
    reason: "The shared closed-fact projection accepts arbitrary binary values up to 160 bytes under approved keys. An attacker-controlled email and reset token under `reason` is retained by `Trigger` and reaches durable event payloads; digest reason values can also reach trace output."
    artifacts:
      - path: "lib/chimeway/safe_evidence.ex"
        issue: "`closed_facts/2` accepts every <=160-byte binary via `safe_scalar?/1`; `safe_digest/1` performs only key redaction."
      - path: "lib/chimeway/trigger.ex"
        issue: "`event_changeset/5` persists `SafeEvidence.event_payload/1` directly."
      - path: "lib/chimeway/traces.ex"
        issue: "Digest resolution reasons flow into explanation context and timeline entries."
    missing:
      - "Use field-specific safe code/enum grammars for retained strings and add persistence/trace regression tests with PII and token text under approved keys."
      - "Build digest projections from a closed, value-validated vocabulary rather than `Privacy.redact/1` alone."
  - truth: "Lifecycle status remains available in the delivery explanation, including a digested terminal delivery."
    status: failed
    reason: "`:digested` is omitted from `SafeEvidence.safe_status/1`, so a real digested delivery is projected with `status: nil`."
    artifacts:
      - path: "lib/chimeway/safe_evidence.ex"
        issue: "The safe-status allowlist excludes `:digested`."
    missing:
      - "Add `:digested` to the closed status set and cover a digested `Traces.explain_delivery/2` result."
---

# Phase 98: Privacy-Safe Delivery Evidence Verification Report

**Phase Goal:** Operators can explain delivery behavior without Chimeway retaining or emitting sensitive endpoint, credential, identity, or content data.
**Verified:** 2026-08-13T02:59:28Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Nested maps, lists, and keyword-shaped diagnostics redact forbidden keys consistently regardless of casing. | ✓ VERIFIED | `Chimeway.Privacy` recursively redacts and the focused suite passed (76 tests across privacy/boundary/trigger/trace/executor/telemetry files). |
| 2 | Operators can inspect delivery trace, attempt, telemetry, and proof using opaque refs, classifications, and allowlisted facts. | ✗ FAILED | Call sites use `SafeEvidence`, but `reason` is not value-validated and `:digested` becomes `nil`; the projected evidence is neither fully safe nor fully explainable. |
| 3 | Raw tokens, credentials, recipient data, trusted links, rendered content, and provider bodies from fixtures cannot escape storage or diagnostics. | ✗ FAILED | Existing sentinel tests cover forbidden *keys*, but an executable adversarial-value probe retained `alex@example.test; reset-token=abc` under the permitted `reason` key. |
| 4 | Attempt persistence and trace projections retain only outcome/classification, opaque provider reference, and narrowly validated provider facts. | ✓ VERIFIED | `Deliveries.record_attempt/2` calls `SafeEvidence.attempt_attrs/1`; executor/privacy-boundary tests passed. |
| 5 | Trigger, delivery planning, and Inbox use validated tenant/domain-bound opaque identity references. | ✓ VERIFIED | `Trigger` and `Inbox` call `SafeEvidence.opaque_ref/2`; focused Trigger/Inbox coverage is present and passed in the selected suite. |
| 6 | Telemetry and default logs project bounded metadata after metadata merge and do not inspect arbitrary adapter terms. | ✓ VERIFIED | `Telemetry.safe_meta/1` delegates to `SafeEvidence.telemetry_meta/1`; telemetry and executor sentinel tests passed. |
| 7 | Trace and Admin DTOs are safe before optional Admin redaction and preserve lifecycle explanation. | ✗ FAILED | `Traces.explain_delivery/2` invokes `SafeEvidence.trace/1`, but unvalidated digest/reason text can remain and digested status is removed. |
| 8 | Proof output is closed, parses hostile input without atomization, and describes provider handoff without engagement claims. | ✓ VERIFIED | The adoption-proof fixture calls `SafeEvidence.proof/1`; release-gate contract coverage exists and plan key-link verification passed. |
| 9 | Migration 034 irreversibly purges historical generic payload/content/provider blobs without deriving facts from raw data. | ✓ VERIFIED | Canonical migration exists; `mix verify.install_golden` and `mix verify.runtime_prefix` both exited 0. |
| 10 | Repository/template/public/prefixed migration paths have equivalent cleanup semantics. | ✓ VERIFIED | Runtime-prefix and install-golden gates exited 0; the repository copy differs from the canonical template only by expected marker/prefix rendering. |
| 11 | Phase-owned focused checks and CI provide automated evidence. | ✓ VERIFIED | The independently rerun focused suite and both install/runtime gates exited 0; requester confirmed the latest `mix ci` had a clean process exit. These green tests do not cover the failed adversarial-value path. |

**Score:** 7/11 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/chimeway/privacy.ex` | Recursive atom-safe forbidden-key boundary | ✓ VERIFIED | Substantive and exercised by `privacy_test.exs`. |
| `lib/chimeway/safe_evidence.ex` | Closed durable/diagnostic vocabulary | ✗ FAILED | Wired broadly, but arbitrary text under allowed keys is accepted; status allowlist omits `:digested`. |
| `lib/chimeway/{trigger,deliveries,inbox,telemetry,traces,admin}.ex` | Safe persistence and projections | ⚠️ PARTIAL | Wiring is present, but callers inherit the unsafe closed-fact contract. |
| `priv/adoption_proof/artifact_consumer_fixture.ex` | Closed proof construction/parser | ✓ VERIFIED | Uses `SafeEvidence.proof/1`; contract coverage exists. |
| `priv/chimeway_migrations/034_privacy_safe_delivery_evidence.exs` | Prefix-aware historical cleanup | ✓ VERIFIED | Generated-template path exercised by install/runtime verification gates. |

### Key Link Verification

All 11 declared PLAN key links were found by `gsd-tools verify.key-links`; direct source inspection corroborated the critical calls: `Deliveries.record_attempt/2 → SafeEvidence.attempt_attrs/1`, `Trigger/Inbox → opaque_ref/2`, `Telemetry → telemetry_meta/1`, `Traces → trace_attempt/timeline_detail`, `Admin → admin_fact/2`, and proof fixture → `proof/1`. The links are present, but the shared safe-evidence implementation makes the privacy outcome fail.

### Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
| --- | --- | --- | --- | --- |
| `trigger.ex` | `Event.payload` | `params → Privacy.redact → SafeEvidence.event_payload → Event.changeset` | Yes — but unsafe allowed-key value survives | ✗ HOLLOW PRIVACY BOUNDARY |
| `traces.ex` | `Explanation` | tenant-scoped Event/Notification/Delivery/Attempt query → `SafeEvidence.trace` | Yes — but digest reason/status projection is incomplete | ✗ HOLLOW PRIVACY/EXPLANATION |
| migration 034 | historical rows | generated canonical migration under public/prefixed runtime modes | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Forbidden-key recursion and sentinel surfaces | `env MIX_ENV=test mix test ...privacy/trace/executor/telemetry... --warnings-as-errors` | 76 tests, 0 failures | ✓ PASS |
| Allowed-key adversarial value is rejected | `env MIX_ENV=test mix run -e 'SafeEvidence.event_payload(%{"reason" => "alex@example.test; reset-token=abc"})'` | Returned `%{"reason" => "alex@example.test; reset-token=abc"}` | ✗ FAIL |
| Digested lifecycle status is retained | `env MIX_ENV=test mix run -e 'SafeEvidence.trace(%{status: :digested}).status'` | Returned `nil` | ✗ FAIL |
| Installer golden and public/prefixed runtime migration proof | `mix verify.install_golden && mix verify.runtime_prefix` | Exit 0 | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| PRIV-03 | 98-01, 02, 03, 04, 06 | Recursive case-normalized forbidden-key redaction before every surface. | ✓ SATISFIED | `Privacy.redact/1` handles the specified map/list/keyword/case behavior; focused recursion tests passed. |
| PRIV-04 | 98-01, 02, 03, 04, 05, 06 | No raw token/credential/recipient/link/provider body in storage or diagnostics; retain only opaque refs/classifications/allowlisted facts. | ✗ BLOCKED | `reason` accepts PII/token text and digested status is lost. No plan-declared requirement is orphaned. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `lib/chimeway/safe_evidence.ex` | 441 | Arbitrary <=160-byte binary treated as safe scalar | 🛑 BLOCKER | Allows raw sensitive values under approved keys through persistence/projections. |
| `lib/chimeway/safe_evidence.ex` | 373 | Closed status set omits `:digested` | 🛑 BLOCKER | Removes a real lifecycle terminal status from operator explanation. |

No unreferenced `TBD`, `FIXME`, or `XXX` debt markers were found in the 24 reviewed phase files.

### Gaps Summary

The phase is wired and its existing sentinel tests are green, but the test matrix only proves that forbidden **keys** are redacted. It does not prove that sensitive **values** under an allowlisted key are rejected. This is an observable privacy breach in the core persistence path, not a cosmetic concern: `Trigger.event_changeset/5` persists the unsafe result. The code-review critical finding CR-01 is therefore confirmed as a goal-blocking gap. WR-01 is also confirmed and blocks the explainability portion of the goal for digested deliveries. Neither issue is explicitly scheduled in a later milestone phase, so neither is deferred.

---

_Verified: 2026-08-13T02:59:28Z_
_Verifier: the agent (gsd-verifier)_

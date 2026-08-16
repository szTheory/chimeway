---
phase: 98-privacy-safe-delivery-evidence
verified: 2026-08-16T00:47:19Z
status: gaps_found
score: 7/11 must-haves verified
behavior_unverified: 1
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 8/11
  gaps_closed:
    - "Public Traces query APIs now project through SafeEvidence.trace_event/1 and trace_notification/1 rather than returning raw Ecto lifecycle schemas."
    - "Generated Core and Mailglass proof notifiers now provide cw_ opaque recipient references."
  gaps_remaining: []
  regressions:
    - "Privacy.redact/1 returns arbitrary structs unchanged, retaining forbidden fields."
    - "SafeEvidence.trace/1 forwards nested last_attempt and timeline values without a closed projection."
gaps:
  - truth: "Every persisted or emitted delivery fact is recursively free of raw sensitive values."
    status: failed
    reason: "The recursive privacy boundary intentionally short-circuits structs, so a struct carrying a token, recipient, body, or provider data survives unchanged through Privacy.redact/1 and SafeEvidence.proof/1."
    artifacts:
      - path: "lib/chimeway/privacy.ex"
        issue: "Line 18 returns every struct unchanged before map recursion."
      - path: "lib/chimeway/safe_evidence.ex"
        issue: "proof/1 delegates to Privacy.redact/1, exposing the struct bypass at a proof/diagnostic surface."
    missing:
      - "Recursively project non-scalar structs to maps (preserving only explicitly safe scalar structs such as DateTime as needed) before forbidden-key filtering."
      - "Add a regression with a struct containing mixed-case forbidden fields and assert its values cannot appear in proof or diagnostic output."
  - truth: "Operators can inspect delivery traces using opaque references, classifications, and allowlisted facts only."
    status: failed
    reason: "SafeEvidence.trace/1 is documented as the closed operator-explanation constructor but directly copies caller-controlled last_attempt and timeline values."
    artifacts:
      - path: "lib/chimeway/safe_evidence.ex"
        issue: "Lines 275-276 assign Map.get(value, :last_attempt) and Map.get(value, :timeline, []) without trace_attempt/1 or timeline_detail/1 projection."
    missing:
      - "Build last_attempt with trace_attempt/1 and each timeline entry with a closed at/event/detail projection; reject or omit malformed entries."
      - "Add a hostile nested provider_response/body sentinel regression for SafeEvidence.trace/1."
behavior_unverified_items:
  - truth: "Proof output is closed and the complete Core/Mailglass adoption-path commands emit proof records."
    test: "Run mix verify.adoption_paths --only core and mix verify.adoption_paths after PostgreSQL connection capacity is available."
    expected: "Both commands exit zero and emit only closed CHIMEWAY_*_PROOF records."
    why_human: "No human judgement is needed; this is a machine gate. The verifier's commands could not reach the test database because PostgreSQL returned FATAL 53300 (too_many_connections), so no fresh runtime result was produced."
---

# Phase 98: Privacy-Safe Delivery Evidence Verification Report

**Phase Goal:** Operators can explain delivery behavior without Chimeway retaining or emitting sensitive endpoint, credential, identity, or content data.
**Verified:** 2026-08-16T00:47:19Z
**Status:** gaps_found
**Re-verification:** Yes — after Plan 98-14

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Nested map, list, and keyword-shaped diagnostics redact forbidden keys case-insensitively. | ✓ VERIFIED | Pure-module positive control confirms nested map/list/keyword filtering; the existing implementation preserves retained keyword ordering. |
| 2 | An operator can inspect a delivery trace, attempt result, telemetry projection, and proof artifact using opaque references, classifications, and allowlisted facts. | ✗ FAILED | `SafeEvidence.trace/1` copies nested `last_attempt` and `timeline` terms directly. Executable probe retained both `TRACE_NESTED_SECRET` values. |
| 3 | Raw tokens, credentials, recipient data, trusted links, and provider bodies cannot expose through Chimeway-owned storage or diagnostics. | ✗ FAILED | Executable struct probe retained `STRUCT_SECRET` through `Privacy.redact/1`; `SafeEvidence.proof/1` inherits that bypass. |
| 4 | Attempt persistence retains only outcome, classification, opaque provider reference, and narrowly validated provider facts. | ✓ VERIFIED | `Deliveries.record_attempt/2` calls `SafeEvidence.attempt_attrs/1` before `DeliveryAttempt.changeset/2`; its output is a closed set of attempt fields. |
| 5 | Trigger, planning, and Inbox use tenant/domain-bound opaque identity references. | ✓ VERIFIED | Current call paths validate with `SafeEvidence.recipient_reference/1`; strict recipient validation remains present. |
| 6 | Telemetry and default logs use bounded metadata and avoid arbitrary adapter-term inspection. | ✓ VERIFIED | `telemetry_meta/1` filters through its explicit vocabulary and `Privacy.redact/1`; the adapter/log boundary does not serialize raw result terms. |
| 7 | Trace and Admin DTOs are safe before optional Admin redaction while retaining explanation. | ✗ FAILED | The repaired public query projections are closed, but the shared `SafeEvidence.trace/1` explanation constructor is an unsafe nested-data escape hatch. |
| 8 | Proof output is closed, non-atomizing, and honestly reports provider handoff. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Source now uses `cw_artifact_core_proof`/`cw_artifact_mailglass_proof`; the adoption command could not run freshly because test PostgreSQL rejected connections. |
| 9 | Migration 034 purges historical generic payload/content/provider blobs without deriving facts from raw data. | ✓ VERIFIED | Canonical migration performs deletion/nulling of legacy evidence rather than deriving retained facts from it. |
| 10 | Repository, template, public, and prefixed migration paths have equivalent cleanup semantics. | ✓ VERIFIED | Canonical template and repository migration copies are present and linked through the migration installer path. |
| 11 | Phase-focused checks provide automated evidence. | ✓ VERIFIED | Code compiles with `mix compile --warnings-as-errors`; direct executable safety probes produced the two blocking counterexamples below. |

**Score:** 7/11 truths verified (1 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/chimeway/privacy.ex` | Recursive forbidden-key boundary | ✗ HOLLOW | Exists and is used broadly, but returns structs unchanged at line 18. |
| `lib/chimeway/safe_evidence.ex` | Closed durable and diagnostic evidence vocabulary | ✗ HOLLOW | Public trace constructor forwards two nested caller values without projection. |
| `lib/chimeway/traces.ex` | Safe public trace APIs | ✓ VERIFIED | `get_trace/2`, recipient search, and correlation search project via `trace_event/1` or `trace_notification/1`. |
| `priv/adoption_proof/artifact_consumer_fixture.ex` | Runnable opaque-recipient proof construction | ⚠️ PRESENT | Source notifier refs are `cw_artifact_core_proof` and `cw_artifact_mailglass_proof`; fresh runtime gate was database-blocked. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `lib/chimeway/traces.ex` | `lib/chimeway/safe_evidence.ex` | Public trace result projection | ✓ WIRED | Lines 76, 123, and 160 invoke closed event/notification constructors. |
| `lib/chimeway/traces.ex` | `lib/chimeway/safe_evidence.ex` | `explain_delivery/2` explanation construction | ✗ PARTIAL | Calls `SafeEvidence.trace/1`, whose nested values are not closed. |
| adoption fixture | `SafeEvidence.recipient_reference/1` / `SafeEvidence.proof/1` | Explicit opaque recipient and proof output | ⚠️ PARTIAL | Static wiring is present, but runtime proof command could not obtain a DB connection. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `traces.ex` public query APIs | nested event/notification/delivery maps | Ecto preload → `trace_event/1` / `trace_notification/1` | Yes; only literal safe maps are returned | ✓ FLOWING |
| `SafeEvidence.trace/1` | `last_attempt`, `timeline` | caller map → direct `Map.get` | Yes; raw nested terms survive unchanged | ✗ UNSAFE BYPASS |
| `SafeEvidence.proof/1` | arbitrary proof payload | caller map → `Privacy.redact/1` | Struct fields can survive unchanged | ✗ UNSAFE BYPASS |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Compile and formatting | `mix compile --warnings-as-errors` and `mix format --check-formatted …` | Exit 0 | ✓ PASS |
| Struct redaction boundary | `mix run -e` probe with `%Phase98StructProbe{token: "STRUCT_SECRET"}` | Printed `struct_secret_retained=true`; forced exit 42 | ✗ FAIL |
| Nested trace boundary | `mix run -e` probe with `last_attempt.provider_response.token` and `timeline.detail.body` sentinels | Printed `trace_secret_retained=true`; forced exit 42 | ✗ FAIL |
| Focused DB test suite | `env MIX_ENV=test mix test … --warnings-as-errors` | PostgreSQL `FATAL 53300 (too_many_connections)` while creating test DB | ? ENVIRONMENT BLOCKED |
| Core adoption proof | `mix verify.adoption_paths --only core` | Began then could not complete a fresh DB-backed run under the same exhausted connection state | ? ENVIRONMENT BLOCKED |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| PRIV-03 | 98-01 through 98-14 | Recursive, case-normalized privacy redaction before all observable surfaces. | ✗ BLOCKED | Struct bypass and unprojected nested trace fields defeat recursive/closed coverage. |
| PRIV-04 | 98-01 through 98-14 | Only opaque references, classifications, and allowlisted facts enter storage/diagnostics. | ✗ BLOCKED | Raw token/body values can be emitted through the two public SafeEvidence surfaces. |

Every requirement ID declared in Phase 98 PLAN frontmatter (`PRIV-03`, `PRIV-04`) is accounted for. No Phase 98 requirement is orphaned. No later roadmap phase explicitly schedules either SafeEvidence privacy-boundary repair, so neither gap is deferred.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `lib/chimeway/privacy.ex` | 18 | Arbitrary struct returned unchanged | 🛑 BLOCKER | Forbidden fields evade recursive redaction and can reach proof/diagnostic output. |
| `lib/chimeway/safe_evidence.ex` | 275–276 | Raw nested maps assigned to closed trace result | 🛑 BLOCKER | Provider bodies/tokens/content can be emitted by the advertised trace boundary. |
| `lib/chimeway/deliveries.ex` | 740–819 | Deferred mutation lookup/update is unscoped | ⚠️ WARNING | Independently confirms CR-02, but it is an authorization defect explicitly deferred outside the Phase 98 PRIV-03/PRIV-04 privacy-evidence scope; it does not repair or defer either blocker above. |

No unreferenced `TBD`, `FIXME`, or `XXX` markers were found in the reviewed Phase 98 implementation/test artifacts.

### Gaps Summary

Plan 98-14 genuinely closes the earlier raw public-Trace return and opaque proof-recipient defects: the three query APIs now apply closed constructors and the generated recipient refs are opaque. The phase still misses its goal because the supposedly shared recursive boundary has a structural escape hatch, and the supposedly closed explanation constructor has a nested-data escape hatch. Both were reproduced with local executable probes, not inferred from SUMMARY.md or the advisory review. These are machine-testable blockers; no conversational UAT is appropriate.

---

_Verified: 2026-08-16T00:47:19Z_
_Verifier: the agent (gsd-verifier)_

---
phase: 98-privacy-safe-delivery-evidence
verified: 2026-08-15T23:42:51Z
status: gaps_found
score: 8/11 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 10/11
  gaps_closed:
    - "Every Lifecycle* notifier now supplies a cw_ opaque recipient reference and the focused lifecycle regression matrix passes."
  gaps_remaining: []
  regressions:
    - "Public Traces query APIs still return raw Ecto lifecycle schemas, bypassing SafeEvidence."
    - "The packaged Core adoption proof cannot pass the strict recipient boundary."
gaps:
  - truth: "An operator can inspect a delivery trace, attempt result, telemetry projection, and proof artifact using opaque references, classifications, and allowlisted facts."
    status: failed
    reason: "Three public trace functions return raw Ecto schemas, and the real Core adoption proof exits 70 before it can produce its proof artifact."
    artifacts:
      - path: "lib/chimeway/traces.ex"
        issue: "get_trace/2, find_traces_for_recipient/2, and find_traces_by_correlation_id/2 preload and return Event/Notification/Delivery/Attempt schemas instead of closed DTOs."
      - path: "priv/adoption_proof/artifact_consumer_fixture.ex"
        issue: "Generated Core notifier sends recipient_identity: proof-user, rejected by SafeEvidence.recipient_reference/1."
    missing:
      - "Make every public trace query return a SafeEvidence-backed closed projection (or remove raw-schema access from its public API) and add raw-legacy-value regression coverage."
      - "Generate an explicit cw_ recipient_ref for the Core and Mailglass proof notifiers, retaining any real address only as transient host render context."
      - "Require mix verify.adoption_paths --only core (and the full adoption-path gate) to exit zero."
  - truth: "Test fixtures containing raw tokens, credentials, recipient data, trusted deep links, and provider bodies cannot expose those values through Chimeway-owned storage or diagnostics."
    status: failed
    reason: "The raw-schema Trace APIs provide an emission path for legacy or directly inserted sensitive payload, render, and provider-response columns; no focused test closes that path."
    artifacts:
      - path: "lib/chimeway/traces.ex"
        issue: "Public preloads return schemas whose fields are not passed through SafeEvidence before returning them to an operator caller."
    missing:
      - "Add an executable sentinel regression that inserts legacy/raw lifecycle values and proves all public trace functions omit them."
---

# Phase 98: Privacy-Safe Delivery Evidence Verification Report

**Phase Goal:** Operators can explain delivery behavior without Chimeway retaining or emitting sensitive endpoint, credential, identity, or content data.
**Verified:** 2026-08-15T23:42:51Z
**Status:** gaps_found
**Re-verification:** Yes — after Plan 98-13

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Nested map, list, and keyword-shaped diagnostics redact forbidden keys consistently regardless of casing before they are persisted or emitted. | ✓ VERIFIED | The focused privacy matrix passed with warnings-as-errors; `Privacy.redact/1` and the persistence/diagnostic boundary tests are included. |
| 2 | An operator can inspect a delivery trace, attempt result, telemetry projection, and proof artifact using opaque references, classifications, and allowlisted facts. | ✗ FAILED | `Traces.get_trace/2` and both `find_traces*` functions return raw preloaded schemas; `mix verify.adoption_paths --only core` exits 70. |
| 3 | Test fixtures containing raw tokens, credentials, recipient data, trusted deep links, and provider bodies cannot expose those values through Chimeway-owned storage or diagnostics. | ✗ FAILED | Existing sentinels cover selected closed projections, but the public raw-schema trace path bypasses those projections and has no sentinel regression. |
| 4 | Attempt persistence retains only outcome, classification, opaque provider reference, and narrowly validated provider facts. | ✓ VERIFIED | `Deliveries.record_attempt/2` is linked to `SafeEvidence.attempt_attrs/1`; focused boundary tests pass. |
| 5 | Trigger, planning, and Inbox use tenant/domain-bound opaque identity references. | ✓ VERIFIED | `Trigger` and `Workflows` call `SafeEvidence.recipient_reference/1`; malformed and slug-like values are covered by the focused matrix. |
| 6 | Telemetry and default logs use bounded metadata after merge and avoid arbitrary adapter-term inspection. | ✓ VERIFIED | Executor/Telemetry SafeEvidence links and the telemetry integration suite pass in the focused matrix. |
| 7 | Trace and Admin DTOs are safe before optional Admin redaction while preserving lifecycle explanation. | ✗ FAILED | `explain_delivery/2` is safe, but the other public trace APIs bypass it and return raw DTO-less Ecto schemas. |
| 8 | Proof output is closed, non-atomizing, and reports provider handoff without engagement claims. | ✗ FAILED | Structural proof code exists, but its actual Core proof run fails at the strict recipient boundary and produces no proof. |
| 9 | Migration 034 purges historical generic payload/content/provider blobs without deriving facts from raw data. | ✓ VERIFIED | Migration-contract tests pass in the focused matrix; canonical and copied migration artifacts pass substantive checks. |
| 10 | Repository, template, public, and prefixed migration paths have equivalent cleanup semantics. | ✓ VERIFIED | The migration artifacts and installer/runtime-prefix links pass structural verification; migration contract tests pass. |
| 11 | Phase-focused checks provide automated evidence. | ✓ VERIFIED | The exact 11-file Phase 98 matrix exits 0 with `--warnings-as-errors` (run by verifier). |

**Score:** 8/11 truths verified (0 present, behavior-unverified)

### Required Artifacts

All **38/38 declared artifacts** exist and pass the structural substantive check. That does not establish safety: the trace and adoption-proof artifacts have failed behavior/data-flow checks below.

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/chimeway/privacy.ex` | Recursive forbidden-key boundary | ✓ VERIFIED | Substantive and exercised by the focused privacy matrix. |
| `lib/chimeway/safe_evidence.ex` | Closed evidence vocabulary | ✓ VERIFIED | Wired into durable writes, telemetry, safe explanation, and recipient validation. |
| `lib/chimeway/traces.ex` | Safe operator trace APIs | ✗ HOLLOW | Safe `explain_delivery/2` exists, but three separately public raw-schema paths bypass it. |
| `priv/adoption_proof/artifact_consumer_fixture.ex` | Runnable closed proof construction | ✗ HOLLOW | Has `SafeEvidence.proof/1` wiring, but generated notifier input is rejected before proof construction. |
| `test/chimeway/integration/delivery_lifecycle_test.exs` | Opaque-recipient lifecycle proof | ✓ VERIFIED | All Lifecycle fixtures use `cw_lifecycle_*` refs; focused matrix exits zero. |

### Key Link Verification

The declarative tool found all 38 artifacts. It found 23/27 links directly; the four escaped-pattern/description links were manually confirmed in source. Those structural links do not cure the two failed data flows.

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `lib/chimeway/deliveries.ex` | `lib/chimeway/safe_evidence.ex` | attempt attrs projection | ✓ WIRED | `SafeEvidence.attempt_attrs/1` is called before attempt persistence. |
| `lib/chimeway/traces.ex` | `lib/chimeway/safe_evidence.ex` | closed explanation/timeline projection | ⚠️ PARTIAL | `explain_delivery/2` uses `SafeEvidence.trace/1`; raw public trace functions do not. |
| `lib/chimeway/trigger.ex` | `lib/chimeway/safe_evidence.ex` | opaque recipient validation | ✓ WIRED | `recipient_reference/1` is called before notification persistence. |
| `lib/chimeway/workflows.ex` | `lib/chimeway/safe_evidence.ex` | actor-reference validation | ✓ WIRED | `find_runs_waiting_for_signal/3` validates the actor before querying. |
| `priv/adoption_proof/artifact_consumer_fixture.ex` | `lib/chimeway/safe_evidence.ex` | proof construction | ✗ NOT FUNCTIONAL | Generated notifier's `proof-user` does not meet the required recipient grammar. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `safe_evidence.ex` → `trigger.ex` | persisted recipient identity | host opaque ref → strict validator → notification insert | Yes; raw slugs rejected | ✓ FLOWING SAFELY |
| `oban_worker.ex` | hydration failure outcome | resolver failure → fixed attempt evidence → retry/exhaustion | Yes; bounded categorical facts | ✓ FLOWING SAFELY |
| `traces.ex` public query APIs | returned event/notification/delivery/attempt fields | direct Ecto preload | Yes, including raw schema fields | ✗ UNSAFE BYPASS |
| adoption Core proof | `CHIMEWAY_CORE_PROOF` evidence | generated notifier → Trigger → explanation → proof | No; Trigger returns `{:error, :unsafe_evidence}` | ✗ DISCONNECTED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Exact Phase 98 focused regression matrix | `env MIX_ENV=test mix test` over the declared 11 files with `--warnings-as-errors` | Exit 0; warnings/log fixtures only | ✓ PASS |
| Packaged Core adoption proof | `mix verify.adoption_paths --only core` | `[adoption:core] FAIL stage=core status=70` | ✗ FAIL |
| Public trace projection safety | Source/data-flow inspection of `Traces.get_trace/2`, `find_traces_for_recipient/2`, and `find_traces_by_correlation_id/2` | Each preloads and returns raw Ecto schemas without `SafeEvidence` projection | ✗ FAIL |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| PRIV-03 | 98-01 through 98-13 | Case-normalized recursive redaction before every persistence and diagnostic surface. | ✗ BLOCKED | Public raw trace APIs are a diagnostic surface that bypasses the closed projection. |
| PRIV-04 | 98-01 through 98-13 | No raw recipient/adopter data in storage or diagnostics; retain only opaque refs/classifications/allowlisted facts. | ✗ BLOCKED | Raw lifecycle schemas can be emitted by public trace APIs; proof path is non-runnable. |

Every requirement ID declared in Phase 98 PLAN frontmatter is accounted for. No Phase 98 requirement is orphaned. No later roadmap phase explicitly schedules a privacy-safe public trace API or adoption-proof fixture repair, so these gaps are not deferred.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `lib/chimeway/traces.ex` | 53–76, 92–121, 136–157 | Public APIs return full preloaded Ecto schemas | 🛑 BLOCKER | Bypasses the shared privacy boundary and can emit legacy/directly inserted raw values. |
| `priv/adoption_proof/artifact_consumer_fixture.ex` | 507, 553 | Generated proof recipients violate strict opaque-recipient contract | 🛑 BLOCKER | Core proof cannot reach its safe evidence assertions; Mailglass has the same defect. |
| `lib/chimeway/deliveries.ex` | 497–502 | Provider-message lookup is unscoped by tenant/adapter | ⚠️ WARNING | Independently confirmed code-review regression; can select an ambiguous delivery. |
| `lib/chimeway/workflows.ex` | 424 | Caller-controlled `delivery_id` copied to transition relationship | ⚠️ WARNING | Independently confirmed code-review regression; relationship is not validated against the matched run/tenant. |

No unreferenced `TBD`, `FIXME`, or `XXX` marker was found in the scanned Phase 98 artifacts.

### Gaps Summary

Phase 98's closed write, telemetry, safe-explanation, migration, and opaque-recipient paths have executable passing evidence. The goal nevertheless fails at two exposed seams: public trace functions can return raw lifecycle schemas outside the `SafeEvidence` boundary, and the actual packaged Core adoption proof fails before generating evidence because its notifier still supplies a raw recipient identity. These are objectively machine-testable blockers; per project policy, no conversational UAT is requested.

---

_Verified: 2026-08-15T23:42:51Z_
_Verifier: the agent (gsd-verifier)_

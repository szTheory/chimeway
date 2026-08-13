---
phase: 98-privacy-safe-delivery-evidence
verified: 2026-08-13T20:32:50Z
status: gaps_found
score: 8/11 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 7/11
  gaps_closed:
    - "Caller-supplied precomputed rendering is transient; delivery persistence normalizes render data to an empty map."
    - "Trigger separates private dispatch context from its public result and omits rendering and recipient handoffs."
    - "Duplicate atom/string evidence fields are rejected and provider codes use the closed grammar."
  gaps_remaining:
    - "Queued context-hydration failure has no durable lifecycle evidence."
    - "Slug-like raw recipient identities are persisted unchanged."
  regressions: []
gaps:
  - truth: "An operator can inspect a delivery trace and attempt result using opaque references, classifications, and allowlisted facts."
    status: failed
    reason: "An email delivery whose host render context cannot be resolved returns an Oban error before Executor.run_delivery/1, so no attempt, terminal state, or safe reason is persisted."
    artifacts:
      - path: "lib/chimeway/dispatch/oban_worker.ex"
        issue: "do_dispatch/3 returns hydrate_for_execution/1's error directly at lines 187-189; no Deliveries record/suppress/exhaust path runs."
      - path: "lib/chimeway/delivery_planning.ex"
        issue: "hydrate_execution_delivery/1 collapses resolver failures to :render_context_unavailable at lines 62-65, but the worker never durably records that classification."
    missing:
      - "Persist a bounded, safe attempt and lifecycle outcome for unavailable or invalid render context before Oban retries/discards."
      - "Add a worker regression that exhausts a missing-context job and asserts the final delivery state, attempt/timeline evidence, and absence of raw context."
  - truth: "Raw recipient or adopter data never enters Chimeway-owned storage or diagnostics; only opaque references are retained."
    status: failed
    reason: "recipient_reference/1 accepts any slug matching opaque_id?/1 unchanged, and Trigger persists that result as notifications.recipient_identity."
    artifacts:
      - path: "lib/chimeway/safe_evidence.ex"
        issue: "The opaque_id?/1 branch at lines 115-116 accepts alex-smith; the predicate at lines 708-710 only validates slug syntax, not a namespaced opaque reference."
      - path: "lib/chimeway/trigger.ex"
        issue: "notifications_attrs/6 writes recipient_ref(recipient) directly to the durable recipient_identity column at line 244."
    missing:
      - "Accept only documented namespaced opaque references (and the intentional user:<opaque-id> form); hash all other recipient input to cw_recipient_<hash>."
      - "Add persistence regressions for alex-smith and similar slug-like values proving only the opaque projection is stored."
---

# Phase 98: Privacy-Safe Delivery Evidence Verification Report

**Phase Goal:** Recursive redaction and bounded diagnostics across every observable Chimeway surface.
**Verified:** 2026-08-13T20:32:50Z
**Status:** gaps_found
**Re-verification:** Yes — after Wave 7 and Wave 8 gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Nested map, list, and keyword diagnostics remove forbidden keys case-insensitively without atomizing input. | ✓ VERIFIED | `Privacy.redact/1` is recursive and the focused 103-test matrix passed. |
| 2 | Operators can inspect delivery traces and attempts using opaque references, classifications, and allowlisted facts. | ✗ FAILED | A queued email resolver/hydration failure returns before attempt/state recording; no traceable durable outcome exists. |
| 3 | Fixture tokens, credentials, recipient data, links, rendered content, and provider bodies cannot escape Chimeway-owned storage or diagnostics. | ✗ FAILED | `recipient_reference("alex-smith")` returns the raw slug, which `Trigger` persists as `notifications.recipient_identity`. |
| 4 | Attempt persistence retains only outcome, classification, opaque provider reference, and narrowly validated provider facts. | ✓ VERIFIED | `logical_lookup/3` rejects duplicate atom/string aliases; provider-code validation is closed. |
| 5 | Trigger, planning, and Inbox use tenant/domain-bound opaque identity references. | ✗ FAILED | Tenant scoping is wired, but `recipient_reference/1` treats an arbitrary raw slug as an opaque reference before Trigger persists it. |
| 6 | Telemetry and default logs use bounded metadata after merge and avoid arbitrary adapter-term inspection. | ✓ VERIFIED | `Telemetry.safe_meta/1` delegates to the closed `SafeEvidence.telemetry_meta/1` projection. |
| 7 | Trace and Admin DTOs are safe before optional Admin redaction while preserving lifecycle explanation. | ✓ VERIFIED | Safe trace/admin projections are wired; reloaded delivery render data is empty in the worker hydration test. |
| 8 | Proof output is closed, non-atomizing, and reports provider handoff without engagement claims. | ✓ VERIFIED | Adoption proof fixture consumes `SafeEvidence.proof/1`; its artifact/link checks pass. |
| 9 | Migration 034 purges historical generic payload/content/provider blobs without deriving facts from raw data. | ✓ VERIFIED | Canonical/repository migration artifacts and prefix-aware generation links pass. |
| 10 | Repository, template, public, and prefixed migration paths have equivalent cleanup semantics. | ✓ VERIFIED | Plan 06's three artifacts and two generation/runtime links pass verification. |
| 11 | Phase-focused checks provide automated evidence. | ✓ VERIFIED | Independently ran the declared Phase 10 focused command: 103 tests, 0 failures. Full `mix test` timeout remains inconclusive, not passing evidence. |

**Score:** 8/11 truths verified (0 present, behavior-unverified)

### Required Artifacts

All 29 declared artifacts across Plans 01–10 exist and are substantive. `verify.artifacts` reports **29/29 passed**. The critical runtime artifacts are nevertheless partial at data-flow level:

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/chimeway/privacy.ex` | Recursive atom-safe redaction | ✓ VERIFIED | Wired into closed projections. |
| `lib/chimeway/safe_evidence.ex` | Opaque identity/evidence constructors | ✗ PARTIAL | `recipient_reference/1` retains arbitrary slug-shaped input. |
| `lib/chimeway/trigger.ex` | Safe persistence/public boundary | ✗ PARTIAL | Persists the unsafe recipient-reference result. |
| `lib/chimeway/delivery_planning.ex` | Transient-only render hydration | ⚠️ PARTIAL | Correctly collapses resolver failure, but that failure is not handed to a durable worker outcome. |
| `lib/chimeway/dispatch/oban_worker.ex` | Explainable queued execution | ✗ PARTIAL | Hydration error bypasses all attempt/state writers. |
| `lib/chimeway/{deliveries,traces,admin,telemetry,inbox}.ex` | Safe evidence projections | ✓ VERIFIED | Declared safe-projection links are present. |
| `priv/chimeway_migrations/034_privacy_safe_delivery_evidence.exs` | Historical cleanup | ✓ VERIFIED | Canonical template and generated-copy links pass. |

### Key Link Verification

`verify.key-links` reports **20/20 declared links wired** across Plans 01–10. This does not prove the goal: the hydration-error data flow terminates at the `with` in `ObanWorker.do_dispatch/3`, before the wired `Executor → Deliveries.record_attempt/2` route.

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `trigger.ex` / `delivery_planning.ex` | Private recipient/render context | notifier → in-process adapter handoff | Yes, but no longer durable/public | ✓ FLOWING SAFELY |
| `safe_evidence.ex` → `trigger.ex` | `recipient_identity` | notifier recipient → `recipient_reference/1` → notification insert | Yes, raw slug can flow unchanged | ✗ LEAKING |
| `oban_worker.ex` | Resolver failure outcome | hydration error → worker `with` | No durable attempt or state transition | ✗ DISCONNECTED |
| `traces.ex` / `admin.ex` | Operator DTO facts | tenant-scoped lifecycle queries → `SafeEvidence` | Closed facts | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Declared focused Phase 98 matrix | `env MIX_ENV=test mix test ... --warnings-as-errors` | 103 tests, 0 failures | ✓ PASS |
| Slug recipient projection | `mix run --no-start -e 'SafeEvidence.recipient_reference("alex-smith")'` | `{:ok, "alex-smith"}` | ✗ FAIL |
| Email recipient projection control | same command with `private@example.test` | `{:ok, "cw_recipient_f0b5..."}` | ✓ PASS |
| Worker suite | `env MIX_ENV=test mix test test/chimeway/dispatch/oban_worker_test.exs --warnings-as-errors` | 14 tests, 0 failures | ✓ PASS, but missing-context durable-evidence behavior is untested |
| Full workspace test suite | `mix test` | Previously exceeded 600-second limit with no reported failures | ? INCONCLUSIVE |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| PRIV-03 | 98-01 through 98-10 | Recursive case-normalized redaction before every persistence and diagnostic surface. | ✗ BLOCKED | Raw slug-like recipient input bypasses opaque projection before notification persistence. |
| PRIV-04 | 98-01 through 98-10 | No raw recipient/adopter data in storage or diagnostics; retain only opaque refs/classifications/allowlisted facts. | ✗ BLOCKED | Raw slug persists; resolver failure yields no explainable lifecycle evidence. |

Every requirement ID declared by all ten PLAN frontmatters is accounted for. No Phase 98 requirement is orphaned. No later roadmap phase specifically schedules either repair, so neither is deferred.

### Review Findings Adjudication

| Finding | Verdict | Evidence |
| --- | --- | --- |
| Queued hydration failure lacks durable evidence | 🛑 BLOCKER CONFIRMED | `ObanWorker.do_dispatch/3` lines 187–189 returns `:render_context_unavailable` directly; `DeliveryPlanning` emits it at lines 62–65; no call to `record_attempt`, `suppress_delivery`, or `exhaust_delivery` is reachable on that branch. |
| Slug-like recipient identity bypasses opaque projection | 🛑 BLOCKER CONFIRMED | `recipient_reference/1` lines 105–120 preserves `opaque_id?/1`; standalone runtime check returns raw `alex-smith`; `Trigger` persists this result at line 244. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `lib/chimeway/dispatch/oban_worker.ex` | 187–189 | Error path bypasses lifecycle persistence | 🛑 BLOCKER | Operator cannot explain a permanently failing queued delivery. |
| `lib/chimeway/safe_evidence.ex` | 115–116, 708–710 | Syntax-only slug accepted as opaque identity | 🛑 BLOCKER | Raw recipient/adopter-like data enters durable notification storage. |

No phase-owned unreferenced `TBD`, `FIXME`, or `XXX` marker was found.

### Gaps Summary

Wave 7 repairs successfully removed the earlier trusted-render, public-return, and duplicate-provider-fact leaks; the focused matrix independently passes. Two remaining data flows still falsify the roadmap contract: an unavailable host execution context leaves no durable explanation, and a slug that may be recipient data is treated as an opaque reference and stored unchanged. Both are machine-testable blocking gaps; no conversational UAT is appropriate.

---

_Verified: 2026-08-13T20:32:50Z_
_Verifier: the agent (gsd-verifier)_

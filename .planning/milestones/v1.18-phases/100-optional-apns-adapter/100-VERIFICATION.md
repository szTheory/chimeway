---
phase: 100-optional-apns-adapter
verified: 2026-08-22T17:52:25Z
status: passed
score: 5/5 roadmap must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/5
  gaps_closed:
    - "The enabled packaged-consumer warning-strict gate completes successfully."
    - "Open references reject identifiers, URLs, controls, invalid representations, and over-bound values at durable, reload, and direct-payload boundaries."
    - "Caller-supplied collapse IDs reject CR/LF/control bytes before the APNs request header seam."
  gaps_remaining: []
  regressions: []
---

# Phase 100: Optional APNs Adapter Verification Report

**Phase Goal:** An APNs-enabled host can dispatch safe, bounded push requests and receive honest target-specific provider outcomes without adding push dependencies to other hosts.
**Verified:** 2026-08-22T17:52:25Z
**Status:** passed
**Re-verification:** Yes — stale gap report replaced after Plans 100-10 and 100-11.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Non-push hosts run without Pigeon/APNs configuration; opted-in hosts use the Pigeon-backed adapter through host-controlled lookup. | ✓ VERIFIED | Root `mix.exs` has no Pigeon dependency; `Transport` uses dynamic `Module.concat`/`Code.ensure_loaded?` only. The independently run `bash scripts/verify-apns.sh` passed both disabled and enabled clean consumers, including the synthetic Pigeon handoff. |
| 2 | A request has target-correct environment/topic, stable `apns-id`, bounded allowlisted payload, expiry, and opaque one-time reference. | ✓ VERIFIED | `RequestIntent` persists validated environment/topic/id/expiry/open/collapse facts; `Payload.build/2` independently validates the shared closed reference grammar and enforces 4096 bytes. The 34-test focused APNs contract passed. |
| 3 | Provider outcomes are honest and target-specific. | ✓ VERIFIED | `APNS.deliver/2` separates pre-provider lookup/payload failures from the narrowly guarded transport handoff; `result_test.exs` proves exact 410 triple-only invalidation and retry classification. Focused suite passed. |
| 4 | Expiry prevents send/retry; collapse is opt-in, installation-safe, and absent for distinct work. | ✓ VERIFIED | Expiry is checked before lookup/transport; request tests exercise equality expiry, derived exact-scope collapse, default omission, and explicit `[A-Za-z0-9_-]{1,64}` validation. Focused suite passed. |
| 5 | Invalidation changes only the exact tenant/environment/topic/binding revision, never a replacement or another installation. | ✓ VERIFIED | `APNS.classify_result/3` builds `BindingLookup.InvalidationKey` from target tenant/revision and persisted intent environment/topic; invalidation test asserts the exact key and rejects incomplete/wrong triples. |

**Score:** 5/5 roadmap truths verified (0 present, behavior-unverified).

### Plan Must-Haves

All 59 declared plan truths were checked against the implementation, tests, and executable gate; the 17 declared prohibitions have executable enforcement in the corresponding request, adapter, result, lifecycle, migration, and package-contract tests. No Plan frontmatter requirement is orphaned.

| Plans | Status | Direct evidence |
| --- | --- | --- |
| 100-01 through 100-04 | ✓ VERIFIED | Durable target intent, bounded request construction, expiry/no-I/O, optional transport, outcome algebra, exact locked completion, and 410-only invalidation are implemented in the delivery/APNs modules and covered by the focused APNs suite. |
| 100-05 through 100-08 | ✓ VERIFIED | `scripts/verify-apns.sh`, fixture consumer, `mix verify.apns`, CI `verify_apns`, API coverage, raw-stream bridge, package graph checks, and CI aggregate wiring are present; the package script passed. |
| 100-09 | ✓ VERIFIED | `safe_lookup/1` and `safe_payload/2` normalize exceptions before `safe_transport/2`; adapter tests prove no transport invocation for those paths. |
| 100-10 | ✓ VERIFIED | `OpaqueReference.valid?/1` is used by `RequestIntent.new/2`, storage reload, and `Payload.build/2`; malformed stored input cannot reach the fake transport; request tests exercise accepted/rejected boundary values. |
| 100-11 | ✓ VERIFIED | The gate runs normal `mix deps.compile` followed by `mix cmd --cd "$package_path" mix compile --force-elixir --no-deps-check --warnings-as-errors`; its tagged command-order/mutation contract passed 2/2 and the complete script passed. |

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/chimeway/apns/opaque_reference.ex` | Shared closed opaque-reference grammar | ✓ VERIFIED | Anchored ASCII `open-`/`open_` grammar with optional `cw_` prefix and 256-byte bound. |
| `lib/chimeway/apns/request_intent.ex` | Safe durable intent, expiry, collapse derivation | ✓ VERIFIED | Substantive validation/storage/reload code; wired from planning to adapter reload. Explicit collapse is constrained to 1..64 header-safe bytes. |
| `lib/chimeway/apns/payload.ex` | Closed bounded APNs payload | ✓ VERIFIED | Emits only alert plus `chimeway_open_ref`; revalidates direct calls and rejects >4096 bytes. |
| `lib/chimeway/adapters/apns.ex` | Stage-scoped delivery and honest outcome classification | ✓ VERIFIED | Wires intent → expiry → exact lookup → payload → transport → typed result; exception boundaries preserve pre-handoff versus ambiguity semantics. |
| `lib/chimeway/apns/{binding_lookup,transport}.ex` | Host custody seam and optional Pigeon bridge | ✓ VERIFIED | Exact scope echo validation; dynamic Pigeon resolution; raw end-stream closes only recognized complete provider facts. |
| APNs migrations and golden fixtures | Nullable safe intent storage across install modes | ✓ VERIFIED | All four copies add/remove only `apns_request_intent`; focused migration contract passed. |
| `scripts/verify-apns.sh` and consumer fixture | Hermetic disabled/enabled package proof | ✓ VERIFIED | Exists, substantive, invoked by local alias/CI, and completed exit 0 in this verification. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Planning | `DeliveryTarget.apns_request_intent` | `RequestIntent.to_storage/1` | ✓ WIRED | `DeliveryTargets.plan_targets/3` stores the validated immutable intent. |
| Adapter | durable intent and host lookup | `RequestIntent.from_storage/1` → `BindingLookup.resolve/1` | ✓ WIRED | Reload happens before lookup; binding request carries tenant/environment/topic/revision. |
| Adapter | payload and transport | `Payload.build/2` → `Transport.push/3` | ✓ WIRED | Payload response is used to construct the actual request; tests assert no transport on invalid input/pre-provider exceptions. |
| Pigeon raw stream | result classifier / host CAS | `PigeonAdapter.process_end_stream/2` → `APNS.classify_result/3` | ✓ WIRED | Complete correlated 410 facts reach exact invalidation only; malformed/normalized variants remain non-authoritative. |
| Local + hosted gate | package verifier | `mix verify.apns` and `verify_apns` | ✓ WIRED | `mix.exs` calls the script; CI job runs `mix verify.apns`; both PR and non-PR aggregators require `verify_apns`. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Request intent | `apns_request_intent` | planned exact target → persisted map → adapter reload | Validated host-declared routing facts | ✓ FLOWING |
| Provider request | `Transport.Request` | exact transient host lookup + intent + rendered payload | Request includes target topic/environment/id/expiry/collapse and bounded JSON | ✓ FLOWING |
| Provider outcome | typed adapter result | Pigeon/fake transport → classifier → target outcome | Closed status/reason/timestamp facts; exact invalidation key | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Full disabled/enabled packaged consumer proof | `bash scripts/verify-apns.sh` | Exit 0; emitted `{"provider":"apns","outcome":"provider_accepted","environment":"sandbox","proof":"not_live_not_device_not_open"}` | ✓ PASS |
| APNs contracts (payload, input boundaries, outcomes, lifecycle, evidence, migrations) | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns/api_coverage_test.exs test/chimeway/apns/request_test.exs test/chimeway/apns/result_test.exs test/chimeway/adapters/apns_test.exs test/chimeway/safe_evidence_test.exs test/chimeway/migration_contract_test.exs --warnings-as-errors` | 34 tests, 0 failures | ✓ PASS |
| Warning-gate order/non-vacuity contract | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only apns_warning_gate_contract --warnings-as-errors` | 2 tests, 0 failures | ✓ PASS |
| Changed APNs formatting | `mix format --check-formatted ...` | Exit 0 | ✓ PASS |

### Probe Execution

Step 7c: no `scripts/*/tests/probe-*.sh` probe is declared for this phase. The declared executable package proof was run directly above.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| APNS-01 | 03, 05, 06, 08, 09, 11 | Optional Pigeon adapter with clean non-push consumption | ✓ SATISFIED | No static Pigeon dependency in root; package proof passed both modes; strict Chimeway-owned warning gate mutation contract passed. |
| APNS-02 | 01, 02, 03, 05, 08, 10 | Exact host custody and safe bounded request/open reference | ✓ SATISFIED | Durable/reload/direct-payload closed validation, payload bound, and exact lookup are code-wired and test-passing. |
| APNS-03 | 04, 05, 06, 07, 08, 09 | Classified outcomes and exact-binding invalidation | ✓ SATISFIED | Result matrix and raw-response bridge distinguish retryable/permanent/ambiguous/invalidated paths and bind invalidation exactly. |
| APNS-04 | 01, 02, 03, 04, 05, 08 | Absolute expiry and explicit suppression | ✓ SATISFIED | Adapter expiry check precedes lookup/transport; request/lifecycle contracts passed. |
| APNS-05 | 01, 03, 05, 08, 10 | Opt-in installation-safe collapse; no implicit coalescing | ✓ SATISFIED | Default is nil; derived scope includes occurrence/binding/environment/topic; explicit IDs have strict grammar. |
| APNS-06 | 04, 05, 08, 09 | Distinct explainable operator outcome vocabulary | ✓ SATISFIED | Typed outcome algebra, `SafeEvidence`, worker lifecycle, and focused contract suite preserve accepted/retryable/permanent/ambiguous/expired/invalidated distinctions. |

`REQUIREMENTS.md` maps no additional requirement to Phase 100. Every APNS-01 through APNS-06 declaration in Plans 100-01…100-11 is accounted for above; none is orphaned.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| — | — | No unreferenced `TBD`, `FIXME`, or `XXX`; no placeholder/empty implementation or hardcoded hollow data flow found in reviewed Phase 100 artifacts. | — | — |

The reviewed script intentionally shows normal dependency-compile diagnostics before its Chimeway-only strict compiler stage; the tagged mutation tests prove that the Chimeway stage itself remains warning-strict and load-bearing. This is not warning suppression or a dependency-source modification.

### Gaps Summary

None. The prior failures are closed with current code and executable evidence. Per project policy, this machine-testable phase has no human-verification or UAT item.

---

_Verified: 2026-08-22T17:52:25Z_
_Verifier: the agent (gsd-verifier)_

---
phase: 100-optional-apns-adapter
verified: 2026-08-21T16:08:00Z
status: gaps_found
score: 34/36 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 11/12
  gaps_closed: []
  gaps_remaining:
    - "A represented 410 ExpiredToken or Unregistered response must traverse the real Pigeon bridge, APNS.classify_result/3, and the exact host CAS in one executable path."
  regressions: []
gaps:
  - truth: "D-16/APNS-03: a represented 410 ExpiredToken or Unregistered response traverses the production response bridge and APNS.classify_result/3 before invoking the host compare-and-update with the original tenant, environment, topic, and binding revision."
    status: failed
    reason: "The raw Pigeon bridge and the APNS classifier/CAS are covered only in disconnected tests. No test invokes APNS.deliver/2 with the real Pigeon transport and represented end stream, so the required production bridge-to-CAS behavior is not executable evidence."
    artifacts:
      - path: "test/fixtures/apns_consumer/test/apns_consumer_test.exs"
        issue: "Its 410 test proves Pigeon.push -> Transport.Result, but stops before APNS.deliver/2 and host invalidation."
      - path: "test/chimeway/apns/result_test.exs"
        issue: "Its CAS test injects a fake Transport.Result directly through APNSFakeTransport rather than receiving the Pigeon-produced result."
    missing:
      - "Add a no-network enabled-consumer/integration test that configures the host lookup and exact CAS callback, calls APNS.deliver/2 using the real optional Pigeon transport, injects a correlated 410 ExpiredToken or Unregistered end stream, and asserts the original four-field CAS key."
  - truth: "D-14/D-15: stock normalized Pigeon atoms, incomplete or malformed response bodies, wrong status/reason combinations, and uncorrelated streams remain permanent/non-authoritative and cannot invalidate a binding."
    status: failed
    reason: "The code fails closed and unit tests cover several individual projections, but none executes those real Pigeon response variants through APNS.deliver/2 and asserts that the host CAS was not called."
    artifacts:
      - path: "test/fixtures/apns_consumer/test/apns_consumer_test.exs"
        issue: "Malformed/wrong-status checks call extract_response/1 directly; the raw callback test covers only the valid Unregistered 410 path."
      - path: "test/chimeway/apns/result_test.exs"
        issue: "Non-authority variants use APNSFakeTransport, not PigeonAdapter/Pigeon.push."
    missing:
      - "Extend the same real-transport integration test with normalized, incomplete, malformed, wrong-scope/status, and uncorrelated variants that assert no successful invalidation."
---

# Phase 100: Optional APNs Adapter Verification Report

**Phase Goal:** An APNs-enabled host can dispatch safe, bounded push requests and receive honest target-specific provider outcomes without adding push dependencies to other hosts.
**Verified:** 2026-08-21T16:08:00Z
**Status:** gaps_found
**Re-verification:** Yes — after claimed gap closure

## Goal Achievement

The previous APNS-03 code defect is corrected at the source level: the Pigeon end-stream bridge combines HTTP status with the decoded APNs body, preserves recognized retryable response facts, and maps `:not_started` to pre-handoff unavailability. The required full production behavior remains unproven because the bridge and classifier/CAS are tested as separate seams.

### Observable Truths

| Plan | # | Truth | Status | Evidence |
| --- | --- | --- | --- | --- |
| 100-01 | 1 | Planning persists one validated safe intent per binding and execution reloads it unchanged. | ✓ VERIFIED | `DeliveryTargets.plan_targets/3` stores `RequestIntent.to_storage/1`; `APNS.deliver/2` reloads it with `from_storage/1`. |
| 100-01 | 2 | Lookup and dispatcher material resolve only after durable attempt start. | ✓ VERIFIED | Adapter is invoked through the target executor after claim; tracer contracts are included in the APNs gate. |
| 100-01 | 3 | Invalid lookup, expiry, and over-4096-byte payload stop before transport. | ✓ VERIFIED | Ordered `with` gates in `APNS.deliver/2`; `Payload.build/2` bounds final JSON. |
| 100-01 | 4 | Collapse is default-absent, opaque, bounded, and exact-target scoped. | ✓ VERIFIED | `RequestIntent.collapse_id/4` hashes occurrence, revision, environment, and topic; validates 64 bytes. |
| 100-01 | 5 | 4096/4097 payload and 64/65 collapse boundaries are enforced. | ✓ VERIFIED | APNs request contracts are included in the passing `verify.apns` gate. |
| 100-01 | 6 | Nil intent remains valid for non-APNs targets; invalid APNs intent fails before lookup. | ✓ VERIFIED | `TargetResolver.valid_request_intent?(nil)` and adapter `from_storage/1` gate; focused tests pass. |
| 100-01 | 7 | Duplicate target planning retains one intent and concurrent execution permits one handoff. | ✓ VERIFIED | Unique conflict target plus Phase 99 claim/outcome contracts; deterministic regression gate passed 738/738 with seed 0. |
| 100-01 | 8 | Expiry creates one terminal result without provider I/O under repeats/concurrency. | ✓ VERIFIED | Expiry precedes lookup/transport; tracer and worker contracts are part of `verify.apns`. |
| 100-02 | 1 | All install paths add only nullable safe intent storage. | ✓ VERIFIED | Canonical/public/prefixed migrations add only `:apns_request_intent, :map`. |
| 100-02 | 2 | Public/prefixed upgrades preserve intent through up/down/up and retry reads. | ✓ VERIFIED | Migration/runtime contracts are part of the APNs gate. |
| 100-02 | 3 | Canonical and both golden migrations are structurally equivalent. | ✓ VERIFIED | Golden-diff contract and matching migration bodies. |
| 100-02 | 4 | Rollback removes only the variant column. | ✓ VERIFIED | All three down migrations remove only `:apns_request_intent`. |
| 100-03 | 1 | Pigeon is optional and core APNs modules boot without it. | ✓ VERIFIED | Dynamic Pigeon resolution is isolated in `transport.ex`; fresh disabled package consumer passed. |
| 100-03 | 2 | Lookup requires exact tenant/environment/topic/revision and normalizes failures safely. | ✓ VERIFIED | `BindingLookup.echoes?/2` compares all four facts; invalid results normalize to `:binding_not_found`. |
| 100-03 | 3 | Request reconstruction reuses durable facts and resolves only transient material per attempt. | ✓ VERIFIED | Adapter reloads intent then invokes host lookup immediately before request construction. |
| 100-03 | 4 | Payload has only allowlisted APS alert/open-ref keys and a final 4096-byte bound. | ✓ VERIFIED | Closed `Payload.build/2` JSON shape and byte-size gate. |
| 100-03 | 5 | Collapse is opt-in and `apns-id` is correlation only. | ✓ VERIFIED | Optional collapse derivation and request construction use separate fields. |
| 100-03 | 6 | Timeout/exit/lost response is ambiguous; only the raw Pigeon seam can preserve an invalidation triple. | ✓ VERIFIED | Transport maps timeout/rescue/catch to ambiguity; optional raw bridge is exercised by the package consumer. |
| 100-04 | 1 | Conclusive outcomes close the exact target/attempt through one locked mutation. | ✓ VERIFIED | Executor maps typed outcomes to `DeliveryTargets.record_target_outcome/5`; key-link query passes. |
| 100-04 | 2 | Provider acceptance remains distinct from open/seen/read. | ✓ VERIFIED | `provider_accepted` is an outcome fact; safe-evidence/trace contracts retain distinct lifecycle vocabulary. |
| 100-04 | 3 | Only defined pre-provider/retryable outcomes carry retry authority. | ✓ VERIFIED | Adapter emits retryable tags only for allowlisted reasons; worker retry dispatch is typed. |
| 100-04 | 4 | Timeout/exit/loss is terminal ambiguous handoff, never automatic retry. | ✓ VERIFIED | `{:error, :ambiguous}` maps to `:possible_handoff`; executor/worker contracts cover it. |
| 100-04 | 5 | Only complete recognized 410 facts can invalidate; incomplete/unknown facts are permanent. | ✓ VERIFIED | Classifier guard requires 410, recognized reason, and non-negative timestamp; direct result matrix passes. |
| 100-04 | 6 | CAS and target completion use the original four-field scope. | ✓ VERIFIED | `invalidation_key/2` is built from target tenant/revision and persisted intent environment/topic; result test asserts the key for a supplied complete result. |
| 100-04 | 7 | Expired work remains single-terminal under retries. | ✓ VERIFIED | See 100-01 expiry gate and passing APNs contracts. |
| 100-04 | 8 | Completion races produce one terminal result and stable traces. | ✓ VERIFIED | Phase 99 deterministic regression evidence plus target lifecycle contracts. |
| 100-05 | 1 | Disabled packaged consumer is Pigeon/APNs-free and boots a core path. | ✓ VERIFIED | Fresh `bash scripts/verify-apns.sh` exited 0; disabled dependency tree/lock checks are in the script. |
| 100-05 | 2 | Enabled consumer pins Pigeon 2.0.1 and runs no-network accepted tracer. | ✓ VERIFIED | Same fresh package proof resolved/pinned Pigeon 2.0.1 and completed enabled tests without credentials/network. |
| 100-05 | 3 | `mix verify.apns` covers the declared APNs contracts. | ✓ VERIFIED | Script is the alias entrypoint; supplied current run reported `VERIFY_APNS_OK`. |
| 100-05 | 4 | Coverage table parser rejects unsupported disposition/blank opt-out reason. | ✓ VERIFIED | `api_coverage_test.exs` is included in the APNs verification command. |
| 100-05 | 5 | Local gate, CI job, release contract, and ci-gate are in parity. | ✓ VERIFIED | Workflow job runs `mix verify.apns`; adoption-path release-gate contract passed 1/1 in isolation. |
| 100-06 | 1 | Represented 410 response becomes a closed result only with complete status/reason/timestamp. | ✓ VERIFIED | `closed_result/1` injects `stream.status`; enabled package test proves raw correlated 410 → `Transport.Result`. |
| 100-06 | 2 | Represented 410 traverses real bridge → classifier → exact CAS. | ✗ FAILED | No single execution joins these paths; see Gaps Summary. |
| 100-06 | 3 | Real malformed/normalized/uncorrelated variants cannot invalidate. | ✗ FAILED | Fail-closed code exists, but real-Pigeon-to-CAS negative behavior has no executable test; see Gaps Summary. |
| 100-06 | 4 | Root remains Pigeon-free and disabled packaged consumer stays clean. | ✓ VERIFIED | Fresh disabled package proof passed and root `mix.exs` declares no Pigeon dependency. |
| 100-06 | 5 | Both PR and non-PR gates require the APNs lane. | ✓ VERIFIED | `pr-gate` and `ci-gate` both need `verify_apns`, export `VERIFY_APNS`, and call the aggregate; isolated contract passed. |

**Score:** 34/36 truths verified.

### Roadmap Success Criteria

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Optional host opt-in without dependencies/config for other hosts. | ✓ VERIFIED | Fresh disabled/enabled packaged-consumer proof. |
| 2 | Correct target request identity, routing, bounds, expiry, and open reference. | ✓ VERIFIED | Durable intent, exact lookup, closed payload, and request contracts. |
| 3 | Distinct operator lifecycle outcomes. | ✓ VERIFIED | Typed result algebra, outcome persistence, and safe evidence. |
| 4 | Expiry suppression and opt-in installation-safe collapse. | ✓ VERIFIED | Pre-transport expiry gate and scoped default-absent collapse derivation. |
| 5 | Provider invalidation is exact-target scoped. | ✗ FAILED | Code is narrow, but no real-Pigeon → classifier → exact-CAS execution proves the critical bridge. |

### Required Artifacts

| Artifact group | Status | Details |
| --- | --- | --- |
| Intent, payload, lookup, APNs adapter | ✓ VERIFIED | All substantive and wired; data flows from persisted target intent through exact transient lookup to closed request construction. |
| Durable schema/migrations and installer fixtures | ✓ VERIFIED | Nullable map only, matching public/prefixed copies, column-only down paths. |
| Outcome/executor/worker/safe-evidence spine | ✓ VERIFIED | Typed results connect to one locked target/attempt mutation and distinct evidence. |
| Optional Pigeon transport bridge | ⚠️ PARTIAL | Substantive and wired, and raw-result projection is tested; its classifier/CAS data-flow is not exercised end to end. |
| Package/CI/release-gate artifacts | ✓ VERIFIED | Script, alias, CI lane, both aggregate gates, and executable gate contract are wired. |

### Key Link Verification

| From | To | Status | Details |
| --- | --- | --- | --- |
| Delivery planning | Durable target intent | ✓ WIRED | `plan_targets/3` stores the normalized intent under the unique target conflict key. |
| APNS adapter | Intent → lookup → payload → transport | ✓ WIRED | Ordered calls in `APNS.deliver/2` enforce expiry before transient/provider I/O. |
| Pigeon stream | Closed transport result | ✓ WIRED | `PigeonAdapter.process_end_stream/2` correlates stream ID, bounds/decodes body, and calls `Pigeon.Tasks.process_on_response/1`. |
| Closed result | APNS classifier → exact host CAS | ⚠️ WIRED, NOT EXECUTABLY PROVEN | `pigeon_push/2` accepts `%Result{}` and `classify_result/3` builds the exact key, but no test spans both. |
| CI workflow | `mix verify.apns` / PR and CI aggregates | ✓ WIRED | `verify_apns` is a dependency and aggregate input of both gates. |

### Data-Flow Trace

| Artifact | Data | Source | Status |
| --- | --- | --- | --- |
| Target planning | `apns_request_intent` | Normalized host binding → `DeliveryTarget` map | ✓ FLOWING |
| Request dispatch | intent, exact transient, closed payload | Persisted target → host lookup → `Transport.Request` | ✓ FLOWING |
| 410 invalidation | stream status/body → `Result` → classifier → CAS | Bridge and classifier are individually tested; composition is untested | ✗ GAP |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Fresh disabled/enabled package optionality and raw Pigeon bridge | `bash scripts/verify-apns.sh` | Exit 0; disabled host rejected Pigeon dependency/lock, enabled fixture resolved Pigeon 2.0.1; synthetic safe evidence emitted | ✓ PASS |
| Focused APNS result and adapter outcomes | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns/result_test.exs test/chimeway/adapters/apns_test.exs --warnings-as-errors` | 6 tests, 0 failures | ✓ PASS |
| Adoption-path release-gate APNs parity | Supplied current isolated release-gate contract evidence | 1/1 passed | ✓ PASS |
| Phase 97–99 deterministic regression | Supplied current deterministic gate evidence | 738/738 passed with seed 0 | ✓ PASS |
| Real Pigeon 410 through APNS classifier to exact CAS | No existing named test | Bridge and classifier execute only in separate tests | ✗ FAIL |

### Probe Execution

Step 7c: SKIPPED — no Phase 100 `scripts/*/tests/probe-*.sh` declaration or conventional probe exists. `scripts/verify-apns.sh` is the phase’s executable package gate and was run above.

### Requirements Coverage

| Requirement | Source Plans | Status | Evidence |
| --- | --- | --- | --- |
| APNS-01 | 100-03, 100-05, 100-06 | ✓ SATISFIED | Pigeon-free root/disabled consumer and explicit enabled Pigeon 2.0.1 fixture pass. |
| APNS-02 | 100-01, 100-02, 100-03, 100-05 | ✓ SATISFIED | Durable safe intent, exact lookup, closed payload, bounds, migrations, and package contracts. |
| APNS-03 | 100-04, 100-05, 100-06 | ✗ BLOCKED | Exact CAS code and separate seam tests exist, but the critical represented-Pigeon response-to-CAS behavior lacks an executable end-to-end test. |
| APNS-04 | 100-01 through 100-05 | ✓ SATISFIED | Absolute expiry is stored, checked before lookup/I/O, and included in APNs contract coverage. |
| APNS-05 | 100-01, 100-03, 100-05 | ✓ SATISFIED | Opaque, bounded, exact-scope collapse is opt-in/default-absent. |
| APNS-06 | 100-04, 100-05 | ✓ SATISFIED | Typed target outcomes and safe evidence distinguish handoff, retry/exhaustion, invalidation, and independent inbox/open facts. |

All six requirement IDs declared across the six phase plans are accounted for. No orphaned Phase 100 IDs were found in `REQUIREMENTS.md`.

### Review-Fix Verification

| Review fix | Actual code/test evidence | Verdict |
| --- | --- | --- |
| CR-01: preserve 410 stream status | `closed_result/1` now merges `stream.status` before `extract_response/1`; enabled package test exercises represented 410 to `Transport.Result`. | ⚠️ PARTIAL — bridge-to-CAS composition untested. |
| CR-02: preserve retryable APNs responses | Allowlisted 403/429/500/503 reasons create typed closed results; package bridge tests and focused adapter-result test pass. | ✓ VERIFIED |
| CR-03: missing dispatcher is pre-handoff retryable | `:not_started` maps to `:pigeon_unavailable`; real optional transport and adapter-result tests cover both sides. | ✓ VERIFIED |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- |
| `test/fixtures/apns_consumer/test/apns_consumer_test.exs` | 140-174 | Valid raw Pigeon 410 test terminates at `Transport.Result` | 🛑 Blocker | Does not prove the advertised provider result reaches the exact invalidation CAS. |
| `test/chimeway/apns/result_test.exs` | 55-123 | CAS test injects fake transport result | 🛑 Blocker | Can pass even if the Pigeon bridge stops/changes before the APNS classifier. |

No unreferenced `TBD`, `FIXME`, or `XXX` markers were found in Phase 100 implementation artifacts. The verifier’s generic artifact/link queries reported false negatives only for conceptual/non-file `from` fields and the directory artifact; manual source inspection established their wiring above.

### Gaps Summary

This remains an APNS-03 blocker. The review fixes corrected the actual production code paths, and the component tests demonstrate each half independently. But the phase’s essential guarantee is a behavioral chain: a represented Pigeon 410 response must enter the bridge, be classified by `APNS.deliver/2`, and invoke the exact four-field host CAS. The existing test layout can still pass if the transport-to-adapter handoff is broken. That is a machine-testable missing contract, so no conversational UAT is requested.

No later roadmap phase explicitly covers Phase 100’s Pigeon response bridge or its APNS-03 executable contract; this gap is not deferred.

---

_Verified: 2026-08-21T16:08:00Z_
_Verifier: the agent (gsd-verifier)_

---
phase: 100-optional-apns-adapter
verified: 2026-08-20T21:26:16Z
status: gaps_found
score: 11/12 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "A provider invalidation affects only its exact tenant, environment, and binding revision, never a rotated replacement or another installation."
    status: failed
    reason: "The real optional Pigeon transport discards every non-success response as :rejected, so it cannot construct the complete HTTP 410/reason/timestamp result required to invoke exact-binding invalidation."
    artifacts:
      - path: "lib/chimeway/apns/transport.ex"
        issue: "classify_pigeon_response/1 has only success, timeout, generic-response, and fallback clauses; the generic clause returns {:error, :rejected} without status, reason, or timestamp."
      - path: "test/chimeway/apns/result_test.exs"
        issue: "Tests inject a fake Transport.Result triple directly and never exercise the Pigeon-backed production bridge."
    missing:
      - "Extract Pigeon 2.0.1's actual APNs error response into Transport.Result{outcome: :rejected, status: 410, reason: ..., timestamp: ...} only when all three facts are present."
      - "Add an enabled-consumer or isolated Pigeon-bridge test proving a real represented 410 ExpiredToken/Unregistered response reaches APNS.classify_result/3 and performs the exact host CAS."
---

# Phase 100: Optional APNs Adapter Verification Report

**Phase Goal:** An APNs-enabled host can dispatch safe, bounded push requests and receive honest target-specific provider outcomes without adding push dependencies to other hosts.
**Verified:** 2026-08-20T21:26:16Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A non-push host runs without Pigeon/APNs configuration, while an opting-in host can use the optional Pigeon seam. | ✓ VERIFIED | `mix verify.apns` passed: its packaged disabled consumer rejects Pigeon in dependency tree/lock and boots; the enabled fixture resolves Pigeon 2.0.1. Root `mix.exs` has no Pigeon dependency. |
| 2 | Every request uses the selected target's topic/environment, stable `apns-id`, bounded allowlisted payload, host expiry, and opaque open ref. | ✓ VERIFIED | `RequestIntent`, `Payload`, `BindingLookup`, and `APNS.deliver/2` form the persisted-intent → exact lookup → closed request path; the 28-test automated APNs gate passed. |
| 3 | Planning retains one safe immutable APNs intent per normalized binding and non-APNs targets remain valid. | ✓ VERIFIED | `DeliveryTargets.plan_targets/3` stores `RequestIntent.to_storage/1` on conflict-safe target creation; `TargetResolver.normalize/2` explicitly accepts `request_intent: nil`. Tracer/migration contracts pass under `mix verify.apns`. |
| 4 | Expiry/oversize/invalid lookup stop before transport, including retry/concurrency protection. | ✓ VERIFIED | Adapter checks expiry before `BindingLookup.resolve/1`; `Payload.build/2` measures encoded bytes against 4096; focused tracer/result contracts are included in the passing APNs gate. |
| 5 | Collapse is opt-in, opaque, bounded, and exact-target scoped; distinct notifications omit it. | ✓ VERIFIED | `RequestIntent.collapse_id/4` derives SHA-256 from length-delimited occurrence, binding revision, environment, and topic; default is `nil`; request tests are in the passing gate. |
| 6 | Target outcomes are durably classified as accepted, retryable, permanent, expired, ambiguous, or invalidated without equating acceptance to engagement. | ✓ VERIFIED | `TargetAdapter.deliver_result`, `Executor.target_adapter_result/2`, `DeliveryTargets.record_target_outcome/5`, and `SafeEvidence` retain distinct terminal vocabulary. Result/evidence/traces tests passed in `mix verify.apns`. |
| 7 | Retry authority is limited to pre-provider/retryable results; timeouts/exits/lost responses are ambiguous, terminal handoffs. | ✓ VERIFIED | `APNS.deliver/2` maps ambiguous transport failures to `:possible_handoff`; executor persists `:ambiguous_handoff`; `ObanWorker` behavior is covered by APNs result/worker contracts in the gate. |
| 8 | A provider invalidation affects only its exact tenant, environment, and binding revision, never a rotated replacement or another installation. | ✗ FAILED | `BindingLookup.invalidate/1` and adapter CAS key are exact when supplied a complete result, but the actual Pigeon transport cannot supply that result. See blocker evidence below. |
| 9 | Supported repository/public/prefixed installation paths add only nullable safe intent storage and roll back only that column. | ✓ VERIFIED | Canonical migration 037, repository migration, and both golden migrations use `add/remove :apns_request_intent, :map`; migration contracts are included in the passing gate. |
| 10 | Operators can distinguish APNs handoff/rejection/retry exhaustion/invalidation from protected-open and inbox lifecycle facts. | ✓ VERIFIED | Target statuses/outcomes and `SafeEvidence` maintain `provider_accepted`, `invalidated`, `expired`, `retry_exhausted`, and `ambiguous_handoff` separately; trace tests passed. |
| 11 | The APNs verification entrypoint, CI job, and non-PR `ci-gate` aggregation are wired. | ✓ VERIFIED | `mix verify.apns` invokes `scripts/verify-apns.sh`; `.github/workflows/ci.yml` defines `verify_apns`; `ci-gate` needs and exports `VERIFY_APNS` to `aggregate-gate.sh`. |
| 12 | No raw token, credential, provider body, or arbitrary payload becomes a durable/diagnostic APNs fact. | ✓ VERIFIED | Stored intent/migrations contain only safe fields; `Payload` has a closed two-key JSON shape; fake transport redacts token; API, tracer, and safe-evidence checks passed. |

**Score:** 11/12 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/chimeway/apns/request_intent.ex` | Safe durable intent and collapse/expiry validation | ✓ VERIFIED | 110 substantive lines; exported construction, storage conversion, and expiry functions are used by planner/adapter. |
| `lib/chimeway/apns/payload.ex` | Closed final-byte-bounded payload | ✓ VERIFIED | Constructs only APS alert and `chimeway_open_ref`; adapter consumes it before transport. |
| `lib/chimeway/apns/binding_lookup.ex` | Exact transient lookup/invalidation boundary | ✓ VERIFIED | Explicit request/transient/key structs enforce equality of all four scope facts. |
| `lib/chimeway/apns/transport.ex` | Optional dynamic Pigeon transport | ⚠️ HOLLOW FOR INVALIDATION | Optional dependency wiring is substantive and invoked, but its non-success Pigeon response projection lacks required invalidation facts. |
| `lib/chimeway/adapters/apns.ex` | Production target adapter | ✓ VERIFIED except Truth 8 | Reloads stored intent, gates expiry, calls lookup/payload/transport, and maps typed results to outcome algebra. |
| `lib/chimeway/{delivery_target,delivery_targets,delivery_planning}.ex` | Durable nullable variant and planning path | ✓ VERIFIED | `apns_request_intent` schema field flows from normalized binding to persisted target. |
| `priv/repo/migrations/20260820000001_add_apns_request_intent.exs` | Repository migration | ✓ VERIFIED | Additive nullable map and column-only rollback. |
| `priv/chimeway_migrations/037_add_apns_request_intent.exs` and both fixture copies | Generated installer migration parity | ✓ VERIFIED | Equivalent prefix-aware/public/prefixed migration bodies; passed installer contracts. |
| `test/chimeway/apns/{tracer,request,result,api_coverage}_test.exs` | Executable APNs contracts | ⚠️ PARTIAL | Gate passes, but result test gives the adapter a synthetic triple instead of exercising Pigeon response conversion. |
| `scripts/verify-apns.sh`, fixture consumer, `mix.exs`, CI workflow | Package and CI proof | ✓ VERIFIED | Local gate executed successfully; required job and non-PR aggregate wiring are present. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `delivery_planning.ex` | `delivery_targets.ex` | resolver bindings → `plan_targets/3` | ✓ WIRED | Resolver returns normalized bindings; planning passes them to durable target creation, which stores intent. |
| `adapters/apns.ex` | intent/lookup/payload/transport | reload → expiry gate → exact transient resolution → bounded request | ✓ WIRED | Direct calls are present in `APNS.deliver/2`; data reaches transport only after all gates. |
| `transport.ex` | optional Pigeon 2.0.1 | dynamic module loading and `apply(:push, ...)` | ⚠️ PARTIAL | Dynamic call is correctly isolated to optional transport, but response conversion breaks the real invalidation link. |
| executor/worker | `DeliveryTargets.record_target_outcome/5` | typed outcome → one locked mutation | ✓ WIRED | Executor maps adapter tags and calls locked completion; result/worker tests pass. |
| workflow `verify_apns` | `mix verify.apns` / `ci-gate` | CI lane and aggregate env | ✓ WIRED | `verify_apns` job runs the command; non-PR `ci-gate` includes its result and `VERIFY_APNS`. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Target planning | `BindingRevision.request_intent` | host target resolver → normalized binding | Persisted as `DeliveryTarget.apns_request_intent` | ✓ FLOWING |
| APNs adapter | `intent`, `transient`, `payload` | reloaded target map; host `BindingLookup`; closed render input | All pass to `Transport.Request`; raw token is transient | ✓ FLOWING |
| Provider outcome | `Transport.Result` | fake transport in tests / `pigeon_push/2` in production | Fake produces complete 410 triples; real Pigeon bridge discards them | ✗ DISCONNECTED for invalidation |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Hermetic package optionality, APNs request/outcome/migration/evidence contracts | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix verify.apns` | 28 tests, 0 failures; packaged disabled/enabled consumer proof completed | ✓ PASS |
| Pigeon-backed 410 invalidation reaches exact CAS | Source/data-flow inspection of `Transport.pigeon_push/2` and `classify_pigeon_response/1` | Generic `%{response: _}` branch returns `{:error, :rejected}`; no `Transport.Result` with 410 facts is possible | ✗ FAIL |

### Probe Execution

Step 7c: SKIPPED — no Phase 100 `scripts/*/tests/probe-*.sh` declarations or conventional probes were found.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| APNS-01 | 100-03, 100-05 | Optional Pigeon host opt-in with clean non-push consumer | ✓ SATISFIED | Passing packaged consumer disabled/enabled proof; Pigeon absent from root dependency graph. |
| APNS-02 | 100-01, 100-02, 100-03, 100-05 | Safe exact target request, custody, bounds, and open ref | ✓ SATISFIED | Durable intent, closed payload, exact lookup, migrations, and passing gate. |
| APNS-03 | 100-04, 100-05 | Reason-aware outcomes and exact-binding invalidation | ✗ BLOCKED | Real Pigeon `Unregistered`/`ExpiredToken` is flattened to generic rejection before exact invalidation classifier. |
| APNS-04 | 100-01 through 100-05 | Absolute expiry before send/retry and explicit suppression | ✓ SATISFIED | Intent expiry gate and result/worker/tracer contracts pass. |
| APNS-05 | 100-01, 100-03, 100-05 | Explicit opaque installation-safe collapse | ✓ SATISFIED | Scoped derivation/default omission/boundary contracts pass. |
| APNS-06 | 100-04, 100-05 | Distinct operator lifecycle vocabulary | ✓ SATISFIED | Typed outcomes, exact completion, safe evidence, and trace contracts pass. |

All six requirement IDs declared across the five plan frontmatters are accounted for. No orphaned Phase 100 requirement IDs were found in `REQUIREMENTS.md`.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `lib/chimeway/apns/transport.ex` | 83 | Generic Pigeon response is reduced to `{:error, :rejected}` | 🛑 Blocker | Removes facts needed for APNS-03 exact invalidation. |
| `.github/workflows/ci.yml` | 302 | `pr-gate` omits `verify_apns` | ⚠️ Warning | The APNs job still runs on PRs and `ci-gate` aggregation is correct for non-PR events, so the plan's literal CI/`ci-gate` link passes; however, a branch protected only by `pr-gate` can merge without requiring this lane. |

No unreferenced `TBD`, `FIXME`, or `XXX` markers were found in Phase 100 implementation artifacts.

## Gaps Summary

The phase has a genuine APNS-03 blocker, not merely an untested edge case. The exact invalidation logic downstream of `APNS.classify_result/3` is correctly narrow, but it is unreachable from the advertised real Pigeon transport: all non-success Pigeon responses become generic `:rejected`. Tests demonstrate only a fake transport that manually fabricates the complete invalidation triple and therefore cannot prove production-provider behavior.

The advisory `pr-gate` finding is valid as a CI enforcement improvement, but it does not falsify the phase's explicit `verify_apns` + non-PR `ci-gate` parity criterion. It should be addressed with the gap closure if PR aggregation is intended to be the required merge gate.

No later roadmap phase explicitly covers APNs provider-response extraction or Phase 100 CI aggregation, so this blocker is not deferred.

---

_Verified: 2026-08-20T21:26:16Z_
_Verifier: the agent (gsd-verifier)_

---
phase: 100-optional-apns-adapter
verified: 2026-08-22T00:43:30Z
status: gaps_found
score: 42/44 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 35/37
  gaps_closed:
    - "A correlated ordinary HTTP 200 stream now reaches Pigeon's normal completion path and produces provider_accepted."
    - "The enabled consumer now has a committed Pigeon 2.0.1 / HTTPoison 3.0.0 / Hackney 4.7.4 lock and runs mix hex.audit."
  gaps_remaining: []
  regressions:
    - "A host lookup or payload exception before Transport.push/2 is recorded as ambiguous_handoff, falsely asserting possible provider emission."
    - "The enabled package build emits Chimeway warnings, but the APNs script's warnings-as-errors command does not observe that dependency compilation."
gaps:
  - truth: "Only a timeout, exit, connection loss, or missing post-emission response becomes ambiguous_handoff; pre-provider failures retain pre-handoff retry or terminal truth."
    status: failed
    reason: "APNS.deliver/2 rescues and catches the complete lookup/payload/transport sequence. A BindingLookup.resolve/1 exception before any provider request returns {:error, :possible_handoff, :ambiguous_handoff}."
    artifacts:
      - path: "lib/chimeway/adapters/apns.ex"
        issue: "Lines 9-30 cover pre-I/O work with the provider-ambiguity rescue."
    missing:
      - "Limit the ambiguity guard to Transport.push/2 and map pre-I/O callback exceptions to an honest retryable or terminal pre-handoff result."
      - "Add a regression test that raises from lookup and proves no transport call plus pre-handoff durable evidence."
  - truth: "A clean enabled packaged consumer compiles with warnings-as-errors as part of the optional APNs proof."
    status: failed
    reason: "The enabled proof exits successfully but emits unreachable duplicate callback warnings and undefined Pigeon.json_library/0 warnings from Chimeway.APNS.Transport.PigeonAdapter. The dependency is compiled during mix deps.get, before the later mix compile --warnings-as-errors command, so the claimed gate does not fail closed."
    artifacts:
      - path: "lib/chimeway/apns/transport.ex"
        issue: "Lines 115-175 and 266-379 define overlapping callback clauses; lines 332 and 353 call an undefined Pigeon.json_library/0."
      - path: "scripts/verify-apns.sh"
        issue: "Lines 43-54 compile the package as a dependency before the later warnings-as-errors command, allowing its warnings to escape the gate."
    missing:
      - "Remove or isolate the unreachable duplicate Pigeon callback implementation and use the runtime-resolved JSON module."
      - "Make the enabled-consumer proof fail when Chimeway compilation emits warnings."
---

# Phase 100: Optional APNs Adapter Verification Report

**Phase Goal:** An APNs-enabled host can dispatch safe, bounded push requests and receive honest target-specific provider outcomes without adding push dependencies to other hosts.
**Verified:** 2026-08-22T00:43:30Z
**Status:** gaps_found
**Re-verification:** Yes — after Plan 100-08 gap closure

## Goal Achievement

### Roadmap Success Criteria

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Non-push hosts run without Pigeon/APNs config; opt-in uses Pigeon through host lookup. | ✓ VERIFIED | Disabled/enabled consumer isolation is encoded in `scripts/verify-apns.sh`; the enabled focused package tracer ran with Pigeon supplied only by the fixture. |
| 2 | Requests have exact routing, stable ID, bounded allowlisted payload, expiry, and opaque open reference. | ✓ VERIFIED | `RequestIntent`, `Payload`, `BindingLookup`, migration contract, and 30 root APNs tests exercised by `mix verify.apns` passed. |
| 3 | Provider outcomes remain honest and target-specific. | ✗ FAILED | A local lookup crash before provider I/O is persisted as possible provider handoff; this is not an honest provider outcome. |
| 4 | Expiry suppresses sends/retries and collapse is opt-in, exact-target scoped, and default absent. | ✓ VERIFIED | Request and tracer contracts cover expiry and 4096/4097-byte/collapse boundaries. |
| 5 | Invalidation affects only the exact tenant/environment/topic/revision. | ✓ VERIFIED | The packaged 410/CAS fixture and `result_test.exs` use the original four-field invalidation key and reject malformed/non-authoritative inputs. |

### Plan Must-Haves

All 44 PLAN frontmatter truths were checked. The 42 non-failed items are implemented, wired, and covered by the root APNs contract suite and/or the package consumer tracer. The following groups are specifically evidenced by code and tests: durable immutable intent and target concurrency (100-01); public/prefixed migration parity (100-02); optional dynamic Pigeon boundary, exact lookup, payload, expiry, and collapse (100-03); exact result classification/CAS and safe trace facts (100-04); package/CI/API-coverage wiring (100-05); complete 410 response authority (100-06/07); and ordinary 200 plus locked enabled graph/audit (100-08).

| Plan | Truth count | Result | Evidence |
| --- | ---: | --- | --- |
| 100-01 | 8 | ✓ 8/8 | `tracer_test.exs`, request contracts, persisted intent/target path, and root APNs suite. |
| 100-02 | 4 | ✓ 4/4 | Canonical and golden migration 037 files, migration/prefix contracts. |
| 100-03 | 6 | ✓ 6/6 | Optional dynamic transport, exact lookup, closed payload, and request/result tests. |
| 100-04 | 8 | ✗ 7/8 | D-12/D-13 lifecycle boundary fails for a raised pre-provider lookup; all other outcome/CAS/evidence paths pass. |
| 100-05 | 5 | ✗ 4/5 | Consumer isolation, API coverage, alias and CI wiring exist; the asserted warnings-as-errors compilation proof is not fail-closed. |
| 100-06 | 5 | ✓ 5/5 | Represented 410 bridge and non-authority matrix are wired and covered. |
| 100-07 | 3 | ✓ 3/3 | Public `APNS.deliver/2` bridge-to-CAS fixture is present and preserved. |
| 100-08 | 5 | ✓ 5/5 | Runtime HTTP 200 tracer passed; lock/version/audit commands and CI link exist. The build-warning defect is counted against the original clean-consumer compile claim above, not as a duplicate truth. |

**Score:** 42/44 must-haves verified (0 present-but-behavior-unverified).

### Required Artifacts

| Artifact group | Status | Details |
| --- | --- | --- |
| Request intent, payload, lookup, adapter, target lifecycle, evidence | ✓ VERIFIED | All declared source artifacts exist, are substantive, and are called from planning/executor/adapter paths. |
| Repository/template/golden migrations | ✓ VERIFIED | All four copies use nullable `apns_request_intent`; migration tests are included in the APNs alias. |
| Pigeon-neutral transport and package consumer tracer | ⚠️ WIRED WITH GAP | The real ordinary-200 and 410 paths run, but duplicate enabled-only callbacks are unreachable and compile warnings escape the gate. |
| Locked enabled dependency graph and verifier script | ✓ VERIFIED | `apns-enabled.lock`, exact dependency assertions, `deps.get --check-locked`, and `mix hex.audit` are present and run in enabled mode. |

### Key Link Verification

| Link | Status | Evidence |
| --- | --- | --- |
| Planning → persisted exact-target intent → adapter reload | ✓ WIRED | `DeliveryPlanning`/`DeliveryTargets.plan_targets` persist the request intent; `APNS.deliver/2` uses `RequestIntent.from_storage/1`. |
| Adapter → exact host lookup → closed payload → optional transport | ✓ WIRED | Adapter calls `BindingLookup.resolve`, `Payload.build`, then `Transport.push`; the focused runtime package tracer returns `provider_accepted`. |
| Raw correlated 410 → closed result → classifier → exact host CAS | ✓ WIRED | `PigeonAdapter.process_end_stream/2`, `classify_result/3`, and the public fixture prove the original four-field key. |
| Raw correlated HTTP 200 → Pigeon normal handler → accepted result | ✓ WIRED | `runtime_closed_result/1` returns `:normalized` for 200/201 and calls `Pigeon.Configurable.handle_end_stream/3`; `CHIMEWAY_APNS_FOCUS=runtime_success` exited 0. |
| Local alias → package proof → verify_apns → PR and CI aggregates | ✓ WIRED | `mix.exs`, `scripts/verify-apns.sh`, CI `verify_apns`, `pr-gate`, and `ci-gate` link the same lane. |

### Data-Flow Trace (Level 4)

| Artifact | Data | Source to sink | Status |
| --- | --- | --- | --- |
| APNs request | persisted safe intent | target row → exact lookup → closed payload/headers → transport | ✓ FLOWING |
| Ordinary provider success | correlated HTTP 200 | Pigeon stream → original notification callback → `Transport.Result.accepted` → `provider_accepted` | ✓ FLOWING |
| Invalidation | bounded 410 tuple | stream/body → closed rejected result → exact key → host CAS | ✓ FLOWING |
| Pre-provider failure | lookup exception | lookup → broad adapter rescue → ambiguous target result | ✗ MISCLASSIFIED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Root APNs request/result/adapter contracts | `mix verify.apns` root test command | 30 tests, 0 failures before package-consumer stage. | ✓ PASS |
| Public ordinary HTTP 200 | `CHIMEWAY_APNS_FOCUS=runtime_success bash scripts/verify-apns.sh` | Exit 0; returned the bounded synthetic `provider_accepted` proof. | ✓ PASS |
| Pre-I/O lookup exception | isolated `MIX_ENV=test mix run -e ... APNS.deliver(...)` | Returned `{:error, :possible_handoff, :ambiguous_handoff}` before any transport exists. | ✗ FAIL |
| Exact invalidation/retry classification | `mix test test/chimeway/apns/result_test.exs test/chimeway/adapters/apns_test.exs --warnings-as-errors` | 6 tests, 0 failures. | ✓ PASS, but lacks raised-lookup regression |
| Enabled compilation quality | focused package proof above | Exit 0 but emitted Chimeway duplicate/unreachable and undefined `Pigeon.json_library/0` warnings. | ✗ FAIL |

The later `release_gate_contract_test.exs` rerun could not acquire PostgreSQL connections (`FATAL 53300 too_many_connections`); this is environmental contention after the already-recorded functional checks, not evidence that either implementation gap is fixed or deferred.

### Requirements Coverage

| Requirement | Source plans | Status | Evidence |
| --- | --- | --- | --- |
| APNS-01 | 100-03, 05, 06, 08 | ✗ BLOCKED | Optionality and locked graph are implemented, but the consumer's claimed warning-fail-closed compile gate is false. |
| APNS-02 | 100-01, 02, 03, 05, 08 | ✓ SATISFIED | Safe durable intent, exact lookup, closed payload, and package tracer exist. |
| APNS-03 | 100-04, 05, 06, 07, 08 | ✗ BLOCKED | A pre-provider lookup exception produces false ambiguous-handoff evidence; 200 and 410 provider paths otherwise pass. |
| APNS-04 | 100-01 through 05, 08 | ✓ SATISFIED | Absolute expiry gate and durable suppression contract are present and tested. |
| APNS-05 | 100-01, 03, 05, 08 | ✓ SATISFIED | Collapse remains host-declared, bounded, opaque, and exact-target scoped. |
| APNS-06 | 100-04, 05, 08 | ✗ BLOCKED | False possible-handoff state prevents fully honest operator outcome vocabulary. |

All six requirement IDs declared by Phase 100 plans are accounted for; `REQUIREMENTS.md` maps no additional Phase 100 requirement IDs.

### Prohibitions and Anti-Patterns

The 12 plan prohibitions were checked against closed payload/evidence, exact CAS, expiry/collapse, and consumer fixtures. No raw-token/credential/provider-body persistence, cross-binding invalidation, stale send, collapse coalescing, or acceptance-as-engagement path was found. They are objectively testable and require no human UAT.

| File | Lines | Finding | Severity |
| --- | --- | --- | --- |
| `lib/chimeway/adapters/apns.ex` | 9-30 | Broad rescue turns pre-I/O callback exceptions into provider ambiguity. | 🛑 BLOCKER |
| `lib/chimeway/apns/transport.ex` | 115-175, 266-379 | Duplicate/unreachable Pigeon callbacks and undefined API calls emit warnings in enabled consumer compilation. | 🛑 BLOCKER |

No unreferenced `TBD`, `FIXME`, or `XXX` markers were found in the Phase 100 implementation artifacts.

### Deferred Items

None. Phase 101 owns registration and protected-open authority, not truthful classification of Phase 100's pre-provider adapter failures or its enabled-package compiler gate.

### Gaps Summary

Plan 100-08 closed the previous ordinary-200 and advisory-graph gaps: the real package tracer now succeeds for a correlated 200, and the enabled graph is locked/audited. The current review's two findings are genuine. The broad `APNS.deliver/2` rescue creates a durable provider-handoff claim even when the provider was never reached, directly breaking the phase's honesty contract. Separately, the package verification lane claims warnings-as-errors while allowing its own optional-path warnings to pass; this breaks a stated must-have and leaves dead, divergent provider code in the shipped adapter.

This is an escalation gate. Both gaps are machine-testable; no conversational UAT is appropriate.

---

_Verified: 2026-08-22T00:43:30Z_
_Verifier: the agent (gsd-verifier)_

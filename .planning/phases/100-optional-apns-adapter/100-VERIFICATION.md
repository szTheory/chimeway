---
phase: 100-optional-apns-adapter
verified: 2026-08-21T18:27:48Z
status: gaps_found
score: 35/37 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 34/36
  gaps_closed:
    - "A represented 410 ExpiredToken or Unregistered response traverses the real Pigeon bridge, APNS.classify_result/3, and the exact host CAS in one executable path."
    - "Normalized, incomplete, malformed, wrong status/reason, oversized, and uncorrelated Pigeon variants cannot invalidate a binding through APNS.deliver/2."
  gaps_remaining: []
  regressions:
    - "The Pigeon-neutral runtime bridge still classifies a correlated ordinary HTTP 200 APNs response as a rejection."
gaps:
  - truth: "A normal represented APNs success produces the distinct provider_accepted handoff outcome through the runtime Pigeon-neutral adapter."
    status: failed
    reason: "The always-compiled Pigeon-neutral process_end_stream/2 sends every correlated stream through runtime_closed_result/1. Its catch-all wraps HTTP 200 as Result{outcome: :rejected, code: :unrecognized_provider_response}; it never delegates ordinary streams to Pigeon's normal handler. The only implementation with that fallback is inside if Code.ensure_loaded?(Pigeon.Adapter), which is unavailable when Chimeway is compiled without Pigeon, the package's optional-dependency mode."
    artifacts:
      - path: "lib/chimeway/apns/transport.ex"
        issue: "Lines 153-168 and 222-230 turn an unrecognized/200 stream into a rejected closed result; no enabled-consumer test covers a 200 end stream."
    missing:
      - "For unrecognized/success streams, delegate to Pigeon's normal Configurable.handle_end_stream/3 path rather than process a rejected Chimeway result."
      - "Add a no-network packaged-consumer test that injects a correlated 200 end stream through APNS.deliver/2 and asserts provider_accepted."
  - truth: "The documented Pigeon 2.0.1 opt-in path has an acceptable supported dependency-security posture."
    status: failed
    reason: "The supported fixture hard-pins pigeon == 2.0.1. Both verifier executions resolved advisory-bearing Hackney: the focused run selected 1.17.1 with GHSA-vq52-99r9-h5pw plus 2026 advisories, and the full APNs gate selected 1.25.0 with EEF-CVE-2026-47069/47071/47075/47076, including HIGH EEF-CVE-2026-47071. The script prints these advisories but exits 0, so current CI evidence does not enforce the security condition."
    artifacts:
      - path: "test/fixtures/apns_consumer/mix.exs"
        issue: "The supported adopter fixture pins Pigeon 2.0.1 and has no locked/verified patched HTTP-client graph."
      - path: "scripts/verify-apns.sh"
        issue: "It verifies the Pigeon version but treats Hex security-advisory output as a successful proof."
    missing:
      - "Upgrade or replace the supported Pigeon integration so its resolved HTTP dependency graph is patched, then lock and assert that graph."
      - "Fail the APNs adoption gate for unresolved advisory-bearing supported dependencies, or obtain an explicit, documented risk acceptance outside this verification report."
---

# Phase 100: Optional APNs Adapter Verification Report

**Phase Goal:** An APNs-enabled host can dispatch safe, bounded push requests and receive honest target-specific provider outcomes without adding push dependencies to other hosts.
**Verified:** 2026-08-21T18:27:48Z
**Status:** gaps_found
**Re-verification:** Yes — after Plan 100-07 gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Non-push hosts stay Pigeon/APNs-free; opted-in hosts use host-controlled lookup. | ✓ VERIFIED | `scripts/verify-apns.sh` fresh disabled/enabled package proof passed; disabled tree/lock reject Pigeon. |
| 2 | Requests retain exact topic/environment, stable ID, bounded allowlisted payload, expiry, and opaque open reference. | ✓ VERIFIED | `RequestIntent`, `Payload`, `BindingLookup`, adapter request tests, and `mix verify.apns` (30 root tests) pass. |
| 3 | Accepted handoff, retryable, permanent, exhaustion, invalidation, and inbox/open facts remain distinct. | ✗ FAILED | The required normal accepted-handoff runtime path is wrong for a correlated Pigeon HTTP 200 stream; see Gap 1. Other typed outcome/evidence paths are wired and tested. |
| 4 | Expiry suppresses initial/retry work and collapse is host opt-in, scoped, and default-absent. | ✓ VERIFIED | APNs request/result and lifecycle tests run in `mix verify.apns`; request construction gates expiry before lookup/transport. |
| 5 | A represented recognized 410 invalidates only the original tenant/environment/topic/revision; non-authoritative variants do not. | ✓ VERIFIED | Focused packaged tracer calls public `APNS.deliver/2`, real Pigeon dispatcher/end stream, and host CAS; three tagged tests passed. |
| 6 | The supported opt-in dependency graph is safe to ship. | ✗ FAILED | The required `pigeon == 2.0.1` fixture resolves known advisory-bearing Hackney releases; see Gap 2. |

**Score:** 35/37 truths verified. The former two APNS-03 bridge/CAS truths are now executable and verified; the two failed truths above are release blockers.

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/chimeway/apns/transport.ex` | Optional runtime Pigeon bridge | ✗ SUBSTANTIVE, BUT INCORRECT | The real 410 bridge is wired; its Pigeon-neutral catch-all rejects normal 200 streams. |
| `lib/chimeway/adapters/apns.ex` | Intent → lookup → payload → transport → outcome/CAS | ✓ VERIFIED | Public `deliver/2` consumes the returned `Transport.Result`; exact invalidation key uses target tenant/revision and persisted intent topic/environment. |
| `test/fixtures/apns_consumer/lib/apns_consumer.ex` | Host-owned exact lookup and conditional CAS fixture | ✓ VERIFIED | Registry distinguishes original/replacement revision and only mutates the original four-field key. |
| `test/fixtures/apns_consumer/test/apns_consumer_test.exs` | Real bridge-to-CAS and fail-closed matrix | ✓ VERIFIED | Tagged tests enter through `APNS.deliver/2`, inject raw `%Pigeon.Http2.Stream{}`, and do not inject a `Transport.Result`. Missing normal-200 coverage is a blocker. |
| `scripts/verify-apns.sh` | Fresh disabled/enabled package proof | ⚠️ PARTIAL | Wiring and focused/full modes work, but advisories printed during dependency resolution do not fail the gate. |
| `test/fixtures/apns_consumer/mix.exs` | Explicit host-only Pigeon dependency | ⚠️ PARTIAL | Keeps the root clean but pins the advisory-bearing supported Pigeon 2.0.1 graph. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Consumer tracer | `Chimeway.Adapters.APNS.deliver/2` | `APNSConsumer.deliver/1` | ✓ WIRED | The public adapter is the only tracer entry; no private classifier/result injection. |
| Runtime Pigeon stream | `Transport.Result` | Correlated queue pop / `Pigeon.Tasks.process_on_response/1` | ✓ WIRED for 410; ✗ FAILED for 200 | Correlated 410 reaches closed result/CAS. Catch-all returns `:unrecognized_provider_response` for 200. |
| `APNS.deliver/2` | Host exact CAS | `BindingLookup.invalidate/1` | ✓ WIRED | Focused tracer proves both accepted invalidation reasons and original four-field key. |
| `mix verify.apns` | packaged consumer proof / hosted gates | `scripts/verify-apns.sh`, `verify_apns`, PR and CI aggregates | ✓ WIRED | Local full gate passed; CI/release contract includes `verify_apns` in both required aggregates. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| APNs request | persisted `apns_request_intent` | Delivery target → exact host lookup → payload → request | Yes | ✓ FLOWING |
| 410 invalidation | stream status/body → closed result → private classifier → exact host CAS | Real dispatcher/end stream in package fixture | Yes | ✓ FLOWING |
| Ordinary provider acceptance | stream status 200 → normal Pigeon handling → accepted result | Runtime bridge intercepts stream before normal handling | No | ✗ DISCONNECTED/INCORRECT |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Real public bridge → exact host CAS, including non-authority matrix | `CHIMEWAY_APNS_FOCUS=bridge_to_cas bash scripts/verify-apns.sh` | Exit 0; tagged package tracer passed. Resolver printed Pigeon 2.0.1 and Hackney 1.17.1 advisories. | ✓ PASS (functional); ✗ security gap |
| Full declared APNs contracts | `mix verify.apns` | Exit 0; 30 tests, 0 failures; package gate completed. Resolver printed Hackney 1.25.0 advisories including HIGH EEF-CVE-2026-47071. | ✓ PASS (covered behavior); ✗ security gap |
| Ordinary correlated HTTP 200 acceptance | named enabled-consumer test | No such test exists; source path routes 200 to rejected `unrecognized_provider_response`. | ✗ FAIL |

### Probe Execution

Step 7c: SKIPPED — no Phase 100 `probe-*.sh` exists or is declared. The phase declares executable package gates, which were run above.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| APNS-01 | 100-03, 100-05, 100-06 | Host opt-in without non-push Pigeon/configuration burden | ⚠️ BLOCKED | Isolation works, but the documented supported opt-in graph has unresolved advisories. |
| APNS-02 | 100-01, 100-02, 100-03, 100-05 | Exact host custody, routing, stable ID, bounds, opaque reference | ✓ SATISFIED | Durable intent, exact lookup, closed payload, migrations, and package proof pass. |
| APNS-03 | 100-04, 100-05, 100-06, 100-07 | Honest reason classification and exact-binding invalidation | ✗ BLOCKED | 410/CAS closure is proven, but ordinary success is misclassified as rejection in the optional runtime bridge. |
| APNS-04 | 100-01 through 100-05 | Absolute expiry suppression before send/retry | ✓ SATISFIED | Pre-transport expiry and APNs contract tests pass. |
| APNS-05 | 100-01, 100-03, 100-05 | Opt-in installation-safe collapse | ✓ SATISFIED | Default-absent, bounded, exact-scope collapse implementation/tests pass. |
| APNS-06 | 100-04, 100-05 | Distinct safe operator lifecycle evidence | ✗ BLOCKED | Accepted handoff is not reliable for normal runtime Pigeon success, undermining the distinct outcome claim. |

All six Phase 100 requirement IDs declared by PLAN frontmatter are accounted for. No additional Phase 100 requirement IDs are orphaned in `REQUIREMENTS.md`.

### Review-Fix Verification

| Review finding | Actual evidence | Verdict |
| --- | --- | --- |
| CR-01: normal APNs 200 success handling | Dynamic `process_end_stream/2` always calls `runtime_closed_result/1`; line 222 wraps unrecognized streams as rejected. No test injects a status-200 raw stream. | ✗ BLOCKER CONFIRMED |
| CR-02: Pigeon 2.0.1 dependency graph | Supported fixture pins `pigeon == 2.0.1`; both verifier executions emitted Hackney vulnerability advisories, including a high-severity advisory. | ✗ BLOCKER CONFIRMED |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- |
| `lib/chimeway/apns/transport.ex` | 153-168, 222-230 | Closed fallback treats all ordinary/unrecognized streams as rejected | 🛑 BLOCKER | Valid APNs 200 response cannot become accepted handoff in the Pigeon-neutral runtime bridge. |
| `test/fixtures/apns_consumer/mix.exs` | 19-20 | Hard-pinned supported Pigeon graph with unresolved advisory-bearing HTTP dependency | 🛑 BLOCKER | Shipping the advertised opt-in imports the affected graph. |
| `scripts/verify-apns.sh` | 37-44 | Version/lock assertion without advisory failure | ⚠️ WARNING | Green gate masks the graph-security failure. |

No unreferenced `TBD`, `FIXME`, or `XXX` markers were found in Phase 100 implementation artifacts. No later roadmap phase specifically owns a normal APNs-200 bridge correction or the Phase 100 Pigeon dependency-security disposition, so neither gap is deferred.

### Gaps Summary

Plan 100-07 successfully closes the previous APNS-03 composition gap: a real optional Pigeon 410 now traverses the public adapter and reaches only the original host CAS, while malformed/uncorrelated variants produce no successful invalidation. That evidence does not cover normal provider success, and the source proves its current handling is wrong in the intended Pigeon-neutral compilation mode.

The supported adapter also remains unsafe to ship while its prescribed Pigeon 2.0.1 fixture resolves known advisories. Both issues are objectively machine-testable, so this is an escalation gate with no conversational UAT request.

---

_Verified: 2026-08-21T18:27:48Z_
_Verifier: the agent (gsd-verifier)_

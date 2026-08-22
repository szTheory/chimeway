---
phase: 100-optional-apns-adapter
verified: 2026-08-22T16:07:23Z
status: gaps_found
score: 2/5 roadmap must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 42/44
  gaps_closed:
    - "Pre-provider lookup and payload-builder exceptions now produce bounded pre-handoff outcomes rather than possible provider handoff."
  gaps_remaining:
    - "The enabled packaged-consumer warning-strict compile still exits nonzero."
  regressions:
    - "Open references accept personal identifiers and URLs, then persist and send them as chimeway_open_ref."
    - "Caller-supplied collapse IDs accept CR/LF control characters and reach the APNs request header field."
gaps:
  - truth: "An APNs-enabled host can use the optional Pigeon-backed adapter through the supported packaged-consumer gate."
    status: failed
    reason: "The mandatory enabled-consumer proof exits nonzero during its warning-strict dependency compile."
    artifacts:
      - path: "scripts/verify-apns.sh"
        issue: "The forced `deps/chimeway` compile emits Oban.Repo.expected_error?/1 unreachable-clause warning under --warnings-as-errors."
    missing:
      - "Eliminate or isolate the warning so `bash scripts/verify-apns.sh` completes successfully under its declared strict gate."
  - truth: "Each request carries an opaque one-time open reference and never transfers sensitive routing data to APNs."
    status: failed
    reason: "Both durable intent and payload construction use a four-word blacklist rather than a closed opaque-reference format."
    artifacts:
      - path: "lib/chimeway/apns/request_intent.ex"
        issue: "`safe_opaque?/1` accepts `alice@example.com`; `to_storage/1` persists the value."
      - path: "lib/chimeway/apns/payload.ex"
        issue: "`opaque_ref?/1` accepts a URL and sends it as `chimeway_open_ref`, including when Payload.build/2 is called directly."
    missing:
      - "Require a closed opaque-reference format at both construction boundaries and add rejection tests for identifiers, URLs, and control characters."
  - truth: "A host-opted collapse key is installation-safe and distinct notifications are never silently coalesced."
    status: failed
    reason: "An explicit collapse ID is accepted based only on length and the same blacklist; CR/LF reaches Transport.Request.collapse_id."
    artifacts:
      - path: "lib/chimeway/apns/request_intent.ex"
        issue: "The explicit-collapse branch returns any binary unchanged, allowing header-control characters."
    missing:
      - "Constrain explicit collapse IDs to an APNs-header-safe allowlist (or derive all IDs internally) and add CR/LF/control-character regressions."
---

# Phase 100: Optional APNs Adapter Verification Report

**Phase Goal:** An APNs-enabled host can dispatch safe, bounded push requests and receive honest target-specific provider outcomes without adding push dependencies to other hosts.
**Verified:** 2026-08-22T16:07:23Z
**Status:** gaps_found
**Re-verification:** Yes — after Plan 100-09 gap closure

## Goal Achievement

### Roadmap Success Criteria

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Non-push hosts run without Pigeon/APNs config; opting-in hosts use the Pigeon-backed adapter through host lookup. | ✗ FAILED | The disabled path is structurally isolated, but the single supported enabled-consumer proof (`bash scripts/verify-apns.sh`) exits nonzero at `mix cmd --cd deps/chimeway mix compile --force --warnings-as-errors` on an Oban unreachable-clause warning. |
| 2 | Each request has exact routing, stable ID, bounded allowlisted payload, expiry, and opaque one-time open reference. | ✗ FAILED | Direct execution accepted `alice@example.com` as durable `open_ref` and `Payload.build/2` accepted/sent `https://private.example.test/open`; neither is opaque. |
| 3 | Provider outcomes are honest and target-specific. | ✓ VERIFIED | The current 15-test adapter/worker suite passed. In particular, raised lookup and payload-builder paths return bounded pre-handoff results with no transport invocation; only `safe_transport/2` maps failures to ambiguity. |
| 4 | Expiry suppresses sends/retries and collapse is opt-in, exact-target scoped, and default absent. | ✗ FAILED | Expiry and derived-collapse tests pass, but direct execution accepted `"safe\\r\\nvalue"` as a caller-supplied collapse ID and forwards it to `Transport.Request.collapse_id`; this is not installation-safe provider input. |
| 5 | Invalidation affects only the exact tenant/environment/topic/revision. | ✓ VERIFIED | `result_test.exs` passed and `APNS.classify_result/3` constructs `BindingLookup.InvalidationKey` from the target tenant/revision and persisted environment/topic before conditional invalidation. |

**Score:** 2/5 roadmap truths verified (0 present, behavior-unverified).

### Plan Must-Haves

All six requirement IDs declared in Plan frontmatter are accounted for below. The former Plan 100-04/09 pre-provider-honesty gap is closed by executable evidence. The Plan 100-09 strict-compile truth remains failed. Plan assertions that call the stored/sent value an "opaque" reference or an "installation-safe" collapse key are disproven by the direct boundary checks above; presence of the corresponding modules and tests is not sufficient.

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/chimeway/apns/request_intent.ex` | Durable validated APNs intent and safe collapse derivation | ✗ SUBSTANTIVE BUT UNSAFE | Wired through planning and adapter reload, but `safe_opaque?/1` is a blacklist and explicit collapse IDs admit control bytes. |
| `lib/chimeway/apns/payload.ex` | Closed bounded APNs payload | ✗ SUBSTANTIVE BUT UNSAFE | Wired by `APNS.deliver/2`; direct `Payload.build/2` accepts URLs as open refs and emits them in the provider payload. |
| `lib/chimeway/adapters/apns.ex` | Stage-scoped delivery and honest classification | ✓ VERIFIED | `safe_lookup/1`, `safe_payload/2`, and `safe_transport/2` have distinct rescue boundaries; focused 15 tests pass. |
| `lib/chimeway/apns/transport.ex` | Optional dynamic Pigeon bridge | ✓ VERIFIED | Single runtime callback bridge uses configured JSON decoder and normal 200 delegation; no Phase-100 debt markers found. |
| APNs intent migrations and golden fixtures | Same nullable safe-intent column in repository/public/prefixed modes | ✓ VERIFIED | Migration/prefix contract command passed (16 tests); all copies use `apns_request_intent`. |
| `scripts/verify-apns.sh` and consumer fixture | Disabled/enabled hermetic optionality proof | ✗ FAILED | Script correctly contains the strict dependency compile but currently terminates on a real warning, so it is not a passing release gate. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Delivery planning | persisted target intent | `DeliveryTargets.plan_targets/3` | ✓ WIRED | The target row stores `RequestIntent.to_storage/1`; adapter reloads with `RequestIntent.from_storage/1`. |
| APNS adapter | lookup → payload → transport | ordered stage helpers | ✓ WIRED | `deliver/2` invokes lookup and payload before its narrowly guarded `Transport.push/3`; current tests exercise the pre-handoff boundary. |
| Pigeon end stream | result classifier / exact CAS | `PigeonAdapter.process_end_stream/2` | ✓ WIRED | Correlated 410 is projected into a closed result; `classify_result/3` invokes `BindingLookup.invalidate/1` only for a complete recognized triple. |
| Mix alias / CI | package gate | `mix verify.apns`, `verify_apns`, `pr-gate`, `ci-gate` | ⚠️ WIRED BUT FAILING | The local and CI wiring exists, but the local command's enabled mode exits nonzero. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| APNs request | persisted `apns_request_intent` | planned target → adapter → host exact lookup → payload/headers → transport | Yes | ⚠️ FLOWING UNSAFELY — accepted `open_ref` data can be a personal identifier or URL. |
| Collapse header | `intent.collapse_id` | caller-supplied value → request → optional Pigeon transport | Yes | ✗ UNSAFE — CR/LF is not rejected before the provider header seam. |
| Pre-provider error | lookup/payload result | stage helper → executor → exact target outcome | Yes | ✓ FLOWING — test evidence confirms retryable/terminal truth with no handoff. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Pre-provider outcome boundary | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/adapters/apns_test.exs test/chimeway/dispatch/target_worker_test.exs --warnings-as-errors` | 15 tests, 0 failures | ✓ PASS |
| Intent/payload/result/expiry/collapse contracts | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns/request_test.exs test/chimeway/apns/tracer_test.exs test/chimeway/apns/result_test.exs test/chimeway/apns/api_coverage_test.exs --warnings-as-errors` | 11 tests, 0 failures | ✓ PASS — insufficient to prove opaque/header-safe negative cases, which are absent. |
| Installation and migration parity | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/migration_contract_test.exs test/chimeway/generated_prefixed_runtime_proof_test.exs test/chimeway/install/migrations_test.exs test/chimeway/install/golden_diff_test.exs test/chimeway/install/prefix_contract_test.exs --warnings-as-errors` | 16 tests, 0 failures | ✓ PASS |
| Enabled packaged consumer | `bash scripts/verify-apns.sh` | Nonzero: `lib/oban/repo.ex:253` warns that `Oban.Repo.expected_error?/1` clause is never used | ✗ FAIL |
| Opaque/open and collapse boundaries | `MIX_ENV=test mix run -e '...RequestIntent.new(...open_ref: "alice@example.com", collapse_id: "safe\\r\\nvalue")...; ...Payload.build(..., "https://private.example.test/open")'` | Both calls returned `{:ok, ...}`; payload contained the URL | ✗ FAIL |

### Probe Execution

Step 7c: SKIPPED — no Phase 100 `scripts/*/tests/probe-*.sh` probe is declared or present. The executable APNs gate was run directly above.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| APNS-01 | 03, 05, 06, 08, 09 | Optional Pigeon adapter without push dependencies for other hosts | ✗ BLOCKED | Disabled isolation is wired, but the required enabled packaged-consumer strict compilation exits nonzero. |
| APNS-02 | 01, 02, 03, 05, 08 | Exact host custody, safe bounded request, opaque open reference | ✗ BLOCKED | Durable/routing/bounds code and tests exist, but identifier/URL values are accepted, persisted, and/or emitted as the supposed opaque reference. |
| APNS-03 | 04, 05, 06, 07, 08, 09 | Reason-classified outcomes and exact-binding invalidation | ✓ SATISFIED | Adapter/worker and result suites pass; Plan 09 fixes pre-provider exceptions; complete 410-only CAS remains wired. |
| APNS-04 | 01, 02, 03, 04, 05, 08 | Absolute expiry before send/retry and explicit suppression | ✓ SATISFIED | Request/tracer and target lifecycle tests pass; adapter checks expiry before lookup/transport. |
| APNS-05 | 01, 03, 05, 08 | Opaque installation-safe opt-in collapse key; no implicit coalescing | ✗ BLOCKED | Derived identity is bounded/scoped, but explicit collapse input admits CR/LF and is provider-bound. |
| APNS-06 | 04, 05, 08, 09 | Distinct explainable operator outcome vocabulary | ✓ SATISFIED | Current tested pre-handoff, accepted, retryable, permanent, ambiguous, invalidated, expiry, and trace pathways remain distinct. |

No additional Phase 100 requirements are mapped by `REQUIREMENTS.md`; no requirement is orphaned.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `lib/chimeway/apns/request_intent.ex` | 31-35, 104, 123-126 | Blacklist-as-opaque validation; unrestricted explicit collapse value | 🛑 BLOCKER | Sensitive host routing data can become durable/provider payload; invalid header characters can reach the transport seam. |
| `lib/chimeway/apns/payload.ex` | 20-24, 47-50 | Duplicate permissive `opaque_ref?/1` boundary | 🛑 BLOCKER | Direct payload construction bypasses the durable-intent boundary and emits non-opaque values. |
| `scripts/verify-apns.sh` | 46 | Strict compilation observes a real Oban warning | 🛑 BLOCKER | The declared enabled-consumer acceptance gate is red. |

No unreferenced `TBD`, `FIXME`, or `XXX` marker was found in the inspected Phase 100 implementation artifacts.

### Deferred Items

None. Later phases cover registration, protected open, and end-to-end twin proof; they do not authorize unsafe routing data/header input or a failing Phase 100 package gate.

### Gaps Summary

This phase does not achieve its safety goal. The previous false-ambiguity gap is closed, but three observable failures remain: the strict enabled-consumer gate is red, an alleged opaque reference can be a user identifier or URL and is sent to APNs, and explicit collapse values are not header-safe. All are deterministic, machine-testable blockers. Per project policy, no conversational UAT or human-verification item is emitted.

---

_Verified: 2026-08-22T16:07:23Z_
_Verifier: the agent (gsd-verifier)_

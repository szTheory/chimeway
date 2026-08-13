---
phase: 98-privacy-safe-delivery-evidence
verified: 2026-08-13T15:33:52Z
status: gaps_found
score: 7/11 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 7/11
  gaps_closed:
    - "Allowlisted Trigger and digest facts now use field-specific validators; the earlier arbitrary `reason` value path is closed."
    - "`:digested` is included in the delivery-status projection."
  gaps_remaining: []
  regressions:
    - "A caller-controlled precomputed-rendering path persists rendered content."
    - "The public Trigger return emits transient rendered payload and recipient handoff values."
    - "Duplicate atom/string provider fields silently select the string value, including arbitrary recipient text."
gaps:
  - truth: "Chimeway does not retain raw rendered content at a Chimeway-owned delivery write boundary."
    status: failed
    reason: "The presence of a caller-supplied `:precomputed_rendering` entry makes render data trusted and writes the complete rendered map to `deliveries.render_data`."
    artifacts:
      - path: "lib/chimeway/delivery_planning.ex"
        issue: "`trusted_render_data?` is derived from public opts and passes unfiltered render data through `maybe_apply_render_result/3`."
      - path: "lib/chimeway/deliveries.ex"
        issue: "`normalize_optional_render_data/2` and `apply_render_result/2` persist a trusted map without SafeEvidence projection."
    missing:
      - "Remove the caller-forgeable trusted-render-data bypass and keep rendered payloads in a non-persistent dispatch context."
      - "Add a regression proving precomputed subject/body/recipient values are absent from a reloaded Delivery."
  - truth: "Chimeway does not emit raw recipient identity or rendered content from the public trigger API."
    status: failed
    reason: "`Trigger.trigger/3` returns `precomputed_rendering` and `recipient_handoffs`; the former contains rendered body data and the latter contains the address parsed from `user:<email>`."
    artifacts:
      - path: "lib/chimeway/trigger.ex"
        issue: "`normalize_trigger_result/4` adds both sensitive maps to the returned result; `dispatch_after_trigger/4` uses the same public map as its private handoff context."
    missing:
      - "Separate the in-process dispatch context from the public return shape and regression-test that neither map nor its sentinel values are returned."
  - truth: "Provider facts are closed and ambiguous atom/string duplicates cannot select an arbitrary durable value."
    status: failed
    reason: "`fetch_known/3` prefers the string key over its atom twin. `SafeEvidence.provider_facts(%{provider_code: \"atom_code\", \"provider_code\" => \"recipient@example.test\"})` returns the email as a durable provider code."
    artifacts:
      - path: "lib/chimeway/safe_evidence.ex"
        issue: "`provider_facts/1`, `attempt_attrs/1`, and `render_channels/1` use duplicate-blind `fetch_known/3`; provider_code has only a length check."
    missing:
      - "Use one duplicate-aware lookup that omits or rejects both map and keyword duplicates, and validate provider codes with the closed code grammar."
      - "Add atom/string conflict tests for provider facts, attempt attributes, and render channels."
---

# Phase 98: Privacy-Safe Delivery Evidence Verification Report

**Phase Goal:** Operators can explain delivery behavior without Chimeway retaining or emitting sensitive endpoint, credential, identity, or content data.
**Verified:** 2026-08-13T15:33:52Z
**Status:** gaps_found
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Nested maps, lists, and keyword diagnostics remove forbidden keys case-insensitively without atomizing input. | ✓ VERIFIED | `Privacy.redact/1` is recursive; the supplied authoritative CI and focused privacy suite cover mixed casing/shapes. |
| 2 | Operators can inspect safe trace, attempt, telemetry, and proof evidence using opaque refs and closed facts. | ✗ FAILED | The dedicated DTOs are wired, but `Traces.get_trace/2` can preload a Delivery whose `render_data` contains rendered content through the forgeable trusted path. |
| 3 | Fixture tokens, credentials, recipient data, links, rendered content, and provider bodies cannot escape Chimeway-owned storage or diagnostics. | ✗ FAILED | Rendered content is stored in `Delivery.render_data`; `Trigger.trigger/3` emits rendering and recipient-handoff maps. |
| 4 | Attempt persistence retains only outcome, classification, opaque provider reference, and narrowly validated provider facts. | ✗ FAILED | Runtime proof: `MIX_ENV=dev mix run --no-start -e ...provider_facts(...)` returned `%{"provider_code" => "recipient@example.test"}` for duplicate keys. |
| 5 | Trigger, planning, and Inbox use tenant/domain-bound opaque identity references. | ✓ VERIFIED | `Trigger`/`Inbox` call `SafeEvidence` reference constructors; Phase 97 tenant predicates remain in the write/read paths. |
| 6 | Telemetry and default logs use bounded metadata after merge and avoid arbitrary adapter-term inspection. | ✓ VERIFIED | `Telemetry.safe_meta/1` delegates to `SafeEvidence.telemetry_meta/1`; executor reduces unexpected results to `unknown_classification`. |
| 7 | Trace and Admin DTOs are safe before optional Admin redaction while preserving lifecycle explanation. | ✗ FAILED | `explain_delivery/2` projects safely and preserves `:digested`, but the other public trace API returns the raw preloaded delivery containing the persisted render map. |
| 8 | Proof output is closed, non-atomizing, and reports provider handoff without engagement claims. | ✓ VERIFIED | Proof fixture is wired to `SafeEvidence.proof/1`; supplied Core, Mailglass, and Accrue packaged proofs passed. |
| 9 | Migration 034 purges historical generic payload/content/provider blobs without deriving facts from raw data. | ✓ VERIFIED | Canonical/repository migration artifacts and installation/runtime-prefix evidence are present; supplied gates passed. |
| 10 | Repository, template, public, and prefixed migration paths have equivalent cleanup semantics. | ✓ VERIFIED | `verify.artifacts`/`verify.key-links` found the canonical generation and runtime-prefix wiring; supplied installer/runtime gates passed. |
| 11 | Phase-focused checks and CI provide automated evidence. | ✓ VERIFIED | The requester supplied an authoritative clean `mix ci` (1,396 tests, 0 failures) and focused privacy suite (57/0). This verifier's duplicate test run was blocked only by the current shared PostgreSQL connection limit. |

**Score:** 7/11 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/chimeway/privacy.ex` | Atom-safe recursive forbidden-key boundary | ✓ VERIFIED | Exists, substantive, and is used before safe projections. |
| `lib/chimeway/safe_evidence.ex` | Closed durable/diagnostic evidence vocabulary | ✗ PARTIAL | Broadly wired, but duplicate-blind provider lookup admits arbitrary recipient-shaped provider codes. |
| `lib/chimeway/trigger.ex` | Safe event/notification persistence and public boundary | ✗ PARTIAL | Persistence projection is wired; public result emits raw transient handoff data. |
| `lib/chimeway/delivery_planning.ex` / `deliveries.ex` | Non-sensitive delivery planning/persistence | ✗ PARTIAL | Trusted precomputed render payload is written directly to `render_data`. |
| `lib/chimeway/{traces,admin,telemetry,inbox}.ex` | Safe operator/diagnostic projections | ⚠️ PARTIAL | DTO paths are wired; `get_trace/2` exposes the raw preloaded delivery from the failed render-data path. |
| `priv/adoption_proof/artifact_consumer_fixture.ex` | Closed proof construction/parser | ✓ VERIFIED | Substantive, wired to `SafeEvidence.proof/1`, and covered by packaged proof evidence. |
| `priv/chimeway_migrations/034_privacy_safe_delivery_evidence.exs` | Prefix-aware historical cleanup | ✓ VERIFIED | Substantive template and generation/runtime links verified. |

### Key Link Verification

`gsd-tools verify.key-links` found all 14 declared links across Plans 01–07. The critical links are therefore present, but several are hollow at the data-flow layer: `Trigger → DeliveryPlanning → Deliveries` preserves the raw rendering map under a public-opts-derived trust flag, and `Trigger → public return` emits the transient handoff values.

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `trigger.ex` | Trigger result `precomputed_rendering`, `recipient_handoffs` | notifier rendering and `user:<email>` identity | Yes — raw rendered data/address | ✗ LEAKING |
| `delivery_planning.ex` | `Delivery.render_data` | `precomputed_rendering[{notification_id, channel}]` | Yes — complete render result, not a safe projection | ✗ LEAKING |
| `safe_evidence.ex` | provider facts | adapter map / keyword data | Yes — duplicate string key wins | ✗ LEAKING |
| `traces.ex` | `Explanation` | tenant-scoped lifecycle query → `SafeEvidence.trace/1` | Yes — closed DTO itself | ✓ FLOWING, but raw `get_trace/2` remains exposed |
| migration 034 | historical rows | canonical template → generated copies | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Duplicate provider facts fail closed | `MIX_ENV=dev mix run --no-start -e 'SafeEvidence.provider_facts(...)'` | `{:ok, %{"provider_code" => "recipient@example.test"}}` | ✗ FAIL |
| Existing lifecycle test records rendered body data | `env MIX_ENV=test mix test test/chimeway/integration/delivery_lifecycle_test.exs:1137 --warnings-as-errors` | Could not start: shared PostgreSQL `FATAL 53300 too_many_connections`; source test explicitly asserts persisted subject/html/text body at lines 1161–1169. | ? BLOCKED ENVIRONMENT |
| Phase privacy suites | focused 57-test command | Current retry blocked by same PostgreSQL capacity; requester supplied 57/0 authoritative run. | ✓ PASS (supplied executable evidence) |
| Workspace CI | `mix ci` | Requester supplied clean 1,396-test/0-failure run after Phase 98 fixes. | ✓ PASS (supplied executable evidence) |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| PRIV-03 | 98-01 through 98-07 | Recursive case-normalized redaction before every persistence and diagnostic surface. | ✗ BLOCKED | Recursive redaction works, but ambiguous provider duplicate keys violate the closed boundary and raw rendering reaches a public trace preload. |
| PRIV-04 | 98-01 through 98-07 | No raw tokens/credentials/recipient/link/provider body in storage or diagnostics; retain only opaque refs/classifications/allowlisted facts. | ✗ BLOCKED | Delivery writes persist rendered subject/body, Trigger emits recipient/render payloads, and provider facts can retain recipient text. |

All requirement IDs declared in every Plan frontmatter are accounted for. No Phase 98 requirement is orphaned. No later roadmap phase explicitly schedules any of these privacy-boundary repairs, so none are deferred.

### Review Findings Adjudication

| Finding | Verdict | Evidence |
| --- | --- | --- |
| CR-01 trusted/precomputed render data persists | 🛑 BLOCKER CONFIRMED | `delivery_planning.ex:117-145`, `:560-569`; `deliveries.ex:425-430`, `:617-630`; lifecycle test asserts the persisted body map. This violates the goal and PRIV-04. |
| CR-02 Oban loses transient recipient | ⚠️ WARNING CONFIRMED | Oban job args contain only `delivery_id`; worker reloads a Delivery whose `recipient_address` is virtual, while Mailglass falls back to `:missing_recipient`. This is a functional async-email regression, but it does not itself retain/emit sensitive data and is not an explicit PRIV-03/04 acceptance truth. |
| CR-03 Trigger public return leaks handoffs | 🛑 BLOCKER CONFIRMED | `trigger.ex:313-336` returns both sensitive maps and `:506-534` forwards that same map. This directly violates the goal's no-emission condition. |
| WR-01 atom/string provider fact ambiguity | 🛑 BLOCKER CONFIRMED | `fetch_known/3` at `safe_evidence.ex:388-393` prefers the string key; the standalone command retained `recipient@example.test`. This violates Plan 07's duplicate-key truth and PRIV-03/04. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `lib/chimeway/delivery_planning.ex` | 117, 560 | Caller-controlled trusted render-data bypass | 🛑 BLOCKER | Durable rendered content leak. |
| `lib/chimeway/deliveries.ex` | 427, 623 | Unprojected trusted render map persistence | 🛑 BLOCKER | Bypasses `SafeEvidence.render_data/1`. |
| `lib/chimeway/trigger.ex` | 335-336 | Sensitive transient context returned publicly | 🛑 BLOCKER | Emits recipient identity and rendered content. |
| `lib/chimeway/safe_evidence.ex` | 388-393 | String-over-atom duplicate preference | 🛑 BLOCKER | Allows arbitrary durable provider fact. |

No unreferenced `TBD`, `FIXME`, or `XXX` markers were found in the Phase-owned implementation/test set.

### Gaps Summary

The earlier allowed-key and `:digested` gaps are closed. However, the current code introduces three independently observable privacy failures: rendered content is durably persisted through a public “trusted” option, Trigger returns raw transient context, and duplicate provider keys can preserve arbitrary recipient text. Green tests and CI do not invalidate these failures because the existing lifecycle test actually codifies the first behavior and there is no negative coverage for the latter two paths.

---

_Verified: 2026-08-13T15:33:52Z_
_Verifier: the agent (gsd-verifier)_

---
phase: 101-crosswake-registration-protected-open
verified: 2026-08-25T15:12:51Z
status: gaps_found
score: 2/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/4
  gaps_closed:
    - "Provider feedback now selects and conditionally invalidates an exact authenticated binding revision."
    - "Forward migration reconciles both authority and token-identity active-row uniqueness domains before replacement indexes."
    - "The native pending-open queue compacts duplicate open_ref evidence before its production drain."
  gaps_remaining: []
  regressions:
    - "Supported :subject_installation bindings cannot receive provider invalidation because provider_feedback_scope/1 unconditionally requires session_ref and session_version."
    - "Supported :subject_installation bindings cannot issue notification-open intents because the intent schema unconditionally requires session_ref and session_version."
    - "Notification-open intent metadata is caller-controlled and persists without the existing token/payload metadata sanitizer."
gaps:
  - truth: "A signed-in user can complete permission, APNs registration, and authenticated host binding; repeated observations, rotation, logout, revocation, and provider invalidation leave only the current binding usable."
    status: failed
    reason: "The durable TokenBinding schema explicitly supports :subject_installation bindings without session fields, but provider feedback rejects that valid authority scope before it can conditionally invalidate its exact active binding."
    artifacts:
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex"
        issue: "provider_feedback_scope/1 requires session_ref/session_version and equality with authenticated context for every scope."
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/token_binding.ex"
        issue: "validate_scope_consistency/1 permits :subject_installation with neither session field, creating a supported lifecycle the feedback path cannot serve."
    missing:
      - "Scope provider-feedback validation and predicates by subject_scope, with an executable installation-scoped invalidation test."
  - truth: "A notification tap contains only opaque evidence; offline taps queue safely and reconnect only activates a one-time intent after tenant, revision, expiry, session, manifest, and RouteGate reauthorization."
    status: failed
    reason: "Intent issuance accepts arbitrary metadata for durable storage, including forbidden raw-token/payload keys, and the valid installation-scoped binding lifecycle cannot issue its one-time intent."
    artifacts:
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/notification_open_intent.ex"
        issue: "changeset/2 casts :metadata without sanitizing/rejecting forbidden nested or top-level data and unconditionally validates session_ref/session_version."
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex"
        issue: "issue_notification_open_intent/1 forwards caller metadata and copies nil session fields from a valid :subject_installation binding."
    missing:
      - "Apply a closed metadata sanitizer/rejection policy at intent persistence and test raw-token, notification-body, and nested-payload attempts."
      - "Either restrict this feature to subject-session bindings at bind time or model an exact installation scope throughout issue and consume, with executable coverage."
---

# Phase 101: CrossWake Registration & Protected Open Verification Report

**Phase Goal:** A CrossWake host can bind APNs registrations and activate notification routes only when current host authority permits it.
**Verified:** 2026-08-25T15:12:51Z
**Status:** gaps_found
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A signed-in user can complete permission, APNs registration, and authenticated host binding; repeated observations, rotation, logout, revocation, and provider invalidation leave only the current binding usable. | ✗ FAILED | Exact session-scoped feedback is now wired and tested, but `provider_feedback_scope/1` requires session fields even though `TokenBinding` supports `:subject_installation` without them. Invalidating feedback for that valid binding fails closed as `:no_active_bindings`, leaving the stale binding active. |
| 2 | Malformed, absent, or unknown action and route configuration is rejected by a manifest-consistent default-deny policy. | ✓ VERIFIED | Schema, builder, validator, resolver membership check, and notification RouteGate linkage are substantive; 73 focused policy/manifest tests pass. |
| 3 | A notification tap contains only opaque evidence; offline taps queue safely and reconnect only activates a one-time intent after tenant, revision, expiry, session, manifest, and RouteGate reauthorization. | ✗ FAILED | Queue first-wins compaction and consume-first authorization work, but `NotificationOpenIntent.changeset/2` persists arbitrary caller metadata and its required session fields prevent issuance for a valid installation-scoped binding. |
| 4 | Replayed, expired, revoked, mismatched, logged-out, tenant-switched, or removed-route opens activate no fallback route and produce sanitized denial evidence. | ✓ VERIFIED | Resolver returns closed denials after host consumption/current-policy checks; native protected-denial handling is terminal and 11 focused Swift tests pass. |

**Score:** 2/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `packages/crosswake_chimeway/.../{contracts,resolver,denial_codes,telemetry}.ex` | Server-bound resolution, default denial, sanitized terminal outcomes | ✓ VERIFIED | Substantive contracts/resolver (691/139 lines) are wired to host consumption and `RouteGate.evaluate/4`; focused policy and native-denial suites pass. |
| `lib/crosswake/policy/schema.ex`, `manifest/{builder,types,validator}.ex` | One normalized closed action-policy representation | ✓ VERIFIED | Substantive, wired normalization/validation path; malformed, absent, and unknown policy coverage passes. |
| `examples/phoenix_host/.../registry.ex` | Exact-scoped registration lifecycle, provider invalidation, and one-time intent issuing/consumption | ✗ INCOMPLETE | Exact session-scoped feedback repair is real, but its scope builder cannot express the supported installation scope; issuing an intent forwards unsanitized metadata. |
| `examples/phoenix_host/.../notification_open_intent.ex` | Opaque, scope-authorized durable intent | ✗ INCOMPLETE | Directly casts arbitrary `metadata` and requires session fields for all intents. |
| `.../20260824210000_upgrade_chimeway_registration_authority.exs` | Safe forward authority migration | ✓ VERIFIED | Reconciles authority then token-identity partitions before recreating indexes; the released-schema collision test passes. |
| `crosswake-shell-core-ios/.../{NotificationRegistrationCoordinator,NotificationOpenQueue,ActivationCoordinator}.swift` | Acknowledged permission-loss revoke, bounded opaque queue, terminal protected activation | ✓ VERIFIED | Substantive and wired; queue compacts duplicate `openRef`s on enqueue/reload/drain and focused Swift suite passes. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `Registry.consume_intent/1` | `Resolver.resolve/3` | Host-bound `OpenResolution`, then current manifest/RouteGate | ✓ WIRED | Host returns route/action only after atomic consumption; resolver uses `activation_source: :notification`. |
| `NotificationOpenQueue.drain` | host consumer → `ActivationCoordinator.handleProtectedNotificationOutcome` | One compacted opaque item per `openRef` | ✓ WIRED | `pruneAndCompactPendingItems()` precedes production drain; XCTest proves one consume and stable allowed presentation. |
| provider feedback | exact active binding revision | authenticated scope plus conditional update | ⚠️ PARTIAL | `feedback_target_query/2` and update repeat the exact predicates for session scope, but the scope builder rejects valid installation scope. |
| `Registry.issue_notification_open_intent/1` | `NotificationOpenIntent.changeset/2` | authoritative binding-derived scope and safe durable evidence | ✗ NOT WIRED SAFELY | The call sends caller `metadata` unchanged and copies nil session fields from installation-scoped bindings into a schema that rejects them. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Phoenix registry | bindings/intents | Ecto transaction, predicate updates, durable rows | Yes | ⚠️ PARTIAL — session-scoped lifecycle flows, but installation-scoped invalidation/issuance does not. |
| Resolver | route/action | Host-consumed `OpenResolution`, current compiled manifest, RouteGate | Yes | ✓ FLOWING |
| Native queue | opaque evidence | File-backed Codable queue | Yes | ✓ FLOWING — compacts legacy/duplicate records before drain. |
| Intent metadata | `metadata` | Caller-supplied `attrs` | No safe boundary | ✗ UNSAFE — raw token/payload fields reach durable storage without sanitization. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Registration lifecycle, migration collision repair, open CAS, and native adapter | `cd examples/phoenix_host && MIX_ENV=test mix test registry_test.exs registry_notification_open_test.exs registration_authority_migration_upgrade_test.exs notification_registration_adapter_test.exs --seed 0` | 19 tests, 0 failures | ✓ PASS — does not exercise installation-scoped feedback/issuance or intent metadata rejection. |
| Closed manifest policy | `cd crosswake && MIX_ENV=test mix test schema_test.exs route_test.exs builder_test.exs validator_test.exs --seed 0` | 73 tests, 0 failures | ✓ PASS |
| Native registration, queue, and protected activation | `cd packages/crosswake-shell-core-ios && swift test --filter 'NotificationRegistrationTests\|NotificationOpenQueueTests\|ProtectedNotificationActivationTests'` | 11 tests, 0 failures | ✓ PASS |

### Probe Execution

Step 7c: SKIPPED — no phase-declared or conventional `scripts/*/tests/probe-*.sh` files found.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| OPEN-01 | 101-04, 101-06, 101-09, 101-10, 101-11, 101-12 | Permission → APNs registration → authenticated binding lifecycle including provider invalidation | ✗ BLOCKED | A valid `:subject_installation` binding cannot be invalidated by provider feedback. |
| OPEN-02 | 101-02, 101-03, 101-09 | Closed manifest-consistent action policy | ✓ SATISFIED | Normalizer, compiled validator, exact resolver membership, and focused suite pass. |
| OPEN-03 | 101-01, 101-03, 101-05, 101-07, 101-09, 101-13 | Opaque queued one-time reauthorized protected open | ✗ BLOCKED | Intent metadata can contain raw sensitive material; valid installation-scoped bindings cannot issue a protected open. |
| OPEN-04 | 101-01, 101-05, 101-08, 101-09 | Sanitized no-fallback denied opens | ✓ SATISFIED | Closed host outcomes and terminal native behavior are wired and tested. |

All requirement IDs declared by the 13 plan frontmatters are accounted for. No additional Phase 101 requirements are orphaned in `REQUIREMENTS.md`.

### Advisory Review Disposition

| Review finding | Verdict | Why |
| --- | --- | --- |
| CR-01: arbitrary intent metadata | BLOCKER | Directly violates OPEN-03’s opaque-evidence boundary and the project prohibition on durable raw token/payload storage. The implementation has an existing sanitizer but does not invoke it here. |
| WR-01: installation-scoped provider invalidation | BLOCKER | Invalidates OPEN-01 for an authority scope the binding schema explicitly accepts. |
| WR-02: installation-scoped intent issuance | BLOCKER | Invalidates OPEN-03 for the same supported scope: it cannot complete the host-issued one-time intent lifecycle. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `notification_open_intent.ex` | 33-58 | Caller-controlled `metadata` cast without sanitization/rejection | 🛑 Blocker | Durable raw token, provider payload, or notification content can bypass the host metadata boundary. |
| `registry.ex` | 1526-1548 | Unconditional session-scoped provider-feedback validation | 🛑 Blocker | Supported installation-scoped binding remains active after invalidating feedback. |
| `notification_open_intent.ex` | 48-58 | Unconditional session fields in intent schema | 🛑 Blocker | Supported installation-scoped binding cannot receive a protected notification open. |
| Phase-modified sources | — | Debt-marker scan | ℹ️ Info | No unreferenced `TBD`, `FIXME`, or `XXX` marker found. |

## Gaps Summary

The prior provider-scope, migration, and duplicate-queue defects are closed. This re-verification nonetheless fails the phase: the public intent issuer can retain non-opaque evidence, and the code advertises `:subject_installation` binding support while blocking both provider invalidation and protected-open issuance for that scope. These are executable contract gaps, not a need for conversational UAT. Phase 102's digital-twin goal does not explicitly own either implementation repair, so none is deferred.

---

_Verified: 2026-08-25T15:12:51Z_
_Verifier: the agent (gsd-verifier)_

---
phase: 101-crosswake-registration-protected-open
verified: 2026-08-25T17:12:50Z
status: gaps_found
score: 2/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/4
  gaps_closed:
    - "Installation-scoped provider feedback now accepts nil session authority and conditionally invalidates its exact active binding."
    - "Installation-scoped bindings now issue and atomically consume one protected-open intent with nil session fields."
  gaps_remaining: []
  regressions:
    - "The metadata sanitizer remains an exact-name blocklist, so arbitrary caller-controlled sensitive fields can be durably persisted in notification-open intent metadata."
    - "The binding changeset permits :subject_installation rows with session fields; a session logout query can therefore revoke an installation-scoped binding."
gaps:
  - truth: "A signed-in user can complete permission, APNs registration, and authenticated host binding; repeated observations, rotation, logout, revocation, and provider invalidation leave only the current binding usable."
    status: failed
    reason: "The supported :subject_installation scope is not constrained to nil session authority. Registry.bind_or_rotate/3 forwards supplied session fields, and revoke_for_logout/2 selects rows by session_ref without subject_scope. A session logout can revoke a longer-lived installation binding."
    artifacts:
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/token_binding.ex"
        issue: "validate_scope_consistency/1 has no installation-scope nil-session invariant."
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex"
        issue: "Logout query at lines 550-557 lacks b.subject_scope == :subject_session."
    missing:
      - "Reject session_ref/session_version for :subject_installation at the binding boundary (and preferably in the database), scope logout to :subject_session, and add a bind-plus-logout regression test."
  - truth: "A notification tap contains only opaque evidence; offline taps queue safely and reconnect only activates a one-time intent after tenant, revision, expiry, session, manifest, and RouteGate reauthorization."
    status: failed
    reason: "NotificationOpenIntent changesets call MetadataSanitizer, but that sanitizer preserves every key except a small literal blocklist. Caller-controlled keys such as deviceToken, authorization, user_email, arbitrary provider-body names, and nested variants survive to durable metadata, so the evidence is not demonstrably opaque."
    artifacts:
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/metadata_sanitizer.ex"
        issue: "Lines 10-60 implement a finite forbidden-key blocklist and recursively retain unknown keys and scalar values."
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/notification_open_intent.ex"
        issue: "Lines 90-94 persist the blocklist projection rather than an opaque-only allowlist/rejection boundary."
    missing:
      - "Use a narrow documented allowlist (or reject/drop all caller metadata), including recursive scalar/type bounds, and add durable regression cases for camelCase token, authorization/PII, arbitrary provider-body, and nested unknown fields."
---

# Phase 101: CrossWake Registration & Protected Open Verification Report

**Phase Goal:** A CrossWake host can bind APNs registrations and activate notification routes only when current host authority permits it.
**Verified:** 2026-08-25T17:12:50Z
**Status:** gaps_found
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Signed-in permission, APNs observation, authenticated binding, rotation, logout/revocation, and provider invalidation leave only the current binding usable. | ✗ FAILED | Installation-scoped provider invalidation is now exact and tested, but a binding declared `:subject_installation` can still carry session fields and is then selected by the session-logout query. |
| 2 | Malformed, absent, or unknown action and route configuration is rejected by a manifest-consistent default-deny policy. | ✓ VERIFIED | Policy schema/builder/validator and resolver exact-action membership are substantive and wired; 60 focused root tests plus 33 companion tests pass. |
| 3 | A tap carries only opaque evidence; offline queueing and reconnect perform a one-time, currently-authorized protected open. | ✗ FAILED | The queue, atomic consume, and installation scope repair work, but durable intent metadata remains caller-controlled except for a finite key blocklist, violating the opaque-evidence boundary. |
| 4 | Replayed, expired, revoked, mismatched, logged-out, tenant-switched, or removed-route opens never fall back and return sanitized denial evidence. | ✓ VERIFIED | `Registry.consume_intent/1` atomically consumes before resolver checks; resolver and native terminal-denial suites pass, including all protected-denial cases. |

**Score:** 2/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `registry.ex` | Exact binding lifecycle and protected-intent issue/consume | ⚠️ INCOMPLETE | L1/L2 substantive and L3 wired. Scope-aware feedback/consume predicates are real, but logout can cross the supported installation/session boundary. |
| `token_binding.ex` | Durable authority-scope invariants | ✗ INCOMPLETE | L1/L2 substantive, but `:subject_installation` has no nil-session invariant, leaving a cross-lifecycle authority path. |
| `notification_open_intent.ex` | Scope-consistent, opaque durable one-time intent | ⚠️ INCOMPLETE | Scope checks and sanitizer link are wired, but the linked sanitizer does not make arbitrary caller metadata opaque. |
| `metadata_sanitizer.ex` | Recursive safe metadata boundary | ✗ UNSAFE | Exists and is used, but it is a narrow blocklist; unknown top-level/nested keys flow through unchanged. |
| `policy/schema.ex`, `manifest/{types,builder,validator}.ex`, `resolver.ex` | Closed policy and current RouteGate authorization | ✓ VERIFIED | Substantive normalization/validation and consume-first resolver path are covered by focused tests. |
| iOS registration/open queue/activation coordinators | Transient registration, bounded opaque queue, terminal activation | ✓ VERIFIED | Substantive and wired; selected Swift suites cover registration, reload/duplicate queue compaction, and no-fallback terminal denials. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `Registry.provider_feedback_scope/1` | exact feedback select and mutation | scope-aware predicates | ✓ WIRED | Installation and session branches have exact binding/install/tenant/subject predicates; focused install feedback test passes. |
| `Registry.issue_notification_open_intent/1` | `NotificationOpenIntent.changeset/2` | binding-derived scope/session fields | ✓ WIRED | Installation scope persists nil session fields and consumes once; focused suite passes. |
| `Registry.consume_intent/1` | `TokenBinding` exact active revision | Ecto `update_all` with `exists` predicate | ✓ WIRED | One predicate-CAS checks active binding and scope before issued→consumed transition. |
| `NotificationOpenIntent.changeset/2` | `MetadataSanitizer.sanitize/1` | before insert | ✗ NOT WIRED SAFELY | Call is present, but the downstream blocklist admits arbitrary durable metadata. |
| native protected outcome | `ActivationCoordinator` | allowed route only; denied outcome terminal | ✓ WIRED | Three Swift protected-activation tests pass. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Phoenix registry | bindings/intents | Ecto transactions and conditional updates | Yes | ⚠️ PARTIAL — current scope data flows, but malformed installation/session authority flows into logout selection. |
| Resolver | route/action | host-consumed resolution, current manifest, RouteGate | Yes | ✓ FLOWING |
| Native queue | opaque `openRef` evidence | file-backed Codable queue | Yes | ✓ FLOWING |
| Intent metadata | caller `attrs.metadata` | blocklist sanitizer | No safe opaque projection | ✗ UNSAFE |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Installation feedback, scope-consistent issue/consume, replay, and named-key metadata removals | `cd examples/phoenix_host && MIX_ENV=test mix test registry_test.exs notification_open_intent_test.exs registry_notification_open_test.exs --seed 0` | 24 tests, 0 failures | ✓ PASS — does not test unknown sensitive metadata or installation scope carrying a session. |
| Closed policy/manifest normalization and validation | `cd crosswake && MIX_ENV=test mix test schema_test.exs builder_test.exs validator_test.exs --seed 0` | 60 tests, 0 failures | ✓ PASS |
| Resolver denial/redaction/telemetry contracts | `cd packages/crosswake_chimeway && MIX_ENV=test mix test resolver_test.exs denial_codes_test.exs redaction_test.exs telemetry_test.exs --seed 0` | 33 tests, 0 failures | ✓ PASS |
| Native registration, queue, and protected activation | `cd packages/crosswake-shell-core-ios && swift test --filter 'NotificationRegistrationTests|NotificationOpenQueueTests|ProtectedNotificationActivationTests'` | 11 tests, 0 failures | ✓ PASS |

### Probe Execution

Step 7c: SKIPPED — no phase-declared or conventional `scripts/*/tests/probe-*.sh` probes found.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| OPEN-01 | 101-04, 06, 09-12, 14 | Authenticated registration lifecycle and exact invalidation | ✗ BLOCKED | Installation scope may receive session authority and be revoked by a session logout. |
| OPEN-02 | 101-02, 03, 09 | Closed manifest-consistent action policy | ✓ SATISFIED | Focused schema, builder, validator, and resolver suites pass. |
| OPEN-03 | 101-01, 03, 05, 07, 09, 13, 14 | Opaque queued one-time reauthorized protected open | ✗ BLOCKED | A caller can retain unknown sensitive metadata at the durable intent boundary. |
| OPEN-04 | 101-01, 05, 08, 09 | Sanitized, no-fallback denial outcomes | ✓ SATISFIED | Atomic host outcomes, resolver mappings, and native terminal behavior are executable and pass. |

All four IDs declared across the 14 PLAN frontmatters are accounted for. No Phase 101 requirement is orphaned in `REQUIREMENTS.md`.

### Must-NOT / Review Disposition

| Item | Verdict | Evidence |
| --- | --- | --- |
| Exact installation feedback must not invalidate another authority scope | ✓ VERIFIED | Exact install/sibling-control test passes and both query/mutation reuse scope predicates. |
| Intent metadata must not become a durable shadow token/content/payload store | ✗ FAILED — BLOCKER | The plan’s judgment-tier prohibition is contradicted by the finite blocklist implementation; unknown sensitive fields are persisted. |
| Client evidence must not supply route/action/tenant/binding/session authority; denied opens must not fall back | ✓ VERIFIED | Host-derived `OpenResolution` and Swift terminal-denial test suite. |
| Review CR-02: logout may revoke installation scope | ✗ CONFIRMED — BLOCKER | Binding invariant and logout predicate together establish the observable cross-scope path; no regression test excludes it. |
| Review WR-01: native coordinator callback concurrency | ⚠️ WARNING | Mutable state is not isolated and no concurrent test exists. Exact backend CAS limits authority impact, so this does not independently falsify a roadmap truth, but it should be serialized/tested. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `metadata_sanitizer.ex` | 10-60 | finite literal-key blocklist used as a privacy boundary | 🛑 Blocker | Unrecognised sensitive metadata is durably retained. |
| `token_binding.ex` | 153-167 | installation scope accepts session authority | 🛑 Blocker | A session lifecycle action can deactivate a longer-lived installation binding. |
| `registry.ex` | 550-557 | logout predicate lacks `subject_scope` | 🛑 Blocker | Completes the cross-scope revocation path. |
| `NotificationRegistrationCoordinator.swift` | 85-133 | unsynchronised mutable callback state | ⚠️ Warning | Duplicate/out-of-order shell commands remain possible; CAS makes them fail safe. |
| Phase-modified sources | — | debt-marker scan | ℹ️ Info | No unreferenced `TBD`, `FIXME`, or `XXX` marker found. |

### Gaps Summary

The prior installation-feedback and installation-intent failures are genuinely repaired. This re-verification still fails because two separate, machine-testable authority/privacy defects remain: installation authority can be silently coupled to a session lifecycle, and the durable intent boundary accepts unknown caller metadata. Phase 102’s hermetic-proof goal does not explicitly own either repair, so neither is deferred.

---

_Verified: 2026-08-25T17:12:50Z_
_Verifier: the agent (gsd-verifier)_

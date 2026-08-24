---
phase: 101-crosswake-registration-protected-open
verified: 2026-08-24T21:50:43Z
status: gaps_found
score: 2/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/4
  gaps_closed:
    - "A rejected native permission-loss revoke is retained and retried until the host returns revoked or staleNoop."
    - "Concurrent observations of one authority scope with different app-identity postures converge on one active binding."
  gaps_remaining:
    - "Provider invalidation is still selected by token fingerprint/token_ref rather than exact authenticated authority scope."
    - "The forward migration does not reconcile the new token-identity uniqueness domain before creating its index."
    - "Duplicate queued opaque evidence is consumed twice and can replace an allowed activation with a replay denial."
  regressions: []
gaps:
  - truth: "A signed-in user can complete permission, APNs registration, and authenticated host binding; repeated observations, rotation, logout, revocation, and provider invalidation leave only the current binding usable."
    status: failed
    reason: "Provider invalidation selects all matching active token fingerprints/token refs without the authority scope, and the forward migration can fail while creating the new token-identity unique index for valid pre-upgrade data."
    artifacts:
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex"
        issue: "feedback_target_query/1 and the conditional update omit app identity, tenant/org, subject, installation, session/version, and binding revision."
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260824210000_upgrade_chimeway_registration_authority.exs"
        issue: "reconcile_active_collisions/0 reconciles only the authority partition, then replace_active_indexes/0 creates an additional token-identity unique index that old-valid rows may violate."
    missing:
      - "Require an opaque exact binding reference plus authenticated authority scope for invalidating provider feedback, and include that scope in selection and conditional update tests."
      - "Reconcile both new uniqueness domains before creating replacement indexes and seed the different-authority/same-token old-data collision in the upgrade test."
  - truth: "A notification tap contains only opaque evidence; offline taps queue safely and reconnect only activates a one-time intent after tenant, revision, expiry, session, manifest, and RouteGate reauthorization."
    status: failed
    reason: "NotificationOpenQueue accepts duplicate open_ref entries and drains both. The second host call is a replay denial which the production drain forwards to ActivationCoordinator, replacing the successful protected activation with a terminal denial."
    artifacts:
      - path: "/Users/jon/projects/crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationOpenQueue.swift"
        issue: "enqueue/1 appends every item and both drain overloads iterate every duplicate without open_ref deduplication."
      - path: "/Users/jon/projects/crosswake/packages/crosswake-shell-core-ios/Tests/CrosswakeShellCoreTests/NotificationOpenQueueTests.swift"
        issue: "No test enqueues duplicate evidence and asserts one consume, one activation, and preserved allowed presentation."
    missing:
      - "Deduplicate pending queue entries by open_ref (or suppress duplicates during drain) and add a production-drain test for the final allowed presentation."
---

# Phase 101: CrossWake Registration & Protected Open Verification Report

**Phase Goal:** A CrossWake host can bind APNs registrations and activate notification routes only when current host authority permits it.
**Verified:** 2026-08-24T21:50:43Z
**Status:** gaps_found
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A signed-in user can complete permission, APNs registration, and authenticated host binding; repeated observations, rotation, logout, revocation, and provider invalidation leave only the current binding usable. | ✗ FAILED | Permission-loss retry and same-scope posture races are repaired, but provider feedback can revoke a different authority scope and the forward migration can fail on a new token-identity collision. |
| 2 | Malformed, absent, or unknown action and route configuration is rejected by a manifest-consistent default-deny policy. | ✓ VERIFIED | Schema normalization, compiled validator, resolver exact-membership check, and notification-source RouteGate wiring are substantive and covered by 99 focused ExUnit tests. |
| 3 | A notification tap contains only opaque evidence; offline taps queue safely and reconnect only activates a one-time intent after tenant, revision, expiry, session, manifest, and RouteGate reauthorization. | ✗ FAILED | The host CAS/resolver path is real, but duplicate queued `open_ref` records are sent twice; the replay response can overwrite the valid activation. |
| 4 | Replayed, expired, revoked, mismatched, logged-out, tenant-switched, or removed-route opens activate no fallback route and produce sanitized denial evidence. | ✓ VERIFIED | Resolver returns closed denials after host consume/current-manifest/RouteGate checks; native protected-denial handling is terminal and the focused denial suite passes. |

**Score:** 2/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `packages/crosswake_chimeway/.../resolver.ex` | Consume-first, exact-policy current authority resolution | ✓ VERIFIED | Host-supplied route/action only; exact action membership then `RouteGate.evaluate/4` with `activation_source: :notification`. |
| `lib/crosswake/policy/schema.ex`, `manifest/{builder,types,validator}.ex` | One closed notification-open representation | ✓ VERIFIED | Canonical non-empty allowlist and malformed-policy rejection are implemented and exercised. |
| `examples/phoenix_host/.../registry.ex` | Exact scoped registration lifecycle and provider invalidation | ✗ INCOMPLETE | Binding paths are substantive, but invalidating provider feedback has no exact authority-scope predicate. |
| `.../20260824210000_upgrade_chimeway_registration_authority.exs` | Safe forward authority migration | ✗ INCOMPLETE | Adds/backfills authority fields, but only reconciles one of two new uniqueness domains. |
| `crosswake-shell-core-ios/.../NotificationRegistrationCoordinator.swift` | Acknowledgement-driven permission-loss revoke | ✓ VERIFIED | `.rejected` retains the command; `.revoked`/`.staleNoop` set the delivered marker. XCTest passes. |
| `crosswake-shell-core-ios/.../NotificationOpenQueue.swift` | Bounded durable opaque queue with one host consume per open | ✗ INCOMPLETE | Bounded opaque storage works, but duplicate `open_ref` evidence is not deduplicated. |
| `.../denial_codes.ex`, `telemetry.ex`, `ActivationCoordinator.swift` | Sanitized, terminal no-fallback denial handling | ✓ VERIFIED | Closed denial vocabulary/redaction and protected terminal handler are wired and tested. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `Registry.consume_intent/1` | `Resolver.resolve/3` | Server-bound `OpenResolution` | ✓ WIRED | Resolver calls the host consumer before route selection and ignores client route/action choices. |
| `Resolver.resolve/3` | `RouteGate.evaluate/4` | Exact current policy, notification source | ✓ WIRED | `activation_source: :notification` and host auth context are passed after exact allowlist membership. |
| `NotificationRegistrationCoordinator.recheckPermissionState()` | authenticated adapter → `Registry.revoke_for_permission_loss/2` | Retained exact binding command | ✓ WIRED | Terminal acknowledgement is now required; the retry test passes. |
| `NotificationOpenQueue.drain` | host consumer → protected activation | Opaque evidence, terminal removal | ✗ NOT WIRED SAFELY | The linkage is present but duplicate evidence results in two consumes and a later replay denial presentation. |
| provider feedback | exact active binding revision | conditional invalidation | ✗ NOT WIRED SAFELY | Query/update use token selector and provider/platform/environment only, not authority scope. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Phoenix registry | bindings/intents | Ecto queries plus transaction/CAS updates | Yes | ⚠️ UNSAFE for provider feedback and one upgrade collision class |
| Resolver | route/action | Host-consumed `OpenResolution`, then current manifest | Yes | ✓ FLOWING |
| Native queue | opaque evidence | File-backed Codable queue | Yes | ⚠️ DUPLICATE-HOLLOW — duplicate records yield a second terminal outcome |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Registration migration, lifecycle, open CAS, and native adapter | `cd examples/phoenix_host && MIX_ENV=test mix test ...registration_authority_migration_upgrade_test.exs ...registry_test.exs ...registry_notification_open_test.exs ...notification_registration_adapter_test.exs` | 18 tests, 0 failures | ✓ PASS — does not seed the uncovered cross-authority token collision or provider invalidation scope. |
| Policy, compiled manifest, resolver, denial, and telemetry | `MIX_ENV=test mix test ...schema_test.exs ...route_test.exs ...builder_test.exs ...validator_test.exs`; package companion suite | 73 + 26 tests, 0 failures | ✓ PASS |
| Native registration/queue/protected activation | `cd packages/crosswake-shell-core-ios && swift test --filter 'NotificationRegistrationTests\|NotificationOpenQueueTests\|ProtectedNotificationActivationTests'` | 10 tests, 0 failures | ✓ PASS — no duplicate-open production-drain assertion. |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| OPEN-01 | 101-04, 101-06, 101-09, 101-10, 101-11 | Authenticated APNs binding lifecycle | ✗ BLOCKED | Provider invalidation can target another authority scope; forward migration can fail on token-identity conflicts. |
| OPEN-02 | 101-02, 101-03, 101-09 | Closed manifest-consistent action policy | ✓ SATISFIED | Normalizer, compiled validator, and exact resolver membership pass focused tests. |
| OPEN-03 | 101-01, 101-03, 101-05, 101-07, 101-09 | Opaque queued, one-time, reauthorized protected open | ✗ BLOCKED | Duplicate opaque queue entries violate the one-host-consume/reconnect behavior and can overwrite allowed activation. |
| OPEN-04 | 101-01, 101-05, 101-08, 101-09 | No-fallback sanitized stale/denied opens | ✓ SATISFIED | Resolver and activation denial matrix are closed, sanitized, terminal, and tested. |

### Advisory Review Disposition

| Review finding | Verdict | Why |
| --- | --- | --- |
| CR-01: provider invalidation scope | BLOCKER | Directly violates OPEN-01 exact current binding authority. |
| CR-02: migration token-identity reconciliation | BLOCKER | A legitimate upgraded host can be unable to obtain the current authority schema. |
| CR-03: duplicate queue evidence | BLOCKER | Directly violates OPEN-03’s safe one-time reconnect path. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `registry.ex` | 929-983 | Token-only provider invalidation selection/update | 🛑 Blocker | Revokes active binding outside feedback authority scope. |
| `20260824210000_upgrade_chimeway_registration_authority.exs` | 86-116 | Only one new uniqueness domain reconciled | 🛑 Blocker | Replacement index can make migration fail on valid old data. |
| `NotificationOpenQueue.swift` | 54-58, 100-108 | Duplicate evidence retained and drained | 🛑 Blocker | Later replay denial can replace allowed activation. |
| Phase-modified sources | — | Debt-marker scan | ℹ️ Info | No unreferenced `TBD`, `FIXME`, or `XXX` marker found. |

### Probe Execution

Step 7c: SKIPPED — no phase-declared or conventional `probe-*.sh` files found.

## Gaps Summary

This re-verification closes two prior OPEN-01 defects: permission-loss revocation now waits for host acknowledgement, and same-scope posture races converge. It cannot pass the phase because provider invalidation still trusts a non-authoritative token selector, the migration cannot handle every newly constrained old-data shape, and an offline duplicate tap can reverse the presentation of a valid protected open. These are objective, executable gaps; no conversational UAT is requested. No later roadmap phase explicitly owns any of them, so none is deferred.

---

_Verified: 2026-08-24T21:50:43Z_
_Verifier: the agent (gsd-verifier)_

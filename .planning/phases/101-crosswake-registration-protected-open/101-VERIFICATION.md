---
phase: 101-crosswake-registration-protected-open
verified: 2026-08-24T20:45:14Z
status: gaps_found
score: 3/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "A signed-in user can complete permission, APNs registration, and authenticated host binding; repeated observations, rotation, logout, revocation, and provider invalidation leave only the current binding usable."
    status: failed
    reason: "The current tree cannot safely upgrade an existing host, drops a rejected permission-loss revoke permanently, and permits duplicate active bindings when posture differs during a concurrent bind."
    artifacts:
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260602100000_create_chimeway_token_bindings.exs"
        issue: "Historical migration was rewritten to require new authority columns and revised indexes; no later forward migration/backfill exists."
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260603000000_create_chimeway_notification_open_intents.exs"
        issue: "Historical migration was rewritten with authority columns; an already-migrated host will not receive them."
      - path: "/Users/jon/projects/crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationRegistrationCoordinator.swift"
        issue: "permissionLossDelivered becomes true before the host acknowledgement, so a .rejected revoke cannot be retried."
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260602100000_create_chimeway_token_bindings.exs"
        issue: "All active unique indexes include mutable app_identity_posture although registry lookup omits it; distinct postures can create two active authority rows."
    missing:
      - "Restore released migrations and add a forward, additive migration with backfill, replacement indexes, and an upgrade-path integration test."
      - "Only mark permission loss delivered after .revoked or .staleNoop; add rejected-then-revoked retry coverage."
      - "Remove posture from active uniqueness identity, enforce the actual authority scope with a conflict-safe upsert/lock-retry, and add a concurrent differing-posture test."
---

# Phase 101: CrossWake Registration & Protected Open Verification Report

**Phase Goal:** A CrossWake host can bind APNs registrations and activate notification routes only when current host authority permits it.
**Verified:** 2026-08-24T20:45:14Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A signed-in user can complete permission, APNs registration, and authenticated host binding; repeated observations, rotation, logout, revocation, and provider invalidation leave only the current binding usable. | ✗ FAILED | Three observable OPEN-01 defects remain: historical migrations were rewritten without an upgrade migration; `recheckPermissionState()` suppresses retries after a `.rejected` host revoke; posture participates in active unique indexes but not the lookup scope, permitting two active rows under a posture race. |
| 2 | Malformed, absent, or unknown action and route configuration is rejected by a manifest-consistent default-deny policy. | ✓ VERIFIED | `Schema.validate_notification_open/1` normalizes only canonical actions; `Manifest.Validator` rejects malformed compiled policies; resolver accepts exact current action membership only. Focused Elixir policy/manifest/companion tests: 86 passing. |
| 3 | A notification tap contains only opaque evidence; offline taps queue safely and reconnect only activates a one-time intent after tenant, revision, expiry, session, manifest, and RouteGate reauthorization. | ✓ VERIFIED | Host `consume_intent/1` uses a predicate `update_all` and server-bound resolution; resolver evaluates current manifest then RouteGate with `activation_source: :notification`; Swift queue stores opaque evidence and routes only allowed outcomes to activation. Focused host tests: 16 passing; Swift queue/activation suites are included in the reported clean `swift test` run. |
| 4 | Replayed, expired, revoked, mismatched, logged-out, tenant-switched, or removed-route opens activate no fallback route and produce sanitized denial evidence. | ✓ VERIFIED | Resolver maps closed denial codes and sanitizes details; `ActivationCoordinator.handleProtectedNotificationOutcome` only activates `.allowed`; `ProtectedNotificationActivationTests` covers the denial matrix. Focused companion tests: 26 passing; single Swift registration suite also passes. |

**Score:** 3/4 truths verified (0 present, behavior-unverified)

## Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `packages/crosswake_chimeway/lib/crosswake/companions/chimeway/contracts.ex` | Server-bound `OpenResolution` | ✓ VERIFIED | Valid resolution requires bound route/action; resolver consumes before selection. |
| `packages/crosswake_chimeway/lib/crosswake/companions/chimeway/resolver.ex` | Exact policy and RouteGate authorization | ✓ VERIFIED | Uses host result, exact action list, then `RouteGate.evaluate/4` with notification source. |
| `lib/crosswake/policy/schema.ex`, `manifest/{builder,types,validator}.ex` | Canonical fail-closed notification-open policy | ✓ VERIFIED | Normalization, compile transfer, serialization, and structural validation are exercised by 60 tests. |
| `examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex` | Binding lifecycle and one-time intent CAS | ⚠️ INCOMPLETE | Substantive and exercised, but its durable binding path is unsafe for upgrades and posture races. |
| `examples/phoenix_host/lib/crosswake_example/chimeway/notification_open_intent.ex` | Scoped one-time intent record | ✓ VERIFIED | Used by the registry's conditional consume path and host integration tests. |
| `packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationRegistrationCoordinator.swift` | Permission/observation/binding lifecycle | ⚠️ INCOMPLETE | Correctly keeps APNs bytes transient, but loses a required permission-loss revoke after host `.rejected`. |
| `packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/{NotificationOpenQueue,NotificationOpenDelegate}.swift` | Opaque offline queue and host-consume seam | ✓ VERIFIED | File-backed bounded queue; no local route resolution or fallback activation. |
| `packages/crosswake_chimeway/lib/crosswake/companions/chimeway/{denial_codes,telemetry}.ex` | Closed sanitized outcome vocabulary | ✓ VERIFIED | Recursive bounded-scalar projection tested in companion suite. |
| `examples/phoenix_host/test/crosswake_example/chimeway/{registry_test,registry_notification_open_test,notification_registration_adapter_test}.exs` | Host lifecycle/open evidence | ⚠️ INCOMPLETE | 16 tests pass, but no prior-schema upgrade, rejected-then-retry, or differing-posture concurrency test exists. |
| `packages/crosswake-shell-core-ios/Tests/CrosswakeShellCoreTests/ProtectedNotificationActivationTests.swift` | Native terminal denial matrix | ✓ VERIFIED | Tests terminal handling without activation or fallback. |

## Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `Registry.consume_intent/1` | `Resolver.resolve/3` | Valid server-bound `OpenResolution` | ✓ WIRED | Resolver matches only host-supplied route/action after consumption. |
| `Resolver.resolve/3` | `RouteGate.evaluate/4` | `activation_source: :notification` | ✓ WIRED | Source and auth context are passed after exact policy check. |
| `NotificationOpenQueue.drain` | `NotificationOpenDelegate.consume` | Opaque evidence, terminal removal | ✓ WIRED | Allowed/denied are terminal; retry remains queued. |
| Allowed host outcome | `ActivationCoordinator.activateAllowedNotification` | Protected activation only | ✓ WIRED | Denials terminate in `handleProtectedNotificationOutcome`. |
| Native permission recheck | Authenticated adapter → `Registry.revoke_for_permission_loss/2` | Exact scoped callback | ⚠️ PARTIAL | The callback is wired, but retry semantics are broken before a rejected host response can be retried. |

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Phoenix registry | bindings/intents | Ecto `TokenBinding` and `NotificationOpenIntent` queries plus conditional updates | Yes, on fresh schema | ⚠️ UPGRADE-BROKEN |
| Resolver | route/action | Host-consumed `OpenResolution`, then current manifest | Yes | ✓ FLOWING |
| Native queue | evidence records | File-backed Codable queue and host delegate response | Yes | ✓ FLOWING |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Policy normalization and compiled validation | `MIX_ENV=test mix test test/crosswake/policy/schema_test.exs test/crosswake/manifest/builder_test.exs test/crosswake/manifest/validator_test.exs` | 60 tests, 0 failures | ✓ PASS |
| Resolver, denial, and telemetry contracts | `MIX_ENV=test mix test test/crosswake/companions/chimeway/resolver_test.exs test/crosswake/companions/chimeway/denial_codes_test.exs test/crosswake/companions/chimeway/telemetry_test.exs` (package) | 26 tests, 0 failures | ✓ PASS |
| Registry/open/adapter lifecycle | `MIX_ENV=test mix test test/crosswake_example/chimeway/registry_test.exs test/crosswake_example/chimeway/registry_notification_open_test.exs test/crosswake_example/chimeway/notification_registration_adapter_test.exs` (host) | 16 tests, 0 failures | ✓ PASS — incomplete coverage |
| Native registration state machine | `swift test --filter NotificationRegistrationTests` | 3 tests, 0 failures | ✓ PASS — incomplete coverage |
| Full final source tree | `MIX_ENV=test mix verify`; `swift test` | Reported current evidence: 1,482 ExUnit tests (73 excluded) and 48 Swift tests, 0 failures | ✓ PASS — does not exercise the three gaps |

## Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| OPEN-01 | 101-04, 101-06, 101-09 | Authenticated APNs binding lifecycle | ✗ BLOCKED | Upgrade safety, rejected-revoke retry, and posture-race uniqueness fail the lifecycle contract. |
| OPEN-02 | 101-02, 101-03, 101-09 | Closed manifest-consistent action policy | ✓ SATISFIED | Schema/manifest/resolver tests pass and code is wired. |
| OPEN-03 | 101-01, 101-03, 101-05, 101-07, 101-09 | Opaque queued, one-time, reauthorized protected open | ✓ SATISFIED | CAS host consume plus queue and protected activation paths are exercised. |
| OPEN-04 | 101-01, 101-05, 101-08, 101-09 | No-fallback sanitized stale/denied opens | ✓ SATISFIED | Closed resolver vocabulary and native terminal denial matrix are wired and tested. |

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `examples/phoenix_host/priv/repo/migrations/20260602100000_create_chimeway_token_bindings.exs` | 11-17, 53-105 | Historical migration rewritten; posture in active identity indexes | 🛑 Blocker | Existing databases miss required columns/indexes; concurrent differing postures may create two active bindings. |
| `examples/phoenix_host/priv/repo/migrations/20260603000000_create_chimeway_notification_open_intents.exs` | 9-12 | Historical migration rewritten | 🛑 Blocker | Existing databases miss current-authority intent columns. |
| `NotificationRegistrationCoordinator.swift` | 121-124 | Delivered marker set before host acknowledgement | 🛑 Blocker | Permission-loss revocation may be permanently skipped after a transient rejection. |
| Phase-modified sources | — | Debt-marker scan | ℹ️ Info | No unreferenced `TBD`, `FIXME`, or `XXX` markers found. |

## Gaps Summary

The protected-open path, policy closure, opaque queue, RouteGate wiring, denial sanitization, and no-fallback native handling are real and have executable coverage. Phase 101 nevertheless misses its core registration guarantee for existing hosts and under two lifecycle failure/race paths. The clean suites are insufficient evidence because they construct fresh schemas and cover only terminal permission-loss acknowledgements and same-posture binding cases.

No later roadmap phase explicitly owns migration repair, permission-loss retry semantics, or active-binding uniqueness. These are not deferred Phase 102 work.

---

_Verified: 2026-08-24T20:45:14Z_
_Verifier: the agent (gsd-verifier)_

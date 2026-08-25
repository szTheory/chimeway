---
phase: 101-crosswake-registration-protected-open
verified: 2026-08-25T19:28:33Z
status: gaps_found
score: 2/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/4
  gaps_closed:
    - "Every legacy issued intent that migration reconciliation revokes has append-only sanitized denial evidence explaining that terminal transition."
  gaps_remaining: []
  regressions:
    - "A delayed logout selector ignores the authenticated session version and can revoke a newer binding with the same session reference."
    - "Deleting a notification-open intent cascade-deletes its append-only denial history."
gaps:
  - truth: "A signed-in user can complete permission, APNs registration, and authenticated host binding; repeated observations, rotation, logout, revocation, and provider invalidation leave only the current binding usable."
    status: failed
    reason: "Logout validates session_version but its selector and CAS update omit it. A delayed v1 logout can select and revoke an active v2 replacement having the same subject, tenant, and session_ref."
    artifacts:
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex"
        issue: "Lines 538-570 filter by subject_ref, org_ref, session_ref, scope, and state, but never session_version."
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registry_test.exs"
        issue: "No regression creates a v2 binding then submits a stale v1 logout."
    missing:
      - "Include ctx.session_version in the initial logout query and in the conditional update predicate."
      - "Add an executable stale-logout regression proving the newer binding remains active."
  - truth: "Replayed, expired, revoked, mismatched, logged-out, tenant-switched, or removed-route opens activate no fallback route and produce sanitized explainable denial evidence."
    status: failed
    reason: "The append-only notification-open event relation has an on_delete: :delete_all foreign key. Any deletion of its parent intent erases issued, consumed, and reconciliation_revoked evidence, so denials are not durably explainable."
    artifacts:
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260603000000_create_chimeway_notification_open_intents.exs"
        issue: "Line 23 declares the event foreign key with on_delete: :delete_all."
    missing:
      - "Add a forward migration that prevents intent deletion from cascade-deleting notification-open lifecycle events (and make intent deletion restrictive or otherwise auditable)."
      - "Add a migration/runtime regression proving an intent deletion cannot erase its event history."
---

# Phase 101: CrossWake Registration & Protected Open Verification Report

**Phase Goal:** A CrossWake host can bind APNs registrations and activate notification routes only when current host authority permits it.
**Verified:** 2026-08-25T19:28:33Z
**Status:** gaps_found
**Re-verification:** Yes — after Plan 101-19

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A signed-in user can complete permission, APNs registration, and authenticated host binding; repeated observations, rotation, logout, revocation, and provider invalidation leave only the current binding usable. | ✗ FAILED | `Registry.revoke_for_logout/2` validates a version but omits it from both selection and update; stale logout can revoke a newer authority. |
| 2 | Malformed, absent, or unknown action and route configuration is rejected by a manifest-consistent default-deny policy. | ✓ VERIFIED | Schema, route, builder, types, validator, and resolver carry the closed actions map and exact membership. The focused policy/manifest command passed 73 tests. |
| 3 | A notification tap contains only opaque evidence; offline taps queue safely and reconnect only activates a one-time intent after tenant, revision, expiry, session, manifest, and RouteGate reauthorization. | ✓ VERIFIED | Opaque Swift queue persistence, host predicate-CAS, current binding checks, exact manifest membership, and notification-source RouteGate wiring are exercised by passing host/companion/Swift tests. |
| 4 | Replayed, expired, revoked, mismatched, logged-out, tenant-switched, or removed-route opens activate no fallback route and produce sanitized explainable denial evidence. | ✗ FAILED | Runtime denials are terminal and Plan 101-19 now appends reconciliation evidence, but the event FK cascade makes that lifecycle evidence deletable. |

**Score:** 2/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex` | Exact-current binding lifecycle and atomic protected-open consume | ⚠️ INCOMPLETE | Consume predicate and events are substantive/wired; logout lacks `session_version` in selection/CAS. |
| `examples/phoenix_host/priv/repo/migrations/20260825190000_backfill_chimeway_notification_open_intent_scope.exs` | Forward-only scope reconciliation with durable denial evidence | ✓ VERIFIED | Captures exact terminal IDs after scope backfill, inserts one `reconciliation_revoked` event per ID with `{}`, then revokes exactly that set. Upgrade test passed. |
| `examples/phoenix_host/priv/repo/migrations/20260603000000_create_chimeway_notification_open_intents.exs` | Durable append-only protected-open evidence | ✗ STUB FOR DURABILITY | The event table exists but parent deletion cascades to all history. |
| `packages/crosswake_chimeway/lib/crosswake/companions/chimeway/resolver.ex` | Consume-first, exact-policy notification authorization | ✓ VERIFIED | Host resolution supplies route/action; resolver checks current route/actions then calls `RouteGate.evaluate/4` with `activation_source: :notification`. |
| `packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationOpenQueue.swift` | Bounded opaque reconnect queue | ✓ VERIFIED | Tests prove bounded, first-wins opaque queue and terminal outcome removal. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `Registry.consume_intent/1` | `Resolver.resolve/3` | Server-bound `OpenResolution.route_id/action_ref` after host CAS | ✓ WIRED | Resolver consumes before manifest selection and never selects route/action from client evidence. |
| `Resolver.resolve/3` | `RouteGate.evaluate/4` | Exact current action membership and `activation_source: :notification` | ✓ WIRED | `resolver.ex:63-67`; only reached after valid host resolution and membership check. |
| Scope reconciliation migration | `NotificationOpenIntentEvent` | Captured terminal ID set to sanitized `reconciliation_revoked` rows | ✓ WIRED | `insert_all` at migration lines 106-117; released-boundary regression proves one event for each forced revocation. |
| `revoke_for_logout/2` | current session-version binding | Version-qualified selector/CAS | ✗ NOT WIRED | `ctx.session_version` is validated but not used by the selector or `update_all`. |
| `NotificationOpenIntent` | durable lifecycle evidence | Event FK retention | ✗ NOT WIRED | Initial migration intentionally cascades delete, disconnecting deleted intents from their audit history. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Host consume path | intent authority and consumed event | Ecto correlated predicate-CAS | Yes | ✓ FLOWING |
| Reconciliation migration | binding-derived scope and denial event | exact active-binding SQL plus captured IDs | Yes | ✓ FLOWING |
| Native queue | opaque `openRef` evidence | persisted queue and host closed outcome | Yes | ✓ FLOWING |
| Logout lifecycle | binding version | validated context → selector/update | No | ✗ DISCONNECTED — version is dropped after validation |
| Open-event lifecycle | durable evidence | parent deletion behavior | No | ✗ HOLLOW — cascade can remove all records |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Binding lifecycle, metadata drop, reconciliation scope/event evidence, and protected consume | `cd examples/phoenix_host && MIX_ENV=test mix test test/crosswake_example/chimeway/{registration_authority_migration_upgrade_test,registry_test,notification_open_intent_test,registry_notification_open_test,notification_registration_adapter_test}.exs --seed 0` | 29 tests, 0 failures | ✓ PASS |
| Closed authoring and compiled manifest policy | `cd crosswake && mix test test/crosswake/policy/{schema_test,route_test}.exs test/crosswake/manifest/{builder_test,validator_test}.exs --seed 0` | 73 tests, 0 failures | ✓ PASS |
| Resolver denial/redaction/telemetry | `cd packages/crosswake_chimeway && mix test test/crosswake/companions/chimeway/{resolver_test,denial_codes_test,redaction_test,telemetry_test}.exs --seed 0` | 33 tests, 0 failures | ✓ PASS |
| Native registration, opaque queue, protected activation | `cd packages/crosswake-shell-core-ios && swift test --filter 'NotificationRegistrationTests|NotificationOpenQueueTests|ProtectedNotificationActivationTests'` | 11 tests, 0 failures | ✓ PASS |
| Delayed v1 logout cannot revoke a v2 binding | No named regression exists; static selector inspection | Version omitted | ✗ FAIL |
| Intent deletion retains lifecycle events | No named regression exists; migration inspection | `on_delete: :delete_all` | ✗ FAIL |

### Probe Execution

Step 7c: SKIPPED — no phase-declared or conventional `scripts/*/tests/probe-*.sh` probes exist.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| OPEN-01 | 101-04, 06, 09-12, 14-15, 17 | Permission → APNs observation → authenticated binding, rotation, logout/session revocation, and provider invalidation | ✗ BLOCKED | Delayed logout is not exact-session-version authority, allowing revocation of a current replacement binding. |
| OPEN-02 | 101-02, 03, 09 | Manifest-consistent closed action allowlist/default deny | ✓ SATISFIED | 73 focused policy/manifest tests plus companion resolver tests pass. |
| OPEN-03 | 101-01, 03, 05, 07, 09, 13-14, 16, 18 | Opaque offline evidence, exact authority recheck, one-time consume | ✓ SATISFIED | Queue, host CAS, resolver, and released-boundary matched-scope/replay evidence pass. |
| OPEN-04 | 101-01, 05, 08, 09, 19 | Terminal no-fallback stale denial with sanitized explainability | ✗ BLOCKED | Event production is correct, but `on_delete: :delete_all` permits durable denial evidence loss. |

All four IDs declared across all 19 PLAN frontmatters are accounted for. `REQUIREMENTS.md` maps no additional Phase 101 IDs, so no requirements are orphaned.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `registry.ex` | 538-570 | Authenticated version validated then discarded before lifecycle mutation | 🛑 Blocker | A stale authority action can revoke a current binding. |
| `20260603000000_create_chimeway_notification_open_intents.exs` | 23 | Cascade deletion of append-only lifecycle evidence | 🛑 Blocker | A denied-open explanation can disappear. |
| `ProtectedNotificationActivationTests.swift` | 8-19 | Enumeration omits `routeActionRemoved` | ⚠️ Warning | Current generic denial branch is terminal, but the claimed exhaustive test does not cover that enum case. |
| Phase-modified source set | — | debt-marker scan | ℹ️ Info | No unreferenced `TBD`, `FIXME`, or `XXX` markers found. |

### Gaps Summary

Plan 101-19 closes the prior migration-evidence blocker: the current migration atomically records one sanitized reconciliation event for each forced legacy revocation, and the released-boundary test proves it. That does not achieve the phase goal: the logout mutation remains vulnerable to a stale session version, and the audit relation allows deletion of all evidence. Neither defect is explicitly assigned to Phase 102 or 103, so neither is deferred.

---

_Verified: 2026-08-25T19:28:33Z_
_Verifier: the agent (gsd-verifier)_

---
phase: 101-crosswake-registration-protected-open
verified: 2026-08-25T18:55:00Z
status: gaps_found
score: 3/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/4
  gaps_closed:
    - "Authenticated registration persists caller metadata as exactly an empty map in current bindings and append-only binding audit events."
    - "A matched historical issued intent receives its exact active binding scope and can consume once under current authority."
  gaps_remaining:
    - "Every legacy issued intent that migration reconciliation revokes has append-only sanitized denial evidence explaining that terminal transition."
  regressions: []
gaps:
  - truth: "Replayed, expired, revoked, mismatched, logged-out, tenant-switched, or removed-route opens activate no fallback route and produce sanitized explainable denial evidence."
    status: failed
    reason: "The forward reconciliation migration changes unreconcilable issued intents to revoked but inserts no NotificationOpenIntentEvent. A legacy intent therefore has an issued event followed by a changed current row with no timestamped, sanitized explanation of the migration-driven denial."
    artifacts:
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260825190000_backfill_chimeway_notification_open_intent_scope.exs"
        issue: "Lines 63-91 execute only UPDATE; no append-only reconciliation event is inserted."
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs"
        issue: "Asserts revoked state for unmatched/inactive intents but does not assert one reconciliation event per forced revocation."
    missing:
      - "In the same migration transaction, insert one sanitized append-only event for each exact row selected by the terminal NOT EXISTS predicate, with a stable reconciliation-denial type and empty/static details."
      - "Add an upgrade regression proving each forced-revoked intent has exactly one such event and matched intents do not receive it."
---

# Phase 101: CrossWake Registration & Protected Open Verification Report

**Phase Goal:** A CrossWake host can bind APNs registrations and activate notification routes only when current host authority permits it.
**Verified:** 2026-08-25T18:55:00Z
**Status:** gaps_found
**Re-verification:** Yes — after Plans 101-17 and 101-18

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A signed-in user can complete permission, APNs registration, and authenticated host binding; repeated observations, rotation, logout, revocation, and provider invalidation leave only the current binding usable. | ✓ VERIFIED | `MetadataSanitizer.sanitize/1` now always returns `%{}` and is wired through `TokenBinding` and `TokenBindingEvent`; 29 focused host tests pass, including public binding/audit persistence and lifecycle cases. |
| 2 | Malformed, absent, or unknown action and route configuration is rejected by a manifest-consistent default-deny policy. | ✓ VERIFIED | The policy schema, builder, manifest validator, and exact-membership resolver are substantive and wired; 73 focused root tests and 33 companion tests pass. |
| 3 | A notification tap contains only opaque evidence; offline taps queue safely and reconnect only activates a one-time intent after tenant, revision, expiry, session, manifest, and RouteGate reauthorization. | ✓ VERIFIED | The new forward migration derives scope only from an exact active binding; the released-boundary integration test consumes the matched intent once then receives replay. Queue and protected-activation tests pass. |
| 4 | Replayed, expired, revoked, mismatched, logged-out, tenant-switched, or removed-route opens activate no fallback route and produce sanitized explainable denial evidence. | ✗ FAILED | Runtime replay/denial paths are terminal and sanitized, but migration-revoked legacy intents have no append-only denial event. Their terminal state is consequently not explainable from durable lifecycle evidence. |

**Score:** 3/4 truths verified (0 present, behavior-unverified)

### Plan Must-Have Coverage

| Plans | Contract | Status | Evidence |
| --- | --- | --- | --- |
| 101-01, 03, 05, 07-09, 13-14, 16 | Opaque one-time protected open, closed policy, bounded queue, consume-first/RouteGate/no-fallback, and sanitized evidence | ✓ VERIFIED | Host, companion, and Swift focused suites pass; current code has no local activation route in denied outcomes. |
| 101-02-03, 09 | One closed compiled notification-open representation and exact action membership | ✓ VERIFIED | 73 policy/manifest tests plus resolver tests pass. |
| 101-04, 06, 10-12, 14-15, 17 | Separate permission/observation/binding authority, exact lifecycle CAS, upgrade uniqueness, no raw token or caller metadata retention | ✓ VERIFIED | Exact-current binding predicates and `%{}` durable metadata projection are wired and covered by the 29 host tests and 11 Swift tests. |
| 101-18 | Exact-binding scope backfill and fail-closed reconciliation of legacy issued intents | ✗ FAILED | Scope derivation and matched consumption are correct, but the reconciliation branch records no append-only reason for forced revocations. |

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `examples/phoenix_host/lib/crosswake_example/chimeway/metadata_sanitizer.ex` | Drop-all caller metadata at registration, audit, and open-intent persistence boundaries | ✓ VERIFIED | Both public functions are exact `%{}` projections; `TokenBinding`, `TokenBindingEvent`, and `NotificationOpenIntent` call them before persistence. |
| `examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex` | Current binding lifecycle and atomically authorized one-time consume | ✓ VERIFIED | Ecto transaction inserts issued/consumed audit events; consume query includes binding, tenant, subject, installation, scope, session, state, and expiry predicates. |
| `examples/phoenix_host/priv/repo/migrations/20260825190000_backfill_chimeway_notification_open_intent_scope.exs` | Forward-only exact scope reconciliation with explainable terminal denial | ⚠️ INCOMPLETE | Scope backfill and terminal revocation are substantive, but the revocation UPDATE is not wired to `chimeway_notification_open_intent_events`. |
| `packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationRegistrationCoordinator.swift` and `NotificationOpenQueue.swift` | Explicit registration state and opaque reconnect drain | ✓ VERIFIED | Coordinator retains only opaque command data and retries rejected revocation acknowledgement; queue tests prove bounded opaque first-wins drain. |
| Policy, manifest, resolver, denial-code, telemetry modules | Default-deny route/action authorization and sanitized outcome vocabulary | ✓ VERIFIED | Substantive, cross-module wiring is exercised by focused tests. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `Registry.bind_or_rotate/3` | `TokenBinding` / `TokenBindingEvent` | changesets plus exact-empty metadata projection | ✓ WIRED | Binding and append-only audit rows sanitize again at their changeset boundaries. |
| `NotificationOpenIntent.changeset/2` | `MetadataSanitizer.sanitize_notification_open/1` | caller metadata before insert | ✓ WIRED | Exact empty projection is covered by changeset and persistence regressions. |
| `Registry.consume_intent/1` | exact active binding / `NotificationOpenIntentEvent` | one predicate-CAS, then consumed event | ✓ WIRED | Lines 1354-1380 enforce current authority and append the consumed event only for the sole winner. |
| `20260825190000_backfill_chimeway_notification_open_intent_scope.exs` | `NotificationOpenIntentEvent` | migration-driven terminal revocation evidence | ✗ NOT WIRED | Lines 63-91 update state but contain neither an INSERT nor an event-table reference. |
| `NotificationOpenQueue` | `ActivationCoordinator.handleProtectedNotificationOutcome` | allowed result activates; denial is terminal | ✓ WIRED | Swift tests exercise one allowed activation and all denial/no-fallback branches. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Phoenix registry | bindings, intent authority, lifecycle events | Ecto transactions and conditional updates | Yes | ✓ FLOWING — typed host facts, never caller metadata, populate authority records. |
| Scope reconciliation migration | `intent.scope` and terminal state | correlated exact active-binding SQL | Partially | ⚠️ PARTIAL — authoritative scope/state flows, but a terminal reconciliation has no corresponding durable event. |
| Native queue | stored opaque evidence | persisted `openRef` items and host consumer outcome | Yes | ✓ FLOWING — no route, URL, identity, or token is serialized. |
| Resolver/telemetry | closed result and bounded metadata | current manifest and RouteGate result | Yes | ✓ FLOWING — tests exercise allow and denial classifications. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Binding lifecycle, exact metadata drop, migration scope backfill, one-time host consume | `cd examples/phoenix_host && MIX_ENV=test mix test test/crosswake_example/chimeway/{registration_authority_migration_upgrade_test,registry_test,notification_open_intent_test,registry_notification_open_test,notification_registration_adapter_test}.exs --seed 0` | 29 tests, 0 failures | ✓ PASS |
| Closed authoring and compiled manifest policy | `cd crosswake && mix test test/crosswake/policy/{schema_test,route_test}.exs test/crosswake/manifest/{builder_test,validator_test}.exs --seed 0` | 73 tests, 0 failures | ✓ PASS |
| Resolver denial/redaction/telemetry | `cd packages/crosswake_chimeway && mix test test/crosswake/companions/chimeway/{resolver_test,denial_codes_test,redaction_test,telemetry_test}.exs --seed 0` | 33 tests, 0 failures | ✓ PASS |
| Native registration, opaque queue, protected activation | `cd packages/crosswake-shell-core-ios && swift test --filter 'NotificationRegistrationTests|NotificationOpenQueueTests|ProtectedNotificationActivationTests'` | 11 tests, 0 failures | ✓ PASS |
| Migration-revoked intent has reconciliation event | static inspection of migration and upgrade test | No migration INSERT/event-table reference; test asserts only state | ✗ FAIL |

### Probe Execution

Step 7c: SKIPPED — no phase-declared or conventional `scripts/*/tests/probe-*.sh` probes exist.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| OPEN-01 | 101-04, 06, 09-12, 14-15, 17 | Permission → APNs observation → authenticated binding, rotation, revocation, and provider invalidation | ✓ SATISFIED | Exact scoped lifecycle tests pass; current/displaced/audit metadata remains `%{}`. |
| OPEN-02 | 101-02, 03, 09 | Manifest-consistent action allowlist that fails closed | ✓ SATISFIED | Policy/manifest/resolver suites pass. |
| OPEN-03 | 101-01, 03, 05, 07, 09, 13-14, 16, 18 | Opaque offline tap, exact authority recheck, and one-time consumption | ✓ SATISFIED | Queue, resolver, host CAS, and the new matched-legacy scope/consume proof pass. |
| OPEN-04 | 101-01, 05, 08, 09 | Stale/denied opens have no fallback and emit sanitized explainable evidence | ✗ BLOCKED | No-fallback and runtime sanitization pass, but a migration-forced revocation lacks append-only explainability. |

All four requirement IDs declared in the 18 PLAN frontmatters are accounted for. `REQUIREMENTS.md` assigns no additional requirement to Phase 101, so there are no orphaned Phase 101 requirements.

### Code Review Disposition

| Finding | Verdict | Evidence |
| --- | --- | --- |
| WR-01: reconciled intent revocations have no durable denial event | ✗ CONFIRMED — BLOCKER | Migration lines 63-91 only update state; normal issuance and consumption append events at `registry.ex:1302-1312` and `1372-1380`. This violates the project requirement that notification decisions be explainable. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `20260825190000_backfill_chimeway_notification_open_intent_scope.exs` | 63-91 | terminal lifecycle update without append-only evidence | 🛑 Blocker | An operator cannot distinguish a deliberate migration denial from an unexplained revoked row. |
| Phase-modified source set | — | debt-marker scan | ℹ️ Info | No unreferenced `TBD`, `FIXME`, or `XXX` markers found. The two “not available” strings are bounded runtime denial copy, not stubs. |

### Gaps Summary

Plans 101-17 and 101-18 close the previous blockers: generic registration/audit metadata is now exactly empty, and matched legacy intents obtain binding-derived scope and consume once. However, 101-18 introduces a fail-closed terminal transition without the lifecycle evidence that makes it explainable. The needed repair is a small forward migration addition plus an upgrade regression; it is not deferred to Phase 102 or 103.

---

_Verified: 2026-08-25T18:55:00Z_
_Verifier: the agent (gsd-verifier)_

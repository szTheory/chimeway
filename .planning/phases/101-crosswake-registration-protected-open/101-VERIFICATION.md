---
phase: 101-crosswake-registration-protected-open
verified: 2026-08-25T20:05:28Z
status: passed
score: 4/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/4
  gaps_closed:
    - "Logout authority is qualified by the exact authenticated session version during selection and conditional mutation."
    - "Event-bearing notification-open intents retain their append-only lifecycle history after forward upgrade."
  gaps_remaining: []
  regressions: []
---

# Phase 101: CrossWake Registration & Protected Open Verification Report

**Phase Goal:** A CrossWake host can bind APNs registrations and activate notification routes only when current host authority permits it.
**Verified:** 2026-08-25T20:05:28Z
**Status:** passed
**Re-verification:** Yes — after Plan 101-20 gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A signed-in user can complete permission, APNs registration, and authenticated host binding; repeated observations, rotation, logout, revocation, and provider invalidation leave only the current binding usable. | ✓ VERIFIED | The live registry qualifies logout selection and its predicate-CAS by `ctx.session_version`; the named stale-v1/v2 regression proves only v1 is revoked/audited. Exact provider scope and permission-loss regressions are included in the 24-test host suite. |
| 2 | Malformed, absent, or unknown action and route configuration is rejected by a manifest-consistent default-deny policy. | ✓ VERIFIED | `Resolver.resolve/3` consumes host state before route selection, requires a nonempty exact action list, and calls `RouteGate.evaluate/4` with `activation_source: :notification`. Policy/manifest suite: 73 tests, 0 failures. |
| 3 | A notification tap contains only opaque evidence; offline taps queue safely and reconnect only activates a one-time intent after tenant, revision, expiry, session, manifest, and RouteGate reauthorization. | ✓ VERIFIED | `NotificationOpenQueue` persists bounded opaque `openRef` evidence and drains solely through its protected host/delegate path; host predicate-CAS and resolver authorization are covered by the host, resolver, and Swift tests. |
| 4 | Replayed, expired, revoked, mismatched, logged-out, tenant-switched, or removed-route opens activate no fallback route and produce sanitized denial evidence. | ✓ VERIFIED | Resolver denial branches are terminal; Swift protected-activation tests prove denied outcomes do not activate or fall back. The new SQLite `BEFORE DELETE` trigger prevents an event-bearing parent deletion from erasing the retained sanitized history. |

**Score:** 4/4 truths verified (0 present, behavior-unverified)

### Plan Must-Have Coverage

Every PLAN frontmatter requirement/truth was checked against the live implementation and the focused commands below. Flagged `assumptions` are planning metadata, not additional delivery truths.

| Plans | Must-have area | Status | Live evidence |
| --- | --- | --- | --- |
| 101-01, 05, 09 | Server-bound, one-winner consume; replay/stale opens deny without activation. | ✓ VERIFIED | Registry consume predicate-CAS, resolver consume-first ordering, and protected-activation tests. |
| 101-02, 03 | Closed authoring/compiled action representation, malformed/unknown default deny, exact membership. | ✓ VERIFIED | `policy/{schema,route}` and `manifest/{builder,validator}`: 73/73. |
| 101-04, 06, 10–12, 14–15, 17, 20 | Permission/observation/binding separation; exact scoped lifecycle authority, session/version isolation, provider invalidation, and durable metadata redaction. | ✓ VERIFIED | Live Ecto selectors, changesets, guards, migrations, native delegate transitions, and 24/24 focused host tests. Plan 20's stale-v1 logout regression passes. |
| 101-07, 13, 16, 18 | Opaque bounded/deduplicated queue, reconnect consumption, drop-all metadata, and released-boundary scope reconciliation. | ✓ VERIFIED | `NotificationOpenQueue` queue/drain/first-wins behavior and Swift tests; host migration/intent tests pass. |
| 101-08, 19, 20 | Stable sanitized terminal evidence, reconciliation evidence, and append-only history retention. | ✓ VERIFIED | Resolver/redaction/telemetry suite: 33/33; migration adds the named retention guard and both migration/runtime deletion regressions pass. |

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex` | Exact-current binding lifecycle and protected intent consumption | ✓ VERIFIED | Substantive, used by the host adapter/tests, and its logout query plus `update_all` both bind `ctx.session_version`. |
| `examples/phoenix_host/priv/repo/migrations/20260825200000_protect_chimeway_notification_open_intent_history.exs` | Forward-only restrictive history guard | ✓ VERIFIED | Substantive named `BEFORE DELETE` trigger; released-boundary test proves installation, rejection, retention, and one-step rollback. Historical migration remains unchanged. |
| `examples/phoenix_host/test/crosswake_example/chimeway/registry_test.exs` | Stale logout authority regression | ✓ VERIFIED | Named test creates same-session v1/v2 rows and proves only v1 changes/audits. |
| `examples/phoenix_host/test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs` | Upgrade/rollback retention regression | ✓ VERIFIED | Tests direct deletion rejection and byte-for-byte parent/event preservation across the migration boundary. |
| `examples/phoenix_host/test/crosswake_example/chimeway/registry_notification_open_test.exs` | Runtime event-history deletion regression | ✓ VERIFIED | Ordinary `Repo.delete!` fails and both parent and issued event remain queryable. |
| `packages/crosswake_chimeway/lib/crosswake/companions/chimeway/resolver.ex` | Consume-first, exact-policy notification authorization | ✓ VERIFIED | Wired to host consumer, exact action membership, and notification-source `RouteGate`. |
| `packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationOpenQueue.swift` | Bounded opaque reconnect queue | ✓ VERIFIED | Data flows from persisted opaque evidence to the host delegate only; no local route resolution/activation path exists. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `Registry.revoke_for_logout/2` context | TokenBinding selection and CAS mutation | Same exact `ctx.session_version` in both predicates | ✓ WIRED | `registry.ex` lines 533–570; named v1/v2 regression passes. |
| Notification-open parent delete | Intent-event history | Forward migration's named restrictive SQLite trigger | ✓ WIRED | Trigger checks `open_intent_id = OLD.id` before delete and aborts; direct SQL and Ecto paths are tested. |
| Host `consume_intent` | `Resolver.resolve/3` | Server-bound `OpenResolution` route/action | ✓ WIRED | Resolver consumes before manifest lookup and never trusts client route/action for selection. |
| `Resolver.resolve/3` | `RouteGate.evaluate/4` | Exact current action membership and `activation_source: :notification` | ✓ WIRED | `resolver.ex` lines 49–69; resolver suite passes. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Host protected-open path | Intent authority/state | Ecto correlated predicate-CAS plus current active binding | Yes | ✓ FLOWING |
| Logout lifecycle | `session_version` | Validated authenticated context → selection and conditional mutation | Yes | ✓ FLOWING |
| History-retention migration | Existing parent/event rows | Forward Ecto migration trigger over the released event table | Yes | ✓ FLOWING |
| Native queue | Opaque `openRef` evidence | Persisted bounded queue → host delegate → protected activation | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Exact-version logout; history retention across runtime and upgrade/rollback | `cd examples/phoenix_host && MIX_ENV=test mix test test/crosswake_example/chimeway/{registry_test,registration_authority_migration_upgrade_test,registry_notification_open_test}.exs --seed 0` | 24 tests, 0 failures; released migration diff check passed | ✓ PASS |
| Closed authoring and compiled manifest policy | `cd crosswake && mix test test/crosswake/policy/{schema_test,route_test}.exs test/crosswake/manifest/{builder_test,validator_test}.exs --seed 0` | 73 tests, 0 failures | ✓ PASS |
| Resolver denial/redaction/telemetry | `cd packages/crosswake_chimeway && mix test test/crosswake/companions/chimeway/{resolver_test,denial_codes_test,redaction_test,telemetry_test}.exs --seed 0` | 33 tests, 0 failures | ✓ PASS |
| Native permission, opaque queue, and protected activation | `cd packages/crosswake-shell-core-ios && swift test --filter 'NotificationRegistrationTests|NotificationOpenQueueTests|ProtectedNotificationActivationTests'` | 11 tests, 0 failures | ✓ PASS |
| Configured regression gate | Crosswake root suite and Swift suite (fresh orchestrator evidence) | 1482 Elixir tests and 50 Swift tests, 0 failures | ✓ PASS |

### Probe Execution

Step 7c: SKIPPED — no phase-declared or conventional `scripts/*/tests/probe-*.sh` probes exist.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| OPEN-01 | 101-04, 06, 09–12, 14–15, 17, 20 | Permission → APNs observation → authenticated binding, rotation, logout/session revocation, and provider invalidation | ✓ SATISFIED | Exact host authority is maintained through current selectors/CAS; the repaired stale-version logout regression and focused host suite pass. |
| OPEN-02 | 101-02, 03, 09 | Manifest-consistent closed action allowlist/default deny | ✓ SATISFIED | Exact schema/manifest/resolver policy checks; 73 focused tests pass. |
| OPEN-03 | 101-01, 03, 05, 07, 09, 13–14, 16, 18 | Opaque offline evidence, exact authority recheck, one-time consume | ✓ SATISFIED | Queue, host CAS, resolver, and release-boundary regression evidence pass. |
| OPEN-04 | 101-01, 05, 08–09, 19–20 | Terminal no-fallback stale denial with sanitized explainable evidence | ✓ SATISFIED | Terminal resolver/native behavior plus retained append-only event history are tested. |

All four IDs declared in PLAN frontmatter are accounted for. `REQUIREMENTS.md` maps no additional Phase 101 IDs, so no requirements are orphaned.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `examples/phoenix_host/README.md` | 127–132 | Provider-feedback Oban recipe calls a nonexistent contract constructor and supplies the wrong scope shape. | ⚠️ Warning | A host copying this optional documentation recipe cannot process provider feedback; the actual registry/provider boundary is tested and correct. This is tracked advisory documentation debt, not a failure of the implemented phase authority goal. |
| Phase-modified source set | — | Debt-marker scan | ℹ️ Info | No unreferenced `TBD`, `FIXME`, or `XXX` markers found. |

### Review Finding Assessment

`101-REVIEW.md`'s WR-01 is real and should remain tracked: the README must call `Redaction.feedback_from_provider_attrs/1` and resolve the complete authenticated registry options. It does **not** block the phase goal or OPEN-01 acceptance because the authoritative `Registry.apply_provider_feedback/2` implementation and its exact-scope/provider invalidation tests are live and passing; the defect is an optional host-owned recipe, not missing or unsafe runtime authority wiring. Repair it as a follow-up documentation/integration task with a compiling recipe test.

### Gaps Summary

No goal-blocking gaps remain. Plan 101-20 closed both prior blockers with executable evidence: delayed logout cannot affect a newer session version, and deleting an event-bearing intent cannot erase its lifecycle evidence.

---

_Verified: 2026-08-25T20:05:28Z_
_Verifier: the agent (gsd-verifier)_

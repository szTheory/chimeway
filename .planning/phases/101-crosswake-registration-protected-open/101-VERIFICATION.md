---
phase: 101-crosswake-registration-protected-open
verified: 2026-08-25T18:15:00Z
status: gaps_found
score: 2/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/4
  gaps_closed:
    - "Installation-scoped bindings reject session authority and session lifecycle operations select only subject-session bindings."
    - "Notification-open caller metadata is projected to an empty durable map."
  gaps_remaining:
    - "A matched legacy issued intent is not given its binding's scope by the forward authority migration, so it cannot pass current consumption authorization."
    - "Token-binding and audit metadata still use a finite forbidden-key blocklist and durably retain arbitrary caller-controlled values."
  regressions: []
gaps:
  - truth: "A signed-in user can complete permission, APNs registration, and authenticated host binding; repeated observations, rotation, logout, revocation, and provider invalidation leave only the current binding usable."
    status: failed
    reason: "The binding and audit durable metadata boundary is a finite exact-name blocklist. Arbitrary or camelCase token, credential, PII, and provider-body fields flow through token-binding and audit persistence, contradicting the phase's D-04/OPEN-01 durable-evidence contract."
    artifacts:
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/metadata_sanitizer.ex"
        issue: "sanitize/1 preserves every key not in a small literal list, recursively."
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/token_binding.ex"
        issue: "TokenBinding changesets persist the unsafe generic sanitizer projection."
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex"
        issue: "Evidence normalization, binding construction, and audit-event construction all reuse the unsafe generic projection."
    missing:
      - "Replace generic binding/audit metadata persistence with a narrow recursively validated allowlist or an empty projection, and add adversarial persistence regressions for camelCase token, authorization/PII, provider-body, and nested unknown values."
  - truth: "A notification tap contains only opaque evidence; offline taps queue safely and reconnect only activates a one-time intent after tenant, revision, expiry, session, manifest, and RouteGate reauthorization."
    status: failed
    reason: "The forward authority migration backfills tenant, subject, and session authority for matched historical intents but omits scope. Current consumption requires intent.scope to equal the authenticated scope, making an otherwise valid legacy issued intent permanently ineligible."
    artifacts:
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260824210000_upgrade_chimeway_registration_authority.exs"
        issue: "The backfill UPDATE omits scope = binding.subject_scope."
      - path: "/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex"
        issue: "consume_current_intent/3 requires i.scope == authenticated scope, so the omitted historical value cannot authorize."
    missing:
      - "Add a new forward migration that derives scope from the exact bound row for matched issued intents (terminally revoke rows that cannot be made authoritative), plus an upgrade regression that consumes an unexpired matched legacy intent."
---

# Phase 101: CrossWake Registration & Protected Open Verification Report

**Phase Goal:** A CrossWake host can bind APNs registrations and activate notification routes only when current host authority permits it.
**Verified:** 2026-08-25T18:15:00Z
**Status:** gaps_found
**Re-verification:** Yes — after Plans 101-15 and 101-16

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A signed-in user can complete permission, APNs registration, and authenticated host binding; repeated observations, rotation, logout, revocation, and provider invalidation leave only the current binding usable. | ✗ FAILED | 101-15 correctly separates installation/session authority, but the active registration evidence boundary still durably retains arbitrary sensitive caller metadata through the generic blocklist. This fails the phase's D-04/OPEN-01 durable-evidence must-have. |
| 2 | Malformed, absent, or unknown action and route configuration is rejected by a manifest-consistent default-deny policy. | ✓ VERIFIED | Policy schema, manifest builder/validator, and resolver exact-membership suites pass: 73 focused root tests and 33 companion tests. |
| 3 | A notification tap contains only opaque evidence; offline taps queue safely and reconnect only activates a one-time intent after tenant, revision, expiry, session, manifest, and RouteGate reauthorization. | ✗ FAILED | New intent issuance correctly drops caller metadata, but a matched pre-upgrade issued intent has NULL scope because the forward migration omitted that backfill. The current CAS requires a matching scope, so a valid legacy tap cannot activate. |
| 4 | Replayed, expired, revoked, mismatched, logged-out, tenant-switched, or removed-route opens activate no fallback route and produce sanitized denial evidence. | ✓ VERIFIED | Atomic consume-before-resolve, closed resolver outcomes, and native terminal-denial suites pass; 11 focused Swift tests confirm no fallback activation. |

**Score:** 2/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `token_binding.ex`, `registry.ex`, scope-consistency migration | Exact current binding lifecycle | ⚠️ INCOMPLETE | 101-15 changeset, registry predicates, SQLite guards, and focused bind/logout tests are substantive and wired; generic durable metadata is still unsafe. |
| `20260824210000_upgrade_chimeway_registration_authority.exs` | Forward authority backfill | ✗ INCOMPLETE | Exists and is exercised by migration tests, but it does not backfill `NotificationOpenIntent.scope`. |
| `notification_open_intent.ex`, `metadata_sanitizer.ex` | Opaque durable one-time intent | ✓ VERIFIED | `changeset/2` calls `sanitize_notification_open/1`, which unconditionally returns `%{}`; focused adversarial changeset/persistence tests pass. |
| Policy/manifest/resolver modules | Closed notification policy and current RouteGate authorization | ✓ VERIFIED | Substantive, wired, and covered by focused suites. |
| iOS registration, queue, and activation coordinators | Host-only registration and terminal protected activation | ✓ VERIFIED | Substantive and wired; focused Swift registration, queue, and protected-activation tests pass. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `Registry.bind_or_rotate/3` | changeset, scope guards, logout/session-revocation queries | shared installation/session invariant | ✓ WIRED | Installation scope rejects session facts; both lifecycle queries select only `:subject_session`; 101-15 regression passes. |
| `NotificationOpenIntent.changeset/2` | `MetadataSanitizer.sanitize_notification_open/1` | caller metadata before insert | ✓ WIRED | The new dedicated method is an exact empty-map projection and persistence evidence passes. |
| authority upgrade migration | `Registry.consume_current_intent/3` | matched historical intent authority backfill | ✗ NOT WIRED | Migration copies tenant/subject/session but not scope; consume requires `i.scope == scope.scope`. |
| registration evidence/audit attrs | `MetadataSanitizer.sanitize/1` | generic durable metadata projection | ✗ UNSAFE | Call sites are wired to an exact-name blocklist that preserves unknown values. |
| native protected outcome | `ActivationCoordinator` | allowed result only; denial terminal | ✓ WIRED | Focused native tests cover allowed activation and denied/no-fallback branches. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Phoenix registry | bindings and intents | Ecto transactions / conditional updates | Yes | ⚠️ PARTIAL — fresh scopes flow, but matched legacy intent scopes are absent after upgrade. |
| Notification-open metadata | caller `attrs.metadata` | `sanitize_notification_open/1` | Yes, empty projection | ✓ FLOWING |
| Binding/audit metadata | evidence and attrs metadata | generic `sanitize/1` | No safe projection | ✗ UNSAFE |
| Resolver/native queue | host resolution and opaque evidence | current manifest, RouteGate, file-backed queue | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Scope separation, logout/session-revocation isolation, database guards, and drop-all intent metadata | `cd examples/phoenix_host && MIX_ENV=test mix test registration_authority_migration_upgrade_test.exs registry_test.exs notification_open_intent_test.exs registry_notification_open_test.exs --seed 0` | 26 tests, 0 failures | ✓ PASS — does not seed and consume a matched legacy intent or adversarial generic binding/audit metadata. |
| Closed policy and manifest validation | `cd crosswake && mix test schema_test.exs route_test.exs builder_test.exs validator_test.exs --seed 0` | 73 tests, 0 failures | ✓ PASS |
| Resolver denial/redaction/telemetry | `cd packages/crosswake_chimeway && mix test resolver_test.exs denial_codes_test.exs redaction_test.exs telemetry_test.exs --seed 0` | 33 tests, 0 failures | ✓ PASS |
| Native registration, queue, and protected activation | `cd packages/crosswake-shell-core-ios && swift test --filter 'NotificationRegistrationTests|NotificationOpenQueueTests|ProtectedNotificationActivationTests'` | 11 tests, 0 failures | ✓ PASS |

### Probe Execution

Step 7c: SKIPPED — no phase-declared or conventional `scripts/*/tests/probe-*.sh` probes found.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| OPEN-01 | 101-04, 06, 09-12, 14-15 | Authenticated registration lifecycle and exact invalidation | ✗ BLOCKED | Scope separation is repaired, but D-04/OPEN-01 durable binding/audit evidence still admits unknown sensitive fields. |
| OPEN-02 | 101-02, 03, 09 | Closed manifest-consistent action policy | ✓ SATISFIED | Focused schema, builder, validator, and resolver suites pass. |
| OPEN-03 | 101-01, 03, 05, 07, 09, 13-14, 16 | Opaque offline tap, one-time consume, and current reauthorization | ✗ BLOCKED | New intent metadata is opaque, but matched historical issued intents lack the required scope and cannot reauthorize. |
| OPEN-04 | 101-01, 05, 08, 09 | Sanitized, no-fallback denial outcomes | ✓ SATISFIED | Consume-first resolver and native terminal-denial evidence pass. |

All four IDs declared across the 16 Phase 101 PLAN frontmatters are accounted for. No additional Phase 101 requirement is orphaned in `REQUIREMENTS.md`.

### Code Review Disposition

| Finding | Verdict | Evidence |
| --- | --- | --- |
| CR-01: forward authority migration leaves historical intents without scope | ✗ CONFIRMED — BLOCKER | Migration lines 19-24 omit scope while the CAS at `registry.ex:1358-1362` requires it. This also contradicts Plan 101-10's exact binding-derived authority-backfill acceptance. |
| CR-02: generic metadata sanitizer retains arbitrary sensitive data | ✗ CONFIRMED — BLOCKER | `sanitize/1` retains all non-literal keys; token binding and audit writes reuse it. Plan 101-16 fixed only notification-open metadata, not this independent D-04/OPEN-01 boundary. |
| WR-01: malformed public intent issuance raises | ⚠️ WARNING | `issue_notification_open_intent/1` dereferences `attrs.binding_ref` without a shape guard. It is a real API robustness defect, but no Phase 101 roadmap truth requires malformed internal issuance input to return a normal result, so it does not independently block the goal. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `metadata_sanitizer.ex` | 35-39, 53-65 | finite forbidden-key blocklist used as privacy boundary | 🛑 Blocker | Unknown caller-controlled fields persist in binding/audit metadata. |
| `20260824210000_upgrade_chimeway_registration_authority.exs` | 19-24 | incomplete authority backfill | 🛑 Blocker | Valid matched historical intents become permanently ineligible under current scope checks. |
| `registry.ex` | 1279-1286 | unguarded public attrs dereference | ⚠️ Warning | Malformed issuance input raises instead of returning a closed error. |
| Phase-modified source set | — | debt-marker scan | ℹ️ Info | No unreferenced `TBD`, `FIXME`, or `XXX` marker found. `git diff --check` is clean. |

### Gaps Summary

Plans 101-15 and 101-16 genuinely close the previous installation/session and notification-intent metadata gaps. The phase still misses its goal because an existing host cannot upgrade a valid matched issued intent into the complete current authority contract, and registration/audit durable metadata retains arbitrary caller input. Both are specific machine-testable blockers; Phase 102 does not explicitly own either repair, so neither is deferred.

---

_Verified: 2026-08-25T18:15:00Z_
_Verifier: the agent (gsd-verifier)_

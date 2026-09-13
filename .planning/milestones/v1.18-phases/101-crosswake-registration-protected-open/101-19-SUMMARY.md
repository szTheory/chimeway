---
phase: 101-crosswake-registration-protected-open
plan: "19"
subsystem: crosswake-example-host
tags: [elixir, ecto, sqlite, migrations, lifecycle-evidence, protected-open]
requires:
  - phase: 101-crosswake-registration-protected-open
    provides: forward reconciliation of legacy notification-open intent authority
provides:
  - Atomic reconciliation-revoked lifecycle evidence for every forced legacy intent revocation
  - Released-boundary regression coverage for evidence cardinality, privacy, matched-row exclusion, and re-entry
affects: [OPEN-04, crosswake-example-host, notification-open]
tech-stack:
  added: []
  patterns:
    - Capture reconciliation identities once after ordered migration backfill, then reuse that immutable set for all writes
    - Persist migration denial evidence as opaque lifecycle metadata with decoded empty details
key-files:
  created:
    - .planning/phases/101-crosswake-registration-protected-open/101-19-SUMMARY.md
  modified:
    - ../crosswake/examples/phoenix_host/priv/repo/migrations/20260825190000_backfill_chimeway_notification_open_intent_scope.exs
    - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs
key-decisions:
  - "[101-19]: The migration callback captures terminal intent IDs only after scope backfill has flushed, then inserts evidence and updates precisely that set in the same migration transaction."
  - "[101-19]: Reconciliation evidence contains a generated opaque UUID, intent foreign key, static reconciliation_revoked type, shared timestamp, and decoded empty details only."
patterns-established:
  - "Ecto migration callbacks that depend on preceding queued SQL are registered with execute/1 so the runner preserves statement order."
requirements-completed: [OPEN-04]
coverage:
  - id: D1
    description: "Migration-forced legacy notification-open revocations append exactly one sanitized reconciliation event while matched intents remain consumable once."
    requirement: OPEN-04
    verification:
      - kind: integration
        ref: "examples/phoenix_host/test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs#released host schema upgrades forward to fail-closed authority indexes"
        status: pass
      - kind: integration
        ref: "cd examples/phoenix_host && MIX_ENV=test mix test test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs test/crosswake_example/chimeway/registry_notification_open_test.exs --seed 0"
        status: pass
    human_judgment: false
metrics:
  tasks_completed: 1
  files_modified: 2
  completed: 2026-08-25
status: complete
---

# Phase 101 Plan 19: Reconciliation Revocation Evidence Summary

**Forward reconciliation now appends one privacy-safe `reconciliation_revoked` lifecycle event for every legacy protected-open intent it terminally revokes.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-08-25T19:11:56Z
- **Completed:** 2026-08-25T19:16:59Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments

- Captured the exact post-backfill terminal intent-ID set once, then reused it for the event insert and revoked-state update within the migration transaction.
- Added append-only events with generated opaque IDs, a stable event type, shared reconciliation timestamp, and empty JSON details.
- Extended the isolated upgrade regression to prove per-intent cardinality, empty decoded details, matched-row exclusion, repeated migration entry, and the existing valid-then-replay public consume path.

## Task Commits

1. **Task 1: Append exact sanitized evidence for migration-driven intent revocations** - `463f5431` (test RED), `1eb8bcfa` (feat GREEN)

## Files Created/Modified

- `../crosswake/examples/phoenix_host/priv/repo/migrations/20260825190000_backfill_chimeway_notification_open_intent_scope.exs` - Captures terminal IDs after backfill and atomically records sanitized reconciliation evidence with revocation.
- `../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs` - Proves event cardinality, empty details, matched-row exclusion, and migration re-entry.

## Verification

- PASS: `cd /Users/jon/projects/crosswake/examples/phoenix_host && MIX_ENV=test mix test test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs test/crosswake_example/chimeway/registry_notification_open_test.exs --seed 0` — 13 tests, 0 failures.
- PASS: `git -C /Users/jon/projects/crosswake diff --check`.

## TDD Gate Compliance

- RED: `463f5431` — the upgrade regression failed because forced revocations had no reconciliation events.
- GREEN: `1eb8bcfa` — captured-set event insertion and state update satisfy the full focused regression.

## Decisions Made

- Use an ordered `execute/1` migration callback for the dependent capture step, because direct repository access would run before Ecto flushed the preceding queued scope-backfill SQL.
- Store the empty map as JSON through the raw migration source; the regression decodes and requires `%{}` at the lifecycle boundary.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Migration ordering] Deferred the terminal selection to Ecto's ordered migration callback.**
- **Found during:** Task 1 GREEN implementation.
- **Issue:** A direct repository query evaluated before the preceding queued backfill, incorrectly including the matched authoritative intent.
- **Fix:** Registered selection, event insertion, and state update in `execute/1`, which runs after the scope SQL while retaining one transaction and one captured ID set.
- **Files modified:** `../crosswake/examples/phoenix_host/priv/repo/migrations/20260825190000_backfill_chimeway_notification_open_intent_scope.exs`
- **Verification:** Focused released-boundary regression passed.

**2. [Rule 3 - Adapter value encoding] Encoded empty event details through the raw migration source.**
- **Found during:** Task 1 GREEN implementation.
- **Issue:** SQLite cannot bind an Elixir map with source-only `insert_all/3` type inference.
- **Fix:** Bound the canonical empty JSON object, which the event map schema and regression decode to `%{}`.
- **Files modified:** `../crosswake/examples/phoenix_host/priv/repo/migrations/20260825190000_backfill_chimeway_notification_open_intent_scope.exs`
- **Verification:** Focused released-boundary regression passed.

**Total deviations:** 2 auto-fixed (1 Rule 1, 1 Rule 3). All changes preserve the plan's migration-only boundary.

## Known Stubs

None.

## Next Phase Readiness

OPEN-04's migration-denial evidence gap is covered by executable released-boundary proof. No user setup or external service configuration is required.

## Self-Check: PASSED

- Confirmed the migration and released-boundary regression files exist in the Crosswake checkout.
- Confirmed RED commit `463f5431` and GREEN commit `1eb8bcfa` exist.

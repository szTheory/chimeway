---
phase: 101-crosswake-registration-protected-open
plan: "20"
subsystem: crosswake-phoenix-example-host
tags: [ecto, sqlite, authorization, audit-retention, tdd]
requires:
  - 101-15
  - 101-19
provides:
  - exact-version logout authority predicates
  - append-only notification-open event retention guard
affects:
  - OPEN-01
  - OPEN-04
tech_stack:
  added: []
  patterns: [Ecto predicate CAS, SQLite BEFORE DELETE trigger, released-boundary migration proof]
key_files:
  created:
    - /Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260825200000_protect_chimeway_notification_open_intent_history.exs
  modified:
    - /Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex
    - /Users/jon/projects/crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registry_test.exs
    - /Users/jon/projects/crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs
    - /Users/jon/projects/crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registry_notification_open_test.exs
decisions:
  - Logout authority requires the same validated session version in selection and conditional mutation predicates.
  - Event-bearing notification-open intents use a forward SQLite trigger to retain existing lifecycle history.
metrics:
  tasks_completed: 2
  tests_passed: 24
status: complete
---

# Phase 101 Plan 20: Registration and protected-open regression closure Summary

Exact-version logout authority and append-only notification-open event retention are now enforced with focused deterministic regression evidence.

## Completed Tasks

1. Bound `Registry.revoke_for_logout/2` selection and conditional mutation to the authenticated session version, with stale version-1 versus active version-2 coverage.
2. Added a forward SQLite `BEFORE DELETE` guard for event-bearing notification-open intents, with runtime retention and released-boundary upgrade/rollback coverage.

## TDD Evidence

- RED: `32c38a21` added the failing stale logout regression; `943b3fb8` added failing migration/runtime retention regressions.
- GREEN: `65b00ffd` qualified logout predicates; `f2c502cd` added the restrictive migration and completed the executable retention evidence.

## Verification

Passed:

```text
cd /Users/jon/projects/crosswake/examples/phoenix_host && MIX_ENV=test mix test test/crosswake_example/chimeway/registry_test.exs test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs test/crosswake_example/chimeway/registry_notification_open_test.exs --seed 0
24 tests, 0 failures
```

Also passed `git diff --check` and confirmed the released `20260603000000_create_chimeway_notification_open_intents.exs` migration remains unchanged.

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 1 - Bug] Corrected the runtime deletion assertion to match the SQLite adapter's exception behavior.
- **Found during:** Task 2
- **Fix:** Asserted the static SQLite abort from `Repo.delete!/1` rather than an `{:error, changeset}` tuple.

2. [Rule 1 - Bug] Used Ecto's one-step rollback mode for the irreversible preceding migration boundary.
- **Found during:** Task 2
- **Fix:** Replaced a target-version rollback with `step: 1`, so the regression reverses only the new migration without requiring a nonexistent `down/0` on the prior migration.

## Known Stubs

None.

## Self-Check: PASSED

All declared Crosswake source/test artifacts exist and all four task commits are present in the Crosswake repository.

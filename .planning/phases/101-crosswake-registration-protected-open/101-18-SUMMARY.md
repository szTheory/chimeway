---
phase: 101-crosswake-registration-protected-open
plan: "18"
subsystem: crosswake-example-host
tags: [elixir, ecto, sqlite, authorization, migrations, protected-open]
requires:
  - phase: 101-crosswake-registration-protected-open
    provides: exact binding authority and one-time protected intent consumption
provides:
  - Forward-only reconciliation of legacy notification-open intent scope from exact active bindings
  - Terminal revocation for every issued legacy intent that cannot meet current authority predicates
  - Upgrade evidence that a matched legacy intent is consumed once and then denied as replay
affects: [OPEN-03, crosswake-example-host, notification-open]
tech-stack:
  added: []
  patterns:
    - Forward migrations reconcile durable authority with one exact active-binding predicate and fail closed otherwise
    - Legacy protected-open evidence is proven through the public Registry.consume_intent/1 seam
key-files:
  created:
    - ../crosswake/examples/phoenix_host/priv/repo/migrations/20260825190000_backfill_chimeway_notification_open_intent_scope.exs
    - .planning/phases/101-crosswake-registration-protected-open/101-18-SUMMARY.md
  modified:
    - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs
key-decisions:
  - "[101-18]: A legacy intent gains scope only when its exact active binding has a closed valid scope and coherent copied authority facts."
  - "[101-18]: Every issued intent that fails the current exact-binding authority predicate is terminally revoked; no fallback scope or resurrection path exists."
patterns-established:
  - "Forward authority repairs use correlated exact-binding SQL for both derivation and fail-closed reconciliation."
requirements-completed: [OPEN-03]
metrics:
  tasks_completed: 1
  files_modified: 2
  completed: 2026-08-25
status: complete
coverage:
  - id: D1
    description: Matched historical notification-open intent upgrades to exact current authority and consumes once.
    requirement: OPEN-03
    verification:
      - kind: integration
        ref: examples/phoenix_host/test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs#released host schema upgrades forward to fail-closed authority indexes
        status: pass
    human_judgment: false
---

# Phase 101 Plan 18: Legacy Protected-Open Authority Upgrade Summary

**A forward Ecto migration now derives a matched legacy intent's scope from its exact active binding, then proves real one-time consumption while terminally closing unreconcilable issued rows.**

## Completed Work

- Added `20260825190000_backfill_chimeway_notification_open_intent_scope.exs`, which derives `scope` only from an exact active binding with a closed scope and matching tenant, subject, and scope-specific session facts.
- Reconciles every issued row through the same authoritative predicate, terminally changing all failures to `revoked` without changing pre-existing consumed or revoked rows.
- Extended the isolated released-boundary SQLite migration proof: it observes absent scope after `20260824210000`, verifies the derived scope after the new migration, validates inactive and absent-binding controls close, then calls public `Registry.consume_intent/1` for valid-and-replay outcomes plus durable consumed-event evidence.

## Verification

- PASS: `cd /Users/jon/projects/crosswake/examples/phoenix_host && MIX_ENV=test mix test test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs test/crosswake_example/chimeway/registry_notification_open_test.exs --seed 0` — 13 tests, 0 failures.
- PASS: Static migration predicate check confirms exact `binding_ref`, active state, closed scopes, and terminal revocation logic.
- PASS: `git diff --check`.

## TDD Gate Compliance

- Task 1 RED: `a3a5d2d0` — released-boundary migration evidence failed because the matched legacy intent's scope was nil.
- Task 1 GREEN: `1de1433f` — exact-binding scope derivation, terminal reconciliation, and public one-time consume/replay proof passed.

## Decisions Made

- Scope is a binding-derived durable fact; migration SQL does not infer defaults or accept caller metadata.
- The forward-only repair uses the existing `revoked` terminal state for incomplete authority rather than a reversible fallback.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - SQL null semantics] Replaced a nullable `NOT IN` terminal check with an authoritative `NOT EXISTS` predicate.**
- **Found during:** Task 1 GREEN implementation.
- **Issue:** SQL `NULL NOT IN (...)` is unknown, which could leave an incomplete issued row eligible.
- **Fix:** Terminal reconciliation now rejects every issued row unless its scope and all authority facts match one exact active binding.
- **Files modified:** `../crosswake/examples/phoenix_host/priv/repo/migrations/20260825190000_backfill_chimeway_notification_open_intent_scope.exs`
- **Commit:** `1de1433f`

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed the migration and regression test artifacts exist.
- Confirmed RED `a3a5d2d0` and GREEN `1de1433f` commits exist.

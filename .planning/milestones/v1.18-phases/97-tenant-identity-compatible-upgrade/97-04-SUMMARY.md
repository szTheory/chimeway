---
phase: 97-tenant-identity-compatible-upgrade
plan: "04"
subsystem: tenant-reconciliation
tags: [elixir, ecto, postgresql, json, mix-task, tenant-identity]
requires:
  - phase: 97-tenant-identity-compatible-upgrade
    provides: nullable Event and Notification tenant identity
provides:
  - Deterministic JSON-safe reporting of NULL-owned event trees
  - Atomic host-supplied tenant assignment with conflict protection
  - Strict JSON-only maintenance Mix task
affects: [97-06-upgrade-migration-proofs]
tech-stack:
  added: []
  patterns:
    - Row-locked event-tree ownership assignment in one Repo transaction
    - Versioned JSON-safe maintenance reports
    - Strict OptionParser mode selection delegated to a callable core module
key-files:
  created:
    - lib/chimeway/reconciliation.ex
    - lib/mix/tasks/chimeway.reconcile_tenants.ex
    - test/chimeway/reconciliation_test.exs
    - test/chimeway/mix/tasks/reconcile_tenants_test.exs
  modified: []
key-decisions:
  - "[97-04]: Reconciliation reports only IDs, NULL ownership, counts, status, schema version, and an explicit assignment instruction."
  - "[97-04]: Assignment locks the named Event and its Notifications, rejects any existing ownership, and writes only a validated host-supplied tenant ID."
  - "[97-04]: The Mix task accepts exactly report mode or explicit event-and-tenant assignment mode and emits one JSON object."
metrics:
  duration: 12 min
  completed: 2026-08-12
  tasks_completed: 2
status: complete
---

# Phase 97 Plan 04: Tenant Reconciliation Summary

**Legacy NULL-owned event trees now have deterministic, JSON-safe visibility and a one-way host-controlled ownership assignment path.**

## Completed Tasks

1. Added reconciliation contracts and `Chimeway.Reconciliation`, including sorted NULL-ownership reports, UUID/tenant validation, row locking, atomic child updates, idempotency, rollback, and concurrent-conflict proof.
2. Added `mix chimeway.reconcile_tenants` as a strict JSON-only wrapper around the core reconciliation API.

## Verification

- `mix format --check-formatted lib/chimeway/reconciliation.ex test/chimeway/reconciliation_test.exs` — passed.
- `mix test test/chimeway/reconciliation_test.exs --warnings-as-errors` — passed (7 tests).
- `mix format --check-formatted lib/mix/tasks/chimeway.reconcile_tenants.ex test/chimeway/mix/tasks/reconcile_tenants_test.exs` — passed.
- `mix test test/chimeway/mix/tasks/reconcile_tenants_test.exs test/chimeway/reconciliation_test.exs --warnings-as-errors` — passed (10 tests).

## Decisions Made

- The versioned report omits payload, recipients, deliveries, workflow data, actors, and inferred tenant values; its event IDs and NULL notification IDs are stable-sort ordered.
- Repeated matching assignment returns `:already_assigned`; any non-NULL event or child ownership prevents reassignment and leaves the tree unchanged.
- The CLI has no dynamic-prefix or tenant-routing flag; tenant is an explicit durable column value only.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test determinism] Sort report expectations by durable event ID**
- **Found during:** Task 1 verification
- **Issue:** UUID insertion order is not lexical durable-ID order, making the initial test expectation nondeterministic.
- **Fix:** Sorted expected event records by ID to match the report contract.
- **Files modified:** `test/chimeway/reconciliation_test.exs`
- **Verification:** Focused test suite passed repeatedly.
- **Commit:** `83b130a`

**Total deviations:** 1 auto-fixed (Rule 1).

## Known Stubs

None.

## Self-Check: PASSED

- Created reconciliation module, Mix task, and both focused test files exist.
- Task commits `017700a`, `83b130a`, `27f9266`, and `fc0c64b` exist in git history.

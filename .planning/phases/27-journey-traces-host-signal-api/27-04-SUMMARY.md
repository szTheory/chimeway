---
phase: 27-journey-traces-host-signal-api
plan: 04
subsystem: persistence
tags: [elixir, ecto, postgres, migration, workflow, tenancy]
requires:
  - phase: 27-03
    provides: Tenant-aware workflow inspection surfaces that depend on non-null spine fields
provides:
  - Upgrade-safe Phase 27 spine migration for existing workflow_runs rows
  - WorkflowRun tenant_id validation parity with Signal changesets
affects: [schema-evolution, host-data-safety, tenant-isolation]
tech-stack:
  added: []
  patterns:
    - Three-step ADD/UPDATE/MODIFY migration flow for new NOT NULL columns on populated tables
    - Changeset-level tenant validation mirrors existing Signal schema guards
key-files:
  created: []
  modified:
    - priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs
    - test/chimeway/migration_contract_test.exs
    - lib/chimeway/workflows/workflow_run.ex
    - test/chimeway/workflows/workflow_run_test.exs
key-decisions:
  - "Backfill legacy workflow runs to tenant_id = \"default\" during migration instead of adding a schema default, so future inserts still have to provide tenant_id explicitly."
  - "Backfill pending_signals to an empty array for pre-27 rows so inspection code never sees NULL for the spine field."
  - "Keep empty-string tenant rejection at the changeset boundary to align WorkflowRun with the existing Signal validation contract."
requirements-completed: [API-01, OPS-03, OPS-04]
duration: ~12 min
completed: 2026-04-30
---

# Phase 27 Plan 04: Upgrade-Safe Spine Migration Summary

**Phase 27-04 closes the migration blocker for existing `chimeway_workflow_runs` rows and removes the `tenant_id` validation asymmetry between `WorkflowRun` and `Signal`, so Phase 27 inspection and routing code can rely on non-null spine data and non-empty tenant identifiers.**

## Performance

- **Duration:** ~12 min
- **Completed:** 2026-04-30
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Reworked `priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs` into a safe ADD/UPDATE/MODIFY sequence:
  - add `tenant_id` as nullable
  - backfill legacy rows to `tenant_id = 'default'`
  - backfill legacy rows to `pending_signals = '{}'`
  - enforce `tenant_id` as `NOT NULL`
- Extended `test/chimeway/migration_contract_test.exs` to assert the Phase 27 spine table and column contract exists after migration.
- Added `validate_length(:tenant_id, min: 1)` to `lib/chimeway/workflows/workflow_run.ex`.
- Added a regression test in `test/chimeway/workflows/workflow_run_test.exs` covering empty-string `tenant_id` rejection.

## Task Commits

1. `0e4d2bc` — `fix(27-04): make phase 27 spine migration upgrade-safe`
2. `bb2b903` — `fix(27-04): reject empty workflow run tenant ids`

## Verification

- `MIX_ENV=test mix ecto.drop`
- `MIX_ENV=test mix ecto.create`
- `MIX_ENV=test mix ecto.migrate`
- `mix test test/chimeway/migration_contract_test.exs`
- `mix test test/chimeway/workflows/workflow_run_test.exs`
- `mix compile --warnings-as-errors`
- Manual upgrade-path check:
  - migrated test DB only through `20260429170300`
  - inserted a pre-27 `chimeway_workflow_runs` row
  - ran `MIX_ENV=test mix ecto.migrate`
  - verified resulting row was `["default", [], false, false]` for `tenant_id`, `pending_signals`, `tenant_id IS NULL`, `pending_signals IS NULL`

## Deviations from Plan

### Execution Adjustments

**1. Repo does not define `mix ecto.reset`**
- **Found during:** Task 1 verification
- **Issue:** The plan's verification command used `mix ecto.reset`, but this project only exposes `ecto.drop`, `ecto.create`, and `ecto.migrate`.
- **Adjustment:** Used `MIX_ENV=test mix ecto.drop`, `MIX_ENV=test mix ecto.create`, and `MIX_ENV=test mix ecto.migrate` to perform the same reset-and-migrate check.

## Known Stubs

None.

## Threat Flags

No new threat surface beyond the planned schema change. The plan threats are mitigated:

- **T-27-06 (Tampering / populated DB migration):** mitigated by the three-step backfill flow before `NOT NULL` enforcement.
- **T-27-07 (Information Disclosure / empty tenant_id):** mitigated by `validate_length(:tenant_id, min: 1)` in `WorkflowRun.changeset/2`.

## Self-Check: PASSED

- `priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs` — FOUND
- `test/chimeway/migration_contract_test.exs` — FOUND
- `lib/chimeway/workflows/workflow_run.ex` — FOUND
- `test/chimeway/workflows/workflow_run_test.exs` — FOUND
- `.planning/phases/27-journey-traces-host-signal-api/27-04-SUMMARY.md` — FOUND
- Commits `0e4d2bc`, `bb2b903` — both present in git log

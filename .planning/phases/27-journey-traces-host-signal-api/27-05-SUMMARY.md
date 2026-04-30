---
phase: 27-journey-traces-host-signal-api
plan: 05
subsystem: trigger-tenant-threading
tags: [elixir, ecto, workflow, trigger, tenancy, integration]
requires:
  - phase: 27-04
    provides: WorkflowRun tenant_id validation on persisted workflow spine rows
  - phase: 27-06
    provides: Tenant-scoped workflow inspection and signal routing on workflow runs
provides:
  - Tenant-aware workflow run creation for trigger-born runs
  - Trigger pipeline validation that refuses missing tenant_id instead of inventing a default tenant
  - End-to-end trigger-to-explain coverage for host tenant boundaries
affects: [trigger-pipeline, workflow-run-persistence, tenant-isolation, operator-inspection]
tech-stack:
  added: []
  patterns:
    - Explicit tenant threading from public API opts through private trigger pipeline helpers
    - Workflow leaf contract enforcement with tenant_id as a required positional argument
    - End-to-end integration coverage that validates positive and cross-tenant inspection behavior
key-files:
  created:
    - .planning/phases/27-journey-traces-host-signal-api/27-05-SUMMARY.md
    - test/chimeway/integration/trigger_explain_test.exs
  modified:
    - lib/chimeway/workflows.ex
    - lib/chimeway/trigger.ex
    - test/chimeway/workflows_test.exs
    - test/chimeway/trigger_pipeline_test.exs
key-decisions:
  - "Trigger.trigger/3 now requires host-supplied tenant_id and returns {:error, :missing_tenant_id} when omitted rather than silently using a shared default."
  - "Workflow run creation keeps tenant identity as an explicit positional argument all the way into Workflows.create_initial_run/5."
  - "Trigger-created workflow runs are verified through persisted state alone by round-tripping Trigger.trigger/3 into Workflows.explain/2 and Workflows.route_signal/1."
requirements-completed: [OPS-03, OPS-04]
duration: ~22 min
completed: 2026-04-30
---

# Phase 27 Plan 05: Trigger Tenant Threading Summary

**Phase 27-05 closes the tenant-threading gap that made trigger-created workflow runs unreachable to tenant-scoped inspection and signal routing, by requiring a host-provided `tenant_id` from `Trigger.trigger/3` through `Workflows.create_initial_run/5` and validating the full round-trip in tests.**

## Performance

- **Duration:** ~22 min
- **Completed:** 2026-04-30
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Bumped `Workflows.create_initial_run/4` to `create_initial_run/5` and removed the hardcoded `"default"` tenant from trigger-created `WorkflowRun` rows.
- Added workflow-level tests proving `create_initial_run/5` persists the supplied tenant and rejects an empty-string tenant via the `WorkflowRun` changeset.
- Required `tenant_id` in `Chimeway.Trigger.trigger/3`, validated it alongside `idempotency_key`, and threaded it through `do_trigger/7`, `insert_notifications/6`, and `insert_workflow_runs/3`.
- Updated trigger pipeline tests to pass an explicit tenant for workflow-bearing trigger paths.
- Added `test/chimeway/integration/trigger_explain_test.exs` covering:
  - `Trigger.trigger/3` with `tenant_id: "acme"`
  - `Workflows.explain("acme", run.id) == {:ok, _}`
  - `Workflows.explain("other_tenant", run.id) == {:error, :not_found}`
  - `Trigger.trigger/3` without `tenant_id` returning `{:error, :missing_tenant_id}`
  - `Workflows.route_signal/1` resuming a trigger-created run only within the correct tenant

## Task Commits

1. `6014765` — `fix(27-05): thread tenant into initial workflow runs`
2. `03f3e84` — `fix(27-05): pass tenant ids through trigger workflow runs`
3. `dfa75f7` — `test(27-05): finish tenant coverage in trigger pipeline tests`

## Verification

- `mix test test/chimeway/workflows_test.exs`
- `mix compile --warnings-as-errors`
- `mix test test/chimeway/integration/trigger_explain_test.exs test/chimeway/trigger_pipeline_test.exs test/chimeway/workflows_test.exs`
- `mix compile --warnings-as-errors`
- `mix test`

## Deviations from Plan

### Execution Adjustments

**1. Task 2 required two commits because `test/chimeway/trigger_pipeline_test.exs` was already dirty**
- **Found during:** Task 2 staging
- **Issue:** The trigger pipeline test file already contained unrelated unstaged workflow expectation edits, so the tenant-threading assertions could not be cleanly committed in one pass without selective staging.
- **Adjustment:** Committed the trigger pipeline contract changes in `03f3e84` and followed with `dfa75f7` to stage the remaining tenant-specific assertions while leaving unrelated dirty hunks in place.

## Known Stubs

None.

## Threat Flags

No new threat surface beyond the planned trigger tenant threading. The planned mitigations are implemented:

- **T-27-08:** omitted tenant IDs now fail explicitly at the trigger boundary instead of being persisted under a shared default namespace.
- **T-27-09:** end-to-end tests prove `Workflows.explain/2` remains tenant-scoped for trigger-created runs and `Workflows.route_signal/1` only resumes runs for the matching tenant.

## Self-Check: PASSED

- `.planning/phases/27-journey-traces-host-signal-api/27-05-SUMMARY.md` — FOUND
- Commits `6014765`, `03f3e84`, and `dfa75f7` — all present in git log

---
phase: 27-journey-traces-host-signal-api
plan: 03
subsystem: api
tags: [elixir, ecto, postgres, signals, workflow, inspection, tenant-isolation]
requires:
  - phase: 27-01
    provides: State Spine columns on WorkflowRun (tenant_id, suspended_until, pending_signals, terminal_reason)
  - phase: 27-02
    provides: route_signal/1 routing logic and WorkflowTransition trace records
provides:
  - Chimeway.Workflows.explain/2 — tenant-isolated workflow run state inspection
  - Chimeway.Workflows.list_traces/3 — tenant-isolated structural trace listing
affects: [host-app-integration, operator-observability]
tech-stack:
  added: []
  patterns:
    - explain/2 uses a single left-join query to resolve current_step_name without extra round-trips
    - list_traces/3 verifies tenant ownership before returning trace data (two-query pattern for isolation)
    - Both functions return {:error, :not_found} for missing or cross-tenant execution IDs
key-files:
  created:
    - test/chimeway/workflows_inspection_test.exs
  modified:
    - lib/chimeway/workflows.ex
key-decisions:
  - "explain/2 resolves current_step_name via a LEFT JOIN to chimeway_workflow_steps on current_step_id, so callers receive the step key in one query without a separate lookup."
  - "list_traces/3 uses a two-query pattern: first confirm tenant ownership (returning :not_found on mismatch), then fetch transitions. This keeps the tenant guard structurally mandatory."
  - "Both functions return {:error, :not_found} rather than an empty result for missing/cross-tenant IDs to prevent timing-based information disclosure."
  - "Payload safety is structural: WorkflowTransition.context only ever contains structural metadata (event_name, step_key, source); the inspection API does not need to redact anything at query time."
requirements-completed: [OPS-04]
duration: ~4 min
completed: 2026-04-30
---

# Phase 27 Plan 03: Host Trace Inspection API Summary

**Phase 27-03 exposes tenancy-aware operator inspection endpoints — `Chimeway.Workflows.explain/2` and `Chimeway.Workflows.list_traces/3` — that return workflow run state and structural traces strictly isolated to the requested tenant, mitigating the T-27-04 information disclosure and T-27-05 privilege escalation threats from the plan's threat model.**

## Performance

- **Duration:** ~4 min
- **Completed:** 2026-04-30
- **Tasks:** 1 (TDD: RED + GREEN)
- **Files created:** 1
- **Files modified:** 1

## Accomplishments

- Added `Chimeway.Workflows.explain/2` to `lib/chimeway/workflows.ex`. The function executes a single Ecto query with a LEFT JOIN to `chimeway_workflow_steps` to resolve the `current_step_name` (step key) alongside the authoritative State Spine fields (`state`, `status_reason`, `suspended_until`, `pending_signals`, `terminal_reason`). The `WHERE` clause mandates both `id = ^execution_id` AND `tenant_id = ^tenant_id` — preventing any cross-tenant data access.
- Added `Chimeway.Workflows.list_traces/3` to `lib/chimeway/workflows.ex`. The function first checks that the workflow run exists under the given `tenant_id`; if not found it returns `{:error, :not_found}`. On success it returns all `WorkflowTransition` records for that run ordered by `inserted_at` ascending. No payload data is surfaced because `WorkflowTransition.context` only ever contains structural metadata.
- Added `test/chimeway/workflows_inspection_test.exs` with 14 tests covering:
  - `explain/2` basic state inspection (state, step name, spine fields, terminal_reason)
  - `explain/2` tenant isolation (cross-tenant rejection, non-existent ID)
  - `list_traces/3` basic listing (returns transitions, empty result, insertion-order sort)
  - `list_traces/3` tenant isolation (cross-tenant rejection, non-existent ID, run-scoped results)
  - `list_traces/3` payload safety (context must not contain raw payload keys)
- Fixed a `@doc` placement ordering issue in `lib/chimeway/workflows.ex` where the existing `route_signal/1` docstring was being immediately overwritten by a new `@doc` — moved the `route_signal` docstring to sit directly above its `@spec` and `def`.

## Task Commits

Each task followed the TDD (RED → GREEN) cycle with individual commits:

1. **Task 1 RED:** `80cbda0` — `test(27-03): add failing tests for Workflows.explain/2 and list_traces/3`
2. **Task 1 GREEN:** `a87ce63` — `feat(27-03): implement Workflows.explain/2 and list_traces/3 inspection API`

## Files Created/Modified

- `lib/chimeway/workflows.ex` — Added `explain/2` and `list_traces/3` public functions; fixed `@doc` placement for `route_signal/1`.
- `test/chimeway/workflows_inspection_test.exs` — 14 integration tests for both inspection endpoints covering correctness, tenant isolation, ordering, and payload safety.

## Decisions Made

- **Single left-join for `explain/2`**: The step key is resolved via `LEFT JOIN chimeway_workflow_steps ON wr.current_step_id = ws.id` so the function returns `current_step_name` in one round-trip. A `LEFT JOIN` is used (not `INNER JOIN`) so runs without a current step still return a result (e.g., a completed run whose step cursor is cleared).
- **Two-query pattern for `list_traces/3`**: The tenant ownership check is explicit and mandatory: the function queries `chimeway_workflow_runs WHERE id = ^id AND tenant_id = ^tenant_id` first, then fetches transitions only on success. This makes cross-tenant leakage structurally impossible even if the transition query were to drift.
- **`{:error, :not_found}` instead of empty result**: Both functions return an error tuple rather than an empty/nil result for missing or cross-tenant IDs. This prevents callers from misinterpreting "tenant-isolated not found" as "execution has no data," and avoids timing-based disclosure of whether an execution ID exists.
- **No payload redaction needed at query time**: `WorkflowTransition.context` is written only by `route_signal/1` (which structurally excludes payload per T-27-03) and `create_initial_run/4` (which uses a static trigger context). The inspection API doesn't need to filter keys at read time — the invariant is enforced at write time.

## Verification

- `mix test test/chimeway/workflows_inspection_test.exs` — 14/14 pass.
- `mix test test/chimeway/workflows_test.exs` — 7/7 pass (27-02 tests unaffected).
- `mix test test/chimeway/signal_test.exs` — 5/5 pass (27-01 tests unaffected).
- `mix test --exclude oban` — 367 tests, 2 failures. Both failures are pre-existing Phase 26-01 RED tests (committed as `f01b2cf test(26-01): add failing test for explicit stops and implicit completions`) that are turned GREEN by the in-progress Phase 26 work. Not a Phase 27 regression.
- `mix compile` — clean, no warnings from modified files.

## TDD Gate Compliance

Task 1 followed RED → GREEN:

- Task 1: `test(27-03)` commit `80cbda0` (RED) before `feat(27-03)` commit `a87ce63` (GREEN).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed @doc placement collision in workflows.ex**
- **Found during:** Task 1 GREEN
- **Issue:** When inserting `@doc` for `explain/2` immediately after the existing `@doc` for `route_signal/1`, Elixir emitted a "redefining @doc attribute" warning because both `@doc` attributes appeared consecutively without an intervening `def`. The first docstring was being silently discarded.
- **Fix:** Removed the `route_signal/1` docstring from before the new `explain/2` `@doc` and restored it immediately above the `@spec route_signal/1` and `def route_signal/1` definitions later in the file.
- **Files modified:** `lib/chimeway/workflows.ex`
- **Commit:** `a87ce63`

## Known Stubs

None — both inspection functions query live database rows and return real persisted state.

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes were introduced. Both threats from the plan's `<threat_model>` are mitigated:

- **T-27-04 (Information Disclosure — list_traces):** Mitigated. `list_traces/3` enforces `tenant_id` at the function signature level; cross-tenant queries structurally return `{:error, :not_found}`. Payload data is never present in `WorkflowTransition.context` by construction.
- **T-27-05 (Elevation of Privilege — explain):** Mitigated. `explain/2` queries `chimeway_workflow_runs WHERE id = ^execution_id AND tenant_id = ^tenant_id`; a run belonging to another tenant cannot be returned regardless of execution ID.

## Self-Check: PASSED

- `lib/chimeway/workflows.ex` — FOUND
- `test/chimeway/workflows_inspection_test.exs` — FOUND
- `.planning/phases/27-journey-traces-host-signal-api/27-03-SUMMARY.md` — FOUND (this file)
- Commits `80cbda0`, `a87ce63` — both present in git log

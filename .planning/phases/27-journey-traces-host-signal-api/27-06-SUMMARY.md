---
phase: 27-journey-traces-host-signal-api
plan: 06
subsystem: workflow-routing-and-inspection
tags: [elixir, ecto, oban, workflow, concurrency, inspection]
requires:
  - phase: 27-04
    provides: Upgrade-safe workflow spine fields used by signal routing and inspection
provides:
  - Transaction-scoped signal routing locks that prevent duplicate signal resumption traces
  - Consistent Oban queue wiring for signal routing jobs across runtime environments
  - Bounded workflow trace reads through the documented list_traces/3 limit option
affects: [workflow-routing, oban-configuration, operator-inspection]
tech-stack:
  added: []
  patterns:
    - Function-form Repo.transaction preserving FOR UPDATE locks through commit
    - Oban queue naming aligned between worker declarations and runtime config
    - Optional Ecto query limit applied only when callers request bounded trace reads
key-files:
  created:
    - .planning/phases/27-journey-traces-host-signal-api/27-06-SUMMARY.md
  modified:
    - lib/chimeway/workflows.ex
    - lib/chimeway/dispatch/signal_router_worker.ex
    - config/config.exs
    - config/dev.exs
    - config/test.exs
    - test/chimeway/workflows_test.exs
    - test/chimeway/workflows_inspection_test.exs
key-decisions:
  - "Keep route_signal/1 on a function-form Repo.transaction so the matching FOR UPDATE query and the resume writes share one database transaction while preserving the existing results-map shape."
  - "Standardize signal-routing jobs on :chimeway_signals to match the project’s chimeway_* Oban queue naming convention."
  - "Interpret list_traces(..., limit: 0) as an explicitly bounded empty result instead of falling back to an unbounded read."
requirements-completed: [API-01, OPS-03, OPS-04]
duration: ~20 min
completed: 2026-04-30
---

# Phase 27 Plan 06: Signal Routing Correctness Summary

**Phase 27-06 closes the remaining signal-routing correctness gaps by holding workflow row locks through commit, wiring the signal router onto a real Oban queue, and making `Workflows.list_traces/3` honor its documented `:limit` option.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-04-30
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Moved `Workflows.route_signal/1` to a function-form `Repo.transaction/1`, so `find_runs_waiting_for_signal/2` acquires `FOR UPDATE` locks inside the same transaction that updates `WorkflowRun` rows and appends `WorkflowTransition` records.
- Tightened `test/chimeway/workflows_test.exs` to assert the returned per-run result map shape and added a concurrent routing regression that proves only one `signal_received` transition is persisted for a logically single resumption.
- Renamed `SignalRouterWorker` to use queue `:chimeway_signals` and declared that queue in `config/config.exs`, `config/dev.exs`, and `config/test.exs`.
- Updated `Workflows.list_traces/3` to read `opts`, apply `limit: ^n` for non-negative integer limits, and preserve the prior unbounded behavior when `:limit` is omitted.
- Added inspection coverage for bounded reads, unbounded reads, and the `limit: 0` boundary case.

## Task Commits

1. `9089f0d` — `fix(27-06): hold workflow signal locks through commit`
2. `3a0ffd0` — `fix(27-06): declare the signal router queue everywhere`
3. `8c738f1` — `fix(27-06): honor trace limits in workflow inspection`

## Verification

- `mix compile --warnings-as-errors`
- `mix test test/chimeway/workflows_test.exs test/chimeway/workflows_inspection_test.exs test/chimeway/dispatch/signal_router_worker_test.exs test/chimeway/signal_test.exs`
- `git grep -n ':signals\b' lib/ config/ test/ || true`

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

No new threat surface beyond the planned signal-routing and inspection changes. The planned mitigations are implemented:

- **T-27-10:** concurrent `route_signal/1` callers now serialize on transaction-scoped row locks.
- **T-27-11:** `SignalRouterWorker` and runtime Oban config agree on `:chimeway_signals`.
- **T-27-12:** `list_traces/3` now honors caller-supplied bounds.

## Self-Check: PASSED

- `.planning/phases/27-journey-traces-host-signal-api/27-06-SUMMARY.md` — FOUND
- Commits `9089f0d`, `3a0ffd0`, and `8c738f1` — all present in git log

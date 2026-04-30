---
phase: 27-journey-traces-host-signal-api
plan: 02
subsystem: api
tags: [elixir, ecto, oban, postgres, signals, workflow, signal-routing]
requires:
  - phase: 27-01
    provides: Signal schema, Chimeway.Signal.track/4, barebones SignalRouterWorker
provides:
  - Chimeway.Workflows.route_signal/1 — tenant-isolated signal fan-out with atomic Multi
  - Completed Chimeway.Dispatch.SignalRouterWorker.perform/1 — fetches signal and delegates routing
affects: [27-03-host-trace-inspection, host-app-integration]
tech-stack:
  added: []
  patterns:
    - route_signal uses Ecto.Multi with per-run update + transition insert for atomic fan-out
    - FOR UPDATE lock on matched runs prevents concurrent routing races
    - Payload safety enforced at routing boundary — event_name recorded in transition context, raw payload excluded
    - Cross-tenant isolation structurally enforced via tenant_id filter in the query (T-27-03)
key-files:
  created:
    - test/chimeway/workflows_test.exs
    - test/chimeway/dispatch/signal_router_worker_test.exs
  modified:
    - lib/chimeway/workflows.ex
    - lib/chimeway/dispatch/signal_router_worker.ex
key-decisions:
  - "route_signal uses Ecto.Multi.reduce over matched runs so all updates and transition inserts share one transaction boundary — no partial fan-out possible."
  - "Cross-tenant isolation is structural: the query always includes tenant_id = ^signal.tenant_id in the WHERE clause; no opt-in required per T-27-03."
  - "Payload is never written to WorkflowTransition.context — only event_name is recorded, matching the structural-traces-only approach from 27-RESEARCH.md."
  - "SignalRouterWorker returns {:error, :signal_not_found} for missing signal rows so Oban schedules retry, and :ok for both zero-match and successful routing."
requirements-completed: [OPS-03]
duration: ~3 min
completed: 2026-04-30
---

# Phase 27 Plan 02: Signal Router Worker Summary

**Phase 27-02 implements the signal routing fan-out: `Chimeway.Workflows.route_signal/1` atomically resumes all `:waiting` workflow runs that declare the incoming signal's `event_name` in their `pending_signals` list, and `SignalRouterWorker.perform/1` wires the Oban job to that routing function with signal-not-found retry semantics.**

## Performance

- **Duration:** ~3 min
- **Completed:** 2026-04-30
- **Tasks:** 2 (Task 1 route_signal routing logic, Task 2 complete SignalRouterWorker)
- **Files created:** 2
- **Files modified:** 2

## Accomplishments

- Added `Chimeway.Workflows.route_signal/1` to `lib/chimeway/workflows.ex`. The function queries `chimeway_workflow_runs` for rows where `tenant_id` matches, `state = :waiting`, and `event_name IN pending_signals` (Postgres array containment via Ecto query). All matched runs are updated to `state: :active`, `pending_signals: []`, `status_reason: "signal_received"` and one `WorkflowTransition` is inserted per run with `event_name` in the context (payload excluded). All operations are wrapped in a single `Ecto.Multi.reduce/3` transaction.
- Completed `Chimeway.Dispatch.SignalRouterWorker.perform/1` in `lib/chimeway/dispatch/signal_router_worker.ex`. The worker fetches the `Signal` row from `signal_id`; returns `{:error, :signal_not_found}` if gone (Oban retries), calls `Workflows.route_signal/1` on success and returns `:ok` (job completes) or propagates error tuples.
- Added `test/chimeway/workflows_test.exs` with 7 tests verifying: basic matching, cross-tenant isolation, non-matching event names, non-waiting state exclusion, payload safety in transition context, multi-run fan-out, and idempotency.
- Added `test/chimeway/dispatch/signal_router_worker_test.exs` with 5 tests verifying: success path (run resumed, transition written), no-match path, missing signal error path, cross-tenant isolation.

## Task Commits

Each task followed the TDD (RED → GREEN) cycle with individual commits:

1. **Task 1 RED:** `239aa1a` — `test(27-02): add failing tests for Workflows.route_signal/1`
2. **Task 1 GREEN:** `b3a88d2` — `feat(27-02): implement Chimeway.Workflows.route_signal/1`
3. **Task 2 RED:** `9ea4032` — `test(27-02): add failing tests for SignalRouterWorker.perform/1`
4. **Task 2 GREEN:** `6ab36b7` — `feat(27-02): complete SignalRouterWorker.perform/1 implementation`

## Files Created/Modified

- `lib/chimeway/workflows.ex` — Added `route_signal/1` public function and `find_runs_waiting_for_signal/2` private helper; added `alias Chimeway.Signals.Signal` import.
- `lib/chimeway/dispatch/signal_router_worker.ex` — Replaced barebones `{:ok, :noop}` perform with full implementation: signal lookup → route_signal delegate.
- `test/chimeway/workflows_test.exs` — 7 integration tests for `route_signal/1` covering matching, isolation, payload safety, fan-out, and idempotency.
- `test/chimeway/dispatch/signal_router_worker_test.exs` — 5 integration tests for `SignalRouterWorker.perform/1` covering success, no-match, missing signal, and cross-tenant isolation.

## Decisions Made

- **FOR UPDATE lock**: `find_runs_waiting_for_signal` acquires a `FOR UPDATE` lock on matched rows before updating them; this prevents two concurrent `SignalRouterWorker` jobs (e.g., two signals with the same event_name arriving milliseconds apart) from racing on the same run.
- **Ecto.Multi.reduce fan-out**: All per-run updates and transition inserts are composed into one `Ecto.Multi` and executed in a single `Repo.transaction/1`, so either all matched runs transition or none do.
- **Payload excluded from transition context**: Only `event_name` is written to `WorkflowTransition.context`. The signal's `payload` map is intentionally never recorded in trace rows — consistent with the structural-traces-only approach from 27-RESEARCH.md § 3 (Payload-Safe and Tenancy-Aware Journey Traces).
- **`:signal_not_found` returns `{:error, _}` from worker**: Oban will retry the job on transient deletion (e.g., race with cleanup). For a signal that genuinely never existed this would exhaust retries, but that case cannot happen because `Chimeway.Signal.track/4` inserts the row before enqueuing the job.

## Verification

- `mix test test/chimeway/workflows_test.exs` — 7/7 pass.
- `mix test test/chimeway/dispatch/signal_router_worker_test.exs` — 5/5 pass.
- `mix test test/chimeway/signal_test.exs` — 5/5 pass (27-01 tests unaffected).
- `mix test --exclude oban` — 353 tests, 0 failures.
- `mix compile` — clean, no warnings from modified files.

## TDD Gate Compliance

Both tasks followed RED → GREEN:

- Task 1: `test(27-02)` commit `239aa1a` (RED) before `feat(27-02)` commit `b3a88d2` (GREEN).
- Task 2: `test(27-02)` commit `9ea4032` (RED) before `feat(27-02)` commit `6ab36b7` (GREEN).

## Known Stubs

None — all routing logic is fully implemented and all tests exercise real database paths.

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes were introduced. The cross-tenant isolation threat T-27-03 (identified in the plan's `<threat_model>`) is mitigated: `find_runs_waiting_for_signal/2` structurally filters by `tenant_id = ^signal.tenant_id`, making cross-tenant signal bleeding impossible without modifying the query itself.

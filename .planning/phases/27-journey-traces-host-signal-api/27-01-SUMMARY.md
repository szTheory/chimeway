---
phase: 27-journey-traces-host-signal-api
plan: 01
subsystem: api
tags: [elixir, ecto, oban, postgres, signals, workflow, state-spine]
requires:
  - phase: 24-workflow-contracts-state-spine
    provides: WorkflowRun aggregate row and workflow_runs table baseline
  - phase: 25-progression-engine-wait-gates
    provides: status_reason/status_context contract on WorkflowRun
provides:
  - State Spine columns on WorkflowRun (tenant_id, suspended_until, pending_signals, terminal_reason)
  - Chimeway.Signals.Signal schema for durable host-submitted facts
  - Chimeway.Signal.track/4 host API boundary
  - Barebones Chimeway.Dispatch.SignalRouterWorker (perform/1 returns {:ok, :noop})
affects: [27-02-signal-router-worker, 27-03-host-trace-inspection, host-app-integration]
tech-stack:
  added: []
  patterns:
    - host API boundary mirrors Chimeway.Trigger: Multi.insert + Oban.insert atomic enqueue
    - State Spine columns evolve WorkflowRun in place; tenant_id required, others optional
key-files:
  created:
    - priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs
    - lib/chimeway/signals/signal.ex
    - lib/chimeway/signal.ex
    - lib/chimeway/dispatch/signal_router_worker.ex
    - test/chimeway/workflows/workflow_run_test.exs
    - test/chimeway/signal_test.exs
  modified:
    - lib/chimeway/workflows/workflow_run.ex
    - lib/chimeway/workflows.ex
key-decisions:
  - "Tenant id is required on every WorkflowRun row, asserted via validate_required; legacy internal callers default to \"default\" until host-supplied tenancy lands."
  - "Signals and the State Spine ship in a single migration so the schema arrives atomically before any downstream worker can be wired."
  - "Chimeway.Signal.track/4 wraps insert + Oban enqueue in one Ecto.Multi so the queued job is rolled back on insert failure — no orphaned signals or jobs."
  - "SignalRouterWorker ships barebones in 27-01 so the API can reference it; full routing logic is owned by 27-02."
patterns-established:
  - "Host API boundary: Multi.new |> Multi.insert(:row, changeset) |> Oban.insert(:job, fn changes -> Worker.new(...) end) |> Repo.transaction (analog of Chimeway.Trigger.do_trigger)"
  - "State Spine evolution: add explicit columns to WorkflowRun rather than packing state into status_context maps — query-friendly, index-friendly, schema-typed"
requirements-completed: [API-01]
duration: ~30 min (resumed after Gemini terminal crash mid-execution)
completed: 2026-04-30
---

# Phase 27 Plan 01: Journey Traces & Host Signal API Summary

**Phase 27-01 introduces the durable host signal API and evolves WorkflowRun with the Authoritative State Spine columns, giving host apps a single `Chimeway.Signal.track/4` entry point that atomically persists a fact and queues it for routing.**

## Performance

- **Duration:** ~30 min (recovery + completion; original Gemini run had partially landed Tasks 0–1 before the terminal crashed)
- **Completed:** 2026-04-30
- **Tasks:** 3 (Task 0 SignalRouterWorker barebones, Task 1 State Spine, Task 2 Signal API)
- **Files created:** 6
- **Files modified:** 2

## Accomplishments

- Added a single Ecto migration that alters `chimeway_workflow_runs` with the four spine columns (`tenant_id` not null, `suspended_until`, `pending_signals` array default `[]`, `terminal_reason`) and creates the `chimeway_signals` table with `(tenant_id, actor_id)` and `(tenant_id, event_name)` indexes.
- Added `tenant_id`, `suspended_until`, `pending_signals`, and `terminal_reason` to the `Chimeway.Workflows.WorkflowRun` schema, with `tenant_id` in `@required_fields` and the rest optional. Internal callers in `Chimeway.Workflows` now pass `tenant_id: "default"` until host-supplied tenancy is wired in a future phase.
- Added `Chimeway.Signals.Signal`, an immutable durable record with `tenant_id`, `actor_id`, `event_name`, `payload :map default: %{}`, mirroring the `Chimeway.Events.Event` analog.
- Added `Chimeway.Signal.track/4`, the host API boundary. It builds an `Ecto.Multi` that inserts the `Signal` then enqueues `Chimeway.Dispatch.SignalRouterWorker` carrying `signal_id`, all inside a single `Repo.transaction/1`.
- `Chimeway.Dispatch.SignalRouterWorker` exists as an Oban worker on the `:signals` queue with `perform/1` returning `{:ok, :noop}` — full routing logic lands in 27-02.
- Added unit tests for the new spine fields (`test/chimeway/workflows/workflow_run_test.exs`, 3 tests) and integration tests for the host API (`test/chimeway/signal_test.exs`, 5 tests) — all 8 pass.

## Task Commits

Each task was committed atomically:

1. **Task 0: SignalRouterWorker barebones** — `739ffa9` (feat) — committed in original Gemini session
2. **Task 1: State Spine columns on WorkflowRun** — `9b468aa` (feat) — committed during recovery
3. **Task 2: Signal model + Chimeway.Signal.track/4 API** — `4ab48f0` (feat) — committed during recovery

## Files Created/Modified

- `priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs` — Adds the four spine columns to `chimeway_workflow_runs` and creates `chimeway_signals` with tenant-scoped indexes.
- `lib/chimeway/workflows/workflow_run.ex` — Schema evolution for the State Spine; `tenant_id` required, the other three optional.
- `lib/chimeway/workflows.ex` — Single one-line addition: pass `tenant_id: "default"` when starting a workflow run from internal callers.
- `lib/chimeway/signals/signal.ex` — Durable signal schema mirroring `Chimeway.Events.Event` (binary_id PK, default `%{}` payload).
- `lib/chimeway/signal.ex` — Host API boundary `track/4` using `Ecto.Multi` + `Oban.insert/2` for atomic insert + enqueue.
- `lib/chimeway/dispatch/signal_router_worker.ex` — Barebones Oban worker on `:signals` queue (perform/1 returns `{:ok, :noop}`).
- `test/chimeway/workflows/workflow_run_test.exs` — Pure changeset tests for the State Spine fields.
- `test/chimeway/signal_test.exs` — Integration tests for `Chimeway.Signal.track/4` (insert, default payload, atomic enqueue, validation error).

## Decisions Made

- **Required `tenant_id`**: chose `validate_required(:tenant_id)` instead of leaving it nullable to force tenancy through every WorkflowRun row from day one. Internal callers pass `"default"` until host-supplied tenancy is plumbed; this keeps existing code green without weakening the contract.
- **Single migration for both Task 1 + Task 2 schema**: keeps the spine columns and `chimeway_signals` table in one atomic up/down so partial schema states cannot exist between tasks.
- **Mirrored `Chimeway.Trigger.do_trigger` Multi shape**: adopted the same `Multi.new |> Multi.insert |> Oban.insert |> Repo.transaction` shape so future readers immediately recognize this as a sibling of the existing host API entry point.
- **SignalRouterWorker barebones in 27-01**: shipping the worker module empty lets `Chimeway.Signal.track/4` reference it without a forward declaration; 27-02 can fill in `perform/1` without touching 27-01's surface.

## Verification

- `mix compile` clean.
- `mix ecto.migrate` rolls forward cleanly (verified at `11:08:51`).
- `mix test test/chimeway/workflows/workflow_run_test.exs` — 3/3 pass.
- `mix test test/chimeway/signal_test.exs` — 5/5 pass.
- `mix test` — 412 tests, 2 failures. Both failures are pre-existing Phase 26-01 RED tests (committed as `f01b2cf test(26-01): add failing test for explicit stops and implicit completions`) that are turned GREEN by the in-progress Phase 26 work currently held in `git stash` (`wip: phase 26-01 escalations/stops + test adjustments`). Not a Phase 27 regression.

## Recovery Notes

Original Gemini terminal crashed mid-execution while running `mix test` inside the `gsd-executor` subagent. State at recovery:

- Task 0 already committed (`739ffa9`).
- Task 1 had migration + schema + `tenant_id: "default"` modification staged as working-copy edits, but no test file written and no commit made.
- Task 2 not started.

Recovery path: stashed unrelated Phase 26-01 working-copy changes (`progression.ex` + 4 test files), wrote the missing TDD test for Task 1, committed Task 1, executed Task 2 TDD (test → impl → commit), wrote this summary, and will restore the Phase 26 stash so the user can resume Phase 26 work in parallel and re-launch `/gsd-execute-phase 27` for 27-02 + 27-03.

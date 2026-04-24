---
phase: 03-async-dispatch-and-policy-hardening
plan: "03-01"
subsystem: dispatch
tags: [oban, async, dispatcher, worker, optional-dep]
dependency_graph:
  - lib/chimeway/dispatch/oban.ex → lib/chimeway/dispatch.ex (@behaviour)
  - lib/chimeway/dispatch/oban_worker.ex → lib/chimeway/deliveries.ex (get_delivery!, record_attempt)
  - lib/chimeway/application.ex → Oban (conditional supervision)
  - test/chimeway/dispatch/oban_test.exs → Oban.Testing
key_files:
  - lib/chimeway/dispatch/oban.ex
  - lib/chimeway/dispatch/oban_worker.ex
  - lib/chimeway/application.ex
  - config/test.exs
  - priv/repo/migrations/20260424093000_create_oban_jobs_tables.exs
  - test/chimeway/dispatch/oban_test.exs
  - guides/flows/oban-integration.md
key_decisions:
  - Job args contain only delivery_id (UUID string) — no payload, no module names (security gate TM-03-01-JOB-ARGS-PAYLOAD)
  - Both Oban modules wrapped in Code.ensure_loaded?(Oban) guard; files always exist on disk
  - Oban started conditionally in Application via oban_child/0 — only when Oban loaded AND configured
  - test.exs configured with testing: :manual so assert_enqueued/refute_enqueued work correctly
  - FailingTestAdapter defined inline in test file to avoid test support clutter
tech_stack: [elixir, oban, ecto, postgresql]
duration: ~18 min
completed_at: "2026-04-24T05:16:14Z"
---

Added the optional Oban-backed async dispatch path with `Chimeway.Dispatch.Oban` and `Chimeway.Dispatch.ObanWorker`, both conditionally compiled behind `Code.ensure_loaded?(Oban)`, with transactional enqueue support and 6 passing tests under `Oban.Testing`.

## Tasks

### 03-01-01: Oban dep + ObanWorker ✅

- Added `{:oban, "~> 2.17", optional: true}` to `mix.exs`
- Created `lib/chimeway/dispatch/oban_worker.ex` behind `Code.ensure_loaded?(Oban)` guard
- Worker: queue `:chimeway_delivery`, `max_attempts: 5`, unique by `delivery_id`
- `perform/1` loads delivery, short-circuits on `[:succeeded, :suppressed, :cancelled]` terminal states, then runs the full dispatch pipeline (transition → adapter call → record_attempt)
- `mix compile --warnings-as-errors` clean

### 03-01-02: Chimeway.Dispatch.Oban ✅

- Created `lib/chimeway/dispatch/oban.ex` behind `Code.ensure_loaded?(Oban)` guard
- `@behaviour Chimeway.Dispatch`, implements `dispatch/2`
- Two enqueue paths: direct `Oban.insert/2` (no multi) and transactional (multi: %Ecto.Multi{} appended with named steps)
- `mix compile --warnings-as-errors` clean

### 03-01-03: Tests and integration guide ✅

- Created Oban migration (`20260424093000_create_oban_jobs_tables.exs`) using `Oban.Migrations.up/down`
- Updated `config/test.exs` with `testing: :manual` Oban config
- Updated `lib/chimeway/application.ex` to conditionally start Oban via `oban_child/0`
- Created `test/chimeway/dispatch/oban_test.exs` with 6 tests under `Oban.Testing`
- Created `guides/flows/oban-integration.md`
- All 6 Oban tests pass; full suite: 79 tests, 0 failures

## Deviations

- **`FailingTestAdapter` placement**: Defined inline at the top of `oban_test.exs` (before the test module) rather than in `test/support/`. The plan permitted this; keeping it local avoids polluting the support namespace for a one-test helper.
- **Oban supervision wiring**: Application.ex was updated to conditionally start Oban when both loaded and configured. This is required for `Oban.insert/2` to work at runtime and in tests but was not explicitly scoped in the plan tasks — treated as an implied prerequisite for tests to pass.
- **Migration needed for test DB**: `MIX_ENV=test mix ecto.migrate` required after dev migration — standard Ecto workflow, no deviation from plan intent.

## Security Gate

- **TM-03-01-JOB-ARGS-PAYLOAD (high)**: PASS — job args contain only `delivery_id` UUID. No payload, metadata, or module names in args. Mitigation check confirmed.
- **TM-03-01-MISSING-OBAN-RUNTIME (medium)**: PASS — guide documents host app must add Oban as non-optional dep.
- **TM-03-01-ORPHANED-JOBS (medium)**: PASS — transactional enqueue via `multi:` option implemented and rollback test passes.

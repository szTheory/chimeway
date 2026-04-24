---
plan: 03-01
phase: 3
title: Build Optional Oban Worker Path and Transactional Enqueue Integration
status: not_started
requirements: [DLVR-04, INTG-03]
depends_on: null
---

# Plan 03-01: Build Optional Oban Worker Path and Transactional Enqueue Integration

## Goal
Introduce a `Chimeway.Dispatch` behaviour with a sync implementation and an optional `Chimeway.Dispatch.ObanWorker` so the caller site is unchanged while Oban-backed async delivery becomes a documented, opt-in seam.

## Context
Phase 2 delivered `notify_deliveries` and `notify_delivery_attempts` schemas, a `Chimeway.Adapters.Channel` behaviour, and a sync execution path that calls adapters directly from the trigger pipeline. Delivery rows are created inside an `Ecto.Multi` during planning. There is no async path, no dispatcher abstraction, and Oban is listed as an optional dependency in `mix.exs` but is not yet used. This plan adds the dispatcher seam and the Oban worker on top of the existing Phase 2 persistence model without changing the in-app or adapter contract.

## Tasks

### Task 1: Define the Chimeway.Dispatch Behaviour and Sync Implementation
**What**: Create `Chimeway.Dispatch` as an Elixir behaviour with a single required callback `dispatch/2` that accepts a `%Chimeway.Delivery{}` struct and a keyword list of options, and returns `{:ok, delivery} | {:error, reason}`. Implement `Chimeway.Dispatch.Sync` as the default — it calls the adapter directly in the current process and persists the resulting attempt row. Wire the application config so `config :chimeway, dispatcher: Chimeway.Dispatch.Sync` is the documented default. Update the Phase 2 trigger pipeline to call `dispatcher().dispatch(delivery, opts)` instead of invoking the adapter inline.

**Where**:
- `lib/chimeway/dispatch.ex` — behaviour definition with `@callback dispatch(Chimeway.Delivery.t(), keyword()) :: {:ok, Chimeway.Delivery.t()} | {:error, term()}`
- `lib/chimeway/dispatch/sync.ex` — `@behaviour Chimeway.Dispatch`; calls adapter, persists attempt via `Chimeway.Deliveries.record_attempt/2`
- `lib/chimeway/trigger.ex` (or equivalent Phase 2 trigger pipeline module) — replace inline adapter call with `dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync); dispatcher.dispatch(delivery, opts)`

**Acceptance criteria**:
- [ ] `Chimeway.Dispatch` defines `@callback dispatch/2` with documented typespec
- [ ] `Chimeway.Dispatch.Sync` passes all existing Phase 2 adapter and delivery tests unchanged
- [ ] Config key `:chimeway, :dispatcher` is documented in module doc with default value
- [ ] `mix test` passes with no regressions

**Done when**: The trigger pipeline routes through `Chimeway.Dispatch.Sync` via the config seam and existing tests confirm no behavioral change.

---

### Task 2: Implement Chimeway.Dispatch.ObanWorker
**What**: Create `Chimeway.Dispatch.ObanWorker` as an Oban worker module that performs a single delivery by `delivery_id`. The worker must: (1) load the delivery row by id, (2) confirm the delivery is still in a dispatchable state (not already succeeded, cancelled, or suppressed), (3) call the relevant adapter, and (4) persist the attempt outcome. Create `Chimeway.Dispatch.Oban` (the dispatcher-behaviour implementation) that, given a `%Chimeway.Delivery{}`, inserts an `ObanWorker` job via `Oban.insert/2` and returns `{:ok, delivery}`. The job args must contain only `delivery_id` (UUID string) — no full payload in args. Guard the entire `Chimeway.Dispatch.ObanWorker` and `Chimeway.Dispatch.Oban` modules behind a compile-time `Code.ensure_loaded?(Oban)` check so the files compile cleanly when Oban is not in the dependency tree.

**Where**:
- `lib/chimeway/dispatch/oban_worker.ex` — `use Oban.Worker, queue: :chimeway_delivery, max_attempts: 5`; `perform/1` callback loads delivery by id, checks state, calls adapter, records attempt
- `lib/chimeway/dispatch/oban.ex` — `@behaviour Chimeway.Dispatch`; `dispatch/2` calls `Oban.insert(Chimeway.Dispatch.ObanWorker.new(%{delivery_id: delivery.id}))` and returns `{:ok, delivery}`

**Acceptance criteria**:
- [ ] `Chimeway.Dispatch.ObanWorker` compiles only when `oban` is present in deps; project still compiles and tests pass when oban is absent
- [ ] Worker queue is named `:chimeway_delivery` and `max_attempts: 5` is set
- [ ] Worker `perform/1` loads delivery by `delivery_id`, skips (returns `:ok`) if delivery is already in a terminal state
- [ ] Worker `perform/1` calls the correct channel adapter and records attempt outcome via `Chimeway.Deliveries.record_attempt/2`
- [ ] `Chimeway.Dispatch.Oban` satisfies the `Chimeway.Dispatch` behaviour and passes a contract test

**Done when**: Setting `config :chimeway, dispatcher: Chimeway.Dispatch.Oban` in test config causes deliveries to enqueue Oban jobs instead of executing inline, verified by a test that asserts `Oban.Test` job presence.

---

### Task 3: Transactional Enqueue and Documentation
**What**: Update `Chimeway.Dispatch.Oban.dispatch/2` to accept an optional `multi: %Ecto.Multi{}` option. When `:multi` is provided, the Oban job insertion is added to the multi as a named step (`:enqueue_delivery_job`) using `Oban.insert(repo, multi, name, changeset)` — keeping job creation in the same DB transaction as delivery row creation. When `:multi` is absent, use `Oban.insert/2` directly. Add a module-level `@moduledoc` to `Chimeway.Dispatch.ObanWorker` explaining the transactional pattern with a code snippet showing `Ecto.Multi` usage. Add a `guides/flows/oban-integration.md` doc page describing: (1) adding Oban to `mix.exs`, (2) setting the dispatcher config, (3) transactional enqueue with `Ecto.Multi`, and (4) queue naming and retry tuning.

**Where**:
- `lib/chimeway/dispatch/oban.ex` — extend `dispatch/2` to thread `multi` option into `Oban.insert/4`
- `lib/chimeway/trigger.ex` — pass the existing delivery-creation `Ecto.Multi` into `dispatcher.dispatch(delivery, multi: multi)` when using the Oban dispatcher
- `guides/flows/oban-integration.md` — new guide file with code samples

**Acceptance criteria**:
- [ ] When called with `multi: multi`, `Chimeway.Dispatch.Oban.dispatch/2` adds the job insert as a named step in the provided `Ecto.Multi` — no separate `Oban.insert` call outside the transaction
- [ ] A test confirms that rolling back the enclosing transaction also prevents the Oban job from being visible
- [ ] Guide page renders via `mix docs` without warnings
- [ ] `mix test` passes

**Done when**: The Oban worker path is fully opt-in, transactionally consistent, and documented with a working guide page.

## Verification
**This plan is complete when**:
- [ ] `Chimeway.Dispatch` behaviour exists with `dispatch/2` callback and is satisfied by both `Chimeway.Dispatch.Sync` and `Chimeway.Dispatch.Oban`
- [ ] Switching `config :chimeway, dispatcher:` between sync and oban changes dispatch behavior without altering callers
- [ ] `Chimeway.Dispatch.ObanWorker` is queue-isolated (`:chimeway_delivery`), idempotent on re-run for terminal deliveries, and skips redundant attempt creation
- [ ] Oban job insertion participates in the same `Ecto.Multi` as delivery row creation
- [ ] Oban integration guide page exists and renders
- [ ] All tasks done conditions are met
- [ ] `mix test` passes for this plan's scope

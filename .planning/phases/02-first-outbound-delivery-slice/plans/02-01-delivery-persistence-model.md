---
plan: 02-01
phase: 2
title: Add Delivery and Attempt Persistence Model plus Lifecycle Transitions
status: not_started
requirements: [DLVR-01, DLVR-02, DLVR-03]
depends_on: null
---

# Plan 02-01: Add Delivery and Attempt Persistence Model plus Lifecycle Transitions

## Goal

Create the `chimeway_deliveries` and `chimeway_delivery_attempts` tables with full state machine enforcement, an idempotent delivery planner, and the `Chimeway.Dispatch` behaviour stub — establishing the persistence foundation that Plans 02-02 and 02-03 (and Phase 3) will build on.

## Context

Phase 1 established `chimeway_events` and `chimeway_notifications`. The trigger pipeline resolves recipients but currently creates no delivery rows. DLVR-01 requires delivery rows per recipient × channel; DLVR-02 requires attempt rows per send call; DLVR-03 requires explicit state classification. Phase 3's Oban path (D-05, D-06, D-08) depends on the `suppression_reason`, `delay_fallback`, and `notification_id` columns being present. To avoid Phase 3 alter migrations, these columns are included now. The `Chimeway.Dispatch` behaviour is stubbed here so the trigger pipeline has a stable call site before the real adapter wiring lands in 02-02.

## Tasks

### Task 1: Migrations for chimeway_deliveries and chimeway_delivery_attempts

**What**: Create two migrations:

1. `create_chimeway_deliveries`: table with columns `id` (UUID PK), `notification_id` (UUID FK → `chimeway_notifications`, not null), `channel` (string, not null), `status` (string, not null, default `"pending"`), `suppression_reason` (string, nullable), `delay_fallback` (boolean, not null, default false), `metadata` (map/jsonb, nullable), `inserted_at`, `updated_at`. Add a unique index on `(notification_id, channel)`.

2. `create_chimeway_delivery_attempts`: table with columns `id` (UUID PK), `delivery_id` (UUID FK → `chimeway_deliveries`, not null), `outcome` (string, not null), `provider_response` (map/jsonb, nullable), `inserted_at`. Add an index on `delivery_id`.

**Where**:
- `priv/repo/migrations/<timestamp>_create_chimeway_deliveries.exs`
- `priv/repo/migrations/<timestamp>_create_chimeway_delivery_attempts.exs`

**Acceptance criteria**:
- [ ] Both migrations run with `mix ecto.migrate` and roll back cleanly with `mix ecto.rollback`
- [ ] Unique index on `(notification_id, channel)` is present in `chimeway_deliveries`
- [ ] FK constraint: inserting a `chimeway_delivery_attempts` row with a non-existent `delivery_id` fails at the DB level
- [ ] `mix test` passes after migration

**Done when**: Both tables exist in the DB and both migrations roll back cleanly.

---

### Task 2: Chimeway.Delivery and Chimeway.DeliveryAttempt Ecto Schemas

**What**: Create the Ecto schemas:

- `Chimeway.Delivery` mapping to `chimeway_deliveries`. Use `Ecto.Enum` for the `status` field with values `[:pending, :dispatched, :succeeded, :failed, :suppressed, :cancelled]`. Add a `changeset/2` that validates required fields (`notification_id`, `channel`, `status`) and validates `status` is a valid enum value. Add `belongs_to :notification, Chimeway.Notification` and `has_many :attempts, Chimeway.DeliveryAttempt`.

- `Chimeway.DeliveryAttempt` mapping to `chimeway_delivery_attempts`. Use `Ecto.Enum` for the `outcome` field with values `[:succeeded, :failed, :bounced, :rejected]`. Add a `changeset/2` validating required fields (`delivery_id`, `outcome`). Add `belongs_to :delivery, Chimeway.Delivery`.

Create `Chimeway.Deliveries` as the public context module with:
- `plan_delivery/2` — creates a delivery row given `notification_id` and `channel`; uses `on_conflict: :nothing` to respect the unique index (idempotent planning)
- `record_attempt/2` — inserts an attempt row and transitions delivery status in a single `Ecto.Multi` transaction
- `get_delivery!/1` — loads delivery by id
- `transition_status/2` — updates delivery `status` via changeset; validates allowed transitions

**Where**:
- `lib/chimeway/delivery.ex` — schema
- `lib/chimeway/delivery_attempt.ex` — schema
- `lib/chimeway/deliveries.ex` — context module

**Acceptance criteria**:
- [ ] `Chimeway.Delivery` schema has all six `status` enum values
- [ ] `Chimeway.DeliveryAttempt` schema has all four `outcome` enum values
- [ ] `Chimeway.Deliveries.plan_delivery/2` called twice with the same `(notification_id, channel)` creates exactly one row (idempotent)
- [ ] `Chimeway.Deliveries.record_attempt/2` inserts the attempt row and updates delivery status in the same transaction
- [ ] Unit tests cover: plan creates row, duplicate plan is idempotent, status transition, attempt recording

**Done when**: Delivery and attempt schemas are operational, and idempotent delivery planning is confirmed by test.

---

### Task 3: Chimeway.Dispatch Behaviour Stub and Trigger Pipeline Wiring

**What**: Define `Chimeway.Dispatch` as an Elixir behaviour with a single required callback:

```elixir
@callback dispatch(delivery :: Chimeway.Delivery.t(), opts :: keyword()) ::
            {:ok, Chimeway.Delivery.t()} | {:error, term()}
```

Create `Chimeway.Dispatch.Sync` as a stub implementation of the behaviour. For now, `dispatch/2` plans delivery rows for all configured channels on the notification, and returns `{:ok, delivery}` without calling any adapter (adapter call lands in 02-02). Wire the trigger pipeline to call `Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync).dispatch(delivery, opts)` at the point after notification creation.

Document the `:chimeway, :dispatcher` config key in `Chimeway.Dispatch` `@moduledoc` with the default value and a note that `Chimeway.Dispatch.Oban` will be the Phase 3 alternative.

**Where**:
- `lib/chimeway/dispatch.ex` — behaviour with `@callback dispatch/2` typespec and `@moduledoc` config docs
- `lib/chimeway/dispatch/sync.ex` — `@behaviour Chimeway.Dispatch`; stub implementation that plans delivery rows and returns `{:ok, delivery}` without adapter call
- `lib/chimeway/trigger.ex` (or equivalent Phase 1 trigger module) — add `dispatcher.dispatch(delivery, opts)` call after notification creation

**Acceptance criteria**:
- [ ] `Chimeway.Dispatch` defines `@callback dispatch/2` with documented typespec
- [ ] `Chimeway.Dispatch.Sync` satisfies the behaviour (no compiler warning)
- [ ] Trigger pipeline routes through `Chimeway.Dispatch.Sync` via the config seam
- [ ] Overriding `config :chimeway, :dispatcher, MyTestDispatcher` in tests allows swap without recompilation
- [ ] Existing Phase 1 tests pass unchanged

**Done when**: The dispatch seam is wired into the trigger pipeline; delivery rows are created on trigger; Phase 1 tests still pass.

## Verification

**This plan is complete when**:
- [ ] `chimeway_deliveries` and `chimeway_delivery_attempts` tables exist with correct columns, constraints, and indexes
- [ ] `suppression_reason` (nullable string) and `delay_fallback` (boolean default false) are present in `chimeway_deliveries` — no Phase 3 alter migration needed
- [ ] `Chimeway.Delivery` uses `Ecto.Enum` for status with all six lifecycle states
- [ ] `Chimeway.Deliveries.plan_delivery/2` is idempotent under duplicate calls (unique index + `on_conflict: :nothing`)
- [ ] `Chimeway.Dispatch` behaviour exists and is satisfied by `Chimeway.Dispatch.Sync`
- [ ] Trigger pipeline creates delivery rows on notification trigger
- [ ] All tasks done conditions are met
- [ ] `mix test` passes for this plan's scope

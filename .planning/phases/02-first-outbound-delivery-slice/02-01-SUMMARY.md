---
phase: 02-first-outbound-delivery-slice
plan: "02-01"
subsystem: delivery-persistence
tags: [delivery, persistence, dispatch, idempotency, migrations]
depends_on: []
key_files:
  - priv/repo/migrations/20260424082833_create_chimeway_deliveries.exs
  - priv/repo/migrations/20260424082834_create_chimeway_delivery_attempts.exs
  - lib/chimeway/delivery.ex
  - lib/chimeway/delivery_attempt.ex
  - lib/chimeway/deliveries.ex
  - lib/chimeway/dispatch.ex
  - lib/chimeway/dispatch/sync.ex
  - lib/chimeway/trigger.ex
  - test/chimeway/deliveries_test.exs
key_decisions:
  - Use Ecto.Enum with plain varchar columns (not Postgres ENUM type) for status/outcome
  - plan_delivery/2 uses on_conflict :nothing for idempotent planning
  - record_attempt/2 atomically inserts attempt row and transitions delivery status in one Ecto.Multi
  - Dispatch called outside notification transaction via dispatch_after_trigger/2 (pitfall 7 avoidance)
  - suppression_reason and delay_fallback present in schema now; semantics activate in Phase 3
duration: "~10 min"
completed_at: "2026-04-24T04:35:00Z"
---

# Plan 02-01 Summary

Established the delivery and attempt persistence foundation for Phase 2: two migrations, three schema/context modules, the dispatch behaviour + sync stub, and a 18-test suite confirming idempotency, atomic attempt recording, and guarded status transitions.

## Task Results

### Task 02-01-01: Migrations
- **Status:** COMPLETE (pre-existing)
- `chimeway_deliveries`: UUID PK, notification_id FK (on_delete: :delete_all), channel, status (varchar default "pending"), suppression_reason (nullable), delay_fallback (boolean default false), metadata (jsonb), timestamps
- `chimeway_delivery_attempts`: UUID PK, delivery_id FK (on_delete: :delete_all), outcome (varchar), provider_response (jsonb), inserted_at only (no updated_at — append-only)
- Unique index `chimeway_deliveries_notification_channel_index` on (notification_id, channel)
- Both migrations apply and roll back cleanly (verified: rollback --step 2 then re-migrate)

### Task 02-01-02: Schemas and Context
- **Status:** COMPLETE (pre-existing)
- `Chimeway.Delivery`: Ecto.Enum status with 6 values (:pending, :dispatched, :succeeded, :failed, :suppressed, :cancelled), FK belongs_to :notification, has_many :attempts
- `Chimeway.DeliveryAttempt`: Ecto.Enum outcome with 4 values (:succeeded, :failed, :bounced, :rejected), no updated_at field, inserted_at via changeset hook
- `Chimeway.Deliveries`: plan_delivery/2 (idempotent via on_conflict :nothing), get_delivery!/1, transition_status/2 (guard table with @allowed_transitions), record_attempt/2 (Ecto.Multi atomic), terminal_states/0 helper, sanitize_metadata/1 inherited pattern
- All 18 deliveries_test.exs tests pass

### Task 02-01-03: Dispatch Behaviour + Trigger Wiring
- **Status:** COMPLETE (pre-existing)
- `Chimeway.Dispatch`: @callback dispatch/2 with typespec, documented config seam and Oban upgrade path
- `Chimeway.Dispatch.Sync`: @behaviour Chimeway.Dispatch, plans :in_app delivery rows per notification, returns {:ok, deliveries}
- `lib/chimeway/trigger.ex`: dispatch_after_trigger/2 called after Repo.transaction returns; uses Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync); dispatch failure logged but does not mask trigger result
- `config/config.exs`: config :chimeway, dispatcher: Chimeway.Dispatch.Sync

## Verification

- [x] mix ecto.migrate — both tables exist
- [x] mix ecto.rollback --step 2 && mix ecto.migrate — rollback/re-apply clean
- [x] mix compile --warnings-as-errors — clean
- [x] mix test test/chimeway/deliveries_test.exs --seed 0 — 18 tests, 0 failures
- [x] mix test --seed 0 — 35 tests, 0 failures (full suite including Phase 1)
- [x] rg "on_conflict: :nothing" lib/chimeway/deliveries.ex — present
- [x] rg "Application.get_env.*dispatcher" lib/chimeway/trigger.ex — present

## Security Gate (ASVS L1, block_on: high)

- [x] TM-02-01-SENSITIVE-MIGRATION (HIGH): sanitize_metadata present in both deliveries.ex and trigger.ex — PASS
- [x] TM-02-01-POSTGRES-ENUM (MEDIUM): Ecto.Enum on varchar columns confirmed; no "create type" or "ENUM" in migrations — PASS
- [x] TM-02-01-IDEMPOTENCY-GAP (HIGH): on_conflict: :nothing in plan_delivery/2 + chimeway_deliveries_notification_channel_index — PASS
- [x] TM-02-01-TRANSACTION-LEAK (MEDIUM): dispatch_after_trigger/2 is called after |> Repo.transaction() pipeline, outside transaction — PASS

## Deviations

None. All code was pre-authored and verified clean. Verification steps confirmed correctness.

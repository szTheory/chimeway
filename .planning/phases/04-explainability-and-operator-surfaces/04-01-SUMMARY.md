---
phase: 04-explainability-and-operator-surfaces
plan: "04-01"
subsystem: traces
tags: [traces, explainability, correlation-id, operator-surfaces]
dependency_graph:
  - lib/chimeway/events/event.ex → priv/repo/migrations/20260424093908_add_correlation_id_to_chimeway_events.exs
  - lib/chimeway/trigger.ex → lib/chimeway/events/event.ex
  - lib/chimeway/traces.ex → lib/chimeway/events/event.ex
  - lib/chimeway/traces.ex → lib/chimeway/traces/explanation.ex
  - lib/chimeway/traces.ex → lib/chimeway/delivery.ex
  - lib/chimeway/traces.ex → lib/chimeway/notifications/notification.ex
tech_stack: [elixir, ecto, postgresql]
key_files:
  - lib/chimeway/traces.ex
  - lib/chimeway/traces/explanation.ex
  - lib/chimeway/events/event.ex
  - lib/chimeway/trigger.ex
  - priv/repo/migrations/20260424093908_add_correlation_id_to_chimeway_events.exs
  - test/chimeway/traces_test.exs
key_decisions:
  - Added `has_many :notifications` to Event schema and `has_many :deliveries` to Notification schema to support preload chains required by Traces context
  - correlation_id resolved from opts first, falls back to Logger.metadata()[:request_id], persisted as nil if absent
  - find_traces_for_recipient/2 uses explicit Ecto join + limit to avoid N+1
  - explain_delivery/1 single preload query: [notification: :event, attempts: []]
duration: ~12 min
completed_at: "2026-04-24T05:42:00Z"
---

Added `Chimeway.Traces` operator query context with `correlation_id` propagation through the trigger pipeline, enabling operators to answer "why wasn't this sent?" via four query shapes over the durable lifecycle spine.

## Tasks

### 04-01-01: correlation_id migration + Event schema + trigger ✅

- Migration `20260424093908_add_correlation_id_to_chimeway_events.exs` adds nullable `correlation_id :string` column with index; reversible via `change`.
- `lib/chimeway/events/event.ex`: added `field :correlation_id, :string` + `@optional_fields ~w(correlation_id)a`; changeset casts it; also added `has_many :notifications, Chimeway.Notifications.Notification` for preload support.
- `lib/chimeway/trigger.ex`: resolves `correlation_id` from `opts[:correlation_id]` (binary), falls back to `Logger.metadata()[:request_id]`, persists on event row.

### 04-01-02: Chimeway.Traces.Explanation + Chimeway.Traces ✅

- `lib/chimeway/traces/explanation.ex`: `defstruct` with all 10 fields and `@type t` typespec.
- `lib/chimeway/traces.ex`: all 4 public functions implemented with no N+1 patterns:
  - `get_trace/1`: Repo.get + Repo.preload (separate SELECT per level)
  - `find_traces_for_recipient/2`: explicit join + limit + preload, supports `notification_key:` and `limit:` opts
  - `find_traces_by_correlation_id/1`: returns list, never error tuple
  - `explain_delivery/1`: single `Repo.one` with `preload: [notification: :event, attempts: []]`; timeline sorted ascending
- **Deviation**: Added `has_many :deliveries` to `Chimeway.Notifications.Notification` schema — required for the preload chain in `find_traces_for_recipient/2`. Not in original plan but necessary for Ecto preload to work.

### 04-01-03: Integration tests ✅

- `test/chimeway/traces_test.exs`: 16 tests covering all 4 query functions + all 3 explain scenarios (succeeded, suppressed, failed) + edge cases.
- `mix test test/chimeway/traces_test.exs --seed 0`: **16 tests, 0 failures**.
- Full suite: 115 tests, 1 pre-existing flaky failure in `sync_test.exs:70` (async test uses global `Application.put_env`, passes in isolation — not caused by this plan).

## Deviations

1. **has_many :notifications on Event** — added to enable `Repo.preload(event, notifications: ...)` in `get_trace/1`.
2. **has_many :deliveries on Notification** — added to enable `preload: [deliveries: :attempts]` in `find_traces_for_recipient/2`.
   Both are straightforward association additions consistent with the schema design; no data migrations needed.

## Security Gate

- TM-04-01-RECIPIENT-ENUMERATION (medium): Chimeway.Traces is a server-side context, not an HTTP endpoint. Authorization is the host app's responsibility per moduledoc. No change needed.
- TM-04-01-CORRELATION-ID-COLLISIONS (low): Documented in function spec — returns list, never error.
- TM-04-01-N-PLUS-ONE-PERFORMANCE (medium): Confirmed Repo.preload issues separate SELECTs; no cartesian explosion.
- **No high-severity blockers.**

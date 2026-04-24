---
plan: 04-01
phase: 4
title: Implement Trace Query Surfaces and Correlation Helpers for Operator Debugging
status: not_started
requirements: [OPS-01]
depends_on: null
---

# Plan 04-01: Implement Trace Query Surfaces and Correlation Helpers for Operator Debugging

## Goal
Deliver a `Chimeway.Traces` public context that lets operators answer "why wasn't this sent?" by querying the full lifecycle chain (event → notification → delivery → attempt) using durable identifiers, including an `explain_delivery/1` function that returns a structured explanation ready for IEx inspection or a future UI.

## Context
After Phases 1–3, the following tables exist and are fully joinable: `chimeway_events`, `chimeway_notifications`, `chimeway_deliveries`, `chimeway_delivery_attempts`, and `chimeway_notification_preferences`. The delivery lifecycle is complete: deliveries have `status`, `suppression_reason`, and `delay_fallback` fields; attempts have `outcome` and timestamps. OPS-01 requires operators to trace from trigger through policy, delivery planning, and attempt outcomes using durable data — the data exists, Phase 4 adds the query API surface. No LiveView or HTTP endpoint is in scope; ADMN-01/02 are v2.

## Tasks

### Task 1: Add `correlation_id` to Events and Wire Trigger Integration
**What**: Check the `chimeway_events` schema for a `correlation_id` column. If absent, create a migration to add it as a nullable string. Update `Chimeway.Notifier.trigger/3` (or equivalent trigger entry point) to accept a `correlation_id:` option from the caller and persist it on the event row at insert time. Document the integration pattern: host app reads `Logger.metadata()[:request_id]` (or `conn.assigns[:request_id]`) and passes it as `correlation_id:` at trigger time.

**Where**:
- `priv/repo/migrations/<timestamp>_add_correlation_id_to_chimeway_events.exs` — `alter table :chimeway_events add :correlation_id :string` with index on `correlation_id` for lookup performance; skip if already present
- `lib/chimeway/events/event.ex` (Phase 1 schema) — add `field :correlation_id, :string` to schema and changeset cast
- `lib/chimeway/notifier.ex` (or trigger pipeline entry) — accept `correlation_id: string` option; include in event changeset

**Acceptance criteria**:
- [ ] Migration runs with `mix ecto.migrate` and rolls back cleanly
- [ ] `Chimeway.Notifier.trigger(notifier, params, correlation_id: "req-abc")` persists `correlation_id` on the event row
- [ ] Trigger called without `correlation_id:` stores `nil` without error
- [ ] An index exists on `chimeway_events.correlation_id` for query performance

**Done when**: `correlation_id` is persisted on event rows and retrievable by the trace query functions in Task 2.

---

### Task 2: Implement `Chimeway.Traces` Context with Core Query Functions
**What**: Create `Chimeway.Traces` as the public operator-facing query context. Implement four functions:

1. **`get_trace/1`** — accepts `event_id` (UUID string or binary), returns `{:ok, event}` with all associations preloaded: `[notifications: [deliveries: :attempts]]`, or `{:error, :not_found}` if the event does not exist. For large fanouts, preload in batches — do not use a single deeply nested join that produces cartesian rows.

2. **`find_traces_for_recipient/2`** — accepts `recipient_id` and an options keyword list (`notification_key:`, `status:`, `inserted_after:`, `inserted_before:`, `limit:` defaulting to 50). Returns a list of `%Chimeway.Notifications.Notification{}` records with their `deliveries` and the parent `event` preloaded. Uses explicit Ecto joins, not N+1 preloads.

3. **`find_traces_by_correlation_id/1`** — accepts a `correlation_id` string, returns all events with that correlation ID, each preloaded with `[notifications: [deliveries: :attempts]]`. Returns `[]` if none found.

4. **`explain_delivery/1`** — described in Task 3.

**Where**:
- `lib/chimeway/traces.ex` — public context module; all four functions defined here
- `lib/chimeway/traces/explanation.ex` — `Chimeway.Traces.Explanation` struct (or inline in `traces.ex` if it remains small)

**Acceptance criteria**:
- [ ] `get_trace/1` returns `{:ok, event}` with fully preloaded associations or `{:error, :not_found}`; does not produce N+1 queries for single-event lookup
- [ ] `find_traces_for_recipient/2` filters by `notification_key` when provided; respects `limit:` option
- [ ] `find_traces_by_correlation_id/1` returns `[]` for unknown correlation IDs
- [ ] All query functions use `Repo.preload/2` or explicit joins — no N+1 patterns verified in test with `:telemetry` query count assertions or Ecto sandbox inspection
- [ ] Module doc explains each function's use case with example IEx calls

**Done when**: All four function signatures exist and return well-shaped results verified by integration tests seeding the full event → notification → delivery → attempt chain.

---

### Task 3: Implement `explain_delivery/1` with Structured Explanation
**What**: Add `Chimeway.Traces.explain_delivery/1` that accepts a `delivery_id` (UUID) and returns `{:ok, %Chimeway.Traces.Explanation{}}` with a flattened, chronological view of everything that happened to that delivery, or `{:error, :not_found}` when the delivery does not exist. The struct:

```elixir
%Chimeway.Traces.Explanation{
  delivery_id: uuid,
  notification_key: string,
  recipient_id: string,
  channel: atom,
  status: atom,            # :succeeded | :failed | :suppressed | :pending
  suppression_reason: string | nil,
  last_attempt: %{outcome: atom, inserted_at: datetime} | nil,
  event_id: uuid,
  correlation_id: string | nil,
  timeline: [%{at: datetime, event: atom, detail: map}]
}
```

The `timeline` is built from: `{:event_created, event.inserted_at}`, `{:delivery_planned, delivery.inserted_at}`, and one entry per attempt `{:attempt_made, attempt.inserted_at, %{outcome: ...}}`. Timeline entries are sorted ascending by `at`. Returns `{:error, :not_found}` when `delivery_id` does not exist.

**Where**:
- `lib/chimeway/traces/explanation.ex` — `defstruct` with all fields; `@type t :: %__MODULE__{...}` typespec
- `lib/chimeway/traces.ex` — `explain_delivery/1` loads delivery with `[notification: :event, attempts: []]` preload and builds the explanation struct

**Acceptance criteria**:
- [ ] `explain_delivery/1` returns `{:ok, %Chimeway.Traces.Explanation{}}` with correct `:status` for a succeeded delivery
- [ ] For a suppressed delivery, `:status` is `:suppressed`, `:suppression_reason` is populated, `:last_attempt` is `nil`
- [ ] For a failed delivery with one attempt, `:last_attempt` contains `outcome: :failed` and a timestamp
- [ ] `timeline` is sorted chronologically and contains at least `[:event_created, :delivery_planned]` entries for all deliveries
- [ ] `explain_delivery("nonexistent-uuid")` returns `{:error, :not_found}`
- [ ] A test seeding the full suppressed/failed/succeeded scenarios asserts all struct fields

**Done when**: `explain_delivery/1` produces a complete, correct explanation for the suppressed, failed, and succeeded delivery cases verified by an integration test.

## Verification
**This plan is complete when**:
- [ ] `correlation_id` is persisted on event rows and queryable; migration exists and is reversible
- [ ] `Chimeway.Traces.get_trace/1` returns `{:ok, event}` with fully preloaded chain or `{:error, :not_found}`
- [ ] `Chimeway.Traces.find_traces_for_recipient/2` filters by key/status/date and respects limit
- [ ] `Chimeway.Traces.find_traces_by_correlation_id/1` returns matching events or `[]`
- [ ] `Chimeway.Traces.explain_delivery/1` returns `{:ok, %Explanation{}}` for a found delivery and `{:error, :not_found}` for an unknown delivery ID, correctly populated for succeeded, failed, and suppressed cases
- [ ] A support-workflow integration test seeds the full chain and walks through all explanation scenarios
- [ ] No N+1 query patterns in any `Chimeway.Traces` function
- [ ] All tasks done conditions are met
- [ ] `mix test` passes for this plan's scope

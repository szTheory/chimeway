---
plan: 02-02
phase: 2
title: Implement First Outbound Adapter Seam and Outcome Classification
status: not_started
requirements: [DLVR-02, DLVR-03, INTG-01, INTG-02]
depends_on: [02-01]
---

# Plan 02-02: Implement First Outbound Adapter Seam and Outcome Classification

## Goal

Define the `Chimeway.Adapter` behaviour contract, implement two concrete adapters (Test and Logger), and wire the sync dispatcher to call the adapter, record an attempt row, and transition delivery status — proving end-to-end delivery from trigger through attempt outcome.

## Context

After 02-01, `chimeway_deliveries` and `chimeway_delivery_attempts` tables exist, `Chimeway.Deliveries` can plan and record, and `Chimeway.Dispatch.Sync.dispatch/2` is a stub that plans rows but does not call any adapter. This plan replaces the stub body with a real adapter call and attempt recording. The adapter behaviour must be defined before the dispatcher can call it — Task 1 locks the contract, Task 2 implements the adapters, Task 3 wires the dispatcher.

Key constraint: outcome classification (success/failure/bounce/rejection) happens in the dispatcher after the adapter returns, not inside the adapter. Adapters are thin: they know how to send, not how to categorize for Chimeway's state machine.

## Tasks

### Task 1: Define Chimeway.Adapter Behaviour

**What**: Create `Chimeway.Adapter` as an Elixir behaviour with one required callback:

```elixir
@callback deliver(delivery :: Chimeway.Delivery.t(), config :: keyword()) ::
            {:ok, map()} | {:error, atom(), map()}
```

- `{:ok, meta}` — provider accepted; `meta` is a compact map written to `chimeway_delivery_attempts.provider_response`
- `{:error, reason_class, detail}` — provider rejected or call failed; `reason_class` is one of `:temporary | :permanent | :bounced`; `detail` is a compact map (no PII, no full response bodies)

Document the callback contract in `@moduledoc`: adapters must redact sensitive fields before returning `meta` or `detail`. Adapters must not call back into notifier modules to render content — all rendered content must be present on `%Chimeway.Delivery{}` before `deliver/2` is called.

**Where**:
- `lib/chimeway/adapter.ex` — behaviour definition with `@callback deliver/2` typespec and `@moduledoc` describing the contract and redaction requirement

**Acceptance criteria**:
- [ ] `Chimeway.Adapter` defines `@callback deliver/2` with the two-clause return typespec
- [ ] `@moduledoc` documents `:temporary | :permanent | :bounced` reason classes and redaction requirement
- [ ] A module implementing the behaviour with a missing callback produces a compiler warning (Elixir default behaviour)

**Done when**: The `Chimeway.Adapter` behaviour is defined; any module that uses `@behaviour Chimeway.Adapter` and omits `deliver/2` gets a compile-time warning.

---

### Task 2: Implement Chimeway.Adapters.Test and Chimeway.Adapters.Logger

**What**: Implement two adapters that satisfy `@behaviour Chimeway.Adapter`:

**`Chimeway.Adapters.Test`** — in-memory adapter following the Swoosh.Adapters.Test pattern:
- Stores delivered messages in the current process's mailbox (or a named ETS table scoped to the test process) so tests can assert `Chimeway.Adapters.Test.delivered_messages()` returns the delivery structs passed to it
- `deliver/2` always returns `{:ok, %{adapter: "test", delivered_at: DateTime.utc_now()}}`
- Provides a `Chimeway.Adapters.Test.assert_delivered/1` helper that flunks with a readable error if the expected delivery is not found

**`Chimeway.Adapters.Logger`** — structured log adapter:
- `deliver/2` emits a `Logger.info` log with `[chimeway_delivery]` tag, `channel`, `recipient_id` (from delivery), and `notification_key` — no payload content in the log line
- Always returns `{:ok, %{adapter: "logger", logged: true}}`
- No state, no side effects beyond the log line

**Where**:
- `lib/chimeway/adapters/test.ex` — `@behaviour Chimeway.Adapter`; in-memory store + assert helper
- `lib/chimeway/adapters/logger.ex` — `@behaviour Chimeway.Adapter`; structured Logger.info call

**Acceptance criteria**:
- [ ] Both modules satisfy `@behaviour Chimeway.Adapter` (no compiler warnings)
- [ ] `Chimeway.Adapters.Test.deliver/2` stores the delivery and returns `{:ok, meta}`
- [ ] `Chimeway.Adapters.Test.assert_delivered/1` passes when the expected delivery was made and flunks otherwise
- [ ] `Chimeway.Adapters.Logger.deliver/2` emits a Logger.info message and returns `{:ok, meta}`
- [ ] Logger adapter does not include payload content or PII in the log line
- [ ] Unit tests for each adapter: success return shape, storage (Test adapter), log emission (Logger adapter)

**Done when**: Both adapters are implemented, satisfy the behaviour, and have passing unit tests.

---

### Task 3: Wire Sync Dispatcher to Adapter, Outcome Classification, and Attempt Recording

**What**: Replace the `Chimeway.Dispatch.Sync.dispatch/2` stub body with full dispatch logic:

1. Load the delivery row by id (confirm it is in `:pending` or `:dispatched` state; return `:ok` early if already in a terminal state to protect against duplicate dispatch)
2. Transition delivery to `:dispatched` via `Chimeway.Deliveries.transition_status/2`
3. Resolve the adapter module: `Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)`
4. Call `adapter.deliver(delivery, adapter_config)` where `adapter_config` is read via `Application.get_env(:chimeway, [:adapters, channel], [])`
5. Classify the outcome:
   - `{:ok, meta}` → `attempt_outcome: :succeeded`, `delivery_status: :succeeded`
   - `{:error, :temporary, detail}` → `attempt_outcome: :failed`, `delivery_status: :failed`
   - `{:error, :permanent, detail}` → `attempt_outcome: :rejected`, `delivery_status: :failed`
   - `{:error, :bounced, detail}` → `attempt_outcome: :bounced`, `delivery_status: :failed`
6. Call `Chimeway.Deliveries.record_attempt/2` with outcome and provider_response
7. Return `{:ok, updated_delivery}` or `{:error, reason}`

All steps 2–7 must run inside a single `Ecto.Multi` transaction so attempt row and delivery status are atomic.

**Where**:
- `lib/chimeway/dispatch/sync.ex` — replace stub body with full `Ecto.Multi` dispatch pipeline

**Acceptance criteria**:
- [ ] A full trigger → dispatch → attempt cycle creates: one delivery row (`status: succeeded`), one attempt row (`outcome: :succeeded`) when the adapter returns `{:ok, meta}`
- [ ] Adapter returning `{:error, :temporary, detail}` creates: one attempt row (`outcome: :failed`), delivery status `failed`
- [ ] Adapter returning `{:error, :permanent, detail}` creates: attempt row (`outcome: :rejected`), delivery status `failed`
- [ ] Dispatch called on a delivery already in `:succeeded` returns `{:ok, delivery}` without creating a second attempt row
- [ ] Attempt row creation and delivery status transition are atomic (test: if status update fails, attempt row is also rolled back)
- [ ] `mix test` passes

**Done when**: The sync dispatch path is fully wired — trigger creates delivery, sync dispatcher calls adapter, classifies outcome, and persists attempt + final status atomically.

## Verification

**This plan is complete when**:
- [ ] `Chimeway.Adapter` behaviour is defined with `deliver/2` callback and documented return contract
- [ ] `Chimeway.Adapters.Test` and `Chimeway.Adapters.Logger` both satisfy the behaviour
- [ ] `Chimeway.Adapters.Test.assert_delivered/1` helper is usable in ExUnit tests
- [ ] `Chimeway.Dispatch.Sync` is fully wired: adapter call + attempt persistence + status transition in one transaction
- [ ] Outcome classification maps all four adapter return cases to correct attempt outcomes and delivery statuses
- [ ] End-to-end test: trigger notification → delivery row `status: succeeded` → attempt row `outcome: :succeeded`
- [ ] All tasks done conditions are met
- [ ] `mix test` passes for this plan's scope

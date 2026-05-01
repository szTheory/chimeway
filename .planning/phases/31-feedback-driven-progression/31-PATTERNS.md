# Phase 31: Feedback-Driven Progression - Pattern Map

**Mapped:** 2024-05-01
**Files analyzed:** 4
**Analogs found:** 4 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/chimeway/delivery.ex` | model | CRUD | `lib/chimeway/signals/signal.ex` | exact |
| `priv/repo/migrations/*_add_tenant_and_actor_to_chimeway_deliveries.exs` | migration | batch | `priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs` | exact |
| `lib/chimeway/webhooks/process_feedback_worker.ex` | worker | event-driven | `lib/chimeway/webhooks/process_feedback_worker.ex` | self/exact |
| `test/chimeway/webhooks/process_feedback_worker_test.exs` | test | event-driven | `test/chimeway/signal_test.exs` | partial |

## Pattern Assignments

### `lib/chimeway/delivery.ex` (model, CRUD)

**Analog:** `lib/chimeway/signals/signal.ex`

**Schema fields pattern** (lines 19-20):
```elixir
    field(:tenant_id, :string)
    field(:actor_id, :string)
```

**Changeset validation pattern** (lines 35-36):
```elixir
    |> validate_length(:tenant_id, min: 1)
    |> validate_length(:actor_id, min: 1)
```

---

### `priv/repo/migrations/*_add_tenant_and_actor_to_chimeway_deliveries.exs` (migration, batch)

**Analog:** `priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs`

**Three-step column evolution pattern (Add, Backfill, Enforce)** (lines 4-22):
```elixir
    alter table(:chimeway_workflow_runs) do
      add :tenant_id, :string
      # ...
    end

    execute(
      "UPDATE chimeway_workflow_runs SET tenant_id = 'default' WHERE tenant_id IS NULL",
      ""
    )

    alter table(:chimeway_workflow_runs) do
      modify :tenant_id, :string, null: false, from: :string
    end
```

---

### `lib/chimeway/webhooks/process_feedback_worker.ex` (worker, event-driven)

**Analog:** `lib/chimeway/webhooks/process_feedback_worker.ex` (self modification) & `Chimeway.Signal.track/4` API

**Signal emission pattern** (injected into `perform/1`):
```elixir
      # Extract signal arguments
      event_name = "chimeway.delivery.#{outcome}"
      payload = %{delivery_id: delivery.id, status: to_string(outcome)}
      
      # Additional payload fields like error class
      payload = 
        if outcome in [:bounced, :failed] do
          Map.put(payload, :error, to_string(outcome))
        else
          payload
        end

      # Track the signal using denormalized fields on Delivery
      case Chimeway.Signal.track(delivery.tenant_id, delivery.actor_id, event_name, payload) do
        {:ok, _signal} -> :ok
        error -> error
      end
```

---

### `test/chimeway/webhooks/process_feedback_worker_test.exs` (test, event-driven)

**Analog:** `test/chimeway/signal_test.exs`

**Signal testing pattern** (lines 14-31):
```elixir
      assert {:ok, %Signal{} = signal} =
               Chimeway.Signal.track("acme", "user_42", "email_opened", %{"campaign" => "march"})

      assert signal.tenant_id == "acme"
      assert signal.actor_id == "user_42"
      assert signal.event_name == "email_opened"

      assert_enqueued(worker: SignalRouterWorker, args: %{"signal_id" => signal.id})
```

## Shared Patterns

### Direct Signal Emission
**Source:** `Chimeway.Signal.track/4`
**Apply to:** Webhook processing layer
Instead of CDC triggers or PubSub, we invoke the exact same durable transactional API that host applications use. The side effects (database insert + Oban job enqueue) remain atomic.

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| None | N/A | N/A | All mapped |

## Metadata

**Analog search scope:** `lib/chimeway/`, `priv/repo/migrations/`, `test/chimeway/`
**Files scanned:** 5
**Pattern extraction date:** 2024-05-01
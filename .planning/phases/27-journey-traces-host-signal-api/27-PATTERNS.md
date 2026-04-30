# Phase 27: Journey Traces & Host Signal API - Pattern Map

**Mapped:** 2024-05-15
**Files analyzed:** 5
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/chimeway/signal.ex` | service | request-response | `lib/chimeway/trigger.ex` | exact |
| `lib/chimeway/signals/signal.ex` | model | CRUD | `lib/chimeway/events/event.ex` | exact |
| `lib/chimeway/workflows/workflow_run.ex` | model | State Spine | `lib/chimeway/workflows/workflow_run.ex` | exact (modification) |
| `lib/chimeway/dispatch/signal_router_worker.ex` | worker | event-driven | `lib/chimeway/dispatch/deferred_resume_worker.ex` | role-match |
| `lib/chimeway/traces.ex` | service | request-response | `lib/chimeway/traces.ex` | exact (modification) |

## Pattern Assignments

### `lib/chimeway/signal.ex` (service, request-response)

**Analog:** `lib/chimeway/trigger.ex`

**Core Pattern (Transactional insert & enqueue)** (lines 68-80):
Using `Ecto.Multi` to synchronously write a durable row (the signal) and enqueue an async side effect (the Oban router job), just like `trigger` handles events and notifications.

```elixir
        result =
          Multi.new()
          |> Multi.insert(
            :event,
            Event.changeset(%Event{}, %{
              notification_key: notifier.notification_key(),
              notification_version: notifier.version(),
              idempotency_key: idempotency_key,
              payload: sanitize_payload(params),
              correlation_id: correlation_id
            })
          )
          |> Multi.run(:notifications, fn repo, %{event: event} ->
            insert_notifications(repo, notifier, params, event, normalized_recipients)
          end)
          |> Repo.transaction()
```

### `lib/chimeway/signals/signal.ex` (model, CRUD)

**Analog:** `lib/chimeway/events/event.ex`

**Schema Pattern** (lines 13-33):
Use `binary_id` (UUID), cast required/optional fields, and default maps for payloads. Includes indexing and constraint validation.

```elixir
  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "chimeway_events" do
    field(:notification_key, :string)
    field(:notification_version, :integer)
    field(:idempotency_key, :string)
    field(:payload, :map, default: %{})
    field(:correlation_id, :string)

    has_many(:notifications, Chimeway.Notifications.Notification)

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(notification_key notification_version idempotency_key payload)a
  @optional_fields ~w(correlation_id)a

  def changeset(event, attrs) do
    event
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:idempotency_key, name: :chimeway_events_idempotency_key_index)
  end
```

### `lib/chimeway/workflows/workflow_run.ex` (model, State Spine)

**Analog:** Existing `lib/chimeway/workflows/workflow_run.ex`

**Core Pattern (Ecto Schema evolution)** (lines 18-24):
Adding explicit `suspended_reason`, `suspended_until`, `pending_signals` columns to act as the "Authoritative State Spine".

```elixir
    field(:state, Ecto.Enum, values: @state_values, default: :active)
    field(:started_at, :utc_datetime_usec)
    field(:last_transition_at, :utc_datetime_usec)
    field(:status_reason, :string)
    field(:status_context, :map, default: %{})
    
    # Required additions for Phase 27 State Spine:
    # field(:suspended_until, :utc_datetime_usec)
    # field(:pending_signals, {:array, :string}, default: [])
    # field(:tenant_id, :string)
    # field(:terminal_reason, :string)
```

### `lib/chimeway/dispatch/signal_router_worker.ex` (worker, event-driven)

**Analog:** `lib/chimeway/dispatch/deferred_resume_worker.ex`

**Core Pattern (Oban transaction and fan-out)** (lines 24-30):
Receives the target ID from arguments, wraps a `Multi` transaction, handles the domain logic, and explicitly maps out `{:ok, _}` vs `{:error, _}` returns for job completion/retry.

```elixir
    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"delivery_id" => delivery_id}}) do
      Multi.new()
      |> Multi.run(:resume_delivery, resume_delivery_step(delivery_id))
      |> Multi.run(:dispatch_job, &dispatch_job_step/2)
      |> Repo.transaction()
      |> normalize_transaction_result()
    end
```

### `lib/chimeway/traces.ex` (service, query)

**Analog:** `lib/chimeway/traces.ex`

**Core Pattern (Explicit preloading & query functions)** (lines 55-68):
Uses Ecto's `from` queries with explicit `preload` and `where` clauses to query state accurately. Tenancy enforcement will be modeled as the primary filter query similar to `recipient_identity`.

```elixir
  def find_traces_for_recipient(recipient_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    notification_key = Keyword.get(opts, :notification_key)
    repo_opts = Keyword.drop(opts, [:limit, :notification_key])

    query =
      from(n in Notification,
        join: e in Event,
        on: e.id == n.event_id,
        where: n.recipient_identity == ^recipient_id, # Replicate with ^tenant_id
        order_by: [desc: n.inserted_at],
        limit: ^limit,
        preload: [deliveries: :attempts, event: []]
      )
```

## Shared Patterns

### Tenancy and Payload Safety
**Apply to:** All API and query entry points.
- Require `tenant_id` as the primary functional signature argument, ensuring it is passed implicitly into all Ecto filters.
- Payload data must be omitted or sanitized from trace logs unless explicitly passed through a redaction mechanism (analog: `sanitize_payload/1` in `Chimeway.Trigger`).

### Authoritative Persistence First
**Apply to:** The Signal API boundary (`Chimeway.Signal.track`)
- Write the structural database records (e.g. `Chimeway.Signal` and `WorkflowTransition`) within a transaction and immediately return. Push long-running downstream matching or fan-out via Oban workers (Topic-Mapped Event API).

## Metadata

**Analog search scope:** `lib/chimeway/**/*.ex`
**Files scanned:** ~50
**Pattern extraction date:** 2024-05-15

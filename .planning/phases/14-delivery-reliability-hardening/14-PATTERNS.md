# Phase 14: Delivery Reliability Hardening - Pattern Map

**Mapped:** 2026-04-26
**Files analyzed:** 16 (8 lib + 1 migration + 7 test)
**Analogs found:** 16 / 16 — every file has a strong in-repo analog. No external pattern needed.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/chimeway/dispatch/executor.ex` | executor seam (dispatcher) | request-response (sync + Oban) | self (extend `classify/1` in place) | exact |
| `lib/chimeway/dispatch/oban_worker.ex` | worker (Oban) | event-driven (queue) | self (in-place rewrite of `perform/1`) | exact |
| `lib/chimeway/dispatch/sync.ex` | dispatcher | request-response | self (in-place — replace `@terminal_states` list + guard) | exact |
| `lib/chimeway/deliveries.ex` | context module / state machine | CRUD + state transition | self — extend `@allowed_transitions`, add guarded helper modeled on `suppress_delivery/3` (deliveries.ex:128-153) | exact |
| `lib/chimeway/delivery_attempt.ex` | schema + changeset | CRUD (append-only) | self (extend schema with `attempt_number`, `error_class`); whitelist pattern from `Trigger.@sensitive_keys` (trigger.ex:225-227) | exact |
| `lib/chimeway/traces.ex` | query context | request-response | self — `last_attempt_summary/1` (traces.ex:148-153) | exact |
| `lib/chimeway/delivery_planning.ex` | planner | CRUD | self — re-entry contract preserved; module docstring update only | exact |
| `priv/repo/migrations/<ts>_add_attempt_history_columns.exs` | migration (additive) | batch | `priv/repo/migrations/20260424093908_add_correlation_id_to_chimeway_events.exs` | role-match (correlation_id is also additive nullable; this one needs `execute/2` backfill) |
| `test/chimeway/reliability/duplicate_protection_test.exs` | test (concurrency) | request-response | `test/chimeway/idempotency_constraint_test.exs` | exact |
| `test/chimeway/reliability/attempt_history_test.exs` | test | CRUD | `test/chimeway/dispatch/oban_worker_test.exs` (perform_job + DeliveryAttempt assertions) | exact |
| `test/chimeway/reliability/retry_exhaustion_test.exs` | test (Oban retry) | event-driven | `test/chimeway/dispatch/oban_worker_test.exs:127-149` (the test being rewritten under D-13) + `oban_transactional_test.exs` (`assert_enqueued`) | exact |
| `test/chimeway/reliability/terminal_convergence_test.exs` | test (state machine) | request-response | `test/chimeway/dispatch/sync_test.exs` "terminal state guard" describe block + `test/chimeway/deliveries_test.exs` `transition_status` describe | exact |
| `test/chimeway/dispatch/oban_worker_test.exs` (D-13 rewrite) | test (Oban worker) | event-driven | self (rewrite lines 109-149); `oban_transactional_test.exs` for `use Oban.Testing, repo: Chimeway.Repo` and `assert_enqueued/refute_enqueued` idiom | exact |
| `test/chimeway/dispatch/sync_test.exs` (extend) | test | request-response | self — extend "terminal state guard" describe (sync_test.exs:135-156) for permanent/bounced -> :cancelled parity | exact |
| `test/chimeway/deliveries_test.exs` (extend) | test | CRUD | self — extend `transition_status/2` describe (deliveries_test.exs:96+) with `exhaust_delivery/1` cases | exact |
| `test/chimeway/traces_test.exs` (extend) | test | request-response | self — `succeed_delivery/fail_delivery` helpers (traces_test.exs:41-57) | exact |

## Pattern Assignments

### `lib/chimeway/dispatch/executor.ex` (executor seam, request-response)

**Analog:** self — `lib/chimeway/dispatch/executor.ex` (entire file, 34 lines).

**Current shape — `classify/1` returns 2-tuple, drops error_class** (executor.ex:18-33):
```elixir
{attempt_outcome, provider_response} =
  dispatched
  |> adapter.deliver(adapter_config)
  |> classify()

Deliveries.record_attempt(dispatched, %{
  outcome: attempt_outcome,
  provider_response: provider_response
})
# ...
defp classify({:ok, meta}), do: {:succeeded, meta}
defp classify({:error, :temporary, detail}), do: {:failed, detail}
defp classify({:error, :permanent, detail}), do: {:rejected, detail}
defp classify({:error, :bounced, detail}), do: {:bounced, detail}
```

**Pattern to mimic — extend `classify/1` to return 3-tuple `{outcome, error_class, detail}`** (per RESEARCH "Example: Wiring error_class through Executor"):
```elixir
{attempt_outcome, error_class, provider_response} =
  dispatched
  |> adapter.deliver(adapter_config)
  |> classify()

Deliveries.record_attempt(dispatched, %{
  outcome: attempt_outcome,
  error_class: error_class,
  provider_response: provider_response
})

defp classify({:ok, meta}),                     do: {:succeeded, nil,         meta}
defp classify({:error, :temporary, detail}),    do: {:failed,    "temporary", detail}
defp classify({:error, :permanent, detail}),    do: {:rejected,  "permanent", detail}
defp classify({:error, :bounced, detail}),      do: {:bounced,   "bounced",   detail}
```

**Adapter return contract** to preserve verbatim (adapter.ex:26-31):
```elixir
@callback deliver(delivery :: Chimeway.Delivery.t(), config :: keyword()) ::
            {:ok, map()} | {:error, atom(), map()}
# reason_class MUST be one of :temporary | :permanent | :bounced
```

**Key constraint:** The two-tuple return shape from `Executor.run_delivery/1` (`{:ok, %{delivery, attempt}}` or `{:error, step, reason, changes}` or `{:error, term()}`) is consumed by both `oban_worker.ex:76-86` and `sync.ex:84-95`. Phase 14 must NOT change the outer return shape — only what `record_attempt` writes inside.

---

### `lib/chimeway/dispatch/oban_worker.ex` (worker, event-driven)

**Analog:** self — `lib/chimeway/dispatch/oban_worker.ex` (entire file, 88 lines).

**Module use + worker config to preserve** (oban_worker.ex:29-32):
```elixir
use Oban.Worker,
  queue: :chimeway_delivery,
  max_attempts: 5,
  unique: [fields: [:args], keys: [:delivery_id], period: 60]
```

**Current `perform/1` — returns `:ok` even on failure (the bug)** (oban_worker.ex:40-60):
```elixir
@impl Oban.Worker
def perform(%Oban.Job{args: %{"delivery_id" => delivery_id}}) do
  delivery = Deliveries.get_delivery!(delivery_id)

  if delivery.status in @terminal_states do
    :ok
  else
    Telemetry.span(
      [:dispatch, :perform],
      Telemetry.safe_meta(%{
        delivery_id: delivery.id,
        channel: delivery.channel,
        notification_key: Map.get(delivery.metadata || %{}, "notification_key")
      }),
      fn ->
        result = dispatch_delivery(delivery)
        {result, %{}}
      end
    )
  end
end
```

**Pattern to mimic — pull `attempt`/`max_attempts` from `%Oban.Job{}`, use `Deliveries.terminal_states()` (D-09), map adapter outcome to retry/success/exhaust** (per RESEARCH Pattern 1 + Pattern 2):
```elixir
@impl Oban.Worker
def perform(%Oban.Job{args: %{"delivery_id" => delivery_id}, attempt: attempt, max_attempts: max_attempts}) do
  delivery = Deliveries.get_delivery!(delivery_id)

  if delivery.status in Deliveries.terminal_states() do
    :ok
  else
    Telemetry.span(
      [:dispatch, :perform],
      Telemetry.safe_meta(%{
        delivery_id: delivery.id,
        channel: delivery.channel,
        notification_key: Map.get(delivery.metadata || %{}, "notification_key")
      }),
      fn ->
        result = handle_attempt(delivery, attempt, max_attempts)
        {result, %{}}
      end
    )
  end
end

# {:ok, _}            -> :ok
# {:terminal, _}      -> :ok           (permanent/bounced — record_attempt already wrote :cancelled)
# {:retry, reason} when attempt < max_attempts  -> {:error, reason}   (Oban schedules retry)
# {:retry, reason} when attempt == max_attempts -> exhaust + :ok
```

**Telemetry metadata pattern (Phase 10) to preserve verbatim**: `delivery_id`, `channel`, `notification_key` via `Telemetry.safe_meta/1`. New retry/exhaustion spans must keep this shape — D-15.

**`@terminal_states` line to delete** (oban_worker.ex:38): replace all references with `Deliveries.terminal_states()`. Note: this is *not* in a `when` guard here (it's an `if` expression), so the swap is a one-line replacement. (Pitfall 6 only matters in sync.ex.)

---

### `lib/chimeway/dispatch/sync.ex` (dispatcher, request-response)

**Analog:** self — `lib/chimeway/dispatch/sync.ex` (entire file, 99 lines).

**Current — `when status in @terminal_states` GUARD form** (sync.ex:25, 57-59):
```elixir
@terminal_states [:succeeded, :suppressed, :cancelled]
# ...
defp dispatch_delivery(%{status: status} = delivery) when status in @terminal_states do
  {:ok, delivery}
end

defp dispatch_delivery(delivery) do
  case Policy.evaluate(delivery, check_read_state: delivery.delay_fallback) do
    {:suppress, reason} -> Deliveries.suppress_delivery(delivery, reason, checkpoint: :perform)
    {:ok, :proceed} -> do_dispatch_with_telemetry(delivery)
  end
end
```

**Pattern to mimic — convert `when` guard to `if` (Pitfall 6 — `Deliveries.terminal_states/0` is a function call and cannot be used in `when`)** (per RESEARCH "Example: Promoted terminal_states/0 usage in sync.ex"):
```elixir
# Delete @terminal_states line.
defp dispatch_delivery(%{status: status} = delivery) do
  if status in Deliveries.terminal_states() do
    {:ok, delivery}
  else
    case Policy.evaluate(delivery, check_read_state: delivery.delay_fallback) do
      {:suppress, reason} -> Deliveries.suppress_delivery(delivery, reason, checkpoint: :perform)
      {:ok, :proceed} -> do_dispatch_with_telemetry(delivery)
    end
  end
end
```

**Constraint:** Sync path does NOT exhaust deliveries (no Oban retries to give up on). For permanent/bounced, the `:cancelled` write happens inside `Deliveries.record_attempt/2` based on `error_class` — see Pitfall 2 / `deliveries.ex` pattern below — so sync converges automatically via the shared seam.

---

### `lib/chimeway/deliveries.ex` (context module, state machine)

**Analog:** self — `lib/chimeway/deliveries.ex`, particularly `suppress_delivery/3` (deliveries.ex:128-153) and `record_attempt/2` (deliveries.ex:163-213).

**`@terminal_states` already present — promote it (D-09)** (deliveries.ex:15-21):
```elixir
@terminal_states [:succeeded, :suppressed, :cancelled]

@doc """
Returns the list of terminal delivery states — used by the dispatcher (Plan 02-02)
to short-circuit dispatch for already-terminal deliveries.
"""
def terminal_states, do: @terminal_states
```
Phase 14 keeps this exact list and helper. The audit "orphan" finding is closed because `sync.ex` and `oban_worker.ex` start calling it.

**`@allowed_transitions` — current** (deliveries.ex:23-27):
```elixir
@allowed_transitions %{
  pending: [:dispatched, :suppressed, :cancelled],
  dispatched: [:succeeded, :failed, :suppressed],
  failed: [:dispatched]
}
```

**Pattern to mimic — widen `failed` row, add `exhaust_delivery/1` modeled on `suppress_delivery/3`** (per RESEARCH Pattern 5; mimics deliveries.ex:128-153):
```elixir
@allowed_transitions %{
  pending: [:dispatched, :suppressed, :cancelled],
  dispatched: [:succeeded, :failed, :suppressed],
  failed: [:dispatched, :cancelled]   # <-- D-10
}

@doc """
Transitions a `:failed` delivery to `:cancelled` with `suppression_reason: "retries_exhausted"`.
ONLY entry point for `failed -> cancelled`. Must be called exclusively from
`Chimeway.Dispatch.ObanWorker.perform/1` when `job.attempt == job.max_attempts`.
"""
@spec exhaust_delivery(Delivery.t()) :: {:ok, Delivery.t()} | {:error, term()}
def exhaust_delivery(%Delivery{status: :failed} = delivery) do
  metadata =
    delivery.metadata
    |> ensure_metadata_map()
    |> Map.put("policy_checkpoint", "perform")

  delivery
  |> change(status: :cancelled, suppression_reason: "retries_exhausted", metadata: metadata)
  |> Repo.update()
end

def exhaust_delivery(%Delivery{status: status}),
  do: {:error, {:invalid_exhaust_from, status}}
```
Note: pattern matches `suppress_delivery/3` (deliveries.ex:134-153) verbatim — `ensure_metadata_map`, `Map.put("policy_checkpoint", checkpoint)`, `change/2 |> Repo.update()`.

**`record_attempt/2` — current shape** (deliveries.ex:163-213): wraps `Multi.insert(:attempt) |> Multi.run(:delivery, transition_status(...))` inside `Telemetry.span/3`.

**Pattern to mimic — extend `record_attempt/2` with `attempt_number` step + `error_class -> :cancelled` for permanent/bounced** (per RESEARCH Pattern 4 + Pitfall 2):
```elixir
def record_attempt(%Delivery{} = delivery, attrs) do
  Telemetry.span(
    [:attempts, :record],
    Telemetry.safe_meta(%{
      delivery_id: delivery.id,
      channel: delivery.channel,
      notification_key: Map.get(delivery.metadata || %{}, "notification_key")
    }),
    fn ->
      outcome = Map.get(attrs, :outcome) || Map.get(attrs, "outcome")
      error_class = Map.get(attrs, :error_class) || Map.get(attrs, "error_class")

      safe_attrs =
        attrs
        |> Map.update(:provider_response, nil, &sanitize_metadata/1)
        |> Map.put(:delivery_id, delivery.id)

      result =
        Multi.new()
        |> Multi.run(:next_attempt_number, fn repo, _changes ->
          n =
            from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id, select: count(a.id))
            |> repo.one()
            |> Kernel.+(1)
          {:ok, n}
        end)
        |> Multi.insert(:attempt, fn %{next_attempt_number: n} ->
          DeliveryAttempt.changeset(%DeliveryAttempt{}, Map.put(safe_attrs, :attempt_number, n))
        end)
        |> Multi.run(:delivery, fn _repo, _changes ->
          terminal_or_failed_transition(delivery, outcome, error_class)
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{delivery: updated, attempt: attempt}} -> {:ok, %{delivery: updated, attempt: attempt}}
          {:error, step, reason, changes} -> {:error, step, reason, changes}
        end

      extra =
        case result do
          {:ok, %{attempt: attempt}} ->
            Telemetry.safe_meta(%{
              attempt_id: attempt.id,
              outcome: attempt.outcome,
              attempt_number: attempt.attempt_number,
              error_class: attempt.error_class
            })
          _ -> %{}
        end

      {result, extra}
    end
  )
end

# Maps outcome + error_class to the next status. Permanent/bounced go straight to :cancelled
# (sync and Oban both converge here). Temporary stays at :failed so Oban can retry.
defp terminal_or_failed_transition(delivery, :succeeded, _),
  do: transition_status(delivery, :succeeded)
defp terminal_or_failed_transition(delivery, _outcome, "permanent"),
  do: cancel_with_reason(delivery, "permanent_failure")
defp terminal_or_failed_transition(delivery, _outcome, "bounced"),
  do: cancel_with_reason(delivery, "bounced")
defp terminal_or_failed_transition(delivery, _outcome, _error_class),
  do: transition_status(delivery, :failed)
```
Pitfall 3 (concurrent `record_attempt` racing on `attempt_number`): the `dispatched -> failed/succeeded` transition step in the same multi already serializes via the row update. D-14 concurrency tests must verify; if they flake, escalate to `for_update: true` on the delivery row.

---

### `lib/chimeway/delivery_attempt.ex` (schema, append-only CRUD)

**Analog:** self — `lib/chimeway/delivery_attempt.ex` (entire file, 41 lines). Whitelist pattern from `Deliveries.@sensitive_keys` (deliveries.ex:215) is the in-repo idiom for `@error_classes`.

**Current schema** (delivery_attempt.ex:15-31):
```elixir
schema "chimeway_delivery_attempts" do
  field(:outcome, Ecto.Enum, values: [:succeeded, :failed, :bounced, :rejected])
  field(:provider_response, :map)
  field(:inserted_at, :utc_datetime_usec)

  belongs_to(:delivery, Chimeway.Delivery)
end

@required_fields ~w(delivery_id outcome)a
@optional_fields ~w(provider_response)a

def changeset(attempt, attrs) do
  attempt
  |> cast(attrs, @required_fields ++ @optional_fields)
  |> validate_required(@required_fields)
  |> put_inserted_at()
end
```

**Pattern to mimic — add `attempt_number` (required for new rows) + `error_class` (string + whitelist)** (per RESEARCH "Example: DeliveryAttempt changeset whitelist"):
```elixir
@error_classes ~w(temporary permanent bounced)

schema "chimeway_delivery_attempts" do
  field(:outcome, Ecto.Enum, values: [:succeeded, :failed, :bounced, :rejected])
  field(:provider_response, :map)
  field(:attempt_number, :integer)
  field(:error_class, :string)
  field(:inserted_at, :utc_datetime_usec)

  belongs_to(:delivery, Chimeway.Delivery)
end

@required_fields ~w(delivery_id outcome attempt_number)a
@optional_fields ~w(provider_response error_class)a

def changeset(attempt, attrs) do
  attempt
  |> cast(attrs, @required_fields ++ @optional_fields)
  |> validate_required(@required_fields)
  |> validate_inclusion(:error_class, @error_classes)
  |> validate_attempt_number_positive()
  |> put_inserted_at()
end

defp validate_attempt_number_positive(changeset) do
  case get_field(changeset, :attempt_number) do
    n when is_integer(n) and n >= 1 -> changeset
    nil -> changeset
    _ -> add_error(changeset, :attempt_number, "must be a positive integer")
  end
end
```

**Anti-pattern (Phase 11 rule, also called out in RESEARCH "Anti-Patterns to Avoid"):** No `String.to_atom/1` for `error_class`. Stay with string column + changeset whitelist (mirrors `outcome`'s `Ecto.Enum` choice but explicitly chooses string + whitelist for symmetry with how channels are handled).

---

### `lib/chimeway/traces.ex` (query context, request-response)

**Analog:** self — `lib/chimeway/traces.ex`, `last_attempt_summary/1` (traces.ex:148-153).

**Current** (traces.ex:148-153):
```elixir
defp last_attempt_summary([]), do: nil

defp last_attempt_summary(attempts) do
  last = Enum.max_by(attempts, & &1.inserted_at, DateTime)
  %{outcome: last.outcome, inserted_at: last.inserted_at}
end
```

**Pattern to mimic — surface `attempt_number` and `error_class` per D-07** (also affects `Traces.Explanation` struct fields if any):
```elixir
defp last_attempt_summary([]), do: nil

defp last_attempt_summary(attempts) do
  last = Enum.max_by(attempts, & &1.inserted_at, DateTime)
  %{
    outcome: last.outcome,
    inserted_at: last.inserted_at,
    attempt_number: last.attempt_number,
    error_class: last.error_class
  }
end
```

**Also extend timeline entry** (traces.ex:189-192) to include `attempt_number` and `error_class` in the `:attempt_recorded` detail:
```elixir
attempt_entries =
  Enum.map(attempts, fn attempt ->
    %{at: attempt.inserted_at, event: :attempt_recorded,
      detail: %{outcome: attempt.outcome, attempt_number: attempt.attempt_number, error_class: attempt.error_class}}
  end)
```

---

### `lib/chimeway/delivery_planning.ex` (planner — docstring only)

**Analog:** self — `lib/chimeway/delivery_planning.ex`. Re-entry contract is already implemented via `Deliveries.plan_delivery/3`'s `on_conflict: :nothing, conflict_target: [:notification_id, :channel]` (deliveries.ex:66) + reload (deliveries.ex:69-72). No code change needed — only docstring update on `plan_notifications/2` documenting that double-call is safe and returns the existing pending deliveries.

**Idempotent reload pattern to reference in docstring** (deliveries.ex:66-72):
```elixir
|> Repo.insert(on_conflict: :nothing, conflict_target: [:notification_id, :channel])

case result do
  {:ok, _} ->
    {:ok, Repo.get_by!(Delivery, notification_id: notification_id, channel: channel_str)}
  error -> error
end
```

---

### `priv/repo/migrations/<timestamp>_add_attempt_history_columns.exs` (additive migration)

**Analog:** `priv/repo/migrations/20260424093908_add_correlation_id_to_chimeway_events.exs` (12 lines — exact additive-nullable shape). Backfill `execute/2` idiom is from RESEARCH Pattern 3.

**Reference shape** (20260424093908_add_correlation_id_to_chimeway_events.exs:1-11):
```elixir
defmodule Chimeway.Repo.Migrations.AddCorrelationIdToChimewayEvents do
  use Ecto.Migration

  def change do
    alter table(:chimeway_events) do
      add :correlation_id, :string, null: true
    end

    create index(:chimeway_events, [:correlation_id])
  end
end
```

**Pattern to mimic — additive nullable + Postgres `ROW_NUMBER()` backfill + index on `error_class`** (per RESEARCH Pattern 3):
```elixir
defmodule Chimeway.Repo.Migrations.AddAttemptNumberAndErrorClassToChimewayDeliveryAttempts do
  use Ecto.Migration

  def up do
    alter table(:chimeway_delivery_attempts) do
      add :attempt_number, :integer, null: true
      add :error_class, :string, null: true
    end

    execute(
      """
      UPDATE chimeway_delivery_attempts AS a
      SET attempt_number = sub.rn
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY delivery_id ORDER BY inserted_at) AS rn
        FROM chimeway_delivery_attempts
      ) AS sub
      WHERE a.id = sub.id;
      """,
      "UPDATE chimeway_delivery_attempts SET attempt_number = NULL;"
    )

    create index(:chimeway_delivery_attempts, [:error_class])
  end

  def down do
    drop index(:chimeway_delivery_attempts, [:error_class])

    alter table(:chimeway_delivery_attempts) do
      remove :error_class
      remove :attempt_number
    end
  end
end
```

**Important:** `def up`/`def down` instead of `def change` — required because `execute/2` backfill cannot be auto-reversed. Columns stay **nullable at DB level**; the changeset's `validate_required(:attempt_number)` enforces presence on new rows only. Original migration `priv/repo/migrations/20260424082834_create_chimeway_delivery_attempts.exs` confirms `delivery_id` reference shape — no change there.

---

### `test/chimeway/reliability/duplicate_protection_test.exs` (NEW — D-02, D-14)

**Analog:** `test/chimeway/idempotency_constraint_test.exs` (entire 75 lines). This is the canonical concurrency-via-`Task.async_stream`-+-`Sandbox.allow` pattern in the repo.

**Module setup pattern to mimic** (idempotency_constraint_test.exs:1-27):
```elixir
defmodule Chimeway.IdempotencyConstraintTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo
  alias Chimeway.Trigger

  defmodule IdempotentNotifier do
    @behaviour Chimeway.Notifier

    @impl true
    def notification_key, do: "comment.created"
    @impl true
    def version, do: 2
    @impl true
    def recipients(_params),
      do: {:ok, [%{recipient_identity: "user-1", recipient_type: "member"}]}
    @impl true
    def build(_params, _recipient), do: {:ok, %{"topic" => "mentions", "token" => "drop-me"}}
  end
```

**Concurrency idiom to mimic verbatim** (idempotency_constraint_test.exs:49-74) — **THIS is the canonical pattern for D-14**:
```elixir
test "concurrent duplicate triggers still produce one canonical event row" do
  parent = self()

  results =
    1..10
    |> Task.async_stream(
      fn _attempt ->
        Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())

        Trigger.trigger(
          IdempotentNotifier,
          %{"body" => "hello", "secret" => "drop-this"},
          idempotency_key: "concurrent-dup-key"
        )
      end,
      ordered: false,
      max_concurrency: 10,
      timeout: 15_000
    )
    |> Enum.map(fn {:ok, result} -> result end)

  assert Enum.count(results, &match?({:ok, _payload}, &1)) == 1
  assert Enum.count(results, &match?({:duplicate, %Event{}}, &1)) == 9
  assert Repo.aggregate(Event, :count, :id) == 1
  assert Repo.aggregate(Notification, :count, :id) == 1
end
```

**Coverage required by D-02 and D-14** (each its own test using the pattern above):
- (D-02a) `Trigger.fire/...` returning `{:duplicate, event}` on serial re-fire — modeled by `idempotency_constraint_test.exs:29-47`.
- (D-02b) `plan_notifications/2` re-entered for same event returns existing pending deliveries with no duplicate rows — call `DeliveryPlanning.plan_notifications/2` twice; assert `Repo.aggregate(Delivery, :count, :id) == n_channels`.
- (D-02c) sync and Oban dispatch short-circuit against already-terminal deliveries — borrow from `sync_test.exs:135-156` "terminal state guard" + `oban_worker_test.exs:75-105` "terminal state short-circuit".
- (D-02d) Phase 12 atomicity preserved on partial enqueue failure — borrow shape from `oban_transactional_test.exs:44-73` "rollback path" with `failing_multi`.
- (D-14a/b/c) concurrent re-fires of same trigger; concurrent `plan_notifications/2`; concurrent dispatch re-entry — apply Pattern 6 (`Task.async_stream` + `Sandbox.allow`) to each.

**Use `Deliveries.terminal_states/0` membership assertion (D-12), NOT a hardcoded list** (RESEARCH Anti-Pattern):
```elixir
assert delivery.status in Deliveries.terminal_states()
```

---

### `test/chimeway/reliability/attempt_history_test.exs` (NEW — REL-02)

**Analog:** `test/chimeway/dispatch/oban_worker_test.exs` (perform_job + DeliveryAttempt assertions, lines 44-72) and `test/chimeway/traces_test.exs` (`succeed_delivery`/`fail_delivery` helpers, lines 41-57).

**Setup pattern to mimic** (oban_worker_test.exs:23-42):
```elixir
defmodule Chimeway.Reliability.AttemptHistoryTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  @moduletag :oban

  import Chimeway.Test.DispatchHelpers

  alias Chimeway.{Deliveries, DeliveryAttempt, Dispatch.ObanWorker, Repo}

  setup do
    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    end)

    :ok
  end
```

**Attempt-row assertion pattern** (oban_worker_test.exs:53-58 + new fields):
```elixir
attempts = Repo.all(from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id))
assert length(attempts) == 1
[attempt] = attempts
assert attempt.outcome == :failed
assert attempt.error_class == "temporary"
assert attempt.attempt_number == 1
```

---

### `test/chimeway/reliability/retry_exhaustion_test.exs` (NEW — REL-02 end-to-end)

**Analog:** `test/chimeway/dispatch/oban_worker_test.exs:127-149` (the failing-adapter retry test being rewritten under D-13) plus `test/chimeway/dispatch/oban_transactional_test.exs:31-41` (`assert_enqueued` idiom).

**Setup with failing adapter** (oban_worker_test.exs:1-6, 127-149):
```elixir
defmodule Chimeway.Test.RetryFailingAdapter do
  @behaviour Chimeway.Adapter
  @impl true
  def deliver(_delivery, _config), do: {:error, :temporary, %{reason: "test_failure"}}
end

# In the test setup:
Application.put_env(:chimeway, :adapter, Chimeway.Test.RetryFailingAdapter)
%{delivery: delivery} = create_pending_delivery()
```

**Pattern to mimic — `perform_job/3` with `attempt:` option** (per RESEARCH Pattern 7):
```elixir
test "transient failure on attempt 1 returns {:error, _} so Oban retries" do
  Application.put_env(:chimeway, :adapter, Chimeway.Test.RetryFailingAdapter)
  %{delivery: delivery} = create_pending_delivery()

  assert {:error, _reason} = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 1)

  updated = Deliveries.get_delivery!(delivery.id)
  assert updated.status == :failed
  assert updated.suppression_reason == nil

  [attempt] = Repo.all(from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id))
  assert attempt.outcome == :failed
  assert attempt.error_class == "temporary"
  assert attempt.attempt_number == 1
end

test "exhaustion: final attempt writes :cancelled with retries_exhausted" do
  Application.put_env(:chimeway, :adapter, Chimeway.Test.RetryFailingAdapter)
  %{delivery: delivery} = create_pending_delivery()

  # Simulate attempts 1..4 transitioning :failed each time, then attempt 5 = max_attempts.
  # NOTE: Multiple perform_job calls accumulate attempt rows but each one transitions
  # delivery :pending->:dispatched->:failed via the executor seam.
  for n <- 1..4, do: assert {:error, _} = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: n)

  assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 5)

  updated = Deliveries.get_delivery!(delivery.id)
  assert updated.status == :cancelled
  assert updated.suppression_reason == "retries_exhausted"
  assert updated.status in Deliveries.terminal_states()
end
```

**Important on `:ok` vs `{:error, _}` on final attempt** (RESEARCH Pitfall 1 + Pattern 7): on the final attempt return `:ok` after writing `:cancelled` — Oban marks the job `:completed`, not `:discarded`, and operator dashboards stay clean.

---

### `test/chimeway/reliability/terminal_convergence_test.exs` (NEW — D-12)

**Analog:** `test/chimeway/dispatch/sync_test.exs` "terminal state guard" describe (sync_test.exs:135-156) + `test/chimeway/deliveries_test.exs` `transition_status` describe.

**Pattern to mimic — table-driven D-12 coverage; assert `terminal_states/0` membership, never hardcoded list:**
```elixir
@terminal_paths [
  {:succeeded, nil, "ok meta", &assert_succeeded/1},
  {:cancelled, "retries_exhausted", "5x temporary", &assert_exhausted/1},
  {:cancelled, "permanent_failure", "1x permanent", &assert_permanent/1},
  {:cancelled, "bounced", "1x bounced", &assert_bounced/1},
  {:suppressed, "channel_disabled", "policy", &assert_suppressed/1},
  {:cancelled, nil, "manual cancel", &assert_manual_cancel/1}
]

for {expected_status, expected_reason, label, fixture_fn} <- @terminal_paths do
  test "delivery converges to terminal state #{expected_status}/#{expected_reason || "nil"} via #{label}" do
    delivery = unquote(fixture_fn).()

    assert delivery.status == unquote(expected_status)
    assert delivery.suppression_reason == unquote(expected_reason)
    assert delivery.status in Deliveries.terminal_states()
  end
end
```

---

### `test/chimeway/dispatch/oban_worker_test.exs` (D-13 rewrite)

**Analog:** self — replace lines 109-149 ("adapter error path and retry" describe). Keep lines 1-107 + 152+ untouched.

**Lines to delete** (oban_worker_test.exs:127-149) — manual two-step adapter swap:
```elixir
test "retries failed delivery and succeeds with two attempts" do
  Application.put_env(:chimeway, :adapter, Chimeway.Test.ObanWorkerFailingAdapter)
  # ...
  assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
  Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
  assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
  # ...
end
```

**Pattern to mimic — `perform_job/3 attempt:` pattern from `oban_transactional_test.exs:31-41` plus RESEARCH Pattern 7:**
- Use `assert_enqueued(worker: ObanWorker, args: %{delivery_id: ...})` after `Oban.insert/1` for queue-level assertions.
- Use `perform_job(ObanWorker, %{delivery_id: id}, attempt: N)` for in-band attempt simulation.
- Optionally use `Oban.drain_queue(queue: :chimeway_delivery, with_scheduled: true, with_recursion: true)` for end-to-end retry — but RESEARCH Open Question 2 says this requires verification; prefer `perform_job/3 attempt:` as the primary tool.

---

### `test/chimeway/dispatch/sync_test.exs` (extend)

**Analog:** self — extend "terminal state guard" describe (sync_test.exs:135-156) and "dispatch/2 with `{:error, :permanent, detail}`" describe (sync_test.exs:93-112).

**Current sync permanent assertion** (sync_test.exs:104-111):
```elixir
assert {:ok, results} = Sync.dispatch([notification], [])
assert [{:ok, delivery}] = results
assert delivery.status == :failed   # <-- after Phase 14 this becomes :cancelled
```

**Pattern to extend — sync convergence parity** (Pitfall 2 — sync path now also writes `:cancelled` for permanent/bounced via `record_attempt`):
```elixir
assert {:ok, [{:ok, delivery}]} = Sync.dispatch([notification], [])
assert delivery.status == :cancelled
assert delivery.suppression_reason == "permanent_failure"  # or "bounced"
assert delivery.status in Deliveries.terminal_states()

[attempt] = Repo.all(from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id))
assert attempt.error_class == "permanent"  # or "bounced"
assert attempt.attempt_number == 1
```

---

### `test/chimeway/deliveries_test.exs` (extend)

**Analog:** self — `transition_status/2` describe (deliveries_test.exs:96+). Add `exhaust_delivery/1` describe alongside.

**Pattern to mimic — fixture from `insert_notification/1` (deliveries_test.exs:10-32), then driver per allowed transition:**
```elixir
describe "exhaust_delivery/1" do
  setup :insert_notification

  test "transitions :failed -> :cancelled with retries_exhausted reason", %{notification: notification} do
    {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)
    {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
    {:ok, %{delivery: failed}} =
      Deliveries.record_attempt(dispatched, %{outcome: :failed, error_class: "temporary"})

    assert {:ok, exhausted} = Deliveries.exhaust_delivery(failed)
    assert exhausted.status == :cancelled
    assert exhausted.suppression_reason == "retries_exhausted"
    assert exhausted.status in Deliveries.terminal_states()
  end

  test "rejects exhaust_delivery from non-:failed status", %{notification: notification} do
    {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)
    assert {:error, {:invalid_exhaust_from, :pending}} = Deliveries.exhaust_delivery(delivery)
  end
end
```

---

### `test/chimeway/traces_test.exs` (extend)

**Analog:** self — `succeed_delivery/1` and `fail_delivery/1` helpers (traces_test.exs:41-57); `last_attempt_summary/1` is exercised indirectly via `explain_delivery/1` (traces_test.exs:65+).

**Pattern to extend — assert new fields surface on `last_attempt`:**
```elixir
test "explain_delivery surfaces attempt_number and error_class on last_attempt" do
  event = insert_event()
  notification = insert_notification(event)
  delivery = plan_delivery(notification)

  {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
  {:ok, %{delivery: failed}} =
    Deliveries.record_attempt(dispatched, %{outcome: :failed, error_class: "temporary"})

  assert {:ok, %Explanation{last_attempt: last}} = Traces.explain_delivery(failed.id)
  assert last.outcome == :failed
  assert last.attempt_number == 1
  assert last.error_class == "temporary"
end
```

---

## Shared Patterns

### Pattern A — Telemetry metadata propagation (Phase 10 — preserve verbatim, D-15)

**Source:** `lib/chimeway/dispatch/oban_worker.ex:49-53`, `lib/chimeway/dispatch/sync.ex:71-75`, `lib/chimeway/deliveries.ex:166-171`.

**Apply to:** Every new telemetry span (retry, exhaust, error_class) added by Phase 14.

```elixir
Telemetry.span(
  [:dispatch, :perform],
  Telemetry.safe_meta(%{
    delivery_id: delivery.id,
    channel: delivery.channel,
    notification_key: Map.get(delivery.metadata || %{}, "notification_key")
  }),
  fn -> ... end
)
```

`correlation_id` and `event_id` propagate through `delivery.metadata` (set by `Deliveries.plan_delivery/3` opts in deliveries.ex:53-55) — must be retained.

### Pattern B — Guarded named transition helper

**Source:** `lib/chimeway/deliveries.ex:128-153` (`suppress_delivery/3`).

**Apply to:** `exhaust_delivery/1` (D-10) — same `change/2 |> Repo.update()` shape, same `metadata |> ensure_metadata_map() |> Map.put("policy_checkpoint", ...)` pattern, same explicit `{:error, ...}` clause for invalid-from-status.

### Pattern C — Idempotent insert with reload

**Source:** `lib/chimeway/deliveries.ex:66-72`.

**Apply to:** None directly in Phase 14 (this is the existing dedup mechanism, locked by D-01) — but referenced in module docstrings on `Trigger.trigger/3`, `Trigger.dispatch_after_trigger/4`, and `DeliveryPlanning.plan_notifications/2` to make the re-entry contract explicit (D-02b, D-03 docs).

```elixir
|> Repo.insert(on_conflict: :nothing, conflict_target: [:notification_id, :channel])

case result do
  {:ok, _} -> {:ok, Repo.get_by!(Delivery, ...)}
  error -> error
end
```

### Pattern D — Concurrency assertion via `Task.async_stream` + `Sandbox.allow`

**Source:** `test/chimeway/idempotency_constraint_test.exs:49-74`.

**Apply to:** All D-14 concurrency tests (`test/chimeway/reliability/duplicate_protection_test.exs`).

```elixir
parent = self()
results =
  1..10
  |> Task.async_stream(
    fn _ ->
      Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
      ...
    end,
    ordered: false, max_concurrency: 10, timeout: 15_000
  )
  |> Enum.map(fn {:ok, r} -> r end)
```

`use Chimeway.DataCase, async: false` is required (matches idempotency_constraint_test.exs:2).

### Pattern E — `Oban.Testing` setup + `perform_job/3 attempt:` option

**Source:** `test/chimeway/dispatch/oban_worker_test.exs:24-42` (setup) and `test/chimeway/dispatch/oban_transactional_test.exs:31-41` (`assert_enqueued`/`refute_enqueued`).

**Apply to:** `oban_worker_test.exs` D-13 rewrite, `retry_exhaustion_test.exs`, any new Oban-driven coverage.

```elixir
use Chimeway.DataCase, async: false
use Oban.Testing, repo: Chimeway.Repo

@moduletag :oban

import Chimeway.Test.DispatchHelpers
```

`perform_job/3` with explicit `attempt: N` simulates Nth execution without queue side effects (RESEARCH Pattern 7 / Assumption A4).

### Pattern F — Whitelist via module attribute + `validate_inclusion`

**Source:** `lib/chimeway/deliveries.ex:215, 237-239` (`@sensitive_keys ~w(...)`). Existing changeset validations elsewhere (e.g., `Delivery.changeset/2` at delivery.ex:37-44) use `validate_required` + `unique_constraint`.

**Apply to:** `DeliveryAttempt.@error_classes ~w(temporary permanent bounced)` + `validate_inclusion(:error_class, @error_classes)` (RESEARCH "Example: DeliveryAttempt changeset whitelist"). Avoids `Ecto.Enum` for symmetry with project's string-channel rule (Phase 11).

### Pattern G — Multi-step record_attempt with nested transition

**Source:** `lib/chimeway/deliveries.ex:163-213`.

**Apply to:** Extended `record_attempt/2` per Phase 14 — adds `:next_attempt_number` step (RESEARCH Pattern 4) and routes outcome/error_class to `:succeeded | :failed | :cancelled` via a private dispatch helper (RESEARCH Pitfall 2).

---

## No Analog Found

None. Every Phase 14 file has a strong in-repo analog. This is consistent with RESEARCH's "Phase 14 introduces zero new dependencies" finding — the work is plumbing across known good substrates.

---

## Metadata

**Analog search scope:**
- `lib/chimeway/` (deliveries.ex, delivery.ex, delivery_attempt.ex, traces.ex, trigger.ex, adapter.ex, delivery_planning.ex)
- `lib/chimeway/dispatch/` (executor.ex, oban_worker.ex, sync.ex)
- `priv/repo/migrations/` (additive-column patterns, especially `20260424093908_add_correlation_id_to_chimeway_events.exs`)
- `test/chimeway/` (idempotency_constraint_test.exs, deliveries_test.exs, traces_test.exs, trigger_pipeline_test.exs)
- `test/chimeway/dispatch/` (oban_worker_test.exs, oban_transactional_test.exs, sync_test.exs)
- `test/support/chimeway/` (dispatch_helpers.ex)

**Files scanned:** 18 analog files read; ~30 directory listings.

**Pattern extraction date:** 2026-04-26

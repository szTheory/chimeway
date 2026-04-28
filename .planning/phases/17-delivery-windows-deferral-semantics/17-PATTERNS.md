# Phase 17: Delivery Windows & Deferral Semantics - Pattern Map

**Mapped:** 2026-04-28
**Files analyzed:** 9 inferred targets
**Analogs found:** 8 / 9

No phase-local `CONTEXT.md` or `RESEARCH.md` was present in `.planning/phases/17-delivery-windows-deferral-semantics/` at mapping time, so this map is derived from the requested planning concerns and the current codebase.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `priv/repo/migrations/*_add_delivery_window_columns_to_chimeway_deliveries.exs` | migration | transform | `priv/repo/migrations/20260426150000_add_attempt_history_columns.exs` | exact |
| `lib/chimeway/delivery.ex` | model | CRUD | `lib/chimeway/delivery.ex` | exact |
| `lib/chimeway/delivery_planning.ex` | service | request-response | `lib/chimeway/delivery_planning.ex` | exact |
| `lib/chimeway/deliveries.ex` | service | CRUD | `lib/chimeway/deliveries.ex` | exact |
| `lib/chimeway/policy.ex` | service | request-response | `lib/chimeway/policy.ex` | exact |
| `lib/chimeway/traces.ex` | service | transform | `lib/chimeway/traces.ex` | exact |
| `lib/chimeway/dispatch/sync.ex` | service | request-response | `lib/chimeway/dispatch/sync.ex` | exact |
| `lib/chimeway/dispatch/oban.ex` / `lib/chimeway/dispatch/oban_worker.ex` | service | event-driven | `lib/chimeway/dispatch/oban.ex`, `lib/chimeway/dispatch/oban_worker.ex` | exact |
| `test/chimeway/**/*delivery_window*_test.exs` | test | contract/integration | `test/chimeway/policy_settings_test.exs`, `test/chimeway/reliability/terminal_convergence_test.exs`, `test/chimeway/integration/delivery_lifecycle_test.exs` | role-match |

## Pattern Assignments

### `priv/repo/migrations/*_add_delivery_window_columns_to_chimeway_deliveries.exs` (migration, transform)

**Primary analog:** [priv/repo/migrations/20260426150000_add_attempt_history_columns.exs](/Users/jon/projects/chimeway/priv/repo/migrations/20260426150000_add_attempt_history_columns.exs:16)

Use the explicit `up/0` + `down/0` shape when adding deferral/window columns that may need backfill or index management.

**Schema-evolution pattern** ([20260426150000_add_attempt_history_columns.exs:16](/Users/jon/projects/chimeway/priv/repo/migrations/20260426150000_add_attempt_history_columns.exs:16)):
```elixir
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
      SELECT id, ROW_NUMBER() OVER (PARTITION BY delivery_id ORDER BY inserted_at, id) AS rn
      FROM chimeway_delivery_attempts
    ) AS sub
    WHERE a.id = sub.id;
    """,
    "UPDATE chimeway_delivery_attempts SET attempt_number = NULL;"
  )

  create index(:chimeway_delivery_attempts, [:error_class])
end
```

**Down migration pattern** ([20260426150000_add_attempt_history_columns.exs:38](/Users/jon/projects/chimeway/priv/repo/migrations/20260426150000_add_attempt_history_columns.exs:38)):
```elixir
def down do
  drop index(:chimeway_delivery_attempts, [:error_class])

  alter table(:chimeway_delivery_attempts) do
    remove :error_class
    remove :attempt_number
  end
end
```

**Creation/index style to preserve** from [priv/repo/migrations/20260424082833_create_chimeway_deliveries.exs](/Users/jon/projects/chimeway/priv/repo/migrations/20260424082833_create_chimeway_deliveries.exs:5) and [priv/repo/migrations/20260425000200_create_chimeway_policy_settings.exs](/Users/jon/projects/chimeway/priv/repo/migrations/20260425000200_create_chimeway_policy_settings.exs:5):
```elixir
create table(:chimeway_deliveries, primary_key: false) do
  add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
  ...
  timestamps(type: :utc_datetime_usec)
end

create unique_index(:chimeway_deliveries, [:notification_id, :channel],
         name: :chimeway_deliveries_notification_channel_index
       )
```

**Planner note:** if delivery windows require backfilling existing rows, copy the Phase 14 pattern: nullable DB columns first, deterministic SQL backfill second, then indexes.

---

### `lib/chimeway/delivery.ex` (model, CRUD)

**Analog:** [lib/chimeway/delivery.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery.ex:16)

Extend the schema by adding stable window/deferral fields next to the existing durable planning fields, and keep validation minimal in the schema.

**Schema pattern** ([delivery.ex:16](/Users/jon/projects/chimeway/lib/chimeway/delivery.ex:16)):
```elixir
schema "chimeway_deliveries" do
  field(:channel, :string)

  field(:status, Ecto.Enum,
    values: [:pending, :dispatched, :succeeded, :failed, :suppressed, :cancelled],
    default: :pending
  )

  field(:suppression_reason, :string)
  field(:delay_fallback, :boolean, default: false)
  field(:metadata, :map)

  belongs_to(:notification, Notification)
  has_many(:attempts, Chimeway.DeliveryAttempt)

  timestamps(type: :utc_datetime_usec)
end
```

**Changeset pattern** ([delivery.ex:34](/Users/jon/projects/chimeway/lib/chimeway/delivery.ex:34)):
```elixir
@required_fields ~w(notification_id channel status)a
@optional_fields ~w(suppression_reason delay_fallback metadata)a

def changeset(delivery, attrs) do
  delivery
  |> cast(attrs, @required_fields ++ @optional_fields)
  |> validate_required(@required_fields)
  |> unique_constraint(:channel,
    name: :chimeway_deliveries_notification_channel_index
  )
end
```

**Planner note:** keep durable explanatory values as plain persisted columns or string metadata, not derived-only runtime state.

---

### `lib/chimeway/delivery_planning.ex` (service, request-response)

**Analog:** [lib/chimeway/delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:32)

Phase 17 delivery-window planning should mirror the current channel fanout planner: resolve inputs first, validate second, persist one delivery per channel, then run planning-time suppression.

**Planner loop pattern** ([delivery_planning.ex:32](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:32)):
```elixir
def plan_notification(%Notification{} = notification, opts \\ []) do
  with {:ok, channels} <- resolve_channels(notification, opts),
       {:ok, delayed_fallback_channels, delayed_fallback_source} <-
         resolve_delayed_fallback_channels(notification, channels, opts) do
    plan_channels(
      notification,
      channels,
      delayed_fallback_channels,
      delayed_fallback_source,
      opts
    )
  end
end
```

**Per-channel persistence pattern** ([delivery_planning.ex:75](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:75)):
```elixir
defp plan_one_channel(notification, channel, delayed_fallback_set, delayed_fallback_source, opts) do
  delay_fallback = MapSet.member?(delayed_fallback_set, channel)
  source = delayed_fallback_source_for(channel, delayed_fallback_set, delayed_fallback_source)

  with {:ok, delivery} <-
         Deliveries.plan_delivery(notification.id, channel,
           delay_fallback: delay_fallback,
           delayed_fallback_source: source,
           notification_key: Keyword.get(opts, :notification_key),
           event_id: Keyword.get(opts, :event_id),
           correlation_id: Keyword.get(opts, :correlation_id)
         ) do
    evaluate_planning_policy(delivery)
  end
end
```

**Validation-before-write pattern** ([delivery_planning.ex:123](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:123), [delivery_planning.ex:179](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:179)):
```elixir
with {:ok, delayed_fallback_channels, source} <-
       delayed_fallback_channels_for(notification, opts),
     :ok <- validate_delayed_fallback_channels(delayed_fallback_channels, channels) do
  {:ok, delayed_fallback_channels, source}
end
```

**Planning-time suppression checkpoint** ([delivery_planning.ex:235](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:235)):
```elixir
defp evaluate_planning_policy(delivery) do
  case Policy.evaluate(delivery, []) do
    {:ok, :proceed} -> {:ok, delivery}
    {:suppress, reason} -> suppress_delivery_at_planning_checkpoint(delivery, reason)
  end
end
```

**Planner note:** delivery windows/deferral should slot into this same planning flow. If a window changes whether work is immediate vs deferred, persist that on the row before dispatch path branching.

---

### `lib/chimeway/deliveries.ex` (service, CRUD)

**Analog:** [lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:35)

This is the main analog for durable planning state, transactional boundaries, and explanation-preserving status writes.

**Idempotent planning write pattern** ([deliveries.ex:43](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:43)):
```elixir
def plan_delivery(notification_id, channel, opts) when is_list(opts) do
  ...
  result =
    %Delivery{}
    |> Delivery.changeset(%{
      notification_id: notification_id,
      channel: channel_str,
      status: :pending,
      delay_fallback: delay_fallback,
      metadata: metadata
    })
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:notification_id, :channel])

  case result do
    {:ok, _} ->
      {:ok, Repo.get_by!(Delivery, notification_id: notification_id, channel: channel_str)}
    error ->
      error
  end
end
```

**Durable explanation metadata pattern** ([deliveries.ex:54](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:54)):
```elixir
metadata =
  opts
  |> Keyword.get(:metadata, %{})
  |> ensure_metadata_map()
  |> Map.put("delayed_fallback_source", delayed_fallback_source)
  |> maybe_put("notification_key", opts[:notification_key])
  |> maybe_put("event_id", opts[:event_id])
  |> maybe_put("correlation_id", opts[:correlation_id])
```

**Suppression checkpoint write pattern** ([deliveries.ex:134](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:134)):
```elixir
def suppress_delivery(%Delivery{} = delivery, reason, opts)
    when is_atom(reason) and is_list(opts) do
  checkpoint =
    opts
    |> Keyword.get(:checkpoint, :perform)
    |> normalize_checkpoint()

  metadata =
    delivery.metadata
    |> ensure_metadata_map()
    |> Map.put("policy_checkpoint", checkpoint)

  delivery
  |> change(
    status: :suppressed,
    suppression_reason: Atom.to_string(reason),
    metadata: metadata
  )
  |> Repo.update()
end
```

**Atomic transaction pattern** for delivery mutation + durable child record ([deliveries.ex:195](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:195), [deliveries.ex:262](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:262)):
```elixir
Multi.new()
|> Multi.run(:lock_delivery, fn repo, _changes ->
  case repo.one(from(d in Delivery, where: d.id == ^delivery.id, lock: "FOR UPDATE")) do
    nil -> {:error, :delivery_not_found}
    locked -> {:ok, locked}
  end
end)
|> Multi.run(:next_attempt_number, fn repo, %{lock_delivery: locked} ->
  next_n =
    from(a in DeliveryAttempt,
      where: a.delivery_id == ^locked.id,
      select: count(a.id)
    )
    |> repo.one()
    |> Kernel.+(1)

  {:ok, next_n}
end)
|> Multi.insert(:attempt, fn %{next_attempt_number: n, lock_delivery: locked} ->
  ...
end)
|> Multi.run(:delivery, fn _repo, %{lock_delivery: locked} ->
  terminal_or_failed_transition(locked, outcome, error_class)
end)
|> Repo.transaction()
```

**Terminal convergence helper pattern** ([deliveries.ex:320](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:320)):
```elixir
defp terminal_or_failed_transition(delivery, _outcome, "permanent"),
  do: cancel_with_reason(delivery, "permanent_failure")

defp terminal_or_failed_transition(delivery, _outcome, "bounced"),
  do: cancel_with_reason(delivery, "bounced")

defp terminal_or_failed_transition(delivery, _outcome, _error_class),
  do: transition_status(delivery, :failed)
```

**Sensitive metadata sanitization pattern** ([deliveries.ex:349](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:349)):
```elixir
@sensitive_keys ~w(password token secret)

defp sanitize_metadata(map) when is_map(map) do
  Enum.reduce(map, %{}, fn {key, value}, acc ->
    if sensitive_key?(key), do: acc, else: Map.put(acc, key, value)
  end)
end
```

**Planner note:** if deferral semantics require changing a delivery from "planned" to "deferred" to "dispatchable", mirror the named-helper pattern used by `suppress_delivery/3` and `exhaust_delivery/1` rather than ad hoc updates.

---

### `lib/chimeway/policy.ex` and `lib/chimeway/policy/settings.ex` (service, request-response)

**Primary analogs:** [lib/chimeway/policy.ex](/Users/jon/projects/chimeway/lib/chimeway/policy.ex:41), [lib/chimeway/policy/settings.ex](/Users/jon/projects/chimeway/lib/chimeway/policy/settings.ex:41)

Use these for delivery-window evaluation and durable suppression/explanation behavior.

**Dual-checkpoint policy evaluation pattern** ([policy.ex:41](/Users/jon/projects/chimeway/lib/chimeway/policy.ex:41)):
```elixir
def evaluate(%Delivery{} = delivery, opts \\ []) do
  Telemetry.span(
    [:policy, :evaluate],
    Telemetry.safe_meta(%{
      delivery_id: delivery.id,
      channel: delivery.channel,
      notification_key: Map.get(delivery.metadata || %{}, "notification_key"),
      category: delivery_category(delivery)
    }),
    fn ->
      check_read_state = Keyword.get(opts, :check_read_state, false)
      result = evaluate_delivery_policy(delivery, check_read_state)
      ...
      {result, extra}
    end
  )
end
```

**Ordered suppression checks pattern** ([policy.ex:72](/Users/jon/projects/chimeway/lib/chimeway/policy.ex:72)):
```elixir
with :ok <- check_channel_preferences(delivery, context),
     :ok <- check_category_preferences(delivery, context),
     :ok <- check_policy_settings(delivery) do
  maybe_check_read_state(delivery, check_read_state)
end
```

**Reason-returning policy contract** ([policy.ex:94](/Users/jon/projects/chimeway/lib/chimeway/policy.ex:94), [policy.ex:129](/Users/jon/projects/chimeway/lib/chimeway/policy.ex:129), [policy.ex:146](/Users/jon/projects/chimeway/lib/chimeway/policy.ex:146)):
```elixir
{:suppress, :channel_disabled}
{:suppress, :category_disabled}
{:suppress, reason}
{:suppress, :already_read}
```

**Settings-backed evaluation pattern** ([policy/settings.ex:42](/Users/jon/projects/chimeway/lib/chimeway/policy/settings.ex:42)):
```elixir
def evaluate(%Delivery{} = delivery) do
  with recipient_id when not is_nil(recipient_id) <- recipient_identity_for(delivery),
       %Setting{} = settings <- get_settings(recipient_id),
       :ok <- maybe_suppress_quiet_hours(settings),
       :ok <- maybe_suppress_delivery_cap(delivery, settings, recipient_id) do
    {:ok, :proceed}
  else
    nil -> {:ok, :proceed}
    {:suppress, reason} -> {:suppress, reason}
  end
end
```

**Window-check logic analog** ([policy/settings.ex:54](/Users/jon/projects/chimeway/lib/chimeway/policy/settings.ex:54), [policy/settings.ex:104](/Users/jon/projects/chimeway/lib/chimeway/policy/settings.ex:104)):
```elixir
defp maybe_suppress_quiet_hours(%Setting{} = settings) do
  case {settings.quiet_hours_start_minute, settings.quiet_hours_end_minute} do
    {nil, nil} -> :ok
    {start_minute, end_minute} ->
      now_minute = DateTime.utc_now().hour * 60 + DateTime.utc_now().minute

      if quiet_hours_now?(now_minute, start_minute, end_minute) do
        {:suppress, :quiet_hours}
      else
        :ok
      end
  end
end
```

**Settings upsert pattern** ([policy/settings.ex:12](/Users/jon/projects/chimeway/lib/chimeway/policy/settings.ex:12)):
```elixir
%Setting{}
|> Setting.changeset(attrs)
|> Repo.insert(
  on_conflict:
    {:replace,
     [
       :quiet_hours_start_minute,
       :quiet_hours_end_minute,
       :delivery_cap_count,
       :delivery_cap_window_minutes,
       :updated_at
     ]},
  conflict_target: [:recipient_id]
)
```

**Planner note:** delivery windows that suppress or defer should return stable reason atoms first, then let `Deliveries` persist stringified reasons plus checkpoint metadata.

---

### `lib/chimeway/traces.ex` (service, transform)

**Analog:** [lib/chimeway/traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:103)

Use this file as the source pattern for all explainability surfaces added in Phase 17.

**Structured explanation API pattern** ([traces.ex:111](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:111)):
```elixir
def explain_delivery(delivery_id, opts \\ []) do
  delivery =
    Repo.one(
      from(d in Delivery,
        where: d.id == ^delivery_id,
        preload: [notification: :event, attempts: []]
      ),
      opts
    )

  case delivery do
    nil ->
      {:error, :not_found}

    %Delivery{notification: notification, attempts: attempts} ->
      event = notification.event
      last_attempt = last_attempt_summary(attempts)
      timeline = build_timeline(event, notification, delivery, attempts)
      ...
      {:ok, explanation}
  end
end
```

**Timeline construction pattern** ([traces.ex:178](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:178)):
```elixir
base = [
  %{at: event.inserted_at, event: :event_created, detail: %{notification_key: event.notification_key}},
  %{at: notification.inserted_at, event: :notification_created, detail: %{recipient_id: notification.recipient_identity}},
  %{at: delivery.inserted_at, event: :delivery_planned, detail: %{channel: delivery.channel}}
]
```

**Durable suppression/cancellation explanation pattern** ([traces.ex:193](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:193), [traces.ex:212](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:212)):
```elixir
detail: %{
  reason: delivery.suppression_reason,
  policy_checkpoint: Map.get(delivery.metadata || %{}, "policy_checkpoint", "unknown"),
  delayed_fallback_source: Map.get(delivery.metadata || %{}, "delayed_fallback_source", "unknown")
}
```

**Last-attempt summarization pattern** ([traces.ex:152](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:152)):
```elixir
case Enum.filter(attempts, &is_integer(&1.attempt_number)) do
  [] ->
    last = Enum.max_by(attempts, & &1.inserted_at, DateTime)
    build_last_attempt_map(last)

  numbered ->
    last = Enum.max_by(numbered, & &1.attempt_number)
    build_last_attempt_map(last)
end
```

**Planner note:** if Phase 17 adds deferred-until timestamps or window-open/window-closed explanations, surface them by extending `timeline` detail maps, not by inventing a separate explanation shape.

---

### `lib/chimeway/dispatch/sync.ex` and `lib/chimeway/dispatch/oban*.ex` (sync vs Oban parity)

**Primary analogs:** [lib/chimeway/dispatch/sync.ex](/Users/jon/projects/chimeway/lib/chimeway/dispatch/sync.ex:26), [lib/chimeway/dispatch/oban.ex](/Users/jon/projects/chimeway/lib/chimeway/dispatch/oban.ex:35), [lib/chimeway/dispatch/oban_worker.ex](/Users/jon/projects/chimeway/lib/chimeway/dispatch/oban_worker.ex:112)

These are the parity-defining implementations for immediate dispatch vs queued dispatch.

**Shared planning first pattern** ([sync.ex:40](/Users/jon/projects/chimeway/lib/chimeway/dispatch/sync.ex:40), [oban.ex:43](/Users/jon/projects/chimeway/lib/chimeway/dispatch/oban.ex:43)):
```elixir
case DeliveryPlanning.plan_notification(notification, opts) do
```
```elixir
base_multi
|> Multi.run(:plan_notifications, &do_plan(notifications, opts, &1, &2))
|> Multi.run(:enqueue_jobs, &do_enqueue(&1, &2))
```

**Perform-time policy parity pattern** ([sync.ex:55](/Users/jon/projects/chimeway/lib/chimeway/dispatch/sync.ex:55), [oban_worker.ex:140](/Users/jon/projects/chimeway/lib/chimeway/dispatch/oban_worker.ex:140)):
```elixir
case Policy.evaluate(delivery, check_read_state: delivery.delay_fallback) do
  {:suppress, reason} ->
    Deliveries.suppress_delivery(delivery, reason, checkpoint: :perform)
```

**Sync execution path** ([sync.ex:69](/Users/jon/projects/chimeway/lib/chimeway/dispatch/sync.ex:69)):
```elixir
Telemetry.span(
  [:dispatch, :sync],
  Telemetry.safe_meta(%{
    delivery_id: delivery.id,
    channel: delivery.channel,
    notification_key: Map.get(delivery.metadata || %{}, "notification_key")
  }),
  fn ->
    result = do_dispatch(delivery)
    outcome = if match?({:ok, _}, result), do: :succeeded, else: :failed
    {result, Telemetry.safe_meta(%{outcome: outcome})}
  end
)
```

**Transactional Oban enqueue pattern** ([oban.ex:43](/Users/jon/projects/chimeway/lib/chimeway/dispatch/oban.ex:43)):
```elixir
multi =
  base_multi
  |> Multi.run(:plan_notifications, &do_plan(notifications, opts, &1, &2))
  |> Multi.run(:enqueue_jobs, &do_enqueue(&1, &2))

handle_transaction_result(Repo.transaction(multi))
```

**Oban worker return-value parity pattern** ([oban_worker.ex:172](/Users/jon/projects/chimeway/lib/chimeway/dispatch/oban_worker.ex:172)):
```elixir
# - succeeded                                       -> :ok
# - permanent/bounced (delivery already :cancelled) -> :ok
# - temporary AND attempt == max_attempts           -> exhaust_delivery + :ok
# - temporary AND attempt < max_attempts            -> {:error, reason}
```

**Planner note:** if delivery windows defer execution into Oban, keep the durable row semantics identical to sync. Only transport differs; policy outcome and persisted explanations must converge.

---

### `test/chimeway/policy_settings_test.exs` (unit/contract test)

**Analog:** [test/chimeway/policy_settings_test.exs](/Users/jon/projects/chimeway/test/chimeway/policy_settings_test.exs:7)

Use this structure for delivery-window policy unit tests.

**Test structure pattern** ([policy_settings_test.exs:7](/Users/jon/projects/chimeway/test/chimeway/policy_settings_test.exs:7)):
```elixir
describe "upsert_settings/1 and get_settings/1" do
  test "creates and fetches a settings row" do
    ...
  end
end

describe "evaluate/1" do
  test "returns {:ok, :proceed} when no settings exist" do
    ...
  end
end
```

**Fixture style** ([policy_settings_test.exs:35](/Users/jon/projects/chimeway/test/chimeway/policy_settings_test.exs:35)):
```elixir
fixture = DispatchHelpers.create_pending_delivery(recipient_identity: "user:no-settings")
assert Settings.evaluate(fixture.delivery) == {:ok, :proceed}
```

**Planner note:** for Phase 17, add one test per reason atom and one no-settings/default-proceed test.

---

### `test/chimeway/reliability/*_test.exs` (reliability/parity test)

**Analog:** [test/chimeway/reliability/terminal_convergence_test.exs](/Users/jon/projects/chimeway/test/chimeway/reliability/terminal_convergence_test.exs:26)

Use this file as the main parity/reliability pattern when deferral semantics must end in a terminal or dispatchable durable state.

**Local adapter stub pattern** ([terminal_convergence_test.exs:1](/Users/jon/projects/chimeway/test/chimeway/reliability/terminal_convergence_test.exs:1)):
```elixir
defmodule ...TemporaryAdapter do
  @behaviour Chimeway.Adapter
  @impl true
  def deliver(_delivery, _config), do: {:error, :temporary, %{reason: "test_failure"}}
end
```

**Oban test harness pattern** ([terminal_convergence_test.exs:39](/Users/jon/projects/chimeway/test/chimeway/reliability/terminal_convergence_test.exs:39)):
```elixir
use Chimeway.DataCase, async: false
use Oban.Testing, repo: Chimeway.Repo

@moduletag :oban
```

**Terminal assertion pattern** ([terminal_convergence_test.exs:72](/Users/jon/projects/chimeway/test/chimeway/reliability/terminal_convergence_test.exs:72)):
```elixir
updated = Deliveries.get_delivery!(delivery.id)
assert updated.status == :cancelled
assert updated.suppression_reason == "retries_exhausted"
assert updated.status in Deliveries.terminal_states()
```

**Planner note:** adapt this into deferral parity tests asserting the same final durable explanation under sync and Oban paths.

---

### `test/chimeway/integration/*_test.exs` (integration/trace test)

**Analog:** [test/chimeway/integration/delivery_lifecycle_test.exs](/Users/jon/projects/chimeway/test/chimeway/integration/delivery_lifecycle_test.exs:89)

This is the closest end-to-end pattern for delivery-window lifecycle, trace, and integration assertions.

**Scenario-per-behavior structure** ([delivery_lifecycle_test.exs:103](/Users/jon/projects/chimeway/test/chimeway/integration/delivery_lifecycle_test.exs:103)):
```elixir
describe "Scenario A: trigger → event → notification → delivery → attempt (in-app)" do
  test "all records in the chain are created and have correct state" do
    ...
  end
end
```

**Fanout durability pattern** ([delivery_lifecycle_test.exs:323](/Users/jon/projects/chimeway/test/chimeway/integration/delivery_lifecycle_test.exs:323)):
```elixir
deliveries = Repo.all(from(d in Delivery, where: d.notification_id == ^notification.id))
assert length(deliveries) == 2
assert MapSet.new(Enum.map(deliveries, & &1.channel)) == MapSet.new(["email", "in_app"])
```

**Persisted planning metadata assertion pattern** ([delivery_lifecycle_test.exs:404](/Users/jon/projects/chimeway/test/chimeway/integration/delivery_lifecycle_test.exs:404)):
```elixir
assert email_delivery.delay_fallback
assert email_delivery.metadata["delayed_fallback_source"] == "notifier"
refute in_app_delivery.delay_fallback
assert in_app_delivery.metadata["delayed_fallback_source"] == "default"
```

**Trace/explainability assertion pattern** ([delivery_lifecycle_test.exs:486](/Users/jon/projects/chimeway/test/chimeway/integration/delivery_lifecycle_test.exs:486), [delivery_lifecycle_test.exs:527](/Users/jon/projects/chimeway/test/chimeway/integration/delivery_lifecycle_test.exs:527)):
```elixir
assert {:ok, %Chimeway.Traces.Explanation{channel: "webhook_partner", timeline: timeline}} =
         Traces.explain_delivery(delivery.id)

assert :delivery_planned in Enum.map(timeline, & &1.event)
```
```elixir
assert {:ok, trace_event} = Traces.get_trace(result.trace.event_id)
events = Traces.find_traces_by_correlation_id(result.trace.correlation_id)
assert MapSet.new(result.trace.delivery_ids) == MapSet.new(durable_delivery_ids)
```

**Planner note:** use one full-stack scenario to prove `trigger -> plan -> defer/dispatch -> trace` with durable row inspection and trace API assertions.

## Shared Patterns

### Ecto schema + migration evolution
**Sources:** [lib/chimeway/delivery.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery.ex:16), [lib/chimeway/policy/settings/setting.ex](/Users/jon/projects/chimeway/lib/chimeway/policy/settings/setting.ex:12), [priv/repo/migrations/20260426150000_add_attempt_history_columns.exs](/Users/jon/projects/chimeway/priv/repo/migrations/20260426150000_add_attempt_history_columns.exs:16)

- Use `timestamps(type: :utc_datetime_usec)` everywhere.
- Keep schema validation simple and durable; push runtime semantics into service modules.
- For additive evolution with backfill/indexes, prefer `up/0` + `down/0`, nullable rollout, explicit `execute/2`, then indexes.

### Delivery planning and transaction boundaries
**Sources:** [lib/chimeway/delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:32), [lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:262), [lib/chimeway/dispatch/oban.ex](/Users/jon/projects/chimeway/lib/chimeway/dispatch/oban.ex:43)

- Resolve and validate planner inputs before per-channel writes.
- Make row creation idempotent with `on_conflict: :nothing` and reload authoritative state.
- Use `Ecto.Multi` for any operation that both records a child row and mutates the delivery.
- Insert Oban work inside the same transaction when dispatch becomes deferred/background.

### Durable suppression and explanation behavior
**Sources:** [lib/chimeway/policy.ex](/Users/jon/projects/chimeway/lib/chimeway/policy.ex:72), [lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:140), [lib/chimeway/traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:193)

- Policy returns `{:suppress, reason_atom}`.
- `Deliveries` persists `suppression_reason` as a string and tags `metadata["policy_checkpoint"]`.
- Trace surfaces read explanation state from the delivery row and metadata, not from logs or Oban job state.

### Sync vs Oban parity
**Sources:** [lib/chimeway/dispatch/sync.ex](/Users/jon/projects/chimeway/lib/chimeway/dispatch/sync.ex:55), [lib/chimeway/dispatch/oban_worker.ex](/Users/jon/projects/chimeway/lib/chimeway/dispatch/oban_worker.ex:140), [lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:320)

- Both paths must run the same perform-time `Policy.evaluate/2`.
- Both paths should converge via `Deliveries` helpers rather than path-specific updates.
- Durable delivery status is the product truth; transport-specific return values only control retries.

### Contract/integration test structure
**Sources:** [test/chimeway/policy_settings_test.exs](/Users/jon/projects/chimeway/test/chimeway/policy_settings_test.exs:33), [test/chimeway/reliability/terminal_convergence_test.exs](/Users/jon/projects/chimeway/test/chimeway/reliability/terminal_convergence_test.exs:66), [test/chimeway/integration/delivery_lifecycle_test.exs](/Users/jon/projects/chimeway/test/chimeway/integration/delivery_lifecycle_test.exs:304)

- Unit tests assert reason atoms directly.
- Reliability tests assert final durable `status` + `suppression_reason`.
- Integration tests assert actual rows, row metadata, and trace API results together.

## No Exact Analog Found

| File/Concern | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/chimeway/*` deferral scheduler logic that computes a future dispatch-at time and intentionally leaves a delivery pending for later execution | service | event-driven | No existing code schedules a future execution timestamp; current closest analogs only cover immediate fanout planning, delayed fallback flags, and transactional Oban enqueue. Use `delivery_planning.ex` + `dispatch/oban.ex` as the composite pattern. |

## Metadata

**Analog search scope:** `lib/chimeway`, `priv/repo/migrations`, `test/chimeway`
**Files scanned:** 15
**Pattern extraction date:** 2026-04-28

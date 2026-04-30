# Phase 22: Recovery & Outcome Analytics - Pattern Map

**Mapped:** 2026-04-28
**Files analyzed:** 7
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/chimeway/deliveries.ex` | service | request-response | `lib/chimeway/deliveries.ex` | exact |
| `lib/chimeway/traces.ex` | service | transform | `lib/chimeway/traces.ex` | exact |
| `lib/chimeway/traces/outcome_summary.ex` | model | transform | `lib/chimeway/traces/explanation.ex` | role-match |
| `test/chimeway/deliveries_test.exs` | test | request-response | `test/chimeway/deliveries_test.exs` | exact |
| `test/chimeway/traces_test.exs` | test | transform | `test/chimeway/traces_test.exs` | exact |
| `test/chimeway/integration/delivery_lifecycle_test.exs` | test | request-response | `test/chimeway/integration/delivery_lifecycle_test.exs` | exact |
| `test/chimeway/orchestration/recovery_test.exs` | test | event-driven | `test/chimeway/orchestration/deferred_resume_test.exs` | role-match |

## Pattern Assignments

### `lib/chimeway/deliveries.ex` (service, request-response)

**Analog:** `lib/chimeway/deliveries.ex`

**Imports and aliases pattern** (lines 9-16):
```elixir
import Ecto.Changeset, only: [change: 2]
import Ecto.Query, only: [from: 2]

alias Chimeway.{Delivery, DeliveryAttempt, Repo}
alias Chimeway.Events.Event
alias Chimeway.Notifications.Notification
alias Chimeway.Telemetry
alias Ecto.Multi
```

**Recoverable row query pattern** (lines 51-68):
```elixir
@spec list_recoverable_deliveries(keyword()) :: [Delivery.t()]
def list_recoverable_deliveries(opts \\ []) when is_list(opts) do
  now =
    opts
    |> Keyword.get(:now, DateTime.utc_now())
    |> normalize_datetime!()

  cutoff = recoverable_cutoff!(now, Keyword.get(opts, :older_than, 60))

  Repo.all(
    from(d in Delivery,
      where:
        d.status == :pending and d.orchestration_state == :ready and d.updated_at <= ^cutoff and
          fragment("?->>? IS NULL", d.metadata, ^"recovered_at"),
      order_by: [asc: d.updated_at, asc: d.inserted_at]
    )
  )
end
```

**In-place claim/update pattern** (lines 74-133):
```elixir
@spec begin_recovery(binary() | Delivery.t(), keyword()) ::
        {:ok, Delivery.t()} | {:noop, Delivery.t()}
def begin_recovery(delivery_or_id, opts \\ [])

def begin_recovery(delivery_id, opts) when is_binary(delivery_id) and is_list(opts) do
  now =
    opts
    |> Keyword.get(:now, DateTime.utc_now())
    |> normalize_datetime!()

  cutoff = recoverable_cutoff!(now, Keyword.get(opts, :older_than, 60))
  source = normalize_recovery_value!("recovery source", Keyword.get(opts, :source, "operator"))
  reason = normalize_recovery_value!("recovery reason", Keyword.get(opts, :reason, "stuck"))
  recovered_at = iso8601_utc_usec(now)

  recovery_query =
    from(d in Delivery,
      where:
        d.id == ^delivery_id and d.status == :pending and d.orchestration_state == :ready and
          d.updated_at <= ^cutoff and fragment("?->>? IS NULL", d.metadata, ^"recovered_at"),
      update: [
        set: [
          metadata:
            fragment(
              """
              jsonb_set(
                jsonb_set(
                  jsonb_set(COALESCE(?, '{}'::jsonb), '{recovery_source}', to_jsonb(?::text), true),
                  '{recovery_reason}',
                  to_jsonb(?::text),
                  true
                ),
                '{recovered_at}',
                to_jsonb(?::text),
                true
              )
              """,
              d.metadata,
              ^source,
              ^reason,
              ^recovered_at
            ),
          updated_at: ^now
        ]
      ]
    )

  {updated_count, _rows} = Repo.update_all(recovery_query, [])
  updated_delivery = get_delivery!(delivery_id)

  if updated_count == 1, do: {:ok, updated_delivery}, else: {:noop, updated_delivery}
end
```

**Dispatcher reuse + tagged outcomes pattern** (lines 146-179):
```elixir
@spec recover_delivery(binary() | Delivery.t(), keyword()) ::
        {:ok, map()} | {:noop, map()} | {:error, term()}
def recover_delivery(delivery_or_id, opts \\ [])

def recover_delivery(delivery_id, opts) when is_binary(delivery_id) and is_list(opts) do
  now =
    opts
    |> Keyword.get(:now, DateTime.utc_now())
    |> normalize_datetime!()

  source = normalize_recovery_value!("recovery source", Keyword.get(opts, :source, "operator"))
  reason = normalize_recovery_value!("recovery reason", Keyword.get(opts, :reason, "stuck"))
  dispatcher = configured_dispatcher()

  case begin_recovery(delivery_id, Keyword.put(opts, :now, now)) do
    {:ok, _claimed_delivery} ->
      case dispatcher.dispatch_delivery(delivery_id, pre_planned: true, post_commit: true) do
        {:ok, dispatched_delivery} ->
          {:ok, recovery_delivery_result(dispatched_delivery, source, reason, now, :dispatched)}

        {:skip, skipped_delivery} ->
          {:noop, recovery_delivery_result(skipped_delivery, source, reason, now, :skipped)}

        {:error, reason_term} ->
          {:error, reason_term}
      end

    {:noop, existing_delivery} ->
      {:noop, recovery_delivery_result(existing_delivery, source, reason, now, :noop)}
  end
end
```

**Closest secondary analog for idempotent row mutation** (lines 578-619):
```elixir
@spec resume_deferred_delivery(binary() | Delivery.t(), keyword()) ::
        {:ok, Delivery.t()} | {:noop, Delivery.t()}
def resume_deferred_delivery(delivery_or_id, opts \\ [])

def resume_deferred_delivery(delivery_id, opts) when is_binary(delivery_id) and is_list(opts) do
  now =
    opts
    |> Keyword.get(:now, DateTime.utc_now())
    |> normalize_datetime!()

  source = normalize_resume_source!(Keyword.get(opts, :source, "scheduled_resume"))
  delivery = get_delivery!(delivery_id)

  metadata =
    delivery.metadata
    |> ensure_metadata_map()
    |> Map.put("resume_source", source)
    |> Map.put("resume_scheduled_at", iso8601_utc_usec(delivery.next_eligible_at))
    |> Map.put("resumed_at", iso8601_utc_usec(now))

  {updated_count, _rows} =
    Repo.update_all(
      from(d in Delivery,
        where:
          d.id == ^delivery_id and d.status == :pending and d.orchestration_state == :deferred and
            not is_nil(d.next_eligible_at) and d.next_eligible_at <= ^now
      ),
      set: [orchestration_state: :ready, metadata: metadata, updated_at: now]
    )
```

### `lib/chimeway/traces.ex` (service, transform)

**Analog:** `lib/chimeway/traces.ex`

**Imports and alias pattern** (lines 31-35):
```elixir
import Ecto.Query

alias Chimeway.{Delivery, Events.Event, Notifications.Notification, Repo}
alias Chimeway.Digests.DigestMembership
alias Chimeway.Traces.Explanation
```

**Existing join-based operator query pattern** (lines 65-88):
```elixir
@spec find_traces_for_recipient(String.t(), keyword()) :: [Notification.t()]
def find_traces_for_recipient(recipient_id, opts \\ []) do
  limit = Keyword.get(opts, :limit, 50)
  notification_key = Keyword.get(opts, :notification_key)
  repo_opts = Keyword.drop(opts, [:limit, :notification_key])

  query =
    from(n in Notification,
      join: e in Event,
      on: e.id == n.event_id,
      where: n.recipient_identity == ^recipient_id,
      order_by: [desc: n.inserted_at],
      limit: ^limit,
      preload: [deliveries: :attempts, event: []]
    )

  query =
    if notification_key do
      from([n, e] in query, where: e.notification_key == ^notification_key)
    else
      query
    end

  Repo.all(query, repo_opts)
end
```

**Aggregate query pattern** (lines 161-243):
```elixir
@spec aggregate_outcomes(keyword()) :: [map()]
def aggregate_outcomes(opts \\ []) do
  repo_opts =
    Keyword.drop(opts, [
      :notification_key,
      :channel,
      :outcomes,
      :inserted_after,
      :inserted_before,
      :updated_after,
      :updated_before
    ])

  base_query =
    from(d in Delivery,
      join: n in Notification,
      on: n.id == d.notification_id,
      join: e in Event,
      on: e.id == n.event_id,
      select: %{
        notification_key: e.notification_key,
        channel: d.channel,
        outcome:
          fragment(
            """
            CASE
              WHEN ? = 'succeeded' THEN 'sent'
              WHEN ? = 'suppressed' THEN 'suppressed'
              WHEN ? = 'pending' AND ? = 'deferred' THEN 'delayed'
              WHEN ? = 'digested' THEN 'digested'
              WHEN ? = 'failed' THEN 'failed'
              WHEN ? = 'cancelled' AND ? = 'retries_exhausted' THEN 'exhausted'
              ELSE NULL
            END
            """,
            d.status,
            d.status,
            d.status,
            d.orchestration_state,
            d.status,
            d.status,
            d.status,
            d.suppression_reason
          )
      }
    )
    |> maybe_filter_notification_key(Keyword.get(opts, :notification_key))
    |> maybe_filter_channel(Keyword.get(opts, :channel))
    |> maybe_filter_delivery_inserted_after(Keyword.get(opts, :inserted_after))
    |> maybe_filter_delivery_inserted_before(Keyword.get(opts, :inserted_before))
    |> maybe_filter_delivery_updated_after(Keyword.get(opts, :updated_after))
    |> maybe_filter_delivery_updated_before(Keyword.get(opts, :updated_before))

  aggregate_query =
    from(row in subquery(base_query),
      where: not is_nil(row.outcome),
      group_by: [row.notification_key, row.channel, row.outcome],
      order_by: [asc: row.notification_key, asc: row.channel, asc: row.outcome],
      select: %{
        notification_key: row.notification_key,
        channel: row.channel,
        outcome: row.outcome,
        count: count(row.outcome)
      }
    )
    |> maybe_filter_aggregate_outcomes(Keyword.get(opts, :outcomes))

  Repo.all(aggregate_query, repo_opts)
end
```

**Explainability/timeline pattern for recovery facts** (lines 284-415, 427-434):
```elixir
defp build_timeline(event, notification, delivery, attempts, digest_context) do
  planning_context = explanation_planning_context(delivery)
  resume_fields = explanation_resume_fields(delivery)
  recovery_fields = explanation_recovery_fields(delivery)

  recovery_entries =
    if recovery_fields.recovered_at do
      [
        %{
          at: recovery_fields.recovered_at,
          event: :recovered,
          detail: %{
            recovery_source: recovery_fields.recovery_source,
            recovery_reason: recovery_fields.recovery_reason,
            recovered_at: recovery_fields.recovered_at
          }
        }
      ]
    else
      []
    end

  (base ++ deferred_entries ++ resumed_entries ++ recovery_entries ++ suppression_entries ++
     cancellation_entries ++ digest_entries ++ attempt_entries)
  |> Enum.sort_by(&timeline_sort_key/1)
end

defp explanation_recovery_fields(%Delivery{} = delivery) do
  metadata = delivery.metadata || %{}

  %{
    recovery_source: metadata_string(metadata, "recovery_source"),
    recovery_reason: metadata_string(metadata, "recovery_reason"),
    recovered_at: metadata_datetime(metadata, "recovered_at")
  }
end
```

### `lib/chimeway/traces/outcome_summary.ex` (model, transform)

**Analog:** `lib/chimeway/traces/explanation.ex`

**Typed result struct pattern** (lines 1-89):
```elixir
defmodule Chimeway.Traces.Explanation do
  @moduledoc """
  Structured explanation of a single delivery.
  """

  @type t :: %__MODULE__{
          delivery_id: String.t(),
          event_id: String.t(),
          correlation_id: String.t() | nil,
          notification_key: String.t(),
          recipient_id: String.t(),
          channel: String.t(),
          status: :succeeded | :failed | :suppressed | :pending | :cancelled | :dispatched,
          suppression_reason: String.t() | nil,
          timeline: [timeline_entry()]
        }

  defstruct [
    :delivery_id,
    :event_id,
    :correlation_id,
    :notification_key,
    :recipient_id,
    :channel,
    :status,
    :suppression_reason,
    :timeline
  ]
end
```

**What to copy if planner introduces a typed aggregate row**
- Keep the module under `Chimeway.Traces.*`, not top-level.
- Use `@type t :: %__MODULE__{...}` plus a minimal `defstruct`.
- Keep fields payload-safe: `notification_key`, `channel`, `outcome`, `count`, plus optional window/filter metadata only if needed.

### `test/chimeway/deliveries_test.exs` (test, request-response)

**Analog:** `test/chimeway/deliveries_test.exs`

**Recovery query assertions pattern** (lines 442-545):
```elixir
test "list_recoverable_deliveries/1 excludes terminal, dispatched, and deferred rows" do
  now = ~U[2026-04-28 18:00:00Z]
  old_time = ~U[2026-04-28 17:45:00Z]

  recoverable_delivery =
    insert_delivery(
      updated_at: old_time,
      inserted_at: old_time,
      status: :pending,
      orchestration_state: :ready
    )

  dispatched_delivery =
    insert_delivery(
      updated_at: old_time,
      inserted_at: old_time,
      status: :dispatched,
      orchestration_state: :ready
    )

  ...

  recoverable_ids =
    Deliveries.list_recoverable_deliveries(now: now, older_than: 60)
    |> Enum.map(& &1.id)

  assert recoverable_delivery.id in recoverable_ids
  refute dispatched_delivery.id in recoverable_ids
  refute deferred_delivery.id in recoverable_ids
  refute succeeded_delivery.id in recoverable_ids
end
```

**Metadata stamping + noop semantics pattern** (lines 548-608):
```elixir
describe "Phase 22 recovery guards" do
  test "begin_recovery/2 stamps recovery metadata on the canonical row" do
    recovered_at = ~U[2026-04-28 18:00:00Z]

    delivery =
      insert_delivery(
        updated_at: ~U[2026-04-28 17:45:00Z],
        inserted_at: ~U[2026-04-28 17:45:00Z],
        status: :pending,
        orchestration_state: :ready,
        metadata: %{"notification_key" => "ops.recovery.delivery"}
      )

    assert {:ok, recovered_delivery} =
             Deliveries.begin_recovery(delivery,
               now: recovered_at,
               older_than: 60,
               source: "operator_console",
               reason: "dispatch_stuck"
             )

    assert recovered_delivery.id == delivery.id
    assert recovered_delivery.metadata["recovery_source"] == "operator_console"
    assert recovered_delivery.metadata["recovery_reason"] == "dispatch_stuck"
    assert recovered_delivery.metadata["recovered_at"] == "2026-04-28T18:00:00.000000Z"
  end
end
```

### `test/chimeway/traces_test.exs` (test, transform)

**Analog:** `test/chimeway/traces_test.exs`

**Test module helper pattern** (lines 1-60):
```elixir
defmodule Chimeway.TracesTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.{Deliveries, Delivery, Repo, Traces}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Traces.Explanation

  defp insert_event(attrs \\ %{}) do
    {:ok, event} =
      Repo.insert(%Event{
        notification_key: Map.get(attrs, :notification_key, "test_notifier"),
        notification_version: 1,
        idempotency_key: Map.get(attrs, :idempotency_key, "key-#{System.unique_integer()}"),
        payload: %{},
        correlation_id: Map.get(attrs, :correlation_id)
      })
```

**Recovery explainability test pattern** (lines 591-617):
```elixir
test "explain_delivery surfaces durable recovery facts after a delivery is claimed for recovery" do
  ctx = create_pending_delivery_for_traces()
  recovered_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

  assert {:ok, recovered} =
           Deliveries.begin_recovery(ctx.delivery,
             now: recovered_at,
             older_than: 0,
             source: "ops_console",
             reason: "worker_missed"
           )

  assert {:ok, %Explanation{} = explanation} = Traces.explain_delivery(recovered.id)

  recovered_entries = Enum.filter(explanation.timeline, &(&1.event == :recovered))
  assert length(recovered_entries) == 1
  [%{at: timeline_recovered_at, detail: recovery_detail}] = recovered_entries

  assert recovery_detail.recovery_source == "ops_console"
  assert recovery_detail.recovery_reason == "worker_missed"
  refute Map.has_key?(recovery_detail, :payload)
end
```

**Aggregate assertions pattern** (lines 619-692):
```elixir
test "aggregate_outcomes groups counts by notification_key, channel, and lifecycle bucket" do
  _base = create_outcome_fixture("ops.analytics", "email")

  assert outcome_rows(notification_key: "ops.analytics", channel: "email") == [
           %{notification_key: "ops.analytics", channel: "email", outcome: "delayed", count: 1},
           %{notification_key: "ops.analytics", channel: "email", outcome: "digested", count: 1},
           %{notification_key: "ops.analytics", channel: "email", outcome: "exhausted", count: 1},
           %{notification_key: "ops.analytics", channel: "email", outcome: "failed", count: 1},
           %{notification_key: "ops.analytics", channel: "email", outcome: "sent", count: 2},
           %{notification_key: "ops.analytics", channel: "email", outcome: "suppressed", count: 1}
         ]
end

test "aggregate_outcomes returns payload-safe identifiers and counts only" do
  rows = Traces.aggregate_outcomes(notification_key: "ops.safe-surface", channel: "email")

  assert Enum.all?(rows, fn row ->
           Enum.sort(Map.keys(row)) == [:channel, :count, :notification_key, :outcome]
         end)

  refute inspect(rows) =~ "provider_response"
  refute inspect(rows) =~ "secret"
  refute inspect(rows) =~ "payload"
end
```

**Outcome fixture builder pattern** (lines 724-866):
```elixir
defp create_outcome_fixture(notification_key, channel) do
  sent = insert_notification(insert_event(%{notification_key: notification_key}), "user:sent")
  suppressed = insert_notification(insert_event(%{notification_key: notification_key}), "user:suppressed")
  delayed = insert_notification(insert_event(%{notification_key: notification_key}), "user:delayed")
  ...

  delayed_delivery =
    delayed
    |> plan_delivery(channel)
    |> defer_delivery()

  exhausted_delivery =
    exhausted
    |> plan_delivery(channel)
    |> fail_delivery()
    |> exhaust_delivery()

  %{
    notification_key: notification_key,
    channel: channel,
    sent_delivery: sent_delivery,
    delayed_delivery: delayed_delivery,
    digested_delivery: digested_delivery,
    failed_delivery: failed_delivery,
    exhausted_delivery: exhausted_delivery
  }
end
```

### `test/chimeway/integration/delivery_lifecycle_test.exs` (test, request-response)

**Analog:** `test/chimeway/integration/delivery_lifecycle_test.exs`

**Integration setup pattern for Oban-backed delivery recovery** (lines 1019-1035):
```elixir
describe "Scenario K: recoverable ready rows re-drive through the canonical delivery identity" do
  setup do
    previous_adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    previous_dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)

    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Oban)
    TestAdapter.clear()

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, previous_adapter)
      Application.put_env(:chimeway, :dispatcher, previous_dispatcher)
      TestAdapter.clear()
    end)

    :ok
  end
```

**End-to-end recovery flow pattern** (lines 1037-1093):
```elixir
test "recover_delivery reuses the same row, stamps recovery_source, and dispatches once" do
  fixture =
    Chimeway.Test.DispatchHelpers.create_notification(
      notification_key: "test.lifecycle_recovery",
      recipient_identity: "user:15"
    )

  {:ok, delivery} = Deliveries.plan_delivery(fixture.notification.id, :email)

  delivery =
    delivery
    |> Ecto.Changeset.change(updated_at: ~U[2026-01-15 11:00:00.000000Z])
    |> Repo.update!()

  assert {:ok, recovery} =
           Chimeway.recover_delivery(delivery.id,
             now: ~U[2026-01-15 12:30:00Z],
             older_than: 60,
             source: "ops_console",
             reason: "stuck_after_trigger"
           )

  assert_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})
  assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
  assert attempt_count(delivery.id) == 1

  recovered = Repo.get!(Delivery, delivery.id)
  assert recovered.metadata["recovery_source"] == "ops_console"

  assert {:noop, duplicate} =
           Chimeway.recover_delivery(delivery.id,
             now: ~U[2026-01-15 12:31:00Z],
             older_than: 60,
             source: "ops_console",
             reason: "duplicate_attempt"
           )

  assert duplicate.delivery.id == delivery.id
  assert attempt_count(delivery.id) == 1
end
```

### `test/chimeway/orchestration/recovery_test.exs` (test, event-driven)

**Analog:** `test/chimeway/orchestration/deferred_resume_test.exs`

**Module/setup pattern** (lines 1-25):
```elixir
defmodule Chimeway.Orchestration.DeferredResumeTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  import Ecto.Query

  alias Chimeway.{Deliveries, Delivery, Dispatch.DeferredResumeWorker, Dispatch.ObanWorker, Repo, Traces}
  alias Chimeway.Test.DispatchHelpers

  setup do
    previous_adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    previous_dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
    ...
  end
```

**Single-row identity + noop pattern** (lines 27-71):
```elixir
test "only one caller can promote a due deferred delivery and later calls no-op" do
  delivery = deferred_delivery_fixture(...)

  assert {:ok, resumed_delivery} =
           Deliveries.resume_deferred_delivery(
             delivery.id,
             now: ~U[2026-01-15 13:05:00Z],
             source: "scheduled_resume"
           )

  assert resumed_delivery.id == delivery.id

  assert {:noop, already_resumed} =
           Deliveries.resume_deferred_delivery(
             delivery.id,
             now: ~U[2026-01-15 13:06:00Z],
             source: "scheduled_resume"
           )

  assert Repo.aggregate(
           from(d in Delivery, where: d.notification_id == ^delivery.notification_id),
           :count,
           :id
         ) == 1
end
```

**Worker/enqueue idempotency pattern** (lines 255-312):
```elixir
test "promotes a deferred row and enqueues exactly one canonical dispatch worker" do
  delivery = deferred_delivery_fixture(...)

  refute_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})

  assert :ok = perform_job(DeferredResumeWorker, %{delivery_id: delivery.id})

  resumed = Deliveries.get_delivery!(delivery.id)
  assert resumed.orchestration_state == :ready
  assert resumed.status == :pending

  assert_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})
  assert length(all_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})) == 1

  assert :ok = perform_job(DeferredResumeWorker, %{delivery_id: delivery.id})
  assert length(all_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})) == 1
end
```

## Shared Patterns

### Durable row mutation over replacement
**Source:** `lib/chimeway/deliveries.ex` lines 74-133, 578-619
**Apply to:** Recovery helpers and any follow-on reconciliation path
```elixir
{updated_count, _rows} = Repo.update_all(recovery_query, [])
updated_delivery = get_delivery!(delivery_id)

if updated_count == 1 do
  {:ok, updated_delivery}
else
  {:noop, updated_delivery}
end
```

### Queue is execution artifact; delivery_id is the execution contract
**Source:** `lib/chimeway/dispatch/oban.ex` lines 52-60, 90-114; `lib/chimeway/dispatch/oban_worker.ex` lines 113-137
**Apply to:** Any recovery dispatch entrypoint or worker-triggered reconciliation
```elixir
def dispatch_delivery(delivery_id, _opts) when is_binary(delivery_id) do
  delivery = Chimeway.Deliveries.get_delivery!(delivery_id)
  dispatch_delivery(delivery, [])
end

defp enqueue_delivery(%{status: :pending, orchestration_state: :ready} = delivery) do
  enqueue_job(delivery, ObanWorker.new(%{delivery_id: delivery.id}))
end

def perform(%Oban.Job{args: %{"delivery_id" => delivery_id}, attempt: attempt, max_attempts: max_attempts}) do
  delivery = Deliveries.get_delivery!(delivery_id)

  if delivery.status in Deliveries.terminal_states() or delivery.orchestration_state != :ready do
    :ok
  else
    ...
  end
end
```

### Outcome buckets come from canonical delivery state, not attempts
**Source:** `lib/chimeway/traces.ex` lines 188-243
**Apply to:** All aggregate outcome APIs
```elixir
select: %{
  notification_key: e.notification_key,
  channel: d.channel,
  outcome:
    fragment(
      """
      CASE
        WHEN ? = 'succeeded' THEN 'sent'
        WHEN ? = 'suppressed' THEN 'suppressed'
        WHEN ? = 'pending' AND ? = 'deferred' THEN 'delayed'
        WHEN ? = 'digested' THEN 'digested'
        WHEN ? = 'failed' THEN 'failed'
        WHEN ? = 'cancelled' AND ? = 'retries_exhausted' THEN 'exhausted'
        ELSE NULL
      END
      """,
      d.status,
      d.status,
      d.status,
      d.orchestration_state,
      d.status,
      d.status,
      d.status,
      d.suppression_reason
    )
}
```

### Explainability surfaces only safe, durable facts
**Source:** `lib/chimeway/traces.ex` lines 338-349, 427-434; `test/chimeway/traces_test.exs` lines 680-692
**Apply to:** Recovery timelines and aggregate result structs/maps
```elixir
detail: %{
  recovery_source: recovery_fields.recovery_source,
  recovery_reason: recovery_fields.recovery_reason,
  recovered_at: recovery_fields.recovered_at
}

assert Enum.all?(rows, fn row ->
         Enum.sort(Map.keys(row)) == [:channel, :count, :notification_key, :outcome]
       end)
```

### Test setup for dispatcher-swapping integration coverage
**Source:** `test/chimeway/integration/delivery_lifecycle_test.exs` lines 1019-1035; `test/chimeway/orchestration/deferred_resume_test.exs` lines 10-25
**Apply to:** Recovery integration/orchestration tests
```elixir
previous_adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
previous_dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)

Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Oban)
TestAdapter.clear()

on_exit(fn ->
  Application.put_env(:chimeway, :adapter, previous_adapter)
  Application.put_env(:chimeway, :dispatcher, previous_dispatcher)
  TestAdapter.clear()
end)
```

## No Analog Found

None. Every implied file has at least a strong role-match analog in the current codebase.

## Metadata

**Analog search scope:** `lib/chimeway`, `test/chimeway`, `.planning`
**Files scanned:** 12
**Pattern extraction date:** 2026-04-28

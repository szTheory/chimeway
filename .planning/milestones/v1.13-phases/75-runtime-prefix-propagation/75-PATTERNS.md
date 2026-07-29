# Phase 75: Runtime Prefix Propagation - Pattern Map

**Mapped:** 2026-07-01  
**Files analyzed:** 28  
**Analogs found:** 28 / 28

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/chimeway/repo.ex` | config | CRUD | `lib/chimeway/storage.ex` + `deps/ecto/lib/ecto/repo.ex` | role-match |
| `lib/chimeway/storage.ex` | utility | transform | `lib/chimeway/storage.ex` | exact |
| `lib/chimeway/admin.ex` | service | request-response | `lib/chimeway/admin.ex` + `lib/chimeway/storage.ex` | exact |
| `lib/chimeway/traces.ex` | service | request-response | `lib/chimeway/traces.ex` + `test/chimeway/traces_test.exs` | exact |
| `lib/chimeway/trigger.ex` | service | event-driven | `lib/chimeway/trigger.ex` | exact |
| `lib/chimeway/deliveries.ex` | service | CRUD | `lib/chimeway/deliveries.ex` | exact |
| `lib/chimeway/inbox.ex` | service | event-driven | `lib/chimeway/inbox.ex` | exact |
| `lib/chimeway/preferences.ex` | service | CRUD | `lib/chimeway/preferences.ex` | exact |
| `lib/chimeway/policy.ex` | service | request-response | `lib/chimeway/policy.ex` | exact |
| `lib/chimeway/policy/settings.ex` | service | request-response | `lib/chimeway/policy/settings.ex` | exact |
| `lib/chimeway/workflows.ex` | service | event-driven | `lib/chimeway/workflows.ex` | exact |
| `lib/chimeway/workflows/progression.ex` | service | event-driven | `lib/chimeway/workflows/progression.ex` | exact |
| `lib/chimeway/signal.ex` | service | event-driven | `lib/chimeway/signal.ex` | exact |
| `lib/chimeway/digests.ex` | service | CRUD | `lib/chimeway/digests.ex` | exact |
| `lib/chimeway/digests/accumulation.ex` | service | event-driven | `lib/chimeway/digests/accumulation.ex` | exact |
| `lib/chimeway/digests/emission.ex` | service | event-driven | `lib/chimeway/digests/emission.ex` | exact |
| `lib/chimeway/webhooks.ex` | service | event-driven | `lib/chimeway/webhooks.ex` | exact |
| `lib/chimeway/webhooks/process_feedback_worker.ex` | service | event-driven | `lib/chimeway/webhooks/process_feedback_worker.ex` | exact |
| `lib/chimeway/dispatch/oban.ex` | service | event-driven | `lib/chimeway/dispatch/oban.ex` + `deps/oban/lib/oban/repo.ex` | role-match |
| `lib/chimeway/dispatch/oban_worker.ex` | service | event-driven | `lib/chimeway/dispatch/oban_worker.ex` | exact |
| `lib/chimeway/dispatch/deferred_resume_worker.ex` | service | event-driven | `lib/chimeway/dispatch/deferred_resume_worker.ex` | exact |
| `lib/chimeway/dispatch/signal_router_worker.ex` | service | event-driven | `lib/chimeway/dispatch/signal_router_worker.ex` | exact |
| `lib/chimeway/dispatch/workflow_progression_worker.ex` | service | event-driven | `lib/chimeway/dispatch/workflow_progression_worker.ex` | exact |
| `lib/chimeway/dispatch/digest_flush_worker.ex` | service | event-driven | `lib/chimeway/dispatch/digest_flush_worker.ex` | exact |
| `test/chimeway/repo_prefix_test.exs` | test | transform | `test/chimeway/storage_test.exs` | exact |
| `test/support/prefixed_runtime_case.ex` | test | batch | `test/support/data_case.ex` + `test/chimeway/migration_contract_test.exs` | role-match |
| `test/chimeway/runtime_prefix_integration_test.exs` | test | event-driven | `test/chimeway/trigger_pipeline_test.exs` + existing integration tests | role-match |
| `mix.exs` | config | batch | `mix.exs` aliases | exact |

## Pattern Assignments

### `lib/chimeway/repo.ex` (config, CRUD)

**Analog:** `lib/chimeway/storage.ex`; Ecto default hook in `deps/ecto/lib/ecto/repo.ex`

**Current Repo shape** (`lib/chimeway/repo.ex` lines 1-5):

```elixir
defmodule Chimeway.Repo do
  use Ecto.Repo,
    otp_app: :chimeway,
    adapter: Ecto.Adapters.Postgres
end
```

**Storage mapping to delegate to** (`lib/chimeway/storage.ex` lines 25-31):

```elixir
@spec repo_opts(keyword()) :: keyword()
def repo_opts(opts \\ []) do
  case validate_prefix!() do
    @storage_prefix -> Keyword.put_new(opts, :prefix, @storage_prefix)
    false -> opts
  end
end
```

**Ecto default-options merge behavior** (`deps/ecto/lib/ecto/repo.ex` lines 313-321):

```elixir
def default_options(_operation), do: []
defoverridable default_options: 1

defp prepare_opts(operation_name, []), do: default_options(operation_name)

defp prepare_opts(operation_name, [{key, _} | _rest] = opts) when is_atom(key) do
  operation_name
  |> default_options()
  |> Keyword.merge(opts)
end
```

**Copy/adapt:** add `@impl true`, `def default_options(:transaction), do: []`, and `def default_options(_operation), do: Chimeway.Storage.repo_opts()` in `Chimeway.Repo`. Do not pass Chimeway prefixes through public APIs or transaction opts.

---

### `lib/chimeway/storage.ex` (utility, transform)

**Analog:** self

**Validation contract** (`lib/chimeway/storage.ex` lines 8-23):

```elixir
@spec validate_prefix!() :: String.t() | false
def validate_prefix! do
  case Application.fetch_env(:chimeway, :prefix) do
    {:ok, @storage_prefix} ->
      @storage_prefix

    {:ok, false} ->
      false

    {:ok, value} ->
      invalid_prefix!(value)

    :error ->
      invalid_prefix!(:missing)
  end
end
```

**Existing guardrails to copy into new Repo test** (`test/chimeway/storage_test.exs` lines 90-111):

```elixir
describe "repo_opts/1" do
  test "adds the configured chimeway prefix when no caller prefix exists" do
    Application.put_env(:chimeway, :prefix, "chimeway")

    assert Storage.repo_opts([]) == [prefix: "chimeway"]
  end

  test "preserves a caller-supplied prefix for probes" do
    Application.put_env(:chimeway, :prefix, "chimeway")

    assert Storage.repo_opts(prefix: "custom_probe", timeout: 1) == [
             prefix: "custom_probe",
             timeout: 1
           ]
  end

  test "returns unprefixed repo options in public-schema legacy mode" do
    Application.put_env(:chimeway, :prefix, false)

    refute Keyword.has_key?(Storage.repo_opts([]), :prefix)
    assert Storage.repo_opts(timeout: 1) == [timeout: 1]
  end
end
```

**Copy/adapt:** keep `Storage.repo_opts/1` as the only Chimeway storage-prefix mapping helper. New tests should assert Repo defaults call this behavior rather than duplicate the mapping.

---

### `lib/chimeway/admin.ex` (service, request-response)

**Analog:** self plus `Chimeway.Storage.repo_opts/1`

**Imports and aliases pattern** (`lib/chimeway/admin.ex` lines 10-12):

```elixir
import Ecto.Query

alias Chimeway.{Delivery, Events.Event, Notifications.Notification, Repo}
```

**Read-model query + DTO pattern** (`lib/chimeway/admin.ex` lines 35-61):

```elixir
def recent_problem_deliveries(opts \\ []) do
  limit = Keyword.get(opts, :limit, @default_limit)

  Delivery
  |> join(:inner, [d], n in assoc(d, :notification))
  |> join(:inner, [_d, n], e in assoc(n, :event))
  |> where([d], d.status in ^@problem_statuses)
  |> maybe_filter_tenant(Keyword.get(opts, :tenant_id))
  |> order_by([d], desc: d.updated_at)
  |> limit(^limit)
  |> select([d, n, e], %{
    delivery_id: d.id,
    event_id: e.id,
    notification_key: e.notification_key,
    notification_version: e.notification_version,
    recipient_id: n.recipient_identity,
    channel: d.channel,
    status: d.status,
    suppression_reason: d.suppression_reason,
    planning_reason: d.planning_reason,
    tenant_id: d.tenant_id,
    correlation_id: e.correlation_id,
    inserted_at: d.inserted_at,
    updated_at: d.updated_at
  })
  |> Repo.all(repo_opts(opts))
  |> Enum.map(&delivery_dto/1)
end
```

**Current local domain-option filter** (`lib/chimeway/admin.ex` lines 318-320):

```elixir
defp repo_opts(opts) do
  Keyword.drop(opts, [:limit, :tenant_id, :recipient_id, :now, :older_than])
end
```

**Copy/adapt:** preserve tenant/redaction filters and DTOs. If this helper is changed, only drop non-Repo domain options and then delegate to `Chimeway.Storage.repo_opts/1` so explicit `prefix:` probes survive.

---

### `lib/chimeway/traces.ex` (service, request-response)

**Analog:** self plus `test/chimeway/traces_test.exs`

**Option propagation pattern** (`lib/chimeway/traces.ex` lines 66-90):

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

**Preload options pattern** (`lib/chimeway/traces.ex` lines 101-121):

```elixir
def find_traces_by_correlation_id(correlation_id, opts \\ []) do
  limit = Keyword.get(opts, :limit)
  repo_opts = Keyword.drop(opts, [:limit])

  query =
    from(e in Event,
      where: e.correlation_id == ^correlation_id,
      order_by: [desc: e.inserted_at]
    )

  query =
    if limit do
      from(e in query, limit: ^limit)
    else
      query
    end

  events = Repo.all(query, repo_opts)

  Repo.preload(events, [notifications: [deliveries: :attempts]], repo_opts)
end
```

**Explicit prefix probe tests** (`test/chimeway/traces_test.exs` lines 993-1024):

```elixir
describe "opts propagation" do
  test "get_trace/2 passes opts to Repo" do
    assert_raise Postgrex.Error,
                 ~r/relation "nonexistent_schema.chimeway_events" does not exist/,
                 fn ->
                   Traces.get_trace(Ecto.UUID.generate(), prefix: "nonexistent_schema")
                 end
  end

  test "find_traces_for_recipient/2 passes opts to Repo" do
    assert_raise Postgrex.Error,
                 ~r/relation "nonexistent_schema.chimeway_notifications" does not exist/,
                 fn ->
                   Traces.find_traces_for_recipient("user:123", prefix: "nonexistent_schema")
                 end
  end

  test "find_traces_by_correlation_id/2 passes opts to Repo" do
    assert_raise Postgrex.Error,
                 ~r/relation "nonexistent_schema.chimeway_events" does not exist/,
                 fn ->
                   Traces.find_traces_by_correlation_id("req-xyz", prefix: "nonexistent_schema")
                 end
  end

  test "explain_delivery/2 passes opts to Repo" do
    assert_raise Postgrex.Error,
                 ~r/relation "nonexistent_schema.chimeway_deliveries" does not exist/,
                 fn ->
                   Traces.explain_delivery(Ecto.UUID.generate(), prefix: "nonexistent_schema")
                 end
  end
end
```

**Copy/adapt:** when stripping trace-specific filters, keep explicit repo opts. Add `Chimeway.Storage.repo_opts/1` only after domain keys are dropped, and keep the probe tests green.

---

### `lib/chimeway/trigger.ex` (service, event-driven)

**Analog:** self

**Transaction and callback repo pattern** (`lib/chimeway/trigger.ex` lines 78-93):

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
    insert_notifications(repo, notifier, params, event, normalized_recipients, tenant_id)
  end)
  |> Repo.transaction()
```

**String-source `insert_all` risk path** (`lib/chimeway/trigger.ex` lines 158-169):

```elixir
defp insert_notifications(repo, notifier, params, event, recipients, tenant_id) do
  with {:ok, notifications} <- notifications_attrs(repo, notifier, params, event, recipients) do
    try do
      rows = Enum.map(notifications, & &1.row)
      {count, _rows} = repo.insert_all("chimeway_notifications", rows)

      with :ok <- insert_workflow_runs(repo, notifications, tenant_id) do
        {:ok, count}
      end
    rescue
      error -> {:error, error}
    end
  end
end
```

**Duplicate idempotency lookup pattern** (`lib/chimeway/trigger.ex` lines 233-245):

```elixir
defp normalize_trigger_result(
       {:error, :event, %Ecto.Changeset{} = changeset, _changes},
       idempotency_key,
       _recipients
     ) do
  if idempotency_conflict?(changeset) do
    case Repo.get_by(Event, idempotency_key: idempotency_key) do
      nil -> {:error, :duplicate_event_not_found}
      existing_event -> {:duplicate, existing_event}
    end
  else
    {:error, {:event_insert_failed, changeset}}
  end
end
```

**Post-commit dispatch handoff** (`lib/chimeway/trigger.ex` lines 432-444):

```elixir
defp dispatch_after_trigger({:ok, %{event: event} = trigger_result}, notifier, params, opts) do
  dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
  notifications = Repo.all(from(n in Notification, where: n.event_id == ^event.id))

  dispatch_opts =
    opts
    |> Keyword.put_new(:notifier, notifier)
    |> Keyword.put_new(:trigger_params, params)
    |> Keyword.put_new(:notification_key, event.notification_key)
    |> Keyword.put_new(:event_id, event.id)
    |> Keyword.put_new(:correlation_id, event.correlation_id)

  case dispatcher.dispatch(notifications, dispatch_opts) do
```

**Copy/adapt:** prove `repo.insert_all("chimeway_notifications", rows)` and duplicate `Repo.get_by/2` land in configured storage through `Repo.default_options/1`. Do not add prefix to trigger opts or job args.

---

### `lib/chimeway/deliveries.ex` (service, CRUD)

**Analog:** self

**Recovery query pattern with tenant scope** (`lib/chimeway/deliveries.ex` lines 58-79):

```elixir
@spec list_recoverable_deliveries(keyword()) :: [Delivery.t()]
def list_recoverable_deliveries(opts \\ []) when is_list(opts) do
  now =
    opts
    |> Keyword.get(:now, DateTime.utc_now())
    |> normalize_datetime!()

  cutoff = recoverable_cutoff!(now, Keyword.get(opts, :older_than, 60))
  tenant_id = scoped_tenant_id(opts)

  query =
    from(d in Delivery,
      where:
        d.status == :pending and d.orchestration_state == :ready and d.updated_at <= ^cutoff and
          fragment("?->>? IS NULL", d.metadata, ^"recovered_at"),
      order_by: [asc: d.updated_at, asc: d.inserted_at]
    )

  query
  |> maybe_scope_delivery_tenant(tenant_id)
  |> Repo.all()
end
```

**Atomic recovery claim** (`lib/chimeway/deliveries.ex` lines 105-130):

```elixir
recovery_query =
  from(d in Delivery,
    where:
      d.id == ^delivery_id and d.status == :pending and d.orchestration_state == :ready and
        d.updated_at <= ^cutoff and fragment("?->>? IS NULL", d.metadata, ^"recovered_at"),
    update: [
      set: [
        metadata:
          fragment(
            "COALESCE(?, '{}'::jsonb) || ?::jsonb",
            d.metadata,
            ^metadata_patch
          ),
        updated_at: ^now
      ]
    ]
  )
  |> maybe_scope_delivery_tenant(tenant_id)

{updated_count, _rows} = Repo.update_all(recovery_query, [])

case {updated_count, tenant_id} do
  {1, _tenant_id} -> {:ok, get_delivery!(delivery_id)}
  {0, nil} -> {:noop, get_delivery!(delivery_id)}
  {0, _scoped_tenant_id} -> {:noop, nil}
end
```

**Record attempt transaction** (`lib/chimeway/deliveries.ex` lines 1081-1114):

```elixir
Multi.new()
|> Multi.run(:lock_delivery, fn repo, _changes ->
  # W8 preemptive fix: SELECT FOR UPDATE serializes concurrent
  # record_attempt/2 callers for the same delivery_id. With this lock,
  # attempt_number contiguity is invariant under concurrent execution.
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
  attempt_attrs =
    safe_attrs
    |> Map.put(:delivery_id, locked.id)
    |> Map.put(:attempt_number, n)

  DeliveryAttempt.changeset(%DeliveryAttempt{}, attempt_attrs)
end)
|> Multi.run(:delivery, fn _repo, %{lock_delivery: locked} ->
  terminal_or_failed_transition(locked, outcome, error_class)
end)
|> Repo.transaction()
```

**Copy/adapt:** keep recovery tenant filters and metadata redaction intact. Repo defaults should route these reads/writes; do not rewrite recovery semantics while adding prefix proof.

---

### `lib/chimeway/inbox.ex` (service, event-driven)

**Analog:** self

**Inbox list and lifecycle update pattern** (`lib/chimeway/inbox.ex` lines 66-85 and 141-164):

```elixir
defp list_for_recipient_paginated(recipient_identity, opts) do
  limit = Keyword.get(opts, :limit, 20)
  unread_only? = Keyword.get(opts, :unread_only, false)
  exclude_archived = exclude_archived?(opts)

  query =
    Notification
    |> base_recipient_query(recipient_identity)
    |> maybe_exclude_archived(exclude_archived)
    |> maybe_filter_unread(unread_only?)
    |> order_by([notification], desc: notification.inserted_at, desc: notification.id)
    |> maybe_apply_cursor(opts)
    |> limit(^limit + 1)

  rows = Repo.all(query)
  has_more = length(rows) > limit
  items = rows |> Enum.take(limit) |> Enum.map(&Item.to_map/1)

  %{items: items, has_more: has_more}
end
```

```elixir
defp update_lifecycle_timestamp(notification_id, recipient_identity, field, at, event_name) do
  timestamp = DateTime.truncate(at, :microsecond)

  first_transition_query =
    Notification
    |> where([n], n.id == ^notification_id)
    |> where([n], n.recipient_identity == ^recipient_identity)
    |> where([n], is_nil(field(n, ^field)))

  case Repo.update_all(first_transition_query, set: [{field, timestamp}, {:updated_at, timestamp}]) do
    {1, _} ->
      maybe_emit_inbox_signal(notification_id, recipient_identity, event_name)
      :ok

    {0, _} ->
      case Repo.get_by(Notification, id: notification_id, recipient_identity: recipient_identity) do
        %Notification{} = notification ->
          if is_nil(Map.get(notification, field)), do: {:error, :not_found}, else: :ok

        nil ->
          {:error, :not_found}
      end
  end
end
```

**Signal emission follow-on** (`lib/chimeway/inbox.ex` lines 166-200):

```elixir
defp maybe_emit_inbox_signal(notification_id, recipient_identity, event_name) do
  case resolve_tenant_id(notification_id) do
    nil -> :ok
    tenant_id -> emit_inbox_signal(tenant_id, recipient_identity, notification_id, event_name)
  end
end

defp emit_inbox_signal(tenant_id, recipient_identity, notification_id, event_name) do
  Signal.track(
    tenant_id,
    recipient_identity,
    event_name,
    %{"notification_id" => notification_id}
  )

  :ok
end
```

**Copy/adapt:** tests must prove list/unread/mark_seen/mark_read/archive and follow-on signal rows use configured storage.

---

### `lib/chimeway/preferences.ex`, `lib/chimeway/policy.ex`, `lib/chimeway/policy/settings.ex` (services, CRUD/request-response)

**Analogs:** self

**Preference upsert/get pattern** (`lib/chimeway/preferences.ex` lines 18-37):

```elixir
def upsert_preference(attrs) do
  %NotificationPreference{}
  |> NotificationPreference.changeset(attrs)
  |> Repo.insert(
    on_conflict: {:replace, [:enabled, :updated_at]},
    conflict_target: [:recipient_id, :notification_key, :channel]
  )
end

def get_preference(recipient_id, notification_key, channel) do
  Repo.get_by(NotificationPreference,
    recipient_id: recipient_id,
    notification_key: notification_key,
    channel: channel
  )
end
```

**Policy context reload pattern** (`lib/chimeway/policy.ex` lines 75-99):

```elixir
@spec delivery_category(Delivery.t()) :: String.t() | nil
def delivery_category(%Delivery{} = delivery) do
  notification = Repo.get!(Notification, delivery.notification_id)
  event = Repo.get!(Event, notification.event_id)
  delivery_category_from_event(event)
end

defp load_policy_context(%Delivery{} = delivery) do
  notification = Repo.get!(Notification, delivery.notification_id)
  event = Repo.get!(Event, notification.event_id)

  %{
    notification: notification,
    event: event,
    recipient_id: notification.recipient_identity,
    category: delivery_category_from_event(event)
  }
end
```

**Policy settings query pattern** (`lib/chimeway/policy/settings.ex` lines 72-82):

```elixir
recent_count =
  from(d in Delivery,
    join: n in assoc(d, :notification),
    where:
      n.recipient_identity == ^recipient_id and
        d.inserted_at >= ^cutoff and
        d.id != ^delivery.id,
    select: count(d.id)
  )
  |> Repo.one()
```

**Copy/adapt:** rely on `Repo.default_options/1`; do not add public prefix options to policy/preference APIs.

---

### `lib/chimeway/workflows.ex` and `lib/chimeway/workflows/progression.ex` (services, event-driven)

**Analogs:** self

**Workflow definition Multi pattern** (`lib/chimeway/workflows.ex` lines 22-34):

```elixir
@spec upsert_definition(String.t(), Chimeway.Notifier.workflow_resolution()) ::
        {:ok, WorkflowDefinition.t()} | {:error, term()}
def upsert_definition(notification_key, workflow)
    when is_binary(notification_key) and is_map(workflow) do
  Multi.new()
  |> Multi.run(:workflow_definition, fn repo, _changes ->
    ensure_definition(repo, notification_key, workflow)
  end)
  |> Repo.transaction()
  |> case do
    {:ok, %{workflow_definition: definition}} -> {:ok, preload_steps(Repo, definition)}
    {:error, _operation, reason, _changes} -> {:error, reason}
  end
end
```

**Workflow lock helper pattern** (`lib/chimeway/workflows.ex` lines 221-228):

```elixir
@spec lock_run(Ecto.Repo.t(), Ecto.UUID.t()) ::
        {:ok, WorkflowRun.t()} | {:error, :workflow_run_not_found}
def lock_run(repo, workflow_run_id) when is_binary(workflow_run_id) do
  case repo.one(from(wr in WorkflowRun, where: wr.id == ^workflow_run_id, lock: "FOR UPDATE")) do
    nil -> {:error, :workflow_run_not_found}
    run -> {:ok, run}
  end
end
```

**Progression transaction pattern** (`lib/chimeway/workflows/progression.ex` lines 80-104):

```elixir
@spec progress_run(Ecto.UUID.t(), keyword()) :: progress_result()
def progress_run(workflow_run_id, opts \\ []) when is_binary(workflow_run_id) do
  now = Keyword.get(opts, :now, DateTime.utc_now()) |> DateTime.truncate(:microsecond)

  Repo.transaction(fn ->
    with {:ok, run} <- Workflows.lock_run(Repo, workflow_run_id),
         {:ok, intermediate} <- maybe_reactivate_due(Repo, run, now) do
      case intermediate do
        {:advanced, _advanced_run, _deliveries} = advanced ->
          advanced

        %WorkflowRun{} = run ->
          case do_progress_active_run(Repo, run, now) do
            {:ok, result} -> result
            {:noop, run, reason} -> {:noop, run, reason}
            {:error, reason} -> Repo.rollback(reason)
          end
      end
    else
      {:noop, run, reason} -> {:noop, run, reason}
      {:error, reason} -> Repo.rollback(reason)
    end
  end)
```

**Route signal transaction pattern** (`lib/chimeway/workflows.ex` lines 397-434):

```elixir
@spec route_signal(Signal.t()) :: {:ok, map()} | {:error, term()}
def route_signal(
      %Signal{tenant_id: tenant_id, event_name: event_name, actor_id: actor_id} = signal
    )
    when is_binary(tenant_id) and is_binary(event_name) and is_binary(actor_id) do
  Repo.transaction(fn ->
    matched_runs = find_runs_waiting_for_signal(tenant_id, actor_id, event_name)

    now = DateTime.utc_now()

    Enum.reduce_while(matched_runs, %{}, fn run, acc ->
      with {:ok, updated_run} <-
             update_run(Repo, run, %{
               state: :active,
               pending_signals: [],
               status_reason: "signal_received",
               last_transition_at: now,
               suspended_until: nil
             }),
           {:ok, transition} <-
             append_transition(Repo, %{
               workflow_run_id: run.id,
               from_state: :waiting,
               to_state: :active,
               reason: "signal_received",
               context: %{"event_name" => event_name},
               delivery_id: Map.get(signal.payload, "delivery_id"),
               inserted_at: now
             }) do
        {:cont,
         acc
         |> Map.put({:run_updated, run.id}, updated_run)
         |> Map.put({:transition_inserted, run.id}, transition)}
      else
        {:error, reason} -> {:halt, Repo.rollback(reason)}
      end
    end)
  end)
end
```

**Copy/adapt:** audit callback `repo` calls and plain `Repo` calls inside transactions. Repo defaults should carry Chimeway storage; transaction opts should remain empty.

---

### `lib/chimeway/signal.ex` and webhook/digest entrypoints (services, event-driven)

**Analogs:** self

**Signal durable row + Oban job transaction** (`lib/chimeway/signal.ex` lines 30-39):

```elixir
Multi.new()
|> Multi.insert(:signal, Signal.changeset(%Signal{}, attrs))
|> Oban.insert(:job, fn %{signal: signal} ->
  SignalRouterWorker.new(%{"signal_id" => signal.id})
end)
|> Repo.transaction()
|> case do
  {:ok, %{signal: signal}} -> {:ok, signal}
  {:error, _step, reason, _changes} -> {:error, reason}
end
```

**Webhook ingress transaction** (`lib/chimeway/webhooks.ex` lines 45-60):

```elixir
Multi.new()
|> Multi.insert(:ingress, Ingress.changeset(%Ingress{}, attrs),
  on_conflict: :nothing,
  conflict_target:
    {:unsafe_fragment,
     ~s|("adapter_module", "provider_event_id") WHERE "provider_event_id" IS NOT NULL|},
  returning: true
)
|> Oban.insert(:job, fn %{ingress: ingress} ->
  ProcessFeedbackWorker.new(%{"ingress_id" => ingress.id})
end)
|> Repo.transaction()
|> case do
  {:ok, %{ingress: ingress}} -> {:ok, ingress}
  {:error, _step, reason, _changes} -> {:error, reason}
end
```

**Digest facade lookup pattern** (`lib/chimeway/digests.ex` lines 40-61):

```elixir
@doc "Lists digest rules, optionally filtered by exact-match fields."
@spec list_rules(keyword()) :: [DigestRule.t()]
def list_rules(opts \\ []) when is_list(opts) do
  DigestRule
  |> maybe_where(:channel, Keyword.get(opts, :channel))
  |> maybe_where(:rule_key, Keyword.get(opts, :rule_key))
  |> Repo.all()
end

@doc "Finds the first digest rule matching channel and rule selectors."
@spec find_matching_rule(rule_lookup()) :: DigestRule.t() | nil
def find_matching_rule(%{} = attrs) do
  channel = Map.fetch!(attrs, :channel)

  attrs
  |> build_match_queries(channel)
  |> Enum.find_value(&Repo.one/1)
end
```

**Copy/adapt:** signal and webhook job args must remain durable-ID only. Prefix values must never enter job args.

---

### `lib/chimeway/digests/accumulation.ex` and `lib/chimeway/digests/emission.ex` (services, event-driven)

**Analogs:** self

**Accumulation transaction** (`lib/chimeway/digests/accumulation.ex` lines 37-59):

```elixir
@spec accumulate_delivery(Delivery.t(), keyword()) ::
        {:ok, DigestBucket.t() | :noop} | {:error, term()}
def accumulate_delivery(%Delivery{} = delivery, opts \\ []) when is_list(opts) do
  accumulated_at =
    opts
    |> Keyword.get(:accumulated_at, DateTime.utc_now())
    |> normalize_datetime()

  case Repo.transact(fn ->
         locked_delivery = lock_delivery!(delivery.id)

         if accumulatable?(locked_delivery) do
           {:ok,
            do_accumulate(
              locked_delivery,
              accumulated_at,
              Keyword.get(opts, :lookup_attrs, %{})
            )}
         else
           {:ok, :noop}
         end
       end) do
    {:ok, result} -> {:ok, result}
    {:error, reason} -> {:error, reason}
  end
end
```

**Schema `insert_all` pattern** (`lib/chimeway/digests/accumulation.ex` lines 270-286):

```elixir
{inserted_count, _rows} =
  Repo.insert_all(
    DigestMembership,
    [
      %{
        id: Ecto.UUID.generate(),
        digest_bucket_id: bucket.id,
        delivery_id: delivery.id,
        notification_id: delivery.notification_id,
        inserted_at: accumulated_at,
        updated_at: accumulated_at
      }
    ],
    on_conflict: :nothing,
    conflict_target: [:delivery_id]
  )
```

**Emission transaction** (`lib/chimeway/digests/emission.ex` lines 27-91):

```elixir
case Repo.transact(fn ->
       bucket = lock_bucket!(bucket_id!(bucket_or_id))

       cond do
         bucket.flush_state == :emitted and is_binary(bucket.digest_delivery_id) ->
           digest_delivery = Repo.get!(Delivery, bucket.digest_delivery_id)
           immediate_deliveries = immediate_deliveries_for_bucket(bucket.id)

           {:ok,
            %{
              bucket: bucket,
              digest_delivery: digest_delivery,
              immediate_deliveries: immediate_deliveries
            }}

         DateTime.compare(bucket.window_ends_at, emitted_at) == :gt ->
           Repo.rollback({:bucket_not_due, bucket.id})

         true ->
           unresolved_memberships = unresolved_memberships(bucket.id)
           # ...
           {:ok, %{bucket: bucket, digest_delivery: digest_delivery, immediate_deliveries: immediate_deliveries}}
       end
     end) do
  {:ok,
   %{digest_delivery: digest_delivery, immediate_deliveries: immediate_deliveries} = result} ->
    dispatch_after_commit(dispatch_mode, digest_delivery, immediate_deliveries)
    {:ok, result}

  {:error, reason} ->
    {:error, reason}
end
```

**Copy/adapt:** prove accumulation membership inserts, bucket updates, emission-created event/notification/delivery rows, and worker-triggered emission use configured storage.

---

### Worker Files (services, event-driven)

**Files:** `lib/chimeway/dispatch/oban_worker.ex`, `lib/chimeway/dispatch/deferred_resume_worker.ex`, `lib/chimeway/dispatch/signal_router_worker.ex`, `lib/chimeway/dispatch/workflow_progression_worker.ex`, `lib/chimeway/dispatch/digest_flush_worker.ex`, `lib/chimeway/webhooks/process_feedback_worker.ex`

**Analog:** existing worker reload-by-ID pattern

**Delivery worker reload** (`lib/chimeway/dispatch/oban_worker.ex` lines 112-139):

```elixir
@impl Oban.Worker
def perform(%Oban.Job{
      args: %{"delivery_id" => delivery_id},
      attempt: attempt,
      max_attempts: max_attempts
    }) do
  delivery = Deliveries.get_delivery!(delivery_id)

  if delivery.status in Deliveries.terminal_states() or delivery.orchestration_state != :ready do
    :ok
  else
    Telemetry.span(
      [:dispatch, :perform],
      Telemetry.safe_meta(%{
        delivery_id: delivery.id,
        channel: delivery.channel,
        notification_key: Map.get(delivery.metadata || %{}, "notification_key"),
        correlation_id: Map.get(delivery.metadata || %{}, "correlation_id"),
        attempt: attempt,
        max_attempts: max_attempts
      }),
      fn ->
        result = handle_delivery(delivery, attempt, max_attempts)
        {result, %{}}
      end
    )
  end
end
```

**Feedback worker ingress reload** (`lib/chimeway/webhooks/process_feedback_worker.ex` lines 43-67):

```elixir
@impl Oban.Worker
def perform(%Oban.Job{args: %{"ingress_id" => ingress_id}}) when is_binary(ingress_id) do
  case Repo.get(Ingress, ingress_id) do
    nil ->
      :ok

    %Ingress{ingress_state: :ignored} ->
      :ok

    %Ingress{ingress_state: :processed} ->
      :ok

    %Ingress{} = ingress ->
      ingress
      |> apply_feedback()
      |> normalize_perform_result()
  end
end
```

**Thin delegate workers**:

`lib/chimeway/dispatch/signal_router_worker.ex` lines 22-34:

```elixir
@impl Oban.Worker
def perform(%Oban.Job{args: %{"signal_id" => signal_id}}) do
  case Repo.get(Signal, signal_id) do
    nil ->
      {:error, :signal_not_found}

    %Signal{} = signal ->
      case Workflows.route_signal(signal) do
        {:ok, _results} -> :ok
        {:error, reason} -> {:error, reason}
      end
  end
end
```

`lib/chimeway/dispatch/workflow_progression_worker.ex` lines 43-75:

```elixir
@impl Oban.Worker
def perform(%Oban.Job{args: %{"workflow_run_id" => workflow_run_id}})
    when is_binary(workflow_run_id) do
  workflow_run_id
  |> Progression.progress_run([])
  |> normalize_progress_result()
end

def normalize_progress_result({:ok, {:advanced, _run, _deliveries}}), do: :ok
def normalize_progress_result({:ok, {:waiting, _run}}), do: :ok
def normalize_progress_result({:ok, {:noop, _run, _reason}}), do: :ok
def normalize_progress_result({:ok, {:completed, _run}}), do: :ok
def normalize_progress_result({:ok, {:stopped, _run}}), do: :ok
def normalize_progress_result({:error, :workflow_run_not_found}), do: :ok
def normalize_progress_result({:error, reason}), do: {:error, reason}
```

`lib/chimeway/dispatch/deferred_resume_worker.ex` lines 22-29:

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

`lib/chimeway/dispatch/digest_flush_worker.ex` lines 13-20:

```elixir
@impl Oban.Worker
def perform(%Oban.Job{args: %{"bucket_id" => bucket_id}}) do
  case Digests.emit_bucket(bucket_id) do
    {:ok, _result} -> :ok
    {:error, {:bucket_not_due, _bucket_id}} -> :ok
    {:error, reason} -> {:error, reason}
  end
end
```

**Copy/adapt:** workers should keep durable-ID args and reload from Chimeway storage through `Repo.default_options/1`. Tests should assert worker reloads by ID work in prefixed mode.

---

### `lib/chimeway/dispatch/oban.ex` (service, event-driven)

**Analog:** self plus Oban repo prefix helper

**Direct Oban.Job query risk** (`lib/chimeway/dispatch/oban.ex` lines 169-198):

```elixir
defp collapse_duplicate_digest_flush_jobs({:ok, %Job{} = job}, bucket_id, scheduled_at) do
  case matching_digest_flush_jobs(bucket_id, scheduled_at) do
    [%Job{} = keep | duplicates] ->
      duplicate_ids = Enum.map(duplicates, & &1.id)

      if duplicate_ids != [] do
        from(enqueued in Job, where: enqueued.id in ^duplicate_ids)
        |> Repo.delete_all()
      end

      {:ok, keep}

    [] ->
      {:ok, job}
  end
end

defp matching_digest_flush_jobs(bucket_id, scheduled_at) do
  from(job in Job,
    where:
      job.worker == ^to_string(DigestFlushWorker) and
        fragment("?->>'bucket_id' = ?", job.args, ^bucket_id) and
        job.scheduled_at == ^scheduled_at and
        job.state in ["available", "scheduled", "executing", "retryable"],
    order_by: [asc: job.inserted_at, asc: job.id]
  )
  |> Repo.all()
end
```

**Oban config-derived defaults** (`deps/oban/lib/oban/repo.ex` lines 140-148):

```elixir
def default_options(conf) do
  base = [log: conf.log, oban: true, telemetry_options: [oban_conf: conf]]

  if conf.prefix do
    [prefix: conf.prefix] ++ base
  else
    base
  end
end
```

**Copy/adapt:** add a narrow helper for direct `Oban.Job` `Repo.all`/`Repo.delete_all` calls so they use Oban's job-table prefix/default behavior, not `Chimeway.Storage.repo_opts/1`. Do not conflate Chimeway storage prefix and Oban job-table prefix.

---

### `test/chimeway/repo_prefix_test.exs` (test, transform)

**Analog:** `test/chimeway/storage_test.exs`

**Application env setup/restore** (`test/chimeway/storage_test.exs` lines 1-14 and 114-120):

```elixir
defmodule Chimeway.StorageTest do
  use ExUnit.Case, async: false

  alias Chimeway.{ConfigError, Storage}

  setup do
    original = Application.fetch_env(:chimeway, :prefix)

    on_exit(fn ->
      restore_prefix(original)
    end)

    :ok
  end
```

```elixir
defp restore_prefix({:ok, value}) do
  Application.put_env(:chimeway, :prefix, value)
end

defp restore_prefix(:error) do
  Application.delete_env(:chimeway, :prefix)
end
```

**Copy/adapt:** create focused tests for `Repo.default_options(:insert)`, `Repo.default_options(:all)` or equivalent operation atoms, `Repo.default_options(:transaction) == []`, public legacy mode, and explicit caller override preservation via a real operation or `Storage.repo_opts(prefix: ...)`.

---

### `test/support/prefixed_runtime_case.ex` (test, batch)

**Analog:** `test/support/data_case.ex` + `test/chimeway/migration_contract_test.exs`

**Sandbox owner setup** (`test/support/data_case.ex` lines 19-23):

```elixir
setup tags do
  pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Chimeway.Repo, shared: not tags[:async])
  on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  :ok
end
```

**Temporary generated database pattern** (`test/chimeway/migration_contract_test.exs` lines 116-145):

```elixir
defp with_generated_database(mode, fun) do
  unique = System.unique_integer([:positive])
  database = "chimeway_migration_contract_#{mode.slug}_#{unique}"
  tmp_root = Path.join(System.tmp_dir!(), "chimeway_migration_contract_#{mode.slug}_#{unique}")
  migrations_path = Path.join(tmp_root, "migrations")
  config = generated_repo_config(database)

  File.rm_rf!(tmp_root)
  File.mkdir_p!(migrations_path)
  write_numbered_fixture_migrations!(mode.fixture_root, migrations_path)

  case Ecto.Adapters.Postgres.storage_up(config) do
    :ok -> :ok
    {:error, :already_up} -> :ok
    {:error, reason} -> flunk("failed to create #{database}: #{inspect(reason)}")
  end

  try do
    {:ok, pid} = GeneratedRepo.start_link(config)

    try do
      fun.(GeneratedRepo, migrations_path)
    after
      if Process.alive?(pid), do: GenServer.stop(pid)
    end
  after
    _ = Ecto.Adapters.Postgres.storage_down(config)
    File.rm_rf!(tmp_root)
    purge_fixture_modules!(mode.fixture_root)
  end
end
```

**Migration runner pattern** (`test/chimeway/migration_contract_test.exs` lines 257-269):

```elixir
defp run_fixture_migrations(repo, migrations_path, direction) when direction in [:up, :down] do
  parent = self()
  ref = make_ref()

  ExUnit.CaptureIO.capture_io(:stderr, fn ->
    result = Ecto.Migrator.run(repo, migrations_path, direction, all: true, log: false)
    send(parent, {ref, result})
  end)

  receive do
    {^ref, result} -> result
  end
end
```

**Copy/adapt:** prefer a serialized non-async case that switches `Application.put_env(:chimeway, :prefix, "chimeway")`, restores it on exit, and either uses a temporary migrated database or a cleaned `chimeway` schema. Keep default tests in explicit public legacy mode.

---

### `test/chimeway/runtime_prefix_integration_test.exs` (test, event-driven)

**Analog:** `test/chimeway/trigger_pipeline_test.exs`, `test/chimeway/inbox_integration_test.exs`, `test/chimeway/webhooks/process_feedback_worker_test.exs`, `test/chimeway/orchestration/recovery_test.exs`, `test/chimeway/migration_contract_test.exs`

**Trigger fanout scenario** (`test/chimeway/trigger_pipeline_test.exs` lines 208-260):

```elixir
test "returns deterministic, deduped recipient output with explicit channel fanout" do
  assert {:ok, result} =
           Trigger.trigger(FanoutNotifier, %{}, idempotency_key: "idem-123", tenant_id: "acme")

  assert result.notification_key == "comment.created.fanout"
  assert result.notification_version == 3
  assert result.idempotency_key == "idem-123"

  assert Enum.map(result.recipients, & &1.recipient_identity) == ["a-user", "m-user", "z-user"]
  assert length(result.recipients) == 3

  notifications =
    Repo.all(from(n in Notification, where: n.event_id == ^result.event.id, select: n.id))

  assert length(notifications) == 3

  delivery_count =
    Repo.aggregate(
      from(d in Delivery, where: d.notification_id in ^notifications),
      :count,
      :id
    )

  assert delivery_count == 6
end
```

**Duplicate idempotency proof** (`test/chimeway/trigger_pipeline_test.exs` lines 316-358):

```elixir
test "duplicate idempotency trigger bypasses dispatch invocation on second call" do
  previous_dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)

  on_exit(fn ->
    Application.put_env(:chimeway, :dispatcher, previous_dispatcher)
  end)

  Application.put_env(:chimeway, :dispatcher, SpyDispatcher)

  assert {:ok, _result} =
           Trigger.trigger(
             PipelineNotifier,
             %{},
             idempotency_key: "idem-dup-001",
             tenant_id: "acme",
             spy_pid: self()
           )

  assert_receive {:dispatch_called, _}

  assert {:duplicate, _event} =
           Trigger.trigger(
             PipelineNotifier,
             %{},
             idempotency_key: "idem-dup-001",
             tenant_id: "acme",
             spy_pid: self()
           )

  refute_receive {:dispatch_called, _}

  event_count =
    Repo.aggregate(from(e in Event, where: e.idempotency_key == "idem-dup-001"), :count, :id)

  assert event_count == 1
end
```

**Inbox lifecycle proof** (`test/chimeway/inbox_integration_test.exs` lines 32-67):

```elixir
test "trigger fanout rows are listed and transitioned explicitly for user:42" do
  assert {:ok, _result} =
           Chimeway.trigger(
             IntegrationNotifier,
             %{"body" => "hello inbox", "password" => "redact"},
             idempotency_key: "inbox-integration-1",
             tenant_id: "acme"
           )

  notifications_before = Chimeway.list_for_recipient("user:42")
  assert length(notifications_before) == 1
  [notification] = notifications_before
  assert is_nil(notification.read_at)

  persisted_before = Repo.get!(Notification, notification.id)

  unread_notifications = Chimeway.list_for_recipient("user:42", unread_only: true)
  assert Enum.map(unread_notifications, & &1.id) == [notification.id]

  persisted_after = Repo.get!(Notification, notification.id)
  assert persisted_after.read_at == persisted_before.read_at

  seen_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)
  read_at = DateTime.add(seen_at, 5, :second)
  archived_at = DateTime.add(read_at, 5, :second)

  assert :ok = Chimeway.mark_seen(notification.id, "user:42", seen_at)
  assert :ok = Chimeway.mark_read(notification.id, "user:42", read_at)
  assert :ok = Chimeway.archive(notification.id, "user:42", archived_at)

  persisted_final = Repo.get!(Notification, notification.id)
  assert persisted_final.seen_at == seen_at
  assert persisted_final.read_at == read_at
  assert persisted_final.archived_at == archived_at
  assert length(Chimeway.list_for_recipient("user:77")) == 1
end
```

**Webhook worker proof** (`test/chimeway/webhooks/process_feedback_worker_test.exs` lines 56-89):

```elixir
test "processes feedback for a delivery_id-correlated ingress row", %{delivery: delivery} do
  {:ok, ingress} =
    %Ingress{}
    |> Ingress.changeset(%{
      adapter_module: "SomeAdapter",
      delivery_id: delivery.id,
      normalized_status: "bounced",
      ingress_state: :queued
    })
    |> Repo.insert()

  assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: %{"ingress_id" => ingress.id}})

  updated_delivery = Deliveries.get_delivery!(delivery.id)
  assert updated_delivery.status == :cancelled
  assert updated_delivery.suppression_reason == "bounced"

  attempts = Repo.all(Chimeway.DeliveryAttempt)
  assert length(attempts) == 1
  assert hd(attempts).outcome == :bounced
  assert hd(attempts).adapter_module == "SomeAdapter"

  signals = Repo.all(Signal)
  assert length(signals) == 1
  assert hd(signals).event_name == "chimeway.delivery.bounced"
  assert_enqueued(worker: SignalRouterWorker, args: %{"signal_id" => hd(signals).id})

  reloaded = Repo.get!(Ingress, ingress.id)
  assert reloaded.ingress_state == :processed
  assert reloaded.processed_at
end
```

**Placement assertion helpers** (`test/chimeway/migration_contract_test.exs` lines 358-373):

```elixir
defp regclass(repo, schema, name) do
  case Ecto.Adapters.SQL.query!(repo, "SELECT to_regclass($1)", ["#{schema}.#{name}"]).rows do
    [[nil]] -> nil
    [[value]] -> value
  end
end

defp schema_exists?(repo, schema) do
  result =
    Ecto.Adapters.SQL.query!(
      repo,
      "SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = $1)",
      [schema]
    )

  result.rows == [[true]]
end
```

**Copy/adapt:** new runtime-prefix suite should run normal Chimeway flows and assert both positive `chimeway.chimeway_*` placement and practical absence of accidental public reads/writes where feasible.

---

### `mix.exs` (config, batch)

**Analog:** existing alias block

**Alias organization pattern** (`mix.exs` lines 62-77 and 99-108):

```elixir
defp aliases do
  [
    # Full local gate: run before pushing
    ci: ["ci.lint", "ci.test"],

    # Lint lane
    "ci.lint": [
      "format --check-formatted",
      "compile --warnings-as-errors",
      "credo --strict"
    ],

    # Test lane (mailglass/accrue/threadline/sigra excluded — run mix verify.* separately, GATE-04/05/07)
    "ci.test": [
      "cmd env MIX_ENV=test mix test --exclude mailglass --exclude accrue --exclude threadline --exclude sigra"
    ],
```

```elixir
# Installer golden-diff, idempotency, prefix, and DB migration contract (path-gated in CI, not default ci)
"verify.install_golden": [
  "cmd env CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs test/chimeway/install/prefix_contract_test.exs test/chimeway/migration_contract_test.exs --warnings-as-errors"
],
"ci.install_golden": ["verify.install_golden"],

# GATE-01 doc-contract + version alignment gates (pre-ship; no Postgres required)
"ci.verify_gates": [
  "cmd env MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --warnings-as-errors"
],
```

**Copy/adapt:** if adding `verify.runtime_prefix`, keep it focused on `repo_prefix_test.exs` plus `runtime_prefix_integration_test.exs`. Do not fold Phase 76 docs/demo/release-gate parity into this alias.

## Shared Patterns

### Storage Prefix Defaults

**Source:** `lib/chimeway/storage.ex` and `deps/ecto/lib/ecto/repo.ex`  
**Apply to:** all Chimeway-owned table reads/writes through `Chimeway.Repo`

```elixir
# lib/chimeway/storage.ex lines 25-31
def repo_opts(opts \\ []) do
  case validate_prefix!() do
    @storage_prefix -> Keyword.put_new(opts, :prefix, @storage_prefix)
    false -> opts
  end
end
```

```elixir
# deps/ecto/lib/ecto/repo.ex lines 316-321
defp prepare_opts(operation_name, []), do: default_options(operation_name)

defp prepare_opts(operation_name, [{key, _} | _rest] = opts) when is_atom(key) do
  operation_name
  |> default_options()
  |> Keyword.merge(opts)
end
```

### String-Source `insert_all`

**Source:** `lib/chimeway/trigger.ex`; Ecto internals  
**Apply to:** `Trigger.insert_notifications/6` and guardrail tests

```elixir
# lib/chimeway/trigger.ex lines 160-164
try do
  rows = Enum.map(notifications, & &1.row)
  {count, _rows} = repo.insert_all("chimeway_notifications", rows)

  with :ok <- insert_workflow_runs(repo, notifications, tenant_id) do
```

```elixir
# deps/ecto/lib/ecto/repo.ex lines 460-469
def insert_all(schema_or_source, entries, opts \\ []) do
  repo = get_dynamic_repo()

  Ecto.Repo.Schema.insert_all(
    __MODULE__,
    repo,
    schema_or_source,
    entries,
    Ecto.Repo.Supervisor.tuplet(repo, prepare_opts(:insert_all, opts))
  )
end
```

```elixir
# deps/ecto/lib/ecto/repo/schema.ex lines 27-28, 851-858
def insert_all(repo, name, table, rows, tuplet) when is_binary(table) do
  do_insert_all(repo, name, nil, nil, table, rows, tuplet)
end

defp metadata(schema, prefix, source, autogen_id, context, opts) do
  %{
    autogenerate_id: autogen_id,
    context: context,
    schema: schema,
    source: source,
    prefix: Keyword.get(opts, :prefix, prefix)
  }
end
```

### Domain Option Filtering

**Source:** `lib/chimeway/admin.ex` and `lib/chimeway/traces.ex`  
**Apply to:** admin, trace, recovery, inbox, and any context accepting non-Repo filters

```elixir
# lib/chimeway/admin.ex lines 318-320, adapt by adding Storage delegation
defp repo_opts(opts) do
  Keyword.drop(opts, [:limit, :tenant_id, :recipient_id, :now, :older_than])
end
```

Use the Phase 75 target shape:

```elixir
defp repo_opts(opts) do
  opts
  |> Keyword.drop([:limit, :tenant_id, :recipient_id, :older_than, :now])
  |> Chimeway.Storage.repo_opts()
end
```

### Oban Job-Table Prefix Exception

**Source:** `lib/chimeway/dispatch/oban.ex`; `deps/oban/lib/oban/repo.ex`  
**Apply to:** direct `Repo.all(Oban.Job)` and `Repo.delete_all(Oban.Job)` only

```elixir
# deps/oban/lib/oban/repo.ex lines 140-148
def default_options(conf) do
  base = [log: conf.log, oban: true, telemetry_options: [oban_conf: conf]]

  if conf.prefix do
    [prefix: conf.prefix] ++ base
  else
    base
  end
end
```

Direct Oban job queries must not use `Chimeway.Storage.repo_opts/1`.

### Test Isolation

**Source:** `test/support/data_case.ex`; `test/chimeway/storage_test.exs`; `test/chimeway/migration_contract_test.exs`  
**Apply to:** new prefixed runtime test support and repo-prefix tests

```elixir
# test/support/data_case.ex lines 19-23
setup tags do
  pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Chimeway.Repo, shared: not tags[:async])
  on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  :ok
end
```

```elixir
# test/chimeway/storage_test.exs lines 6-14
setup do
  original = Application.fetch_env(:chimeway, :prefix)

  on_exit(fn ->
    restore_prefix(original)
  end)

  :ok
end
```

## No Analog Found

None. New test files have strong composite analogs from existing ExUnit case templates, migration-contract tests, and runtime integration tests.

## Metadata

**Analog search scope:** `lib/chimeway`, `test/chimeway`, `test/support`, `config`, `mix.exs`, and targeted dependency source in `deps/ecto` / `deps/oban` for prefix-default semantics.  
**Files scanned:** 183 Elixir source/test/support files under `lib/chimeway`, `test/chimeway`, and `test/support`, plus config and Mix aliases.  
**Pattern extraction date:** 2026-07-01

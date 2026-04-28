# Phase 21: Template Versioning & Rendering Contracts - Pattern Map

**Mapped:** 2026-04-28
**Files analyzed:** 14
**Analogs found:** 14 / 14

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/chimeway/notifier.ex` | service | request-response | `lib/chimeway/notifier.ex` | exact |
| `lib/chimeway/trigger.ex` | service | CRUD | `lib/chimeway/trigger.ex` | exact |
| `lib/chimeway/notifications/notification.ex` | model | CRUD | `lib/chimeway/notifications/notification.ex` | exact |
| `lib/chimeway/delivery.ex` | model | CRUD | `lib/chimeway/delivery.ex` | exact |
| `lib/chimeway/deliveries.ex` | service | CRUD | `lib/chimeway/deliveries.ex` | exact |
| `lib/chimeway/delivery_planning.ex` | service | request-response | `lib/chimeway/delivery_planning.ex` | exact |
| `lib/chimeway/traces.ex` | service | transform | `lib/chimeway/traces.ex` | exact |
| `lib/chimeway.ex` | utility | request-response | `lib/chimeway.ex` | exact |
| `lib/chimeway/rendering.ex` | service | transform | `lib/chimeway/delivery_planning.ex` | data-flow-match |
| `lib/chimeway/rendering/preview.ex` | service | request-response | `lib/chimeway.ex` | role-match |
| `lib/chimeway/rendering/channels/in_app.ex` | model | transform | `lib/chimeway/delivery.ex` | role-match |
| `lib/chimeway/rendering/channels/email.ex` | model | transform | `lib/chimeway/delivery.ex` | role-match |
| `lib/mix/tasks/preview_rendering.ex` | utility | request-response | `lib/mix/tasks/verify_published.ex` | role-match |
| `priv/repo/migrations/*_add_rendering_contract_fields.exs` | migration | CRUD | `priv/repo/migrations/20260428093000_add_delivery_orchestration_fields_to_chimeway_deliveries.exs` | exact |
| `test/chimeway/notifier_contract_test.exs` | test | request-response | `test/chimeway/notifier_contract_test.exs` | exact |
| `test/chimeway/orchestration/delivery_planning_test.exs` | test | CRUD | `test/chimeway/orchestration/delivery_planning_test.exs` | exact |
| `test/chimeway/integration/delivery_lifecycle_test.exs` | test | request-response | `test/chimeway/integration/delivery_lifecycle_test.exs` | exact |
| `test/chimeway/rendering/preview_test.exs` | test | request-response | `test/chimeway/inbox_integration_test.exs` | role-match |

## Pattern Assignments

### `lib/chimeway/notifier.ex` (service, request-response)

**Analog:** `lib/chimeway/notifier.ex`

**Imports/callback pattern** ([`lib/chimeway/notifier.ex:12`](/Users/jon/projects/chimeway/lib/chimeway/notifier.ex:12), [`lib/chimeway/notifier.ex:18`](/Users/jon/projects/chimeway/lib/chimeway/notifier.ex:18)):
```elixir
defmacro __using__(_opts) do
  quote do
    @behaviour Chimeway.Notifier
  end
end

@callback notification_key() :: String.t()
@callback version() :: pos_integer()
@callback recipients(map()) :: {:ok, [map()]} | {:error, term()}
@callback build(map(), map()) :: {:ok, map()} | {:error, term()}
```

**Validation + compatibility seam pattern** ([`lib/chimeway/notifier.ex:33`](/Users/jon/projects/chimeway/lib/chimeway/notifier.ex:33), [`lib/chimeway/notifier.ex:67`](/Users/jon/projects/chimeway/lib/chimeway/notifier.ex:67)):
```elixir
def validate_module!(module) when is_atom(module) do
  cond do
    not Code.ensure_loaded?(module) -> {:error, :notifier_not_loaded}
    not function_exported?(module, :notification_key, 0) -> {:error, :missing_notification_key_callback}
    not function_exported?(module, :version, 0) -> {:error, :missing_version_callback}
    not function_exported?(module, :recipients, 1) -> {:error, :missing_recipients_callback}
    not function_exported?(module, :build, 2) -> {:error, :missing_build_callback}
    true -> :ok
  end
end
```

**Copy for Phase 21:** add new renderer/render-identity callbacks the same way current optional callbacks are introduced and normalized, instead of replacing `build/2` outright.

---

### `lib/chimeway/trigger.ex` (service, CRUD)

**Analog:** `lib/chimeway/trigger.ex`

**Imports + transaction pattern** ([`lib/chimeway/trigger.ex:27`](/Users/jon/projects/chimeway/lib/chimeway/trigger.ex:27), [`lib/chimeway/trigger.ex:57`](/Users/jon/projects/chimeway/lib/chimeway/trigger.ex:57)):
```elixir
alias Chimeway.Events.Event
alias Chimeway.Notifications.Notification
alias Chimeway.Notifier
alias Chimeway.Repo
alias Chimeway.Telemetry
alias Ecto.Multi
alias Ecto.UUID

Telemetry.span([:events, :create], Telemetry.safe_meta(%{notification_key: notifier.notification_key()}), fn ->
  Multi.new()
  |> Multi.insert(:event, Event.changeset(%Event{}, %{...}))
  |> Multi.run(:notifications, fn repo, %{event: event} ->
    insert_notifications(repo, notifier, params, event, normalized_recipients)
  end)
  |> Repo.transaction()
end)
```

**Durable row materialization pattern** ([`lib/chimeway/trigger.ex:141`](/Users/jon/projects/chimeway/lib/chimeway/trigger.ex:141)):
```elixir
recipients
|> Enum.reduce_while({:ok, []}, fn recipient, {:ok, acc} ->
  with {:ok, metadata} <- notifier.build(params, recipient) do
    row = %{
      id: UUID.generate() |> UUID.dump!(),
      event_id: UUID.dump!(event.id),
      recipient_identity: recipient_identity(recipient),
      recipient_type: recipient_type(recipient),
      metadata: sanitize_metadata(metadata),
      inserted_at: timestamp,
      updated_at: timestamp
    }

    {:cont, {:ok, [row | acc]}}
  end
end)
```

**Payload sanitization pattern** ([`lib/chimeway/trigger.ex:226`](/Users/jon/projects/chimeway/lib/chimeway/trigger.ex:226)):
```elixir
defp sanitize_map(map) when is_map(map) do
  Enum.reduce(map, %{}, fn {key, value}, acc ->
    if sensitive_key?(key), do: acc, else: Map.put(acc, key, value)
  end)
end
```

**Copy for Phase 21:** persist render assigns during `notifications_attrs/4` with the same single-write row builder; keep sanitization at trigger time.

---

### `lib/chimeway/notifications/notification.ex` (model, CRUD)

**Analog:** `lib/chimeway/notifications/notification.ex`

**Schema pattern** ([`lib/chimeway/notifications/notification.ex:16`](/Users/jon/projects/chimeway/lib/chimeway/notifications/notification.ex:16)):
```elixir
schema "chimeway_notifications" do
  belongs_to(:event, Event, type: Ecto.UUID)
  has_many(:deliveries, Chimeway.Delivery, foreign_key: :notification_id)
  field(:recipient_identity, :string)
  field(:recipient_type, :string)
  field(:metadata, :map, default: %{})

  timestamps(type: :utc_datetime_usec)
end
```

**Changeset pattern** ([`lib/chimeway/notifications/notification.ex:29`](/Users/jon/projects/chimeway/lib/chimeway/notifications/notification.ex:29)):
```elixir
@required_fields ~w(event_id recipient_identity recipient_type metadata)a

def changeset(notification, attrs) do
  notification
  |> cast(attrs, @required_fields ++ @optional_fields)
  |> validate_required(@required_fields)
  |> unique_constraint(:recipient_identity,
    name: :chimeway_notifications_event_recipient_index
  )
end
```

**Copy for Phase 21:** add `render_assigns` beside `metadata` with the same map-backed field + required-field discipline.

---

### `lib/chimeway/delivery.ex` and `lib/chimeway/rendering/channels/*.ex` (model, CRUD/transform)

**Analog:** `lib/chimeway/delivery.ex`

**Enum + explicit field pattern** ([`lib/chimeway/delivery.ex:16`](/Users/jon/projects/chimeway/lib/chimeway/delivery.ex:16)):
```elixir
schema "chimeway_deliveries" do
  field(:channel, :string)

  field(:status, Ecto.Enum,
    values: [:pending, :dispatched, :succeeded, :failed, :suppressed, :cancelled, :digested],
    default: :pending
  )

  field(:planning_context, :map)
  field(:suppression_reason, :string)
  field(:metadata, :map)
end
```

**Changeset pattern** ([`lib/chimeway/delivery.ex:50`](/Users/jon/projects/chimeway/lib/chimeway/delivery.ex:50)):
```elixir
@required_fields ~w(notification_id channel status)a
@optional_fields ~w(... metadata)a

def changeset(delivery, attrs) do
  delivery
  |> cast(attrs, @required_fields ++ @optional_fields)
  |> validate_required(@required_fields)
  |> unique_constraint(:channel,
    name: :chimeway_deliveries_notification_channel_index
  )
end
```

**Copy for Phase 21:** add `render_key`, `render_version`, and `render_data` directly to `Delivery` as first-class explicit fields; for `rendering/channels/in_app.ex` and `email.ex`, mirror this explicit-field posture instead of a free-form blob-only contract.

---

### `lib/chimeway/deliveries.ex` (service, CRUD)

**Analog:** `lib/chimeway/deliveries.ex`

**Idempotent plan/update pattern** ([`lib/chimeway/deliveries.ex:35`](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:35)):
```elixir
def plan_delivery(notification_id, channel, opts) when is_list(opts) do
  ...
  %Delivery{}
  |> Delivery.changeset(%{
    notification_id: notification_id,
    channel: channel_str,
    status: :pending,
    delay_fallback: delay_fallback,
    metadata: metadata
  })
  |> Repo.insert(on_conflict: :nothing, conflict_target: [:notification_id, :channel])
end
```

**Validation before persistence pattern** ([`lib/chimeway/deliveries.ex:93`](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:93), [`lib/chimeway/deliveries.ex:191`](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:191)):
```elixir
defp normalize_optional_map(nil), do: {:ok, nil}
defp normalize_optional_map(value) when is_map(value), do: {:ok, value}
defp normalize_optional_map(value), do: {:error, {:invalid_planning_context, value}}

def apply_planning_decision(%Delivery{} = delivery, decision) when is_map(decision) do
  with {:ok, state} <- normalize_orchestration_state(...),
       {:ok, planning_reason} <- normalize_optional_string(...),
       {:ok, planning_context} <- normalize_optional_map(...) do
    delivery
    |> change(%{orchestration_state: state, planning_reason: planning_reason, planning_context: planning_context})
    |> Repo.update()
  end
end
```

**Copy for Phase 21:** put render-data normalization/update helpers here if delivery writes stay centralized; follow the same `normalize_*` then `change |> Repo.update` flow.

---

### `lib/chimeway/delivery_planning.ex` and `lib/chimeway/rendering.ex` (service, request-response/transform)

**Analog:** `lib/chimeway/delivery_planning.ex`

**Planner choke-point pattern** ([`lib/chimeway/delivery_planning.ex:34`](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:34), [`lib/chimeway/delivery_planning.ex:77`](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:77)):
```elixir
def plan_notification(%Notification{} = notification, opts \\ []) do
  with {:ok, channels} <- resolve_channels(notification, opts),
       {:ok, delayed_fallback_channels, delayed_fallback_source} <-
         resolve_delayed_fallback_channels(notification, channels, opts) do
    plan_channels(notification, channels, delayed_fallback_channels, delayed_fallback_source, opts)
  end
end

with {:ok, delivery} <- Deliveries.plan_delivery(notification.id, channel, ...),
     {:ok, orchestration} <- resolve_orchestration(opts, trigger_params, recipient),
     {:ok, delivery} <- apply_declared_orchestration(delivery, channel, orchestration) do
  ...
end
```

**Normalization/error wrapping pattern** ([`lib/chimeway/delivery_planning.ex:107`](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:107)):
```elixir
if notifier && function_exported?(notifier, :channels, 2) do
  handle_notifier_channels(notifier.channels(trigger_params, recipient))
else
  normalize_channels([:in_app])
end
```

**Per-channel decision pattern** ([`lib/chimeway/delivery_planning.ex:282`](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:282)):
```elixir
decision =
  case mode do
    :digest_held ->
      %{orchestration_state: :digest_held, planning_reason: "digest_rule", planning_context: digest_planning_context(channel, orchestration, digest_key)}

    :immediate ->
      %{orchestration_state: :ready, planning_reason: nil, planning_context: nil}
  end
```

**Copy for Phase 21:** render materialization belongs in this same choke point. Add `with {:ok, rendered} <- Rendering.render_delivery(... )` before dispatch, then persist validated render facts onto the canonical delivery row.

---

### `lib/chimeway/traces.ex` (service, transform)

**Analog:** `lib/chimeway/traces.ex`

**Explainability projection pattern** ([`lib/chimeway/traces.ex:112`](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:112)):
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

  ...

  explanation = %Explanation{
    delivery_id: delivery.id,
    event_id: event.id,
    notification_key: event.notification_key,
    channel: delivery.channel,
    status: delivery.status,
    planning_reason: delivery.planning_reason,
    planning_context: explanation_planning_context(delivery),
    ...
  }
end
```

**Timeline detail pattern** ([`lib/chimeway/traces.ex:188`](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:188)):
```elixir
%{
  at: deferred_at(delivery),
  event: :deferred,
  detail: %{
    reason: delivery.planning_reason,
    time_zone: planning_context && planning_context["time_zone"],
    rule_identity: planning_context && planning_context["rule_identity"],
    next_eligible_at: delivery.next_eligible_at,
    planning_context: planning_context
  }
}
```

**Copy for Phase 21:** expose `render_key`, `render_version`, and safe render summary in the same explanation struct style; do not dump raw sensitive render assigns.

---

### `lib/chimeway.ex` and `lib/chimeway/rendering/preview.ex` (utility/service, request-response)

**Analog:** `lib/chimeway.ex`

**Thin public API pattern** ([`lib/chimeway.ex:6`](/Users/jon/projects/chimeway/lib/chimeway.ex:6)):
```elixir
alias Chimeway.Inbox
alias Chimeway.Trigger

def trigger(notifier, params, opts \\ []) do
  Trigger.trigger(notifier, params, opts)
end
```

**Copy for Phase 21:** expose preview through the same thin delegation style, for example `Chimeway.preview/3` delegating into `Chimeway.Rendering.Preview`.

---

### `lib/mix/tasks/preview_rendering.ex` (utility, request-response)

**Analog:** `lib/mix/tasks/verify_published.ex`

**Mix task pattern** ([`lib/mix/tasks/verify_published.ex:13`](/Users/jon/projects/chimeway/lib/mix/tasks/verify_published.ex:13)):
```elixir
use Mix.Task

@shortdoc "Verify chimeway is published and accessible at the given version on hex.pm"

@impl Mix.Task
def run([]) do
  Mix.shell().error("Usage: mix verify.published <version>")
  exit({:shutdown, 1})
end
```

**CLI output/error pattern** ([`lib/mix/tasks/verify_published.ex:23`](/Users/jon/projects/chimeway/lib/mix/tasks/verify_published.ex:23)):
```elixir
Mix.shell().info("Checking hex.pm for chimeway v#{version}...")
...
Mix.shell().error("FAIL: ...")
exit({:shutdown, 1})
```

**Copy for Phase 21:** keep the task as a thin wrapper over the library preview API; validate args first, then delegate and print a stable human-readable preview summary.

---

### `priv/repo/migrations/*_add_rendering_contract_fields.exs` (migration, CRUD)

**Analog:** `priv/repo/migrations/20260428093000_add_delivery_orchestration_fields_to_chimeway_deliveries.exs`

**Alter-table + index pattern** ([`priv/repo/migrations/20260428093000_add_delivery_orchestration_fields_to_chimeway_deliveries.exs:4`](/Users/jon/projects/chimeway/priv/repo/migrations/20260428093000_add_delivery_orchestration_fields_to_chimeway_deliveries.exs:4)):
```elixir
def up do
  alter table(:chimeway_deliveries) do
    add(:orchestration_state, :string, null: false, default: "ready")
    add(:next_eligible_at, :utc_datetime_usec)
    add(:planning_reason, :string)
    add(:planning_context, :map)
  end

  create(
    index(
      :chimeway_deliveries,
      [:orchestration_state, :next_eligible_at],
      name: :chimeway_deliveries_orchestration_state_next_eligible_at_index
    )
  )
end
```

**Simple change migration pattern** ([`priv/repo/migrations/20260428110200_alter_chimeway_deliveries_for_digest_outcome.exs:4`](/Users/jon/projects/chimeway/priv/repo/migrations/20260428110200_alter_chimeway_deliveries_for_digest_outcome.exs:4)):
```elixir
def change do
  alter table(:chimeway_deliveries) do
    add(:digest_flush_outcome, :string)
    add(:digest_flush_reason, :string)
    add(:digest_flush_resolved_at, :utc_datetime_usec)
  end

  create(index(:chimeway_deliveries, [:digest_flush_outcome]))
end
```

**Copy for Phase 21:** follow the same delivery-table alter migration style for `render_key`, `render_version`, and `render_data`; use a second alter on `chimeway_notifications` for `render_assigns` if that field is added.

---

### `test/chimeway/notifier_contract_test.exs` (test, request-response)

**Analog:** `test/chimeway/notifier_contract_test.exs`

**Inline fixture notifier pattern** ([`test/chimeway/notifier_contract_test.exs:6`](/Users/jon/projects/chimeway/test/chimeway/notifier_contract_test.exs:6)):
```elixir
defmodule ValidNotifier do
  @behaviour Notifier

  @impl true
  def notification_key, do: "comment.created"

  @impl true
  def version, do: 1
end
```

**Tagged error assertion pattern** ([`test/chimeway/notifier_contract_test.exs:56`](/Users/jon/projects/chimeway/test/chimeway/notifier_contract_test.exs:56)):
```elixir
test "returns tagged error for missing version callback" do
  assert {:error, :missing_version_callback} =
           Notifier.validate_module!(MissingVersion)
end
```

**Copy for Phase 21:** extend this file first for new notifier render callbacks and compatibility behavior before adding integration coverage.

---

### `test/chimeway/orchestration/delivery_planning_test.exs` (test, CRUD)

**Analog:** `test/chimeway/orchestration/delivery_planning_test.exs`

**Planner-focused test fixture pattern** ([`test/chimeway/orchestration/delivery_planning_test.exs:18`](/Users/jon/projects/chimeway/test/chimeway/orchestration/delivery_planning_test.exs:18)):
```elixir
defmodule DigestEmailNotifier do
  use Chimeway.Notifier
  ...
  def channels(_params, _recipient), do: {:ok, [:email]}
  def orchestration(_params, _recipient),
    do: {:ok, [email: {:digest, [digest_key: "thread:123"]}]}
end
```

**Canonical-row assertion pattern** ([`test/chimeway/orchestration/delivery_planning_test.exs:63`](/Users/jon/projects/chimeway/test/chimeway/orchestration/delivery_planning_test.exs:63)):
```elixir
assert {:ok, [delivery]} = DeliveryPlanning.plan_notification(notification, ...)
assert {:ok, [replanned]} = DeliveryPlanning.plan_notification(notification, ...)
assert replanned.id == delivery.id
```

**Copy for Phase 21:** test render identity/output persistence at the planning seam with this same repeated-planning/no-duplicate-row structure.

---

### `test/chimeway/integration/delivery_lifecycle_test.exs` and `test/chimeway/rendering/preview_test.exs` (test, request-response)

**Analog:** `test/chimeway/integration/delivery_lifecycle_test.exs`

**Module-level notifier fixture pattern** ([`test/chimeway/integration/delivery_lifecycle_test.exs:1`](/Users/jon/projects/chimeway/test/chimeway/integration/delivery_lifecycle_test.exs:1)):
```elixir
defmodule ChimewayTest.Notifiers.LifecycleFanout do
  @behaviour Chimeway.Notifier
  def notification_key, do: "test.lifecycle_fanout"
  def version, do: 1
  def build(_params, _recipient), do: {:ok, %{title: "Test Fanout"}}
  def channels(_params, _recipient), do: {:ok, [:in_app, :email]}
end
```

**End-to-end chain assertion pattern** ([`test/chimeway/integration/delivery_lifecycle_test.exs:118`](/Users/jon/projects/chimeway/test/chimeway/integration/delivery_lifecycle_test.exs:118)):
```elixir
assert {:ok, _result} = Chimeway.trigger(...)

events = Repo.all(from(e in Event, where: ...))
notifications = Repo.all(from(n in Notification, where: ...))
deliveries = Repo.all(from(d in Delivery, where: ...))
attempts = Repo.all(from(a in DeliveryAttempt, where: ...))
```

**Secondary preview-test analog:** `test/chimeway/inbox_integration_test.exs:32` uses a thin public API call and then validates persisted shape after the call.

**Copy for Phase 21:** add one integration proving preview output equals the render artifact persisted onto the delivery used for dispatch.

## Shared Patterns

### Durable Single-Write Capture
**Source:** [`lib/chimeway/trigger.ex:141`](/Users/jon/projects/chimeway/lib/chimeway/trigger.ex:141)
**Apply to:** Notification-level `render_assigns`
```elixir
row = %{
  id: UUID.generate() |> UUID.dump!(),
  event_id: UUID.dump!(event.id),
  recipient_identity: recipient_identity(recipient),
  recipient_type: recipient_type(recipient),
  metadata: sanitize_metadata(metadata),
  inserted_at: timestamp,
  updated_at: timestamp
}
```

### Planner Choke Point Before Dispatch
**Source:** [`lib/chimeway/delivery_planning.ex:89`](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:89)
**Apply to:** Render output materialization
```elixir
with {:ok, delivery} <- Deliveries.plan_delivery(notification.id, channel, ...),
     {:ok, orchestration} <- resolve_orchestration(opts, trigger_params, recipient),
     {:ok, delivery} <- apply_declared_orchestration(delivery, channel, orchestration) do
  ...
end
```

### Explicit Runtime Validation Before Update
**Source:** [`lib/chimeway/deliveries.ex:191`](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:191)
**Apply to:** `render_data`, `render_key`, `render_version`
```elixir
with {:ok, state} <- normalize_orchestration_state(...),
     {:ok, planning_reason} <- normalize_optional_string(...),
     {:ok, planning_context} <- normalize_optional_map(...) do
  delivery
  |> change(%{...})
  |> Repo.update()
end
```

### Adapters Stay Dumb
**Source:** [`lib/chimeway/adapter.ex:5`](/Users/jon/projects/chimeway/lib/chimeway/adapter.ex:5), [`lib/chimeway/dispatch/executor.ex:29`](/Users/jon/projects/chimeway/lib/chimeway/dispatch/executor.ex:29)
**Apply to:** All email/outbound rendering work
```elixir
Adapters receive a pre-planned `%Chimeway.Delivery{}` struct with all rendered
content already present.
```

```elixir
{attempt_outcome, error_class, provider_response} =
  dispatched
  |> adapter.deliver(adapter_config)
  |> classify()
```

### Explainability Without Raw Payload Leakage
**Source:** [`lib/chimeway/traces.ex:134`](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:134), [`lib/chimeway/trigger.ex:226`](/Users/jon/projects/chimeway/lib/chimeway/trigger.ex:226)
**Apply to:** Preview structs, trace structs, test assertions
```elixir
explanation = %Explanation{
  delivery_id: delivery.id,
  notification_key: event.notification_key,
  channel: delivery.channel,
  status: delivery.status,
  planning_reason: delivery.planning_reason
}
```

## No Analog Found

Files with no exact same-role precedent; use the listed partial analogs and Phase 21 research constraints:

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/chimeway/rendering.ex` | service | transform | No existing dedicated rendering pipeline module exists yet. |
| `lib/chimeway/rendering/preview.ex` | service | request-response | No preview API exists yet; use thin public API + planner seam patterns. |
| `lib/chimeway/rendering/channels/email.ex` | model | transform | No channel-specific validated render contract modules exist yet. |
| `lib/chimeway/rendering/channels/in_app.ex` | model | transform | Existing in-app content lives in `metadata`, not a dedicated render contract module. |

## Metadata

**Analog search scope:** `lib/chimeway`, `lib/mix/tasks`, `priv/repo/migrations`, `test/chimeway`
**Files scanned:** 18
**Pattern extraction date:** 2026-04-28

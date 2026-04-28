# Phase 19: Digest Data Model & Accumulation - Pattern Map

**Mapped:** 2026-04-28
**Files analyzed:** 11
**Analogs found:** 11 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/chimeway/digests/digest_rule.ex` | model | CRUD | `lib/chimeway/policy/settings/setting.ex` | role-match |
| `lib/chimeway/digests/digest_bucket.ex` | model | CRUD | `lib/chimeway/delivery.ex` | role-match |
| `lib/chimeway/digests/digest_membership.ex` | model | CRUD | `lib/chimeway/delivery_attempt.ex` | role-match |
| `lib/chimeway/digests/accumulation.ex` | service | event-driven | `lib/chimeway/deliveries.ex` | role+flow |
| `lib/chimeway/delivery_planning.ex` | service | event-driven | `lib/chimeway/delivery_planning.ex` | exact |
| `priv/repo/migrations/*_create_chimeway_digest_rules.exs` | migration | CRUD | `priv/repo/migrations/20260425000200_create_chimeway_policy_settings.exs` | role-match |
| `priv/repo/migrations/*_create_chimeway_digest_buckets.exs` | migration | CRUD | `priv/repo/migrations/20260424082833_create_chimeway_deliveries.exs` | role-match |
| `priv/repo/migrations/*_create_chimeway_digest_memberships.exs` | migration | CRUD | `priv/repo/migrations/20260424082834_create_chimeway_delivery_attempts.exs` | role-match |
| `test/chimeway/digests/digest_rule_test.exs` | test | CRUD | `test/chimeway/delivery_attempt_test.exs` | role-match |
| `test/chimeway/digests/digest_bucket_test.exs` | test | CRUD | `test/chimeway/deliveries_test.exs` | role-match |
| `test/chimeway/digests/accumulation_test.exs` | test | event-driven | `test/chimeway/orchestration/delivery_planning_test.exs` | role+flow |

## Pattern Assignments

### `lib/chimeway/digests/digest_rule.ex` (model, CRUD)

**Analog:** `lib/chimeway/policy/settings/setting.ex`

**Imports + schema pattern** ([lib/chimeway/policy/settings/setting.ex](/Users/jon/projects/chimeway/lib/chimeway/policy/settings/setting.ex:4)):
```elixir
use Ecto.Schema
import Ecto.Changeset

@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id

schema "chimeway_policy_settings" do
  field(:recipient_id, :string)
  timestamps(type: :utc_datetime_usec)
end
```

**Changeset validation pattern** ([lib/chimeway/policy/settings/setting.ex](/Users/jon/projects/chimeway/lib/chimeway/policy/settings/setting.ex:23)):
```elixir
@required_fields ~w(recipient_id)a
@optional_fields ~w(
  quiet_hours_start_minute
  quiet_hours_end_minute
  delivery_cap_count
  delivery_cap_window_minutes
  time_zone
)a

def changeset(setting, attrs) do
  setting
  |> cast(attrs, @required_fields ++ @optional_fields)
  |> validate_required(@required_fields)
  |> validate_number(:delivery_cap_count, greater_than: 0)
  |> unique_constraint(:recipient_id, name: :chimeway_policy_settings_recipient_index)
end
```

**Supplemental durable identity pattern** ([lib/chimeway/preferences/notification_preference.ex](/Users/jon/projects/chimeway/lib/chimeway/preferences/notification_preference.ex:21)):
```elixir
@required_fields ~w(recipient_id notification_key channel enabled)a

def changeset(pref, attrs) do
  pref
  |> cast(attrs, @required_fields)
  |> validate_required(@required_fields)
  |> unique_constraint([:recipient_id, :notification_key, :channel],
    name: :chimeway_notification_preferences_recipient_key_channel_index
  )
end
```

**Copy for digest rules:** binary UUID primary key, `timestamps(type: :utc_datetime_usec)`, explicit `@required_fields` / `@optional_fields`, and named `unique_constraint/3` for stable rule identity.

---

### `lib/chimeway/digests/digest_bucket.ex` (model, CRUD)

**Analog:** `lib/chimeway/delivery.ex`

**Schema structure pattern** ([lib/chimeway/delivery.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery.ex:13)):
```elixir
@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id

schema "chimeway_deliveries" do
  field(:channel, :string)
  field(:status, Ecto.Enum,
    values: [:pending, :dispatched, :succeeded, :failed, :suppressed, :cancelled],
    default: :pending
  )
  field(:metadata, :map)

  belongs_to(:notification, Notification)
  has_many(:attempts, Chimeway.DeliveryAttempt)

  timestamps(type: :utc_datetime_usec)
end
```

**Constraint pattern** ([lib/chimeway/delivery.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery.ex:42)):
```elixir
@required_fields ~w(notification_id channel status)a
@optional_fields ~w(
  orchestration_state
  next_eligible_at
  planning_reason
  planning_context
  suppression_reason
  delay_fallback
  metadata
)a

def changeset(delivery, attrs) do
  delivery
  |> cast(attrs, @required_fields ++ @optional_fields)
  |> validate_required(@required_fields)
  |> unique_constraint(:channel,
    name: :chimeway_deliveries_notification_channel_index
  )
end
```

**Copy for digest buckets:** model window and grouping facts as first-class fields, keep one named composite uniqueness boundary in the DB, and use regular associations rather than JSON-only linkage.

---

### `lib/chimeway/digests/digest_membership.ex` (model, CRUD)

**Analog:** `lib/chimeway/delivery_attempt.ex`

**Append-only child schema pattern** ([lib/chimeway/delivery_attempt.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_attempt.ex:39)):
```elixir
schema "chimeway_delivery_attempts" do
  field(:outcome, Ecto.Enum, values: [:succeeded, :failed, :bounced, :rejected])
  field(:provider_response, :map)
  field(:attempt_number, :integer)
  field(:error_class, :string)
  field(:inserted_at, :utc_datetime_usec)

  belongs_to(:delivery, Chimeway.Delivery)
end
```

**Changeset pattern** ([lib/chimeway/delivery_attempt.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_attempt.ex:52)):
```elixir
@required_fields ~w(delivery_id outcome attempt_number)a
@optional_fields ~w(error_class provider_response)a

def changeset(attempt, attrs) do
  attempt
  |> cast(attrs, @required_fields ++ @optional_fields)
  |> validate_required(@required_fields)
  |> validate_inclusion(:error_class, @error_classes)
  |> validate_attempt_number_positive()
  |> put_inserted_at()
end
```

**Copy for digest memberships:** explicit join schema, explicit timestamps, parent-child `belongs_to` references, and room for future explainability fields instead of an anonymous join table.

---

### `lib/chimeway/digests/accumulation.ex` (service, event-driven)

**Analog:** `lib/chimeway/deliveries.ex`

**Imports + alias pattern** ([lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:9)):
```elixir
import Ecto.Changeset, only: [change: 2]
import Ecto.Query, only: [from: 2]

alias Chimeway.{Delivery, DeliveryAttempt, Repo}
alias Chimeway.Telemetry
alias Ecto.Multi
```

**Idempotent insert pattern** ([lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:43)):
```elixir
%Delivery{}
|> Delivery.changeset(%{
  notification_id: notification_id,
  channel: channel_str,
  status: :pending,
  delay_fallback: delay_fallback,
  metadata: metadata
})
|> Repo.insert(on_conflict: :nothing, conflict_target: [:notification_id, :channel])
```

**Transactional write pattern** ([lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:457)):
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
  DeliveryAttempt.changeset(%DeliveryAttempt{}, %{delivery_id: locked.id, attempt_number: n})
end)
|> Repo.transaction()
```

**Error return pattern** ([lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:490)):
```elixir
|> case do
  {:ok, %{delivery: updated_delivery, attempt: attempt}} ->
    {:ok, %{delivery: updated_delivery, attempt: attempt}}

  {:error, step, reason, changes} ->
    {:error, step, reason, changes}
end
```

**Copy for accumulation:** do bucket upsert + membership insert + bucket metadata update inside one transaction, use DB conflict targets rather than app-level dedupe, and keep step-tagged `{:error, step, reason, changes}` failures.

---

### `lib/chimeway/delivery_planning.ex` (service, event-driven, modified)

**Analog:** `lib/chimeway/delivery_planning.ex`

**Planning loop pattern** ([lib/chimeway/delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:32)):
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

**Per-channel choke-point pattern** ([lib/chimeway/delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:87)):
```elixir
with {:ok, delivery} <-
       Deliveries.plan_delivery(notification.id, channel,
         delay_fallback: delay_fallback,
         delayed_fallback_source: source,
         notification_key: Keyword.get(opts, :notification_key),
         event_id: Keyword.get(opts, :event_id),
         correlation_id: Keyword.get(opts, :correlation_id)
       ),
     {:ok, orchestration} <-
       resolve_orchestration(opts, trigger_params, recipient),
     {:ok, delivery} <- apply_declared_orchestration(delivery, channel, orchestration) do
  evaluate_planning_policy(delivery, opts)
end
```

**Digest-held decision pattern** ([lib/chimeway/delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:277)):
```elixir
decision =
  case mode do
    :digest_held ->
      %{
        orchestration_state: :digest_held,
        planning_reason: "digest_rule",
        planning_context: %{
          "channel" => channel,
          "source" => Atom.to_string(Map.get(orchestration, :source, :default))
        },
        next_eligible_at: nil
      }

    :immediate ->
      %{
        orchestration_state: :ready,
        planning_reason: nil,
        planning_context: nil,
        next_eligible_at: nil
      }
  end

Deliveries.apply_planning_decision(delivery, decision)
```

**Copy for Phase 19 edit:** keep accumulation behind this same choke point, after `apply_declared_orchestration/3` and after policy evaluation leaves the row `:pending` + `:digest_held`; do not branch digest state into a separate planning pipeline.

---

### `priv/repo/migrations/*_create_chimeway_digest_rules.exs` (migration, CRUD)

**Analog:** `priv/repo/migrations/20260425000200_create_chimeway_policy_settings.exs`

**Create-table pattern** ([priv/repo/migrations/20260425000200_create_chimeway_policy_settings.exs](/Users/jon/projects/chimeway/priv/repo/migrations/20260425000200_create_chimeway_policy_settings.exs:4)):
```elixir
create table(:chimeway_policy_settings, primary_key: false) do
  add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
  add :recipient_id, :string, null: false
  add :quiet_hours_start_minute, :integer
  add :quiet_hours_end_minute, :integer
  add :delivery_cap_count, :integer
  add :delivery_cap_window_minutes, :integer

  timestamps(type: :utc_datetime_usec)
end
```

**Named unique index pattern** ([priv/repo/migrations/20260425000200_create_chimeway_policy_settings.exs](/Users/jon/projects/chimeway/priv/repo/migrations/20260425000200_create_chimeway_policy_settings.exs:16)):
```elixir
create unique_index(
  :chimeway_policy_settings,
  [:recipient_id],
  name: :chimeway_policy_settings_recipient_index
)
```

**Copy for digest rules:** create the table in one `change/0`, use UUID PKs and `utc_datetime_usec`, and give the durable rule-identity unique index an explicit name for `unique_constraint/3`.

---

### `priv/repo/migrations/*_create_chimeway_digest_buckets.exs` (migration, CRUD)

**Analog:** `priv/repo/migrations/20260424082833_create_chimeway_deliveries.exs`

**Foreign key + timestamps pattern** ([priv/repo/migrations/20260424082833_create_chimeway_deliveries.exs](/Users/jon/projects/chimeway/priv/repo/migrations/20260424082833_create_chimeway_deliveries.exs:5)):
```elixir
create table(:chimeway_deliveries, primary_key: false) do
  add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

  add :notification_id,
      references(:chimeway_notifications, type: :uuid, on_delete: :delete_all),
      null: false

  add :channel, :string, null: false
  add :status, :string, null: false, default: "pending"
  add :metadata, :map

  timestamps(type: :utc_datetime_usec)
end
```

**Composite unique index pattern** ([priv/repo/migrations/20260424082833_create_chimeway_deliveries.exs](/Users/jon/projects/chimeway/priv/repo/migrations/20260424082833_create_chimeway_deliveries.exs:21)):
```elixir
create unique_index(:chimeway_deliveries, [:notification_id, :channel],
         name: :chimeway_deliveries_notification_channel_index
       )
```

**Follow-on index pattern** ([priv/repo/migrations/20260428093000_add_delivery_orchestration_fields_to_chimeway_deliveries.exs](/Users/jon/projects/chimeway/priv/repo/migrations/20260428093000_add_delivery_orchestration_fields_to_chimeway_deliveries.exs:12)):
```elixir
create(
  index(
    :chimeway_deliveries,
    [:orchestration_state, :next_eligible_at],
    name: :chimeway_deliveries_orchestration_state_next_eligible_at_index
  )
)
```

**Copy for digest buckets:** define the composite bucket identity as a named unique index and add secondary lookup indexes for flush/read paths separately.

---

### `priv/repo/migrations/*_create_chimeway_digest_memberships.exs` (migration, CRUD)

**Analog:** `priv/repo/migrations/20260424082834_create_chimeway_delivery_attempts.exs`

**Child table pattern** ([priv/repo/migrations/20260424082834_create_chimeway_delivery_attempts.exs](/Users/jon/projects/chimeway/priv/repo/migrations/20260424082834_create_chimeway_delivery_attempts.exs:4)):
```elixir
create table(:chimeway_delivery_attempts, primary_key: false) do
  add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

  add :delivery_id,
      references(:chimeway_deliveries, type: :uuid, on_delete: :delete_all),
      null: false

  add :outcome, :string, null: false
  add :provider_response, :map
  add :inserted_at, :utc_datetime_usec, null: false
end
```

**Lookup index pattern** ([priv/repo/migrations/20260424082834_create_chimeway_delivery_attempts.exs](/Users/jon/projects/chimeway/priv/repo/migrations/20260424082834_create_chimeway_delivery_attempts.exs:17)):
```elixir
create index(:chimeway_delivery_attempts, [:delivery_id])
```

**Copy for digest memberships:** explicit FK columns, explicit timestamp, regular lookup index on parent FK, plus a named unique index on `delivery_id` for the no-duplicate-membership boundary.

---

### `test/chimeway/digests/digest_rule_test.exs` (test, CRUD)

**Analog:** `test/chimeway/delivery_attempt_test.exs`

**Unit changeset test style** ([test/chimeway/delivery_attempt_test.exs](/Users/jon/projects/chimeway/test/chimeway/delivery_attempt_test.exs:20)):
```elixir
defp valid_attrs(overrides \\ %{}) do
  %{
    delivery_id: "00000000-0000-0000-0000-000000000001",
    outcome: :succeeded,
    attempt_number: 1
  }
  |> Map.merge(overrides)
end
```

**Validation assertion pattern** ([test/chimeway/delivery_attempt_test.exs](/Users/jon/projects/chimeway/test/chimeway/delivery_attempt_test.exs:29)):
```elixir
describe "changeset/2 — base contract (additive change)" do
  test "is valid with delivery_id, outcome, and attempt_number" do
    changeset = DeliveryAttempt.changeset(%DeliveryAttempt{}, valid_attrs())

    assert changeset.valid?,
           "expected base attrs to remain valid; errors=#{inspect(changeset.errors)}"
  end
end
```

**Copy for digest rule tests:** pure `ExUnit.Case` changeset tests for durable rule identity, allowed grouping modes, and window config validation before DB integration tests.

---

### `test/chimeway/digests/digest_bucket_test.exs` (test, CRUD)

**Analog:** `test/chimeway/deliveries_test.exs`

**DataCase + fixture pattern** ([test/chimeway/deliveries_test.exs](/Users/jon/projects/chimeway/test/chimeway/deliveries_test.exs:1)):
```elixir
use Chimeway.DataCase, async: true

alias Chimeway.{Deliveries, Delivery, DeliveryAttempt, Repo}
alias Chimeway.Events.Event
alias Chimeway.Notifications.Notification
import Ecto.Query, only: [from: 2]
```

**Idempotency assertion pattern** ([test/chimeway/deliveries_test.exs](/Users/jon/projects/chimeway/test/chimeway/deliveries_test.exs:61)):
```elixir
test "is idempotent: duplicate calls create exactly one row" do
  %{notification: notification} = insert_notification()

  assert {:ok, _} = Deliveries.plan_delivery(notification.id, :in_app)
  assert {:ok, _} = Deliveries.plan_delivery(notification.id, :in_app)

  count =
    Repo.aggregate(
      from(d in Delivery, where: d.notification_id == ^notification.id),
      :count,
      :id
    )

  assert count == 1
end
```

**Copy for digest bucket tests:** use `DataCase`, seed real parent rows, and assert one bucket per durable identity even under repeated accumulation attempts.

---

### `test/chimeway/digests/accumulation_test.exs` (test, event-driven)

**Analog:** `test/chimeway/orchestration/delivery_planning_test.exs`

**Notifier-driven orchestration fixture pattern** ([test/chimeway/orchestration/delivery_planning_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/delivery_planning_test.exs:10)):
```elixir
defmodule DigestEmailNotifier do
  use Chimeway.Notifier

  @impl true
  def notification_key, do: "delivery-planning.digest"

  @impl true
  def version, do: 1

  @impl true
  def recipients(_params), do: {:ok, [%{recipient_identity: "user-planning"}]}
  def build(_params, recipient), do: {:ok, %{recipient: recipient}}
  def channels(_params, _recipient), do: {:ok, [:email]}
  def orchestration(_params, _recipient), do: {:ok, [email: :digest]}
end
```

**Canonical-row preservation assertion** ([test/chimeway/orchestration/delivery_planning_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/delivery_planning_test.exs:32)):
```elixir
test "planner keeps one canonical row when a channel is declared as digest-held" do
  notification = insert_notification("user-planning")

  assert {:ok, [delivery]} =
           DeliveryPlanning.plan_notification(notification,
             notifier: DigestEmailNotifier,
             trigger_params: %{}
           )

  assert delivery.orchestration_state == :digest_held
  assert delivery.planning_reason == "digest_rule"
end
```

**Digest-held planning contract** ([test/chimeway/orchestration/planning_declarations_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/planning_declarations_test.exs:47)):
```elixir
test "declared digest participation persists digest_held on the canonical delivery row" do
  notification = insert_notification("user-digest")

  assert {:ok, [delivery]} =
           DeliveryPlanning.plan_notification(notification,
             notifier: DigestEmailNotifier,
             trigger_params: %{}
           )

  assert delivery.status == :pending
  assert delivery.orchestration_state == :digest_held
  assert delivery.planning_context == %{"channel" => "email", "source" => "notifier"}
end
```

**Rollback expectation pattern** ([test/chimeway/deliveries_test.exs](/Users/jon/projects/chimeway/test/chimeway/deliveries_test.exs:306)):
```elixir
test "rolls back attempt insert if status transition fails" do
  result = Deliveries.record_attempt(delivery, %{outcome: :succeeded})

  assert {:error, :delivery, {:invalid_transition, from: :pending, to: :succeeded}, _} = result
  assert Repo.aggregate(DeliveryAttempt, :count, :id) == 0
end
```

**Copy for accumulation tests:** verify accumulation only happens for pending `:digest_held` rows, verify re-planning does not create duplicate bucket/membership rows, and add at least one rollback case where bucket writes and membership writes are both undone.

## Shared Patterns

### Canonical Delivery Row
**Sources:** [lib/chimeway/delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:87), [lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:72)
**Apply to:** `lib/chimeway/digests/accumulation.ex`, `lib/chimeway/delivery_planning.ex`, accumulation tests
```elixir
with {:ok, delivery} <-
       Deliveries.plan_delivery(notification.id, channel,
         delay_fallback: delay_fallback,
         delayed_fallback_source: source,
         notification_key: Keyword.get(opts, :notification_key),
         event_id: Keyword.get(opts, :event_id),
         correlation_id: Keyword.get(opts, :correlation_id)
       ),
     {:ok, orchestration} <-
       resolve_orchestration(opts, trigger_params, recipient),
     {:ok, delivery} <- apply_declared_orchestration(delivery, channel, orchestration) do
  evaluate_planning_policy(delivery, opts)
end
```

### Upsert and Unique Boundary
**Sources:** [lib/chimeway/preferences.ex](/Users/jon/projects/chimeway/lib/chimeway/preferences.ex:18), [lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:63)
**Apply to:** digest rule upserts, bucket creation, membership insertion
```elixir
%NotificationPreference{}
|> NotificationPreference.changeset(attrs)
|> Repo.insert(
  on_conflict: {:replace, [:enabled, :updated_at]},
  conflict_target: [:recipient_id, :notification_key, :channel]
)
```

```elixir
%Delivery{}
|> Delivery.changeset(%{notification_id: notification_id, channel: channel_str, status: :pending})
|> Repo.insert(on_conflict: :nothing, conflict_target: [:notification_id, :channel])
```

### Transaction and Rollback
**Sources:** [lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:457), [lib/chimeway/trigger.ex](/Users/jon/projects/chimeway/lib/chimeway/trigger.ex:68)
**Apply to:** `lib/chimeway/digests/accumulation.ex`
```elixir
Multi.new()
|> Multi.insert(:event, Event.changeset(%Event{}, %{...}))
|> Multi.run(:notifications, fn repo, %{event: event} ->
  insert_notifications(repo, notifier, params, event, normalized_recipients)
end)
|> Repo.transaction()
```

```elixir
|> case do
  {:ok, %{delivery: updated_delivery, attempt: attempt}} ->
    {:ok, %{delivery: updated_delivery, attempt: attempt}}

  {:error, step, reason, changes} ->
    {:error, step, reason, changes}
end
```

### Explainability and Sanitized Durable Facts
**Sources:** [lib/chimeway/delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:282), [lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:544), [lib/chimeway/trigger.ex](/Users/jon/projects/chimeway/lib/chimeway/trigger.ex:226)
**Apply to:** digest rule, bucket, and membership fields
```elixir
%{
  orchestration_state: :digest_held,
  planning_reason: "digest_rule",
  planning_context: %{
    "channel" => channel,
    "source" => Atom.to_string(Map.get(orchestration, :source, :default))
  },
  next_eligible_at: nil
}
```

```elixir
@sensitive_keys ~w(password token secret)

defp sanitize_metadata(map) when is_map(map) do
  Enum.reduce(map, %{}, fn {key, value}, acc ->
    if sensitive_key?(key), do: acc, else: Map.put(acc, key, value)
  end)
end
```

## No Analog Found

None. Every planned file has a usable existing analog in the current codebase.

## Metadata

**Analog search scope:** `lib/chimeway`, `priv/repo/migrations`, `test/chimeway`
**Files scanned:** 15
**Pattern extraction date:** 2026-04-28

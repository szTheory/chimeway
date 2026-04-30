# Phase 24: Workflow Contracts & State Spine - Pattern Map

**Mapped:** 2026-04-29
**Files analyzed:** 13
**Analogs found:** 13 / 13

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/chimeway/notifier.ex` | contract | transform | `lib/chimeway/notifier.ex` | exact |
| `lib/chimeway/trigger.ex` | service | trigger-time persistence | `lib/chimeway/trigger.ex` | exact |
| `lib/chimeway/notifications/notification.ex` | schema | anchor | `lib/chimeway/notifications/notification.ex` | exact |
| `lib/chimeway/delivery.ex` | schema | execution linkage | `lib/chimeway/delivery.ex` | exact |
| `lib/chimeway/delivery_planning.ex` | service | runtime linkage | `lib/chimeway/delivery_planning.ex` | exact |
| `lib/chimeway/deliveries.ex` | service | replay / recovery | `lib/chimeway/deliveries.ex` | exact |
| `lib/chimeway/workflows/workflow_definition.ex` | schema | durable declaration | `lib/chimeway/digests/digest_rule.ex` | role+flow |
| `lib/chimeway/workflows/workflow_step.ex` | schema | ordered child rows | `lib/chimeway/digests/digest_membership.ex` | role |
| `lib/chimeway/workflows/workflow_run.ex` | schema | aggregate current state | `lib/chimeway/digests/digest_bucket.ex` | role+flow |
| `lib/chimeway/workflows/workflow_transition.ex` | schema | append-only history | `lib/chimeway/digests/digest_membership.ex` | role+flow |
| `test/chimeway/notifier_contract_test.exs` | test | contract | `test/chimeway/notifier_contract_test.exs` | exact |
| `test/chimeway/trigger_pipeline_test.exs` | test | trigger integration | `test/chimeway/trigger_pipeline_test.exs` | exact |
| `test/chimeway/orchestration/recovery_test.exs` | test | replay regression | `test/chimeway/orchestration/recovery_test.exs` | role+flow |

## Pattern Assignments

### `lib/chimeway/notifier.ex` (contract, transform)

**Analog:** `lib/chimeway/notifier.ex`

Use the existing callback + normalization posture already used for `rendering/2` and `orchestration/2`.

**Pattern to copy:**

- add a new optional callback for workflow declarations
- normalize atoms/strings into string channel keys
- return `{:ok, normalized}` or wrapped tagged errors
- serialize persisted snapshots with string keys only

**Relevant shape:**

```elixir
@callback orchestration(map(), map()) ::
            {:ok, :immediate | :digest | :digest_held | keyword(atom()) | map()}
            | {:error, term()}
```

```elixir
def resolve_orchestration(notifier, trigger_params, recipient, override \\ :unset)
```

Workflow declarations should follow this same contract style: one public resolve function, one normalization pipeline, one serialization helper for durable persistence.

### `lib/chimeway/trigger.ex` (service, trigger-time persistence)

**Analog:** `lib/chimeway/trigger.ex`

Workflow declaration persistence belongs in the same transaction that inserts notifications.

**Pattern to copy:**

```elixir
with {:ok, rendering} <- Notifier.resolve_rendering(notifier, params, recipient),
     {:ok, orchestration} <- Notifier.resolve_orchestration(notifier, params, recipient) do
  ...
end
```

```elixir
row = %{
  id: UUID.generate() |> UUID.dump!(),
  event_id: UUID.dump!(event.id),
  recipient_identity: recipient_identity(recipient),
  ...
  render_channels: render_channels,
  orchestration: orchestration,
  inserted_at: timestamp,
  updated_at: timestamp
}
```

Phase 24 should extend this posture, not bypass it. Workflow definitions/runs should be inserted inside the trigger transaction so notifications and workflow spine stay consistent.

### `lib/chimeway/workflows/workflow_definition.ex` (schema, durable declaration)

**Analog:** `lib/chimeway/digests/digest_rule.ex`

Use:

- `@primary_key {:id, :binary_id, autogenerate: true}`
- string key + integer version fields
- unique constraint on `(workflow_key, workflow_version)`
- explicit columns and numeric validation

**Relevant shape:**

```elixir
field(:rule_key, :string)
field(:rule_version, :integer)
...
|> validate_number(:rule_version, greater_than: 0)
|> unique_constraint([:rule_key, :rule_version],
  name: :chimeway_digest_rules_rule_key_rule_version_index
)
```

### `lib/chimeway/workflows/workflow_run.ex` (schema, aggregate current state)

**Analog:** `lib/chimeway/digests/digest_bucket.ex`

Use the digest bucket posture for a single current-state row:

- explicit enum state
- current linked child row id
- timestamps for state changes
- foreign keys to durable declaration and emitted execution artifacts

**Relevant shape:**

```elixir
field(:flush_state, Ecto.Enum, values: [:pending, :claimed, :emitted], default: :pending)
belongs_to(:digest_rule, DigestRule)
belongs_to(:digest_delivery, Chimeway.Delivery)
```

The workflow run equivalent should track `state`, `current_step_id`, maybe `current_delivery_id`, and reason/context fields without inferring those from transition history at read time.

### `lib/chimeway/workflows/workflow_transition.ex` (schema, append-only history)

**Analog:** `lib/chimeway/digests/digest_membership.ex`

Use one row per durable fact, with explicit linkage to the owning aggregate row and optional delivery linkage.

**Relevant shape:**

```elixir
belongs_to(:digest_bucket, DigestBucket)
belongs_to(:delivery, Delivery)
field(:resolution, Ecto.Enum, values: [:included, :skipped_by_policy, :emitted_immediately])
field(:resolution_reason, :string)
field(:resolved_at, :utc_datetime_usec)
```

Workflow transition rows should follow the same explicit-fact posture:

- `from_state`
- `to_state`
- `reason`
- `context`
- `workflow_step_id`
- `delivery_id`

### `lib/chimeway/delivery.ex` (schema, execution linkage)

**Analog:** `lib/chimeway/delivery.ex`

Phase 24 likely needs additive workflow linkage fields on deliveries so later progression phases can answer "which run/step produced this delivery?"

Use the existing posture of optional orchestration linkage, not metadata-only linkage.

### `lib/chimeway/delivery_planning.ex` (service, runtime linkage)

**Analog:** `lib/chimeway/delivery_planning.ex`

The planner already resolves persisted declarations, creates canonical delivery rows, and applies orchestration. Workflow linkage should happen in the same seam.

**Relevant shape:**

```elixir
with {:ok, delivery} <- Deliveries.plan_delivery(notification.id, channel, ...),
     {:ok, delivery} <- maybe_apply_render_result(delivery, render_result),
     {:ok, orchestration} <- resolve_orchestration(notification, opts, trigger_params, recipient),
     {:ok, delivery} <- apply_declared_orchestration(delivery, channel, orchestration) do
```

Additive Phase 24 work should pass persisted workflow run/step identity through this seam and stamp the first-step delivery row durably.

### `lib/chimeway/deliveries.ex` (service, replay / recovery)

**Analog:** `lib/chimeway/deliveries.ex`

Recovery must reuse persisted declarations and explicit opts.

**Relevant shape:**

```elixir
dispatch_opts = [
  event_id: event.id,
  notification_key: event.notification_key,
  correlation_id: event.correlation_id,
  post_commit: true,
  use_persisted_channels: true,
  use_persisted_orchestration: true
]
```

Phase 24 replay support should mirror this with persisted workflow declarations rather than callback re-entry.

### `test/chimeway/notifier_contract_test.exs` (test, contract)

**Analog:** `test/chimeway/notifier_contract_test.exs`

Add workflow declaration normalization/validation tests beside the existing orchestration/rendering contract tests.

### `test/chimeway/trigger_pipeline_test.exs` (test, trigger integration)

**Analog:** `test/chimeway/trigger_pipeline_test.exs`

Use this suite for the main Phase 24 proof that one trigger persists notification rows plus the new workflow definition/run/transition artifacts.

### `test/chimeway/orchestration/recovery_test.exs` (test, replay regression)

**Analog:** `test/chimeway/orchestration/recovery_test.exs`

Use this suite for the "no notifier callback re-entry" guarantee. Phase 24 needs regression coverage similar to the persisted rendering/orchestration recovery tests.

## Recommended Plan/File Groupings

### Plan group 1: declaration contract + schema layer

- `lib/chimeway/notifier.ex`
- `lib/chimeway/workflows/workflow_definition.ex`
- `lib/chimeway/workflows/workflow_step.ex`
- migration files
- `test/chimeway/notifier_contract_test.exs`

### Plan group 2: trigger-time persistence + run creation

- `lib/chimeway/trigger.ex`
- `lib/chimeway/workflows.ex`
- `lib/chimeway/workflows/workflow_run.ex`
- `lib/chimeway/workflows/workflow_transition.ex`
- `test/chimeway/trigger_pipeline_test.exs`

### Plan group 3: delivery / replay linkage

- `lib/chimeway/delivery.ex`
- `lib/chimeway/delivery_planning.ex`
- `lib/chimeway/deliveries.ex`
- `test/chimeway/orchestration/recovery_test.exs`

## Planning Notes

- Prefer first-class workflow tables over extending `notifications.orchestration` into a workflow blob.
- Keep the first executable delivery tied to the active workflow step in Phase 24, but do not implement wait/branch/escalation behavior yet.
- Make task actions concrete about field names, unique indexes, and replay opts because this phase spans schema, trigger, planning, and recovery seams.

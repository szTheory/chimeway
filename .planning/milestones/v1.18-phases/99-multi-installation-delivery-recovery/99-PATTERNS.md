# Phase 99: Multi-Installation Delivery & Recovery - Pattern Map

**Mapped:** 2026-08-19  
**Files analyzed:** 21 implementation/test/fixture paths  
**Analogs found:** 21 / 21

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/chimeway/target_resolver.ex` | behaviour/value object | request-response | `lib/chimeway/render_context_resolver.ex` | role-match |
| `lib/chimeway/delivery_target.ex` | model | CRUD/state-machine | `lib/chimeway/delivery.ex` | role-match |
| `lib/chimeway/delivery_target_attempt.ex` | model | append-only/event-driven | `lib/chimeway/delivery_attempt.ex` | exact |
| `lib/chimeway/deliveries.ex` | service | CRUD/event-driven | same file | exact extension |
| `lib/chimeway/delivery_planning.ex` | service | request-response/fan-out | same file | exact extension |
| `lib/chimeway/dispatch/executor.ex` | service | request-response/provider I/O | same file | exact extension |
| `lib/chimeway/dispatch/oban.ex` | service | event-driven | same file | exact extension |
| `lib/chimeway/dispatch/oban_worker.ex` | worker | event-driven | same file | exact extension |
| `lib/chimeway/dispatch/recovery_worker.ex` | worker | batch/event-driven | `lib/chimeway/dispatch/deferred_resume_worker.ex` | role-match |
| `lib/chimeway/traces.ex` | service/projection | request-response | same file | exact extension |
| `lib/chimeway/safe_evidence.ex` | utility/privacy boundary | transform | same file | exact extension |
| `priv/chimeway_migrations/035_create_chimeway_delivery_targets.exs` | migration | CRUD/schema | `004_create_chimeway_delivery_attempts.exs` | exact |
| `test/chimeway/delivery_target_test.exs` | test | CRUD/state-machine | `delivery_attempt_test.exs` | role-match |
| `test/chimeway/dispatch/target_worker_test.exs` | test | event-driven | `dispatch/oban_worker_test.exs` | exact |
| `test/chimeway/orchestration/target_recovery_test.exs` | test | batch/event-driven | `orchestration/recovery_test.exs` | exact |
| `test/chimeway/traces_target_test.exs` | test | request-response | `traces_test.exs` | exact |
| `test/chimeway/migration_contract_test.exs` | test | migration/file-I/O | same file | exact extension |
| `test/chimeway/install/migrations_test.exs` | test | file-I/O | same file | exact extension |
| `test/chimeway/install/golden_diff_test.exs` | test | file-I/O | same file | exact extension |
| `test/chimeway/install/prefix_contract_test.exs` | test | file-I/O | same file | exact extension |
| `test/fixtures/installer_golden_{prefixed,public}/.../035_create_chimeway_delivery_targets.exs` | fixture | file-I/O | existing generated migration fixtures | exact |

The phase should not add APNs token/provider request models or any raw endpoint persistence. Resolver output, worker args, telemetry, trace DTOs, and attempts remain durable IDs plus closed safe facts only.

## Pattern Assignments

### `lib/chimeway/target_resolver.ex` (behaviour/value object, request-response)

**Analog:** `lib/chimeway/render_context_resolver.ex` for host callback resolution; enforce the stronger Phase 98 closed-evidence boundary in `lib/chimeway/safe_evidence.ex`.

**Opaque-reference validation** — `lib/chimeway/safe_evidence.ex:74-96`:

```elixir
@spec opaque_ref(atom() | String.t(), term()) :: {:ok, String.t()} | {:error, :unsafe_evidence}
def opaque_ref(domain, value) when domain in [:provider, :provider_message_id, :recipient, :correlation] and is_binary(value) do
  if byte_size(value) in 4..@max_ref_bytes and String.match?(value, ~r/^cw_[a-z0-9][a-z0-9_-]*$/) do
    {:ok, value}
  else
    {:error, :unsafe_evidence}
  end
end
```

Copy the data-first callback convention, but make tenant an explicit callback input and accept only a normalized binding revision struct/map. Extend `opaque_ref/2` with a `:binding_revision` domain rather than accepting arbitrary maps. Reject a missing/mismatched tenant, extra nested facts, raw token/endpoint/credential keys, and duplicates before persistence.

### `lib/chimeway/delivery_target.ex` (model, CRUD/state machine)

**Analog:** `lib/chimeway/delivery.ex:14-88`.

**Schema/changeset pattern:**

```elixir
@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id

schema "chimeway_deliveries" do
  field(:tenant_id, :string)
  field(:status, Ecto.Enum, values: [:pending, :dispatched, :succeeded, :failed, :suppressed, :cancelled])
  belongs_to(:notification, Notification)
  has_many(:attempts, Chimeway.DeliveryAttempt)
  timestamps(type: :utc_datetime_usec)
end

delivery |> cast(attrs, @required_fields ++ @optional_fields) |> validate_required(@required_fields)
```

Use a child table with `delivery_id`, `tenant_id`, opaque `binding_revision_ref`, target status, and bounded lease/state facts. Add associations from `Delivery` (`has_many :targets`) and target (`has_many :attempts`). Use stable target state names such as `:pending`, `:claimed`, `:retryable`, `:provider_accepted`, `:expired`, `:invalidated`, `:ambiguous_handoff`; never use a bare device-delivered state.

### `lib/chimeway/delivery_target_attempt.ex` (model, append-only event-driven)

**Analog:** `lib/chimeway/delivery_attempt.ex:39-80`.

**Immutable ordered history pattern:**

```elixir
schema "chimeway_delivery_attempts" do
  field(:outcome, Ecto.Enum, values: [:succeeded, :failed, :bounced, :rejected])
  field(:provider_response, :map)
  field(:attempt_number, :integer)
  field(:error_class, :string)
  field(:inserted_at, :utc_datetime_usec)
  belongs_to(:delivery, Chimeway.Delivery)
end

@required_fields ~w(delivery_id outcome attempt_number)a
```

Keep the no-`updated_at` append-only rule. Adapt foreign key/name and vocabulary to record target claim, `attempt_started` before I/O, terminal outcome, ambiguous closeout, and linked authorized re-drive/duplicate-risk facts. Validate ordinal positive and persist only `SafeEvidence`-validated fields.

### `lib/chimeway/deliveries.ex` (service, CRUD/event-driven)

**Analog:** current planning, recovery, and attempt transaction sections.

**Canonical parent identity/reload** — `lib/chimeway/deliveries.ex:329-355`:

```elixir
%Delivery{}
|> Delivery.changeset(attrs)
|> Repo.insert(on_conflict: :nothing, conflict_target: [:notification_id, :channel])

# on_conflict: :nothing returns a phantom struct on conflict.
{:ok, Repo.get_by!(Delivery, notification_id: notification_id, channel: channel_str)}
```

For each normalized selected revision, use this exact insert-then-authoritative-reload idiom with a database unique index on `{delivery_id, binding_revision_ref}`. Preserve the one parent `{notification_id, "push"}` identity; do not create per-installation `Delivery` rows.

**Tenant-scoped conditional claim** — `lib/chimeway/deliveries.ex:109-137`:

```elixir
from(d in Delivery,
  where: d.id == ^delivery_id and d.tenant_id == ^tenant_id and d.status == :pending and
    d.orchestration_state == :ready and d.updated_at <= ^cutoff,
  update: [set: [metadata: fragment("COALESCE(?, '{}'::jsonb) || ?::jsonb", d.metadata, ^metadata_patch), updated_at: ^now]]
)
|> Repo.update_all([])
```

Duplicate this conditional-update shape for target claims: include target id, tenant id, eligible nonterminal status, and lease expiry in the `where`; `{1, _}` is the only authorization to persist claim/start and do provider I/O. On `{0, _}`, reload only through the same tenant predicate and return a non-disclosing noop.

**Ordered attempt transaction** — `lib/chimeway/deliveries.ex:1153-1185`:

```elixir
Multi.new()
|> Multi.run(:lock_delivery, fn repo, _ ->
  case repo.one(from(d in Delivery, where: d.id == ^delivery.id, lock: "FOR UPDATE")) do
    nil -> {:error, :delivery_not_found}
    locked -> {:ok, locked}
  end
end)
|> Multi.run(:next_attempt_number, fn repo, %{lock_delivery: locked} ->
  {:ok, repo.one(from(a in DeliveryAttempt, where: a.delivery_id == ^locked.id, select: count(a.id))) + 1}
end)
|> Multi.insert(:attempt, fn %{next_attempt_number: n} -> DeliveryAttempt.changeset(%DeliveryAttempt{}, Map.put(safe_attrs, :attempt_number, n)) end)
|> Repo.transaction()
```

Copy the lock/ordinal/Multi pattern for target attempts. The target-specific path must insert claim plus `attempt_started` before returning a claimed target to `Executor`; provider result recording and parent aggregate recomputation occur after the result. Recovery closes stale started work as `ambiguous_handoff`, never as retryable unsent work.

**Recovery query scope** — `lib/chimeway/deliveries.ex:36-53` and `218-274`: resolve `TenantScope` first, carry `tenant_id` in every join, and return `[]`/`{:noop, nil}` on absent or wrong scope. Add explicit bounded limit/keyset ordering to new target discovery; do not use unbounded `Repo.all` scans.

### `lib/chimeway/delivery_planning.ex` (service, request-response/fan-out)

**Analog:** `lib/chimeway/delivery_planning.ex:24-42, 130-182`.

```elixir
notifications
|> Enum.sort_by(& &1.id)
|> Enum.reduce_while({:ok, []}, fn notification, {:ok, acc} ->
  case plan_notification(notification, opts) do
    {:ok, deliveries} -> {:cont, {:ok, [deliveries | acc]}}
    {:error, _reason} = error -> {:halt, error}
  end
end)
```

Keep this module as the only fan-out planning seam. In its `push` branch, resolve the tenant from the notification exactly as `resolve_delivery_tenant/2` does at lines 185-194, create/reload the canonical logical delivery, call resolver/normalizer, and idempotently persist sorted target rows. No selected revisions must write the stable parent suppression reason `no_eligible_targets` through named `Deliveries` lifecycle API.

### `lib/chimeway/dispatch/{executor,oban,oban_worker,recovery_worker}.ex` (workers/provider I/O, event-driven)

**Executor analog:** `lib/chimeway/dispatch/executor.ex:29-55` currently exposes the gap:

```elixir
with {:ok, dispatched} <- Deliveries.transition_status(delivery, :dispatched) do
  {attempt_outcome, error_class, safe_attempt_facts} =
    execution_delivery |> adapter.deliver(adapter_config) |> classify()

  Deliveries.record_attempt(execution_delivery, Map.merge(safe_attempt_facts, %{outcome: attempt_outcome, error_class: error_class}))
end
```

Replace the target path with `Deliveries.begin_target_attempt/…` (claim + durable `attempt_started`) before `adapter.deliver/…`; run result classification through the same `SafeEvidence` funnel at lines 73-96. Do not reuse delivery-level attempt outcome as target truth.

**Target-aware job and short-circuit analog:** `lib/chimeway/dispatch/oban_worker.ex:101-138`:

```elixir
use Oban.Worker, queue: :chimeway_delivery, max_attempts: 5,
  unique: [fields: [:args], keys: [:delivery_id], period: 60]

delivery = Deliveries.get_delivery!(delivery_id)
if delivery.status in Deliveries.terminal_states() or delivery.orchestration_state != :ready do
  :ok
else
  # durable row decides eligibility before adapter work
end
```

Target jobs carry only `delivery_target_id` and explicit `tenant_id` (opaque durable identifiers, never raw values); uniqueness becomes defense-in-depth with target identity, while `claim_target` is the actual send gate. Preserve current terminal short-circuit style. Add a recovery worker using `DeferredResumeWorker`'s explicit `%{"delivery_id" => id, "tenant_id" => tenant}` entry point and `Ecto.Multi` transaction (`deferred_resume_worker.ex:24-74`), but batch/recovery APIs must own bounded discovery and safe evidence.

### `lib/chimeway/{safe_evidence,traces}.ex` (privacy utility/projection)

**Safe attempt evidence** — `lib/chimeway/safe_evidence.ex:213-238`:

```elixir
with {:ok, facts} <- provider_facts(provider_response || %{}),
     {:ok, provider_ref} <- optional_provider_ref(provider_message_id),
     {:ok, outcome} <- required_field(attrs, "outcome", :outcome, &valid_outcome/1) do
  {:ok, %{outcome: outcome, error_class: error_class, provider_message_id: provider_ref, provider_response: facts}}
end
```

Extend with dedicated target evidence constructors, allowlisted timeline events/fields, target IDs, binding-revision opaque projection, claim/skip/recovery reasons, `provider_accepted`, `partial_failure`, and `ambiguous_handoff`. Never broaden generic map passthrough; raw target material and provider bodies are rejected/redacted.

**Tenant-filtered trace query** — `lib/chimeway/traces.ex:175-229`:

```elixir
with {:ok, tenant_id} <- TenantScope.resolve(opts) do
  Repo.one(from(d in Delivery,
    join: n in Notification, on: n.id == d.notification_id,
    join: e in Event, on: e.id == n.event_id,
    where: d.id == ^delivery_id and d.tenant_id == ^tenant_id and n.tenant_id == ^tenant_id and e.tenant_id == ^tenant_id,
    preload: [notification: :event, attempts: []]
  ))
end
```

Extend both preload/query and `SafeEvidence.trace/1` DTO construction with target and target-attempt histories. Every child preload/join must repeat the resolved tenant predicate. Project parent aggregate plus children, retain partial/indeterminate evidence, and label positive handoff only `provider_accepted`.

### Migration, installer, and tests

**Migration template:** copy the prefix-safe helper structure from `priv/chimeway_migrations/004_create_chimeway_delivery_attempts.exs:1-44`; every table/index/reference must call `chimeway_*` helpers. Include deterministic 035 template(s), foreign keys, target identity unique index, target attempt ordinal/indexes, no raw endpoint column.

**Installer ordering:** `lib/chimeway/install/migrations.ex:46-52` discovers numeric templates and sorts order; extend `@expected_slugs` and counts in `test/chimeway/install/migrations_test.exs:9-57`.

**Static mode parity:** copy generated 035 to both fixture trees and update `test/chimeway/install/golden_diff_test.exs:32-67`, prefix contract assertions (`prefix_contract_test.exs:22-64`), and migration contract dual-mode loop (`migration_contract_test.exs:23-88`). The existing fixture count is 34 and must become the new exact count everywhere; refresh goldens only via the documented acceptance path.

**Executable tests:** use focused new tests modeled on:

```elixir
# idempotent canonical planning
assert {:ok, [delivery]} = DeliveryPlanning.plan_notification(notification, ...)
assert {:ok, [replanned]} = DeliveryPlanning.plan_notification(notification, ...)
assert replanned.id == delivery.id
```

from `test/chimeway/orchestration/delivery_planning_test.exs:131-174`, and wrong-tenant non-disclosure from `test/chimeway/orchestration/recovery_test.exs:730-757`:

```elixir
assert {:noop, result} = Deliveries.recover_delivery(delivery.id, tenant_id: "tenant-a", ...)
assert result.delivery == nil
refute inspect(result) =~ delivery.id
refute_received {:dispatch_delivery, _, _}
```

Add race tests for duplicate resolution/claim/recovery, pre-I/O persistence, stale-start ambiguous closeout, policy-gated linked re-drive, no-target suppression, mixed aggregate outcome, cross-tenant trace/recovery non-disclosure, and provider call short-circuit. All are automated executable evidence (`type="auto"`), not human UAT.

## Shared Patterns

### Tenant scope and non-disclosure

**Source:** `lib/chimeway/tenant_scope.ex:10-43`, `lib/chimeway/deliveries.ex:36-53`, `lib/chimeway/traces.ex:175-196`  
**Apply to:** resolver, planning, target APIs, worker args, recovery discovery/claims/reloads, aggregates, traces.

Resolve exactly one tenant; include it in every query, join, preload, conditional mutation, and job. Wrong or absent scope returns empty/not-found/noop without exposing identifiers.

### Durable concurrency boundary

**Source:** `lib/chimeway/deliveries.ex:329-355, 1153-1185`  
**Apply to:** target insertion, claims, attempt numbering, recovery/re-drive.

Database uniqueness + authoritative reload + conditional update + row lock are correctness primitives. Oban uniqueness does not substitute for them.

### Privacy-safe evidence

**Source:** `lib/chimeway/safe_evidence.ex:74-96, 196-238, 259-300`  
**Apply to:** resolver normalization, durable facts, attempt/claim histories, telemetry, traces, recovery result DTOs.

Use opaque refs and closed vocabulary only. Never persist or log raw token, endpoint, credential, arbitrary resolver map, rendered payload, or provider response body.

### Migration/template parity

**Source:** `priv/chimeway_migrations/004_create_chimeway_delivery_attempts.exs:5-43`; `test/chimeway/install/prefix_contract_test.exs:34-77`  
**Apply to:** every new copied migration and both generated fixture modes.

Use prefix helpers everywhere and prove public/prefixed generated migrations plus golden/contract behavior in CI-local parity.

## No Analog Found

| File/Concern | Role | Data Flow | Reason |
|---|---|---|---|
| Target aggregate recomputation and `ambiguous_handoff` state vocabulary | service/model | state-machine | Existing delivery state only has one channel-level attempt; Phase 99 creates this target-specific semantic layer. Base it on `Deliveries` transactions and locked Phase 99 decisions. |
| Opaque target resolver public behaviour | behaviour | request-response | No installation resolver exists; copy host callback shape but enforce the new closed target contract. |

## Metadata

**Analog search scope:** `lib/chimeway`, `priv/chimeway_migrations`, `test/chimeway`, Phase 97/98 context/pattern artifacts  
**Files scanned:** 39  
**Pattern extraction date:** 2026-08-19

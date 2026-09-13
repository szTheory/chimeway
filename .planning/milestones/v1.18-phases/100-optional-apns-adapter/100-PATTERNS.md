# Phase 100: Optional APNs Adapter - Pattern Map

**Mapped:** 2026-08-20  
**Files analyzed:** 22 planned files/fixtures  
**Analogs found:** 21 / 22

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/chimeway/adapters/apns.ex` | adapter | request-response | `lib/chimeway/adapters/mailglass.ex` | role-match |
| `lib/chimeway/apns/request_intent.ex` | model | transform | `lib/chimeway/target_resolver.ex` | partial |
| `lib/chimeway/apns/binding_lookup.ex` | behaviour/service | request-response | `lib/chimeway/target_resolver.ex` | role-match |
| `lib/chimeway/apns/transport.ex` | service | request-response | `lib/chimeway/adapters/mailglass.ex` | partial |
| `lib/chimeway/apns/payload.ex` | utility | transform | `lib/chimeway/rendering/channels/push.ex` | role-match |
| `lib/chimeway/target_adapter.ex` | behaviour | request-response | itself | modify-existing |
| `lib/chimeway/dispatch/executor.ex` | controller | event-driven | `lib/chimeway/dispatch/executor.ex` | modify-existing |
| `lib/chimeway/delivery_targets.ex` | service | CRUD/event-driven | itself | modify-existing |
| `lib/chimeway/delivery_target.ex` | model | CRUD | itself | modify-existing |
| `lib/chimeway/delivery_target_attempt.ex` | model | CRUD | itself | modify-existing |
| `lib/chimeway/safe_evidence.ex` | utility | transform | itself | modify-existing |
| `lib/chimeway/rendering/channels/push.ex` | component/validator | transform | itself | modify-existing |
| `priv/chimeway_migrations/037_*apns*.exs` | migration | CRUD | `priv/chimeway_migrations/035_create_chimeway_delivery_targets.exs` | role-match |
| `priv/repo/migrations/*_apns*.exs` | migration | CRUD | `priv/repo/migrations/20260819000001_create_chimeway_delivery_targets.exs` | exact |
| `test/chimeway/adapters/apns_test.exs` | test | request-response | `test/chimeway/adapters/mailglass_adapter_test.exs` | role-match |
| `test/chimeway/apns/request_test.exs` | test | transform | no close test module | none |
| `test/chimeway/apns/result_test.exs` | test | request-response | `test/chimeway/dispatch/target_worker_test.exs` | role/data-flow match |
| `test/support/apns_fake_transport.ex` | test utility | request-response | `test/chimeway/dispatch/target_worker_test.exs` | partial |
| `test/chimeway/dispatch/target_worker_test.exs` | test | event-driven | itself | modify-existing |
| `test/chimeway/safe_evidence_test.exs` | test | transform | `lib/chimeway/safe_evidence.ex` contracts | modify-existing |
| `mix.exs` / `.github/workflows/ci.yml` | config | batch | existing Mailglass verification lane | role-match |
| migration contract and prefixed/public golden fixture trees | test fixture | file-I/O | `test/chimeway/migration_contract_test.exs` + `036` fixture entries | exact |

## Pattern Assignments

### `lib/chimeway/adapters/apns.ex` (adapter, request-response)

**Analog:** `lib/chimeway/adapters/mailglass.ex`

Use the existing optional-library compilation guard, but implement `Chimeway.TargetAdapter`, not the legacy `Chimeway.Adapter`. Keep all `Pigeon` references inside the guard and dynamically invoke the transport so a host without Pigeon compiles and boots.

**Optional dependency guard** (lines 1-17):

```elixir
if Code.ensure_loaded?(Mailglass) do
  defmodule Chimeway.Adapters.Mailglass do
    @behaviour Chimeway.Adapter

    @compile {:no_warn_undefined, [Mailglass.Outbound, Mailglass.Message, ...]}
```

**Validation before provider I/O** (lines 63-89):

```elixir
with :ok <- validate_tenant_id(delivery),
     {:ok, recipient} <- resolve_recipient(delivery),
     {:ok, msg} <- build_message(delivery, recipient, config) do
  Mailglass.Outbound.deliver(msg, outbound_opts)
  |> case do
    {:ok, mg_delivery} -> {:ok, meta}
    {:error, err} -> classify_mailglass_error(err)
  end
end
```

**Safe closed classification fallback** (lines 181-215):

```elixir
defp classify_mailglass_error(%Mailglass.RateLimitError{} = err),
  do: {:error, :temporary, error_detail(err)}

defp classify_mailglass_error(_),
  do: {:error, :permanent, %{reason: :unknown_mailglass_error}}
```

For APNs, map Pigeon unavailability and invalid host lookup to explicit pre-handoff results; map timeout/exit/missing post-emission result to ambiguity; unknown conclusive reasons to permanent. Never return a token, credential, raw payload, body, or exception term.

---

### `lib/chimeway/apns/request_intent.ex` and `lib/chimeway/apns/binding_lookup.ex` (model/behaviour, transform/request-response)

**Analog:** `lib/chimeway/target_resolver.ex`

Use nested data-first structs, explicit callbacks, `with`, and exact tenant equality. Retain only opaque binding revision identity and safe intent in durable structs.

**Host boundary and normalization pattern** (lines 4-40):

```elixir
@callback resolve_targets(String.t(), keyword()) ::
            {:ok, [BindingRevision.t()]} | {:error, term()}

with resolver when is_atom(resolver) <- resolver,
     {:ok, results} <- resolver.resolve_targets(tenant_id, opts),
     {:ok, normalized} <- normalize(tenant_id, results) do
  {:ok, normalized}
else
  nil -> {:error, :target_resolver_not_configured}
  {:error, _} = error -> error
  _ -> {:error, :invalid_target_resolution}
end
```

**Tenant-qualified opaque-ref validation** (lines 13-24):

```elixir
def new(tenant_id, binding_revision_ref)
    when is_binary(tenant_id) and byte_size(tenant_id) > 0 and
           is_binary(binding_revision_ref) and byte_size(binding_revision_ref) in 4..128 do
  if String.match?(binding_revision_ref, ~r/^cw_[a-z0-9][a-z0-9_-]*$/) do
    {:ok, %__MODULE__{tenant_id: tenant_id, binding_revision_ref: binding_revision_ref}}
  else
    {:error, :invalid_binding_revision}
  end
end
```

Adapt the callback to accept exact `tenant_id`, `environment`, `topic`, and `binding_revision_ref`, validate the returned transient material immediately, and project every failure to stable safe atoms. The contract must not put the raw token into request intent or return it from Chimeway-owned public/evidence APIs.

---

### `lib/chimeway/apns/payload.ex` (utility, transform)

**Analog:** `lib/chimeway/rendering/channels/push.ex`

Retain generic push rendering as content-only validation; APNs payload construction is a new closed adapter-side transform. Do not feed the generic `data` map into a custom top-level merge.

**Changeset validation and normalized output** (lines 20-32):

```elixir
@types %{title: :string, body: :string, data: :map}
@required_fields [:title, :body]

{%{}, @types}
|> cast(attrs, Map.keys(@types))
|> validate_required(@required_fields)
|> apply_action(:insert)
|> case do
  {:ok, validated} -> {:ok, stringify_keys(validated)}
  {:error, changeset} -> {:error, changeset}
end
```

The APNs utility should take this validated result plus the opaque open ref, build only the locked `aps.alert` plus a named opaque reference, encode once with Jason, and reject byte sizes over 4,096 before transport.

---

### `lib/chimeway/target_adapter.ex`, `lib/chimeway/dispatch/executor.ex`, and `lib/chimeway/delivery_targets.ex` (behaviour/controller/service, event-driven)

**Analogs:** `lib/chimeway/target_adapter.ex`, `lib/chimeway/dispatch/executor.ex`, `lib/chimeway/delivery_targets.ex`

This is the phase’s central lifecycle extension. Preserve the target claim → append-only `:attempt_started` → adapter I/O → exact locked completion spine, but replace the current success-vs-ambiguity collapse with a typed result algebra and one transactional mutation per outcome.

**Existing TargetAdapter seam** (`lib/chimeway/target_adapter.ex`, lines 11-22):

```elixir
@type deliver_result ::
        {:ok, map()}
        | {:error, :pre_handoff, term()}
        | {:error, :possible_handoff, term()}
        | {:error, term()}

@callback deliver(TargetEnvelope.t(), keyword()) :: deliver_result()
```

**Executor contains provider boundary exceptions** (`lib/chimeway/dispatch/executor.ex`, lines 95-109):

```elixir
try do
  case target_adapter().deliver(%Chimeway.TargetAdapter.TargetEnvelope{delivery: delivery, target: target}, []) do
    {:ok, facts} when is_map(facts) -> {:ok, facts}
    {:error, :pre_handoff, _reason} -> :pre_handoff_retryable
    _other -> :ambiguous_handoff
  end
rescue
  _exception -> :ambiguous_handoff
catch
  _kind, _reason -> :ambiguous_handoff
end
```

**Pre-I/O durability/locking** (`lib/chimeway/delivery_targets.ex`, lines 94-164):

```elixir
Repo.transaction(fn ->
  parent = Repo.one(from(d in Delivery, where: d.id == ^delivery.id and d.tenant_id == ^tenant_id and d.status == :pending, lock: "FOR UPDATE"))
  target = Repo.one(from(t in DeliveryTarget, where: t.id == ^id and t.tenant_id == ^tenant_id and t.status == :pending, lock: "FOR UPDATE"))
  claimed_target = target |> Ecto.Changeset.change(status: :claimed, claimed_at: now, lease_expires_at: DateTime.add(now, 60, :second)) |> Repo.update!()
  attempt = DeliveryTargetAttempt.changeset(%DeliveryTargetAttempt{}, %{tenant_id: tenant_id, delivery_target_id: target.id, outcome: :attempt_started, started_at: now, source: source, safe_facts: %{}}) |> Repo.insert!()
  %{target: claimed_target, attempt: attempt}
end)
```

**Exact claimed-target completion** (`lib/chimeway/delivery_targets.ex`, lines 363-413):

```elixir
current_target = Repo.one(from(t in DeliveryTarget,
  where: t.id == ^target.id and t.delivery_id == ^parent.id and t.tenant_id == ^delivery.tenant_id and t.status == :claimed,
  lock: "FOR UPDATE"))

current_attempt = Repo.one(from(a in DeliveryTargetAttempt,
  where: a.id == ^attempt.id and a.delivery_target_id == ^current_target.id and
         a.tenant_id == ^delivery.tenant_id and a.outcome == :attempt_started,
  lock: "FOR UPDATE"))
```

**Failure mutation uses safe facts only** (`lib/chimeway/delivery_targets.ex`, lines 477-511):

```elixir
updated_target = target |> Ecto.Changeset.change(status: target_status, claimed_at: nil, lease_expires_at: nil) |> Repo.update!()
updated_attempt = attempt |> Ecto.Changeset.change(outcome: attempt_outcome, finished_at: now, safe_facts: %{"provider_code" => provider_code}) |> Repo.update!()

defp failure_attributes(:ambiguous_handoff),
  do: {:ambiguous_handoff, :ambiguous_handoff, "possible_provider_handoff"}
```

Implement APNs accepted, retryable, permanent, invalidated, expired, pre-handoff, and ambiguous paths inside this same locked spine. Invalidation must receive and use the original four-field lookup key; it must not resolve a current replacement.

---

### `lib/chimeway/delivery_target.ex`, `lib/chimeway/delivery_target_attempt.ex`, and the migration copies (models/migration, CRUD)

**Analogs:** their existing schemas and `priv/chimeway_migrations/035_create_chimeway_delivery_targets.exs`

**Schema field/constraint pattern** (`lib/chimeway/delivery_target.ex`, lines 18-45):

```elixir
schema "chimeway_delivery_targets" do
  field(:tenant_id, :string)
  field(:binding_revision_ref, :string)
  field(:status, Ecto.Enum, values: @statuses, default: :pending)
  belongs_to(:delivery, Chimeway.Delivery)
  has_many(:attempts, Chimeway.DeliveryTargetAttempt)
  timestamps(type: :utc_datetime_usec)
end

|> validate_required([:tenant_id, :delivery_id, :binding_revision_ref, :status])
|> unique_constraint(:binding_revision_ref, name: :chimeway_delivery_targets_delivery_id_binding_revision_ref_index)
```

**Prefix-safe migration helpers** (`priv/chimeway_migrations/035_create_chimeway_delivery_targets.exs`, lines 7-33 and 64-74):

```elixir
create chimeway_table(:chimeway_delivery_targets, primary_key: false) do
  add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
  add(:tenant_id, :string, null: false)
  add(:binding_revision_ref, :string, null: false)
end

defp chimeway_table(name, opts \\ []), do: table(name, chimeway_prefix_opts(opts))
defp chimeway_index(table_name, columns, opts \\ []), do: index(table_name, columns, chimeway_prefix_opts(opts))
```

Place durable intent only in target-owned storage; add the same migration to the shipped template, local repo migration, and both generated golden trees. Preserve tenant-qualified foreign-key patterns from migration `036`.

---

### `lib/chimeway/safe_evidence.ex` (utility, transform)

**Analog:** itself

**Closed provider facts** (lines 200-225):

```elixir
def provider_facts(value) when is_map(value) or is_list(value) do
  facts = Privacy.redact(value)

  with {:ok, code} <- optional_provider_code(facts),
       {:ok, retry_after_ms} <- optional_retry_after_ms(facts),
       {:ok, accepted_at} <- optional_accepted_at(facts) do
    {:ok, %{} |> maybe_put("provider_code", code) |> maybe_put("retry_after_ms", retry_after_ms) |> maybe_put("accepted_at", accepted_at)}
  end
end
```

**Bounded field validation** (lines 510-552):

```elixir
{:ok, value} when is_binary(value) ->
  if(code?(value), do: {:ok, value}, else: {:error, :unsafe_evidence})

{:ok, value} when is_integer(value) and value >= 0 and value <= @max_retry_after_ms ->
  {:ok, value}
```

Extend this allowlist rather than persisting APNs response maps. Ensure trace projections continue to invoke `target_attempt_facts_or_empty/1` (lines 451-466), so unsafe values disappear at read time as well as write time.

---

### APNs tests, fake transport, optionality verification, and CI (tests/config, request-response/batch)

**Analogs:** `test/chimeway/adapters/mailglass_adapter_test.exs`, `test/chimeway/dispatch/target_worker_test.exs`, `mix.exs`, `.github/workflows/ci.yml`

**Optional adapter test guard/tag** (`test/chimeway/adapters/mailglass_adapter_test.exs`, lines 1-25):

```elixir
if Code.ensure_loaded?(Mailglass) and Code.ensure_loaded?(Chimeway.Adapters.Mailglass) do
  defmodule Chimeway.Adapters.MailglassAdapterTest do
    @moduletag :mailglass
    use Chimeway.Adapter.ContractTest
  end
end
```

**Config restoration around injected transport** (`test/chimeway/dispatch/target_worker_test.exs`, lines 30-41):

```elixir
previous_adapter = Application.get_env(:chimeway, :target_adapter)
Application.put_env(:chimeway, :target_adapter, Chimeway.Test.TargetWorkerAdapter)

on_exit(fn ->
  restore(:target_adapter, previous_adapter)
  Application.delete_env(:chimeway, :target_worker_adapter_result)
end)
```

**No-send expiry/ambiguity assertion style** (`test/chimeway/dispatch/target_worker_test.exs`, lines 177-209):

```elixir
assert {:error, :ambiguous_handoff} = Executor.run_target(delivery, target_id: target_id)
assert_receive {:target_adapter_called, ^target_id}
assert target.status == :ambiguous_handoff
assert attempt.safe_facts == %{"provider_code" => "possible_provider_handoff"}
assert {:noop, :no_eligible_target} = Executor.run_target(delivery, target_id: target_id)
refute_receive {:target_adapter_called, ^target_id}, 50
```

**Dedicated verifier plus matching CI job** (`mix.exs`, lines 130-134; `.github/workflows/ci.yml`, lines 583-592):

```elixir
"verify.mailglass": [
  "cmd env MIX_ENV=test mix test --only mailglass --warnings-as-errors",
  "cmd --shell cd examples/chimeway_demo_host && mix deps.get && mix test --only mailglass --warnings-as-errors"
]
```

```yaml
- run: mix ecto.create --quiet
- run: mix ecto.migrate --quiet
- run: mix verify.mailglass
```

Build `test/support/apns_fake_transport.ex` as a no-network injected seam that returns the reason/status matrix and sends a process message only after the test's observable boundary. `request_test.exs` has no close single-file analog: make it a focused pure-unit test module for UUID, expiry, closed payload, byte count, collapse derivation, and privacy rejection. Add `mix verify.apns` and a path-gated `ci.apns` job with the same root/clean-consumer proof.

## Shared Patterns

### Optional dependency boundary

**Sources:** `lib/chimeway/adapters/mailglass.ex:1-17`, `test/chimeway/adapters/mailglass_adapter_test.exs:1-25`

Use `Code.ensure_loaded?/1` guards around optional integration modules and keep the core package dependency-free. Phase 100 must go one step further than Mailglass by avoiding static Pigeon structs/calls inside unguarded code.

### Tenant-safe, pre-I/O lifecycle

**Sources:** `lib/chimeway/delivery_targets.ex:94-164`, `lib/chimeway/delivery_targets.ex:363-413`

Claim exactly one tenant-qualified pending target and persist `attempt_started` in the same transaction before lookup/provider I/O. Finish only the exact claimed target and started attempt under `FOR UPDATE` locks.

### Safe evidence and privacy

**Sources:** `lib/chimeway/safe_evidence.ex:200-225`, `lib/chimeway/safe_evidence.ex:451-466`

Use an explicit provider-code/retry-delay/acceptance-time vocabulary. Do not retain raw tokens, Pigeon request structs, payload JSON, provider bodies, credentials, or exception terms.

### Installer parity

**Sources:** `priv/chimeway_migrations/035_create_chimeway_delivery_targets.exs:7-74`, `test/chimeway/migration_contract_test.exs:79-90`

Every storage migration needs a canonical template, repository copy, public/prefixed golden copies, and migration-count/object assertions updated together.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `test/chimeway/apns/request_test.exs` | test | transform | No existing pure request-intent/payload-boundary test module; use the Phase 100 research contract plus the validation/evidence patterns above. |

## Metadata

**Analog search scope:** `lib/chimeway`, `priv/chimeway_migrations`, `priv/repo/migrations`, `test/chimeway`, `test/support`, `test/fixtures`, `mix.exs`, `.github/workflows/ci.yml`  
**Files scanned:** 18 primary analog/config/test files  
**Pattern extraction date:** 2026-08-20

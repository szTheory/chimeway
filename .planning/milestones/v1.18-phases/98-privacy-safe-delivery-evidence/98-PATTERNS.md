# Phase 98: Privacy-Safe Delivery Evidence - Pattern Map

**Mapped:** 2026-08-12  
**Files analyzed:** 20 planned new/modified files  
**Analogs found:** 20 / 20

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/chimeway/privacy.ex` | utility | transform | `lib/chimeway/trigger.ex` | partial-match |
| `lib/chimeway/safe_evidence.ex` | utility | transform | `priv/adoption_proof/artifact_consumer_fixture.ex` | partial-match |
| `lib/chimeway/trigger.ex` | service | CRUD | `lib/chimeway/trigger.ex` | exact |
| `lib/chimeway/deliveries.ex` | service | CRUD | `lib/chimeway/deliveries.ex` | exact |
| `lib/chimeway/dispatch/executor.ex` | service | request-response | `lib/chimeway/dispatch/executor.ex` | exact |
| `lib/chimeway/telemetry.ex` | utility | event-driven | `lib/chimeway/telemetry.ex` | exact |
| `lib/chimeway/traces.ex` | service | request-response | `lib/chimeway/traces.ex` | exact |
| `lib/chimeway/admin.ex` | service | request-response | `lib/chimeway/admin.ex` | exact |
| `chimeway_admin/lib/chimeway_admin/redaction.ex` | utility | transform | `chimeway_admin/lib/chimeway_admin/redaction.ex` | exact |
| `priv/chimeway_migrations/034_privacy_safe_delivery_evidence.exs` | migration | batch | `priv/chimeway_migrations/033_make_chimeway_delivery_tenant_nullable.exs` | role-match |
| `priv/repo/migrations/<timestamp>_privacy_safe_delivery_evidence.exs` | migration | batch | `priv/repo/migrations/20260812000001_make_chimeway_delivery_tenant_nullable.exs` | role-match |
| `test/fixtures/installer_golden_{public,prefixed}/tree/priv/repo/migrations/TIMESTAMP_privacy_safe_delivery_evidence.exs` | test fixture | file-I/O | existing `TIMESTAMP_make_chimeway_delivery_tenant_nullable.exs` fixtures | exact |
| `test/chimeway/privacy_test.exs` | test | transform | `test/chimeway/trigger_sanitization_test.exs` | role-match |
| `test/chimeway/privacy_boundary_test.exs` | test | CRUD/event-driven | `test/chimeway/admin_test.exs` | role-match |
| `test/chimeway/trigger_sanitization_test.exs` | test | CRUD | `test/chimeway/trigger_sanitization_test.exs` | exact |
| `test/chimeway/telemetry_integration_test.exs` | test | event-driven | `test/chimeway/telemetry_integration_test.exs` | exact |
| `test/chimeway/traces_test.exs` | test | request-response | `test/chimeway/traces_test.exs` | exact |
| `test/chimeway/admin_test.exs` | test | request-response | `test/chimeway/admin_test.exs` | exact |
| `test/chimeway/{migration_contract_test,install/migrations_test}.exs` | test | batch/file-I/O | existing same files | exact |
| `priv/adoption_proof/artifact_consumer_fixture.ex` and `test/chimeway/release_gate_contract_test.exs` | utility/test | transform | existing same files | exact |

## Pattern Assignments

### `lib/chimeway/privacy.ex` (utility, transform)

**Analog:** `lib/chimeway/trigger.ex:382-396` and `lib/chimeway/deliveries.ex:1251-1261`.

Both existing sanitizers retain original keys, compare atom/string forms without atom creation, and return an empty map for invalid map input. Replace these competing shallow policies with the one public recursive boundary; do not retain an independent key taxonomy in callers.

```elixir
# lib/chimeway/trigger.ex:382-396
defp sanitize_map(map) when is_map(map) do
  Enum.reduce(map, %{}, fn {key, value}, acc ->
    if sensitive_key?(key) do
      acc
    else
      Map.put(acc, key, value)
    end
  end)
end

defp sensitive_key?(key) when is_atom(key), do: sensitive_key?(Atom.to_string(key))
defp sensitive_key?(key) when is_binary(key), do: String.downcase(key) in @sensitive_keys
defp sensitive_key?(_key), do: false
```

**Required adaptation:** expose a pure walker for maps, ordinary lists, and `Keyword.keyword?/1` lists. For allowed pairs retain the original key and recurse; for forbidden keys omit the whole pair and never retain/traverse its value. Normalize only the comparison string (`Atom.to_string/1` or binary plus `String.downcase/1`); never use `String.to_atom/1` or `String.to_existing_atom/1` on caller-controlled keys.

### `lib/chimeway/safe_evidence.ex` (utility, transform)

**Analog:** `priv/adoption_proof/artifact_consumer_fixture.ex:310-345`.

The proof builder is the project’s strongest closed-vocabulary pattern: validate prerequisite facts, then build a literal-key map rather than forwarding an input map.

```elixir
# priv/adoption_proof/artifact_consumer_fixture.ex:310-345
unless explanation.last_attempt && explanation.last_attempt.outcome do
  raise "public proof requires a last attempt outcome"
end

unless explanation.status == :succeeded do
  raise "public proof requires succeeded delivery status"
end

%{
  notification_key: notifier.notification_key(),
  notification_version: notifier.version(),
  delivery_id: delivery_id,
  status: explanation.status,
  last_attempt_outcome: explanation.last_attempt.outcome,
  timeline_events: timeline_events
}
```

Implement literal-key constructors/projections for lifecycle IDs, opaque refs, status/reason/classification, timestamps, render identity, and narrowly validated provider facts. Generic diagnostic maps and provider response bodies are input to the privacy dropper only, never durable evidence output.

### `lib/chimeway/trigger.ex` (service, CRUD)

**Analog:** `lib/chimeway/trigger.ex:155-170, 190-218, 280-396`.

Preserve the `Ecto.Multi` event-then-notification write structure and its `Telemetry.span` wrapper. Route event payload, render assigns/channels, metadata, correlation/recipient representation through `Privacy` and closed `SafeEvidence` constructors before constructing changesets/`insert_all` rows.

```elixir
# lib/chimeway/trigger.ex:155-170
Event.changeset(%Event{}, %{
  notification_key: notifier.notification_key(),
  notification_version: notifier.version(),
  idempotency_key: idempotency_key,
  tenant_id: tenant_id,
  payload: sanitize_payload(params),
  correlation_id: correlation_id
})
|> Ecto.Changeset.unique_constraint(:idempotency_key,
  name: :chimeway_events_tenant_id_idempotency_key_index
)
```

**Error/log pattern:** replace the uncontrolled `Logger.warning("Dispatch failed after trigger: #{inspect(reason)}")` at `lib/chimeway/trigger.ex:469-477` with a fixed message and bounded evidence/classification. Do not inspect adapter/provider terms.

### `lib/chimeway/deliveries.ex` (service, CRUD)

**Analog:** `lib/chimeway/deliveries.ex:300-365, 560-620, 1063-1158`.

Preserve existing normalization-then-changeset and atomic `Ecto.Multi` semantics, especially the row lock and in-transaction attempt numbering. Replace permissive map normalizers and the shallow `provider_response` sanitization with typed safe-evidence normalization before every `Repo.insert`/`Repo.update`.

```elixir
# lib/chimeway/deliveries.ex:1105-1115
safe_attrs =
  attrs
  |> coerce_provider_response_to_atom_key()
  |> Map.update(:provider_response, nil, &sanitize_metadata/1)
  |> Map.put(:delivery_id, delivery.id)

Multi.new()
|> Multi.run(:lock_delivery, fn repo, _changes ->
  case repo.one(from(d in Delivery, where: d.id == ^delivery.id, lock: "FOR UPDATE")) do
    nil -> {:error, :delivery_not_found}
    locked -> {:ok, locked}
  end
end)
```

**Required adaptation:** no `provider_response` body fallback. Build only outcome, error classification, opaque provider reference (if validated), and allowlisted provider facts. Keep `{:error, step, reason, changes}` propagation intact for invalid input.

### `lib/chimeway/dispatch/executor.ex` (service, request-response)

**Analog:** `lib/chimeway/dispatch/executor.ex:26-65`.

Keep adapter resolution and outcome classification centralized, but convert adapter output directly to `SafeEvidence` facts before `Deliveries.record_attempt/2`; unknown returns must remain a stable classification, not a persisted/logged arbitrary term.

```elixir
# lib/chimeway/dispatch/executor.ex:49-65
defp classify({:ok, meta}), do: {:succeeded, nil, meta}
defp classify({:error, :temporary, detail}), do: {:failed, "temporary", detail}
defp classify({:error, :permanent, detail}), do: {:rejected, "permanent", detail}
defp classify({:error, :bounced, detail}), do: {:bounced, "bounced", detail}

defp classify(other) do
  {:rejected, "unknown_classification", {:unknown_adapter_return, other}}
end
```

### `lib/chimeway/telemetry.ex` (utility, event-driven)

**Analog:** `lib/chimeway/telemetry.ex:73-132, 180-227`.

Retain the façade as the sole telemetry/logger seam and its static key list. Replace `normalize_keys |> Map.take` as the privacy contract with `SafeEvidence.telemetry_meta/1` (value validation plus safe vocabulary); `span/3` must sanitize both initial metadata and `extra_stop_meta` before merge.

```elixir
# lib/chimeway/telemetry.ex:124-132
def safe_meta(meta) when is_map(meta) do
  meta
  |> normalize_keys()
  |> Map.take(@allowed_meta_keys)
end
```

**Logger pattern:** keep literal log fields only, as in `handle_event/4` at lines 201-208. Never pass entire telemetry metadata or exception/provider detail to Logger.

### `lib/chimeway/traces.ex` and `lib/chimeway/admin.ex` (services, request-response)

**Analogs:** `lib/chimeway/traces.ex:164-222, 327-390, 749-775`; `lib/chimeway/admin.ex:36-68, 275-310`.

Both are established core DTO/projection seams. Keep tenant predicates and build literal structs/maps from selected safe facts; replace raw `recipient_identity`, correlation ID, raw planning context, and adapter module forwarding with opaque references and `SafeEvidence` projection functions. Do not solve this only in Admin LiveView.

```elixir
# lib/chimeway/traces.ex:346-355
defp build_last_attempt_map(attempt) do
  %{
    outcome: attempt.outcome,
    inserted_at: attempt.inserted_at,
    attempt_number: attempt.attempt_number,
    error_class: attempt.error_class,
    adapter_module: attempt.adapter_module
  }
end

# lib/chimeway/admin.ex:275-291
defp delivery_dto(row) do
  %{
    delivery_id: row.delivery_id,
    event_id: row.event_id,
    notification_key: row.notification_key,
    notification_version: row.notification_version,
    recipient_id: row.recipient_id,
    channel: row.channel,
    status: to_string(row.status),
    suppression_reason: row.suppression_reason,
    planning_reason: row.planning_reason,
    tenant_id: row.tenant_id,
    correlation_id: row.correlation_id,
    inserted_at: row.inserted_at,
    updated_at: row.updated_at
  }
end
```

### `chimeway_admin/lib/chimeway_admin/redaction.ex` (utility, transform)

**Analog:** `chimeway_admin/lib/chimeway_admin/redaction.ex:67-90`.

Retain this module only as defense in depth after core projections are safe. Its current exact detail-key allowlist is useful for rendering, but it must consume core-safe DTOs rather than serve as the privacy boundary.

```elixir
def safe_timeline_detail(detail) when is_map(detail) do
  detail
  |> Enum.filter(fn {key, _value} ->
    key_str = key |> to_string() |> String.downcase()
    key_str in @allowed_detail_keys and not Regex.match?(@sensitive_key, key_str)
  end)
  |> Map.new()
end
```

### Migrations and installer fixtures (migration/batch and test/file-I/O)

**Analogs:** `priv/chimeway_migrations/033_make_chimeway_delivery_tenant_nullable.exs:1-22`; `lib/chimeway/install/migrations.ex:44-91, 163-176`; `test/chimeway/migration_contract_test.exs:21-88`; `test/chimeway/install/migrations_test.exs:45-56`.

Copy the numbered-template naming, `# chimeway_migration:` marker, `__CHIMEWAY_PREFIX__` sentinel, `chimeway_table/2` helper, and generated public/prefixed golden copies. Update exact template-count assertions and generated migration-count checks from 33 to 34. Migration cleanup must neutralize legacy unsafe diagnostic blobs and preserve only deterministic lifecycle facts; it must be valid under both prefix modes.

```elixir
# priv/chimeway_migrations/033_make_chimeway_delivery_tenant_nullable.exs:1-22
# chimeway_migration: make_chimeway_delivery_tenant_nullable
defmodule Chimeway.Repo.Migrations.MakeChimewayDeliveryTenantNullable do
  use Ecto.Migration
  @chimeway_prefix __CHIMEWAY_PREFIX__

  defp chimeway_prefix_opts(opts \\ []) do
    if @chimeway_prefix, do: Keyword.put_new(opts, :prefix, @chimeway_prefix), else: opts
  end

  defp chimeway_table(name, opts \\ []), do: table(name, chimeway_prefix_opts(opts))
end
```

### Privacy, boundary, and focused regression tests (tests)

**Analogs:** `test/chimeway/trigger_sanitization_test.exs:1-118`; `test/chimeway/telemetry_integration_test.exs:19-153`; `test/chimeway/admin_test.exs:20-175`; `test/chimeway/release_gate_contract_test.exs:1161-1166, 1266-1357`.

Follow `DataCase` integration tests with sentinels inserted into real lifecycle rows, then reload/projection/assert against every output. New `privacy_test.exs` should be a pure unit suite covering nested maps, ordinary lists, keyword lists, mixed atom/string casing, and no dynamic atom creation. New `privacy_boundary_test.exs` should assert the same sentinel set is absent from persisted rows, trace/explanation, core admin DTOs, telemetry, captured logs, and proof output.

```elixir
# test/chimeway/admin_test.exs:68-175 (shape)
assert_exact_keys(problem, @recent_problem_keys)
assert_no_forbidden_keys(all_dtos)
assert_no_sensitive_values(all_dtos)

# test/chimeway/telemetry_integration_test.exs:100-136 (shape)
result = Telemetry.safe_meta(raw)
assert result == %{notification_key: "order_shipped", event_id: "uuid-abc"}
refute Map.has_key?(result, :payload)
```

For proof parsing, preserve string-key allowlisting and duplicate detection rather than atomizing untrusted proof fields:

```elixir
# priv/adoption_proof/artifact_consumer_fixture.ex:774-806
evidence_key =
  case Map.fetch(@evidence_keys, key) do
    {:ok, allowed_key} -> allowed_key
    :error -> raise "artifact consumer proof emitted an unknown evidence key"
  end

if Map.has_key?(evidence, evidence_key) do
  raise "artifact consumer proof emitted a duplicate evidence key"
end
```

## Shared Patterns

### Tenant Scope

**Source:** `lib/chimeway/traces.ex:164-222`, `lib/chimeway/admin.ex:36-68`  
**Apply to:** Trace and Admin projection changes.

Resolve `TenantScope` first and retain tenant predicates across every joined lifecycle row. Privacy work must not loosen Phase 97’s fail-closed ownership checks.

### Write Boundary and Errors

**Source:** `lib/chimeway/deliveries.ex:1063-1158`  
**Apply to:** Trigger, deliveries, executor.

Validate/build safe attrs before the existing changeset or `Ecto.Multi`; preserve explicit `{:error, ...}` paths and transactional attempt sequencing. Never persist a generic sanitized map as a fallback.

### Diagnostics

**Source:** `lib/chimeway/telemetry.ex:124-132, 201-208`  
**Apply to:** All telemetry and log calls.

Use one bounded metadata projection and literal Logger fields. Failure paths cannot use `inspect/1` on provider/adaptor terms.

### Closed Output Vocabularies

**Source:** `priv/adoption_proof/artifact_consumer_fixture.ex:310-345, 774-806`  
**Apply to:** SafeEvidence, traces, Admin DTOs, proof artifacts.

Construct literal-key maps from validated values; reject unknown and duplicate externally supplied keys without dynamic atom creation.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/chimeway/privacy.ex` | utility | transform | No existing recursive mixed map/list/keyword privacy walker; evolve the two shallow sanitizer analogs. |
| `lib/chimeway/safe_evidence.ex` | utility | transform | No centralized durable/projection evidence vocabulary exists; combine existing proof allowlists and DTO construction patterns. |
| `test/chimeway/privacy_boundary_test.exs` | test | CRUD/event-driven | No single current cross-surface persistence/telemetry/log/trace/DTO/proof sentinel matrix exists. |

## Metadata

**Analog search scope:** `lib/chimeway`, `chimeway_admin/lib`, `priv/chimeway_migrations`, `priv/adoption_proof`, focused `test/chimeway` suites, installer golden fixtures  
**Files scanned:** 20 primary analog/test files  
**Pattern extraction date:** 2026-08-12

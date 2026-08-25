# Phase 102: Alpha Digital Twin & Hermetic Gate - Pattern Map

**Mapped:** 2026-08-25  
**Files analyzed:** 21 logical files/groups  
**Analogs found:** 19 / 21

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `test/fixtures/alpha_twin/mix.exs` | config | request-response | `test/fixtures/apns_consumer/mix.exs` | exact |
| `test/fixtures/alpha_twin/config/config.exs` | config | CRUD | `test/fixtures/apns_consumer/config/config.exs` | role-match |
| `test/fixtures/alpha_twin/lib/alpha_twin/registry.ex` | service | CRUD/event-driven | `test/fixtures/apns_consumer/lib/apns_consumer.ex` and CrossWake example `registry.ex` | role-match |
| `test/fixtures/alpha_twin/lib/alpha_twin/clock.ex` | utility | transform | no local clock provider | no analog |
| `test/fixtures/alpha_twin/lib/alpha_twin/scripted_apns_transport.ex` | service | request-response/event-driven | `test/support/apns_fake_transport.ex` | exact |
| `test/fixtures/alpha_twin/lib/alpha_twin/scenario_ledger.ex` | utility | batch/transform | CrossWake `physical_iphone_contract.ex` | partial |
| `test/fixtures/alpha_twin/lib/alpha_twin/runner.ex` | service | CRUD/event-driven | `priv/adoption_proof/artifact_consumer_fixture.ex` | role-match |
| `test/fixtures/alpha_twin/lib/alpha_twin/proof_summary.ex` | service | transform | `lib/chimeway/safe_evidence.ex` and CrossWake `evidence.ex` | role-match |
| `test/fixtures/alpha_twin/priv/repo/migrations/*.exs` | migration | CRUD | `priv/chimeway_migrations/*.exs` / `priv/repo/migrations/*.exs` | exact (copied inputs) |
| `test/fixtures/alpha_twin/test/alpha_twin_test.exs` | test | event-driven | `test/fixtures/apns_consumer/test/apns_consumer_test.exs` | role-match |
| `lib/chimeway/clock.ex` (or equivalent narrow provider) | utility | transform | `Chimeway.TargetRecovery` `now:` option | partial |
| `lib/chimeway/delivery_targets.ex` | service | CRUD | existing `DeliveryTargets` transitions | exact modification |
| `lib/chimeway/adapters/apns.ex` | adapter/service | request-response | existing `Adapters.APNS` | exact modification |
| `lib/mix/tasks/verify.alpha_twin.ex` | config/task | batch | `lib/mix/tasks/verify.adoption_paths.ex` | exact |
| `lib/mix/tasks/verify.physical_proof_contract.ex` | config/task | batch | `lib/mix/tasks/verify.adoption_paths.ex` | role-match |
| `scripts/prove-alpha-twin.exs` | utility | batch/file-I/O | `scripts/prove-adoption-paths.exs` | exact |
| `test/fixtures/alpha_twin_physical_proof/*` | test fixture | transform | CrossWake physical-proof report fixture contract | role-match |
| `test/chimeway/alpha_twin_*_test.exs` | test | batch/event-driven | `test/chimeway/release_gate_contract_test.exs` | role-match |
| `test/chimeway/release_gate_contract_test.exs` | test | transform | existing adoption-path CI-contract block | exact modification |
| `mix.exs` | config | batch | existing `ci.verify_gates` alias | exact modification |
| `.github/workflows/ci.yml` | config | event-driven | `verify_adoption_paths` job | exact modification |

## Pattern Assignments

### `scripts/prove-alpha-twin.exs` and `lib/mix/tasks/verify.alpha_twin.ex`

**Analogs:** `scripts/prove-adoption-paths.exs`; `lib/mix/tasks/verify.adoption_paths.ex`

Use the existing one-artifact runner shape: build once, calculate a SHA-256 from those exact bytes, validate/extract through the existing archive module, run the fixture, validate one closed output, and return status `70` on a proof failure. The Alpha runner additionally must validate a detached CrossWake full SHA and bind both provenance values before emitting its proof.

**Immutable artifact pattern** — `scripts/prove-adoption-paths.exs:23-38, 114-132`:

```elixir
with {:ok, archive} <- builder.(),
     {:ok, result} <-
       with_archive.(archive, sha256!(archive), fn root -> run_paths!(paths, root, opts) end) do
  result
else
  {:error, _} -> fail(failure_path, :unpack)
end

defp sha256!(archive),
  do: :crypto.hash(:sha256, File.read!(archive)) |> Base.encode16(case: :lower)
```

**Archive boundary pattern** — `priv/adoption_proof/artifact_archive.ex:37-59`:

```elixir
archive_binary = read_bounded_archive!(archive, opts)
actual_digest = :crypto.hash(:sha256, archive_binary) |> Base.encode16(case: :lower)

if not secure_equal?(actual_digest, expected_digest),
  do: throw({:provenance, "archive digest mismatch"})

extract_contents!(contents, scratch)
root = artifact_root!(scratch)
validate_root!(root, scratch, config)
{:ok, callback.(root)}
```

**Mix-task parsing/exit pattern** — `lib/mix/tasks/verify.adoption_paths.ex:10-24`:

```elixir
def run(argv) do
  case parse(argv) do
    {:ok, paths} ->
      Code.require_file(Path.expand("../../../scripts/prove-adoption-paths.exs", __DIR__))

      case apply(Chimeway.AdoptionProofRunner, :run!, [paths]) do
        0 -> :ok
        status -> exit({:shutdown, status})
      end

    :error ->
      Mix.shell().error(@usage)
      exit({:shutdown, 64})
  end
end
```

`verify.physical_proof_contract` should retain this task behavior but accept no free-form evidence input: load only committed valid/one-fault fixtures and return stable closed rule IDs.

---

### `test/fixtures/alpha_twin/{mix.exs,config,lib,test,priv/repo/migrations}`

**Analogs:** `test/fixtures/apns_consumer/`; `priv/chimeway_migrations/`

Create an independent committed Mix project, never a source-path Chimeway consumer. Follow the fixture project’s environment-driven package path but require the validated package root, locked `CROSSWAKE_PATH`, and full SHA. Copy the real migration files into the fixture and invoke them through its Repo; do not synthesize Chimeway rows.

**Fixture package dependency pattern** — `test/fixtures/apns_consumer/mix.exs:4-17`:

```elixir
def project do
  [app: :apns_consumer, version: "0.1.0", elixir: "~> 1.17", deps: deps()]
end

defp deps do
  [{:chimeway, path: System.fetch_env!("CHIMEWAY_PACKAGE_PATH")}, {:oban, "~> 2.17"} | pigeon_dep()]
end
```

**Host-owned binding authority and exact CAS pattern** — `test/fixtures/apns_consumer/lib/apns_consumer.ex:87-127`:

```elixir
def resolve_binding(%BindingLookup.Request{} = request) do
  registry = Application.fetch_env!(:apns_consumer, :binding_registry)
  Agent.get(registry, fn state ->
    if exact_original?(request) do
      {:ok, %BindingLookup.Transient{tenant_id: request.tenant_id,
        binding_revision_ref: request.binding_revision_ref,
        device_token: "fixture-token-never-emitted", dispatcher_ref: state.dispatcher}}
    else
      {:error, :binding_not_found}
    end
  end)
end

def invalidate_binding(%BindingLookup.InvalidationKey{} = key) do
  Agent.get_and_update(registry, fn state ->
    if key == original_binding_key() and state.original == :active do
      {{:ok, %BindingLookup.InvalidationResult{status: :invalidated}},
       %{state | original: :invalidated}}
    else
      {{:ok, %BindingLookup.InvalidationResult{status: :unchanged}}, state}
    end
  end)
end
```

The Alpha registry must extend this with two installations, opaque refs/fingerprints only, rotation/revocation, eligibility, and one-time intent consumption. Preserve the explicit exact-revision comparison—an old provider rejection must never revoke a replacement.

**Process fixture test pattern** — `test/fixtures/apns_consumer/test/apns_consumer_test.exs:28-40, 71-102`:

```elixir
setup do
  previous_client = Application.get_env(:pigeon, :http2_client)
  Application.put_env(:pigeon, :http2_client, FakeHttp2Client)
  on_exit(fn -> Application.delete_env(:apns_consumer, :test_pid) end)
end

task = Task.async(fn -> APNSConsumer.deliver(dispatcher) end)
assert_receive {:pigeon_send_request, _headers}
assert {:invalidated, %{provider_status: 410}} = Task.await(task)
```

The Alpha process test should use a synchronous SQL Sandbox owner/shared connection and await/stop all spawned fixture processes before teardown.

---

### `test/fixtures/alpha_twin/lib/alpha_twin/scripted_apns_transport.ex`

**Analog:** `test/support/apns_fake_transport.ex`

Implement `Chimeway.APNS.Transport` directly. The fixture must redact before observation, validate a bounded request, dequeue exactly one ledger outcome, and return a real `%Transport.Result{}` or deliberate ambiguous failure; it must never start Pigeon or perform network I/O.

**Behaviour and redaction pattern** — `test/support/apns_fake_transport.ex:1-20`:

```elixir
defmodule Chimeway.Test.APNSFakeTransport do
  @behaviour Chimeway.APNS.Transport

  @impl true
  def push(dispatcher_ref, request, _opts) do
    send(Application.fetch_env!(:chimeway, :apns_fake_transport_pid),
      {:apns_push, dispatcher_ref, redact(request)})

    Application.get_env(:chimeway, :apns_fake_transport_result,
      {:ok, %Chimeway.APNS.Transport.Result{outcome: :accepted, code: :accepted}})
  end

  defp redact(%Chimeway.APNS.Transport.Request{} = request),
    do: %{request | device_token: "[REDACTED]"}
end
```

**Production adapter outcome boundary** — `lib/chimeway/adapters/apns.ex:9-25, 62-82`:

```elixir
with {:ok, intent} <- safe_intent(target.apns_request_intent),
     false <- safe_expired?(intent),
     {:ok, transient} <- safe_lookup(binding_request(target, intent)),
     {:ok, payload} <- safe_payload(delivery.render_data || %{}, intent.open_ref),
     {:ok, result} <- safe_transport(transient.dispatcher_ref, request(transient, intent, payload)) do
  classify_result(result, target, intent)
else
  {:error, :ambiguous} -> {:error, :possible_handoff, :ambiguous_handoff}
  {:error, :pigeon_unavailable} -> {:pre_handoff_retryable, %{provider_code: "pigeon_unavailable"}}
  {:error, :rejected} -> {:permanent, %{provider_code: "provider_rejected"}}
end
```

The test transport must drive accepted, retryable, permanent, exact invalidation, and ambiguous-handoff through this existing classification—not parallel fixture classifications.

---

### `lib/chimeway/clock.ex`, `lib/chimeway/delivery_targets.ex`, and `lib/chimeway/adapters/apns.ex`

**Analogs:** `lib/chimeway/target_recovery.ex`; existing target/APNs production seams

There is no project-wide clock analogue. Add a small default-system-clock provider only where Alpha needs it; pass an explicit resolved `now` through target attempt/transition and APNs expiry/acceptance paths. Keep `TargetRecovery`’s established `now:` option and preserve production behavior when absent.

**Existing narrow-option seam** — `lib/chimeway/target_recovery.ex:205-221`:

```elixir
defp paging(opts, cursor_key) do
  batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
  limit = if is_integer(batch_size) and batch_size in 1..@max_batch_size,
    do: batch_size, else: @default_batch_size
  older_than = Keyword.get(opts, :older_than, 60)
  now = Keyword.get(opts, :now, DateTime.utc_now())

  %{limit: limit, cursor: opaque_cursor(Keyword.get(opts, cursor_key)),
    cutoff: DateTime.add(now, -max(older_than, 0), :second), now: now}
end
```

**Target transaction/scoping pattern** — `lib/chimeway/delivery_targets.ex:86-106`:

```elixir
def begin_target_attempt(%Delivery{tenant_id: tenant_id} = delivery, opts \\ []) do
  now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
  target_id = Keyword.get(opts, :target_id)

  Repo.transaction(fn ->
    parent = Repo.one(from(d in Delivery,
      where: d.id == ^delivery.id and d.tenant_id == ^tenant_id and d.status == :pending,
      lock: "FOR UPDATE"))
    if is_nil(parent), do: Repo.rollback(:no_eligible_target)
  end)
end
```

Tests must prove: absent injection uses system time; supplied fixed time controls expiry/retry/lease/replay without sleeps; all persistence remains tenant-qualified and locked.

---

### `scenario_ledger.ex`, `proof_summary.ex`, physical-proof fixtures, and `verify.physical_proof_contract`

**Analogs:** `lib/chimeway/safe_evidence.ex`; `Crosswake.ProofLane.PhysicalIphoneContract`; `Crosswake.ProofLane.Evidence`

Use a literal, versioned ordered list of string scenario IDs. Decode only known IDs (no `String.to_atom/1`), require each one exactly once and in canonical order, and reduce all collected facts to a Chimeway-owned closed summary. The physical extension must reference CrossWake’s canonical report, not duplicate its assertion vocabulary.

**Closed safe projection pattern** — `lib/chimeway/safe_evidence.ex:257-284, 405-428`:

```elixir
with {:ok, facts} <- provider_facts(provider_response || %{}),
     {:ok, outcome} <- required_field(attrs, "outcome", :outcome, &valid_outcome/1),
     {:ok, error_class} <- valid_error_class(error_class) do
  {:ok, %{outcome: outcome, error_class: error_class,
           provider_message_id: provider_ref, provider_response: facts}}
else
  {:error, :unsafe_evidence} -> {:error, :unsafe_evidence, :provider_facts}
  {:error, reason} -> {:error, :unsafe_evidence, reason}
end

delivery |> Map.get(:targets, []) |> loaded_association()
|> Enum.sort_by(&{Map.get(&1, :binding_revision_ref), Map.get(&1, :id)})
|> Enum.map(&trace_target/1)
```

**Durable explanation assertion surface** — `lib/chimeway/traces.ex:190-257`:

```elixir
with {:ok, tenant_id} <- TenantScope.resolve(opts) do
  delivery = Repo.one(from(d in Delivery,
    where: d.id == ^delivery_id and d.tenant_id == ^tenant_id, preload: [notification: :event]))

  case delivery && Repo.preload(delivery, target_history_preload(tenant_id), repo_opts) do
    %Delivery{} = loaded_delivery ->
      explanation = %{delivery_id: loaded_delivery.id, status: loaded_delivery.status,
        timeline: timeline} |> SafeEvidence.trace()
      {:ok, struct(Explanation, explanation)}
  end
end
```

**Canonical CrossWake ordering/ownership validation** — `../crosswake/lib/crosswake/proof_lane/physical_iphone_contract.ex:45-87`:

```elixir
expected_ids = Enum.map(@assertions, & &1.id)
supplied_ids = Enum.map(report, &Map.fetch!(&1, :id))

cond do
  length(report) != length(@assertions) or Enum.uniq(supplied_ids) != supplied_ids ->
    {:error, "PI-ASSERTIONS-COMPLETE"}
  supplied_ids != expected_ids -> {:error, "PI-ASSERTIONS-ORDER"}
  not Enum.all?(report, &valid_report_entry?/1) -> {:error, "PI-ASSERTIONS-OWNER"}
  true -> :ok
end
```

Apply the same fail-closed property to extension schema version, proof class, CrossWake SHA, Chimeway digest, scenario IDs, field keys, and leakage sentinels. Rejected sensitive values must not be returned or serialized—only a stable rule ID/path.

---

### `mix.exs`, `.github/workflows/ci.yml`, and `test/chimeway/release_gate_contract_test.exs`

**Analogs:** current `ci.verify_gates` alias; `verify_adoption_paths` lane and its contract tests

Add `verify_alpha_twin` as a credential-free PostgreSQL job that checks out CrossWake at the checked-in full SHA, proves detached/clean provenance, and runs both locked commands. Add it to **both** aggregate gates and their environment/result lists. Update `ci.verify_gates` contract tests concurrently so the source alias, commands, job, checkout, gates, and aggregation cannot drift. This is all automated evidence; do not add human UAT/checkpoints.

**Named local gate pattern** — `mix.exs:124-127`:

```elixir
"ci.verify_gates": [
  "cmd scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test " <>
    "test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs " <>
    "--exclude adoption_paths_e2e --warnings-as-errors"
]
```

**CI lane pattern** — `.github/workflows/ci.yml:1132-1184`:

```yaml
verify_adoption_paths:
  runs-on: ubuntu-latest
  timeout-minutes: 30
  services:
    postgres:
      image: postgres:15
  env:
    MIX_ENV: test
    DATABASE_URL: postgres://postgres:postgres@localhost/chimeway_test
  steps:
    - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
    - run: mix deps.get
    - run: mix ecto.create --quiet
    - run: mix ecto.migrate --quiet
    - run: mix verify.adoption_paths
```

**Gate contract pattern** — `test/chimeway/release_gate_contract_test.exs:2526-2596, 3080-3095`:

```elixir
assert "verify_adoption_paths" in extract_ci_gate_needs(ci_yml)
assert "verify_adoption_paths" in extract_pr_gate_needs(ci_yml)
assert ci_gate =~ "VERIFY_ADOPTION_PATHS: ${{ needs.verify_adoption_paths.result }}"

for mutated <- [String.replace(ci_yml, "verify_adoption_paths:", "verify_adoption_path:", global: false)] do
  refute ci_topology_intact?(mutated)
end
```

The Alpha contract must additionally assert the exact full SHA (not a branch/tag), clean detached checkout, both Mix invocations, no Apple credential/Xcode requirement, and membership/result propagation in `pr-gate` and `ci-gate`.

## Shared Patterns

### Host authority and privacy

**Sources:** `test/fixtures/apns_consumer/lib/apns_consumer.ex:87-127`; `lib/chimeway/safe_evidence.ex:1-31`

Apply to: registry, transport observations, ledger/proof summary, fixture tests.

- Keep raw tokens, eligibility, binding lifecycle and intent consumption in Alpha host components.
- Chimeway receives opaque binding revision refs and bounded APNs intent only.
- Redact before a request crosses into an observation channel; project durable data through `SafeEvidence`, and reject unknown/unsafe maps.

### Tenant-qualified durable truth

**Sources:** `lib/chimeway/delivery_targets.ex:76-106`; `lib/chimeway/traces.ex:190-257`

Apply to: runner assertions and recovery scenarios.

- Assert real persisted event → notification → delivery → target → attempt facts plus `Traces.explain_delivery/2` after every ledger step.
- Preserve stable sorting and tenant predicates; never construct lifecycle rows directly to stage scenarios.

### Explicit time and outcome taxonomy

**Sources:** `lib/chimeway/target_recovery.ex:205-221`; `lib/chimeway/adapters/apns.ex:9-25, 70-82`

Apply to: clock seam, scripted transport, retry/expiry/recovery and open tests.

- Default to system time; fixture passes a fixed `now` and advances it explicitly.
- Keep `provider_accepted`, `invalidated`, `pre_handoff_retryable`, `permanent`, `expired`, and `ambiguous_handoff` distinct from protected open/inbox seen/read facts.

### Closed proof schemas and machine-only gate evidence

**Sources:** `Crosswake.ProofLane.PhysicalIphoneContract:45-87`; `test/chimeway/release_gate_contract_test.exs:2526-2596`

Apply to: ledger, proof summary, physical-proof extension, fixtures, and CI contracts.

- Enforce complete, unique, ordered known IDs and exact owner/proof class/revision fields.
- Use only stable rule IDs/path in negative output; do not echo rejected evidence.
- Verification is executable (`mix verify.alpha_twin`, `mix verify.physical_proof_contract`, `mix ci.verify_gates`) and has no conversational UAT.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `test/fixtures/alpha_twin/lib/alpha_twin/clock.ex` | utility | transform | No reusable project clock behaviour exists; use the narrow `now:` option precedent and keep system-time default. |
| `test/fixtures/alpha_twin/lib/alpha_twin/scenario_ledger.ex` | utility | batch/transform | No existing Chimeway cross-repository ordered scenario ledger; use CrossWake’s closed ordered assertion contract as the closest partial pattern. |

## Metadata

**Analog search scope:** `lib/`, `priv/`, `scripts/`, `test/fixtures/`, `test/chimeway/`, `.github/workflows/`, and `../crosswake/` authoritative contracts  
**Files scanned:** 22 source/config/test files plus migration inventories  
**Pattern extraction date:** 2026-08-25

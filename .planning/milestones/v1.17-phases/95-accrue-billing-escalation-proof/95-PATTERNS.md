# Phase 95: Accrue Billing-Escalation Proof - Pattern Map

**Mapped:** 2026-08-09  
**Files analyzed:** 4  
**Analogs found:** 4 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `test/support/artifact_consumer_fixture.ex` | utility / consumer fixture | file-I/O, event-driven | its existing `prove_mailglass!/2` proof | exact extension |
| `test/chimeway/release_gate_contract_test.exs` | test / release-gate contract | event-driven, batch | existing clean-consumer and Mailglass proof contracts | exact extension |
| `test/chimeway/doc_contract_test.exs` | test / documentation contract | transform | existing Accrue guide contract | exact extension |
| `guides/introduction/accrue-dunning-integration.md` | configuration / adoption guide | event-driven | its existing billing-event and verification sections | exact extension |

## Pattern Assignments

### `test/support/artifact_consumer_fixture.ex` (utility / consumer fixture, file-I/O + event-driven)

**Analog:** `test/support/artifact_consumer_fixture.ex` — `prove_mailglass!/2` and its strict proof parser.

Extend the existing fixture; do not create a separate harness. Preserve its temporary root/database identity, exactly-one unpacked `:chimeway` path dependency validation, `try`/`rescue`/`catch` cleanup, and returned inspection sources. Add a separately callable `prove_accrue!/2`, matching the `prove_mailglass!/2` public shape at lines 113-155.

**Harness lifecycle pattern** (`test/support/artifact_consumer_fixture.ex:118-155`):

```elixir
identity = Keyword.get(opts, :identity, resource_identity())
validate_identity!(identity)

result =
  try do
    File.rm_rf!(root)
    scaffold!(root, unpacked_root, db_config)
    mix_source = File.read!(Path.join(root, "mix.exs"))
    validate_artifact_dependency!(mix_source, unpacked_root, repo_root!())
    run_mix!(root, ["deps.get"])
    run_mix!(root, ["chimeway.gen.migrations"])
    run_mix!(root, ["ecto.create"])
    run_mix!(root, ["ecto.migrate"])
    output = run_mix!(root, ["run", "priv/prove_…​.exs"])
    %{output: …, proof_source: …, identity: identity, evidence: …}
  rescue
    error ->
      cleanup!(identity, opts)
      reraise error, __STACKTRACE__
  end

Map.put(result, :cleanup, cleanup!(identity, opts))
```

**Generated-consumer scaffold pattern** (`test/support/artifact_consumer_fixture.ex:283-325`):

```elixir
File.write!(Path.join(root, "mix.exs"), mix_exs(unpacked_root))
File.write!(Path.join(root, "config/config.exs"), config_exs(db_config))
File.write!(Path.join(root, "lib/artifact_consumer/repo.ex"), repo_ex())
File.write!(Path.join(root, "lib/artifact_consumer/application.ex"), application_ex())
File.write!(Path.join(root, "priv/prove_mailglass.exs"), mailglass_proof_ex())

defp deps,
  do: [
    {:chimeway, path: #{inspect(Path.expand(unpacked_root))}},
    {:mailglass, "~> 1.3"},
    {:ecto_sql, "~> 3.11"},
    {:postgrex, ">= 0.0.0"},
    {:oban, "~> 2.17"}
  ]
```

Adapt the generated `mix.exs` to use exact `{:accrue, "1.3.0"}` and retain Chimeway as the sole `:chimeway` dependency. Generate the Accrue repo/config/migration support required by the resolved package, configure `:accrue` with `engine: Accrue.Integrations.Chimeway`, and retain an isolated `ArtifactConsumer.Repo`; never reference the Chimeway source checkout.

**Strict string-key parser pattern** (`test/support/artifact_consumer_fixture.ex:541-609`):

```elixir
line
|> String.split(" ", trim: true)
|> Enum.reduce(%{}, fn pair, evidence ->
  case String.split(pair, "=", parts: 2) do
    [key, value] when value != "" ->
      evidence_key =
        case Map.fetch(allowed_keys, key) do
          {:ok, allowed_key} -> allowed_key
          :error -> raise "artifact consumer #{label} proof emitted an unknown evidence key"
        end

      if Map.has_key?(evidence, evidence_key),
        do: raise("artifact consumer #{label} proof emitted a duplicate evidence key")

      Map.put(evidence, evidence_key, value)
    _ -> raise "artifact consumer #{label} proof emitted malformed evidence"
  end
end)
```

Use an Accrue-specific static allowlist and validate the exact safe values: provenance mode, released Accrue/Chimeway versions *or* pinned immutable ref, `workflow_key`, `workflow_version`, waiting state/reason, `invoice.paid`, resulting active state/reason, and ordered transition reasons. Do not atomize input keys. `accrue_version` and a compatibility ref are mutually constrained by provenance mode; direct IDs, tenant/customer/recipient details, payloads, metadata, credentials, raw structs, and SQL results are forbidden.

**One-and-only-one output-line pattern** (`test/support/artifact_consumer_fixture.ex:618-629`):

```elixir
lines =
  output
  |> String.split("\n")
  |> Enum.filter(&String.starts_with?(&1, "CHIMEWAY_MAILGLASS_PROOF "))

case lines do
  [line] -> line
  [] -> raise "artifact consumer proof did not emit CHIMEWAY_MAILGLASS_PROOF"
  _ -> raise "artifact consumer proof emitted multiple CHIMEWAY_MAILGLASS_PROOF lines"
end
```

Make this `CHIMEWAY_ACCRUE_PROOF`; unlike the older core helper, it must reject multiple matching lines.

**Public workflow evidence pattern** (`lib/chimeway/workflows.ex:300-370`):

```elixir
{:ok, explain} = Chimeway.Workflows.explain(tenant_id, workflow_run_id)
{:ok, traces} = Chimeway.Workflows.list_traces(tenant_id, workflow_run_id)
reasons = Enum.map(traces, & &1.reason)
```

`explain/2` exposes the tenant-scoped `state` and `status_reason`; `list_traces/2` returns ascending structural transitions and documents that raw signal payloads are absent from transition context. The generated proof must project only safe fields from these APIs, rather than inspecting the generated consumer's database.

**Accrue event/outcome boundary pattern** (`test/chimeway/integrations/accrue_dunning_lifecycle_test.exs:130-163`, `:212-230`):

```elixir
assert {:ok, _row} = trigger_invoice_paid_event!(invoice, subscription, customer)
assert %{success: 1} = Oban.drain_queue(queue: :chimeway_signals, with_scheduled: true)

assert {:ok, explain} = Workflows.explain(customer.id, waiting_run.id)
assert {:ok, traces} = Workflows.list_traces(customer.id, waiting_run.id)
reasons = Enum.map(traces, & &1.reason)
assert "waiting_for_step_progression" in reasons
assert "signal_received" in reasons
```

The generated script begins via `Accrue.Test.trigger_event/2` with `:invoice_payment_failed`, drains the initial delivery/progresses to `:waiting`, ends the wait via `:invoice_paid`, drains `:chimeway_signals`, then takes the public projections. It must not call `Chimeway.trigger/3` or `Chimeway.Signal.track/4` itself. Describe the post-signal `:active` / `signal_received` state as ending the waiting escalation path, never as workflow completion.

**Dependency/provenance pattern** (`deps/accrue/hex_metadata.config:1-3,57-59`; `test/test_helper.exs:72-136`):

```elixir
if Code.ensure_loaded?(Chimeway) and not Code.ensure_loaded?(Accrue.Integrations.Chimeway) do
  source = Path.join(Mix.Project.deps_paths()[:accrue], "lib/accrue/integrations/chimeway.ex")
  _ = Code.compile_file(source)
  unless Code.ensure_loaded?(Accrue.Integrations.Chimeway),
    do: raise("failed to compile Accrue.Integrations.Chimeway from #{source}")
end
```

Accrue Hex metadata identifies version `1.3.0` and includes `lib/accrue/integrations/chimeway.ex`. Because Accrue conditionally compiles this module, resolve/compile it from the *generated consumer's resolved dependency path* before deciding that this is released-package evidence. If that proof cannot establish the released source, emit only compatibility evidence with SHA `236fa2f1649e771f3b515603495436badeed3c7b`.

---

### `test/chimeway/release_gate_contract_test.exs` (test / release-gate contract, event-driven + batch)

**Analog:** existing clean-consumer core and Mailglass contracts.

Add a serialized/timeout-tagged end-to-end Accrue consumer test alongside the existing artifact tests; call `ArtifactConsumerFixture.prove_accrue!/1` after `build_unpacked_package!/0`, inspect returned generated sources, prove cleanup, and use the fixture's parser for adversarial record tests.

**End-to-end contract pattern** (`test/chimeway/release_gate_contract_test.exs:980-1043`, `:1045-1127`):

```elixir
setup do
  output = build_unpacked_package!()
  on_exit(fn -> File.rm_rf(output) end)
  %{root: unpacked_package_root!(output)}
end

@tag timeout: 120_000
test "a clean consumer proves … from only the unpacked artifact", %{root: root} do
  proof = ArtifactConsumerFixture.prove_mailglass!(root)
  assert proof.output =~ "CHIMEWAY_MAILGLASS_PROOF"
  assert Map.keys(proof.evidence) |> Enum.sort() == [...]
  refute File.exists?(proof.identity.root)
  assert proof.cleanup == %{root_removed?: true, database_down?: true}
end
```

Assert the output record values and that its source invokes the Accrue test-event boundary plus only the permitted public workflow/trace functions. Reject generated proof-source/output strings for repos/queries, direct notifier or direct signal calls, IDs, recipient/billing/payload/metadata/credential data, and source-tree paths. Validate only `:chimeway` is resolved from the unpacked artifact; prove the exact Accrue dependency and resulting provenance claim agree.

**Adversarial strict-record pattern** (`test/chimeway/release_gate_contract_test.exs:1224-1394`):

```elixir
unknown_key = "untrusted_mailglass_key_#{System.unique_integer([:positive])}"
assert_raise RuntimeError, ~r/unknown evidence key/, fn ->
  ArtifactConsumerFixture.parse_mailglass_evidence!(complete <> " #{unknown_key}=value")
end

assert_raise ArgumentError, fn -> String.to_existing_atom(unknown_key) end

assert_raise RuntimeError, ~r/duplicate evidence key/, fn ->
  ArtifactConsumerFixture.parse_mailglass_evidence!(complete <> " status=succeeded")
end
```

Copy this test structure for `parse_accrue_evidence!/1`: unknown, duplicate, missing, malformed, and multiple proof lines; every forbidden sensitive key; forged lifecycle/provenance/version/ref values; and out-of-order or unknown timeline reasons. Include both valid provenance branches in unit contracts, but label only a successful resolved `1.3.0` integration as `released_package`.

---

### `test/chimeway/doc_contract_test.exs` (test / documentation contract, transform)

**Analog:** its current Accrue integration-guide contract at `test/chimeway/doc_contract_test.exs:752-853`.

Extend the existing `describe`, not a new contract file. Continue loading the guide once in `setup` and use direct `String.contains?/2` / `refute` contracts for exact public language.

**Guide contract pattern** (`test/chimeway/doc_contract_test.exs:757-803`):

```elixir
describe "accrue dunning integration guide doc contract …" do
  setup do
    content = File.read!(@accrue_integration_guide)
    %{content: content}
  end

  for forbidden <- @recipe_forbidden_strings do
    test "forbids #{forbidden} …", %{content: content} do
      refute String.contains?(content, unquote(forbidden))
    end
  end
end
```

Add contracts for the new packaged-consumer proof and conditional provenance wording: require the `invoice.payment_failed` / `invoice.paid` public lifecycle and non-terminal `signal_received` explanation; require exact `1.3.0` released-package wording only when the guide states the integration-presence condition; require the immutable SHA compatibility fallback; forbid treating `verify.accrue`, DemoHost, a local sibling checkout, or a pinned ref as an independent released-package adopter proof or installation guidance.

Preserve the required section ordering and maintainer-command check at lines 825-852. The new adoption proof must be described separately from `mix verify.accrue`, since that lane remains a regression analog rather than package provenance.

---

### `guides/introduction/accrue-dunning-integration.md` (configuration / adoption guide, event-driven)

**Analog:** its own responsibility split, billing-event triggers, and verification sections.

Amend the canonical guide in place. Keep host ownership clear: Accrue emits/reduces billing events; Chimeway owns durable workflow progression and signal routing.

**Boundary and vocabulary pattern** (`guides/introduction/accrue-dunning-integration.md:55-70`, `:94-128`):

```markdown
| `invoice.payment_failed` | Starts dunning — engine calls `start_campaign/3` → `Chimeway.trigger/3` |
| `invoice.paid` | Terminates active wait via Outcome Signal — `cancel_campaign/3` → `Chimeway.Signal.track/4` |
```

```elixir
Accrue.Test.trigger_event(:invoice_payment_failed, %{...})
Accrue.Test.trigger_event(:invoice_paid, %{...})
```

Extend this with a public-evidence example that says the trace establishes waiting (`waiting_for_step_progression`) and the outcome signal result (`signal_received`), without showing billing IDs, recipients, payloads, metadata, credentials, raw structs, or database access. Avoid the inaccurate claim that `invoice.paid` completes the workflow.

**Truthful proof-language pattern** (`guides/introduction/accrue-dunning-integration.md:17-35`, `:130-158`; `MAINTAINING.md:58-75,108-113`):

```markdown
Production adopters use `{:accrue, "~> 1.3"}` from Hex.
Local proof and CI still use a sibling checkout pinned to the integration ref …
```

Update this wording so the generated proof is an independent released-package adopter proof only after its resolved exact Accrue `1.3.0` package contains and loads the integration; identify the resolved Chimeway version in that branch. Otherwise state the exact immutable SHA `236fa2f1649e771f3b515603495436badeed3c7b` as compatibility evidence only. Do not tell users to install from the ref or present maintainers' `ACCRUE_PATH`/`mix verify.accrue` lane as packaged-consumer proof.

## Shared Patterns

### Packaged-consumer isolation and provenance

**Sources:** `test/support/artifact_consumer_fixture.ex:63-110,118-155`; `test/chimeway/release_gate_contract_test.exs:1129-1145`

Every consumer proof creates fixture-owned temporary filesystem/database resources, checks exactly one unpacked `:chimeway` path dependency before commands run, cleans up on success and exceptions, and then verifies cleanup. Phase 95 may add `:accrue`, but must not add a repository source path, DemoHost, or the normal `verify.accrue` lane to establish adopter provenance.

### Public evidence only

**Sources:** `lib/chimeway/workflows.ex:286-370`; `test/support/artifact_consumer_fixture.ex:541-609`; `test/chimeway/release_gate_contract_test.exs:1105-1123,1224-1394`

Generated proof code may use tenant-scoped `Chimeway.Workflows.explain/2`, `list_traces/2`, and, only if required, `Chimeway.Traces.explain_delivery/1`. Project fixed safe facts into one ordered `key=value` line and parse with string keys/allowlists. Test both source and output against sensitive values; never use database queries as public proof evidence.

### Event-driven lifecycle and async signal drain

**Sources:** `deps/accrue/lib/accrue/integrations/chimeway.ex:78-114`; `test/chimeway/integrations/accrue_dunning_lifecycle_test.exs:130-163,212-230`

Use Accrue's payment events as the producer boundary. `start_campaign/3` internally triggers the durable workflow, while `cancel_campaign/3` tracks the `invoice.paid` signal; the proof must drain the `:chimeway_signals` Oban queue before inspecting public workflow state. The expected evidence chain is waiting → `invoice.paid` → `signal_received` / active, not a terminal completion.

### Conditional integration loading and provenance labels

**Sources:** `test/test_helper.exs:72-136`; `deps/accrue/hex_metadata.config:1-3,57-59`; `.github/workflows/ci.yml:628-674`; `MAINTAINING.md:108-113`

Accrue conditionally compiles the Chimeway integration. In a generated consumer, make the release/provenance decision from its resolved package and whether that package's integration module is actually loadable. `accrue 1.3.0` metadata includes the integration source. The CI checkout SHA is immutable compatibility evidence only and must never be phrased as released-package installation guidance.

## No Analog Found

None. Phase 95 is a direct extension of the Phase 94 clean-consumer proof plus the existing Accrue lifecycle and documentation-contract surfaces.

## Metadata

**Analog search scope:** `test/support`, `test/chimeway`, `guides/introduction`, `lib/chimeway`, `deps/accrue`, `.github/workflows`, root release documentation  
**Files scanned:** 12  
**Pattern extraction date:** 2026-08-09

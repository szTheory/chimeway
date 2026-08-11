# Phase 94: Mailglass Transactional-Email Proof - Pattern Map

**Mapped:** 2026-08-08  
**Files analyzed:** 4 modified repository files (plus generated-consumer templates embedded in the fixture)  
**Analogs found:** 4 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `test/support/artifact_consumer_fixture.ex` | test fixture / generated-host scaffold | request-response + file-I/O + CRUD | same file’s Core consumer proof | exact extension |
| `test/chimeway/release_gate_contract_test.exs` | integration/contract test | request-response + event-driven | same file’s unpacked Core adopter proof | exact extension |
| `guides/introduction/mailglass-integration.md` | documentation | request-response guidance | same guide’s runtime/mailable/verification path | exact extension |
| `test/chimeway/doc_contract_test.exs` | documentation contract test | transform | same file’s Mailglass guide contract | exact extension |

### Generated consumer files (created by the fixture at runtime)

| Generated File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/artifact_consumer/notifiers/mailglass_proof.ex` | notifier | event-driven + CRUD | `examples/chimeway_demo_host/lib/demo_host/notifiers/invite_sent.ex` | exact role/flow |
| `lib/artifact_consumer/mailers/mailglass_proof_email.ex` | component / mailable | transform | `examples/chimeway_demo_host/lib/demo_host/mailers/invite_email.ex` | exact role/flow |
| `priv/repo/migrations/*_mailglass_init.exs` | migration | CRUD | `test/support/mailglass/migrations/00000000000001_mailglass_init.exs` | exact |
| `priv/prove_mailglass.exs` | proof script | request-response + event-driven | existing generated `priv/prove_core.exs` | exact extension |

## Pattern Assignments

### `test/support/artifact_consumer_fixture.ex` (fixture/scaffold, request-response + file-I/O + CRUD)

**Analog:** this fixture’s Core proof implementation, lines 15-68, 183-277, and 295-337.

**Lifecycle and cleanup pattern** (lines 20-68): keep the same single `try` body, provenance validation before commands, `rescue` and `catch` cleanup, and final cleanup on success. `prove_mailglass!/1` must reuse the identical resource identity and cleanup path rather than make another harness.

```elixir
result =
  try do
    File.rm_rf!(root)
    scaffold!(root, unpacked_root, db_config)
    validate_artifact_dependency!(File.read!(Path.join(root, "mix.exs")), unpacked_root, repo_root!())
    run_mix!(root, ["deps.get"])
    run_mix!(root, ["chimeway.gen.migrations"])
    run_mix!(root, ["ecto.create"])
    run_mix!(root, ["ecto.migrate"])
    output = run_mix!(root, ["run", "priv/prove_core.exs"])
    # read generated proof source and strictly parse its one line
  rescue
    error ->
      cleanup!(identity, opts)
      reraise error, __STACKTRACE__
  end

Map.put(result, :cleanup, cleanup!(identity, opts))
```

**Generated-host/config pattern** (lines 183-241): extend `scaffold!/3`, `mix_exs/1`, and `config_exs/1`; preserve the unpacked artifact as the single `:chimeway` dependency, retain direct `:oban`, add direct `{:mailglass, "~> 1.3"}`, and use `ArtifactConsumer.Repo` as the host repo. Add generated Mailglass config and normal Ecto migration files—not a private `Mailglass.TestRepo` or raw DDL.

```elixir
File.write!(Path.join(root, "lib/artifact_consumer/repo.ex"), repo_ex())
File.write!(Path.join(root, "lib/artifact_consumer/notifiers/core_trace.ex"), notifier_ex())
File.write!(Path.join(root, "priv/prove_core.exs"), proof_ex())

defp deps, do: [
  {:chimeway, path: ...}, {:ecto_sql, "~> 3.11"},
  {:postgrex, ">= 0.0.0"}, {:oban, "~> 2.17"}
]
```

**Strict public-output parser pattern** (lines 295-329): implement a distinct Mailglass prefix/allowlist map; split textual pairs, map only known string keys, reject duplicates, and assert the complete exact key set. Do not turn output keys into atoms.

```elixir
case Map.fetch(@evidence_keys, key) do
  {:ok, allowed_key} -> allowed_key
  :error -> raise "artifact consumer proof emitted an unknown evidence key"
end

if Map.has_key?(evidence, evidence_key) do
  raise "artifact consumer proof emitted a duplicate evidence key"
end
```

**Trace-derived evidence pattern** (lines 131-167): extend the validation shape for `channel`, `render_key`, `render_version`, and `last_attempt.adapter_module`; require `"email"`, the exact stable render key/version, succeeded status/outcome, the Mailglass adapter module, and ordered lifecycle events. The generated script must use `Chimeway.Traces.explain_delivery/1` exactly once and must not query a repo.

### Generated notifier and mailable templates (event-driven/transform)

**Notifier analog:** `examples/chimeway_demo_host/lib/demo_host/notifiers/invite_sent.ex`, lines 7-49.

```elixir
use Chimeway.Notifier

@impl true
def notification_key, do: "teampulse.invite_sent"
@impl true
def version, do: 1

@impl true
def channels(_params, _recipient), do: {:ok, [:email, :in_app]}

@impl true
def rendering(_params, _recipient) do
  {:ok, %{assigns: %{...}, channels: %{email: %{render_key: "teampulse.invite_sent.email", render_version: 1}}}}
end
```

For the proof, make this **email-only**, use fixed stable values (recommended `artifact_consumer.mailglass_proof` and `.email`, version `1`), and trigger with explicit fixed `tenant_id` and `idempotency_key`.

**Mailable analog:** `examples/chimeway_demo_host/lib/demo_host/mailers/invite_email.ex`, lines 16-41.

```elixir
use Mailglass.Mailable, stream: :transactional

def invite_email(assigns) when is_map(assigns) do
  new()
  |> Mailglass.Message.update_swoosh(fn email ->
    email
    |> Swoosh.Email.to(recipient(assigns))
    |> Swoosh.Email.from({"TeamPulse", "invites@teampulse.test"})
    |> Swoosh.Email.subject(subject)
    |> Swoosh.Email.html_body(html_body)
    |> Swoosh.Email.text_body(text_body)
  end)
  |> Mailglass.Message.put_function(:invite_email)
end
```

Map the exact render key to `{ArtifactConsumer.Mailers.MailglassProofEmail, :mailglass_proof_email}` in `:channel_adapter_configs`, following the established setup at `test/chimeway/dispatch/executor_mailglass_adapter_test.exs:30-36`. Before synchronous trigger, call `Mailglass.Adapters.Fake.checkout/0` and `Mailglass.Adapters.Fake.set_shared(self())` as at lines 20-22; assert exactly one Fake record privately, without emitting it.

**Migration wrapper analog:** `test/support/mailglass/migrations/00000000000001_mailglass_init.exs`, lines 1-7.

```elixir
defmodule Mailglass.TestRepo.Migrations.MailglassInit do
  use Ecto.Migration
  def up, do: Mailglass.Migration.up()
  def down, do: Mailglass.Migration.down()
end
```

Rename the generated module for `ArtifactConsumer.Repo.Migrations`; retain the public wrapper verbatim.

### `test/chimeway/release_gate_contract_test.exs` (serialized integration contract, event-driven)

**Analog:** unpacked Core adopter-proof describe block, lines 977-1164.

**Serialized package proof** (lines 977-1042): add the Mailglass test within this existing `async: false` file and build/unpack setup. Call `ArtifactConsumerFixture.prove_mailglass!(root)`, assert the exact safe line/allowlist, one public `explain_delivery/1` call, artifact cleanup, and never accept source-tree or direct-DB evidence.

```elixir
@tag timeout: 120_000
test "a clean consumer proves one public Core lifecycle from only the unpacked artifact", %{root: root} do
  proof = ArtifactConsumerFixture.prove_core!(root)
  assert Map.keys(proof.evidence) |> Enum.sort() == [...]
  assert length(Regex.scan(~r/Chimeway\.Traces\.explain_delivery\(/, proof.proof_source)) == 1
  refute File.exists?(proof.identity.root)
end
```

**Safety test pattern** (lines 1121-1137): mirror unknown key plus duplicate-key rejection for the dedicated Mailglass parser and include malformed/missing-key coverage. Keep the dynamic unknown key and `String.to_existing_atom/1` assertion to demonstrate no atom creation.

**Timeline invariant** (lines 1140-1163): reuse `ordered_subsequence?/2`, allowing interposed public events while requiring `:event_created`, `:notification_created`, `:delivery_planned`, and `:attempt_recorded` in order.

### `guides/introduction/mailglass-integration.md` (canonical guide, request-response guidance)

**Analog:** the guide’s current responsibility, config, mailable, and verification flow at lines 5-13, 47-65, 69-141, and 143-165.

**Configuration/mapping language** (lines 49-65): retain `channel_adapters` plus `channel_adapter_configs` and state that the stable notifier render key must exactly match the host-owned mailable map.

```elixir
config :chimeway,
  channel_adapters: %{"email" => Chimeway.Adapters.Mailglass},
  channel_adapter_configs: %{
    "email" => [mailables: %{
      "teampulse.invite_sent.email" => {DemoHost.Mailers.InviteEmail, :invite_email}
    }]
  }
```

Add a concise clean-consumer proof subsection near verification. Use literal brand voice: what happened (Fake records one host-composed message and Chimeway records a successful Mailglass adapter attempt), why it matters (the configured render-key/mailable/routing/persistence seam ran), and next step (use the blueprint for host wiring). State that it does **not** prove provider acceptance, sender/domain verification, inbox placement/display, production credentials, provider callbacks, or live webhook feedback. Cross-reference the blueprint; do not add a duplicate tutorial.

Correct the migration/repo wording at line 45: Mailglass uses a host-configured repo; this proof intentionally configures one consumer-owned host repo. Replace the line-165 implication that consumers run `mix verify.mailglass`; label it as a repository-maintainer regression suite.

### `test/chimeway/doc_contract_test.exs` (documentation contract, transform)

**Analog:** existing Mailglass guide doc-contract block, lines 609-688.

```elixir
@mailglass_integration_guide Path.expand(
  "../../guides/introduction/mailglass-integration.md", __DIR__
)

describe "mailglass integration guide doc contract (DOCS-06 / DOCS-07)" do
  setup do
    content = File.read!(@mailglass_integration_guide)
    %{content: content}
  end

  for required <- @required do
    test "requires #{required} in mailglass integration guide", %{content: content} do
      assert String.contains?(content, unquote(required))
    end
  end
end
```

Extend this same describe block with required truthful Fake/proof and limitation phrases, the host-configured/one-consumer-repo ownership wording, and the blueprint link. Add forbidden assertions for unqualified "email delivered" claims and for presenting `mix verify.mailglass` as a Hex-consumer command. Preserve existing webhook constraints.

## Shared Patterns

### Artifact provenance and cleanup

**Source:** `test/support/artifact_consumer_fixture.ex:20-68,98-119,339-365`  
**Apply to:** Mailglass fixture path and release-gate proof.

The generated `mix.exs` must declare exactly one `:chimeway` path dependency equal to the unpacked artifact, never the repository root. Reuse fixture-generated unique temporary filesystem/database identities and cleanup on success, rescue, and catch.

### Host-owned Mailglass configuration and Fake ownership

**Source:** `test/chimeway/dispatch/executor_mailglass_adapter_test.exs:16-55`  
**Apply to:** generated config/proof script.

```elixir
Mailglass.Adapters.Fake.checkout()
Mailglass.Adapters.Fake.set_shared(self())

Application.put_env(:chimeway, :channel_adapters, %{"email" => Chimeway.Adapters.Mailglass})
Application.put_env(:chimeway, :channel_adapter_configs, %{
  "email" => [mailables: MailglassFixtures.mailables()]
})
```

Generated config should use persistent config rather than test-time restore logic, but preserve this adapter/map shape and explicit Fake ownership.

### Render-key resolution and redaction boundary

**Source:** `lib/chimeway/adapters/mailglass.ex:63-90,133-172`  
**Apply to:** generated notifier, config map, proof assertions, docs.

```elixir
with :ok <- validate_tenant_id(delivery),
     {:ok, recipient} <- resolve_recipient(delivery),
     {:ok, msg} <- build_message(delivery, recipient, config) do
  Mailglass.Outbound.deliver(msg, outbound_opts)
end

case Map.fetch(mailables, delivery.render_key) do
  {:ok, {module, function}} ->
    assigns = Map.merge(%{"to" => recipient}, delivery.render_data || %{})
    msg = build_mailable_message(module, function, assigns)
  :error -> {:error, :permanent, %{reason: :unknown_render_key, render_key: delivery.render_key}}
end
```

No generated proof output may serialize recipient, rendered content, assigns, credentials, raw Mailglass structures, provider values/responses, or metadata.

### Public explainability evidence

**Source:** `lib/chimeway/traces.ex:126-184`, `lib/chimeway/traces/explanation.ex:11-34`, and `test/support/artifact_consumer_fixture.ex:131-167`  
**Apply to:** generated Mailglass proof and release-gate assertions.

`explain_delivery/1` projects `channel`, persisted `render_key`/`render_version`, status, last attempt (including `adapter_module`), and a chronological timeline. It is the sole lifecycle evidence source; the Fake count stays an in-script assertion only.

## No Analog Found

None. Every repository file is an extension of an existing exact phase-93 or Mailglass pattern. The generated consumer adds a new email-only template, but its notifier, mailable, migration wrapper, Fake setup, and strict proof-line shape all have direct local analogs.

## Metadata

**Analog search scope:** `test/support`, `test/chimeway`, `lib/chimeway`, `examples/chimeway_demo_host`, `guides`, `brandbook`  
**Files scanned:** 15  
**Pattern extraction date:** 2026-08-08

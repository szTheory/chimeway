# Accrue Dunning Integration

This guide is the canonical adoption path for composing Chimeway with [Accrue](https://github.com/szTheory/accrue) dunning. Follow it when you want one credible vertical slice: add both libraries, configure the Accrue dunning engine, start a campaign from billing events, inspect the workflow trace, and verify termination via Outcome Signal.

For copy-paste notifier and engine config sections, see the [Accrue dunning blueprint](../recipes/accrue-dunning-blueprint.md). This guide owns the end-to-end path from dependency to verification.

## Responsibility split (SEED-003)

**Chimeway orchestrates the when and why:** durable notification lifecycle, workflow progression (Email 1 → 48h wait → Email 2 escalation), suppression and preference gates, idempotency, Outcome Signal routing, and operator traces you can search at `/admin/chimeway`.

**Accrue owns billing state:** subscriptions, invoices, payment failure and recovery anchors, and dunning campaign timestamps on domain models. Accrue emits billing events; Chimeway does not mutate Accrue records.

This integration is **not** a `Chimeway.Adapter` seam — it is Accrue's `Accrue.Dunning.Engine` behaviour plus Chimeway workflow + Signal bridge only.

## 1. Dependencies

Add Chimeway and Accrue to your host `mix.exs`:

```elixir
def deps do
  [
    {:chimeway, "~> 1.0"},
    {:accrue, "~> 1.3", optional: true}
  ]
end
```

This normal Hex dependency declaration is installation guidance, not a provenance claim. The executable clean-consumer check may label its record `released_package` only after the generated consumer resolves exact Accrue `1.3.0`, finds and loads `Accrue.Integrations.Chimeway` from that resolved package, and reports the resolved Chimeway artifact version. The executable check, not optimistic prose, authorizes that label.

Repository maintainers use the sibling checkout and `ACCRUE_PATH` only for regression work; see [Verification](#6-verification). Those mechanics do not establish packaged-consumer provenance.

## 2. Database / migrations

Chimeway stores the durable lifecycle spine (`event` → `notification` → `delivery` → `attempt`) in your database. Generate and run Chimeway migrations:

```bash
mix chimeway.gen.migrations
mix ecto.migrate
```

For Chimeway install depth — repo config, supervisor setup, and migration idempotency — see [Installation](installation.md).

Accrue maintains its own schema and repo. Follow Accrue documentation for repo setup and migrations in your host application. Both libraries typically share the same Postgres database but use separate Ecto repos and migration paths.

## 3. Runtime config

Register the Chimeway dunning engine in Accrue at runtime:

```elixir
config :accrue,
  dunning: [
    engine: Accrue.Integrations.Chimeway,
    campaign: [enabled: true]
  ]
```

The bundled `Accrue.Integrations.Chimeway.DunningNotifier` module in the Accrue repo implements `workflow/2` — hosts do not author a separate dunning notifier for the standard Accrue integration path. The engine resolves billing domain models to recipients and calls `Chimeway.trigger/3` with stable `notification_key`, `idempotency_key`, and `tenant_id` when Accrue starts a campaign.

For the full Chimeway runtime setup (installer repo, `Chimeway.Repo`, supervisor), see [Installation §3–§4](installation.md#3-configuration).

## 4. DunningNotifier reference

Runnable reference: `Accrue.Integrations.Chimeway.DunningNotifier` in the Accrue repo.

The notifier declares stable string keys — not module names — as durable identity:

```elixir
@impl true
def notification_key, do: "accrue.dunning"
```

`workflow/2` defines a two-step dunning journey:

1. **Email 1 (`initial_email`)** — delivers immediately.
2. **48h wait** — workflow enters `:waiting` on the `wait_until` progress rule (`status_context["rule_kind"] == "wait_until"`).
3. **Email 2 (`escalation_email`)** — fires only if no Outcome Signal arrives within 48 hours.

Accrue 1.3+ does **not** declare `cancel_signals` on the `wait_until` rule. Termination is via `cancel_campaign/3` emitting an Outcome Signal — see §5.

When Accrue starts a campaign, the engine passes `idempotency_key` (campaign-scoped deduplication) and `tenant_id` (customer id) to `Chimeway.trigger/3` — both required for durable traces and tenant-scoped operator search.

For the full `workflow/2` excerpt with step config, see the [Accrue dunning blueprint](../recipes/accrue-dunning-blueprint.md).

## 5. Billing-event triggers

Production hosts subscribe to Accrue webhooks or internal event buses — **do not** adopt dunning by calling `Chimeway.trigger(Accrue.Integrations.Chimeway.DunningNotifier, ...)` from host application code. Accrue billing events are the primary adoption path:

| Accrue event | Role |
|--------------|------|
| `invoice.payment_failed` | Starts dunning — engine calls `start_campaign/3` → `Chimeway.trigger/3` with `DunningNotifier` |
| `invoice.paid` | Terminates active wait via Outcome Signal — `cancel_campaign/3` → `Chimeway.Signal.track/4` with `event_name: "invoice.paid"` |

The `invoice.paid` Outcome Signal routes to waiting runs on the `wait_until` step via `Workflows.route_signal/1` — no host callback route required.

Local and test proof uses `Accrue.Test.trigger_event/2`:

```elixir
# Start dunning campaign
Accrue.Test.trigger_event(:invoice_payment_failed, %{
  id: invoice.processor_id,
  customer: customer.processor_id,
  subscription: subscription.processor_id,
  amount_due: invoice.amount_due_minor,
  currency: invoice.currency
})

# Terminate wait via Outcome Signal
Accrue.Test.trigger_event(:invoice_paid, %{
  id: invoice.processor_id,
  customer: customer.processor_id,
  subscription: subscription.processor_id
})
```

## Clean-consumer proof

Use the packaged-consumer proof when you need adoption evidence from an immutable Chimeway package archive, rather than from this repository source tree. Obtain the immutable package archive and SHA-256 from the trusted package or release channel; an arbitrary source checkout or unpacked directory does not establish package provenance.

```bash
MIX_ENV=prod mix run scripts/prove-accrue-consumer.exs -- --artifact-archive <absolute-tarball> --sha256 <lowercase-64-hex>
```

The release-gate contract builds the package, passes its immutable archive and digest to this command, and invokes the runner from the unpacked artifact. The runner verifies the archive digest and package metadata, confirms that the runner and its support fixture are package members, unpacks into owned temporary storage, then creates an isolated temporary host and database. That host uses the unpacked artifact as its only `:chimeway` dependency. Success occurs only after archive, generated-consumer, public lifecycle, provenance, and cleanup checks pass: it emits exactly one `CHIMEWAY_ACCRUE_PROOF` record. Invalid input, or any provenance, lifecycle, or cleanup failure, exits nonzero without a proof record and removes both temporary host/database and archive-unpack storage.

Accrue owns both event boundaries: `invoice.payment_failed` enters its campaign, public workflow evidence reaches `waiting / waiting_for_step_progression`, and `invoice.paid` produces the outcome signal through the integration. The host does not call Chimeway notifier, trigger, or signal APIs for either boundary. Waiting and outcome facts are derived through `Chimeway.Workflows.explain/2` and `Chimeway.Workflows.list_traces/2`. The resulting public evidence is `active / signal_received`:

```text
CHIMEWAY_ACCRUE_PROOF provenance=released_package accrue_version=1.3.0 chimeway_version=1.0.0 workflow_key=accrue.dunning workflow_version=1 waiting_state=waiting waiting_reason=waiting_for_step_progression outcome_event=invoice.paid outcome_state=active outcome_reason=signal_received timeline_reasons=waiting_for_step_progression,signal_received
```

The record deliberately contains only stable workflow, lifecycle, and provenance facts; it contains no identifiers, billing details, recipients, payloads, metadata, credentials, raw structs, or database results. `active / signal_received` means the outcome signal ended the waiting escalation path; it does not mean the workflow completed or entered a terminal state. The Fake processor coverage is deterministic local orchestration only; live provider credentials, webhooks, and Phase 96 CI/front-door work remain outside this proof.

### Provenance labels

If the resolved-package source/module validation above cannot establish the released package branch, the proof reports the immutable Accrue ref `236fa2f1649e771f3b515603495436badeed3c7b` as **compatibility evidence only**. It is not released-package proof or installation guidance. It does not belong in a dependency declaration, an installation command, or an adopter copy-paste block.

## 6. Verification

### Repository-maintainer regression analogs (not packaged-consumer proof)

After changing this repository's integration code, maintainers can run the named regression command:

```bash
ACCRUE_PATH=../accrue/accrue mix verify.accrue --warnings-as-errors
```

`mix verify.accrue`, `ACCRUE_PATH`, the sibling checkout, and CI checkout are repository-maintainer regression mechanics. They exercise ECOS-06 lifecycle proof at the Chimeway root and the DEMO-07 demo host proof; they are not independent packaged-consumer provenance.

Seed the demo host dunning scenario:

```elixir
DemoHost.Seeds.seed_accrue_dunning/0
```

Then search `/admin/chimeway` by customer email (`accrue.demo@teampulse.test`) to inspect `accrue.dunning` workflow progression, delivery attempts, and `signal_received` on `invoice.paid`.

### Minimal email path (Logger adapter)

For self-contained local proof without provider credentials, configure Chimeway's Logger email adapter in test or dev — the demo host uses this path for Accrue lane isolation. No API keys or production secrets are required in guide snippets.

### Optional: Mailglass email delivery

When hosts want production email delivery for dunning steps, wire `Chimeway.Adapters.Mailglass` per the [Mailglass integration blueprint](../recipes/mailglass-integration-blueprint.md). Chimeway still orchestrates workflow progression; Mailglass handles templating and send.

## Related guides

- [Golden Path](golden-path.md) — Chimeway-only first integration
- [Accrue dunning blueprint](../recipes/accrue-dunning-blueprint.md) — focused notifier/engine recipe
- [Mailglass integration blueprint](../recipes/mailglass-integration-blueprint.md) — optional email delivery for dunning steps
- [Mention escalation](../recipes/mention-escalation.md) — workflow recipe pattern with demo host pointers
- [Installation](installation.md) — Chimeway install and migration depth

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
    accrue_dep()
  ]
end

defp accrue_dep do
  case System.get_env("ACCRUE_PATH") do
    nil -> {:accrue, "~> 1.2", optional: true}
    path -> {:accrue, path: path, runtime: false}
  end
end
```

For local development and integration proof, check out the Accrue repo as a sibling and point `ACCRUE_PATH` at it — the `Accrue.Integrations.Chimeway` engine module lives in the Accrue repo, not in the hex-only artifact:

```bash
ACCRUE_PATH=../accrue/accrue mix deps.get
```

When the integration module is published to hex, `{:accrue, "~> 1.2"}` is sufficient for production adopters. Local proof and CI still require the sibling checkout for `Accrue.Integrations.Chimeway`.

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
2. **48h wait** — workflow enters `:waiting` with `cancel_signals: ["invoice.paid"]` on the `wait_until` progress rule.
3. **Email 2 (`escalation_email`)** — fires only if no Outcome Signal arrives within 48 hours.

When Accrue starts a campaign, the engine passes `idempotency_key` (campaign-scoped deduplication) and `tenant_id` (customer id) to `Chimeway.trigger/3` — both required for durable traces and tenant-scoped operator search.

For the full `workflow/2` excerpt with step config, see the [Accrue dunning blueprint](../recipes/accrue-dunning-blueprint.md).

## 5. Billing-event triggers

Production hosts subscribe to Accrue webhooks or internal event buses — **do not** adopt dunning by calling `Chimeway.trigger(Accrue.Integrations.Chimeway.DunningNotifier, ...)` from host application code. Accrue billing events are the primary adoption path:

| Accrue event | Role |
|--------------|------|
| `invoice.payment_failed` | Starts dunning — engine calls `start_campaign/3` → `Chimeway.trigger/3` with `DunningNotifier` |
| `invoice.paid` | Terminates active wait via Outcome Signal — `cancel_campaign/3` → `Chimeway.Signal.track/4` with `event_name: "invoice.paid"` |

The `invoice.paid` signal satisfies `cancel_signals` on the active `wait_until` step — no host callback route required.

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

## 6. Verification

After wiring dependencies and config, run the named proof command:

```bash
ACCRUE_PATH=../accrue/accrue mix verify.accrue --warnings-as-errors
```

This exercises ECOS-06 lifecycle proof at the Chimeway root and DEMO-07 demo host proof.

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

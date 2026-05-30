# Accrue Dunning Blueprint

## Who this is for

**Feature Developer (DunningNotifier authoring):** Your JTBD is "author a bundled `Chimeway.Notifier` with a multi-step dunning workflow" — implement `workflow/2` with 48h escalation and stable `notification_key` / render keys while Accrue resolves billing domain models to recipients.

**Adopter (Accrue engine config):** Your JTBD is "wire Accrue billing events into Chimeway dunning without host callback glue" — subscribe to `invoice.payment_failed` and `invoice.paid`, set `config :accrue, dunning: [engine: Accrue.Integrations.Chimeway]`, and let Accrue start or terminate campaigns through the engine adapter.

## Prerequisites

- [Golden Path](../introduction/golden-path.md) — install, migrations, and your first `Chimeway.trigger/3`
- Accrue sibling checkout for local dev: set `ACCRUE_PATH` to your Accrue repo (optional path dep in host `mix.exs`, mirroring Chimeway root and demo host)

## Responsibility split (SEED-003)

**Chimeway orchestrates the when and why:** durable notification lifecycle, workflow progression (Email 1 → 48h wait → Email 2 escalation), suppression and preference gates, idempotency, Outcome Signal routing, and operator traces you can search at `/admin/chimeway`.

**Accrue owns billing state:** subscriptions, invoices, payment failure and recovery anchors, and dunning campaign timestamps on domain models. Accrue emits billing events; Chimeway does not mutate Accrue records.

This integration is **not** a `Chimeway.Adapter` seam — it is Accrue's `Accrue.Dunning.Engine` behaviour plus Chimeway workflow + Signal bridge only.

## Feature Developer: DunningNotifier authoring

Runnable reference module: `Accrue.Integrations.Chimeway.DunningNotifier` in the Accrue repo.

Stable string keys — not module names — are the durable identity:

```elixir
@impl true
def notification_key, do: "accrue.dunning"

@impl true
def workflow(_params, _recipient) do
  {:ok,
   %{
     workflow_key: "accrue.dunning",
     workflow_version: 1,
     steps: [
       %{
         step_key: "initial_email",
         step_order: 1,
         channel: :email,
         config: %{
           "progress" => [
             %{
               "kind" => "wait_until",
               "anchor" => "prior_delivery_terminal_at",
               "delay_seconds" => 172_800,
               "to_step" => "escalation_email"
             }
           ]
         }
       },
       %{
         step_key: "escalation_email",
         step_order: 2,
         channel: :email,
         config: %{}
       }
     ]
   }}
end
```

**Escalation shape (SEED-003):** Email 1 delivers immediately → workflow enters `:waiting` on the `wait_until` step for up to 48h → Email 2 fires only if no Outcome Signal arrives.

**Termination (Accrue 1.3+):** `cancel_campaign/3` emits `Chimeway.Signal.track/4` with `event_name: "invoice.paid"`. Chimeway `Workflows.route_signal/1` resumes the waiting run — no rule-config `cancel_signals` on the `wait_until` step.

**Trigger options:** When Accrue starts a campaign, the engine calls `Chimeway.trigger/3` with `idempotency_key` and `tenant_id` (customer id) — both required for durable deduplication and tenant-scoped traces.

## Adopter: Accrue engine registration

Configure Accrue to use the Chimeway dunning engine at runtime:

```elixir
config :accrue,
  dunning: [
    engine: Accrue.Integrations.Chimeway,
    campaign: [enabled: true]
  ]
```

**Event subscription (billing events, not host glue):**

| Accrue event | Role |
|--------------|------|
| `invoice.payment_failed` | Starts dunning — `Accrue.Integrations.Chimeway.start_campaign/3` → `Chimeway.trigger/3` with `DunningNotifier` |
| `invoice.paid` | Terminates active wait via Outcome Signal — `cancel_campaign/3` → `Chimeway.Signal.track/4` with `event_name: "invoice.paid"` |

Do **not** adopt dunning by calling `Chimeway.trigger(Accrue.Integrations.Chimeway.DunningNotifier, ...)` from host application code. Production hosts subscribe to Accrue webhooks or internal event buses; local proof uses `Accrue.Test.trigger_event/2`.

## Trigger example (local / test)

```elixir
Accrue.Test.trigger_event(:invoice_payment_failed, %{
  id: invoice.processor_id,
  customer: customer.processor_id,
  subscription: subscription.processor_id,
  amount_due: invoice.amount_due_minor,
  currency: invoice.currency
})
```

After the initial email succeeds, terminate the wait with:

```elixir
Accrue.Test.trigger_event(:invoice_paid, %{
  id: invoice.processor_id,
  customer: customer.processor_id,
  subscription: subscription.processor_id
})
```

The `invoice.paid` Outcome Signal routes to the waiting run via `Workflows.route_signal/1` — no host callback route required.

## Runnable demo

- **Seeds:** `DemoHost.Seeds.seed_accrue_dunning/0` — standalone API using `Accrue.Test.trigger_event/2` (not invoked from `DemoHost.Seeds.run/0`)
- **Verification:** `ACCRUE_PATH=../accrue/accrue mix verify.accrue --warnings-as-errors` (root ECOS-06 lifecycle + demo host DEMO-07 proof)
- **Operator trace:** Search `/admin/chimeway` by customer email (`accrue.demo@teampulse.test`) to inspect `accrue.dunning` workflow progression and `signal_received` on `invoice.paid`

Demo host uses the Logger email adapter for Accrue lane isolation. For production email delivery, see the optional Mailglass path below.

## Out of scope

This blueprint covers notifier authoring, Accrue engine config, billing-event triggers, and the orchestration vs billing-state split with demo pointers. The full golden-path Accrue integration guide, guide doc-contract, and formal `mix verify.accrue` CI job in MAINTAINING are documented in [Accrue dunning integration](../introduction/accrue-dunning-integration.md) — not duplicated here.

## Related guides

- [Mailglass integration blueprint](mailglass-integration-blueprint.md) — optional email delivery via `Chimeway.Adapters.Mailglass` (Phase 58 D-07)
- [Accrue dunning integration](../introduction/accrue-dunning-integration.md) — canonical end-to-end adoption path (primary)
- [Golden Path](../introduction/golden-path.md) — first Chimeway integration
- [Mention escalation](mention-escalation.md) — workflow recipe pattern with demo host pointers

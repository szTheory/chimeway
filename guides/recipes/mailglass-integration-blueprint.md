# Mailglass Integration Blueprint

## Who this is for

**Adopter (host app wiring):** Your JTBD is "wire Chimeway email delivery through Mailglass without bypassing the durable lifecycle" — register the Mailglass adapter, map render keys to host mailables, and keep templating in Mailglass while Chimeway owns orchestration.

**Feature Developer (notifier authoring):** You author a `Chimeway.Notifier` with stable `notification_key` and per-channel `render_key` values. Chimeway plans and persists deliveries; Mailglass renders and sends the email.

## Prerequisites

- [Golden Path](../introduction/golden-path.md) — install, migrations, and your first `Chimeway.trigger/3`
- [Custom adapter](custom-adapter.md) — built-in Mailglass adapter stub and runtime config shape

## Responsibility split (SEED-003)

**Chimeway orchestrates the when and why:** durable notification lifecycle, suppression and preference gates, idempotency, scheduling, and operator traces you can search at `/admin/chimeway`.

**Mailglass handles templating and delivery:** MJML templates, Swoosh email assembly, and provider send. Chimeway passes notifier `rendering/2` assigns through to your host mailable; Mailglass builds the final message.

**Product name vs module:** REQUIREMENTS and adoption docs refer to `Chimeway.Adapter.Mailglass`; the implementation module is `Chimeway.Adapters.Mailglass`.

## Feature Developer: notifier authoring

Stable string keys — not module names — are the durable identity:

```elixir
defmodule MyApp.Notifiers.InviteSent do
  use Chimeway.Notifier

  @impl true
  def notification_key, do: "teampulse.invite_sent"

  @impl true
  def version, do: 1

  @impl true
  def recipients(%{email: email}) do
    {:ok, [%{recipient_identity: "user:#{email}", recipient_type: "user"}]}
  end

  @impl true
  def build(%{team_name: team_name}, _recipient) do
    {:ok,
     %{
       "headline" => "You're invited to #{team_name}",
       "body" => "Join your team."
     }}
  end

  @impl true
  def channels(_params, _recipient), do: {:ok, [:email, :in_app]}

  @impl true
  def rendering(%{team_name: team_name}, _recipient) do
    {:ok,
     %{
       assigns: %{
         "subject" => "You're invited to #{team_name}",
         "html_body" => "<p>Join your team.</p>",
         "text_body" => "Join your team."
       },
       channels: %{
         email: %{render_key: "teampulse.invite_sent.email", render_version: 1}
       }
     }}
  end
end
```

Runnable TeamPulse reference: `DemoHost.Notifiers.InviteSent` in the demo host.

## Adopter: adapter registration

Add Mailglass to your host `mix.exs` (`{:mailglass, "~> 1.3"}`) and register the adapter at runtime:

```elixir
config :chimeway,
  channel_adapters: %{"email" => Chimeway.Adapters.Mailglass},
  channel_adapter_configs: %{
    "email" => [
      mailables: %{
        "teampulse.invite_sent.email" => {DemoHost.Mailers.InviteEmail, :invite_email}
      }
    ]
  }
```

Replace `DemoHost.Mailers.InviteEmail` with your host mailable module in production apps. The `render_key` string in notifier `rendering/2` must match the key in the `mailables` map.

## Host mailable mapping

Your host owns the `Mailglass.Mailable` module. Chimeway's Mailglass adapter resolves `render_key` → `{Module, :function}` and passes delivery `render_data` (notifier assigns plus recipient `"to"`) into the mailable function.

Runnable reference: `DemoHost.Mailers.InviteEmail` — implements `invite_email/1` for the `teampulse.invite_sent.email` render key.

## Trigger example

```elixir
Chimeway.trigger(
  DemoHost.Notifiers.InviteSent,
  %{email: "alex@teampulse.test", team_name: "Engineering"},
  idempotency_key: "teampulse-invite-alex",
  tenant_id: "teampulse"
)
```

Both `:idempotency_key` and `:tenant_id` are required.

Runnable demo: `DemoHost.Seeds.seed_invite/0` triggers the same notifier with deterministic idempotency keys for local proof and journey tests.

## Operator trace inspectability

After delivery, search `/admin/chimeway` by recipient identity. The delivery detail shows the stable notification key (`teampulse.invite_sent`) and the Mailglass adapter module on the attempt timeline — no raw PII in operator surfaces.

## Out of scope

This blueprint covers notifier authoring, adapter config, and the orchestration vs templating split with demo pointers. The full golden-path Mailglass integration guide, `mix verify.mailglass` CI gate, and demo host inbound webhook route wiring are documented in [Mailglass integration](../introduction/mailglass-integration.md) — not duplicated here.

## Related guides

- [Mailglass integration](../introduction/mailglass-integration.md) — canonical end-to-end adoption path (primary)
- [Custom adapter](custom-adapter.md) — adapter behaviour and Mailglass stub
- [Golden Path](../introduction/golden-path.md) — first Chimeway integration
- [Mention escalation](mention-escalation.md) — workflow recipe pattern with demo host pointers

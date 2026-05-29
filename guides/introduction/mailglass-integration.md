# Mailglass Integration

This guide is the canonical adoption path for composing Chimeway with [Mailglass](https://hex.pm/packages/mailglass). Follow it when you want one credible vertical slice: add both libraries, configure the Mailglass adapter, trigger an email delivery, inspect the trace, and optionally wire inbound feedback.

## Responsibility split (SEED-003)

**Chimeway orchestrates the when and why:** durable notification lifecycle, suppression and preference gates, idempotency, scheduling, and operator traces you can search at `/admin/chimeway`.

**Mailglass handles templating and delivery:** MJML templates, Swoosh email assembly, and provider send. Chimeway passes notifier `rendering/2` assigns through to your host mailable; Mailglass builds the final message.

**Product name vs module:** REQUIREMENTS and adoption docs refer to `Chimeway.Adapter.Mailglass`; the implementation module is `Chimeway.Adapters.Mailglass`.

For copy-paste notifier and adapter sections, see the [Mailglass integration blueprint](../recipes/mailglass-integration-blueprint.md). This guide owns the end-to-end path from dependency to verification.

## 1. Dependencies

Add Chimeway and Mailglass to your host `mix.exs`:

```elixir
def deps do
  [
    {:chimeway, "~> 1.0"},
    {:mailglass, "~> 1.3"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

## 2. Database / migrations

Chimeway stores the durable lifecycle spine (`event` → `notification` → `delivery` → `attempt`) in your database. Generate and run Chimeway migrations:

```bash
mix chimeway.gen.migrations
mix ecto.migrate
```

For Chimeway install depth — repo config, supervisor setup, and migration idempotency — see [Installation](installation.md).

Mailglass maintains its own schema and repo. Follow the [Mailglass installation docs](https://hexdocs.pm/mailglass/installation.html) for repo setup, migrations, and Oban queues in your host application. Both libraries typically share the same Postgres database but use separate Ecto repos.

## 3. Runtime config

Register the Mailglass adapter for the email channel and map `render_key` values to host mailable functions:

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

Configure Mailglass per its docs — repo, Swoosh adapter, and provider credentials. Chimeway does not manage Mailglass application config; it only invokes your mailable through the adapter at delivery time.

For the full Chimeway runtime setup (installer repo, `Chimeway.Repo`, supervisor), see [Installation §3–§4](installation.md#3-configuration).

## 4. Host mailable

Your host owns the `Mailglass.Mailable` module. Chimeway's Mailglass adapter resolves `render_key` → `{Module, :function}` and passes delivery `render_data` (notifier assigns plus recipient `"to"`) into the mailable function.

Example host mailable for the `teampulse.invite_sent.email` render key:

```elixir
defmodule DemoHost.Mailers.InviteEmail do
  use Mailglass.Mailable, stream: :transactional

  def invite_email(assigns) when is_map(assigns) do
    to = Map.get(assigns, "to") || Map.get(assigns, :to)
    subject = Map.get(assigns, "subject") || "You're invited"
    html_body = Map.get(assigns, "html_body") || ""
    text_body = Map.get(assigns, "text_body") || ""

    new()
    |> Mailglass.Message.update_swoosh(fn email ->
      email
      |> Swoosh.Email.to(to)
      |> Swoosh.Email.from({"TeamPulse", "invites@teampulse.test"})
      |> Swoosh.Email.subject(subject)
      |> Swoosh.Email.html_body(html_body)
      |> Swoosh.Email.text_body(text_body)
    end)
    |> Mailglass.Message.put_function(:invite_email)
  end
end
```

Pair this mailable with a notifier that declares stable keys and a matching `render_key`:

```elixir
defmodule DemoHost.Notifiers.InviteSent do
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
    {:ok, %{"headline" => "You're invited to #{team_name}", "body" => "Join your team."}}
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

Runnable reference: `DemoHost.Notifiers.InviteSent` and `DemoHost.Mailers.InviteEmail` in the demo host.

## 5. Trigger and verification

Trigger the notifier with required idempotency and tenancy:

```elixir
Chimeway.trigger(
  DemoHost.Notifiers.InviteSent,
  %{email: "alex@teampulse.test", team_name: "Engineering"},
  idempotency_key: "teampulse-invite-alex",
  tenant_id: "teampulse"
)
```

Both `:idempotency_key` and `:tenant_id` are required. Omitting `tenant_id` returns `{:error, :missing_tenant_id}`.

After delivery, verify explainability:

- Search `/admin/chimeway` by recipient identity — the delivery detail shows the stable notification key (`teampulse.invite_sent`) and the Mailglass adapter module on the attempt timeline.
- In IEx, use `Chimeway.Traces.explain_delivery/1` on a delivery ID from the trigger result.

Runnable demo: `DemoHost.Seeds.seed_invite/0` triggers the same notifier with deterministic idempotency keys for local proof.

As a named proof command, run `mix verify.mailglass` after wiring — it exercises the Mailglass adapter contract, executor routing, webhook pipeline, and demo host delivery proof.

## 6. Optional inbound feedback

When provider webhooks should drive workflow progression, mount inbound feedback through **`Chimeway.Webhooks.process/4`** in your host controller. Do not bypass Chimeway's ingress layer with a standalone Mailglass webhook plug — Chimeway owns ingress durability, attempt recording, and signal emission; the Mailglass adapter supplies webhook callbacks (`verify_webhook`, `resolve_delivery`, `normalize_feedback`) behind the adapter behaviour.

Example host route (optional demo path `/webhooks/chimeway/mailglass`):

```elixir
def create(conn, _params) do
  raw_body = conn.assigns[:raw_body] || ""
  headers = Map.new(conn.req_headers)

  case Chimeway.Webhooks.process(
         "mailglass",
         conn.params,
         raw_body,
         headers: headers
       ) do
    {:ok, _ingress} ->
      send_resp(conn, 200, "")

    {:error, reason} ->
      send_resp(conn, 422, inspect(reason))
  end
end
```

The adapter's `verify_webhook/3` validates the provider signature, `resolve_delivery/2` maps the payload to a Chimeway delivery row, and `normalize_feedback/1` converts provider events into canonical delivery outcomes.

For workflow progression context — how `chimeway.delivery.succeeded` and `chimeway.delivery.bounced` signals resume or stop runs — see [Feedback escalation workflow](../recipes/feedback-escalation-workflow.md).

## Related guides

- [Golden Path](golden-path.md) — Chimeway-only first integration
- [Mailglass integration blueprint](../recipes/mailglass-integration-blueprint.md) — focused notifier/adapter recipe
- [Custom adapter](../recipes/custom-adapter.md) — adapter behaviour and Mailglass stub
- [Feedback escalation workflow](../recipes/feedback-escalation-workflow.md) — webhook-driven workflow progression
- [Installation](installation.md) — Chimeway install and migration depth

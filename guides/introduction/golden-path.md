# Golden Path

This guide is the canonical path from adding Chimeway as a dependency to your first **explainable** notification trace. Follow it when you want one credible vertical slice: install schema, configure the library, trigger a notification, and prove *why* it sent (or was suppressed) with `Chimeway.Traces.explain_delivery/1`.

For detailed install steps, see [Installation](installation.md). For inbox and channel depth after this slice, see [Getting Started](getting-started.md).

## 1. Add the dependency

Add Chimeway to your `mix.exs`:

```elixir
def deps do
  [
    {:chimeway, "~> 1.0"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

## 2. Install database schema

Chimeway stores the durable lifecycle spine (`event` → `notification` → `delivery` → `attempt`) in your database. Generate and run migrations:

```bash
mix chimeway.gen.migrations
mix ecto.migrate
```

For more detail on migration generation, see [Installation §2](installation.md#2-generate-and-run-migrations).

## 3. Configure Chimeway

You need two configuration pieces: one for the **installer** task and one for **runtime queries**.

**Installer (migration generator):**

```elixir
config :chimeway,
  repo: MyApp.Repo
```

Replace `MyApp.Repo` with your host application's Ecto repo module. This tells `mix chimeway.gen.migrations` where to copy migration files.

**Runtime (Chimeway.Repo):**

```elixir
config :chimeway, Chimeway.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "my_app_dev",
  pool_size: 10
```

At runtime, Chimeway queries through `Chimeway.Repo`. Configure it to use the **same database** where your host migrations created the `chimeway_*` tables — not a separate database unless you intentionally run Chimeway on its own Postgres instance.

For supervisor setup, add `{Chimeway.Application, []}` to your application children per [Installation §4](installation.md#4-add-to-supervision-tree). See [Installation §3–§4](installation.md#3-configuration) for the full `application.ex` pattern.

## 4. Define a minimal :in_app notifier

Create `lib/my_app/notifiers/welcome_user.ex`:

```elixir
defmodule MyApp.Notifiers.WelcomeUser do
  use Chimeway.Notifier

  @impl true
  def notification_key, do: "welcome_user"

  @impl true
  def version, do: 1

  @impl true
  def recipients(params) do
    {:ok, [%{recipient_identity: params.user_id, recipient_type: "user"}]}
  end

  @impl true
  def build(params, _recipient) do
    name = Map.get(params, :name, "there")

    {:ok, %{
      subject: "Welcome, #{name}!",
      body: "Your account is ready."
    }}
  end
end
```

The `:in_app` channel is the default when you omit `channels/2`. Use `recipients/1` with `recipient_identity` and `recipient_type` — the engine normalizes these keys when resolving deliveries.

## 5. Trigger your first notification

In IEx or your application code:

```elixir
params = %{user_id: "user_12345", name: "Alice"}

{:ok, result} =
  Chimeway.trigger(
    MyApp.Notifiers.WelcomeUser,
    params,
    idempotency_key: "signup_user_12345",
    tenant_id: "default"
  )
```

Both `:idempotency_key` and `:tenant_id` are required. Omitting `tenant_id` returns `{:error, :missing_tenant_id}`.

After a successful trigger, inspect `result.trace.event_id`, `result.trace.delivery_ids`, and `result.trace.correlation_id` — these are your pointers into the durable trace.

## 6. Prove explainability

Listing inbox messages shows *that* a notification exists; `explain_delivery/1` answers *why* it sent, failed, or was suppressed.

Using `result` from the trigger above:

```elixir
[delivery_id | _] = result.trace.delivery_ids

{:ok, explanation} = Chimeway.Traces.explain_delivery(delivery_id)

explanation.status
#=> :succeeded

explanation.suppression_reason
#=> nil

Enum.map(explanation.timeline, & &1.event)
```

You can also load the full event trace:

```elixir
{:ok, event} = Chimeway.Traces.get_trace(result.trace.event_id)
event.notifications |> Enum.flat_map(& &1.deliveries)
```

Optional: pass `correlation_id: "my-correlation-id"` on trigger, then `Chimeway.Traces.find_traces_by_correlation_id/1` to find related events.

### Validate in the demo host (no webhooks)

After your first `explain_delivery/1` in your host app, the **lowest-friction** way to validate explainability end-to-end is the Chimeway demo host IEx walkthrough — no SendGrid, no provider webhooks.

Follow the [Demo host trace walkthrough](../../examples/chimeway_demo_host/README.md) for a copy-paste IEx session using `Chimeway.trigger/3` and `explain_delivery/1`.

### Validate with operator UI (optional)

After you have trace rows in the database, the [`chimeway_admin`](../../chimeway_admin/) package provides a browser UI for the same Support Operator lookup flow. See the demo host [Operator trace UI (browser)](../../examples/chimeway_demo_host/README.md#operator-trace-ui-browser) section: start `mix phx.server`, visit `/admin/chimeway`, search by recipient or correlation ID, and inspect the delivery timeline. This complements IEx validation; it does not replace webhook E2E proof.

For **webhook-driven workflow progression**, use the [webhook feedback loop](#next-webhook-feedback-loop) appendix instead — the demo host README covers simple delivery explainability only.

## 7. What's next?

- [Getting Started](getting-started.md) — inbox listing, channels, and read/unread flows
- [Tracing a Notification](../recipes/tracing-a-notification.md) — telemetry, correlation, and diagnosis depth
- [Password reset support trace](../recipes/password-reset-support-trace.md) — Support Operator JTBD: why didn't the user get the email?
- [Feedback escalation workflow](../recipes/feedback-escalation-workflow.md) — Product Manager JTBD: webhook-driven workflow progression in the trace

## Next: webhook feedback loop

When inbound delivery feedback should drive workflow progression, Chimeway records webhook handling on the delivery timeline.

- **Progress path:** a succeeded delivery signal resumes the workflow; the trace timeline includes `:webhook_received` entries you can inspect with `Chimeway.Traces.explain_delivery/1`.
- **Stop path:** a bounced signal stops the workflow; the timeline still records the feedback event for explainability.

See the reference implementation in the repo:

- [Demo host example](https://github.com/jonlunsford/chimeway/tree/main/examples/chimeway_demo_host/)
- [Feedback pipeline E2E test](https://github.com/jonlunsford/chimeway/blob/main/examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs)

Feedback appears as `:webhook_received` entries on `Chimeway.Traces.explain_delivery/1` timelines — use that API to answer why progression advanced or stopped after inbound webhook data.

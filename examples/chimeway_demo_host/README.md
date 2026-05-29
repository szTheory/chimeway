# Chimeway Demo Host

This Phoenix example app is a **non-webhook explainability sandbox**. It validates `Chimeway.Traces.explain_delivery/1` on a simple delivery without SendGrid, provider webhooks, or fixture inserts — the lowest-friction way to prove Chimeway's trace APIs work end-to-end.

## Prerequisites

- Elixir 1.17+, PostgreSQL 15+
- From **repo root**: `mix deps.get && mix ecto.create && mix ecto.migrate` (uses shared `chimeway_dev` database per root `config/dev.exs`)
- Optional env vars: `PGHOST`, `PGUSER`, `PGPASSWORD` (same as root project)

## Start IEx

```bash
cd examples/chimeway_demo_host
iex -S mix
```

`.iex.exs` auto-starts `:chimeway`. Manual fallback:

```elixir
{:ok, _} = Application.ensure_all_started(:chimeway)
```

## Not this path: webhook progression

This README proves **explainability on a simple delivery**, not workflow progression after inbound webhooks.

- For webhook-driven progression, use the [Golden Path webhook appendix](../../guides/introduction/golden-path.md#next-webhook-feedback-loop).
- The [feedback pipeline E2E test](test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs) is an internal test reference for webhook progression — **do not** copy fixture helpers from that file into your app.

## Trace walkthrough (IEx)

### Trigger

Use the real public API — no fixtures:

```elixir
{:ok, result} =
  Chimeway.trigger(
    DemoHost.Notifiers.TraceDemo,
    %{user_id: "demo_user_1"},
    idempotency_key: "trace-demo-1",
    tenant_id: "demo"
  )

result.trace.event_id
result.trace.delivery_ids
result.trace.correlation_id
```

### Explain delivery

Support Operator JTBD fields:

```elixir
[delivery_id | _] = result.trace.delivery_ids

{:ok, explanation} = Chimeway.Traces.explain_delivery(delivery_id)

explanation.status
explanation.suppression_reason
explanation.planning_reason
explanation.timeline
```

On success with the default `:in_app` channel and Sync dispatcher, expect `explanation.status` → `:succeeded`. The timeline events are the explainability proof.

### Lookup by recipient

```elixir
Chimeway.Traces.find_traces_for_recipient("user:demo_user_1",
  notification_key: "trace_demo",
  limit: 5
)
```

## One-shot script (optional)

```bash
cd examples/chimeway_demo_host
mix demo.trace
```

Or: `mix run priv/scripts/trace_demo.exs`

## Operator trace UI (browser)

Visual trace lookup complements the IEx walkthrough above (Phase 39). Requires trace data from `mix demo.trace` or the IEx trigger section.

```bash
cd examples/chimeway_demo_host
mix phx.server
```

Open [http://localhost:4001/admin/chimeway](http://localhost:4001/admin/chimeway), search by recipient (e.g. `user:demo_user_1` from `mix demo.trace`), and open a delivery to inspect the unified timeline.

### Production auth

`DemoHost.AdminAuth` always allows access in `:dev` and `:test`. In `:prod` it always returns `{:error, :unauthorized}` — replace with your host's real `ChimewayAdmin.Auth` implementation before exposing admin routes.

### Out of scope for `chimeway_admin` MVP

Bell inbox, marketing/campaign tooling, health aggregates dashboard, notification definitions registry, and `aggregate_outcomes/1` charts are **not** included — trace lookup only.

## Related guides

- [Golden Path](../../guides/introduction/golden-path.md)
- [Password reset support trace](../../guides/recipes/password-reset-support-trace.md)
- [Tracing a notification](../../guides/recipes/tracing-a-notification.md)

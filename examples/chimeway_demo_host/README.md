# Chimeway Demo Host

TeamPulse — a minimal B2B SaaS sandbox for Chimeway consumer journey proof. Maps SEED-004 personas (Feature Developer, Support Operator, Product Manager) with deterministic seeds and admin UI.

## Quick start (5 minutes)

From **repo root**:

```bash
mix deps.get && mix ecto.create && mix ecto.migrate
mix demo.up --serve
```

Open [http://localhost:4001/admin/chimeway](http://localhost:4001/admin/chimeway) and search `user:alex@teampulse.test`.

Or from this directory:

```bash
mix demo.admin
```

## Demo commands

| Command | Where | Purpose |
|---------|-------|---------|
| `mix demo.up` | repo root | Migrate + seed + print admin URL |
| `mix demo.up --serve` | repo root | Above + start Phoenix admin UI |
| `mix demo.up --check` | repo root | CI smoke — migrate + app.start + seed (skips `ecto.create` only), exit 0 |
| `mix demo.seed` | demo host | Idempotent TeamPulse seeds |
| `mix demo.admin` | demo host | Seed + `mix phx.server` |
| `mix demo.trace` | demo host | Quick IEx explainability script |

## TeamPulse scenarios (via `DemoHost.Seeds`)

| Persona | Scenario | Notifier |
|---------|----------|----------|
| Feature Developer | Team invite sent | `DemoHost.Notifiers.InviteSent` |
| Support Operator | Password reset suppressed | `DemoHost.Notifiers.PasswordReset` |
| Product Manager | Payment escalation — READ-driven `:waiting` (inbox read cancels; time fallback to email) | `DemoHost.Notifiers.PaymentReminder` |

See the [Mention escalation recipe](../../guides/recipes/mention-escalation.md) for the read-cancel + time-fallback pattern (JOUR-03/06).

Copy `DemoHost.Seeds` patterns into your app — do not copy internal test fixture helpers from `feedback_pipeline_e2e_test.exs`.

## Storage isolation proof

The demo host uses the isolated Chimeway schema by default:

```elixir
config :chimeway, prefix: "chimeway"
```

The admin trace proof exercises `DemoHost.Seeds` and public Chimeway APIs from trigger to `Chimeway.Traces.explain_delivery/1`, then verifies Chimeway lifecycle rows land under `chimeway.*` instead of public tables.

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

## Webhook progression (separate path)

**TeamPulse Morgan** (persona table above) uses **READ-driven** workflow `:waiting` — see [mention-escalation.md](../../guides/recipes/mention-escalation.md) and JOUR-03/06.

**Webhook-driven progression** is a distinct adoption path — Golden Path webhook appendix and feedback pipeline E2E test.

- For webhook-driven progression, use the [Golden Path webhook appendix](../../guides/introduction/golden-path.md#next-webhook-feedback-loop).
- The [feedback pipeline E2E test](test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs) is an internal test reference for webhook progression — **do not** copy fixture helpers from that file into your app.

## Supplementary: TraceDemo IEx walkthrough

**Primary adoption path:** TeamPulse personas via `mix demo.up` / `DemoHost.Seeds` → admin UI with `user:alex@teampulse.test` (Alex, Sam, Morgan scenarios).

**This section:** minimal single-delivery explainability via `TraceDemo` + `mix demo.trace` — no TeamPulse domain setup required.

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

## Embedded operator console (browser)

The embedded admin console at `/admin/chimeway` is a multi-page operator surface for notification explainability and recovery workflows. It complements the IEx walkthrough above and uses trace data from TeamPulse seeds, `mix demo.trace`, or the IEx trigger section.

```bash
cd examples/chimeway_demo_host
mix phx.server
```

Open [http://localhost:4001/admin/chimeway](http://localhost:4001/admin/chimeway) to start at the Command Center. The console includes:

| Page | Purpose |
|------|---------|
| Command Center | Landing page with Trace Lookup as the primary operator action and secondary paths to Health, Recovery, Definitions, and Feed Debug. |
| Trace Lookup | Search by recipient identity or correlation ID, for example `user:alex@teampulse.test` (TeamPulse seeds) or `user:demo_user_1` (TraceDemo). |
| Trace Detail | Inspect one delivery's unified lifecycle timeline. |
| Feed Debug | Inspect recipient notification lifecycle rows for operator debugging. |
| Definitions | Review DB-inferred durable notification key/version usage, channels, and persisted activity. |
| Health | Review lifecycle outcome totals and recent problem deliveries. |
| Recovery | Inspect eligible recovery candidates before action-bearing follow-up. |

Use Trace Lookup to open a delivery and inspect the unified timeline.

### Production auth

`DemoHost.AdminAuth` always allows access in `:dev` and `:test`. In `:prod` it always returns `{:error, :unauthorized}` — replace with your host's real `ChimewayAdmin.Auth` implementation before exposing admin routes.

### Current admin boundaries

`chimeway_admin` is not generic CRUD over Chimeway tables, not template editing or provider configuration UI, not the end-user inbox product surface, not cohort analytics, and not arbitrary bulk resend/delete recovery.

## Related guides

- [Golden Path](../../guides/introduction/golden-path.md)
- [Password reset support trace](../../guides/recipes/password-reset-support-trace.md)
- [Tracing a notification](../../guides/recipes/tracing-a-notification.md)

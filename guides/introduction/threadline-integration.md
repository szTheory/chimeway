# Threadline Integration

This guide is the canonical adoption path for composing Chimeway with [Threadline](https://github.com/szTheory/threadline) audit telemetry. Threadline integration is **attach-only**: add the optional dependency and attach the reporter in `Application.start/2` — there are no Chimeway migrations to run, no notifier to author, and no host-triggered events. The reporter translates Chimeway notification lifecycle telemetry into Threadline's immutable audit ledger automatically.

## Responsibility split (SEED-003)

**Chimeway orchestrates the when and why:** durable notification lifecycle, suppression and preference gates, idempotency, explainability, and operator traces you can search at `/admin/chimeway`.

**Threadline owns audit ledger:** immutable, append-only event records. Chimeway does not write to Threadline directly — the `Chimeway.Telemetry.ThreadlineReporter` listens to Chimeway lifecycle telemetry and records the outcome as a semantic audit action. Threadline emits and persists the audit row; Chimeway does not mutate Threadline records.

This integration is **not** a `Chimeway.Adapter` delivery seam — it is a `:telemetry` handler bridge only.

## 1. Dependencies

Add Chimeway and Threadline to your host `mix.exs`:

```elixir
def deps do
  [
    {:chimeway, "~> 1.0"},
    threadline_dep()
  ]
end

defp threadline_dep do
  case System.get_env("THREADLINE_PATH") do
    nil -> {:threadline, "~> 0.7", optional: true, runtime: false}
    path -> {:threadline, path: path, optional: true, runtime: false}
  end
end
```

For local development and integration proof, check out the Threadline repo as a sibling and point `THREADLINE_PATH` at it:

```bash
THREADLINE_PATH=../threadline mix deps.get
```

Production adopters use `{:threadline, "~> 0.7", optional: true, runtime: false}` from Hex. Local proof and CI use a sibling checkout pinned to the integration ref documented in `MAINTAINING.md`.

## 2. Attach reporter

Attach the reporter once at boot in your `Application.start/2`:

```elixir
def start(_type, _args) do
  Chimeway.Telemetry.ThreadlineReporter.attach()

  children = [
    # ... your supervision tree
  ]

  Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
end
```

`Chimeway.Telemetry.ThreadlineReporter.attach/0` is idempotent — calling it more than once is safe. Then configure the reporter with the Threadline repo and the actor that owns the audit rows:

```elixir
config :chimeway, :threadline_reporter,
  repo: MyApp.Threadline.Repo,
  actor: Threadline.Semantics.ActorRef.new(:system, "chimeway")
```

Only `:repo` and `:actor` are required. No per-notification host callbacks are needed — the reporter derives everything from Chimeway lifecycle telemetry.

## 3. What gets recorded

The reporter listens to Chimeway notification lifecycle telemetry and records one Threadline audit action per terminal outcome:

| Lifecycle outcome | Threadline action atom | `correlation_id` |
|-------------------|------------------------|------------------|
| Notification suppressed | `:notification_suppressed` | forwarded from Chimeway trigger opts |
| Notification deferred | `:notification_deferred` | forwarded from Chimeway trigger opts |
| Notification dispatched | `:notification_dispatched` | forwarded from Chimeway trigger opts |
| Notification failed | `:notification_failed` | forwarded from Chimeway trigger opts |

Each audit action carries only deterministic outcome metadata (the outcome reason and a bounded summary) — never payload bodies, email contents, templates, or provider responses.

> Pass `correlation_id:` in `Chimeway.trigger/3` opts to thread the audit row through to `Threadline.Query.timeline/2` strict filter. Without it, the Threadline timeline cannot isolate this notification's lifecycle in a multi-event trace.

## 4. Verification

Seed the demo host Threadline scenario to exercise the bridge end-to-end:

```elixir
DemoHost.Seeds.seed_threadline_notification/0
```

Then run the named proof command:

```bash
THREADLINE_PATH=../threadline mix verify.threadline
```

This exercises the Chimeway-root lifecycle proof and the demo host telemetry proof. After seeding, search `/admin/chimeway` for the notification's operator trace and confirm the matching Threadline audit row is linked by `correlation_id`.

## Related guides

- [Golden Path](golden-path.md) — Chimeway-only first integration
- [Mailglass integration blueprint](../recipes/mailglass-integration-blueprint.md) — optional email delivery for notification steps
- [Installation](installation.md) — Chimeway install and migration depth

# Chimeway

Chimeway is a local-first, explainable, durable notification library for Elixir. It runs
inside your application and your database — there is no external notification SaaS to trust
or route your recipient data through. Every notification decision is traceable — teams can
reliably answer why a notification sent, failed, or was suppressed.

[![Hex.pm](https://img.shields.io/hexpm/v/chimeway.svg)](https://hex.pm/packages/chimeway)
[![CI](https://github.com/szTheory/chimeway/actions/workflows/ci.yml/badge.svg)](https://github.com/szTheory/chimeway/actions/workflows/ci.yml)

## When to use

Reach for Chimeway when you want embedded, local-first notifications with an auditable trace:

- You need to explain *why* a specific notification sent, failed, or was suppressed — for
  support operators, product managers, or compliance.
- You want notification state (events, notifications, deliveries, attempts) to live in your
  own Postgres, not a third-party service.
- You want idempotent, tenant-scoped triggers with a durable lifecycle spine.
- You want in-app inbox and multi-channel dispatch that you own end to end.

## Non-goals

Chimeway is intentionally not:

- A hosted notification SaaS or message broker — it is a library embedded in your app.
- A replacement for your email/SMS/push provider — it orchestrates and explains delivery,
  while a channel adapter (for example Mailglass) does the actual sending.
- A general-purpose job queue — it uses durable persistence for the notification lifecycle,
  not for arbitrary background work.
- A CRM or contact-management system — the host owns recipient records and identity.

## Host-owned boundaries

Your application owns the surfaces at the trust boundary; Chimeway never assumes them:

- **Recipient records and contact resolution** — the host resolves who receives a
  notification and passes recipients in.
- **The database and migrations** — Chimeway generates migrations, but the host runs them
  against a repo the host configures.
- **Authentication and authorization** — the host decides who may trigger notifications or
  read traces.
- **Channel credentials and provider config** — the host wires channel adapters and secrets.

## Optional surfaces

Two sibling packages extend Chimeway but are optional and ship in this repository as an
in-repo preview/path package — each is not published on Hex yet:

- **chimeway_admin** — a browser UI for the Support Operator trace-lookup flow.
- **chimeway_inbox** — a mountable in-app inbox surface.

Add them via a `path:` dependency from this repo when you want to preview them; they are not
current Hex installs.

## Installation

Add `chimeway` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:chimeway, "~> 1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
mix chimeway.gen.migrations
mix ecto.migrate
```

Choose the runtime storage prefix before starting Chimeway. New installs should
use the new isolated Chimeway schema:

```elixir
config :chimeway, prefix: "chimeway"
```

Use `prefix: false` only for an existing public-schema legacy install whose
Chimeway tables already live in public:

```elixir
config :chimeway, prefix: false
```

That legacy mode keeps using the existing unprefixed tables and does not move data.

## Quick Start

Follow the [Golden Path guide](guides/introduction/golden-path.md) for install, notifier setup, and your first explainable trace.

```elixir
Chimeway.trigger(MyApp.Notifiers.WelcomeUser, %{user_id: "u1", name: "Ada"},
  idempotency_key: "welcome-u1",
  tenant_id: "default"
)
```

## Trigger to explainable trace

The canonical path is: define a notifier with a stable key, trigger it, then explain the
delivery. Every snippet below uses the real public API.

**1. Define a notifier — the stable key is the `notification_key/0` return value (with `version/0`):**

```elixir
defmodule MyApp.Notifiers.WelcomeUser do
  use Chimeway.Notifier

  @impl true
  def notification_key, do: "welcome_user"

  @impl true
  def version, do: 1
end
```

**2. Configure the runtime storage prefix:**

```elixir
config :chimeway, prefix: "chimeway"
```

**3. Trigger — both `tenant_id` and `idempotency_key` are always required:**

```elixir
{:ok, result} =
  Chimeway.trigger(MyApp.Notifiers.WelcomeUser, %{user_id: "user_12345"},
    idempotency_key: "signup_user_12345",
    tenant_id: "default"
  )
```

**4. Explain the delivery — look up why it sent, failed, or was suppressed:**

```elixir
[delivery_id | _] = result.trace.delivery_ids
{:ok, explanation} = Chimeway.Traces.explain_delivery(delivery_id)
```

`Chimeway.Traces.explain_delivery/1` returns the delivery status, any suppression reason, and
the full timeline — the answer to "why did (or didn't) this notification go out?"

## Documentation

- [Golden Path Guide](guides/introduction/golden-path.md)
- [Storage Prefix Upgrade Guide](guides/introduction/storage-prefix-upgrade.md)
- [Mailglass Integration Guide](guides/introduction/mailglass-integration.md)
- [Accrue Dunning Integration Guide](guides/introduction/accrue-dunning-integration.md)
- [Inbox Integration Guide](guides/introduction/inbox-integration.md)
- [Hex Docs](https://hexdocs.pm/chimeway)
- [Installation Guide](guides/introduction/installation.md)
- [Getting Started Guide](guides/introduction/getting-started.md)
- [Cheat Sheet](guides/cheatsheet.cheatmd)

## License

MIT — see [LICENSE.md](LICENSE.md).

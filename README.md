# Chimeway

Chimeway is an explainable, durable notification library for Elixir. Every notification decision is traceable — teams can reliably answer why a notification sent, failed, or was suppressed.

[![Hex.pm](https://img.shields.io/hexpm/v/chimeway.svg)](https://hex.pm/packages/chimeway)
[![CI](https://github.com/jonlunsford/chimeway/actions/workflows/ci.yml/badge.svg)](https://github.com/jonlunsford/chimeway/actions/workflows/ci.yml)

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

## Quick Start

Follow the [Golden Path guide](guides/introduction/golden-path.md) for install, notifier setup, and your first explainable trace.

```elixir
Chimeway.trigger(MyApp.Notifiers.WelcomeUser, %{user_id: "u1", name: "Ada"},
  idempotency_key: "welcome-u1",
  tenant_id: "default"
)
```

## Documentation

- [Golden Path Guide](guides/introduction/golden-path.md)
- [Mailglass Integration Guide](guides/introduction/mailglass-integration.md)
- [Accrue Dunning Integration Guide](guides/introduction/accrue-dunning-integration.md)
- [Hex Docs](https://hexdocs.pm/chimeway)
- [Installation Guide](guides/introduction/installation.md)
- [Getting Started Guide](guides/introduction/getting-started.md)
- [Trigger to Delivery Flow](guides/flows/trigger-to-delivery.md)
- [Cheat Sheet](guides/cheatsheet.cheatmd)

## License

MIT — see [LICENSE.md](LICENSE.md).

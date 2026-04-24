# Chimeway

Chimeway is an explainable, durable notification library for Elixir. Every notification decision is traceable — teams can reliably answer why a notification sent, failed, or was suppressed.

[![Hex.pm](https://img.shields.io/hexpm/v/chimeway.svg)](https://hex.pm/packages/chimeway)
[![CI](https://github.com/jonlunsford/chimeway/actions/workflows/ci.yml/badge.svg)](https://github.com/jonlunsford/chimeway/actions/workflows/ci.yml)

## Installation

Add `chimeway` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:chimeway, "~> 0.1"}
  ]
end
```

Then run:

```bash
mix deps.get
mix ecto.migrate
```

## Quick Start

Define a notifier:

```elixir
defmodule MyApp.OrderShippedNotifier do
  use Chimeway.Notifier,
    notification_key: "order_shipped",
    version: 1

  @impl true
  def resolve_recipients(%{user_id: user_id}, _opts) do
    {:ok, [%{identity: "user:#{user_id}", type: "user"}]}
  end
end
```

Trigger a notification:

```elixir
Chimeway.trigger(
  MyApp.OrderShippedNotifier,
  %{order_id: "ord-123", user_id: 42},
  idempotency_key: "order-shipped-ord-123"
)
# => {:ok, %{event: %Chimeway.Events.Event{}, notifications: [...]}}
```

## Documentation

- [Hex Docs](https://hexdocs.pm/chimeway)
- [Getting Started Guide](guides/introduction/getting-started.md)
- [Trigger to Delivery Flow](guides/flows/trigger-to-delivery.md)
- [Cheat Sheet](guides/cheatsheet.cheatmd)

## License

MIT — see [LICENSE.md](LICENSE.md).

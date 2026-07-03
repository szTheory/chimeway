# Getting Started

Chimeway is an explainable, durable notification library for Elixir. This guide walks you through defining your first notifier, triggering a notification event, and reading the recipient inbox — from zero to working notifications in minutes.

## 1. Define a Notifier

A Notifier in Chimeway encapsulates the logic for a specific notification event. It defines the payload required to render the notification.

Create a new file in your project, for example `lib/my_app/notifiers/welcome_user.ex`:

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
  def channels(_params, _recipient) do
    {:ok, [:in_app]}
  end

  @impl true
  def build(params, _recipient) do
    name = Map.get(params, :name, "User")

    {:ok, %{
      subject: "Welcome to our app, #{name}!",
      body: "We are so glad you joined us."
    }}
  end
end
```

## 2. Trigger a Notification

With your notifier defined, you can now trigger notifications anywhere in your application (e.g., after a user signs up).

Use `Chimeway.trigger/3` to dispatch the notification. Because Chimeway requires idempotency to ensure explainability, you must pass an `:idempotency_key`:

```elixir
params = %{user_id: "user_12345", name: "Alice"}

{:ok, trigger_result} =
  Chimeway.trigger(
    MyApp.Notifiers.WelcomeUser,
    params,
    idempotency_key: "signup_user_12345",
    tenant_id: "default"
  )
```

Both `:idempotency_key` and `:tenant_id` are required.

## 3. Check the Inbox

Because we used the `:in_app` channel (the default), the notification is durably stored and accessible as an in-app message. You can fetch notifications for a recipient using the `Chimeway` module.

```elixir
recipient = "user_12345"

# Fetch notifications
inbox_items = Chimeway.list_for_recipient(recipient)

case inbox_items do
  [first_item | _rest] ->
    IO.puts("Message: #{first_item.metadata["subject"]}")
  [] ->
    IO.puts("No messages.")
end
```

When a user reads the message, you can mark it as read:

```elixir
# Assuming `first_item` is an inbox item fetched above
{:ok, updated_item} = Chimeway.mark_read(first_item.id, recipient)
```

## What's Next?

If you haven't yet, start with the [Golden Path](golden-path.md) for the canonical install-to-trace vertical slice including `Chimeway.Traces.explain_delivery/1`.

You have successfully defined, triggered, and retrieved a Chimeway notification.

To explore further, you might want to look into:
- [Tracing a Notification](../recipes/tracing-a-notification.md) for explainability and telemetry depth
- Configuring more complex [Channel Adapters](../recipes/custom-adapter.md)
- Setting up Policies and Preferences to respect user communication limits
- Understanding the full Trigger to Delivery Lifecycle
# Integrating Oban for Reliable Async Dispatch

By default, Chimeway uses a synchronous dispatcher that attempts to deliver notifications immediately when they are triggered. For production environments, it is highly recommended to process these deliveries asynchronously in the background.

Chimeway provides native integration with [Oban](https://getoban.pro/), the leading background job system for Elixir.

## Prerequisites

1. Add Oban to your project if you haven't already:
   ```elixir
   defp deps do
     [
       {:oban, "~> 2.17"}
     ]
   end
   ```
2. Configure Oban in your application (see [Oban's installation guide](https://hexdocs.pm/oban/installation.html) for full details).

## Configuring Chimeway for Oban

To tell Chimeway to use Oban for async dispatch, update your application configuration:

```elixir
# config/config.exs
config :chimeway,
  dispatcher: Chimeway.Dispatch.Oban
```

When you use the `Chimeway.Dispatch.Oban` dispatcher, Chimeway will automatically convert delivery plans into Oban jobs instead of executing them synchronously.

## Setting Up the Queue

Chimeway's Oban dispatcher enqueues jobs into a specific queue named `chimeway_delivery`. You must configure your Oban instance to process this queue.

Update your Oban configuration to include the `chimeway_delivery` queue:

```elixir
# config/config.exs
config :my_app, Oban,
  repo: MyApp.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [
    default: 10,
    chimeway_delivery: [limit: 20] # Add this line
  ]
```

## Transactional Enqueueing for Consistency

One of the major benefits of using Oban with Chimeway is transactional consistency. Because both Chimeway and Oban use Ecto and Postgres, you can guarantee that if a transaction commits, the notification will be enqueued, and if it rolls back, the notification won't be sent.

When triggering notifications, you can pass an `Ecto.Multi` struct to the `trigger` options. Chimeway will insert the delivery records and enqueue the Oban jobs within the same database transaction.

```elixir
alias Ecto.Multi
alias MyApp.Repo

# Start a multi transaction
Multi.new()
# ... do your application work (e.g., create a user) ...
|> Multi.insert(:user, %MyApp.User{name: "Alice", email: "alice@example.com"})
# Pass the multi to Chimeway
|> Multi.run(:notification, fn repo, %{user: user} ->
  WelcomeNotifier.trigger(
    user.id,
    %{name: user.name},
    # Ensure deliveries are saved and enqueued inside the Multi
    multi: multi
  )
  # When using the multi option, trigger/3 returns {:ok, multi}
end)
|> Repo.transaction()
```

If the transaction succeeds, all deliveries are guaranteed to be in the `chimeway_delivery` queue, ready for async processing by Oban. If the transaction fails, no jobs are enqueued.

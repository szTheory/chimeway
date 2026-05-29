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

## Setting Up the Queues and Workers

Chimeway uses several queues to handle different background tasks. Update your Oban configuration to include these queues:

```elixir
# config/config.exs
config :my_app, Oban,
  repo: MyApp.Repo,
  plugins: [
    Oban.Plugins.Pruner
    # Optional fallback: sweep past-due wait_until runs if a scheduled job was missed.
    # Primary wait advancement uses per-run jobs scheduled at due_at (see below).
    # {Oban.Plugins.Cron,
    #  crontab: [
    #    {"* * * * *", Chimeway.Dispatch.WorkflowProgressionWorker}
    #  ]}
  ],
  queues: [
    default: 10,
    chimeway_delivery: [limit: 20],   # Async dispatch, WorkflowProgressionWorker, webhook feedback
    chimeway_signals: [limit: 10]     # Chimeway.Dispatch.SignalRouterWorker
    # No Chimeway worker uses :chimeway_workflows; omit unless you have host-specific jobs.
  ]
```

### Wait advancement scheduling

When `dispatcher: Chimeway.Dispatch.Oban` is configured, the engine **automatically enqueues** `Chimeway.Dispatch.WorkflowProgressionWorker` on the `:chimeway_delivery` queue at each waiting run's `due_at`. This is the **primary** model for `wait_until` progression — one scheduled job per run, not a global cron sweep.

Optional cron calling `Chimeway.Workflows.Progression.progress_due_runs/1` (via a thin host wrapper or direct engine call) is a **fallback** for missed schedules or non-Oban recovery — not the primary path. Do not rely on cron alone for wait gates.

### Workflow Engine Workers

If you are using Chimeway's Workflow Engine for multi-step journeys (like wait gates and escalations), you need to configure Oban to process two specific workers:

1.  **`Chimeway.Workflows.Workers.ProgressionWorker`**: This worker is responsible for evaluating wait gates. When a workflow enters a wait step, it pauses. The `ProgressionWorker` must be scheduled to run periodically (e.g., every minute using `Oban.Plugins.Cron` as shown above) to check for expired wait steps and resume progression.
2.  **`Chimeway.Workflows.Workers.SignalRouterWorker`**: When your application emits signals (e.g., "user viewed notification") via `Chimeway.Signal.track/4`, the engine enqueues a job for the `SignalRouterWorker`. This worker processes the signal in the background (using the `chimeway_signals` queue) to see if it satisfies any active stop conditions, preventing slow web requests when tracking user feedback.

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

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
    #    # Cron fallback must call progress_due_runs/1 — WorkflowProgressionWorker alone is not valid here.
    #    {"* * * * *", MyApp.ChimewayCron, args: %{"op" => "progress_due_runs"}}
    #    # MyApp.ChimewayCron.perform/1 should invoke Chimeway.Workflows.Progression.progress_due_runs/1
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

If you are using Chimeway's workflow engine for multi-step journeys (like `wait_until` gates and channel escalations), Oban processes two dispatch workers:

1. **`Chimeway.Dispatch.WorkflowProgressionWorker`** (`:chimeway_delivery` queue) — Evaluates past-due `wait_until` rules via `Chimeway.Workflows.Progression.progress_run/2`. When `dispatcher: Chimeway.Dispatch.Oban` is configured, the engine schedules one job per waiting run at that run's `due_at` (see [Wait advancement scheduling](#wait-advancement-scheduling) above). This is the primary path for time-based escalation.

2. **`Chimeway.Dispatch.SignalRouterWorker`** (`:chimeway_signals` queue) — Processes `Chimeway.Signal.track/4` events asynchronously. Calls `Chimeway.Workflows.route_signal/1` to match `:waiting` runs whose `pending_signals` list contains the signal's `event_name`. It routes signals to waiting runs; progression rules (`on_outcome` / `stop`) apply separately when delivery outcomes converge on active steps.

## Transactional Enqueueing for Consistency

Oban and Chimeway both use Ecto and Postgres, so you can align host writes, notification rows, and Oban jobs with explicit transaction boundaries. Two patterns cover the common cases:

### Two separate transactions

`Chimeway.trigger/3` always commits event and notification rows in its **own** `Repo.transaction/1` before calling the configured dispatcher. Pass a `:multi` option to `Chimeway.trigger/3` is unsupported — use Pattern B below when you need shared transactions. Trigger does **not** return an updated `Ecto.Multi` struct.

### Pattern A — host writes, then notify (recommended)

Commit your host `Ecto.Multi` first, then call `Chimeway.trigger/3` after `Repo.transaction/1` succeeds:

```elixir
alias Ecto.Multi
alias MyApp.Repo

with {:ok, %{user: user}} <-
       Multi.new()
       |> Multi.insert(:user, %MyApp.User{name: "Alice", email: "alice@example.com"})
       |> Repo.transaction(),
     {:ok, _result} <-
       Chimeway.trigger(
         WelcomeNotifier,
         %{name: user.name, email: user.email},
         idempotency_key: "welcome-#{user.id}",
         tenant_id: user.tenant_id
       ) do
  :ok
end
```

If the host transaction rolls back, no user row exists and `Chimeway.trigger/3` is never called. If the host transaction commits but trigger fails, you have a user without a notification — handle that in your `with`/`else` branch.

### Pattern B — atomic delivery planning + Oban job insert

When notification rows already exist and you need dispatch jobs in the **same** database transaction as other host writes, call the Oban dispatcher directly with `multi:`:

```elixir
alias Chimeway.Dispatch.Oban
alias Chimeway.Repo
alias Ecto.Multi

multi =
  Multi.new()
  |> Multi.run(:host_work, fn _repo, _ -> {:ok, :done} end)

# notifications must already be persisted (e.g. from a prior trigger)
assert {:ok, _deliveries} = Oban.dispatch([notification], multi: multi)
assert {:ok, _} = Repo.transaction(multi)
```

If the transaction succeeds, delivery rows and Oban jobs commit together. If it rolls back, neither persists. See `test/chimeway/dispatch/oban_transactional_test.exs` for commit and rollback proofs.

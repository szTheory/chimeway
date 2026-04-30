# Multi-Step Journeys

Chimeway's workflow engine allows you to build multi-step user journeys that coordinate across multiple channels over time. A common SaaS use case is attempting a less intrusive channel first (like in-app notifications), waiting for the user to engage, and escalating to a higher-friction channel (like email) if they haven't seen it.

This guide walks through creating an escalation journey using Wait Gates and Stop Conditions.

## Scenario: The Missed Mention Escalation

When someone is mentioned in a document, we want to:
1. Deliver an `in_app` notification immediately.
2. Wait up to 2 hours for them to see it.
3. If they haven't seen it (a specific signal hasn't been received), escalate to an `email`.
4. If they *do* see it, stop the workflow and do not send the email.

## 1. Defining the Workflow

Workflows are defined by implementing the `Chimeway.Workflow` behavior or simply passing a structured workflow map when triggering.

```elixir
defmodule MyApp.Workflows.MentionEscalation do
  @behaviour Chimeway.Workflow

  @impl true
  def workflow(_args) do
    %{
      key: "mention_escalation",
      version: 1,
      steps: [
        %{
          id: "step_in_app",
          action: %{
            type: :notify,
            channel: :in_app,
            render_key: "mention_notification"
          }
        },
        %{
          id: "step_wait_for_read",
          action: %{
            type: :wait,
            duration: "PT2H", # Wait 2 hours (ISO 8601 duration)
            stop_conditions: [
              %{
                type: :signal_received,
                signal_type: "notification_read"
              }
            ]
          }
        },
        %{
          id: "step_email_escalation",
          action: %{
            type: :notify,
            channel: :email,
            render_key: "mention_email"
          }
        }
      ]
    }
  end
end
```

### Understanding Stop Conditions
The `stop_conditions` on the wait step act as early-exit rules. 
- If the 2 hours elapse without the condition being met, the workflow proceeds to `step_email_escalation`.
- If a signal of type `notification_read` for this workflow is received *before* the 2 hours elapse, the wait step terminates, its stop condition is evaluated, and because it is an early exit, you can configure it to cancel the remainder of the workflow (the default behavior for a fulfilled terminal condition).

## 2. Triggering the Workflow

When the mention happens, trigger the workflow via `Chimeway.Trigger`:

```elixir
Chimeway.Trigger.trigger(
  MyApp.Workflows.MentionEscalation,
  %{
    actor_id: "user_123",
    tenant_id: "org_456",
    document_id: "doc_789"
  },
  tenant_id: "org_456"
)
```

## 3. Emitting Signals

When the user opens the application and views their inbox, your application can emit a signal to inform Chimeway:

```elixir
# In your Phoenix controller or LiveView when the user views notifications
Chimeway.Signal.track(
  "user_123",
  "org_456",
  "notification_read",
  %{document_id: "doc_789"}
)
```

Chimeway will route this signal to active workflow runs for `user_123` in `org_456`. If it matches the wait step's condition, the workflow will mark the condition as met and halt progression, preventing the email escalation.

## Execution Models

### Synchronous (Test/Dev)
In `config/dev.exs` or `config/test.exs`, you might use the inline dispatcher. Progression through steps (especially for non-waiting steps) happens in-process.

### Oban-Backed (Production)
For production wait gates and time-based progression, you must configure Chimeway to use the Oban dispatcher. 

When a `wait` step is reached, the engine pauses progression. A background worker (`Chimeway.Workflows.Workers.ProgressionWorker`) evaluates active wait steps periodically to determine if their duration has expired.

Similarly, signal routing happens in the background via `Chimeway.Workflows.Workers.SignalRouterWorker` to ensure your web requests remain fast when emitting feedback.

See the [Oban Integration](../recipes/oban-integration.md) recipe for configuration details.
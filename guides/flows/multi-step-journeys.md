# Multi-Step Journeys

Chimeway workflows coordinate multi-channel notification journeys over time. You author them by implementing the optional `workflow/2` callback on a Notifier module (`use Chimeway.Notifier`) — not a standalone workflow behaviour module. Progress rules live on each channel step's `config["progress"]` array and drive time-based escalation, outcome branching, and early termination.

## Scenario: Missed Engagement Escalation

When a user is mentioned in a document, deliver an `in_app` notification first. If they do not engage within two hours, escalate to `email`. The primary mechanism is a `wait_until` progress rule on the in-app step — not inbox-read cancellation or separate wait steps.

## 1. Define the Notifier with a Workflow

Implement `workflow/2` on your notifier module. It returns `{:ok, %{workflow_key:, workflow_version:, steps: [...]}}`:

```elixir
defmodule MyApp.Notifiers.MentionEscalation do
  use Chimeway.Notifier

  @impl true
  def notification_key, do: "mention_escalation"

  @impl true
  def version, do: 1

  @impl true
  def recipients(params) do
    {:ok, [%{recipient_identity: params.user_id, recipient_type: "user"}]}
  end

  @impl true
  def build(_params, _recipient) do
    {:ok, %{title: "You were mentioned", body: "See the document."}}
  end

  @impl true
  def channels(_params, _recipient), do: {:ok, [:in_app, :email]}

  @impl true
  def workflow(_params, _recipient) do
    {:ok,
     %{
       workflow_key: "mention_escalation",
       workflow_version: 1,
       steps: [
         %{
           step_key: "in_app",
           step_order: 1,
           channel: :in_app,
           config: %{
             "progress" => [
               %{
                 "kind" => "wait_until",
                 "anchor" => "prior_delivery_terminal_at",
                 "delay_seconds" => 7200,
                 "to_step" => "email"
               }
             ]
           }
         },
         %{
           step_key: "email",
           step_order: 2,
           channel: :email,
           config: %{}
         }
       ]
     }}
  end
end
```

Each step uses `step_key`, `step_order`, `channel`, and optional `config`. The `wait_until` rule anchors on `prior_delivery_terminal_at` (when the prior step's delivery reaches a terminal state) and waits `delay_seconds` before advancing to `to_step`.

## 2. Progress Rules

Progress rules are declared in `config["progress"]` on a channel step. Chimeway supports three rule kinds only:

| Kind | Required keys | Behavior |
|------|---------------|----------|
| `wait_until` | `anchor`, `delay_seconds`, `to_step` | After the step's delivery converges, the run enters `:waiting` until `due_at`, then advances to `to_step` |
| `on_outcome` | `outcome`, `to_step` | When a delivery outcome matches, advance to `to_step` |
| `stop` | `outcome` | When a delivery outcome matches, stop the run |

There are no separate wait steps, signal-based stop DSL, ISO 8601 duration strings, or standalone wait actions — time gates are always `wait_until` rules on a channel step with integer `delay_seconds`.

### Outcome vocabulary

Rules reference delivery outcomes normalized by the engine:

`delivered`, `suppressed`, `temporary_failure`, `retries_exhausted`, `permanent_failure`, `bounced`

Example combining `on_outcome` and `stop` on the same step:

```elixir
"progress" => [
  %{"kind" => "on_outcome", "outcome" => "bounced", "to_step" => "email"},
  %{"kind" => "stop", "outcome" => "suppressed"}
]
```

### WR-02: `temporary_failure` fires early

`temporary_failure` resolves from the first `:failed` delivery row — before Oban retries complete. If you intend to branch only after retries are exhausted, use `retries_exhausted` instead. See the `Chimeway.Notifier` moduledoc for the full early-fire warning and idempotency guidance when pairing early escalation with retrying primary deliveries.

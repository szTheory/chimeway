# Mention Escalation

## Who this is for

**Product Manager:** Your JTBD is "if they don't open in 2 hours, send email" — escalate when a user misses an in-app notice, with inbox read as an early-exit path.

**Feature Developer:** You author a notifier `workflow/2` with a `wait_until` progress rule and `cancel_signals` so inbox read cancels the wait before the time gate fires.

## Not this path

Delivery-feedback / webhook escalation — "if the provider says delivered, resume" — is documented in [Feedback escalation workflow](feedback-escalation-workflow.md). That path is provider-driven via webhook ingress; this recipe covers inbox-read early exit instead.

## Prerequisites

- [Multi-step journeys](../flows/multi-step-journeys.md) — `wait_until`, `cancel_signals`, and inbox lifecycle
- [Golden Path](../introduction/golden-path.md) — install, migrations, and your first `Chimeway.trigger/3`

## Feature Developer: notifier with wait_until + cancel_signals

Workflows are declared via the optional `workflow/2` callback on a `Chimeway.Notifier` module:

```elixir
defmodule MyApp.Notifiers.PaymentReminder do
  use Chimeway.Notifier

  @impl true
  def workflow(_params, _recipient) do
    {:ok,
     %{
       workflow_key: "payment_reminder",
       workflow_version: 1,
       steps: [
         %{
           step_key: "initial_notice",
           step_order: 1,
           channel: :in_app,
           config: %{
             "progress" => [
               %{
                 "kind" => "wait_until",
                 "anchor" => "prior_delivery_terminal_at",
                 "delay_seconds" => 7200,
                 "to_step" => "email_escalation",
                 "cancel_signals" => ["chimeway.notification.read"]
               }
             ]
           }
         },
         %{
           step_key: "email_escalation",
           step_order: 2,
           channel: :email,
           config: %{}
         }
       ]
     }}
  end
end
```

Runnable TeamPulse reference: `DemoHost.Notifiers.PaymentReminder` in the demo host.

## Trigger

```elixir
Chimeway.trigger(
  MyApp.Notifiers.PaymentReminder,
  %{email: "user@example.com", invoice_id: "INV-1001"},
  idempotency_key: "payment-reminder-inv-1001",
  tenant_id: "org_456"
)
```

Both `:idempotency_key` and `:tenant_id` are required.

## READ-driven early exit

When the user opens the in-app notice, the host calls the public inbox API:

```elixir
Chimeway.mark_read(notification_id, recipient_identity)
```

Chimeway emits a durable `chimeway.notification.read` signal. `SignalRouterWorker` drains the job and calls `Chimeway.Workflows.route_signal/1`, which matches the waiting run's `pending_signals`. The run resumes with a `signal_received` transition whose context carries `event_name` only — do **not** call `Chimeway.Signal.track/4` after `mark_read`.

## Time fallback

If the user never reads the notification, `WorkflowProgressionWorker` advances the run at `due_at` to the `to_step` email channel. See [Oban integration](oban-integration.md) for dispatcher and queue configuration.

Automated proof that email fires only when unread is JOUR-06 (Phase 51) — this recipe documents the pattern; read-cancel does not halt the scheduled worker in Phase 50.

## Runnable proof

- `DemoHost.Seeds.escalation_waiting!/0` — trigger-only seed for Morgan's payment reminder
- JOUR-03 in `examples/chimeway_demo_host/test/demo_host_web/journey_test.exs` — seed → `:waiting` with `pending_signals` → `Chimeway.mark_read/3` → signal → `:active`

## Related guides

- [Multi-step journeys](../flows/multi-step-journeys.md) — full workflow authoring reference
- [Feedback escalation workflow](feedback-escalation-workflow.md) — webhook / delivery-feedback path
- [Oban integration](oban-integration.md) — async dispatch and worker queues

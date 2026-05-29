# Feedback Escalation Workflow

## Who this is for

**Product Manager:** You need to see how outbound delivery feedback drives workflow progression — "if the provider says delivered, resume; if bounced, stop" — with proof on the delivery trace timeline.

**Feature Developer:** You author a notifier with an optional `workflow/2` callback and wire webhook ingress so provider feedback becomes durable signals.

## Prerequisites

- [Multi-step journeys](../flows/multi-step-journeys.md) — full `workflow/2` authoring with progress rule kinds
- [Golden Path](../introduction/golden-path.md) — trigger baseline and [webhook feedback loop](../introduction/golden-path.md#next-webhook-feedback-loop) appendix

## Feature Developer: notifier with workflow

Workflows are declared via the optional `workflow/2` callback on a `Chimeway.Notifier` module — not a separate workflow behaviour module.

Minimal envelope shape (progress arrays abbreviated — see the journey guide for full rules):

```elixir
{:ok, %{
  workflow_key: "mention_escalation",
  workflow_version: 1,
  steps: [
    %{step_key: "in_app", step_order: 1, channel: "in_app", config: %{"progress" => [...]}},
    %{step_key: "email", step_order: 2, channel: "email", config: %{"progress" => [...]}}
  ]
}}
```

Progress rule kinds include `wait_until`, `on_outcome`, and `stop`. See [Multi-step journeys](../flows/multi-step-journeys.md) for `on_outcome` outcome vocabulary and full mention-escalation example.

Trigger the notifier:

```elixir
Chimeway.trigger(
  MyApp.Notifiers.MentionEscalation,
  %{actor_id: "user:42", mention_id: "mention-99"},
  idempotency_key: "mention-99-escalation",
  tenant_id: "org_456"
)
```

## End-to-end feedback loop

1. Host triggers notifier → delivery planned and dispatched  
2. Adapter sends (or simulates) outbound delivery  
3. Provider POSTs webhook to a host route (demo host uses `/webhooks/chimeway/echo` — configure your own ingress, do not copy a full controller here)  
4. `Chimeway.Webhooks.ProcessFeedbackWorker` normalizes feedback and records attempts  
5. Worker emits `Chimeway.Signal.track(tenant_id, actor_id, "chimeway.delivery.succeeded", %{...})` — **argument order is tenant, actor, event name, payload**  
6. `Chimeway.Dispatch.SignalRouterWorker` drains the signal job → `Chimeway.Workflows.route_signal/1` matches waiting runs  
7. `Chimeway.Traces.explain_delivery/1` shows `:webhook_received` and/or workflow stop/resume events on the timeline  

Canonical delivery signal event names: `chimeway.delivery.succeeded`, `chimeway.delivery.bounced`, `chimeway.delivery.failed`.

## Progress path: delivered signal resumes the run

When the provider reports success:

1. `ProcessFeedbackWorker` writes a `:succeeded` attempt and tracks `chimeway.delivery.succeeded`.  
2. `SignalRouterWorker` routes the signal; a `:waiting` run whose `pending_signals` includes that event resumes to `:active`.  
3. The trace timeline includes `:webhook_received` with `detail.signal_event_name == "chimeway.delivery.succeeded"`.

This matches the demo host progress describe block in the E2E test.

## Stop path: bounced signal stops the workflow

When the provider reports a bounce:

1. `ProcessFeedbackWorker` records a `:bounced` attempt and tracks `chimeway.delivery.bounced`.  
2. Progression evaluates a `stop` rule and sets the workflow run to `:stopped`.  
3. The trace timeline includes `:webhook_received` and `:workflow_stopped` for the same delivery.

On the stop path the run is already `:stopped` before signal routing completes — that is expected.

## Inspecting progression in the trace

```elixir
{:ok, %{timeline: timeline}} = Chimeway.Traces.explain_delivery(delivery_id)
Enum.map(timeline, & &1.event)
```

Look for `:webhook_received`, signal-driven resume (run returns to `:active`), or `:workflow_stopped` depending on feedback outcome.

## Runnable proof in the repo

- [Feedback pipeline E2E test](https://github.com/jonlunsford/chimeway/blob/main/examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs) — progress and stop describe blocks with real webhook POST + Oban drain  
- [Golden path webhook appendix](../introduction/golden-path.md#next-webhook-feedback-loop) — outcome summary and links

## Related guides

- [Multi-step journeys](../flows/multi-step-journeys.md) — workflow authoring reference  
- [Mention escalation](mention-escalation.md) — inbox-read / PM JTBD path (not delivery-feedback webhooks)
- [Golden Path](../introduction/golden-path.md) — first trigger and webhook loop  
- [Tracing a Notification](tracing-a-notification.md) — telemetry and correlation depth

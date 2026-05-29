# Multi-Step Journeys

Chimeway workflows coordinate multi-channel notification journeys over time. You author them by implementing the optional `workflow/2` callback on a Notifier module (`use Chimeway.Notifier`) — not a standalone workflow behaviour module. Progress rules live on each channel step's `config["progress"]` array and drive time-based escalation, outcome branching, and early termination.

## Scenario: Missed Engagement Escalation

When a user is mentioned in a document, deliver an `in_app` notification first. If they do not engage within two hours, escalate to `email`. Use a `wait_until` progress rule on the in-app step as the time gate, and declare `cancel_signals` with inbox read (`Chimeway.mark_read/3` → `chimeway.notification.read`) for complementary early exit — the two mechanisms work together, not as mutually exclusive alternatives.

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
                 "to_step" => "email",
                 "cancel_signals" => [
                   "chimeway.notification.read",
                   "chimeway.notification.seen"
                 ]
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

Each step uses `step_key`, `step_order`, `channel`, and optional `config`. The `wait_until` rule anchors on `prior_delivery_terminal_at` (when the prior step's delivery reaches a terminal state) and waits `delay_seconds` before advancing to `to_step`. Declare `cancel_signals` explicitly when you want signal-driven early exit; time-only waits omit the key.

## 2. Progress Rules

Progress rules are declared in `config["progress"]` on a channel step. Chimeway supports three rule kinds only:

| Kind | Required keys | Optional keys | Behavior |
|------|---------------|---------------|----------|
| `wait_until` | `anchor`, `delay_seconds`, `to_step` | `cancel_signals` (array of non-empty event-name strings) | After the step's delivery converges, the run enters `:waiting` until `due_at`, then advances to `to_step`. When `cancel_signals` is present, the engine copies the list into `run.pending_signals` at `:waiting` entry so `route_signal/1` can resume the run early |
| `on_outcome` | `outcome`, `to_step` | — | When a delivery outcome matches, advance to `to_step` |
| `stop` | `outcome` | — | When a delivery outcome matches, stop the run |

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

## 3. Trigger the Journey

When the mention event occurs, trigger the notifier with required tenancy and idempotency options:

```elixir
{:ok, _result} =
  Chimeway.trigger(
    MyApp.Notifiers.MentionEscalation,
    %{user_id: "user:123", document_id: "doc:789"},
    idempotency_key: "mention-doc-789-user-123",
    tenant_id: "org_456"
  )
```

Use `Chimeway.trigger/3` — the public entrypoint on the `Chimeway` module. Both `idempotency_key` and `tenant_id` are required.

## 4. How wait_until Works

After the in_app delivery converges to a branchable terminal state, the workflow run enters `:waiting` with:

- `status_reason: "waiting_for_step_progression"`
- `status_context` carrying `due_at`, `to_step`, anchor delivery metadata (`anchor_delivery_id`, `anchor_timestamp`, and related fields)

The engine computes `due_at` from the anchor timestamp plus `delay_seconds`. When `now >= due_at`, `Chimeway.Workflows.Progression.progress_run/2` advances the run to `to_step` and plans the next delivery.

In production with the Oban dispatcher configured (`config :chimeway, dispatcher: Chimeway.Dispatch.Oban`), Chimeway schedules `Chimeway.Dispatch.WorkflowProgressionWorker` at `due_at` for each waiting run. For tests or non-Oban dispatchers, call `progress_run/2` directly or use the optional `progress_due_runs/1` fallback to sweep past-due runs.

## 5. Inspecting Run State

Use tenant-scoped inspection APIs to answer "where is this journey?" without cross-tenant leakage:

```elixir
{:ok, run} = Chimeway.Workflows.explain("org_456", workflow_run_id)

run.state           # :waiting | :active | :stopped | :completed
run.status_reason   # e.g. "waiting_for_step_progression"
run.pending_signals

{:ok, traces} = Chimeway.Workflows.list_traces("org_456", workflow_run_id)

Enum.map(traces, & &1.reason)
#=> ["workflow_started", "step_activated", "waiting_for_step_progression", ...]
```

Both functions require the correct `tenant_id`. Querying a run ID that belongs to another tenant returns `{:error, :not_found}`.

## 6. Delivery-Feedback Signal Routing (Production Path)

The proven production path for delivery outcomes driving workflow progression:

1. Provider webhook → `Chimeway.Webhooks` ingress → `Chimeway.Webhooks.ProcessFeedbackWorker`
2. Worker records the attempt and calls `Chimeway.Signal.track/4` with canonical event names: `chimeway.delivery.succeeded`, `chimeway.delivery.bounced`, or `chimeway.delivery.failed`
3. `Chimeway.Dispatch.SignalRouterWorker` (Oban queue `:chimeway_signals`) delegates to `Chimeway.Workflows.route_signal/1`
4. For waiting runs with matching `pending_signals`, the run resumes; for active runs, `on_outcome` / `stop` rules evaluate on delivery convergence inside `progress_run/2`

Signal signature — tenant first, then actor:

```elixir
Chimeway.Signal.track(
  "org_456",
  "user:123",
  "chimeway.delivery.succeeded",
  %{"delivery_id" => delivery_id}
)
```

Runnable end-to-end proof lives in the demo host:

- [Feedback pipeline E2E test](https://github.com/jonlunsford/chimeway/blob/main/examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs) — webhook → signal → `route_signal` → trace timeline with `:webhook_received`
- [Golden path webhook appendix](../introduction/golden-path.md#next-webhook-feedback-loop) — progress and stop paths with `Chimeway.Traces.explain_delivery/1`

## 7. Generic Signal Routing

`Chimeway.Workflows.route_signal/1` matches `:waiting` runs where:

- the signal's `event_name` is in the run's `pending_signals` list
- `tenant_id` matches the signal
- the notification's `recipient_identity` matches the signal's `actor_id`

When matched, the run transitions to `:active`, clears `pending_signals`, and records a `signal_received` transition (event name only — no raw payload in trace context).

When a run enters `:waiting` via `wait_until`, `enter_waiting/6` auto-populates `pending_signals` from the rule's `cancel_signals` when declared. Host applications no longer need manual `Workflows.update_run/3` calls to set `pending_signals` for `wait_until`-driven waits.

### Inbox Lifecycle Signal Routing

The production path for inbox read/seen driving workflow early exit:

1. Host calls `Chimeway.mark_read/3` or `Chimeway.mark_seen/3` — engine updates lifecycle timestamps on first transition only
2. On first transition, engine calls `Chimeway.Signal.track/4` internally with canonical event names: `chimeway.notification.read` and `chimeway.notification.seen`
3. `Chimeway.Dispatch.SignalRouterWorker` (Oban queue `:chimeway_signals`) delegates to `Chimeway.Workflows.route_signal/1`
4. For `:waiting` runs with matching `pending_signals`, the run resumes to `:active` with a `signal_received` transition

`mark_read` and `mark_seen` emit **distinct** signals — neither auto-emits the other. Re-marking an already-read or already-seen notification returns `:ok` without duplicate signals.

Operator traces record `event_name` only in the `signal_received` transition context; `notification_id` in the signal payload is not copied to transition context.

Signal signature — host calls the public API; the engine emits the durable signal internally:

```elixir
# Host calls public API — engine emits signal internally
Chimeway.mark_read(notification_id, "user:123")

# Equivalent durable signal (system-emitted, not host-called):
Chimeway.Signal.track(
  tenant_id,
  "user:123",
  "chimeway.notification.read",
  %{"notification_id" => notification_id}
)
```

### Canonical inbox cancel signals

For inbox-driven early exit, declare these canonical event names in `cancel_signals`:

- `chimeway.notification.read` — user explicitly read the notification
- `chimeway.notification.seen` — user viewed the notification in the inbox

`wait_until` rules declaring `cancel_signals: ["chimeway.notification.read"]` are end-to-end truthful: Phase 48 populates `pending_signals` at `:waiting` entry; inbox lifecycle APIs emit the matching durable signals without host `Signal.track` glue.

## Next Steps

- [Oban Integration](../recipes/oban-integration.md) — dispatcher config, worker queues, and transactional enqueue patterns (see oban-integration recipe)
- [Golden path](../introduction/golden-path.md) — fresh-host trigger → trace → webhook feedback loop
- [Feedback escalation workflow](../recipes/feedback-escalation-workflow.md) — persona walkthrough for delivery-feedback → trace timeline
- [Mention escalation recipe](../recipes/mention-escalation.md) — PM persona walkthrough for read-cancel plus wait_until time fallback

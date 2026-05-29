# Password Reset Support Trace

## Who this is for

**Support Operator:** A user says they didn't get their password reset email. Why?

**Feature Developer:** You define the password-reset notifier and trigger it from your auth flow. This recipe shows the setup baseline and how support inspects the durable trace without reading raw payloads.

## Prerequisites

- [Golden Path](../introduction/golden-path.md) — install, migrations, config, and your first `Chimeway.trigger/3`
- A host with Chimeway migrations applied and `Chimeway.Repo` configured

## Feature Developer: define and trigger

Define an email-channel notifier using the real `Chimeway.Notifier` callbacks:

```elixir
defmodule MyApp.Notifiers.PasswordReset do
  use Chimeway.Notifier

  @impl true
  def notification_key, do: "password_reset"

  @impl true
  def version, do: 1

  @impl true
  def recipients(params) do
    {:ok, [%{recipient_identity: params.user_identity, recipient_type: "user"}]}
  end

  @impl true
  def channels(_params, _recipient), do: {:ok, [:email]}

  @impl true
  def build(params, _recipient) do
    {:ok, %{
      subject: "Reset your password",
      body: "Use this link to reset your password: #{params.reset_url}"
    }}
  end
end
```

Trigger from your password-reset controller or service:

```elixir
Chimeway.trigger(
  MyApp.Notifiers.PasswordReset,
  %{user_identity: "user:123", reset_url: "https://app.example/reset/token"},
  idempotency_key: "password-reset-user-123",
  tenant_id: "org_456"
)
```

Both `:idempotency_key` and `:tenant_id` are required. Email delivery is often async via Oban — see [Oban Integration](oban-integration.md) for dispatcher config and worker queues.

## Support Operator: find and explain

When a user reports a missing email, look up recent password-reset deliveries by recipient identity:

```elixir
notifications =
  Chimeway.Traces.find_traces_for_recipient("user:123",
    notification_key: "password_reset",
    limit: 10
  )
```

Pick a `delivery_id` from the notification's deliveries (for example `hd(hd(notifications).deliveries).id`), then explain:

```elixir
{:ok, exp} = Chimeway.Traces.explain_delivery(delivery_id)

exp.status
exp.suppression_reason
exp.planning_reason
exp.timeline
```

Read `explanation.status`, `explanation.suppression_reason`, `explanation.planning_reason`, and `explanation.timeline` — these fields come from `Chimeway.Traces.Explanation` and answer "why" without inspecting notification payloads.

If support has a `correlation_id` from application logs:

```elixir
Chimeway.Traces.find_traces_by_correlation_id("req-abc-123")
```

## Diagnostic branches

Use the fields above in IEx to classify what happened.

### Policy / quiet hours / opt-out

| What you see | Fields to read | Meaning |
|--------------|----------------|---------|
| Deferred send | `status: :pending`, `planning_reason: "quiet_hours"` | Policy held the delivery until quiet hours end |
| Blocked channel | `status: :suppressed`, `suppression_reason: "channel_disabled"` | User preference or policy disabled the email channel |

Chimeway recorded the decision — check [Policy and preferences](../flows/policy-and-preferences.md) for the policy model (that guide is still a stub; treat it as orientation, not exhaustive reference).

### Delivery failure

| What you see | Fields to read | Meaning |
|--------------|----------------|---------|
| Retries exhausted | `status: :cancelled`, `suppression_reason: "retries_exhausted"` | Transient failures exceeded Oban retry budget |
| Permanent adapter error | `status: :cancelled`, `suppression_reason: "permanent_failure"` | Adapter returned a non-retryable error |
| Bounce | `status: :cancelled`, `suppression_reason: "bounced"` | Provider reported a hard bounce |
| Failed attempt still retrying | `status: :failed` | Delivery failed but may still retry — check `exp.last_attempt` and timeline |

### Succeeded but user claims non-receipt

When `status: :succeeded`, Chimeway completed its delivery obligation. The trace shows `:succeeded` — investigate provider logs, spam folders, and mailbox rules rather than re-triggering blindly (which idempotency may suppress anyway).

## Related guides

- [Tracing a Notification](tracing-a-notification.md) — telemetry, correlation IDs, and deeper diagnosis
- [Golden Path](../introduction/golden-path.md) — install-to-first-trace baseline
- [Policy and preferences](../flows/policy-and-preferences.md) — policy model overview (stub)

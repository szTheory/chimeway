---
phase: 21-template-versioning-rendering-contracts
reviewed: 2026-04-28T19:41:36Z
depth: deep
files_reviewed: 21
files_reviewed_list:
  - lib/chimeway.ex
  - lib/chimeway/deliveries.ex
  - lib/chimeway/delivery.ex
  - lib/chimeway/delivery_planning.ex
  - lib/chimeway/notifications/notification.ex
  - lib/chimeway/notifier.ex
  - lib/chimeway/rendering.ex
  - lib/chimeway/rendering/channels/email.ex
  - lib/chimeway/rendering/channels/in_app.ex
  - lib/chimeway/rendering/preview.ex
  - lib/chimeway/traces.ex
  - lib/chimeway/traces/explanation.ex
  - lib/chimeway/trigger.ex
  - lib/mix/tasks/preview_rendering.ex
  - priv/repo/migrations/20260428123000_add_rendering_contract_fields.exs
  - test/chimeway/integration/delivery_lifecycle_test.exs
  - test/chimeway/notifier_contract_test.exs
  - test/chimeway/orchestration/delivery_planning_test.exs
  - test/chimeway/rendering/channel_contract_test.exs
  - test/chimeway/rendering/preview_pipeline_test.exs
  - test/chimeway/rendering/render_identity_integration_test.exs
findings:
  critical: 0
  warning: 3
  info: 0
  total: 3
status: issues_found
---

# Phase 21: Code Review Report

**Reviewed:** 2026-04-28T19:41:36Z
**Depth:** deep
**Files Reviewed:** 21
**Status:** issues_found

## Summary

Reviewed the Phase 21 source range covering plans `21-01` through `21-05`, including the new rendering persistence, planner integration, preview API, preview Mix task, and the phase-local tests. The targeted suites currently pass, but three issues remain: one public API crash, one planner-time durability regression, and one local code-execution footgun in the new Mix task.

Validation performed:

- `mix test test/chimeway/rendering/preview_pipeline_test.exs test/chimeway/orchestration/delivery_planning_test.exs test/chimeway/integration/delivery_lifecycle_test.exs`
- `mix run -e 'IO.inspect(Chimeway.preview_rendering(Elixir.Does.Not.Exist, %{}, recipient: %{}, channel: :email))'`
- `MIX_ENV=test mix run -e '...RecipientEmailNotifier...'` to confirm planner-time re-rendering fails when `rendering/2` depends on recipient fields not persisted on `Notification`

## Warnings

### WR-01: `preview_rendering/3` crashes on an invalid notifier module

**File:** `lib/chimeway/rendering/preview.ex:21-33`
**Issue:** The new public preview API accepts any atom and immediately calls `Notifier.resolve_rendering/3`. For an unloaded or invalid module this falls through to `build/2` in `Chimeway.Rendering.resolve_build_fallback/3` and raises `UndefinedFunctionError` instead of returning a tagged error tuple. Reproduction:

```elixir
mix run -e 'IO.inspect(Chimeway.preview_rendering(Elixir.Does.Not.Exist, %{}, recipient: %{}, channel: :email))'
```

This currently terminates with `function Does.Not.Exist.build/2 is undefined`.

**Fix:**

```elixir
with :ok <- Notifier.validate_module!(notifier),
     {:ok, recipient} <- fetch_required_option(opts, :recipient),
     {:ok, channel} <- fetch_required_channel(opts),
     {:ok, rendering} <- Notifier.resolve_rendering(notifier, params, recipient) do
  ...
end
```

Add a regression test in `test/chimeway/rendering/preview_pipeline_test.exs` that asserts `{:error, :notifier_not_loaded}` or another stable tagged error instead of a crash.

### WR-02: Planner re-enters `rendering/2` with incomplete recipient data, so persisted render identity is not actually durable

**File:** `lib/chimeway/delivery_planning.ex:276-333`
**Issue:** `DeliveryPlanning.resolve_render_result/4` calls `Notifier.resolve_rendering/3` again during planning, but `notification_recipient/1` reconstructs the recipient from only `recipient_identity`, `recipient_type`, and `notification.metadata`. Any notifier whose `rendering/2` depends on recipient fields that are present at trigger time but not persisted on `Notification` will now fail or drift during planning. This is a real regression; the following reproduction crashes on the second `rendering/2` call because `recipient.email` has been discarded:

```elixir
MIX_ENV=test mix run -e '
defmodule RecipientEmailNotifier do
  use Chimeway.Notifier
  def notification_key, do: "recipient.email"
  def version, do: 1
  def recipients(_), do: {:ok, [%{recipient_identity: "user:1", recipient_type: "user", email: "ada@example.com"}]}
  def build(_, _), do: {:ok, %{legacy: true}}
  def channels(_, _), do: {:ok, [:email]}
  def rendering(_, recipient) do
    {:ok, %{assigns: %{"subject" => recipient.email, "html_body" => "<p>x</p>", "text_body" => "x"},
            channels: %{email: %{render_key: "recipient.email.email", render_version: 1}}}}
  end
end
IO.inspect(Chimeway.trigger(RecipientEmailNotifier, %{}, idempotency_key: "review-recipient-email-1"))
'
```

**Fix:**

```elixir
# Option A: persist the normalized declaration once at trigger time
%{
  render_assigns: sanitized_assigns,
  render_channels: rendering.channels
}

# and later plan from persisted data instead of calling rendering/2 again
```

Alternatively persist the recipient fields required by the rendering contract, but the cleaner fix is to stop recomputing rendering declarations during planning. Add a regression test that uses a notifier whose `rendering/2` reads `recipient.email` or another non-persisted recipient field.

### WR-03: `mix preview.rendering` executes arbitrary Elixir from CLI input

**File:** `lib/mix/tasks/preview_rendering.ex:83-107`
**Issue:** `--params`, `--recipient`, and `.exs` file inputs are evaluated with `Code.eval_string/1` and `Code.eval_file/1`. That makes the new preview command a code-execution surface, not just a data preview tool. Because the task is explicitly intended for local verification, this is not a remote exploit, but it is still a sharp edge: copying untrusted sample input into the command executes arbitrary code in the developer's environment.

**Fix:**

```elixir
# Prefer a data-only format
Jason.decode!(json_string)

# or, if Elixir terms are required, accept only literal AST nodes
Code.string_to_quoted!(value)
|> validate_literal_ast()
|> quoted_to_term()
```

At minimum, document the code-execution behavior explicitly and add a regression test that rejects non-literal input.

---

_Reviewed: 2026-04-28T19:41:36Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_

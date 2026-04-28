---
phase: 22-recovery-outcome-analytics
reviewed: 2026-04-28T22:52:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - lib/chimeway/deliveries.ex
  - lib/chimeway/delivery_planning.ex
  - lib/chimeway/notifier.ex
  - lib/chimeway/notifications/notification.ex
  - lib/chimeway/dispatch/oban.ex
  - lib/chimeway/dispatch/sync.ex
  - test/chimeway/orchestration/delivery_planning_test.exs
  - test/chimeway/orchestration/recovery_test.exs
findings:
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Phase 22: Code Review Report

**Reviewed:** 2026-04-28T22:52:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

I re-reviewed the final Phase 22 state after gap-closure plan `22-04`, with emphasis on recovery correctness, regressions, and whether the tests actually pin the risky paths. The `22-04` fixes themselves look sound: ordinary notifier-less planning is back to the single `in_app` path, failed `recover_delivery/2` handoffs are compensated, and the relevant targeted tests pass. I also re-ran `mix test`, which finished green (`355 tests, 0 failures`).

The remaining defect is narrower and sits in `recover_event/2`: recovered events replay persisted channel declarations, but they do not preserve notifier-defined orchestration semantics such as `:digest_held`. That means an event that originally should have entered the digest pipeline can be recovered as an immediate ready delivery instead.

## Warnings

### WR-01: `recover_event/2` drops notifier orchestration semantics during replay

**File:** `lib/chimeway/delivery_planning.ex:309-347`, `lib/chimeway/notifier.ex:69-87`, `lib/chimeway/notifications/notification.ex:16-31`, `test/chimeway/orchestration/recovery_test.exs:133-190`

**Issue:** `recover_event/2` intentionally replays notifications without notifier callbacks, but the only persisted recovery inputs are `render_assigns` and `render_channels`. When `DeliveryPlanning` resolves orchestration for a replayed notification, `Notifier.resolve_orchestration/4` receives `nil` and defaults to `%{default: :immediate}`. There is no persisted orchestration snapshot on `notifications`, so recovered events cannot reproduce notifier-declared `:digest_held` or channel-specific orchestration. In practice, a notification that originally should have been held for digest can be recovered as `orchestration_state: :ready`, bypassing digest accumulation and changing user-visible behavior.

The current tests do not cover this path. `test/chimeway/orchestration/recovery_test.exs` verifies persisted channel fanout and recovery metadata, but it only exercises immediate delivery semantics and would not catch a recovered digest/deferred notification being replayed incorrectly.

**Fix:**
Persist enough orchestration data at notification creation time to replay it durably during `recover_event/2`, then feed that snapshot back into `DeliveryPlanning` via an explicit override. For example:

```elixir
# At notification persistence time
%{
  "default" => "digest_held",
  "channels" => %{"email" => "digest_held"},
  "digest_keys" => %{"email" => "thread:123"}
}

# During recovery
dispatch_opts = [
  event_id: event.id,
  notification_key: event.notification_key,
  correlation_id: event.correlation_id,
  post_commit: true,
  use_persisted_channels: true,
  orchestration: persisted_orchestration_snapshot
]
```

Add a regression test that creates a notification whose original notifier orchestration is `:digest_held`, leaves the event recoverable, runs `recover_event/2`, and asserts the recovered row remains `orchestration_state: :digest_held` with the expected planning context.

---

_Reviewed: 2026-04-28T22:52:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

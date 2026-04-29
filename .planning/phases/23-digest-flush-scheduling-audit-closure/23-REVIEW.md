---
phase: 23-digest-flush-scheduling-audit-closure
reviewed: 2026-04-29T02:20:28Z
depth: standard
files_reviewed: 15
files_reviewed_list:
  - lib/chimeway/digests/accumulation.ex
  - lib/chimeway/digests.ex
  - lib/chimeway/dispatch/oban.ex
  - lib/chimeway/dispatch/digest_flush_worker.ex
  - test/chimeway/digests/flush_scheduling_test.exs
  - test/chimeway/digests/emission_test.exs
  - priv/repo/migrations/20260428230000_add_orchestration_snapshot_to_chimeway_notifications.exs
  - lib/chimeway/notifications/notification.ex
  - lib/chimeway/trigger.ex
  - lib/chimeway/notifier.ex
  - lib/chimeway/delivery_planning.ex
  - lib/chimeway/deliveries.ex
  - test/chimeway/orchestration/recovery_test.exs
  - test/chimeway/trigger_pipeline_test.exs
  - test/chimeway/integration/digest_delivery_lifecycle_test.exs
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---
# Phase 23: Code Review Report

**Reviewed:** 2026-04-29T02:20:28Z
**Depth:** standard
**Files Reviewed:** 15
**Status:** issues_found

## Summary

Reviewed the digest flush scheduling, persisted orchestration snapshot, recovery, and lifecycle integration changes at standard depth. The targeted tests in scope are currently green, but the accumulation API now accepts caller-supplied lookup attributes that can override the delivery's persisted recipient/channel/rule identity during bucket selection. That creates a real cross-recipient aggregation risk and is not covered by the new tests.

Validated locally with:

```sh
mix test test/chimeway/digests/flush_scheduling_test.exs test/chimeway/digests/emission_test.exs
mix test test/chimeway/orchestration/recovery_test.exs test/chimeway/trigger_pipeline_test.exs test/chimeway/integration/digest_delivery_lifecycle_test.exs
```

## Critical Issues

### CR-01: Accumulation accepts forged lookup identities and can place a delivery into another recipient's digest bucket

**File:** `lib/chimeway/digests/accumulation.ex:60-95`
**Issue:** `do_accumulate/3` routes the delivery using `lookup_attrs`, and `build_lookup_attrs/4` merges those caller-provided values over the durable notification/event data (`recipient_id`, `channel`, `notification_key`, `notification_version`, `category`, `digest_key`). Any internal or host-side caller that passes inconsistent attrs can accumulate a `digest_held` delivery into the wrong recipient/channel bucket and later emit a digest notification for the wrong owner. That violates the project's host ownership boundary and can leak one recipient's notifications into another recipient's digest.
**Fix:**
```elixir
defp build_lookup_attrs(delivery, notification, event, lookup_attrs) do
  derived = %{
    recipient_id: notification.recipient_identity,
    channel: delivery.channel,
    notification_key: event.notification_key,
    notification_version: event.notification_version,
    category: event_category(event),
    digest_key: digest_key(delivery)
  }

  case Map.take(lookup_attrs, [:recipient_id, :channel, :notification_key, :notification_version]) do
    mismatch when mismatch != %{} and mismatch != Map.take(derived, Map.keys(mismatch)) ->
      Repo.rollback({:invalid_lookup_attrs, mismatch})

    _ ->
      Map.merge(derived, Map.take(lookup_attrs, [:category, :digest_key]))
  end
end
```

## Warnings

### WR-01: No regression test proves mismatched lookup attrs are rejected

**File:** `test/chimeway/digests/flush_scheduling_test.exs:26-95`
**Issue:** The new scheduling tests cover only happy-path bucket creation and sequential duplicate job suppression. They never exercise the new `lookup_attrs` seam with conflicting recipient/channel identifiers, so the cross-recipient accumulation bug above can ship unnoticed.
**Fix:** Add a test that creates a `digest_held` delivery for recipient A, calls `Accumulation.accumulate_delivery/2` with `lookup_attrs: %{recipient_id: "recipient-b"}`, and asserts the call fails (or no-ops) without creating a bucket or membership for recipient B.

---

_Reviewed: 2026-04-29T02:20:28Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

---
phase: 22-recovery-outcome-analytics
plan: 02
subsystem: recovery
tags: [elixir, ecto, dispatcher, recovery, orchestration, tdd]
requires:
  - phase: 22-recovery-outcome-analytics
    provides: durable recovery eligibility queries and guarded recovery claims
provides:
  - public delivery recovery API that reuses the configured dispatcher and preserves canonical delivery identity
  - event recovery flow that replans from persisted notification render declarations without notifier callbacks
  - duplicate-safe noop normalization for dispatcher skip and post-claim state drift
affects: [22-03, ops-01, operator-recovery]
tech-stack:
  added: []
  patterns: [dispatcher-backed recovery handoff, persisted render-channel fallback, noop-normalized duplicate recovery]
key-files:
  created: [.planning/phases/22-recovery-outcome-analytics/22-02-SUMMARY.md, test/chimeway/orchestration/recovery_test.exs]
  modified: [lib/chimeway/deliveries.ex, lib/chimeway/delivery_planning.ex, lib/chimeway.ex, test/chimeway/integration/delivery_lifecycle_test.exs]
key-decisions:
  - "Recovery routes through the configured dispatcher seam instead of inventing a separate send path."
  - "Event recovery derives channels from persisted notification.render_channels when no notifier module is available."
patterns-established:
  - "Delivery recovery claims the canonical row first, then dispatches by delivery_id with pre_planned and post_commit flags."
  - "Event recovery stamps recovery_source, recovery_reason, and recovered_at onto newly planned delivery rows after dispatcher handoff."
requirements-completed: [OPS-01]
duration: 22min
completed: 2026-04-28
---

# Phase 22 Plan 02: Dispatcher-backed recovery orchestration Summary

**Recoverable events and deliveries now re-drive through the normal dispatcher without replacing canonical rows**

## Performance

- **Duration:** 22 min
- **Completed:** 2026-04-28
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added `Chimeway.Deliveries.recover_delivery/2` and `Chimeway.Deliveries.recover_event/2`, plus thin `Chimeway.recover_delivery/2` and `Chimeway.recover_event/2` wrappers.
- Reused `begin_recovery/2` for delivery claims, then handed the same `delivery_id` to `dispatch_delivery/2` with `pre_planned: true` and `post_commit: true`.
- Taught `Chimeway.DeliveryPlanning` to fall back to persisted `Notification.render_channels |> Map.keys()` so event recovery can replan deliveries without notifier callbacks.
- Normalized duplicate attempts and dispatcher `{:skip, delivery}` results into explicit recovery-level noop responses.

## Verification Evidence

- Command: `mix test test/chimeway/orchestration/recovery_test.exs test/chimeway/integration/delivery_lifecycle_test.exs --trace`
- Result: `19 tests, 0 failures`
- Acceptance checks passed via `rg` for:
  - `def recover_event`, `def recover_delivery`, `dispatch_delivery`, `dispatcher.dispatch(notifications`, `pre_planned: true`, `post_commit: true`, `{:noop,` in `lib/chimeway/deliveries.ex`
  - `render_channels` and `Map.keys` in `lib/chimeway/delivery_planning.ex`
  - `def recover_event` and `def recover_delivery` in `lib/chimeway.ex`
  - `recover_event`, `recover_delivery`, `dispatch_delivery`, `render_channels`, `delivery.id`, `{:noop,` in `test/chimeway/orchestration/recovery_test.exs`
  - `recovery_source` and `recovered_at` in `test/chimeway/integration/delivery_lifecycle_test.exs`

## Task Commits

1. **Task 1: Add RED recovery flow tests for dispatcher handoff and duplicate safety** - `a78f1b7` (`test`)
2. **Task 2: Implement the recovery orchestration API and dispatcher-backed handoff** - `8bb160a` (`feat`)

## Files Created/Modified

- `lib/chimeway/deliveries.ex` - adds event and delivery recovery entrypoints, dispatcher handoff, and recovery-result normalization.
- `lib/chimeway/delivery_planning.ex` - adds persisted render-channel fallback for recovery planning without notifier callbacks.
- `lib/chimeway.ex` - exposes public recovery wrappers.
- `test/chimeway/orchestration/recovery_test.exs` - locks event recovery, delivery recovery, duplicate noops, and dispatcher skip semantics.
- `test/chimeway/integration/delivery_lifecycle_test.exs` - proves same-row delivery recovery through the Oban-backed dispatch path.

## Decisions Made

- Recovery treats `notification.render_channels` as the durable channel source during event replanning, including custom channels persisted at trigger time.
- Recovery metadata is returned as structured result data and also persisted onto canonical delivery metadata for later operator explanation.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check

PASSED

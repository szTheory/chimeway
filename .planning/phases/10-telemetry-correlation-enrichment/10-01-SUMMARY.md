---
phase: 10-telemetry-correlation-enrichment
plan: 01
subsystem: Telemetry
tags: [telemetry, correlation, persistence]
requires: [OPS-02]
provides: [correlation-threading]
affects: [Trigger, DeliveryPlanning, Deliveries]
tech-stack: [Elixir, Ecto, Telemetry]
key-files: [lib/chimeway/trigger.ex, lib/chimeway/delivery_planning.ex, lib/chimeway/deliveries.ex]
decisions:
  - Threaded `notification_key`, `event_id`, and `correlation_id` through the dispatch chain.
  - Persisted these identifiers in `Delivery.metadata` using string keys for persistence consistency.
  - Enriched the `[:deliveries, :plan]` telemetry span with these identifiers on success.
metrics:
  duration: 15m
  completed_date: "2026-04-24"
---

# Phase 10 Plan 01: Telemetry Correlation Enrichment Summary

Successfully threaded and persisted correlation identifiers (`notification_key`, `event_id`, `correlation_id`) from the initial trigger through the planning phase and into the resulting delivery records. This ensures that all subsequent lifecycle events (attempts, provider responses, status transitions) can be correlated back to the originating event using only the delivery record.

## Key Changes

### 1. Trigger Metadata Threading
Updated `Chimeway.Trigger.dispatch_after_trigger/4` to include `notification_key` in the `dispatch_opts`. `event_id` and `correlation_id` were already being passed, but adding the key ensures a complete correlation set is available to the dispatcher.

### 2. Delivery Planning Propagation
Modified `Chimeway.DeliveryPlanning` to forward these correlation identifiers from the dispatch options down through its internal planning functions (`plan_notification`, `plan_channels`, `plan_one_channel`) to the persistence layer.

### 3. Delivery Record Persistence
Updated `Chimeway.Deliveries.plan_delivery/3` to merge the correlation identifiers into the delivery's `metadata` field. 
- Keys used: `"notification_key"`, `"event_id"`, `"correlation_id"` (string-based for JSONB stability).
- Introduced a `maybe_put/3` helper for clean conditional map updates.

### 4. Planning Span Enrichment
Enriched the `[:chimeway, :deliveries, :plan, :stop]` telemetry event with `event_id` and `correlation_id`. This allows monitoring systems to trace the planning duration and outcome back to the specific event and correlation chain.

## Verification Results

### Automated Tests
Created `test/chimeway/telemetry_correlation_test.exs` with two primary assertions:
- **Persistence:** Verified that triggering a notification results in `Delivery` records containing the expected correlation keys in their `metadata`.
- **Telemetry:** Verified (using `:telemetry.attach`) that the `[:deliveries, :plan]` span includes the enriched metadata on successful execution.

```bash
mix test test/chimeway/telemetry_correlation_test.exs
# 2 tests, 0 failures
```

## Deviations from Plan

None. The implementation followed the plan exactly.

## Self-Check: PASSED
- [x] All tasks executed
- [x] Each task committed individually
- [x] SUMMARY.md created
- [x] STATE.md update pending

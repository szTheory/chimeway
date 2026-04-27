# Phase 10: Telemetry Correlation Enrichment - Plan 02 Summary

**Executed:** 2026-04-24
**Status:** Complete
**Scope:** Telemetry enrichment and verification

## Goal
Enrich all lifecycle telemetry spans with correlation metadata extracted from delivery records. Verify the enrichment and ensure no sensitive data leakage via updated integration tests.

## Completed Tasks

### 1. Enrich Policy and Sync spans
- Updated `lib/chimeway/policy.ex` to include `notification_key` in `[:policy, :evaluate]` span.
- Updated `lib/chimeway/dispatch/sync.ex` to include `notification_key` in `[:dispatch, :sync]` span.

### 2. Enrich Oban spans
- Updated `lib/chimeway/dispatch/oban.ex` to include `notification_key` and `channel` in `[:dispatch, :enqueue]` span.
- Updated `lib/chimeway/dispatch/oban_worker.ex` to include `notification_key` in `[:dispatch, :perform]` span.

### 3. Enrich Attempt span and add integration tests
- Updated `lib/chimeway/deliveries.ex` to include `notification_key` and `channel` in `[:attempts, :record]` span.
- Added comprehensive integration tests in `test/chimeway/telemetry_integration_test.exs` verifying correlation metadata presence and redaction.
- Improved `Chimeway.Telemetry.span/3` to automatically merge start metadata into stop metadata, ensuring consistent identifier presence across all span events.

## Verification Results

### Automated Tests
- `mix test test/chimeway/telemetry_integration_test.exs` passed (9 tests).
- `mix test` passed (162 tests).

### Evidence
- `[:policy, :evaluate, :stop]` now includes `:notification_key`.
- `[:dispatch, :sync, :stop]` now includes `:notification_key` and `:channel`.
- `[:attempts, :record, :stop]` now includes `:notification_key` and `:channel`.
- `[:dispatch, :enqueue, :stop]` and `[:dispatch, :perform, :stop]` include appropriate identifiers.
- Redaction verified: only allowed keys appear in telemetry spans.

## Artifacts Modified
- `lib/chimeway/telemetry.ex`
- `lib/chimeway/policy.ex`
- `lib/chimeway/dispatch/sync.ex`
- `lib/chimeway/dispatch/oban.ex`
- `lib/chimeway/dispatch/oban_worker.ex`
- `lib/chimeway/deliveries.ex`
- `test/chimeway/telemetry_integration_test.exs`

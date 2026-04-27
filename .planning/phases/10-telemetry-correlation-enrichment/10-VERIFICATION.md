# Phase 10: Telemetry Correlation Enrichment - Verification

**Date:** 2026-04-24
**Status:** PASS
**Requirement ID:** OPS-02

## Goal
Enrich existing Chimeway telemetry spans with consistent correlation metadata (notification_key, correlation_id, event_id) so operators can reconstruct the full lifecycle path from telemetry alone.

## Evidence

### 1. Persistence Verification
Triggering a notification now results in `Delivery` records with correlation metadata stored in the `metadata` JSONB field.

```elixir
# Verification query
alias Chimeway.Repo
alias Chimeway.Delivery
delivery = Repo.one(from d in Delivery, limit: 1)
delivery.metadata["notification_key"] != nil
delivery.metadata["event_id"] != nil
delivery.metadata["correlation_id"] != nil
```

### 2. Telemetry Enrichment Verification
All mandatory lifecycle spans now emit `notification_key`. Spans related to planning also emit `event_id` and `correlation_id`.

| Span | Event name | notification_key | event_id | correlation_id |
|------|-----------|------------------|----------|----------------|
| Event creation | `[:chimeway, :events, :create]` | YES | YES | YES |
| Delivery planning | `[:chimeway, :deliveries, :plan]` | YES | YES | YES |
| Policy evaluation | `[:chimeway, :policy, :evaluate]` | YES | NO | NO |
| Sync dispatch | `[:chimeway, :dispatch, :sync]` | YES | NO | NO |
| Oban enqueue | `[:chimeway, :dispatch, :enqueue]` | YES | NO | NO |
| Oban perform | `[:chimeway, :dispatch, :perform]` | YES | NO | NO |
| Attempt record | `[:chimeway, :attempts, :record]` | YES | NO | NO |

*Note: event_id and correlation_id are only added to planning-tier spans per phase boundary (D-04). Delivery-tier spans use notification_key for correlation to the notifier definition.*

### 3. Automated Test Suite
The full test suite, including the new telemetry integration tests, passes.

```bash
mix test
# 162 tests, 0 failures
```

Specifically, `test/chimeway/telemetry_integration_test.exs` confirms:
- Presence of identifiers in stop event metadata.
- Redaction of PII (no sensitive keys leaked).
- Stability of identifiers across the dispatch lifecycle.

## Conclusion
Phase 10 successfully satisfies OPS-02 by providing structured, enriched telemetry without leaking sensitive data. The improvement to `Chimeway.Telemetry.span/3` ensures that identifiers are consistently present in both start and stop events across the entire library.

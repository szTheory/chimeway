# Phase 2: First Outbound Delivery Slice

**Status**: not_started
**Depends on**: Phase 1 (Durable Core Spine)
**Requirements**: [DLVR-01, DLVR-02, DLVR-03, INTG-01, INTG-02]

## Goal

Prove end-to-end outbound delivery from planned rows through attempt outcomes using one adapter seam.

## Plans

| Plan | Title | Status | Depends On |
|------|-------|--------|------------|
| [02-01](plans/02-01-delivery-persistence-model.md) | Add Delivery and Attempt Persistence Model plus Lifecycle Transitions | not_started | — |
| [02-02](plans/02-02-outbound-adapter-seam.md) | Implement First Outbound Adapter Seam and Outcome Classification | not_started | 02-01 |
| [02-03](plans/02-03-adapter-contract-tests.md) | Add Adapter Contract Tests and Fake Provider Harness | not_started | 02-01, 02-02 |

## Execution Waves

- **Wave 1**: 02-01 — delivery + attempt schemas, state machine, idempotent planner, dispatch behaviour stub
- **Wave 2**: 02-02 — adapter behaviour, Test/Logger adapters, sync dispatcher wired to adapter + attempt persistence
- **Wave 3**: 02-03 — shared contract test module, contract tests applied to all adapters, end-to-end verification

## Success Criteria

1. Trigger flow plans per-channel delivery rows for each recipient with explicit lifecycle states (DLVR-01).
2. Each outbound send attempt creates attempt metadata and final state transitions (DLVR-02, DLVR-03).
3. One outbound adapter seam works in testable form (Test/Logger adapter) in addition to in-app (INTG-02).
4. Integration contract ensures adapters remain replaceable and not core-coupled (INTG-01).

## Key Modules Added This Phase

- `lib/chimeway/delivery.ex` — Ecto schema for `chimeway_deliveries`
- `lib/chimeway/delivery_attempt.ex` — Ecto schema for `chimeway_delivery_attempts`
- `lib/chimeway/deliveries.ex` — delivery context: planning, state transitions, attempt recording
- `lib/chimeway/dispatch.ex` — dispatcher behaviour (seam for Phase 3 Oban)
- `lib/chimeway/dispatch/sync.ex` — sync dispatcher implementation
- `lib/chimeway/adapter.ex` — adapter behaviour with `deliver/2` callback
- `lib/chimeway/adapters/test.ex` — in-memory test adapter (mirrors Swoosh.Adapters.Test pattern)
- `lib/chimeway/adapters/logger.ex` — structured-log adapter, always succeeds
- `test/support/chimeway/adapter/contract_test.ex` — shared contract assertions for all adapters

## Key DB Changes This Phase

- `chimeway_deliveries` table (new): id, notification_id FK, channel, status, suppression_reason, delay_fallback, metadata, timestamps
- `chimeway_delivery_attempts` table (new): id, delivery_id FK, outcome, provider_response, inserted_at
- Unique index on `(notification_id, channel)` in `chimeway_deliveries`
- Index on `delivery_id` in `chimeway_delivery_attempts`

## Design Decisions Applied

- Include `suppression_reason` (nullable string) and `delay_fallback` (boolean, default false) in the initial `chimeway_deliveries` migration to avoid Phase 3 alter migrations (per RESEARCH.md open question 1).
- Test/Logger adapter is sufficient for INTG-02; Swoosh adapter deferred to a follow-up (per RESEARCH.md open question 2).
- Outcome classification (`:ok` → `succeeded`, `{:error, class, detail}` → `failed`) happens in the dispatcher, not the adapter, keeping adapters thin and swappable.
- `Chimeway.Dispatch` behaviour is established in 02-01 (stub only) so Phase 3 can add `Chimeway.Dispatch.Oban` without touching call sites.

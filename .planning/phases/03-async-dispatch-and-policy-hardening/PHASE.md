# Phase 3: Async Dispatch and Policy Hardening

**Status**: not_started
**Depends on**: Phase 2 (First Outbound Delivery Slice)
**Requirements**: [DLVR-04, POLC-01, POLC-02, POLC-03, INTG-03]

## Goal

Add optional Oban-backed async execution and enforce policy correctness across delayed paths.

## Plans

| Plan | Title | Status | Depends On |
|------|-------|--------|------------|
| [03-01](plans/03-01-oban-worker-path.md) | Build Optional Oban Worker Path and Transactional Enqueue Integration | not_started | — |
| [03-02](plans/03-02-preference-policy-engine.md) | Implement Preference Model and Policy Engine with Dual Evaluation Checkpoints | not_started | 03-01 |
| [03-03](plans/03-03-fallback-and-async-tests.md) | Add Delayed Fallback Behavior Tests and Async Failure-Mode Verification | not_started | 03-01, 03-02 |

## Execution Waves

- **Wave 1**: 03-01 — dispatcher seam and Oban worker, no policy dependencies
- **Wave 2**: 03-02 — preference schema, policy engine, dual evaluation hooks
- **Wave 3**: 03-03 — integration and failure-mode tests across both prior plans

## Success Criteria

1. System supports sync and optional Oban-backed dispatch through a documented integration seam (DLVR-04, INTG-03).
2. Preferences and policy are evaluated at both planning/enqueue time and perform/send time (POLC-01, POLC-02).
3. Delayed fallback can suppress outbound sends when in-app state indicates notification was read (POLC-03).
4. Async retries/backoff preserve idempotency and trace correctness (DLVR-04).

## Key Modules Added This Phase

- `lib/chimeway/dispatch.ex` — dispatcher behaviour
- `lib/chimeway/dispatch/sync.ex` — sync implementation
- `lib/chimeway/dispatch/oban.ex` — Oban dispatcher (optional dep guard)
- `lib/chimeway/dispatch/oban_worker.ex` — Oban worker with perform-time policy check
- `lib/chimeway/policy.ex` — dual-checkpoint policy engine
- `lib/chimeway/preferences.ex` — preference context
- `lib/chimeway/preferences/notification_preference.ex` — preference schema

## Key DB Changes This Phase

- `chimeway_notification_preferences` table (new)
- `suppression_reason` column on `chimeway_deliveries` (alter)
- `delay_fallback` boolean column on `chimeway_deliveries` (alter)

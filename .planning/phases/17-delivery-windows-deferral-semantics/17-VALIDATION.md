# Phase 17 Validation

**Phase:** 17 - Delivery Windows & Deferral Semantics
**Created:** 2026-04-28
**Status:** Ready for execution planning

## Validation Intent

Phase 17 must prove that Chimeway can persist and explain immediate, deferred, and
digest-held planning outcomes without:

- breaking the `(notification_id, channel)` idempotency boundary
- conflating deferral with suppression
- dispatching deferred or digest-held rows before Phase 18 scheduling exists

## Requirement Coverage

| Requirement | Validation focus |
|-------------|------------------|
| ORCH-01 | Delivery planning persists `:ready`, `:deferred`, or `:digest_held` on the canonical delivery row and keeps one row per `(notification_id, channel)`. |
| ORCH-02 | Recipient-timezone-aware planning persists rule identity, timezone context, reason, and `next_eligible_at`, and exposes them through trace surfaces. |

## Required Automated Checks

This file satisfies the Phase 17 Nyquist validation artifact requirement and must stay adjacent to the plan set during execution.

### Wave 1

- `mix test test/chimeway/policy_settings_test.exs test/chimeway/orchestration/window_math_test.exs -x`

### Wave 2

- `mix test test/chimeway/notifier_contract_test.exs test/chimeway/policy_settings_test.exs test/chimeway/policy_test.exs test/chimeway/orchestration/planning_declarations_test.exs test/chimeway/orchestration/delivery_planning_test.exs -x`

### Wave 3

- `mix test test/chimeway/orchestration/dispatch_gating_test.exs test/chimeway/orchestration/traces_deferral_test.exs test/chimeway/integration/delivery_lifecycle_test.exs -x`

### Phase gate

- `mix test`

## Mandatory Assertions

- Existing recipients can update `time_zone` through policy settings upserts.
- Product teams can declare digest participation through a notifier/planner seam, and that declaration persists `orchestration_state: :digest_held` on the canonical delivery row.
- Quiet-hours rules defer instead of suppress.
- Deferred rows keep `suppression_reason` unset.
- Sync and Oban dispatch only deliveries whose orchestration state is ready.
- Deferred and digest-held rows accumulate zero attempts in Phase 17.
- `Traces.explain_delivery/2` shows deferral reason, timezone, normalized rule identity, and next eligible send time.

## Risks To Watch

- UTC-only timezone math accidentally passing tests.
- Deferred rows leaking into immediate dispatch or Oban enqueue.
- Explanation fields living only in metadata with no stable query surface.
- Existing suppression-oriented tests not being updated to the new deferral contract.
- Declared digest participation silently creating Phase 19-style accumulation artifacts instead of state-only `:digest_held` rows.
- Scope silently expanding into Phase 18 resume scheduling or a broader delivery-window configuration surface.

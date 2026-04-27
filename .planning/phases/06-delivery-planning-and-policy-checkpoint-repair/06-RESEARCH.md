# Phase 6 Research: Delivery Planning and Policy Checkpoint Repair

**Phase**: 6 - Delivery Planning and Policy Checkpoint Repair  
**Requirements**: DLVR-01, INTG-02, POLC-01, POLC-02  
**Researched**: 2026-04-24  
**Status**: RESEARCH COMPLETE

---

## Executive Summary

Phase 6 is a parity-repair phase, not a greenfield feature. The codebase already has durable rows (`event -> notification -> delivery -> attempt`) and dual-checkpoint policy primitives, but planning currently breaks the intended contract in two places:

1. Delivery planning is hardcoded to `:in_app` in both sync and Oban dispatchers.
2. Planning-time policy checks are enforced in sync but not in Oban enqueue flow.

The recommended implementation is to introduce a shared planning module (`Chimeway.DeliveryPlanning`) that fans out per recipient x channel, applies policy at planning time for both dispatch strategies, persists suppressions as first-class delivery rows, and only enqueues/runs adapter work for dispatchable rows.

---

## 1) Current-State Gap Audit (Code Evidence)

### Confidence: HIGH

### 1.1 Hardcoded single-channel planning

- `lib/chimeway/dispatch/sync.ex` uses `Deliveries.plan_delivery(notification.id, :in_app)` for every notification.
- `lib/chimeway/dispatch/oban.ex` uses the same hardcoded call before enqueue.

This violates Phase 6 success criterion #1 ("per-recipient, per-channel delivery rows").

### 1.2 Asymmetric planning-time policy enforcement

- Sync path currently checks policy during planning (`Policy.evaluate(delivery, [])` in `evaluate_and_dispatch/1`).
- Oban path does **not** check policy in `dispatch/2`; it always enqueues planned deliveries.
- Oban worker checks policy at perform time (`Policy.evaluate(delivery, check_read_state: delivery.delay_fallback)`), which is too late for planning/enqueue parity.

This violates success criterion #2.

### 1.3 Notifier contract lacks explicit channel fanout callback

- `lib/chimeway/notifier.ex` defines `notification_key/0`, `version/0`, `recipients/1`, `build/2`.
- No `channels/2` callback exists yet.

Without an explicit channel contract, fanout behavior remains implicit and tends to drift by dispatcher implementation.

### 1.4 Trigger recipient normalization and channel intent

- `lib/chimeway/trigger.ex` deduplicates recipients by `recipient_identity`.
- This is correct for identity fanout, but channel fanout must then be derived explicitly from one canonical recipient record.

The right fix is not removing dedupe; it is introducing deterministic channel expansion downstream.

---

## 2) Recommended Architecture for Phase 6

### Confidence: HIGH

### 2.1 Shared planner context

Create `lib/chimeway/delivery_planning.ex` with a stable API:

- `plan_notifications(notifications, opts) :: {:ok, [Delivery.t()]} | {:error, term()}`
- `plan_notification(notification, opts) :: {:ok, [Delivery.t()]} | {:error, term()}`

`opts` should include:

- `:notifier` (module, optional)
- `:trigger_params` (map, optional)
- `:policy_checkpoint` default `"planning"`

### 2.2 Channel derivation contract

1. If notifier exports `channels/2`, call it with:
   - trigger params (if available)
   - canonical recipient map derived from notification row
2. Normalize to unique channel strings (atom/string accepted, deterministic order).
3. Fallback to `["in_app"]` when callback is absent (temporary backward compatibility for Phase 6).

### 2.3 Planning-time policy behavior

For every planned delivery:

1. Run `Policy.evaluate(delivery, [])`.
2. If `{:suppress, reason}`, persist suppression row (`status: :suppressed`, `suppression_reason` set).
3. Mark suppression checkpoint source in delivery metadata (`policy_checkpoint: "planning"`).
4. If `{:ok, :proceed}`, keep status pending for sync execution or Oban enqueue.

### 2.4 Dispatch strategy parity rule

- Sync and Oban dispatchers must both call the same planner.
- Oban enqueue must skip rows already suppressed at planning time.
- Perform-time policy checks remain in sync dispatch and Oban worker for delayed/read-state drift handling.

---

## 3) Existing Patterns to Reuse

### Confidence: HIGH

- `Chimeway.Deliveries.plan_delivery/2` already provides idempotent `(notification_id, channel)` row creation.
- `Chimeway.Deliveries.suppress_delivery/2` already persists suppression reason (extend to checkpoint metadata).
- `Chimeway.Policy.evaluate/2` already returns canonical decisions (`{:ok, :proceed}` | `{:suppress, atom}`).
- `Chimeway.Trigger` already passes notifier context at dispatch seam and can pass additional planner inputs via `opts`.
- `test/support/chimeway/dispatch_helpers.ex` provides robust fixture setup for delivery/policy tests.

---

## 4) Risk Register and Mitigations

| Risk | Severity | Why It Matters | Mitigation |
|------|----------|----------------|------------|
| Planner derives inconsistent channels between sync and Oban | High | Behavioral drift causes hard-to-debug delivery mismatches | Route both dispatchers through one planner module and shared normalization logic |
| `channels/2` callback errors create silent partial fanout | High | Hidden drops violate explainability | Treat callback errors as explicit planning failure with tagged error return; no silent fallback on explicit callback failure |
| Suppressed rows still enqueued in Oban | High | Policy bypass and noisy worker churn | Enqueue only rows in `:pending`; add tests asserting suppressed deliveries never enqueue |
| Fallback to `["in_app"]` hides migration debt | Medium | Teams may not adopt explicit channels | Emit deprecation warning when fallback path is used; document removal in next milestone |
| Extra policy checks increase duplicate suppression transitions | Low | Potential noisy transitions | Guard with terminal-state checks and idempotent suppress behavior |

---

## 5) Testing Strategy (Phase 6)

### Confidence: HIGH

### Required automated coverage additions

1. **Fanout coverage**
   - Trigger path produces one delivery per recipient x channel combination.
   - Duplicate channel values are deduped deterministically.

2. **Planning-time policy parity**
   - Sync and Oban both suppress channel-disabled deliveries during planning/enqueue.
   - Suppressed rows persist `suppression_reason` and checkpoint metadata.

3. **Standard outbound success spine**
   - Integration test proves event -> notification -> delivery fanout -> attempts for non-suppressed channels.

4. **Backward compatibility path**
   - Notifier without `channels/2` still produces in-app-only delivery row with deprecation signaling.

---

## 6) Implementation Ordering Recommendation

### Confidence: HIGH

1. Add notifier contract extension + trigger option propagation.
2. Introduce `DeliveryPlanning` module and wire sync/oban to it.
3. Add suppression checkpoint metadata plumbing.
4. Add parity and integration tests.
5. Refactor duplicate adapter-attempt execution helpers only after behavior parity tests are green.

---

## Validation Architecture

Nyquist-style validation for this phase should use **fast focused tests after each task** and **full suite at wave boundaries**:

- Quick loop command:
  - `mix test test/chimeway/trigger_pipeline_test.exs test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/policy_test.exs`
- Full suite command:
  - `mix test`
- Optional integration-only rerun:
  - `mix test test/chimeway/integration/delivery_lifecycle_test.exs`

Sampling policy:

- After every task commit: run quick loop command.
- After each plan wave: run full suite command.
- Before verify-work/phase completion: full suite must be green.

---

## 7) Readiness Verdict

Phase 6 is ready for planning. The codebase has all required primitives; the work is primarily contract unification and parity enforcement.

---

*Research completed: 2026-04-24*  
*Confidence: HIGH overall*

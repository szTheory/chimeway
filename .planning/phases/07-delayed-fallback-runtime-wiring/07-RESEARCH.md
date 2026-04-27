# Phase 7 Research: Delayed Fallback Runtime Wiring

**Phase**: 7 - Delayed Fallback Runtime Wiring  
**Requirement**: POLC-03  
**Researched**: 2026-04-24  
**Status**: Drafted for planning input

---

## Executive Summary

Phase 7 is a runtime wiring and evidence-quality phase. The codebase already has the perform-time suppression gate (`Policy.evaluate(delivery, check_read_state: delivery.delay_fallback)`) in both sync and Oban worker paths, but normal trigger planning does not currently mark deliveries with `delay_fallback: true`.

That means POLC-03 behavior exists only when tests manually build fixture deliveries with `delay_fallback: true`, not through the real trigger -> planning pipeline. The recommended implementation is additive and backward-compatible:

1. Add an optional notifier callback for delayed-fallback intent.
2. Add an additive planning API that can persist `delay_fallback` at insert time.
3. Resolve delayed-fallback intent in the shared planner with deterministic precedence and strict validation.
4. Keep dual-checkpoint suppression exactly as-is (planning + perform) and add trigger-driven parity tests as acceptance evidence.

---

## 1) Current-State Gap Audit (Code Evidence)

### Confidence: HIGH

### 1.1 Trigger plumbing is ready for richer planning input

- `lib/chimeway/trigger.ex` already passes `:notifier` and `:trigger_params` into dispatcher options.
- Both sync and Oban dispatch paths call `Chimeway.DeliveryPlanning` (`dispatch/sync.ex` and `dispatch/oban.ex`), so one planner change can enforce parity.

### 1.2 Planner cannot currently persist delayed-fallback intent

- `lib/chimeway/delivery_planning.ex` resolves channels and calls `Deliveries.plan_delivery(notification.id, channel)` with no path to set `delay_fallback`.
- `lib/chimeway/deliveries.ex` exposes `plan_delivery/2` only; insert attributes do not include delayed-fallback control.
- `lib/chimeway/delivery.ex` already has `field(:delay_fallback, :boolean, default: false)`, so persistence support exists in schema but is not wired in planning.

### 1.3 Notifier contract lacks explicit delayed-fallback intent callback

- `lib/chimeway/notifier.ex` currently defines optional `channels/2`, but no callback for delayed-fallback channel intent.
- Without this callback, delayed fallback cannot be declared at notifier-definition level in trigger-driven flows.

### 1.4 Perform-time suppression path is already correct

- `lib/chimeway/dispatch/sync.ex` and `lib/chimeway/dispatch/oban_worker.ex` both evaluate policy with `check_read_state: delivery.delay_fallback` before adapter execution.
- `lib/chimeway/policy.ex` correctly suppresses with `{:suppress, :already_read}` when `read_at` is present and read-state check is enabled.
- `lib/chimeway/deliveries.ex` persists suppression reason and `metadata["policy_checkpoint"]`, preserving explainability.

### 1.5 Existing tests demonstrate behavior, but mostly fixture-first for POLC-03

- `test/chimeway/policy/delayed_fallback_test.exs`, `dispatch/sync_test.exs`, and `dispatch/oban_test.exs` verify perform-time suppression and zero-attempt behavior.
- Most delayed-fallback scenarios set `delay_fallback: true` via fixture helpers (`test/support/chimeway/dispatch_helpers.ex`) rather than through trigger planning.
- `test/chimeway/integration/delivery_lifecycle_test.exs` has trigger-driven fanout coverage but no trigger-driven delayed-fallback runtime wiring assertions yet.

---

## 2) POLC-03 Contract for Phase 7

### Confidence: HIGH

For Phase 7 to satisfy POLC-03 in runtime (not just fixtures), all must be true:

1. **Planning truth**: trigger-driven planning persists `delay_fallback: true` for channels explicitly marked as delayed fallback.
2. **Suppression truth**: when the linked in-app notification is read before perform time, outbound delivery is suppressed with `suppression_reason: "already_read"`.
3. **Execution truth**: suppressed delayed-fallback deliveries make zero adapter calls and record zero attempts.
4. **Parity truth**: sync and Oban paths produce equivalent suppression outcomes (`status`, `suppression_reason`, `metadata["policy_checkpoint"]`, `attempt_count`).
5. **Explainability truth**: decision source for delayed-fallback intent is queryable (default/notifier/policy).

---

## 3) Recommended Additive Architecture

### Confidence: HIGH

### 3.1 Notifier behavior extension (backward-compatible)

Add optional callback:

- `@callback delayed_fallback_channels(map(), map()) :: {:ok, [atom() | String.t()]} | {:error, term()}`
- `@optional_callbacks delayed_fallback_channels: 2`

Rules:

- Keep `channels/2` focused on delivery channel selection only.
- `delayed_fallback_channels/2` expresses subset intent over resolved channels.
- Missing callback means "no explicit delayed fallback intent" (default false unless override says otherwise).

### 3.2 Deliveries API extension (backward-compatible)

Add additive API:

- `plan_delivery/3` accepting options such as:
  - `delay_fallback: boolean()`
  - `delayed_fallback_source: :default | :notifier | :policy`

Compatibility:

- Keep `plan_delivery/2` and delegate internally to `plan_delivery/3` with defaults.
- Preserve existing idempotent unique key behavior `(notification_id, channel)`.

### 3.3 Shared planner delayed-fallback resolver

Implement in `lib/chimeway/delivery_planning.ex`:

1. Resolve normal channels (`channels/2` or fallback).
2. Resolve delayed-fallback channels using deterministic precedence:
   - notifier explicit override
   - policy/config override
   - default false
3. Enforce strict subset validation:
   - delayed-fallback channels must be subset of resolved channels
   - reject unknown channels with typed planner error (no silent coercion)
4. Enforce safety invariant:
   - never mark `in_app` as delayed fallback
5. Persist `delay_fallback` and source metadata via `plan_delivery/3`.

### 3.4 Keep dual-checkpoint suppression unchanged

- Keep planning checkpoint for early preference suppression.
- Keep perform checkpoint as final gate for read-state drift.
- No adapter call should occur after perform-time suppression in either dispatch path.

### 3.5 Explainability contract hardening

Retain current suppression contract and extend metadata:

- Authoritative fields remain:
  - `delivery.status`
  - `delivery.suppression_reason`
  - `delivery.metadata["policy_checkpoint"]`
- Add delayed-fallback provenance metadata, e.g.:
  - `delivery.metadata["delayed_fallback_source"]`
- Keep suppression reason taxonomy strict for this phase:
  - `channel_disabled`
  - `already_read`

---

## 4) Implementation Recommendations (Order)

### Confidence: HIGH

1. Extend `Notifier` behavior with optional `delayed_fallback_channels/2` callback and docs.
2. Introduce `Deliveries.plan_delivery/3` with defaults; keep `plan_delivery/2` intact.
3. Implement delayed-fallback resolution/validation in `DeliveryPlanning`.
4. Wire provenance metadata for delayed-fallback source.
5. Add trigger-driven delayed-fallback integration and parity coverage.
6. Keep fixture-based tests as branch-level guards, but do not use them as sole Phase 7 acceptance evidence.

---

## 5) Risk Register and Mitigations

| Risk | Severity | Why It Matters | Mitigation |
|------|----------|----------------|------------|
| Delayed-fallback intent drifts between sync and Oban | High | Different runtime behavior breaks POLC-03 parity | Keep all intent resolution in shared `DeliveryPlanning`; dispatchers consume planned rows only |
| Invalid delayed-fallback channel declarations silently pass | High | Hidden policy bugs and hard-to-explain suppression behavior | Fail planning with typed errors when delayed-fallback channels are not a subset of resolved channels |
| `in_app` accidentally marked delayed fallback | High | Could suppress the very read-state signal delayed fallback depends on | Hard guard in planner: never set delayed fallback on `in_app`; test this invariant directly |
| Backward compatibility break for existing notifiers | Medium | Existing adopters may not implement new callback immediately | Make callback optional and default to current behavior (`delay_fallback: false`) |
| Metadata drift reduces operator explainability | Medium | Harder to debug why delayed fallback was or was not applied | Persist stable `delayed_fallback_source` key and assert in tests/traces |
| Fixture-only tests mask runtime regressions | Medium | False confidence on POLC-03 closure | Require trigger-driven evidence in sync + Oban parity matrix and integration suite |

---

## 6) Test Strategy Mapped to POLC-03

### Confidence: HIGH

| POLC-03 Behavior | Primary Evidence Targets | Notes |
|------------------|--------------------------|-------|
| Runtime planning sets `delay_fallback` from trigger flow | `test/chimeway/integration/delivery_lifecycle_test.exs` (new trigger-driven delayed-fallback scenario), `test/chimeway/dispatch/oban_test.exs` | Assert planned delivery row has `delay_fallback: true` without fixture-only injection |
| Read-state suppresses outbound delivery at perform checkpoint | `test/chimeway/dispatch/sync_test.exs`, `test/chimeway/dispatch/oban_test.exs`, `test/chimeway/policy/delayed_fallback_test.exs` | Assert `status: :suppressed`, `suppression_reason: "already_read"` |
| Suppression creates zero attempts and no adapter call | `test/chimeway/policy/delayed_fallback_test.exs`, `test/chimeway/dispatch/oban_worker_test.exs` | Assert attempt_count = 0 and adapter delivery list remains empty |
| Checkpoint/source explainability remains durable | `test/chimeway/dispatch/sync_test.exs`, `test/chimeway/dispatch/oban_test.exs`, trace-related tests if extended | Assert `metadata["policy_checkpoint"]` and delayed-fallback source metadata |
| Additive compatibility for existing notifiers | `test/chimeway/integration/delivery_lifecycle_test.exs`, notifier contract tests | Existing notifier modules without new callback still plan and dispatch normally |

Recommended new assertions:

- Trigger-path delayed-fallback scenario proving `delay_fallback` is persisted by planner, then consumed by perform-time policy.
- Validation failure test for delayed-fallback channel not in resolved channels.
- Guard test ensuring `in_app` is never flagged as delayed fallback.

---

## Validation Architecture

Use fast targeted feedback during implementation, then run the full suite via project aliases before completion.

- **Quick loop (targeted POLC-03 paths):**
  - `mix test test/chimeway/policy/delayed_fallback_test.exs test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/dispatch/oban_worker_test.exs test/chimeway/integration/delivery_lifecycle_test.exs`
- **Full suite (project convention alias):**
  - `mix ci.test`
- **Pre-close full gate (recommended):**
  - `mix ci`

Sampling policy:

- After each task-sized change: run quick loop.
- After each wave and before verification sign-off: run full suite.
- Before phase completion claim: run `mix ci` to ensure lint + tests are both green.

---

## 7) Readiness Verdict

Phase 7 is ready for planning and implementation. The architecture is already close to complete; the remaining work is explicit delayed-fallback intent wiring at planning time plus trigger-driven verification evidence that closes the POLC-03 runtime gap.

## RESEARCH COMPLETE

- POLC-03 gap and closure path are fully scoped.
- Recommendations are additive and backward-compatible.
- Validation commands are aligned with repository test/CI conventions.

---

*Research completed: 2026-04-24*  
*Overall confidence: HIGH*

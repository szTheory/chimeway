# Phase 8 Research: Trigger Dispatch Outcome Surfacing

**Phase**: 8 - Trigger Dispatch Outcome Surfacing  
**Requirements**: DLVR-04, OPS-01  
**Researched**: 2026-04-24  
**Status**: RESEARCH COMPLETE

---

## Executive Summary

Phase 8 is a trigger contract hardening phase. The current trigger pipeline persists events and notifications correctly, but it does not expose dispatch/enqueue outcomes to callers. In `Chimeway.Trigger.dispatch_after_trigger/4`, dispatcher errors are logged and discarded, then the original `{:ok, map}` response is returned unchanged.

The recommended implementation is additive and backward-compatible:

1. Keep top-level trigger tuples unchanged (`{:ok, map} | {:duplicate, event} | {:error, reason}`).
2. Enrich the `{:ok, map}` payload with caller-visible dispatch/enqueue outcome metadata.
3. Surface durable trace pointers (`event_id`, `correlation_id`, `delivery_ids`) in the same payload.
4. Preserve duplicate idempotency behavior exactly (`{:duplicate, event}` remains non-dispatching).

---

## Current-State Code Audit

### Confidence: HIGH

### 1) Trigger currently swallows dispatcher failures

- `lib/chimeway/trigger.ex` calls `dispatcher.dispatch/2` in `dispatch_after_trigger/4`.
- On success it ignores deliveries (`{:ok, _deliveries} -> :ok`).
- On failure it logs warning and still returns the original trigger result.
- Net effect: caller cannot distinguish "event persisted + dispatch succeeded" from "event persisted + dispatch failed."

### 2) Trigger envelope has no dispatch outcome or trace pointer contract

- `normalize_trigger_result/3` currently returns:
  - `event`
  - `notification_key`
  - `notification_version`
  - `idempotency_key`
  - `recipients`
  - `notifications_inserted`
- Missing for Phase 8:
  - dispatch/enqueue status summary
  - failure reason visibility
  - direct trace pointers tied to dispatcher outputs

### 3) Dispatcher contracts already provide enough signal

- `lib/chimeway/dispatch/sync.ex`: returns `{:ok, [Delivery.t()]}` or `{:error, {:planning_failed, reason}} | {:error, term}`.
- `lib/chimeway/dispatch/oban.ex`: returns `{:ok, [Delivery.t()]}` (planned rows, enqueue side-effect performed) or `{:error, {:planning_failed, reason}} | {:error, term}`.
- These contracts are already structured enough for trigger-level surfacing without changing top-level tuples.

### 4) Durable trace linkage primitives already exist

- `Event` already stores `id` and `correlation_id`.
- Delivery rows already contain durable `id`.
- `Chimeway.Traces.get_trace/1` and `find_traces_by_correlation_id/1` already support operator lookup by those fields.

---

## Recommended Caller Outcome Contract

### Confidence: HIGH

For `{:ok, result}` responses, enrich payload with additive keys:

```elixir
%{
  # existing keys...
  dispatch_outcome: :ok | {:error, term()},
  dispatch_mode: :sync | :oban | :unknown,
  trace: %{
    event_id: event.id,
    correlation_id: event.correlation_id,
    delivery_ids: [delivery.id, ...]
  }
}
```

Rules:

1. **Tuple compatibility:** keep return shape `{:ok, map}`.
2. **Failure visibility:** when dispatcher returns `{:error, reason}`, include `dispatch_outcome: {:error, reason}`.
3. **Stage-aware parity:** sync and Oban both expose `delivery_ids`, but semantics remain stage-aware:
   - sync: IDs correspond to immediate execution attempts/outcomes
   - oban: IDs correspond to accepted planned/enqueued delivery rows
4. **Duplicate contract unchanged:** `{:duplicate, event}` remains non-dispatching and does not run dispatcher.

---

## Implementation Notes (Planner-Ready)

### Confidence: HIGH

### 1) Trigger envelope enrichment in one seam

Primary target:
- `lib/chimeway/trigger.ex`

Apply changes in:

- `normalize_trigger_result/3` (seed default dispatch metadata for `{:ok, map}`)
- `dispatch_after_trigger/4` (replace swallow-and-log behavior with payload enrichment)
- helper functions (new private helpers for mode detection and trace map construction)

### 2) Keep dispatcher contracts unchanged unless contract gap is discovered

Primary references:
- `lib/chimeway/dispatch/sync.ex`
- `lib/chimeway/dispatch/oban.ex`

Expected approach:
- rely on existing `{:ok, deliveries}` / `{:error, reason}` shapes
- avoid changing dispatch return tuple contracts in this phase unless tests prove ambiguity

### 3) Contract and regression coverage

Primary targets:
- `test/chimeway/trigger_pipeline_test.exs`
- `test/chimeway/integration/delivery_lifecycle_test.exs`
- `test/chimeway/dispatch/sync_test.exs`
- `test/chimeway/dispatch/oban_test.exs`
- `test/chimeway/traces_test.exs` (only if additional trace assertion is needed)

Minimum new evidence:
- trigger returns `dispatch_outcome` and `trace` on success
- trigger returns `dispatch_outcome: {:error, reason}` on dispatch failure while keeping `{:ok, map}`
- duplicate trigger still returns `{:duplicate, event}` and does not dispatch
- sync vs Oban both expose caller-usable trace pointers

---

## Risk Register

| Risk | Severity | Why It Matters | Mitigation |
|------|----------|----------------|------------|
| Dispatch failure remains opaque | High | Caller retries/support behavior stays blind | Make `dispatch_outcome` mandatory in every `{:ok, map}` response |
| Correlation pointers mismatch durable rows | High | Operators cannot reconstruct lifecycle from trigger return | Build trace pointers directly from persisted `event` + dispatcher delivery structs |
| Duplicate path accidentally dispatches | High | Violates idempotency semantics and can send duplicate notifications | Keep `{:duplicate, event}` short-circuit unchanged and test explicitly |
| Breaking existing callers that pattern-match minimal fields | Medium | Compatibility regression for host apps | Additive map keys only; do not remove/rename existing keys |
| Over-sharing sensitive failure internals | Medium | Error payload may leak adapter internals | Preserve existing dispatcher reason contracts; avoid embedding raw payload data |

---

## Validation Architecture

Use a two-loop strategy: targeted trigger/dispatch loop during development, then full suite before close.

### 1) Quick targeted loop

- `mix test test/chimeway/trigger_pipeline_test.exs test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/integration/delivery_lifecycle_test.exs`

Purpose:
- verify trigger contract enrichment
- verify sync/Oban caller-outcome parity surfaces
- verify duplicate semantics remain intact

### 2) Trace linkage confidence loop

- `mix test test/chimeway/traces_test.exs`

Purpose:
- confirm trigger-surfaced pointers still map cleanly to trace APIs

### 3) Full quality gate

- `mix ci`

Purpose:
- enforce compile/lint/test quality bars before phase sign-off

### 4) Static contract checks

- `rg "dispatch_outcome" lib/chimeway/trigger.ex test/chimeway/**/*.exs`
- `rg "correlation_id|event_id|delivery_ids" lib/chimeway/trigger.ex test/chimeway/**/*.exs`
- `rg "\\{:duplicate, event\\}" lib/chimeway/trigger.ex test/chimeway/**/*.exs`

Expected:
- trigger code and tests both assert new outcome fields
- duplicate path assertions remain present and explicit

---

## Suggested File Touch Set

| File | Why |
|------|-----|
| `lib/chimeway/trigger.ex` | Primary outcome surfacing and trace pointer enrichment |
| `test/chimeway/trigger_pipeline_test.exs` | Trigger response contract assertions |
| `test/chimeway/integration/delivery_lifecycle_test.exs` | End-to-end caller-visible outcome evidence |
| `test/chimeway/dispatch/sync_test.exs` | Sync path contract parity evidence |
| `test/chimeway/dispatch/oban_test.exs` | Oban enqueue path contract parity evidence |
| `test/chimeway/traces_test.exs` | Trace lookup linkage confidence (if needed for new assertions) |

---

## Recommended Plan Split

1. **Plan 08-01** — Implement trigger outcome envelope enrichment and dispatch failure surfacing in `trigger.ex`.
2. **Plan 08-02** — Validate sync/Oban stage-aware outcome semantics and add trigger-focused dispatch contract tests.
3. **Plan 08-03** — Add integration and trace-link evidence proving caller outcomes map to durable trace lookups.

---

## RESEARCH COMPLETE

- Phase 8 implementation approach is fully scoped and aligned to decisions D-01 through D-09.
- Recommended plan split covers both required IDs (`DLVR-04`, `OPS-01`) with explicit verification paths.
- Validation strategy is ready for execution with targeted and full-suite commands.

---

*Research completed: 2026-04-24*  
*Overall confidence: HIGH*

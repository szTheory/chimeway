# Phase 6 Pattern Map: Delivery Planning and Policy Checkpoint Repair

**Phase**: 06  
**Generated**: 2026-04-24  
**Source inputs**: `06-CONTEXT.md`, `06-RESEARCH.md`

---

## Pattern 1: Planner-then-dispatch separation

- **Target files**: `lib/chimeway/delivery_planning.ex`, `lib/chimeway/dispatch/sync.ex`, `lib/chimeway/dispatch/oban.ex`
- **Closest analog**: `lib/chimeway/dispatch/sync.ex` (`dispatch_notification/1` + `evaluate_and_dispatch/1`)
- **Pattern to preserve**:
  - Planner step is deterministic and row-first.
  - Dispatch step is side-effectful and runs only after row state is valid.
- **Notes**:
  - Replace hardcoded `:in_app` planning with shared fanout planner.
  - Keep terminal-state guards in execution path.

---

## Pattern 2: Idempotent row creation by unique key

- **Target files**: `lib/chimeway/delivery_planning.ex`, `lib/chimeway/deliveries.ex`
- **Closest analog**: `lib/chimeway/deliveries.ex` (`plan_delivery/2`)
- **Pattern to preserve**:
  - Use `Repo.insert(on_conflict: :nothing, conflict_target: [...])`.
  - Re-read authoritative row after insert attempt.
- **Notes**:
  - Channel normalization must happen before `plan_delivery/2` call.
  - Keep deterministic channel ordering to avoid fanout jitter.

---

## Pattern 3: Shared policy contract at multiple checkpoints

- **Target files**: `lib/chimeway/delivery_planning.ex`, `lib/chimeway/dispatch/oban_worker.ex`, `lib/chimeway/dispatch/sync.ex`
- **Closest analog**: `lib/chimeway/policy.ex` (`evaluate/2`)
- **Pattern to preserve**:
  - One policy API with explicit opts (`check_read_state:`).
  - Suppression is explicit (`{:suppress, reason}`), never silent.
- **Notes**:
  - Add metadata marker for checkpoint source (`planning` or `perform`) for trace clarity.
  - Oban enqueue must respect planning suppression status.

---

## Pattern 4: Adapter outcome classification at dispatch boundary

- **Target files**: `lib/chimeway/dispatch/sync.ex`, `lib/chimeway/dispatch/oban_worker.ex`, optional shared helper module
- **Closest analog**:
  - `lib/chimeway/dispatch/sync.ex` (`do_dispatch/1`)
  - `lib/chimeway/dispatch/oban_worker.ex` (`do_dispatch/1`)
- **Pattern to preserve**:
  - Dispatcher classifies adapter outcomes (`:succeeded`, `:failed`, `:rejected`, `:bounced`).
  - Persist attempt row and transition delivery atomically through `Deliveries.record_attempt/2`.
- **Notes**:
  - Phase 6 can extract a shared execution helper to prevent sync/worker drift.

---

## Pattern 5: Behavior-driven test parity across sync and Oban

- **Target files**: `test/chimeway/dispatch/sync_test.exs`, `test/chimeway/dispatch/oban_test.exs`, `test/chimeway/integration/delivery_lifecycle_test.exs`
- **Closest analog**:
  - Existing sync dispatch outcome tests in `sync_test.exs`
  - Existing Oban enqueue/worker tests in `oban_test.exs`
- **Pattern to preserve**:
  - Assert behavior, not implementation details.
  - Keep deterministic fixture setup (`test/support/chimeway/dispatch_helpers.ex`).
- **Notes**:
  - Add parity assertions for planning-time policy enforcement and fanout row counts.

---

## Planned File Touch Map

| File | Role | Why touched in Phase 6 |
|------|------|-------------------------|
| `lib/chimeway/notifier.ex` | Contract | Add `channels/2` callback + fallback/deprecation semantics |
| `lib/chimeway/trigger.ex` | Orchestration | Pass notifier and trigger params through dispatch seam |
| `lib/chimeway/delivery_planning.ex` | New shared planner | Expand recipient x channel intents + planning policy checks |
| `lib/chimeway/dispatch/sync.ex` | Sync strategy | Replace inline planning with shared planner output |
| `lib/chimeway/dispatch/oban.ex` | Oban strategy | Run planning policy before enqueue and skip suppressed rows |
| `lib/chimeway/dispatch/oban_worker.ex` | Perform-time strategy | Preserve perform-time checks and checkpoint metadata |
| `lib/chimeway/deliveries.ex` | Persistence API | Add checkpoint-aware suppression metadata helper(s) |
| `lib/chimeway/traces.ex` | Explainability | Surface suppression checkpoint source in timeline details |
| `test/chimeway/dispatch/sync_test.exs` | Verification | Fanout + planning policy tests for sync |
| `test/chimeway/dispatch/oban_test.exs` | Verification | Enqueue parity + suppression non-enqueue tests |
| `test/chimeway/trigger_pipeline_test.exs` | Verification | Recipient identity + channels fanout contract tests |
| `test/chimeway/integration/delivery_lifecycle_test.exs` | Verification | Standard outbound success spine with fanout |


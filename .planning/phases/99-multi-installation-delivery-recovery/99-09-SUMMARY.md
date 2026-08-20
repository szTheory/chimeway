---
phase: 99-multi-installation-delivery-recovery
plan: "09"
subsystem: delivery
tags: [elixir, ecto, push, sync-dispatch, delivery-targets, idempotency]
requires:
  - phase: 99-multi-installation-delivery-recovery
    provides: durable tenant-scoped DeliveryTarget claims and aggregate delivery results
provides:
  - Deterministic synchronous fan-out over every actionable push target
  - Exact target-ID claims for all sync adapter handoffs
  - Regression evidence for ordered, concurrent, mixed-outcome, and empty-target dispatch
affects: [phase-100-apns]
tech-stack:
  added: []
  patterns:
    - Snapshot actionable target IDs before sync execution
    - Continue independent target claims after target-level errors
    - Return the recomputed canonical delivery aggregate
key-files:
  created:
    - .planning/phases/99-multi-installation-delivery-recovery/99-09-SUMMARY.md
  modified:
    - lib/chimeway/dispatch/sync.ex
    - test/chimeway/delivery_target_test.exs
key-decisions:
  - "[99-09]: Sync snapshots ordered actionable target rows, then claims each exact durable ID through Executor.run_target/2."
  - "[99-09]: Target-level errors do not short-circuit sibling attempts; the canonical delivery is recomputed after the complete snapshot."
  - "[99-09]: A succeeded aggregate denotes provider acceptance for one or more targets, never device receipt."
metrics:
  duration: 3m
  completed: 2026-08-20
status: complete
---

# Phase 99 Plan 09: Deterministic Sync Push Fan-Out Summary

**Synchronous push dispatch now claims and executes every ordered eligible installation target, then returns the authoritative aggregate delivery result.**

## Accomplishments

- Added a stable `actionable_targets/1` snapshot to synchronous push dispatch and executes each exact target ID with `source: "sync"`.
- Preserved `begin_target_attempt/2` as the only provider-handoff authority, including repeated and concurrent no-op claims.
- Continued after individual target errors, recomputed the parent after the full snapshot, and retained no-target suppression.
- Added adapter observations and exact attempt-count assertions for two-target, repeated, concurrent, mixed-outcome, and empty-target paths.

## Task Commits

1. **Task 1 RED: multi-target sync regression matrix** — `72a6d5c`.
2. **Task 1 GREEN: deterministic all-target sync execution** — `505a4a7`.

## Verification

- `mix format --check-formatted lib/chimeway/dispatch/sync.ex test/chimeway/delivery_target_test.exs` — passed.
- `env MIX_ENV=test mix test test/chimeway/delivery_target_test.exs test/chimeway/dispatch/target_worker_test.exs test/chimeway/integration/delivery_lifecycle_test.exs --warnings-as-errors` — passed (33 tests, 0 failures).
- `git diff --exit-code -- mix.exs mix.lock` — passed; no dependency changes.

## Decisions Made

- The durable `DeliveryTarget` remains the plural sync execution unit; `Delivery` remains the one canonical logical result.
- Stable target ordering comes from `DeliveryTargets.actionable_targets/1`, and each ID still enters via the durable target claim seam.
- A terminal successful aggregate is provider-acceptance evidence only and does not claim all-device delivery or receipt.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Surface Scan

No new endpoint, auth, file-access, schema, or external provider surface was introduced. The existing tenant-qualified target snapshot and atomic claim seam remain the provider authority.

## Self-Check: PASSED

- `lib/chimeway/dispatch/sync.ex` and `test/chimeway/delivery_target_test.exs` exist.
- Task commits `72a6d5c` and `505a4a7` are present in git history.
- The focused format and warning-free test verification passed.

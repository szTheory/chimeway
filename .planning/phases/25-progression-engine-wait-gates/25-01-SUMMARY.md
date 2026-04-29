---
phase: 25-progression-engine-wait-gates
plan: 01
subsystem: workflows
tags: [elixir, ecto, workflows, progression, notifier, contract]

# Dependency graph
requires:
  - phase: 24-workflow-contracts-state-spine
    provides: durable workflow definition/run/transition spine and persisted string-keyed step config
provides:
  - Replay-safe `progress` step config DSL with curated `wait_until` and `on_outcome` rule shapes
  - Pure `Chimeway.Workflows.ProgressionOutcome.from_delivery/2` mapper covering the D-04 vocabulary
  - Tagged normalization errors for invalid anchors, outcomes, blank `to_step`, mixed shapes, and non-positive delays
  - Unit and contract tests freezing the persisted rule shape and mapper outputs
affects:
  - 25-02-progression-engine
  - 25-03-wait-gates-and-due-step-worker
  - 26-stop-conditions-escalation
  - traces explanation surfaces for workflow transitions

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Pure mapper module driven by canonical Ecto schema struct fields (no Repo access)
    - String-keyed durable rule shapes with atom-key normalization at the declaration boundary
    - Tagged `{:workflow_resolution_failed, {:invalid_workflow_progress_rule, reason}}` errors

key-files:
  created:
    - lib/chimeway/workflows/progression_outcome.ex
    - test/chimeway/workflows/progression_outcome_test.exs
  modified:
    - lib/chimeway/notifier.ex
    - test/chimeway/notifier_contract_test.exs

key-decisions:
  - "Persist `progress` rules under string keys only and reject mixed wait/outcome bodies before any workflow definition is persisted (D-06/D-08)."
  - "Curated workflow-outcome vocabulary is the only set authoring rules and runtime branch resolution may use; both notifier normalization and `ProgressionOutcome.from_delivery/2` share the same six values plus `:not_branchable_yet` (D-04/D-05)."
  - "`prior_delivery_terminal_at` is the only Phase 25 wait anchor; other anchors fail normalization rather than no-op at runtime (D-01)."
  - "`ProgressionOutcome.from_delivery/2` returns primitive evidence (`delivery_status`, `suppression_reason`, `attempt_outcome`, `attempt_error_class`) so workflow transitions can replay branch decisions from durable rows alone (D-12)."
  - "Cancelled deliveries with unknown `suppression_reason` collapse to `:not_branchable_yet` so workflow rules never advance on a meaning the contract did not assign."

patterns-established:
  - "Pattern: Durable string-keyed DSL with atom-key normalization at the boundary, mirroring the Phase 11 string-channel idiom and the Phase 24 string-keyed workflow serialization."
  - "Pattern: Pure outcome mapper that lives next to the curated vocabulary it produces, so authoring-time validation and runtime resolution share one stable set."

requirements-completed: [WRK-02]

# Metrics
duration: 6min
completed: 2026-04-29
---

# Phase 25 Plan 01: Workflow Progression Contract Summary

**Replay-safe `progress` step DSL plus the pure `ProgressionOutcome.from_delivery/2` mapper that share the curated `delivered`/`suppressed`/`temporary_failure`/`retries_exhausted`/`permanent_failure`/`bounced` vocabulary.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-04-29T18:57:53Z
- **Completed:** 2026-04-29T19:03:18Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Locked the persisted workflow `progress` rule shape — string-keyed `wait_until` (anchor + delay_seconds + to_step) and `on_outcome` (outcome + to_step) rules — before any runtime engine is wired, so later plans cannot invent new shapes.
- Added a single pure `Chimeway.Workflows.ProgressionOutcome.from_delivery/2` mapper that derives one of the six curated workflow outcomes plus replay-safe primitive evidence from canonical `Chimeway.Delivery` (and optional `Chimeway.DeliveryAttempt`) facts, or returns `:not_branchable_yet` for non-terminal and degenerate cancelled rows.
- Froze the contract with 14 new test cases — string-keyed serialization round-trip, tagged-error coverage for every invalid rule shape, and exhaustive vocabulary coverage including `:pending`/`:dispatched`/`:digested` and unknown-reason cancelled rows.

## Task Commits

Each task was committed atomically (TDD RED → GREEN):

1. **Task 1: Add RED coverage for progression rule normalization and curated outcome mapping** — `abff81b` (test)
2. **Task 2: Normalize step progress rules and implement the pure progression outcome mapper** — `886ecdc` (feat)

_Note: Task 1 is the RED gate; Task 2 is the GREEN gate. No REFACTOR commit was needed — the GREEN implementation kept the helpers small and the public surface minimal._

## Files Created/Modified

- `lib/chimeway/workflows/progression_outcome.ex` (created) — Pure `from_delivery/2` mapper returning `{:branchable, outcome, evidence}` or `:not_branchable_yet`, with explicit head clauses for each curated outcome and a catch-all `:not_branchable_yet` for `:pending`/`:dispatched`/`:digested` and unknown cancelled buckets.
- `lib/chimeway/notifier.ex` (modified) — `normalize_workflow_config/1` now validates an optional `config["progress"]` list of rule maps. Adds `normalize_workflow_progress_rule/1` plus `wait_until` and `on_outcome` normalizers that enforce exact key sets, the `prior_delivery_terminal_at` anchor allow-list, the curated outcome allow-list, positive-integer `delay_seconds`, and non-blank `to_step`. All errors flow through `{:workflow_resolution_failed, {:invalid_workflow_progress_rule, reason}}`.
- `test/chimeway/notifier_contract_test.exs` (modified) — Added `ProgressWorkflowNotifier`, a positive normalization+serialization round-trip test, and a single test asserting tagged errors for invalid anchor, invalid outcome, blank `to_step`, mixed wait/outcome rule bodies, unknown rule kinds, and non-positive `delay_seconds`.
- `test/chimeway/workflows/progression_outcome_test.exs` (created) — 13 unit tests covering all six curated outcomes (with attempt-evidence shapes for failure variants), all three non-branchable canonical states, attempt-evidence-only inputs, and unknown/nil cancelled `suppression_reason` collapsing to `:not_branchable_yet`.

## Decisions Made

- **String-keyed persistence only.** `progress` rules are normalized into purely string-keyed maps; atom keys are accepted at the declaration boundary and immediately converted, so persisted JSON has one canonical shape.
- **Single anchor, single outcome set.** `prior_delivery_terminal_at` is the only Phase 25 wait anchor and the curated vocabulary is the only `on_outcome` value set. Anything else fails normalization with a tagged error before persistence (D-01/D-04/D-06).
- **Mapper returns evidence, not just a label.** `ProgressionOutcome.from_delivery/2` always emits `{outcome, evidence}` so workflow transitions can persist the supporting facts in one shot — operators can replay why a branch fired without a callback round-trip (D-12).
- **Unknown cancelled buckets stay unbranchable.** Cancelled rows whose `suppression_reason` is not in the curated set return `:not_branchable_yet` rather than collapsing into one of the failure outcomes; this keeps the contract closed-set instead of "something-like-failure".

## Deviations from Plan

None - plan executed exactly as written.

The acceptance criteria for Tasks 1 and 2 mentioned a few literal substring checks that the implementation also satisfies as a side effect (`:not_branchable_yet`, `"retries_exhausted"`, `"prior_delivery_terminal_at"`, `"wait_until"`, `"on_outcome"`, `workflow_resolution_failed`, `def from_delivery`). All literals appear in the committed code and tests.

## Issues Encountered

- Initial `mix test` invocation failed with `Unchecked dependencies for environment test`; resolved with `mix deps.get`. This is normal first-run behavior in a fresh worktree and not a deviation from the plan.

## Threat Flags

None. The trust boundaries and STRIDE register from the plan (`T-25-01` notifier rule normalization, `T-25-02` outcome mapper evidence, `T-25-03` data-first DSL) were all `mitigate` dispositions and are implemented exactly as specified — exact-key validation, primitive-only evidence, and rejection of any non-string-keyed or non-data rule shapes.

## Known Stubs

None. No empty arrays/objects, placeholder text, or unwired components introduced.

## TDD Gate Compliance

- RED gate satisfied: `abff81b test(25-01): add failing coverage for progression rules and outcome mapping` (verified failing with 14 failures before implementation).
- GREEN gate satisfied: `886ecdc feat(25-01): normalize step progress rules and curate workflow outcomes` (all 26 tests in the targeted suites pass after implementation).
- No REFACTOR commit was necessary; implementation landed clean and small.

## Next Phase Readiness

- Plan 25-02 (progression engine) can build on `ProgressionOutcome.from_delivery/2` directly — it is pure, takes preloaded structs, and persists no state of its own, which keeps the engine's transactional progression code free of branching semantics.
- Plan 25-03 (wait gates / due-step worker) can rely on the now-frozen `wait_until` rule shape (`anchor`, `delay_seconds`, `to_step`) and the explicit `:not_branchable_yet` signal as the only "wait" answer the mapper ever gives.
- No new blockers; existing `Delivery.status` / `suppression_reason` semantics are sufficient to source every curated outcome from durable rows.

---

## Self-Check: PASSED

Verified before returning:

- `[ -f lib/chimeway/workflows/progression_outcome.ex ]` → FOUND
- `[ -f test/chimeway/workflows/progression_outcome_test.exs ]` → FOUND
- `git log --oneline --all | grep abff81b` → FOUND `abff81b test(25-01): add failing coverage for progression rules and outcome mapping`
- `git log --oneline --all | grep 886ecdc` → FOUND `886ecdc feat(25-01): normalize step progress rules and curate workflow outcomes`
- `mix test test/chimeway/notifier_contract_test.exs test/chimeway/workflows/progression_outcome_test.exs` → 26 tests, 0 failures

---

*Phase: 25-progression-engine-wait-gates*
*Plan: 01*
*Completed: 2026-04-29*

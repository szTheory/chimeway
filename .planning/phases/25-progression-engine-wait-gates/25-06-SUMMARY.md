---
phase: 25-progression-engine-wait-gates
plan: "06"
subsystem: workflow-progression
tags: [documentation, gap-closure, wr-02, temporary_failure, early-fire-warning]
dependency_graph:
  requires: [25-03]
  provides: [WR-02 gap closure via documentation]
  affects: [lib/chimeway/notifier.ex, lib/chimeway/workflows/progression_outcome.ex]
tech_stack:
  added: []
  patterns: [operator-facing warning sections in module comments, cross-referenced dual-site documentation]
key_files:
  created: []
  modified:
    - lib/chimeway/notifier.ex
    - lib/chimeway/workflows/progression_outcome.ex
decisions:
  - "WR-02 resolved via option (b): document early-fire behavior at both authoring boundary and runtime mapping site rather than removing temporary_failure from the vocabulary"
  - "Warning text placed as module-level code comments above @progress_outcomes (not in @moduledoc) in notifier.ex to maximize discoverability at the constant declaration site"
  - "Inline comment added at :failed clause in from_delivery/2 to ensure maintainers modifying the mapper see the caveat immediately"
  - "Reference corrected from Chimeway.Delivery to Chimeway.Deliveries for @allowed_transitions (the attribute lives in the context module, not the schema)"
metrics:
  duration: "~8 minutes"
  completed_date: "2026-04-29"
  tasks_completed: 1
  tasks_total: 1
  files_changed: 2
  lines_added: 63
  lines_removed: 0
---

# Phase 25 Plan 06: `temporary_failure` Early-Fire Warning (WR-02) Summary

## One-Liner

Added operator-facing early-fire warning for `temporary_failure` at both the authoring boundary (`Chimeway.Notifier` above `@progress_outcomes`) and the runtime mapping site (`Chimeway.Workflows.ProgressionOutcome` moduledoc + inline comment at the `:failed` clause), closing gap WR-02 via resolution option (b).

## What Was Built

Gap WR-02 identified that `temporary_failure` is a branchable outcome derived from a non-terminal `:failed` delivery row — meaning an `on_outcome temporary_failure` rule fires on the FIRST transient failure, before any retry is attempted. The 25-02 plan implemented this behavior deliberately but left no documentation warning at either the authoring boundary or the runtime mapping site.

This plan adds documentation-only warnings at both sites:

1. **`lib/chimeway/notifier.ex`** — A new `## Early-fire warning for temporary_failure (WR-02)` section inserted as code comments immediately above the `@progress_outcomes` declaration. The warning names the early-fire timing (fires on the first `:failed` row before any retry), explains the duplicate-side-effect risk (host may see both a successful primary delivery and the destination-step delivery), recommends using `retries_exhausted` if "fire after retries exhausted" is the intent, and recommends idempotency keys if early-fire escalation IS the intent. Includes a cross-reference to `Chimeway.Workflows.ProgressionOutcome` moduledoc.

2. **`lib/chimeway/workflows/progression_outcome.ex`** — A matching `## Early-fire warning for temporary_failure (WR-02)` section inserted in the `@moduledoc` between the curated vocabulary list and the D-05 paragraph. Same content as the notifier warning, with a back-reference to `Chimeway.Notifier`. An additional inline comment was added immediately above the `def from_delivery(%Delivery{status: :failed}...)` clause pointing maintainers to the moduledoc warning section.

No production semantics were changed. All 36 Phase 25 tests pass unchanged.

## Acceptance Criteria Verification

| Criterion | Result |
|-----------|--------|
| `grep -c 'Early-fire warning for \`temporary_failure\` (WR-02)'` in notifier.ex | 1 |
| `grep -c 'Early-fire warning for \`temporary_failure\` (WR-02)'` in progression_outcome.ex | 2 (moduledoc + inline comment) |
| `grep -c 'BEFORE any'` in notifier.ex | 1 (spans line but text present) |
| `grep -c 'idempotency key'` in notifier.ex | 1 |
| `grep -c 'idempotency key'` in progression_outcome.ex | 2 |
| `grep -c '@allowed_transitions'` in notifier.ex | 1 |
| `grep -c 'failed: \[:dispatched\]'` in notifier.ex | 1 |
| `grep -c 'See \`Chimeway.Workflows.ProgressionOutcome\`'` in notifier.ex | 1 |
| `grep -c 'See \`Chimeway.Notifier\`'` in progression_outcome.ex | 1 |
| Constant `~w(delivered suppressed ...)` unchanged in notifier.ex | 1 |
| `{:branchable, :temporary_failure, ...}` clause body unchanged | 1 |
| `temporary_failure` count >= 4 in notifier.ex | 4 |
| notifier.ex line count >= 735 | 768 |
| progression_outcome.ex line count >= 130 | 157 |
| 36 Phase 25 tests pass | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected module reference from `Chimeway.Delivery` to `Chimeway.Deliveries` for `@allowed_transitions`**
- **Found during:** Task 1 (Step A), reading delivery.ex
- **Issue:** The plan's warning text referenced `Chimeway.Delivery`'s `@allowed_transitions`, but that attribute lives in `lib/chimeway/deliveries.ex` (the context module `Chimeway.Deliveries`), not in `lib/chimeway/delivery.ex` (the schema module `Chimeway.Delivery`). Using the wrong module name in documentation would mislead maintainers.
- **Fix:** Changed all references to `Chimeway.Deliveries`'s `@allowed_transitions` in both warning sections and the inline comment.
- **Files modified:** lib/chimeway/notifier.ex, lib/chimeway/workflows/progression_outcome.ex
- **Commit:** dae8063

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced — this is a documentation-only change. STRIDE threats T-25-15 and T-25-16 are mitigated as specified in the plan's threat model.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | dae8063 | docs(25-06): add early-fire warning for temporary_failure (WR-02) |

## Self-Check: PASSED

- FOUND: lib/chimeway/notifier.ex
- FOUND: lib/chimeway/workflows/progression_outcome.ex
- FOUND: .planning/phases/25-progression-engine-wait-gates/25-06-SUMMARY.md
- FOUND: commit dae8063

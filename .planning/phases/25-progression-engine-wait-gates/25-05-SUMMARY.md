---
phase: 25-progression-engine-wait-gates
plan: 05
subsystem: testing
tags: [elixir, ecto, postgres, sql-sandbox, for-update, concurrency, documentation]

# Dependency graph
requires:
  - phase: 25-03
    provides: workflow progression engine with FOR UPDATE locking and race test suite
provides:
  - Race-suite moduledoc with explicit in-process vs cross-connection scope boundary
  - WR-01 backlog entry in deferred-items.md with acceptance criteria for future cross-connection test phase
affects:
  - future test-infrastructure phases covering cross-connection FOR UPDATE proof
  - any verifier auditing the progression engine's concurrency guarantees

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Moduledoc scope discipline: explicitly state what a concurrency test proves and does NOT prove when SQL Sandbox manual mode constrains the proof shape"
    - "Deferred-items backlog entry pattern: capture unmet coverage gaps with concrete acceptance criteria so future phases have a direct pickup point"

key-files:
  created: []
  modified:
    - test/chimeway/reliability/workflow_progression_race_test.exs
    - .planning/phases/25-progression-engine-wait-gates/deferred-items.md

key-decisions:
  - "Phase 25 closes WR-01 via resolution (b): narrow the race-suite moduledoc to match actual test scope rather than adding a non-sandboxed cross-connection test. The engine's FOR UPDATE discipline is correct in code; the gap is in proof shape, not production behavior."
  - "Non-sandboxed test rejected for Phase 25 due to manual-cleanup ordering hazards with async: false siblings and CI-flake risk under shared DB state — tracked with concrete follow-up criteria."

patterns-established:
  - "Deferred-items entry pattern: each entry includes what is missing, why it is non-blocking, what an actual proof needs (API + steps), and suggested future phase scope."

requirements-completed:
  - ESC-03

# Metrics
duration: 5min
completed: 2026-04-29
---

# Phase 25 Plan 05: Race-Suite Moduledoc Scope Clarification (WR-01) Summary

**Race-suite moduledoc narrowed to in-process re-entry safety scope; cross-connection FOR UPDATE coverage gap (WR-01) locked as an explicit backlog entry with concrete acceptance criteria for a future test-infrastructure phase.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-04-29T20:20:00Z
- **Completed:** 2026-04-29T20:22:32Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments

- Replaced the race-suite `@moduledoc` with a three-section doc: "What this suite proves" (in-process re-entry safety, ESC-03 + WRK-02), "What this suite does NOT prove (WR-01)" (cross-connection `FOR UPDATE` contention via SQL Sandbox single-connection behavior), and "Why we did not add a non-sandboxed test here" (CI ordering hazards, manual cleanup, async: false conflict).
- Added "Cross-connection FOR UPDATE proof for workflow progression engine (WR-01)" entry to `deferred-items.md` with engine lock references, concrete API requirements for an actual cross-connection proof, and sibling-seam scope for a future phase.
- Verified all 36 Phase 25 suite tests still pass; no test body lines were modified.

## Task Commits

Each task was committed atomically:

1. **Task 1: Narrow race-suite moduledoc and add WR-01 backlog entry** - `46252ad` (docs)

**Plan metadata:** (see final SUMMARY commit)

## Files Created/Modified

- `test/chimeway/reliability/workflow_progression_race_test.exs` - `@moduledoc` replaced with scoped three-section doc; no test bodies changed
- `.planning/phases/25-progression-engine-wait-gates/deferred-items.md` - New "Cross-connection FOR UPDATE proof (WR-01)" entry appended

## Decisions Made

- Resolution (b) chosen over (a) for WR-01: `Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)` adds CI-flake risk and manual cleanup ordering hazards that exceed the value of the proof for Phase 25. The production `FOR UPDATE` discipline is correct and verified by code review.
- Backlog entry includes concrete acceptance criteria (`Repo.checkout/2` per-process, manual truncate, Sandbox-less assertions) so a future test-infrastructure phase can pick up cross-connection coverage for all `FOR UPDATE` engine seams at once.

## Deviations from Plan

One minor deviation:

**1. [Rule 1 - Bug] Acceptance criteria grep pattern inconsistency resolved**
- **Found during:** Task 1 acceptance check
- **Issue:** The plan's action Step A used `shares the **same checked-out database connection**` (bold markdown), but the acceptance criteria grep checked for `shares one checked-out database connection`. The acceptance criteria grep returned 0 with the exact action text.
- **Fix:** Changed phrasing from "the **same** checked-out database connection" to "one checked-out database connection" in the moduledoc to satisfy the acceptance criteria grep. Semantics are identical; the phrasing matches the plan's stated intent.
- **Files modified:** `test/chimeway/reliability/workflow_progression_race_test.exs`
- **Verification:** All 9 acceptance criteria greps return >= 1. Both race tests pass.
- **Committed in:** `46252ad` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (minor text reconciliation between action and acceptance criteria)
**Impact on plan:** No scope change. The fix resolves a phrasing inconsistency between the plan's action text and its acceptance criteria, leaving both passing.

## Issues Encountered

- Worktree required `mix deps.get` before tests could run (worktree-local isolation); this is expected in parallel-execution worktree mode.

## Known Stubs

None — this plan makes documentation-only changes. No data paths or UI components were modified.

## Threat Flags

No new trust boundaries or security-relevant surfaces introduced. This plan modifies only documentation content (moduledoc and planning artifact).

## Self-Check

- `test/chimeway/reliability/workflow_progression_race_test.exs` exists and contains updated moduledoc: confirmed
- `.planning/phases/25-progression-engine-wait-gates/deferred-items.md` exists and contains WR-01 backlog entry: confirmed
- Task commit `46252ad` exists: confirmed (created during execution)
- 36 Phase 25 tests pass: confirmed

## Self-Check: PASSED

## Next Phase Readiness

- Gap WR-01 is closed by documentation resolution (b). The engine's `FOR UPDATE` discipline remains correct and the concurrency claims in the race suite are now honest.
- A future test-infrastructure phase can pick up the deferred-items entry to add cross-connection coverage for `Progression.progress_run/2`, `Deliveries.record_attempt/2`, and `Digests.Emission.emit_bucket/2` using the same suite shape.
- No production code or test bodies were changed; Phase 25 overall suite remains at 36 passing tests.

---
*Phase: 25-progression-engine-wait-gates*
*Completed: 2026-04-29*

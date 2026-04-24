---
phase: 12-oban-transactional-dispatch-consistency
plan: "12-01"
subsystem: api
tags: [oban, ecto-multi, transactional-consistency, dispatch]
requires:
  - phase: 11-02
    provides: oban dispatch baseline behavior and custom-channel regression safety net
provides:
  - Unified Oban dispatch path that runs planning and enqueue within one Repo transaction
  - Removal of runtime atom creation for transactional enqueue steps
  - Consistent caller-facing error mapping for planning, enqueue, and caller multi step failures
affects: [phase-12-verification, async-dispatch-consistency]
tech-stack:
  added: []
  patterns: [single-transaction-dispatch, ecto-multi-run-step-enqueue]
key-files:
  created: []
  modified:
    - lib/chimeway/dispatch/oban.ex
key-decisions:
  - "Use one Ecto.Multi pipeline for both plain and caller-provided multi flows."
  - "Map plan step failures to {:planning_failed, reason} and all other step failures to {:error, reason}."
patterns-established:
  - "Oban dispatch planning and enqueue should execute inside a single transaction boundary."
  - "Avoid dynamic atom generation for multi step names in dispatch paths."
requirements-completed: [INTG-03, DLVR-04]
duration: 9 min
completed: 2026-04-24
---

# Phase 12 Plan 01: atomic dispatch restructure summary

**Oban dispatch now performs delivery planning and enqueue work inside one transactional Ecto.Multi contract with stable caller-facing errors and no runtime atom creation.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-24T18:06:00Z
- **Completed:** 2026-04-24T18:15:00Z
- **Tasks:** 3
- **Files modified:** 1

## Accomplishments

- Replaced split dispatch branches with a unified `base_multi |> plan_notifications |> enqueue_jobs` flow.
- Removed `String.to_atom("enqueue_delivery_#{delivery.id}")` usage and deleted now-obsolete helper functions.
- Preserved contract-compatible result shapes by mapping planning failures to `{:error, {:planning_failed, reason}}` and all other transaction step failures to `{:error, reason}`.

## Task Commits

Each task was committed atomically:

1. **Task 12-01-01/12-01-02: unify transaction flow and error mapping** - `9b93ae2` (feat)
2. **Task 12-01-02 follow-up: base multi compatibility guard** - `5fb177a` (fix)
3. **Task 12-01-03: run focused Oban verification suite** - verification command only (no code diff)

**Plan metadata:** summary committed in docs metadata commit

## Files Created/Modified

- `lib/chimeway/dispatch/oban.ex` - Unified dispatch pipeline to run planning and enqueue in one transaction and removed dynamic-atom helper path.

## Decisions Made

- Keep the existing `DeliveryPlanning.plan_notifications/2` contract unchanged and invoke it inside `Ecto.Multi.run`.
- Reuse `enqueue_one/1` in the transactional enqueue step so telemetry behavior remains intact.

## Verification Results

- `mix test test/chimeway/dispatch/oban_transactional_test.exs test/chimeway/dispatch/oban_test.exs` -> **pass** (15 tests, 0 failures after refactor)
- `rg "String\\.to_atom" lib/chimeway/dispatch/oban.ex` -> **pass** (no matches)
- `rg "enqueue_deliveries|pending_deliveries" lib/chimeway/dispatch/oban.ex` -> **pass** (no matches)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] `multi: nil` compatibility regression after unifying dispatch path**
- **Found during:** post-refactor review before phase completion.
- **Issue:** `Keyword.get(opts, :multi, Ecto.Multi.new())` could still return `nil` or non-`Ecto.Multi` values when key is present, causing pipeline failure.
- **Fix:** Coerced `:multi` option through a struct guard fallback to `Ecto.Multi.new()`.
- **Files modified:** `lib/chimeway/dispatch/oban.ex`
- **Verification:** `mix test test/chimeway/dispatch/oban_transactional_test.exs test/chimeway/dispatch/oban_test.exs`
- **Committed in:** `5fb177a`

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Improves backward compatibility without changing the intended transactional contract.

## Issues Encountered

- Initial command from plan used `mix test --tag oban`, but this project's Mix test task does not support `--tag`. Switched to direct file-targeted `mix test` invocation.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Dispatch path is now transactionally consistent and safe from atom-table growth in enqueue step naming.
- Regression coverage can now focus on proving rollback behavior for planning rows and enqueue failures.

---
*Phase: 12-oban-transactional-dispatch-consistency*
*Completed: 2026-04-24*

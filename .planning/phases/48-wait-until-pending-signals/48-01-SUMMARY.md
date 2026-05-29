---
phase: 48-wait-until-pending-signals
plan: 01
subsystem: api
tags: [elixir, notifier, workflow, cancel_signals, dsl-validation]

requires:
  - phase: v1.6-workflow-engine
    provides: wait_until progress rules and workflow declaration normalization
provides:
  - Optional cancel_signals list validation on wait_until progress rules at notifier declaration time
  - Tagged {:invalid_cancel_signals, _} errors for invalid shapes before persistence
  - Contract tests locking accept/reject matrix for Wave 2 progression consumption
affects: [48-02, 48-03, READ-01]

tech-stack:
  added: []
  patterns:
    - "Declaration-time DSL validation with bounded string lists (max 10, trim, dedupe, omit empty key)"

key-files:
  created: []
  modified:
    - lib/chimeway/notifier.ex
    - test/chimeway/notifier_contract_test.exs

key-decisions:
  - "Omit cancel_signals key from normalized output when absent or empty (D-06 stable fixtures)"
  - "Validate cancel_signals at notifier normalization, not runtime in progression (Pitfall 1)"

patterns-established:
  - "normalize_cancel_signals/1: :unset → [], list with trim/dedupe/max-10, tagged error tuples"

requirements-completed: [READ-01]

duration: 12min
completed: 2026-05-29
---

# Phase 48 Plan 01: cancel_signals DSL Validation Summary

**Optional bounded `cancel_signals` string-list validation on `wait_until` progress rules with strict tagged errors at notifier declaration time**

## Performance

- **Duration:** 12 min
- **Started:** 2026-05-29T16:20:00Z
- **Completed:** 2026-05-29T16:32:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `normalize_cancel_signals/1` private helper with `:unset`, list, and fallback clauses
- Extended `normalize_wait_until_rule/1` allowlist and output map to include `cancel_signals` only when non-empty
- Added 7 contract tests covering accept, trim/dedupe, empty omit, blank reject, non-list reject, too_many reject, and mixed_rule_shape reject

## Task Commits

Each task was committed atomically:

1. **Task 1: Add normalize_cancel_signals/1 and extend normalize_wait_until_rule/1** - `0e2c230` (feat)
2. **Task 2: Notifier contract tests for cancel_signals accept/reject matrix** - `6450868` (test)

**Plan metadata:** `def7fdf` (docs)

## Files Created/Modified

- `lib/chimeway/notifier.ex` - `@max_cancel_signals 10`, `normalize_cancel_signals/1`, extended `normalize_wait_until_rule/1`
- `test/chimeway/notifier_contract_test.exs` - `"wait_until cancel_signals normalization (READ-01)"` describe block with 7 tests

## Decisions Made

- Followed D-06: omit `cancel_signals` key when absent or normalizes to `[]` (explicit empty list also omits key)
- Validation at declaration time per RESEARCH Pitfall 1 — no changes to `progression.ex` in this wave

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- ExUnit warning on unused default arg in `base_wait_until_rule/1` — removed default value to satisfy `--warnings-as-errors`

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Wave 1 DSL validation complete; ready for 48-02 (`enter_waiting/6` auto-populates `pending_signals`)
- Progression engine can consume validated `cancel_signals` from persisted step config

## Self-Check: PASSED

- `mix test test/chimeway/notifier_contract_test.exs --warnings-as-errors` — 20 tests, 0 failures
- `mix compile --warnings-as-errors` — green
- `grep -n "normalize_cancel_signals" lib/chimeway/notifier.ex` — 4 matches
- No edits to `lib/chimeway/workflows/progression.ex`

---
*Phase: 48-wait-until-pending-signals*
*Completed: 2026-05-29*

---
phase: 07-delayed-fallback-runtime-wiring
plan: "07-01"
subsystem: policy
tags: [delayed-fallback, delivery-planning, notifier, runtime]
requires:
  - phase: 06-delivery-planning-and-policy-checkpoint-repair
    provides: shared planner fanout and planning-time policy checkpoint contract
provides:
  - Optional notifier callback contract for delayed-fallback channel intent.
  - Additive delivery planning API that persists delayed-fallback flags and provenance metadata.
  - Shared planner validation and runtime wiring for delayed-fallback subset enforcement.
affects: [07-02, 07-03, POLC-03, dispatch-parity]
tech-stack:
  added: []
  patterns:
    - additive notifier behavior callbacks
    - planner-owned delayed-fallback resolution and validation
    - durable delayed-fallback provenance metadata at insert time
key-files:
  created: []
  modified:
    - lib/chimeway/notifier.ex
    - lib/chimeway/deliveries.ex
    - lib/chimeway/delivery_planning.ex
key-decisions:
  - "Keep delayed_fallback_channels/2 optional so existing notifier modules remain compatible."
  - "Persist delayed-fallback provenance as metadata['delayed_fallback_source'] at plan time."
  - "Fail planning on non-subset or in_app delayed-fallback declarations using typed planner errors."
patterns-established:
  - "Planner resolves delayed fallback with deterministic precedence: notifier -> policy opts -> default."
  - "Non-delayed channels persist delayed_fallback_source as default for explainability consistency."
requirements-completed: [POLC-03]
duration: 3 min
completed: 2026-04-24
---

# Phase 07 Plan 07-01: Delayed fallback runtime wiring summary

**Runtime planning now carries delayed-fallback intent from notifier/policy resolution into durable delivery rows while preserving planning-time policy evaluation and notifier backward compatibility.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-24T15:03:04Z
- **Completed:** 2026-04-24T15:06:26Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Added optional `delayed_fallback_channels/2` notifier callback contract with explicit subset-only guidance.
- Introduced additive `Deliveries.plan_delivery/3` options for delayed-fallback persistence and source metadata.
- Wired shared planner delayed-fallback resolution/validation with typed failure paths and in-app guardrails.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add delayed-fallback notifier callback contract** - `c42915b` (feat)
2. **Task 2: Add additive delivery planning API for delayed-fallback persistence** - `9043d5d` (feat)
3. **Task 3: Wire delayed-fallback resolution and validation in shared planner** - `c9358c3` (feat)

**Plan metadata:** `ac17e72` (docs)

## Files Created/Modified
- `lib/chimeway/notifier.ex` - Adds optional delayed-fallback callback and contract docs.
- `lib/chimeway/deliveries.ex` - Adds additive planning API options and delayed-fallback provenance persistence.
- `lib/chimeway/delivery_planning.ex` - Resolves delayed-fallback channels, validates subset/in-app constraints, and wires persistence.

## Decisions Made
- Extended notifier behavior additively so existing notifier modules do not need new callback implementations.
- Stored delayed-fallback provenance with stable values (`default`, `notifier`, `policy`) on planned delivery metadata.
- Kept planning checkpoint evaluation (`Policy.evaluate(delivery, [])`) unchanged while enriching planner persistence inputs.

## Deviations from Plan

None - plan executed exactly as written.

---

**Total deviations:** 0 auto-fixed (0 bug fix, 0 missing critical, 0 blocker)
**Impact on plan:** No scope creep; all outputs and acceptance checks were completed as specified.

## Issues Encountered
- One grep verification pattern for `plan_delivery/3` required fixed-string quoting in shell; equivalent check passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Runtime delayed-fallback planner wiring is complete and verified against compile + targeted dispatch tests.
- Ready for `07-02` sync/Oban suppression parity and provenance explainability work.

---
*Phase: 07-delayed-fallback-runtime-wiring*
*Completed: 2026-04-24*

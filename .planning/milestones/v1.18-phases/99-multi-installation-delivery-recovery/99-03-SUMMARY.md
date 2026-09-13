---
phase: 99-multi-installation-delivery-recovery
plan: "03"
subsystem: delivery-targets
tags: [elixir, ecto, postgres, tenant-safety, push]
requires:
  - phase: 99-multi-installation-delivery-recovery
    provides: 99-01 durable target schemas and dispatch tracer
provides:
  - Atomic, stable, tenant-qualified target-set planning
  - Derived logical-delivery aggregate facts with independent target outcomes
  - Ordered, privacy-safe tenant-scoped target trace projection
affects: [99-04-recovery, 99-05-verification, phase-100-apns]
tech-stack:
  added: []
  patterns:
    - Database-conflict insert followed by tenant-qualified authoritative reload
    - Parent aggregate derived only from durable child target states
    - Closed trace projection with explicit child tenant predicates and ordering
key-files:
  created:
    - test/chimeway/traces_target_test.exs
  modified:
    - lib/chimeway/delivery_targets.ex
    - lib/chimeway/safe_evidence.ex
    - lib/chimeway/traces.ex
    - test/chimeway/delivery_target_test.exs
key-decisions:
  - "[99-03]: Exact opaque binding-revision equality is the only target identity rule; normalized refs sort before durable planning."
  - "[99-03]: Parent success means one or more provider acceptances and retains terminal sibling failures as partial_failure evidence."
  - "[99-03]: Target and attempt trace children repeat tenant predicates and expose only closed projections."
patterns-established:
  - "Target lifecycle transitions append terminal attempt evidence before recomputing the parent aggregate."
requirements-completed: [PUSH-01, PUSH-02, PUSH-03, PUSH-04]
coverage:
  - id: D1
    description: Atomic duplicate-safe target planning with stable opaque revision ordering.
    requirement: PUSH-02
    verification:
      - kind: integration
        ref: test/chimeway/delivery_target_test.exs#normalizes exact duplicates into a stable opaque target set
        status: pass
    human_judgment: false
  - id: D2
    description: Honest logical delivery aggregation retaining independent terminal target outcomes.
    requirement: PUSH-04
    verification:
      - kind: integration
        ref: test/chimeway/delivery_target_test.exs#derives partial target failure without erasing the accepted target
        status: pass
    human_judgment: false
  - id: D3
    description: Tenant-safe, deterministically ordered target and attempt trace evidence.
    requirement: PUSH-03
    verification:
      - kind: integration
        ref: test/chimeway/traces_target_test.exs#orders tenant-scoped target histories and excludes foreign attempt evidence
        status: pass
    human_judgment: false
metrics:
  duration: 14m
  completed: 2026-08-19
status: complete
---

# Phase 99 Plan 03: Deterministic Target Planning and Trace Aggregation Summary

**Atomic opaque-target fan-out now derives honest provider-handoff aggregates while retaining tenant-safe ordered installation histories.**

## Performance

- **Duration:** 14m
- **Completed:** 2026-08-19T23:40:44Z
- **Tasks:** 2/2
- **Files modified:** 9

## Accomplishments

- Normalized target sets before transactional conflict-safe insertions and reload them in stable tenant-qualified order.
- Derived parent aggregate counts from durable target rows so accepted handoffs never hide independent terminal failures.
- Added target lifecycle transitions, closed aggregate evidence, and tenant-filtered ordered target-attempt trace projections.

## Task Commits

1. **Task 1: Converge empty, duplicate, ordered, and concurrent target planning** — `661147a` (feat)
2. **Task 2: Derive truthful parent aggregates and ordered per-target traces** — `daf9301` (feat)

## Files Created/Modified

- `lib/chimeway/delivery_targets.ex` — atomic planning, lifecycle transitions, and aggregate recomputation.
- `lib/chimeway/safe_evidence.ex` — closed target aggregate and target-attempt trace vocabulary.
- `lib/chimeway/traces.ex` — tenant-scoped ordered target and attempt preloads.
- `test/chimeway/traces_target_test.exs` — cross-tenant and ordered trace acceptance coverage.

## Decisions Made

- Target identity uses exact opaque revision equality only; no semantic parsing or prefix merging occurs.
- `provider_accepted` is provider-handoff evidence, not a device-delivery claim; a mixed terminal set is surfaced as `partial_failure`.
- Parent aggregate facts live as a closed, derived metadata projection rather than a second delivery state machine.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Regression] Updated the existing exact trace-shape assertion for the new closed aggregate field.**
- **Found during:** Task 2
- **Issue:** The established trace regression expected the former delivery DTO shape.
- **Fix:** Added `target_aggregate` to the exact key contract.
- **Files modified:** `test/chimeway/traces_test.exs`
- **Verification:** Focused target and trace suites passed.
- **Committed in:** `daf9301`

**Total deviations:** 1 auto-fixed (Rule 1)

## Known Stubs

None.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 99-04 can build bounded target recovery on the durable target lifecycle, aggregate facts, and tenant-safe traces established here.

## Self-Check: PASSED

- Task commits `661147a` and `daf9301` exist in git history.
- All created and modified implementation and test files exist.

---
*Phase: 99-multi-installation-delivery-recovery*
*Completed: 2026-08-19*

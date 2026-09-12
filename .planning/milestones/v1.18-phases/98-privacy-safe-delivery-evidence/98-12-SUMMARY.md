---
phase: 98-privacy-safe-delivery-evidence
plan: 12
subsystem: privacy
tags: [elixir, ecto, privacy, recipient-references, workflows]
requires:
  - phase: 98-privacy-safe-delivery-evidence
    provides: Durable missing-context evidence and the closed render_context_unavailable classification
provides:
  - Pass-through-only recipient reference validation for explicit cw_ references and canonical UUID compatibility values
  - Collision-safe Trigger recipient normalization before lifecycle persistence
  - Workflow signal routing fixtures and regressions that use the same opaque-reference contract
affects: [trigger, workflows, inbox, privacy-safe-delivery-evidence]
tech-stack:
  added: []
  patterns:
    - Recipient aliases are fail-closed when either atom/string spelling appears more than once
    - Host-supplied opaque references cross persistence and workflow query boundaries unchanged
key-files:
  created:
    - .planning/phases/98-privacy-safe-delivery-evidence/98-12-SUMMARY.md
  modified:
    - lib/chimeway/safe_evidence.ex
    - lib/chimeway/trigger.ex
    - lib/chimeway/workflows.ex
    - test/chimeway/privacy_test.exs
    - test/chimeway/trigger_sanitization_test.exs
    - test/chimeway/workflows_test.exs
key-decisions:
  - "[98-12]: recipient_reference/1 accepts only documented cw_ values and exact lowercase UUID user: compatibility values; it does not derive replacements."
  - "[98-12]: equal atom/string recipient aliases are ambiguous and rejected before Trigger opens its lifecycle transaction."
  - "[98-12]: Workflow routing uses explicit opaque actor references; raw signal identities never query waiting runs."
patterns-established:
  - "Validate host-supplied recipient references before durable Event, Notification, and Delivery work begins."
requirements-completed: [PRIV-03, PRIV-04]
coverage:
  - id: D1
    description: "Strict recipient-reference validation rejects raw identities and grammar near misses."
    requirement: "PRIV-04"
    verification:
      - kind: unit
        ref: "test/chimeway/privacy_test.exs#recipient references accept only explicit opaque or canonical UUID compatibility values"
        status: pass
    human_judgment: false
  - id: D2
    description: "Trigger rejects unsafe and ambiguous recipient input before lifecycle persistence."
    requirement: "PRIV-03"
    verification:
      - kind: integration
        ref: "test/chimeway/trigger_sanitization_test.exs#recipient reference persistence boundary"
        status: pass
    human_judgment: false
  - id: D3
    description: "Workflow signal matching accepts only the same explicit opaque recipient references."
    requirement: "PRIV-04"
    verification:
      - kind: integration
        ref: "test/chimeway/workflows_test.exs#route_signal/1 — basic matching"
        status: pass
    human_judgment: false
duration: 12min
completed: 2026-08-15
status: complete
---

# Phase 98 Plan 12: Strict Recipient Reference Boundary Summary

**Trigger and Workflow routing now retain only explicit host-supplied opaque recipient references, rejecting raw identities and ambiguous aliases before persistence or matching.**

## Performance

- **Duration:** 12 min
- **Completed:** 2026-08-15
- **Tasks:** 2/2
- **Files modified:** 6

## Accomplishments

- Restricted `recipient_reference/1` to exact `cw_...` values and the canonical lowercase UUID `user:` compatibility form.
- Rejected duplicate atom/string recipient aliases before Trigger writes an Event or Notification, including equal duplicate values.
- Updated Workflow signal fixtures and routing regressions for opaque references, raw actor rejection, and UUID compatibility matching.

## Task Commits

1. **Task 1: Trace explicit opaque references and raw-recipient rejection through Trigger persistence** - `8e20185`, `a4f7eb9` (test, feat)
2. **Task 2: Align Workflow signal routing and caller fixtures with the strict recipient contract** - `698bb08` (test)

## Files Created/Modified

- `lib/chimeway/safe_evidence.ex` - closed pass-through recipient-reference grammar.
- `lib/chimeway/trigger.ex` - collision-safe recipient alias normalization before persistence.
- `lib/chimeway/workflows.ex` - explicit opaque actor contract documentation at signal matching.
- `test/chimeway/privacy_test.exs` - pure recipient-reference grammar matrix.
- `test/chimeway/trigger_sanitization_test.exs` - Trigger rejection and opaque persistence tracer.
- `test/chimeway/workflows_test.exs` - opaque Workflow routing and raw-signal rejection coverage.

## Decisions Made

- Raw, email-like, slug-like, malformed, non-binary, and oversized recipient values are unsafe evidence; Chimeway does not hash or derive a replacement.
- Atom/string alias collisions are rejected independent of equality or construction order.
- The `render_context_unavailable` classification introduced by Plan 98-11 remains unchanged.

## Verification

Passed:

```text
mix format --check-formatted lib/chimeway/safe_evidence.ex lib/chimeway/trigger.ex lib/chimeway/workflows.ex test/chimeway/privacy_test.exs test/chimeway/trigger_sanitization_test.exs test/chimeway/workflows_test.exs
env MIX_ENV=test mix test test/chimeway/privacy_test.exs test/chimeway/trigger_sanitization_test.exs test/chimeway/inbox_query_test.exs test/chimeway/inbox_state_transition_test.exs test/chimeway/workflows_test.exs --warnings-as-errors
# 46 tests, 0 failures
```

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

The focused Trigger tracer logs the existing non-fatal `Dispatch failed after trigger` warning for its synthetic notifier, while its Event/Notification persistence and public trace assertions pass. The plan's focused verification remains green; delivery-planning configuration is outside this plan's scoped recipient-boundary change.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

PRIV-03 and PRIV-04 now have executable strict-reference evidence at the pure validator, Trigger persistence, Inbox compatibility, and Workflow-routing boundaries.

## Self-Check: PASSED

All six declared production/test artifacts exist and all three task commits are present in git history.

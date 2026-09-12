---
phase: 98-privacy-safe-delivery-evidence
plan: 11
subsystem: async-delivery-privacy
tags: [elixir, oban, postgres, traces, privacy]
requires:
  - phase: 98-privacy-safe-delivery-evidence
    provides: queued email execution-time hydration and closed safe evidence
provides:
  - Durable closed evidence for unavailable queued render context
  - Retry and exhaustion lifecycle explanation without host context disclosure
affects: [oban-worker, delivery-attempts, safe-evidence, traces]
tech-stack:
  added: []
  patterns:
    - Hydration failures enter the same dispatched-attempt-exhaustion spine as retryable adapter failures
    - Unavailable host context is represented only by a closed error classification and empty provider facts
key-files:
  created:
    - .planning/phases/98-privacy-safe-delivery-evidence/98-11-SUMMARY.md
  modified:
    - lib/chimeway/safe_evidence.ex
    - lib/chimeway/delivery_attempt.ex
    - lib/chimeway/dispatch/oban_worker.ex
    - test/chimeway/dispatch/oban_worker_test.exs
key-decisions:
  - "[98-11]: Hydration failure records the literal render_context_unavailable attempt before mapping through the existing Oban retry and exhaustion contract."
requirements-completed: [PRIV-03, PRIV-04]
coverage:
  - id: D1
    description: "Queued unavailable render context produces a bounded failed attempt before retry and reaches retries_exhausted after the final attempt."
    requirement: PRIV-03
    verification:
      - kind: integration
        ref: "test/chimeway/dispatch/oban_worker_test.exs#unavailable execution context"
        status: pass
    human_judgment: false
  - id: D2
    description: "Attempt rows and tenant-scoped trace retain only the fixed classification and lifecycle facts, never resolver or rendering sentinels."
    requirement: PRIV-04
    verification:
      - kind: integration
        ref: "test/chimeway/dispatch/oban_worker_test.exs#unavailable execution context"
        status: pass
    human_judgment: false
duration: 10min
completed: 2026-08-15
status: complete
---

# Phase 98 Plan 11: Durable Missing-Context Evidence Summary

**Queued email context failures now write a closed, tenant-explainable failed attempt before retrying and converge safely to retries_exhausted at the Oban budget limit.**

## Performance

- **Duration:** 10 min
- **Completed:** 2026-08-15
- **Tasks:** 1/1
- **Files modified:** 4

## Accomplishments

- Added `render_context_unavailable` to the shared bounded evidence vocabulary and delivery-attempt validation.
- Routed categorical email hydration failures through dispatched state, one failed attempt with empty provider facts, and the existing retry/exhaustion mapping.
- Added PostgreSQL-backed worker coverage for a missing resolver, hostile resolver errors, contiguous retry attempts, terminal state, tenant trace facts, and raw-sentinel absence.

## Verification

- PASS: `mix format --check-formatted lib/chimeway/safe_evidence.ex lib/chimeway/delivery_attempt.ex lib/chimeway/dispatch/oban_worker.ex test/chimeway/dispatch/oban_worker_test.exs`
- PASS: `env MIX_ENV=test mix test test/chimeway/dispatch/oban_worker_test.exs --warnings-as-errors` — 16 tests, 0 failures.
- OUT OF SCOPE: `mix ci.audit` exits 1 on pre-existing advisories for `postgrex`, `phoenix_live_view`, `hackney`, and `decimal`; this plan makes no dependency changes.

## Task Commits

1. **Task 1 RED:** `34401bd` — failing unavailable-context evidence regression.
2. **Task 1 GREEN:** `d95fad0` — durable unavailable-context attempt and retry mapping.
3. **Task 1 coverage:** `8de76dd` — missing resolver retry regression.

## Decisions Made

- Reused `Deliveries.exhaust_delivery/1` and the worker's existing retry budget instead of creating a second hydration-specific terminal path.
- Returned only `:render_context_unavailable` from the retry branch; resolver failures and context values are neither inspected nor propagated.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Align attempt persistence with the new closed error class.**
- **Found during:** Task 1 GREEN verification.
- **Issue:** `DeliveryAttempt` rejected `render_context_unavailable` even though `SafeEvidence` accepted it.
- **Fix:** Added the same literal classification to the persistence changeset whitelist.
- **Files modified:** `lib/chimeway/delivery_attempt.ex`.
- **Verification:** Focused worker suite passes with persisted attempts and trace evidence.
- **Committed in:** `d95fad0`.

---

**Total deviations:** 1 auto-fixed (Rule 2).
**Impact on plan:** Required consistency repair only; no schema, API, or dependency change.

## Known Stubs

None.

## Issues Encountered

- `mix ci.audit` reports existing dependency advisories and exits 1. It is unrelated to this task's source changes; no package action was taken.

## Next Phase Readiness

The queued hydration-failure gap has executable database and tenant-trace evidence; Phase 98 can use the focused worker suite as machine-readable acceptance.

## Self-Check: PASSED

- Found all declared production and test files.
- Found task commits `34401bd`, `d95fad0`, and `8de76dd`.
- No deletions, placeholders, TODOs, or FIXMEs were introduced in plan-owned code.

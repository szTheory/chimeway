---
phase: 98-privacy-safe-delivery-evidence
plan: 09
subsystem: privacy-boundary
tags: [elixir, ecto, delivery, privacy, safe-evidence]
requires:
  - phase: 98-privacy-safe-delivery-evidence
    provides: private render handoff and identity-only delivery persistence
provides:
  - Duplicate-aware logical evidence lookup across maps and tuple lists
  - Closed provider-code validation before durable attempt writes
  - Collision-safe render channel identity projection
affects: [delivery-attempts, render-channels, traces, privacy]
tech-stack:
  added: []
  patterns:
    - A normalized logical field must occur exactly once before it can be selected
    - Ambiguous render channels and identities are omitted rather than resolved by ordering
key-files:
  created:
    - .planning/phases/98-privacy-safe-delivery-evidence/98-09-SUMMARY.md
  modified:
    - lib/chimeway/safe_evidence.ex
    - test/chimeway/privacy_test.exs
    - test/chimeway/privacy_boundary_test.exs
key-decisions:
  - "[98-09]: Atom/string aliases and repeated tuple-list entries are ambiguous even when their values match."
  - "[98-09]: Provider codes use the same closed grammar as other categorical safe evidence."
patterns-established:
  - "Safe evidence lookup accepts only known atom/binary aliases and never atomizes caller strings."
requirements-completed: [PRIV-03, PRIV-04]
coverage:
  - id: D1
    description: Duplicate provider and attempt evidence fails closed across map and tuple-list representations.
    requirement: PRIV-03
    verification:
      - kind: integration
        ref: env MIX_ENV=test mix test test/chimeway/privacy_test.exs test/chimeway/privacy_boundary_test.exs --warnings-as-errors
        status: pass
    human_judgment: false
  - id: D2
    description: Ambiguous attempt input creates no persisted attempt while a valid singleton remains typed and explainable.
    requirement: PRIV-04
    verification:
      - kind: integration
        ref: env MIX_ENV=test mix test test/chimeway/privacy_boundary_test.exs --warnings-as-errors
        status: pass
    human_judgment: false
duration: 3 min
completed: 2026-08-13
status: complete
---

# Phase 98 Plan 09: Duplicate-Safe Evidence Summary

**Provider, attempt, and render evidence now fail closed whenever a logical field appears more than once, preventing representation or ordering from selecting durable facts.**

## Accomplishments

- Replaced duplicate-blind atom/string and keyword lookups with a single occurrence-counted contract for provider facts and attempt attributes.
- Made render channel projection group normalized channel names and omit duplicate channels or duplicate render identities.
- Enforced the closed categorical code grammar for provider codes, including newline-safe anchoring and sensitive-content term rejection.
- Added pure and PostgreSQL-backed regression coverage proving ambiguous attempt input returns before `Ecto.Multi` and writes no row.

## Verification

- PASS: `mix format --check-formatted lib/chimeway/safe_evidence.ex test/chimeway/privacy_test.exs test/chimeway/privacy_boundary_test.exs`.
- PASS: `env MIX_ENV=test mix test test/chimeway/privacy_test.exs test/chimeway/privacy_boundary_test.exs --warnings-as-errors` — 14 tests, 0 failures.

## Task Commits

1. **Task 1 RED:** `950a002` — failing duplicate evidence regressions.
2. **Task 1 GREEN:** `ebb2fd8` — duplicate-aware lookup and closed provider-code validation.
3. **Task 1 contract correction:** `d4e6b3c` — list evidence support reflected in the public type specification.

## Decisions Made

- Equal duplicates are as unsafe as conflicting duplicates; the collision itself, not the value comparison, is the trust-boundary violation.
- Render channels preserve only singleton normalized channel and identity pairs; ambiguous entries have no redacted or diagnostic fallback.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Closed code grammar accepted a trailing newline.**
- **Found during:** Task 1 provider-code hostile input regression.
- **Issue:** The end-of-line regex anchor accepted an otherwise invalid final newline.
- **Fix:** Used the strict end-of-string anchor in the shared code grammar.
- **Files modified:** `lib/chimeway/safe_evidence.ex`
- **Verification:** focused privacy suites passed.
- **Committed in:** `ebb2fd8`.

**2. [Rule 1 - Bug] Top-level email render channel names were removed before collision grouping.**
- **Found during:** Task 1 render-channel singleton regression.
- **Issue:** Applying generic privacy-key redaction to top-level channels treated the valid `email` channel identifier as sensitive data.
- **Fix:** Grouped original top-level keys by safe normalized channel and continued redaction only inside the render identity map.
- **Files modified:** `lib/chimeway/safe_evidence.ex`
- **Verification:** focused privacy suites passed.
- **Committed in:** `ebb2fd8`.

## Known Stubs

None.

## Self-Check: PASSED

- Found all declared production and test files.
- Found task commits `950a002`, `ebb2fd8`, and `d4e6b3c`.
- Stub scan found no placeholder, TODO, or FIXME markers in plan-owned files.
- No tracked file deletions or unplanned security surfaces were introduced.

## Next Phase Readiness

Phase 98's final duplicate-key and provider-code privacy gap now has pure and real persistence evidence; Plan 98-10 can build on a closed safe-evidence boundary.

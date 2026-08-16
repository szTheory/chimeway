---
phase: 98-privacy-safe-delivery-evidence
plan: 15
subsystem: privacy-safe-delivery-evidence
tags: [elixir, privacy, redaction, traces, safe-evidence]
requires:
  - phase: 98-privacy-safe-delivery-evidence
    provides: closed public lifecycle trace maps
provides:
  - Recursive plain-map projection for untrusted structs
  - Closed nested trace attempt and timeline evidence
affects: [operator-explanations, proof-output, privacy-boundaries]
tech-stack:
  added: []
  patterns: [temporal-scalar exceptions, recursive struct projection, closed nested evidence constructors]
key-files:
  created: [.planning/phases/98-privacy-safe-delivery-evidence/98-15-SUMMARY.md]
  modified: [lib/chimeway/privacy.ex, lib/chimeway/safe_evidence.ex, test/chimeway/privacy_test.exs, test/chimeway/traces_test.exs]
key-decisions:
  - "[98-15]: Only Date, Time, NaiveDateTime, and DateTime bypass recursive redaction; other structs are projected into ordinary maps."
  - "[98-15]: Trace evidence rebuilds attempts and timeline entries from fixed validated vocabularies, omitting malformed nested input."
metrics:
  duration: 18 min
  completed: 2026-08-15
status: complete
---

# Phase 98 Plan 15: Privacy-Safe Delivery Evidence Summary

Untrusted structs and nested trace terms now cross privacy boundaries only through recursive or closed-vocabulary projections.

## Completed Tasks

1. Preserved explicit temporal scalar structs while recursively projecting every other struct through `Privacy.redact/1`, including downstream proof output.
2. Rebuilt trace attempts and timeline entries from validated fixed keys, omitting malformed or hostile nested evidence.

## Verification

- Passed: `mix format --check-formatted lib/chimeway/safe_evidence.ex test/chimeway/privacy_test.exs test/chimeway/traces_test.exs`
- Passed: `env MIX_ENV=test mix test test/chimeway/privacy_test.exs test/chimeway/traces_test.exs --warnings-as-errors` (60 tests, 0 failures)

## Decisions Made

- Only `%Date{}`, `%Time{}`, `%NaiveDateTime{}`, and `%DateTime{}` retain struct form at the recursive privacy boundary.
- Trace output keeps only validated last-attempt facts and literal `%{at, event, detail}` timeline entries.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Restored validated timeline channel and error-class facts**
- **Found during:** Task 2 verification
- **Issue:** Closing generic nested projection exposed existing validator omissions for `:channel` and `:error_class` timeline details.
- **Fix:** Validated channel with `safe_channel/1` and error class with `safe_error_class/1`, preserving established explainability without widening the vocabulary.
- **Files modified:** `lib/chimeway/safe_evidence.ex`
- **Commit:** 8764f75

## Known Stubs

None.

## Self-Check: PASSED

- Required implementation files exist.
- Task commits `08ec594` and `8764f75` exist.

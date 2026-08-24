---
phase: 101-crosswake-registration-protected-open
plan: "02"
subsystem: notification-open policy
tags: [elixir, crosswake, manifest, authorization, tdd]
requires:
  - phase: 101-crosswake-registration-protected-open
    provides: host-bound notification-open resolution contracts
provides:
  - Canonical string-based notification-open action policies
  - Legacy true shorthand normalized to the tap-only allowlist
affects: [101-03, crosswake-chimeway-resolver]
tech-stack:
  added: []
  patterns: [normalize-at-authoring-boundary, closed-action-allowlist, deterministic-manifest-serialization]
key-files:
  created:
    - .planning/phases/101-crosswake-registration-protected-open/101-02-SUMMARY.md
  modified:
    - ../crosswake/lib/crosswake/policy/schema.ex
    - ../crosswake/lib/crosswake/policy/route.ex
    - ../crosswake/lib/crosswake/manifest/types.ex
    - ../crosswake/test/crosswake/policy/schema_test.exs
    - ../crosswake/test/crosswake/manifest/builder_test.exs
key-decisions:
  - "[101-02]: `tap` is the only legacy-true default action; explicit current action allowlists are bounded to `tap` and `reply`."
  - "[101-02]: Schema normalization returns `%{actions: [String.t()]}` and later policy layers transfer and serialize it unchanged."
metrics:
  duration: 10 min
  completed: 2026-08-24
  tasks_completed: 1
  files_modified: 5
status: complete
---

# Phase 101 Plan 02: Closed Notification-Open Policy Summary

**Notification-open authoring now compiles to one fail-closed string action allowlist, with legacy `true` meaning only `tap`.**

## Completed Work

- Normalized `notification_open: true` to `%{actions: ["tap"]}` at the schema boundary.
- Restricted explicit declarations to unique, recognized atom actions and converted them to ordered strings.
- Updated route and manifest entry contracts plus manifest serialization to preserve the canonical map without reinterpretation.
- Added focused schema and builder proof for normalized output, deterministic serialization, and malformed/default-deny input rejection.

## Verification

- `cd ../crosswake && mix test test/crosswake/policy/schema_test.exs test/crosswake/policy/route_test.exs test/crosswake/manifest/builder_test.exs` — 51 tests, 0 failures.

## TDD Gate Compliance

- RED: `4369804c` added failing normalization and fail-closed validation assertions; the legacy boolean and atom-list outputs failed as expected.
- GREEN: `7660f05b` implemented the canonical compiled action representation and made the focused suites pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed a non-guard-safe enumerable check from schema normalization**
- **Found during:** Task 1
- **Issue:** The first implementation placed `Enum.all?/2` in a function guard, which Elixir rejects at compile time.
- **Fix:** Moved the enumerable validation into the function body while retaining the same non-empty, unique, recognized-action checks.
- **Files modified:** `../crosswake/lib/crosswake/policy/schema.ex`
- **Verification:** Focused policy, route, and builder suites passed.
- **Commit:** `7660f05b`

**Total deviations:** 1 auto-fixed (Rule 1). **Impact:** No scope expansion; the correction preserves the planned validation semantics.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed all listed CrossWake production and test files exist.
- Confirmed RED commit `4369804c` and GREEN commit `7660f05b` exist in CrossWake history.

---
phase: 98-privacy-safe-delivery-evidence
plan: 04
subsystem: privacy-safe operator projections
tags: [elixir, privacy, traces, admin, liveview]
requires:
  - phase: 98-privacy-safe-delivery-evidence
    provides: closed persistence and diagnostic evidence constructors
provides:
  - Tenant-scoped trace explanations projected through closed SafeEvidence constructors
  - Core Admin DTOs with opaque recipient and correlation references
  - Recursive Admin view redaction as a secondary privacy barrier
affects: [traces, admin, operator-console]
tech-stack:
  added: []
  patterns:
    - Opaque SHA-256-derived references for operator-visible identity correlation
    - Closed SafeEvidence projection before trace or Admin DTO rendering
key-files:
  created:
    - .planning/phases/98-privacy-safe-delivery-evidence/98-04-SUMMARY.md
  modified:
    - lib/chimeway/safe_evidence.ex
    - lib/chimeway/traces.ex
    - lib/chimeway/admin.ex
    - chimeway_admin/lib/chimeway_admin/redaction.ex
    - test/chimeway/traces_test.exs
    - test/chimeway/admin_test.exs
    - chimeway_admin/test/chimeway_admin/live/privacy_leak_live_test.exs
key-decisions:
  - "[98-04]: Operator projections derive stable cw_* opaque references instead of exposing raw recipient or correlation identity."
  - "[98-04]: Adapter module names and provider-controlled detail are omitted from trace timelines and attempt summaries."
  - "[98-04]: Optional Admin rendering recursively redacts before applying its display allowlist."
requirements-completed: [PRIV-03, PRIV-04]
duration: 30 min
completed: 2026-08-13
status: complete
---

# Phase 98 Plan 04: Privacy-Safe Delivery Evidence Summary

**Trace and Admin operator projections now use a closed safe-evidence vocabulary with opaque identity references and recursive UI defense in depth.**

## Accomplishments

- Projected delivery explanations, timeline details, and attempt summaries through named `SafeEvidence` constructors.
- Replaced raw recipient and correlation values with stable opaque `cw_*` references; omitted adapter modules and provider detail.
- Routed recent-problem, feed, and recovery Admin DTOs through closed facts and added recursive Admin redaction.
- Added hostile nested mixed-case privacy fixtures for core DTO and rendered LiveView regression coverage.

## Task Commits

1. **Task 1: Project tenant-scoped traces through safe evidence** - `e45af89`, `5e294aa` (RED, GREEN)
2. **Task 2: Project core Admin DTOs before recursive view defense** - `0db93ee`, `c77af18` (RED, GREEN)

## Verification

- Passed: `env MIX_ENV=test mix test test/chimeway/traces_test.exs --warnings-as-errors` (47 tests)
- Passed: `env MIX_ENV=test mix test test/chimeway/admin_test.exs --warnings-as-errors` (12 tests)
- Passed: `cd chimeway_admin && env MIX_ENV=test mix test test/chimeway_admin/live/privacy_leak_live_test.exs --warnings-as-errors` (6 tests)
- `mix verify.admin` reached the optional Admin suite but remains red on the pre-existing `ChimewayAdmin.LiveAuthTest` redirect path (`:to` is `nil`); it is unrelated to the DTO/redaction changes and is tracked below.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Restored the safe feed correlation field's stable DTO shape**
- **Found during:** Task 2 verification
- **Issue:** A feed row with no correlation ID omitted the field, causing the existing LiveView renderer to raise.
- **Fix:** Safe Admin facts now preserve the `correlation_id: nil` key while transforming non-nil values to opaque references.
- **Files modified:** `lib/chimeway/safe_evidence.ex`
- **Commit:** `c77af18`

## Deferred Issues

- `mix verify.admin` is blocked by the existing optional Admin `LiveAuth` test configuration: `redirect/2` receives `to: nil` in `ChimewayAdmin.LiveAuthTest`. This plan did not modify that auth path.

## Known Stubs

None.

## Self-Check: PASSED

- Found all seven plan-owned implementation and test files.
- Found task commits `e45af89`, `5e294aa`, `0db93ee`, and `c77af18`.
- No tracked-file deletions were introduced.

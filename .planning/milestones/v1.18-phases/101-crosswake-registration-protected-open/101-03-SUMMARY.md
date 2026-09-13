---
phase: 101-crosswake-registration-protected-open
plan: "03"
subsystem: notification-open authorization
tags: [elixir, crosswake, chimeway, manifest, route-gate, tdd]
requires:
  - phase: 101-crosswake-registration-protected-open
    provides: canonical notification-open action policies and host-bound consumed resolutions
provides:
  - Structural validation of compiled notification-open policies
  - Exact post-consume action membership before RouteGate evaluation
affects: [101-05, 102-crosswake-digital-twin]
tech-stack:
  added: []
  patterns: [fail-closed compiled-policy validation, exact action membership, consume-first authorization]
key-files:
  created:
    - .planning/phases/101-crosswake-registration-protected-open/101-03-SUMMARY.md
  modified:
    - ../crosswake/lib/crosswake/manifest/validator.ex
    - ../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/resolver.ex
    - ../crosswake/test/crosswake/manifest/validator_test.exs
    - ../crosswake/packages/crosswake_chimeway/test/crosswake/companions/chimeway/resolver_test.exs
    - ../crosswake/packages/crosswake_chimeway/test/crosswake/proof/phase71_notification_workflow_proof_test.exs
key-decisions:
  - "[101-03]: Compiled notification-open policy is valid only as a non-empty, unique canonical string allowlist of tap, reply, or approve."
  - "[101-03]: Resolver consumes host evidence once, then uses only the current host-bound route/action policy before invoking RouteGate."
metrics:
  duration: 8 min
  completed: 2026-08-24
  tasks_completed: 1
  files_modified: 5
status: complete
---

# Phase 101 Plan 03: Closed Compiled Policy Summary

**Compiled notification-open policy and protected-open runtime resolution now share one strict, fail-closed action allowlist.**

## Completed Work

- Added structured validator findings for raw legacy booleans, keyword lists, empty, duplicate, blank/non-string, unknown-action, and malformed compiled notification-open policies.
- Replaced resolver allow-through fallbacks with canonical-policy validation and exact post-consume action membership.
- Preserved consume-first authority: only a valid host-bound `OpenResolution` selects the current route/action, and only an exact member reaches `RouteGate`.
- Updated the Phase 71 proof fixture to the canonical `%{actions: [...]}` compiled policy representation while retaining the server-bound route/action denial matrix.

## Verification

- `cd ../crosswake && mix test test/crosswake/manifest/validator_test.exs` — 21 tests, 0 failures.
- `cd ../crosswake/packages/crosswake_chimeway && mix test test/crosswake/companions/chimeway/resolver_test.exs test/crosswake/proof/phase71_notification_workflow_proof_test.exs` — 18 tests, 0 failures.
- Confirmed the resolver has no permissive `notification_open: _` or action fallback branch.

## TDD Gate Compliance

- RED: `bd88cb6a` added failing malformed-policy and server-bound non-member assertions; both suites failed against the former permissive behavior.
- GREEN: `d56f2446` implemented structural validation and exact membership; all focused suites pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed non-guard-safe dynamic membership from the resolver clause**
- **Found during:** Task 1 GREEN verification
- **Issue:** Elixir does not permit `action_ref in actions` when `actions` is dynamic in a guard.
- **Fix:** Evaluated membership inside the canonical-policy branch without changing the fail-closed outcome.
- **Files modified:** `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/resolver.ex`
- **Verification:** Focused resolver and Phase 71 proof suites passed.
- **Commit:** `d56f2446`

**Total deviations:** 1 auto-fixed (Rule 1). **Impact:** No scope expansion; the correction preserves exact action membership.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed all five plan artifacts exist in the Crosswake repository.
- Confirmed RED commit `bd88cb6a` and GREEN commit `d56f2446` exist in Crosswake history.

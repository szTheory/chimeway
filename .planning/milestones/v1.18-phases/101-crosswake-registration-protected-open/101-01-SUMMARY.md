---
phase: 101-crosswake-registration-protected-open
plan: "01"
subsystem: notification-open authorization
tags: [elixir, phoenix, crosswake, chimeway, route-gate, replay-protection]
requires:
  - phase: 100-optional-apns-adapter
    provides: opaque host-owned notification-open evidence and binding references
provides:
  - Host-bound OpenResolution route and action contracts for valid consumed intents
  - Consume-first resolver authorization using the current manifest and RouteGate
  - Executable host tracer for allow-once and replay-deny notification opens
affects: [101-crosswake-registration-protected-open, 102-crosswake-digital-twin]
tech-stack:
  added: []
  patterns: [host-bound authority, consume-first authorization, replay denial]
key-files:
  created:
    - .planning/phases/101-crosswake-registration-protected-open/101-01-SUMMARY.md
  modified:
    - ../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/contracts.ex
    - ../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/resolver.ex
    - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex
    - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registry_notification_open_test.exs
    - ../crosswake/packages/crosswake_chimeway/test/crosswake/companions/chimeway/resolver_test.exs
key-decisions:
  - "[101-01]: Resolver consumes opaque evidence before selecting a route or action, and only authorizes host-bound OpenResolution values."
  - "[101-01]: Valid OpenResolution contracts require non-empty server-bound route_id and action_ref."
metrics:
  duration: 8 min
  completed: 2026-08-24
  tasks_completed: 1
  files_modified: 8
status: complete
---

# Phase 101 Plan 01: Protected Notification Open Summary

**One opaque notification tap now activates exactly once from host-bound route/action values, then deterministically denies replay without fallback navigation.**

## Completed Work

- Added validated `route_id` and `action_ref` fields to successful host `OpenResolution` contracts.
- Changed the resolver to consume evidence before reading the manifest, then use only the consumed host binding for policy and `RouteGate` evaluation with `activation_source: :notification`.
- Added end-to-end host proof for a client redirect attempt, exact-once consume audit, successful `home`/`tap` activation, and replay denial.

## Verification

- `cd packages/crosswake_chimeway && mix test test/crosswake/companions/chimeway/contracts_test.exs test/crosswake/companions/chimeway/resolver_test.exs` — 21 tests, 0 failures.
- `cd examples/phoenix_host && mix test test/crosswake_example/chimeway/registry_notification_open_test.exs` — 7 tests, 0 failures.

## TDD Gate Compliance

- RED: `225c7ccb` added failing host and resolver tests; failures proved the resolver trusted client route/action and successful resolutions lacked bound values.
- GREEN: `8a18dc5b` added consume-first server-bound authorization and made the focused suites pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking test environment] Restored the companion package lock entries for its declared `ex_doc` test dependency**
- **Found during:** Task 1 verification
- **Issue:** `mix test` in `packages/crosswake_chimeway` refused to run because its `mix.lock` did not lock the already-declared `ex_doc` dependency.
- **Fix:** Resolved the declared dependencies and committed the generated lock entries.
- **Files modified:** `../crosswake/packages/crosswake_chimeway/mix.lock`
- **Verification:** The package resolver and contract tests run successfully.
- **Commit:** `8a18dc5b`

**Total deviations:** 1 auto-fixed. **Impact:** The focused companion verification is reproducible from its package directory.

## Known Stubs

None.

## Self-Check: PASSED

- Required CrossWake contract, resolver, host registry, and tracer test files exist.
- Task commits `225c7ccb` and `8a18dc5b` exist in the CrossWake repository.

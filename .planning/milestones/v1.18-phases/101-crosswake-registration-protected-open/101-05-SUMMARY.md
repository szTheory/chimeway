---
phase: 101-crosswake-registration-protected-open
plan: "05"
subsystem: crosswake-example-host
tags: [elixir, ecto, notification-open, authorization, concurrency]
requires:
  - phase: 101-crosswake-registration-protected-open
    provides: exact binding revision and protected-open resolver contracts
provides:
  - Tenant, subject, session, and version-scoped durable notification intents
  - Predicate-CAS intent consumption with a single successful consumer
  - Closed denial classification for stale or mismatched authority
affects:
  - Phase 101 protected-open resolver and native reconnect flow
tech-stack:
  added: []
  patterns:
    - Conditional Ecto update with a correlated active-binding predicate
    - Server-derived durable intent scope and opaque closed outcomes
key-files:
  created:
    - .planning/phases/101-crosswake-registration-protected-open/101-05-SUMMARY.md
  modified:
    - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex
    - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/notification_open_intent.ex
    - ../crosswake/examples/phoenix_host/priv/repo/migrations/20260603000000_create_chimeway_notification_open_intents.exs
    - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registry_notification_open_test.exs
key-decisions:
  - "[101-05]: The host derives durable intent tenant, subject, session, and version scope from the active binding at issue time."
  - "[101-05]: Intent consumption uses one conditional update with a correlated active-binding predicate; zero-row outcomes are classified only into closed public states."
metrics:
  duration: 16 min
  completed: 2026-08-24
status: complete
---

# Phase 101 Plan 05: Atomic Current-Authority Intent Consumption Summary

**Notification-open intents now grant one server-bound route/action resolution only while the exact binding and authenticated authority scope remain current.**

## Completed Work

- Added durable tenant, subject, session, and session-version fields to example-host notification intents; issuing derives them from the exact active binding.
- Replaced read-validate-update consumption with a single predicate-CAS update that verifies issued state, expiry, client-presented binding ref, authenticated scope, and an exact active binding in one database operation.
- Added bounded authoritative zero-row classification into opaque closed states, and records a consumed event only for the winning update.
- Added current-authority and concurrent-consumer coverage: tenant switch, session-version change, expiry, binding mismatch/revocation, server-bound action, and exactly one valid/replay pair.

## Verification

- `cd ../crosswake/examples/phoenix_host && mix test test/crosswake_example/chimeway/notification_open_intent_test.exs test/crosswake_example/chimeway/registry_notification_open_test.exs --seed 0` — 13 tests, 0 failures.
- Re-ran the focused deterministic suite five consecutive times with `--seed 0` — all passed.
- `git -C ../crosswake show --check 26d225cb` — passed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Compile bug] Reworked callable predicates outside guards**
- **Found during:** Task 1 GREEN verification
- **Issue:** Elixir guards cannot invoke local authority helper functions.
- **Fix:** Moved scope and binding checks into a `cond` after authoritative intent lookup.
- **Files modified:** `../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex`
- **Verification:** Focused suite passed.

**2. [Rule 3 - Blocking test environment] Rebuilt the isolated SQLite test database**
- **Found during:** Task 1 GREEN verification
- **Issue:** The changed example-host migration had already been applied locally, so the isolated test database lacked the new intent columns.
- **Fix:** Ran `MIX_ENV=test mix ecto.reset` before verification.
- **Files modified:** None
- **Verification:** Fresh migration and focused suite passed.

**3. [Rule 3 - Contract fixture drift] Updated resolver test fixture to current normalized policy shape**
- **Found during:** Task 1 GREEN verification
- **Issue:** The fixture used the superseded boolean-style notification-open declaration while the current resolver accepts the normalized `%{actions: [...]}` compiled policy.
- **Fix:** Updated the example-host fixture to the current closed policy representation.
- **Files modified:** `../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registry_notification_open_test.exs`
- **Verification:** Resolver replay test passed through the current policy path.

**Total deviations:** 3 auto-fixed (1 Rule 1, 2 Rule 3). **Impact:** No scope expansion; all fixes were required for correct, reproducible task verification.

## Known Stubs

None.

## Self-Check: PASSED

- CrossWake commits `cd195183` and `26d225cb` exist.
- All key implementation and test files exist.

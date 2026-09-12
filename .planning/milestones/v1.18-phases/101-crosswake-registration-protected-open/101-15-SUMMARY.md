---
phase: 101-crosswake-registration-protected-open
plan: "15"
subsystem: crosswake-example-host
tags: [elixir, ecto, sqlite, authorization, migrations]
requires:
  - phase: 101-crosswake-registration-protected-open
    provides: exact installation binding authority and protected-open consumption
provides:
  - Installation bindings that cannot carry session authority
  - Session-only logout and session-revocation selection
  - SQLite reconciliation and guards for malformed active bindings
affects: [OPEN-01, crosswake-example-host]
tech-stack:
  added: []
  patterns:
    - Scope-specific Ecto query branches use is_nil/1 for installation authority
    - SQLite active-row authority guards enforce the same invariant as command validation
key-files:
  created:
    - ../crosswake/examples/phoenix_host/priv/repo/migrations/20260825180000_enforce_chimeway_binding_scope_consistency.exs
    - .planning/phases/101-crosswake-registration-protected-open/101-15-SUMMARY.md
  modified:
    - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/token_binding.ex
    - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex
    - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs
    - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registry_test.exs
key-decisions:
  - "[101-15]: Subject-installation authority is valid only with nil session_ref and session_version at command, changeset, query, and database boundaries."
  - "[101-15]: Logout and session revocation select active subject-session bindings only; installation authority survives session lifecycle events."
  - "[101-15]: Malformed active rows are terminally revoked with the existing session_revoked reason, and SQLite guards prevent direct insert or update bypasses."
requirements-completed: [OPEN-01]
metrics:
  tasks_completed: 1
  files_modified: 5
  completed: 2026-08-25
status: complete
---

# Phase 101 Plan 15: Installation and Session Authority Separation Summary

**Installation authority is now structurally independent of login sessions, including direct SQLite writes and both session-lifecycle revocation paths.**

## Completed Work

- Rejected installation contexts and binding changesets that carry either session field, while preserving paired non-negative requirements for session scope.
- Scoped logout and session-revocation reads to `:subject_session`; valid installation bindings remain active through both paths.
- Added a forward-only migration that terminally revokes malformed active rows and creates named SQLite INSERT and UPDATE guards.
- Extended focused Ecto/ExUnit evidence for command rejection, lifecycle isolation, migration reconciliation, and direct SQL bypass rejection.

## Verification

- PASS: `cd /Users/jon/projects/crosswake/examples/phoenix_host && MIX_ENV=test mix test test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs test/crosswake_example/chimeway/registry_test.exs --seed 0` — 9 tests, 0 failures.
- PASS: `git -C /Users/jon/projects/crosswake diff --check`.
- PASS: `COVERAGE.md` remains limited to local Ecto/ExUnit scope with no external API surface.

## TDD Gate Compliance

- Task 1 RED: `65dc2274` — changeset and migration regressions failed before the authority repair.
- Task 1 GREEN: `33aa06a4` — scope validation, lifecycle query isolation, migration reconciliation, and SQLite guards passed the focused suite.

## Decisions Made

- Installation-scoped bindings never acquire `session_ref` or `session_version`; invalid values fail closed before a transaction starts.
- Reconciliation retains durable lifecycle evidence by using the existing terminal `session_revoked` reason and does not manufacture replacement authority.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Query bug] Branched installation binding queries before comparing session fields**
- **Found during:** Task 1 GREEN verification
- **Issue:** Ecto rejects a pinned `nil` comparison, preventing a valid installation binding from entering the bind path.
- **Fix:** Added a shared scope-specific query helper that applies exact session comparisons only for session scope and `is_nil/1` checks for installation scope.
- **Files modified:** `../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex`
- **Verification:** Focused deterministic suite passed.
- **Commit:** `33aa06a4`

**Total deviations:** 1 auto-fixed (1 Rule 1). **Impact:** The correction is required for valid installation authority and preserves the plan's fail-closed invariant.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed all five Crosswake implementation/test artifacts and this summary exist.
- Confirmed RED and GREEN commits `65dc2274` and `33aa06a4` exist.

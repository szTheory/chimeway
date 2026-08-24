---
phase: 101-crosswake-registration-protected-open
plan: "04"
subsystem: crosswake-notification-binding-registry
tags: [elixir, ecto, sqlite, apns, concurrency, privacy]
requires:
  - phase: 101-crosswake-registration-protected-open
    provides: protected notification-open binding identity
provides:
  - Exact app-identity, session-version, and binding-revision CAS for permission-loss invalidation
  - Idempotent token observations and safe rotated-revision retention under concurrent lifecycle commands
  - Focused host registry race and token-custody regression evidence
affects: [101-crosswake-registration-protected-open, 102-crosswake-digital-twin]
tech-stack:
  added: []
  patterns: [full-authority-scope predicates, bounded sqlite busy retry, transient-token boundary]
key-files:
  created:
    - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registry_test.exs
    - .planning/phases/101-crosswake-registration-protected-open/101-04-SUMMARY.md
  modified:
    - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex
    - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/token_binding.ex
    - ../crosswake/examples/phoenix_host/priv/repo/migrations/20260602100000_create_chimeway_token_bindings.exs
key-decisions:
  - "[101-04]: The authenticated app identity ref represents the APNs topic/app identity and is a durable binding-scope predicate, never token metadata."
  - "[101-04]: Permission-loss commands require the observed binding_ref plus full tenant, installation, provider, environment, app-identity, subject-session, and active-state scope."
  - "[101-04]: The SQLite example host retries only transient database-busy transaction contention, preserving exact-CAS command behavior for race tests."
metrics:
  duration: 5 min
  completed: 2026-08-24
  tasks_completed: 1
  files_modified: 5
status: complete
---

# Phase 101 Plan 04: Exact Scoped Binding Revisions Summary

**Authenticated APNs observations now retain one current app-scoped revision, while stale lifecycle commands cannot disable a replacement or another installation.**

## Completed Work

- Added RED/GREEN registry coverage for idempotent same-token observations, stale permission-loss commands, concurrent rotation/invalidation, unrelated-scope preservation, and raw-token rejection.
- Bound active token and authority uniqueness to app identity plus session version, and persist the authenticated app identity on every new binding.
- Changed permission-loss invalidation to a full exact-revision CAS predicate and made stale commands a safe zero-row `:no_active_bindings` result.
- Added a bounded retry for transient SQLite write contention so concurrent lifecycle proof reflects the registry CAS rather than crashing the caller.

## Verification

- `cd ../crosswake/examples/phoenix_host && mix test test/crosswake_example/chimeway/registry_test.exs test/crosswake_example/chimeway/registry_notification_open_test.exs --seed 0` — 11 tests, 0 failures.
- `git -C ../crosswake diff --check` — passed.

## TDD Gate Compliance

- RED: `4c48c82d` added a stale permission-loss test which failed because the old broad revocation disabled the rotated replacement.
- GREEN: `7680f2f5` implemented full-scope predicates, identity-aware uniqueness, and concurrent transaction retry; all focused registry tests pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Retried transient SQLite write contention during concurrent registry commands**
- **Found during:** Task 1 concurrency verification
- **Issue:** Simultaneous rotation and stale permission-loss commands could raise `Exqlite.Error: Database busy`, preventing the registry race proof from completing.
- **Fix:** Added a bounded retry that handles only the transient SQLite busy error while retaining exact revision/scope predicates.
- **Files modified:** `../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex`
- **Verification:** Deterministic `Task.async_stream` race test passes with the focused registry suites.
- **Commit:** `7680f2f5`

**Total deviations:** 1 auto-fixed. **Impact:** Local concurrency evidence is deterministic without broadening lifecycle authority.

## Known Stubs

None.

## Self-Check: PASSED

- Required registry, binding schema, migration, and focused test files exist in the CrossWake repository.
- Task commits `4c48c82d` and `7680f2f5` exist in the CrossWake repository.

---
phase: 101-crosswake-registration-protected-open
plan: "12"
subsystem: crosswake-example-host-registration-authority
tags: [elixir, ecto, sqlite, migrations, provider-feedback, authorization]
requires:
  - phase: 101-crosswake-registration-protected-open
    provides: authenticated host binding lifecycle and forward authority migration
provides:
  - Authenticated exact-binding provider invalidation with corroborating token evidence
  - Deterministic reconciliation of authority and token-identity migration collisions
affects: [101-crosswake-registration-protected-open, 102-crosswake-digital-twin]
tech-stack:
  added: []
  patterns:
    - Provider evidence corroborates a host-authenticated exact binding; it never selects revocation authority
    - Forward migrations reconcile every replacement unique-index partition before creating indexes
key-files:
  created: []
  modified:
    - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex
    - ../crosswake/examples/phoenix_host/priv/repo/migrations/20260824210000_upgrade_chimeway_registration_authority.exs
    - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registry_test.exs
    - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs
    - ../crosswake/test/crosswake/proof/phase60_chimeway_registry_test.exs
    - ../crosswake/examples/phoenix_host/README.md
key-decisions:
  - "[101-12]: Invalidating provider feedback is closed unless a host-authenticated exact binding scope matches at selection and conditional update time."
  - "[101-12]: Forward upgrades supersede duplicate active token identities by last_seen_at DESC, id DESC after authority-domain reconciliation."
requirements-completed: [OPEN-01]
coverage:
  - id: D1
    description: Exact authenticated binding scope isolates invalidating provider feedback from token-sharing authority scopes.
    requirement: OPEN-01
    verification:
      - kind: integration
        ref: examples/phoenix_host/test/crosswake_example/chimeway/registry_test.exs#invalidating provider feedback only mutates its authenticated exact binding scope
        status: pass
      - kind: integration
        ref: test/crosswake/proof/phase60_chimeway_registry_test.exs --include requires_example_host
        status: pass
    human_judgment: false
  - id: D2
    description: Forward migration reconciles released-valid same-token rows before token-identity unique-index creation.
    requirement: OPEN-01
    verification:
      - kind: integration
        ref: examples/phoenix_host/test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs
        status: pass
    human_judgment: false
metrics:
  duration: 15 min
  completed: 2026-08-25
  tasks_completed: 2
  files_modified: 6
status: complete
---

# Phase 101 Plan 12: Exact Invalidation and Collision Reconciliation Summary

**Provider invalidation now requires a host-authenticated exact binding revision, and forward upgrades reconcile both replacement active-row identity domains before indexing.**

## Accomplishments

- Added exact authenticated authority predicates to provider-invalidation selection and compare-and-update writes; token ref/fingerprint are corroborating only.
- Added a same-token, different-authority regression plus Phase 60 proof updates and host-worker documentation for resolving authority before mutation.
- Added deterministic token-identity collision reconciliation and a released-boundary migration regression.

## Verification

- PASS: `cd /Users/jon/projects/crosswake/examples/phoenix_host && MIX_ENV=test mix test test/crosswake_example/chimeway/registry_test.exs --seed 0`
- PASS: `cd /Users/jon/projects/crosswake && MIX_ENV=test mix test test/crosswake/proof/phase60_chimeway_registry_test.exs --seed 0`
- PASS: `cd /Users/jon/projects/crosswake/examples/phoenix_host && MIX_ENV=test mix test test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs --seed 0`
- PASS: Phase 60 proof with `--include requires_example_host` (18 tests, 0 failures).
- PASS: `git diff --check`.

## Task Commits

1. **Task 1: Bind provider invalidation to one authenticated exact revision**
   - `96bcbaa0` — RED scoped-feedback regression
   - `9d83a8cd` — exact-scope registry, proof, and documentation implementation
2. **Task 2: Reconcile both forward-migration uniqueness domains**
   - `59afc9f1` — RED released-boundary token-identity collision proof
   - `24214569` — deterministic token-identity reconciliation

## Decisions Made

- Invalidating provider feedback returns the existing closed `:no_active_bindings` outcome for absent, stale, or invalid scope rather than exposing authority detail.
- Both authority and token-identity reconciliation retain only the latest active row ordered by `last_seen_at DESC, id DESC`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated Phase 60 proof fixtures for the current exact binding APIs**
- **Found during:** Task 1
- **Issue:** The executable proof omitted required app identity and permission-loss binding scope fields, preventing its tagged integration path from starting.
- **Fix:** Added host app-identity and exact binding scope inputs while preserving the proof's lifecycle behavior.
- **Files modified:** `../crosswake/test/crosswake/proof/phase60_chimeway_registry_test.exs`
- **Verification:** Tagged Phase 60 proof passed with 18 tests, 0 failures.
- **Committed in:** `9d83a8cd`

## Known Stubs

None.

## Next Phase Readiness

OPEN-01’s scoped provider invalidation and forward migration collision gaps are closed with executable evidence. Plan 101-13's protected-open queue work remains preserved.

## Self-Check: PASSED

- Found all six plan-owned Crosswake files.
- Found task commits `96bcbaa0`, `9d83a8cd`, `59afc9f1`, and `24214569`.
- No tracked file deletions or stub markers were introduced by this plan.

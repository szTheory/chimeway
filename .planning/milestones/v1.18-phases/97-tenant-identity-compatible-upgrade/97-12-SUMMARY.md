---
phase: 97-tenant-identity-compatible-upgrade
plan: 12
subsystem: tenant-isolation
tags: [elixir, ecto, phoenix-liveview, authorization, postgres]
requires:
  - phase: 97-tenant-identity-compatible-upgrade
    provides: explicit tenant identity on the durable lifecycle spine
provides:
  - Tenant-coherent Admin read-model joins and aggregates
  - Feed search event-time authorization and revocation handling
affects: [tenant-isolation-verification, admin-console]
tech-stack:
  added: []
  patterns:
    - Joined DTO queries predicate every lifecycle table against the resolved tenant
    - Mounted LiveView read events re-authorize before constructing read options
key-files:
  created:
    - chimeway_admin/test/chimeway_admin/live/feed_live_test.exs
  modified:
    - lib/chimeway/admin.ex
    - test/chimeway/admin_test.exs
    - chimeway_admin/lib/chimeway_admin/live/feed_live.ex
key-decisions:
  - "[97-12]: Optional delivery joins retain tenant filtering in their ON clauses, so foreign rows cannot contribute counts or summaries."
  - "[97-12]: Feed searches invoke LiveAuth.ensure_authorized/3 with only the normalized recipient identifier before database reads."
patterns-established:
  - "Admin lifecycle DTOs fail closed for split-tenant durable links."
  - "Long-lived operator sockets check host authorization at every sensitive search event."
requirements-completed: [TENANT-02]
coverage:
  - id: D1
    description: Tenant-coherent Admin recent-problem, aggregate, feed, and recovery DTOs
    requirement: TENANT-02
    verification:
      - kind: unit
        ref: mix test test/chimeway/admin_test.exs --warnings-as-errors
        status: pass
    human_judgment: false
  - id: D2
    description: Feed Debug re-authorizes searches and redirects after access revocation
    requirement: TENANT-02
    verification:
      - kind: integration
        ref: mix cmd --cd chimeway_admin mix test test/chimeway_admin/live/feed_live_test.exs --warnings-as-errors
        status: pass
      - kind: automated_ui
        ref: mix verify.admin
        status: pass
    human_judgment: false
duration: 15 min
completed: 2026-08-12
status: complete
---

# Phase 97 Plan 12: Tenant-Coherent Admin Reads and Feed Authorization Summary

**Admin lifecycle DTOs now disclose only fully tenant-coherent rows, and Feed Debug re-checks host authorization for every search.**

## Accomplishments

- Required resolved tenant ownership on Event, Notification, and Delivery joins for recent problems, definitions, feed rows, and recovery candidates.
- Kept foreign optional deliveries out of aggregate counts and summaries while preventing them from masquerading as missing deliveries.
- Added mounted FeedLive proof for normalized recipient authorization and post-mount access revocation before querying.

## Verification

- `mix test test/chimeway/admin_test.exs --warnings-as-errors` — 10 tests, passing.
- `mix cmd --cd chimeway_admin mix test test/chimeway_admin/live/feed_live_test.exs --warnings-as-errors` — 2 tests, passing.
- `mix verify.admin` — passing, including package, demo-host, and browser lanes.

## Task Commits

1. **Task 1: Reject one split-tenant recent-problem lifecycle end to end** — `737266b`, `f44e1e5`
2. **Task 2: Enforce lifecycle-wide tenant coherence for definitions, feed, and recovery DTOs** — `7914c6f`, `e9d2b41`
3. **Task 3: Re-authorize Feed searches after mount** — `f308a02`, `3718777`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected a pre-existing coherent-fixture tenant mismatch**
- **Found during:** Task 2
- **Issue:** The definitions channel test planned its Delivery with the helper default tenant instead of its Notification tenant, making a valid fixture incoherent under the new predicate.
- **Fix:** Set the fixture Delivery tenant to `tenant-a`.
- **Files modified:** `test/chimeway/admin_test.exs`
- **Verification:** Focused Admin suite passes.
- **Commit:** `e9d2b41`

## Known Stubs

None.

## Next Phase Readiness

The remaining Phase 97 reconciliation closure plans can rely on Admin read models failing closed for malformed lifecycle ownership.

## Self-Check: PASSED

- Summary, Admin implementation/tests, and FeedLive implementation/test files exist.
- All six task commits are present in git history.

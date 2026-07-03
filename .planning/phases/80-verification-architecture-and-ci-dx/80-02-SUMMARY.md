---
phase: 80-verification-architecture-and-ci-dx
plan: 02
subsystem: ci-dx
tags: [github-actions, ci, caching, npm, playwright, nested-mix, contract-test]
requires:
  - phase: 80-verification-architecture-and-ci-dx
    provides: two-aggregate pr-gate/ci-gate topology + event-guarded heavy lanes (80-01)
provides:
  - npm (~/.npm via setup-node) + Playwright browser cache on verify_admin (CI-05)
  - Nested chimeway_admin / chimeway_inbox mix deps/_build caches keyed on their own mix.lock (CI-05)
  - Per-lane examples/chimeway_demo_host mix caches across the eight demo-host lanes (CI-05, D-11)
  - Contract-test lock for cache presence + lockfile-only keying (D-12)
affects:
  - phase-80-plan-03-scripts-extraction
  - phase-80-plan-04-docs-and-branch-protection
tech-stack:
  added: []
  patterns:
    - Lockfile-only cache keying (no source/test-artifact hashes) so changed code still recompiles
    - Per-lane demo-host cache key (lane slug + demo-host mix.lock hash) to prevent cross-lane optional-dep contamination
    - setup-node built-in npm cache + actions/cache Playwright browser cache
key-files:
  created:
    - .planning/phases/80-verification-architecture-and-ci-dx/80-02-SUMMARY.md
  modified:
    - .github/workflows/ci.yml
    - test/chimeway/release_gate_contract_test.exs
decisions:
  - "[80-02]: npm cache via setup-node cache: 'npm' + cache-dependency-path: package-lock.json (reuses the already-present setup-node in verify_admin)"
  - "[80-02]: Playwright + nested + demo-host caches reuse the pinned actions/cache SHA 0057852bfaa89a56745cba8c7296529d2fc39830"
  - "[80-02]: Per-lane demo-host key slug is mandatory (D-11) so CHIMEWAY_SKIP_*-driven optional-dep resolutions cannot cross lanes"
metrics:
  duration: 6 min
  completed: 2026-07-03
  tasks: 3
  files_modified: 2
requirements-completed: [CI-05]
status: complete
---

# Phase 80 Plan 02: CI Cache Coverage (npm, Playwright, nested + demo-host mix) Summary

**Added the three uncovered cache cost centers to `ci.yml` — npm (`~/.npm`), Playwright browsers (`~/.cache/ms-playwright`), nested `chimeway_admin`/`chimeway_inbox` mix, and per-lane `examples/chimeway_demo_host` mix caches across eight lanes — all keyed on lockfiles only, and locked the coverage in `release_gate_contract_test.exs`.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-07-03T16:28Z
- **Completed:** 2026-07-03T16:34Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- **npm cache:** extended the existing `verify_admin` `setup-node` step with `cache: 'npm'` and `cache-dependency-path: package-lock.json`, so `npm ci` reuses `~/.npm` (CI-05).
- **Playwright cache:** added an `actions/cache` step (`id: playwright-cache`, `path: ~/.cache/ms-playwright`) keyed on `${{ runner.os }}-playwright-${{ hashFiles('package-lock.json') }}`, placed before `mix verify.admin` so browsers are present when the alias runs `npx playwright install`.
- **Nested mix caches:** `verify_admin` caches `chimeway_admin/deps`+`chimeway_admin/_build` keyed on `chimeway_admin/mix.lock`; `verify_inbox` caches `chimeway_inbox/deps`+`chimeway_inbox/_build` keyed on `chimeway_inbox/mix.lock`.
- **Per-lane demo-host caches:** added `examples/chimeway_demo_host/deps`+`_build` caches to all eight demo-host-compiling lanes (`verify_example`, `verify_journeys`, `verify_mailglass`, `verify_accrue`, `verify_inbox`, `verify_threadline`, `verify_sigra`, `verify_admin`), each with a distinct per-lane key slug + `hashFiles('examples/chimeway_demo_host/mix.lock')` (D-11). No shared/lane-agnostic key.
- **Contract lock:** new `CI cache coverage (CI-05)` describe asserts npm/Playwright/nested markers, per-lane demo-host keys across the eight lanes, a D-11 no-shared-key guard, and a D-12 guard that every cache `hashFiles(...)` references a `mix.lock` or `package-lock.json`.
- No `mix verify.*` alias run step altered; no release/publish/automerge workflow touched (scope boundary held).

## Task Commits

Each task was committed atomically:

1. **Task 1: Cache npm + Playwright + nested admin/inbox mix deps** — `035a404` (feat)
2. **Task 2: Per-lane demo-host mix caches across eight lanes** — `8be3e15` (feat)
3. **Task 3: Lock cache coverage + lockfile-only keying in contract test** — `3a0987c` (test)

## Files Created/Modified

- `.github/workflows/ci.yml` — npm cache on `verify_admin` setup-node; Playwright + nested-admin caches on `verify_admin`; nested-inbox cache on `verify_inbox`; per-lane demo-host caches on all eight demo-host lanes.
- `test/chimeway/release_gate_contract_test.exs` — `@demo_host_cache_lanes` attr; new `CI cache coverage (CI-05)` describe (npm/Playwright/nested assertions, per-lane demo-host loop, D-11 no-shared-key guard, D-12 lockfile-only `hashFiles` guard).
- `.planning/phases/80-verification-architecture-and-ci-dx/80-02-SUMMARY.md` — this summary.

## Decisions Made

- Reused the pinned `actions/cache` SHA `0057852bfaa89a56745cba8c7296529d2fc39830` for every new cache step (no new/unpinned actions).
- Used the built-in `setup-node` npm cache rather than a separate `actions/cache` for `~/.npm`, since `verify_admin` already has a `setup-node` step.
- Placed all new cache steps before the lane's `mix verify.*` run step (right after the existing root `deps`/`_build` cache) so restores happen before compile/install.

## Verification

- PASS: Task 1 automated grep — `cache: 'npm'`, `~/.cache/ms-playwright`, `hashFiles('chimeway_admin/mix.lock')`, `hashFiles('chimeway_inbox/mix.lock')` all present.
- PASS: Task 2 automated — 16 `-mix-demo-` occurrences (8 lanes × key+restore-key), 8 distinct lane slugs, `hashFiles('examples/chimeway_demo_host/mix.lock')` present.
- PASS: `python3 yaml.safe_load` parses `ci.yml` after each task.
- PASS: `mix ci.verify_gates` — 523 tests, 0 failures (up from 510 in Plan 01; +13 new cache tests).
- PASS: `mix format` on the contract test.

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed.

## Threat Mitigations Applied

- T-80-05 (stale/poisoned cache masking a bad dependency): all `_build`/`deps` caches key on `mix.lock`/`package-lock.json` only; the D-12 contract guard asserts every `hashFiles()` references a lockfile, so a source-keyed cache fails the gate.
- T-80-06 (shared demo-host cache serving a foreign optional-dep resolution): per-lane key includes the lane slug; the D-11 contract guard asserts every `-mix-demo-` slug is a known per-lane slug, so a shared key fails the gate.
- T-80-SC (package installs): no new package installs; only cache/setup-node steps reusing existing pinned SHAs.

## Known Stubs

None. Stub-pattern scan of the two modified files found no placeholder/TODO/FIXME or runtime/UI stub content.

## Threat Flags

None. No new network endpoints, auth paths, file-access patterns, or schema changes introduced — only additive cache steps keyed on existing lockfiles.

## User Setup Required

None for this plan.

## Next Phase Readiness

Ready for Plan 03 (scripts extraction) and Plan 04 (docs + branch-protection). Cache coverage is in place and contract-locked; no changes to the two-aggregate topology from Plan 01.

## Self-Check: PASSED

- Found modified file: `.github/workflows/ci.yml`.
- Found modified file: `test/chimeway/release_gate_contract_test.exs`.
- Found task commits: `035a404`, `8be3e15`, `3a0987c`.
- `mix ci.verify_gates` green (523 tests, 0 failures).
- No release/publish/automerge workflow modified.

---
*Phase: 80-verification-architecture-and-ci-dx*
*Completed: 2026-07-03*

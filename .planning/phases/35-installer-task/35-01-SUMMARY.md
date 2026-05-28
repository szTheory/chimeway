---
phase: 35-installer-task
plan: "01"
subsystem: database
tags: [ecto, migrations, installer, mix, hex]

requires:
  - phase: 34
    provides: canonical schema in priv/repo/migrations
provides:
  - 31 Hex-shipped migration templates under priv/chimeway_migrations/
  - Chimeway.Install.Migrations core (list, rewrite, slug idempotency, repo resolution)
  - Pure-function unit tests for installer core
affects:
  - 35-02 (Mix task CLI wrapper)
  - 35-03 (golden-diff contract tests)

tech-stack:
  added: []
  patterns:
    - "Copy-based migration installer with slug idempotency"
    - "Namespace rewrite Chimeway.Repo.Migrations → Host.Repo.Migrations"
    - "Repo resolution via config :chimeway, :repo with mix.exs app fallback"

key-files:
  created:
    - priv/chimeway_migrations/001_create_chimeway_events.exs
    - priv/chimeway_migrations/031_create_chimeway_webhook_ingress.exs
    - lib/chimeway/install/migrations.ex
    - test/chimeway/install/migrations_test.exs
  modified: []

key-decisions:
  - "D-05 Option A: infer {App}.Repo from host mix.exs when config :chimeway, :repo unset"
  - "resolve_repo(nil) clause ordered before is_atom guard — nil is an atom in Elixir"
  - "host_migrations_prefix uses Module.split + join to avoid Elixir. prefix in strings"

patterns-established:
  - "Template marker comment # chimeway_migration: {slug} as first line (D-09)"
  - "Slug validation rejects path traversal characters via ^[a-z0-9_]+$"
  - "Timestamp batch: UTC base + index seconds for FK ordering"

requirements-completed: [INST-01]

duration: 12min
completed: 2026-05-28
---

# Phase 35 Plan 01: Migration Templates & Installer Core Summary

**31 canonical migration templates and testable `Chimeway.Install.Migrations` core with slug idempotency, namespace rewrite, and mix.exs repo fallback**

## Performance

- **Duration:** 12 min
- **Started:** 2026-05-28T20:33:00Z
- **Completed:** 2026-05-28T20:35:14Z
- **Tasks:** 3 completed
- **Files modified:** 33

## Accomplishments

- Extracted 31 ordered migration templates to `priv/chimeway_migrations/` with marker comments; Oban wrapper excluded (D-10)
- Implemented `Chimeway.Install.Migrations` with `list_templates/0`, `run/1`, slug matching, namespace rewrite, and repo resolution
- Added 7 pure-function unit tests covering templates, slug extraction, rewrite, and repo resolution paths

## Task Commits

Each task was committed atomically:

1. **Task 35-01-01: Extract 31 migration templates** - `601b2c6` (feat)
2. **Task 35-01-02: Implement Chimeway.Install.Migrations core module** - `e52f6a7` (feat)
3. **Task 35-01-03: Add pure-function unit tests** - `0babcad` (test)

## Files Created/Modified

- `priv/chimeway_migrations/*.exs` — 31 canonical templates with `# chimeway_migration:` markers
- `lib/chimeway/install/migrations.ex` — installer core module
- `test/chimeway/install/migrations_test.exs` — unit tests for pure functions

## Decisions Made

- Repo fallback from host `mix.exs` `app:` atom when `config :chimeway, :repo` unset (D-05 Option A)
- Fixed `resolve_repo/0` clause ordering: `nil` clause must precede `is_atom` guard because `nil` is an atom in Elixir
- `host_migrations_prefix/1` uses `Enum.join(".")` instead of `Atom.to_string/1` to avoid `Elixir.` prefix

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] resolve_repo(nil) matched is_atom guard**
- **Found during:** Task 35-01-03 (unit tests)
- **Issue:** `resolve_repo/0` always returned `{:error, :repo_missing}` because `nil` matched `when is_atom(repo)`
- **Fix:** Reordered clauses — `resolve_repo(nil)` first, then `when is_atom(repo)`
- **Files modified:** `lib/chimeway/install/migrations.ex`
- **Verification:** `mix test test/chimeway/install/migrations_test.exs --warnings-as-errors` passes
- **Committed in:** `0babcad`

**2. [Rule 1 - Bug] host_migrations_prefix included Elixir. prefix**
- **Found during:** Task 35-01-03 (unit tests)
- **Issue:** `Atom.to_string/1` on concatenated module produced `"Elixir.InstallerHost.Repo.Migrations"`
- **Fix:** Use `Enum.join(".")` on module segments instead
- **Files modified:** `lib/chimeway/install/migrations.ex`
- **Verification:** unit test `host_migrations_prefix/1` passes
- **Committed in:** `0babcad`

---

**Total deviations:** 2 auto-fixed (2 bugs)
**Impact on plan:** Both fixes required for correct repo resolution and namespace rewrite. No scope creep.

## Issues Encountered

None beyond the two bugs caught and fixed during test task.

## Verification Results

```
mix test test/chimeway/install/migrations_test.exs --warnings-as-errors  → 7 tests, 0 failures
mix compile --warnings-as-errors                                        → success
ls priv/chimeway_migrations/*.exs | wc -l                               → 31
grep -r '^# chimeway_migration:' priv/chimeway_migrations/ | wc -l      → 31
```

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for **35-02**: thin `Mix.Tasks.Chimeway.Gen.Migrations` wrapper calling `Chimeway.Install.Migrations.run/1`
- Ready for **35-03**: golden-diff fixture and idempotency contract tests
- INST-01 partially complete (core + templates); full INST-01/INST-02 need plans 02–03

## Self-Check: PASSED

- All 3 tasks committed atomically with 35-01 references
- All acceptance criteria verified
- Unit tests green

---
*Phase: 35-installer-task*
*Completed: 2026-05-28*

---
phase: 35
name: installer-task
status: passed
score: 15/15
requirements:
  INST-01: passed
  INST-02: passed
verified_at: 2026-05-28
---

# Phase 35 Verification: Installer Task

**Goal:** Ship copy-based installer with `mix chimeway.gen.migrations`, golden-diff and idempotency CI contracts (INST-01, INST-02)

**Status:** `passed` — all must-haves verified against codebase; contract tests green.

## Requirements Traceability

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| **INST-01** | Host developer can run documented Mix task to generate Chimeway migrations without hand-copying schema files | **passed** | `Mix.Tasks.Chimeway.Gen.Migrations` delegates to `Chimeway.Install.Migrations.run/1`; tmp-host and subprocess tests create 31 namespaced files; task name matches `guides/introduction/installation.md` |
| **INST-02** | Installer output is idempotent and verified by golden-diff or contract test | **passed** | `golden_diff_test.exs` and `idempotency_test.exs` pass; committed fixture at `test/fixtures/installer_golden/`; `mix ci.install_golden` alias and path-gated CI job wired |

## Plan 35-01 Must-Haves

| Check | Result |
|-------|--------|
| Exactly 31 canonical templates under `priv/chimeway_migrations/` (001–031) | ✅ `ls priv/chimeway_migrations/*.exs \| wc -l` → 31 |
| Oban wrapper excluded (D-10) | ✅ 0 oban matches; no `create_oban_jobs_tables` |
| Each template has `# chimeway_migration: {slug}` marker (D-09) | ✅ 31 marker lines |
| Templates retain `Chimeway.Repo.Migrations` prefix (rewrite at generation) | ✅ 31 files contain prefix |
| `Chimeway.Install.Migrations` core: list, rewrite, slug idempotency, repo resolution | ✅ Public API present: `list_templates/0`, `run/1`, `resolve_repo!/0`, `extract_slug/1`, `rewrite_namespace/2`, `find_existing_by_slug/2`, `host_migrations_prefix/1` |
| Pure-function unit tests pass without subprocess or Postgres | ✅ 7 unit tests in `migrations_test.exs` |

## Plan 35-02 Must-Haves

| Check | Result |
|-------|--------|
| `mix chimeway.gen.migrations` exists as `Mix.Tasks.Chimeway.Gen.Migrations` (D-01) | ✅ Module and `@shortdoc` present |
| Task calls `Mix.Task.run("app.config")` then `Chimeway.Install.Migrations.run/1` | ✅ Verified in source |
| No `mix chimeway.install` shipped (D-02) | ✅ 0 matches under `lib/` |
| First run in tmp host creates 31 files with `InstallerHost.Repo.Migrations` namespaces | ✅ Integration tests pass |
| Task name matches `guides/introduction/installation.md` without doc edits (D-14) | ✅ Line 30 references `mix chimeway.gen.migrations` |
| Subprocess CLI smoke test | ✅ `mix chimeway.gen.migrations` subprocess test passes |

## Plan 35-03 Must-Haves

| Check | Result |
|-------|--------|
| Committed golden fixture with STDOUT.txt and 31-file tree (D-11) | ✅ `test/fixtures/installer_golden/STDOUT.txt` + 31 `TIMESTAMP_*.exs` files |
| Golden tree has no `Chimeway.Repo.Migrations` or Oban slugs | ✅ 0 matches |
| Idempotency contract: second run zero diff, 31× unchanged stdout (D-12) | ✅ `idempotency_test.exs` passes |
| `mix ci.install_golden` alias runs both contract tests (D-13) | ✅ Alias in `mix.exs`; not in default `ci:` chain |
| Path-gated `install_golden_contract` CI job; always runs on push to main (D-13) | ✅ Job in `.github/workflows/ci.yml` with path regex and `fetch-depth: 0` |
| `MIX_INSTALLER_ACCEPT_GOLDEN=1` refresh gate documented and functional | ✅ Documented in `golden_diff_test.exs` @moduledoc; env var in `installer_fixture.ex` |
| CONTRIBUTING.md documents `mix ci.install_golden` | ✅ CI table row present |

## Test Execution Evidence

```
mix ci.install_golden
→ 2 tests, 0 failures (32.7s)

mix test test/chimeway/install/ --warnings-as-errors
→ 13 tests, 0 failures (46.9s)
```

## Artifacts Verified

| Artifact | Path | Status |
|----------|------|--------|
| Migration templates | `priv/chimeway_migrations/` (31 files) | ✅ |
| Installer core | `lib/chimeway/install/migrations.ex` | ✅ |
| Mix task | `lib/mix/tasks/chimeway.gen.migrations.ex` | ✅ |
| Unit + integration tests | `test/chimeway/install/migrations_test.exs` | ✅ |
| Golden-diff contract | `test/chimeway/install/golden_diff_test.exs` | ✅ |
| Idempotency contract | `test/chimeway/install/idempotency_test.exs` | ✅ |
| Test harness | `test/support/installer_fixture.ex` | ✅ |
| Golden fixture | `test/fixtures/installer_golden/` | ✅ |
| CI alias | `mix.exs` → `ci.install_golden` | ✅ |
| CI job | `.github/workflows/ci.yml` → `install_golden_contract` | ✅ |

## Score

**15/15 must-have checks passed (100%)**

- Plan 35-01: 5/5
- Plan 35-02: 5/5
- Plan 35-03: 5/5

## Gaps Found

None. Phase 35 goal achievement is complete.

## Notes

- D-14 scope respected: `guides/introduction/installation.md` and README were not modified during Phase 35; task name already matched docs.
- Default `mix ci` gate intentionally excludes `ci.install_golden` (fast core gate per D-13); installer contracts run via dedicated alias and path-gated CI job.
- Maintainer golden refresh procedure: `MIX_INSTALLER_ACCEPT_GOLDEN=1 mix test test/chimeway/install/golden_diff_test.exs --warnings-as-errors`

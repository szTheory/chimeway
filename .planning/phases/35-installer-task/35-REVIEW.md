---
phase: 35-installer-task
reviewed: 2026-05-28T21:30:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - lib/chimeway/install/migrations.ex
  - lib/mix/tasks/chimeway.gen.migrations.ex
  - test/support/installer_fixture.ex
  - test/chimeway/install/migrations_test.exs
  - test/chimeway/install/golden_diff_test.exs
  - test/chimeway/install/idempotency_test.exs
  - priv/chimeway_migrations/*.exs
  - mix.exs
  - .github/workflows/ci.yml
  - CONTRIBUTING.md
  - .formatter.exs
  - .credo.exs
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 35: Code Review Report

**Reviewed:** 2026-05-28  
**Depth:** standard  
**Files Reviewed:** 11 (plus 31 migration templates spot-checked)  
**Status:** issues_found

## Summary

Phase 35 delivers a solid copy-based migration installer: slug-validated idempotency, namespace rewrite, golden-diff and idempotency contract tests, and a path-gated CI job. Prior phase bugs (nil repo clause ordering, `host_migrations_prefix/1` Elixir prefix, `run/1` return value) appear fixed and verified.

No critical or security blockers were found. Slug validation (`^[a-z0-9_]+$`) correctly prevents path traversal in wildcard lookups. Three warnings cover umbrella-app repo inference gaps, duplicate-slug edge cases, and a CI path-gate hole. Three info items note Mix coupling in the core module, duplicated test scaffolding, and lenient repo validation.

**Verification run during review:**

```
mix ci.install_golden                                              → 2 tests, 0 failures
mix test test/chimeway/install/migrations_test.exs --warnings-as-errors → 11 tests, 0 failures
```

---

## Critical Issues

None.

---

## Warnings

### WR-01: Umbrella apps cannot infer the correct host repo from root `mix.exs`

**File:** `lib/chimeway/install/migrations.ex:203-212`

**Issue:** `infer_repo_from_mix_exs/0` reads `File.cwd!/mix.exs` and regex-matches `app: :some_app`, then assumes `SomeApp.Repo`. Umbrella roots typically declare `apps_path` and child apps live under `apps/my_app/` with their own repos. Running `mix chimeway.gen.migrations` from the umbrella root (without `config :chimeway, repo:`) will infer the wrong module or fail with `:repo_missing`.

**Fix:** Document the limitation in the Mix task moduledoc and installation guide (require explicit `config :chimeway, repo:` for umbrellas). Optionally detect `apps_path` and fail with a targeted message instead of silent wrong inference.

---

### WR-02: Duplicate slug files leave orphan migrations undetected

**File:** `lib/chimeway/install/migrations.ex:134-139`

**Issue:** `find_existing_by_slug/2` uses `Path.wildcard("*_{slug}.exs")`, sorts, and returns `List.first/1`. If an operator manually duplicates a migration with the same slug but a different timestamp, idempotency matches only the first sorted path. A re-run prints `unchanged` for that file and never reconciles the duplicate; Ecto may attempt to run both.

**Fix:** When multiple matches exist, emit a warning listing all paths, or fail fast with an actionable error. At minimum, document that slug uniqueness is a host invariant.

---

### WR-03: CI path gate misses workflow and tooling config changes

**File:** `.github/workflows/ci.yml:100`

**Issue:** The PR path gate covers installer surfaces (`priv/chimeway_migrations/`, `lib/chimeway/install/`, fixtures, etc.) but not `.github/workflows/ci.yml`, `.formatter.exs`, or `.credo.exs`. A PR that only changes the `install_golden_contract` job or golden-exclusion rules can merge without running the contract on the PR (push to `main` still runs unconditionally).

**Fix:** Extend the grep pattern to include `^\.github/workflows/ci\.yml$`, `^\.formatter\.exs$`, and `^\.credo\.exs$`.

---

## Info

### IN-01: Installer core defaults to `Mix.shell()` for IO

**File:** `lib/chimeway/install/migrations.ex:42`

**Issue:** `run/1` defaults `io` to `Mix.shell()`, coupling `Chimeway.Install.Migrations` to Mix at runtime. Callers outside Mix must pass a custom `:io` (as tests do via capture). Acceptable for a Mix-first installer, but worth noting if a programmatic API is added later.

**Fix:** No change required for Phase 35; consider a behaviour or plain `IO` default if non-Mix callers emerge.

---

### IN-02: Duplicated tmp-host scaffold between test modules

**Files:** `test/chimeway/install/migrations_test.exs:249-297`, `test/support/installer_fixture.ex:220-253`

**Issue:** Both modules embed nearly identical `InstallerHost.MixProject` scaffolds (path dep, Oban, config). Drift between integration and golden tests is possible when deps or config change.

**Fix:** Consolidate scaffold generation into `Chimeway.Test.InstallerFixture` and reuse from `migrations_test.exs`.

---

### IN-03: Repo validation checks naming convention only

**File:** `lib/chimeway/install/migrations.ex:191-198`

**Issue:** `validate_repo!/1` accepts any atom whose string form ends with `.Repo` without verifying `use Ecto.Repo`. Misconfiguration with a similarly named module passes validation and fails later at migrate time.

**Fix:** Intentional leniency for Phase 35; optional hardening could call `Code.ensure_loaded?/1` and check behaviour.

---

## Positive Observations

- Slug validation and marker comments (`# chimeway_migration:`) provide stable idempotency and future upgrade hooks (D-07, D-09).
- Golden fixture normalization (timestamps, tmp paths, ANSI stripping) is thorough and matches committed fixtures byte-for-byte.
- Mix task rejects unexpected argv strictly and surfaces a clear repo resolution error.
- `mix ci.install_golden` is correctly excluded from default `mix ci` for fast core feedback while remaining path-gated in CI.
- Formatter and Credo exclusions for `test/fixtures/` preserve byte-stable golden snapshots without weakening lint on source code.

---

## Recommendation

**Ship with follow-ups.** No blockers for Phase 35 closure. Address WR-03 before the next CI workflow edit; document WR-01 for umbrella hosts in Phase 36 docs.

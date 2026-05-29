---
phase: 35-installer-task
fixed_at: 2026-05-28T21:00:00Z
review_path: .planning/phases/35-installer-task/35-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 35: Code Review Fix Report

**Fixed at:** 2026-05-28  
**Source review:** `.planning/phases/35-installer-task/35-REVIEW.md`  
**Iteration:** 1

**Summary:**
- Findings in scope: 3
- Fixed: 3
- Skipped: 0

## Fixed Issues

### WR-01: Umbrella apps cannot infer the correct host repo from root mix.exs

**Files modified:** `lib/chimeway/install/migrations.ex`, `lib/mix/tasks/chimeway.gen.migrations.ex`, `test/chimeway/install/migrations_test.exs`  
**Commit:** 76e481f, d28df04  
**Applied fix:** Detect `apps_path` in umbrella root `mix.exs` and return `{:error, :umbrella_root}` instead of wrong inference. Mix task moduledoc and error message document explicit `config :chimeway, repo:` requirement for umbrellas.

### WR-02: Duplicate slug files leave orphan migrations undetected

**Files modified:** `lib/chimeway/install/migrations.ex`, `test/chimeway/install/migrations_test.exs`  
**Commit:** 76e481f  
**Applied fix:** Added `DuplicateSlugError` and fail-fast in `find_existing_by_slug/2` when multiple `*_{slug}.exs` files exist, listing all conflicting paths.

### WR-03: CI path gate misses workflow and tooling config changes

**Files modified:** `.github/workflows/ci.yml`  
**Commit:** 8fc07f5  
**Applied fix:** Extended PR path gate grep to include `.github/workflows/ci.yml`, `.formatter.exs`, and `.credo.exs`.

## Skipped Issues

None — all in-scope findings were fixed.

---

_Fixed: 2026-05-28_  
_Fixer: Claude (gsd-code-fixer)_  
_Iteration: 1_

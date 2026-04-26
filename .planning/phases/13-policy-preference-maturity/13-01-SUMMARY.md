---
phase: 13-policy-preference-maturity
plan: "01"
subsystem: preferences
tags: [preferences, categories, ecto, policy]

requires:
  - phase: 12-oban-transactional-dispatch-consistency
    provides: transactional Oban dispatch baseline
provides:
  - category preference storage and lookup APIs
  - default-enabled semantics for missing category rows
affects:
  - phase 13-policy-preference-maturity (13-03 wiring)

tech-stack:
  added:
    - Ecto schema for category preferences
  patterns:
    - string-only category preference keys
    - default-enabled semantics for missing preference rows

key-files:
  created:
    - lib/chimeway/preferences/category_preference.ex
    - priv/repo/migrations/20260425000100_create_chimeway_category_preferences.exs
  modified:
    - lib/chimeway/preferences.ex
    - test/chimeway/preferences_test.exs

key-decisions:
  - "Store category preferences in a separate durable table keyed by recipient and notification_category."
  - "Normalize category keys as strings only — never derive atoms from runtime input."

patterns-established:
  - "String-only category keys: changesets reject atom inputs; lookups always work on strings."
  - "Default-enabled semantics: missing category preference rows mean delivery is enabled."

requirements-completed: ["POL-01"]

duration: ~7 min
completed: 2026-04-25
---

# Phase 13, Plan 01: Category Preferences Summary

**Chimeway can now persist category-level notification preferences with default-enabled semantics, alongside the existing channel preference store.**

## Performance

- **Tasks:** 3/3
- **Files modified:** 4
- **Verification:** `mix compile --warnings-as-errors`, `mix test test/chimeway/preferences_test.exs`

## Accomplishments

- Added `chimeway_category_preferences` table with unique `recipient_id` + `notification_category` index.
- Added `Chimeway.Preferences.CategoryPreference` schema and changeset.
- Extended `Chimeway.Preferences` with `upsert_category_preference/1`, `get_category_preference/2`, and `category_enabled?/2` (defaulting to true when no row exists).
- Expanded `test/chimeway/preferences_test.exs` with category create/update/default coverage and a channel-preference dedupe regression.

## Task Commits

1. **Task 1+2+3 RED:** `62c8af6` — `test(13-01): add failing category preference tests`
2. **Task 1+2+3 GREEN:** `74caae3` — `fix(13-01): add category preference storage and lookup`

## Files Created/Modified

- `lib/chimeway/preferences/category_preference.ex` — Category preference schema and changeset.
- `priv/repo/migrations/20260425000100_create_chimeway_category_preferences.exs` — Category preference table and unique index.
- `lib/chimeway/preferences.ex` — Added category upsert/get/enabled APIs.
- `test/chimeway/preferences_test.exs` — Category coverage plus channel preference regression.

## Decisions Made

- Category preference rows are durable and keyed by `recipient_id` + `notification_category`.
- `category_enabled?/2` defaults to `true` when no row exists, matching the channel preference default.
- Category strings flow through changesets as strings only — no atom conversion at any boundary.

## Deviations from Plan

None — plan executed as written.

## TDD Gate Compliance

Compliant — `test(13-01)` commit precedes `fix(13-01)` commit.

## Verification Results

| Check | Result |
|-------|--------|
| `mix compile --warnings-as-errors` | PASS |
| `mix test test/chimeway/preferences_test.exs` | PASS |
| `rg "category_enabled\?\|upsert_category_preference\|get_category_preference" lib/chimeway/preferences.ex` | matches present |

## Self-Check: PASSED

- Category preference schema, migration, and APIs exist on disk.
- All listed commits are present in git history.
- Phase-level `13-SUMMARY.md` corroborates this plan's outcomes.

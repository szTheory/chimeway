---
phase: 36-golden-path-version-alignment
plan: "01"
subsystem: docs
tags: [hexdocs, onboarding, explainability, golden-path]

requires: []
provides:
  - guides/introduction/golden-path.md (sections 1-7)
  - HexDocs extras registration for golden-path
affects: [36-02, 36-03]

key-files:
  created:
    - guides/introduction/golden-path.md
  modified:
    - mix.exs

requirements-completed: [DOCS-01]

duration: 15min
completed: 2026-05-28
---

# Phase 36 Plan 01 Summary

**Shipped the canonical golden-path guide from `{:chimeway, "~> 0.1"}` through `Chimeway.Traces.explain_delivery/1` proof, registered in HexDocs extras.**

## Performance

- **Tasks:** 4/4
- **Files modified:** 2

## Accomplishments

- Created `guides/introduction/golden-path.md` with sections 1–7 (dependency → migrations → dual config → notifier → trigger → explainability → next steps)
- Documented shared-database `Chimeway.Repo` config alongside installer `repo:` config
- Registered guide in `mix.exs` extras after `installation.md`
- `mix ci.docs` passes

## Task Commits

1. **Task 36-01-01–03: golden-path sections 1–7** - `b8a40b3` (docs)
2. **Task 36-01-04: mix.exs extras** - `b7a4c95` (docs)

## Self-Check: PASSED

- `guides/introduction/golden-path.md` exists
- `mix.exs` contains `guides/introduction/golden-path.md`
- Grep gates: no `resolve_recipients`, no `~> 1.0`, trigger opts balanced

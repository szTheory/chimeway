---
phase: 36-golden-path-version-alignment
plan: "02"
subsystem: docs
tags: [readme, installation, semver, onboarding]

requires:
  - phase: 36-01
    provides: golden-path.md exists for cross-links
provides:
  - DOCS-02 version alignment across README and installation
  - golden-path-first onboarding navigation
affects: [36-03]

key-files:
  modified:
    - README.md
    - guides/introduction/installation.md

requirements-completed: [DOCS-02]

duration: 10min
completed: 2026-05-28
---

# Phase 36 Plan 02 Summary

**Aligned consumer-facing version strings to `~> 0.1` and made README/installation route adopters to golden-path first.**

## Task Commits

1. **Task 36-02-01: installation version + Repo cross-link** - `d0d6595` (docs)
2. **Task 36-02-02: README rewrite** - `8c77815` (docs)
3. **Task 36-02-03: Next Steps** - included in `d0d6595` (installation.md written with Next Steps)

## Self-Check: PASSED

- No `~> 1.0.0` in installation or README
- No `resolve_recipients` in README
- golden-path linked from README (Quick Start + Documentation) and installation Next Steps

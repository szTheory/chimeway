---
phase: 21-template-versioning-rendering-contracts
plan: 01
subsystem: rendering
tags: [rendering, contracts, notifications, deliveries, tdd]
requires:
  - phase: 20-digest-emission-explainability
    provides: canonical delivery lifecycle and payload-safe trace patterns
provides:
  - durable rendering fields on notifications and deliveries
  - normalized notifier rendering declarations with legacy fallback
  - regression coverage for render identity durability
affects: [delivery-planning, traces, preview, phase-21]
tech-stack:
  added: []
  patterns: [durable render identity, normalized notifier rendering contracts, explicit map-backed render fields]
key-files:
  created:
    - priv/repo/migrations/20260428123000_add_rendering_contract_fields.exs
    - lib/chimeway/rendering.ex
    - test/chimeway/rendering/render_identity_integration_test.exs
  modified:
    - lib/chimeway/notifications/notification.ex
    - lib/chimeway/delivery.ex
    - lib/chimeway/notifier.ex
    - test/chimeway/notifier_contract_test.exs
key-decisions:
  - "Render identity persists as explicit delivery fields instead of being folded into planning_context."
  - "Notifier modules may declare rendering/2, but build/2 remains a compatibility fallback that derives stable per-channel identity."
  - "Rendering normalization rejects blank render keys, invalid channels, and non-positive versions before any persistence."
patterns-established:
  - "Keep durable rendering inputs as explicit map-backed schema fields on canonical rows."
  - "Route notifier rendering declarations through one Chimeway.Rendering normalization seam."
requirements-completed: [TMPL-01, TMPL-02]
duration: 18min
completed: 2026-04-28
---

# Phase 21 Plan 01: Template Versioning & Rendering Contracts Summary

**Durable rendering identity and notifier rendering normalization now anchor Phase 21's content pipeline**

## Accomplishments
- Added notification `render_assigns` plus delivery `render_key`, `render_version`, and `render_data` storage with an explicit migration.
- Introduced `Chimeway.Rendering.resolve_declaration/4` and the optional notifier `rendering/2` callback with validated legacy fallback behavior.
- Added regression coverage proving render identity lives on canonical delivery rows independently from notifier module names.

## Task Commits
1. **Task 1: Add durable rendering fields and seed the render-identity regression** - `d0fe75f`
2. **Task 2: Define the normalized notifier rendering declaration seam** - `2b31b14`

## Verification
- `mix test test/chimeway/rendering/render_identity_integration_test.exs test/chimeway/notifier_contract_test.exs --trace`

## Deviations from Plan
None - plan executed as written.

## Self-Check: PASSED
- Verified the render identity integration test passes against the new notification and delivery fields.
- Verified notifier contract coverage passes for explicit declarations, compatibility fallback, and tagged normalization failures.

---
*Phase: 21-template-versioning-rendering-contracts*
*Completed: 2026-04-28*

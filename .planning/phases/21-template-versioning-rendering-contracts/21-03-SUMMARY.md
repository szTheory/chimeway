---
phase: 21-template-versioning-rendering-contracts
plan: 03
subsystem: rendering
tags: [rendering, contracts, notifications, deliveries, tdd]
requires:
  - phase: 21-template-versioning-rendering-contracts
    provides: durable render identity and persisted render assigns on canonical rows
provides:
  - explicit in-app render payload validation
  - explicit email render payload validation
  - shared channel render dispatch with tagged runtime failures
affects: [rendering, preview, delivery-planning, phase-21]
tech-stack:
  added: []
  patterns: [channel-specific changeset validation, shared render dispatch, tagged payload contract failures]
key-files:
  created:
    - lib/chimeway/rendering/channels/in_app.ex
    - lib/chimeway/rendering/channels/email.ex
    - test/chimeway/rendering/channel_contract_test.exs
  modified:
    - lib/chimeway/rendering.ex
key-decisions:
  - "Channel render contracts stay pure maps validated by Ecto changesets so the core library remains independent from Phoenix and Swoosh."
  - "Shared render dispatch wraps validation failures with channel-tagged errors to match existing planner normalization and test posture."
patterns-established:
  - "Validate each channel's render payload through a dedicated module instead of accepting opaque render_data maps."
  - "Normalize render output into channel/render_key/render_version/render_data tuples before later persistence or preview steps."
requirements-completed: [TMPL-02]
duration: 5min
completed: 2026-04-28
---

# Phase 21 Plan 03: Template Versioning & Rendering Contracts Summary

**Shared render dispatch now turns durable assigns into explicit in-app and email payload contracts with runtime validation and tagged failures**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-28T19:13:00Z
- **Completed:** 2026-04-28T19:18:07Z
- **Tasks:** 1
- **Files modified:** 4

## Accomplishments
- Added `Chimeway.Rendering.render_delivery/4` to normalize channel requests and dispatch them through explicit validators.
- Introduced dedicated `:in_app` and `:email` channel contract modules backed by Ecto changesets rather than free-form payload maps.
- Locked the runtime failure shape with a focused channel contract test covering valid output and malformed email payload rejection.

## Task Commits

Each task was committed atomically:

1. **Task 1: Build explicit in-app and email renderer contracts** - `5f90878` (`test`), `8e4211e` (`feat`)

_Note: TDD tasks may have multiple commits (test → feat → refactor)_

## Files Created/Modified
- `lib/chimeway/rendering.ex` - Adds shared `render_delivery/4` dispatch, normalization, and tagged error wrapping.
- `lib/chimeway/rendering/channels/in_app.ex` - Validates semantic inbox fields and nested primary-action data.
- `lib/chimeway/rendering/channels/email.ex` - Validates explicit email payload fields for subject and both body variants.
- `test/chimeway/rendering/channel_contract_test.exs` - Pins valid channel outputs and deterministic runtime validation failures.

## Decisions Made
- Used changeset-backed validation in the channel modules so render contract errors match the rest of the library's validation posture.
- Kept the render output as normalized maps with string keys, which matches the durable map-backed storage already introduced on deliveries.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The first GREEN pass only failed on an over-specific test assertion for `traverse_errors/2`; the assertion was tightened to the actual error shape and the targeted suite then passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 21 can now persist validated per-channel `render_data` through one shared runtime contract seam.
- No blockers identified for `21-04`.

## Self-Check: PASSED

- Verified `.planning/phases/21-template-versioning-rendering-contracts/21-03-SUMMARY.md` exists on disk.
- Verified task commits `5f90878` and `8e4211e` exist in git history.

---
*Phase: 21-template-versioning-rendering-contracts*
*Completed: 2026-04-28*

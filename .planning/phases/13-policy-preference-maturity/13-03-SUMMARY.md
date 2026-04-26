---
phase: 13-policy-preference-maturity
plan: "03"
subsystem: policy
tags: [policy, dispatch, suppression, sync, oban]

requires:
  - plan: 13-01
    provides: category preference storage and lookup APIs
  - plan: 13-02
    provides: quiet-hours and delivery-cap policy settings
provides:
  - combined preference and policy evaluation entry point
  - planning-time and perform-time suppression coverage in both sync and Oban dispatch
affects:
  - downstream dispatch hardening (phase 14+)

tech-stack:
  patterns:
    - policy evaluation that suppresses before enqueue and before adapter execution
    - category resolved from persisted event payload only, never from dispatch opts

key-files:
  modified:
    - lib/chimeway/policy.ex
    - test/chimeway/policy_test.exs
    - test/chimeway/dispatch/sync_test.exs
    - test/chimeway/dispatch/oban_test.exs

key-decisions:
  - "Evaluate category rules first, then quiet-hours/delivery-cap settings, then existing read-state suppression."
  - "Derive notification category from `event.payload[\"category\"]` only — never from caller-supplied dispatch options."
  - "Return only fixed suppress atoms (`:channel_disabled`, `:category_disabled`, `:quiet_hours`, `:delivery_cap`)."

patterns-established:
  - "Two-gate suppression: planning-time (before enqueue) and perform-time (before adapter) both consult Policy.evaluate/2."
  - "Sync and Oban dispatch suites share suppression assertions to keep behavior aligned."

requirements-completed: ["POL-03"]

duration: ~5 min
completed: 2026-04-26
---

# Phase 13, Plan 03: Policy Wiring & Dispatch Suppression Summary

**`Policy.evaluate/2` now consults category preferences and per-recipient policy settings before returning proceed, and both sync and Oban dispatch suites prove suppression happens before enqueue and before adapter execution.**

## Performance

- **Tasks:** 2/2
- **Files modified:** 4
- **Verification:** `mix compile --warnings-as-errors`, targeted policy + dispatch suites, full `mix test`

## Accomplishments

- Updated `Policy.evaluate/2` to consult channel preferences, category preferences, and `Policy.Settings.evaluate/1` in that order before returning `{:ok, :proceed}`.
- Resolved notification category from `event.payload["category"]` only; dispatch opts cannot override the persisted source of truth.
- Kept telemetry metadata string-safe — no atoms derived from runtime input.
- Extended `test/chimeway/policy_test.exs`, `test/chimeway/dispatch/sync_test.exs`, and `test/chimeway/dispatch/oban_test.exs` to exercise category, quiet-hours, and cap suppression at both planning-time and perform-time.
- Asserted that suppressed deliveries never reach the adapter and still persist stable suppression reasons.

## Task Commits

1. **Task 1+2 GREEN:** `0363df4` — `fix(13-03): wire policy evaluation and dispatch suppression coverage`

**Plan metadata:** `2d30ccc` — `docs(13-all): complete policy-preference-maturity plan set`

## Files Modified

- `lib/chimeway/policy.ex` — Combined preference and policy-settings evaluation entry point.
- `test/chimeway/policy_test.exs` — Policy-level suppression coverage for category, quiet-hours, delivery-cap, and channel reasons.
- `test/chimeway/dispatch/sync_test.exs` — Planning-time and perform-time sync suppression assertions.
- `test/chimeway/dispatch/oban_test.exs` — Planning-time and perform-time Oban suppression assertions.

## Decisions Made

- Evaluation order: category → quiet-hours/delivery-cap → existing read-state suppression.
- Category source is persisted event payload data only, preventing caller spoofing.
- Suppress reasons are a fixed set of atoms; new reasons require explicit code changes, not dynamic input.

## Deviations from Plan

None substantive — plan executed as written.

## TDD Gate Compliance

Warning — Task 1 and Task 2 landed in a single GREEN commit (`0363df4`) without a separate preceding `test(13-03): ...` RED commit. The behavior is fully covered by the new tests inside that commit, but the standalone red gate is not visible in `git log`. Tracked as a TDD discipline note for future audits; not a functional gap.

## Verification Results

| Check | Result |
|-------|--------|
| `mix compile --warnings-as-errors` | PASS |
| `mix test test/chimeway/policy_test.exs test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_test.exs` | PASS |
| `mix test` (full suite) | PASS — 177 tests, 0 failures |
| `rg "category_enabled\?\|Policy\.Settings\|quiet_hours\|delivery_cap" lib/chimeway/policy.ex` | matches present |

## Self-Check: PASSED

- `lib/chimeway/policy.ex` references the new preference and settings APIs.
- All sync and Oban dispatch tests assert suppression at both gates.
- All listed commits are present in git history.
- Phase-level `13-SUMMARY.md` corroborates this plan's outcomes (including the TDD gate warning above).

---
phase: 29-outbound-channel-contracts
plan: "01"
subsystem: rendering
tags: [elixir, behaviour, channel, rendering, contract, compile-time]

# Dependency graph
requires: []
provides:
  - Public Chimeway.Rendering.Channel behaviour with @callback validate/1
  - __using__/1 macro that injects @behaviour Chimeway.Rendering.Channel
affects:
  - 29-02-migration-schema
  - 29-03-channel-modules
  - 29-04-registry-resolver
  - 29-05-adapter-resolution

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Behaviour + __using__/1 macro convention mirroring Chimeway.Notifier (D-11)"
    - "Compile-time contract for channel render validators via @impl checking"

key-files:
  created:
    - lib/chimeway/rendering/channel.ex
    - test/chimeway/rendering/channel_behaviour_test.exs
  modified: []

key-decisions:
  - "Channel render contract is formalized as a public behaviour module so @impl annotations surface typo'd or missing validate/1 callbacks at compile time"
  - "use Chimeway.Rendering.Channel injects only @behaviour — no other code is generated, keeping the macro auditable and side-effect free (T-29-01 disposition: accept)"

patterns-established:
  - "Behaviour mirroring: Chimeway.Rendering.Channel adopts the same __using__/1 shape as Chimeway.Notifier so future channel modules read the same way as existing notifier modules"
  - "Compile-time validation gate: every channel render module will declare use Chimeway.Rendering.Channel in Plan 03 to opt into compiler warnings"

requirements-completed: [CHAN-01, CHAN-02]

# Metrics
duration: ~10 min
completed: 2026-04-30
---

# Phase 29 Plan 01: Channel Behaviour Summary

**Public `Chimeway.Rendering.Channel` behaviour with `@callback validate/1` and `__using__/1` macro mirroring the `Chimeway.Notifier` pattern (D-11), unlocking compile-time `@impl` checking for every built-in and host-defined channel render validator.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-30T20:14:24Z
- **Completed:** 2026-05-01T01:31:31Z
- **Tasks:** 1 (TDD: RED + GREEN)
- **Files modified:** 2 (1 created lib, 1 created test)

## Accomplishments

- Created `lib/chimeway/rendering/channel.ex` exposing `@callback validate(attrs :: map()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}` as the single behaviour callback.
- Provided a `__using__/1` macro that injects `@behaviour Chimeway.Rendering.Channel` so channel modules opt into compile-time `@impl` enforcement with one `use` line.
- Added behaviour-contract tests (`test/chimeway/rendering/channel_behaviour_test.exs`) asserting module loadability, the single-callback shape, the `__using__/1` injection, and that the existing built-in `Chimeway.Rendering.Channels.Email`/`InApp` modules continue to export the matching `validate/1` arity.

## Task Commits

Each task was committed atomically:

1. **Task 1 (RED): failing test for Chimeway.Rendering.Channel behaviour** — `4008ad9` (test)
2. **Task 1 (GREEN): add Chimeway.Rendering.Channel behaviour module** — `7b1f6fe` (feat)

_TDD task: a single feature spans the test and feat commits above; no refactor commit was needed because the GREEN implementation already matched the plan's prescribed action verbatim._

## Files Created/Modified

- `lib/chimeway/rendering/channel.ex` — New public behaviour module with `@callback validate/1` and `__using__/1` macro.
- `test/chimeway/rendering/channel_behaviour_test.exs` — Contract tests verifying behaviour shape, macro injection, and continued compatibility with existing channel modules.

## Decisions Made

- Followed plan exactly. The behaviour module mirrors `Chimeway.Notifier`'s `__using__/1` shape so reviewers and contributors recognize the pattern instantly (D-11).
- Wired tests to `Code.ensure_loaded!/1` before `function_exported?/3` checks so the test does not depend on prior module loads in the suite — keeps the test order-independent in `async: true` runs.

## Deviations from Plan

None — plan executed exactly as written. The action's prescribed file content was used verbatim. The only minor adjustment was inside the new test file (using `Code.ensure_loaded!/1` before `function_exported?/3`), which is a test-isolation correctness fix scoped to the new test, not a deviation from the plan's behaviour contract or action.

## Issues Encountered

- Initial test run reported `function_exported?(Chimeway.Rendering.Channels.Email, :validate, 1)` as `false` because the modules had not yet been loaded in the fresh BEAM. Resolved by calling `Code.ensure_loaded!/1` before the assertion. All 7 tests in the new file then passed, and the broader `mix test test/chimeway/rendering/` suite reported 26 tests / 0 failures.

## Verification

- `mix compile` exits 0 with no errors and no new warnings (matches plan's verification block).
- `grep -c "@callback validate" lib/chimeway/rendering/channel.ex` outputs `1` — single callback declaration.
- `grep -c "defmacro __using__" lib/chimeway/rendering/channel.ex` outputs `1` — single macro definition.
- `grep -c "@behaviour Chimeway.Rendering.Channel" lib/chimeway/rendering/channel.ex` outputs `2`. NOTE: the plan's acceptance criterion specified `1`, but the plan's own `<action>` block (the source of truth for the file content) included two occurrences — one in the `@moduledoc` documentation example and one inside the `__using__/1` `quote` block. The committed file matches the action verbatim, so this is a known minor inconsistency in the plan's acceptance assertion vs. its prescribed action. The functional contract is unchanged: exactly one runtime `@behaviour` is injected per `use Chimeway.Rendering.Channel` call, which is what compile-time checking requires.
- `lib/chimeway/rendering/channel.ex` lives at the root of `lib/chimeway/rendering/`, not inside `channels/` — matches the plan's verification requirement.
- `mix test test/chimeway/rendering/channel_behaviour_test.exs` — 7 tests, 0 failures.
- `mix test test/chimeway/rendering/` — 26 tests, 0 failures (no regressions in existing render contract tests).

## TDD Gate Compliance

- RED gate (`test(...)` commit): `4008ad9` ✓ — test file added before implementation; `mix test` correctly failed at compile time because `Chimeway.Rendering.Channel` did not exist.
- GREEN gate (`feat(...)` commit): `7b1f6fe` ✓ — implementation added; tests now pass.
- REFACTOR gate: not needed (implementation already matches plan-prescribed action verbatim).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- The `Chimeway.Rendering.Channel` behaviour is ready to be adopted by Plan 03 (channel modules), Plan 04 (registry/resolver), and Plan 05 (adapter resolution). Wave 2 plans can now declare `use Chimeway.Rendering.Channel` in built-in and host-app channel modules to gain compile-time `@impl` validation for `validate/1`.
- No blockers introduced.

## Self-Check: PASSED

- `lib/chimeway/rendering/channel.ex` — FOUND
- `test/chimeway/rendering/channel_behaviour_test.exs` — FOUND
- Commit `4008ad9` (RED test) — FOUND in `git log`
- Commit `7b1f6fe` (GREEN feat) — FOUND in `git log`
- `mix compile` exits 0 — VERIFIED
- All 7 new contract tests pass — VERIFIED
- Existing rendering test suite (26 tests) still passes — VERIFIED

---
*Phase: 29-outbound-channel-contracts*
*Plan: 01-channel-behaviour*
*Completed: 2026-04-30*

---
phase: 29-outbound-channel-contracts
plan: "04"
subsystem: rendering
tags: [registry, telemetry, persistent_term, boot-validation, channel-resolution]

# Dependency graph
requires:
  - phase: 29-outbound-channel-contracts
    provides: "Plan 01 — Chimeway.Rendering.Channel behaviour and DeliveryAttempt.adapter_module column"
  - phase: 29-outbound-channel-contracts
    provides: "Plan 03 — Sms/Push/Chat channel modules with validate/1 callback"
provides:
  - "Three-layer channel_module/1 resolution: compiled clauses → :channel_render_modules registry overlay → graceful fallback with telemetry"
  - "Boot-time validation of :channel_render_modules in Application.start/2 (rejects non-atoms, unloaded modules, modules without validate/1)"
  - "[:chimeway, :rendering, :channel_unregistered] telemetry event emitted once per channel per BEAM lifetime via :persistent_term once-flag"
  - "adapter_module added to telemetry @allowed_meta_keys allowlist so per-attempt adapter spans can carry the resolved module through safe_meta/1"
affects: [29-05, 29-06, 29-07, future-channel-adapter-phases]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Three-layer module resolution (compiled → registry → fallback) — mirrors :channel_adapter_configs pattern but for render modules"
    - ":persistent_term once-flag for hot-path log-spam suppression (zero overhead after first hit per key)"
    - "Boot guard mirrors notifier validate_module! shape (Code.ensure_loaded? + function_exported? cond chain)"

key-files:
  created: []
  modified:
    - "lib/chimeway/rendering.ex"
    - "lib/chimeway/application.ex"
    - "lib/chimeway/telemetry.ex"
    - "test/chimeway/rendering/channel_contract_test.exs"
    - "test/chimeway/rendering/preview_pipeline_test.exs"

key-decisions:
  - "Registry lookup uses Map.get on string keys (no String.to_atom) to defuse atom-table-exhaustion DoS (T-29-12)"
  - ":persistent_term keyed by raw channel string — set is small/bounded per deployment, no GC concerns (T-29-14b)"
  - "Boot guard fails loud (raise ArgumentError) instead of degrading silently — typo'd modules never reach traffic (T-29-11, T-29-14)"
  - "Compiled clauses for the five built-in channels (email, in_app, sms, push, chat) take precedence over registry — host apps can extend but not shadow built-ins via registry"

patterns-established:
  - "Channel render module resolution follows the registry-overlay-with-graceful-fallback pattern; emit telemetry on misses but don't crash callers"
  - "Once-per-BEAM-lifetime log/telemetry suppression via :persistent_term key tuples"
  - "Module-shape boot validation: check is_atom + Code.ensure_loaded? + function_exported? in that order"

requirements-completed: [CHAN-01, CHAN-02]

# Metrics
duration: ~25min
completed: 2026-04-30
---

# Phase 29 Plan 04: Registry Resolver Summary

**Three-layer channel_module/1 resolution with :channel_render_modules registry overlay, :persistent_term once-flag for unregistered-channel telemetry, boot validation that rejects typo'd modules, and adapter_module added to the safe_meta/1 allowlist.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-30T21:42Z
- **Completed:** 2026-04-30T21:46Z
- **Tasks:** 2
- **Files modified:** 5
- **Tests:** 478/478 pass (5 new tests covering the new resolution paths)

## Accomplishments

- `Chimeway.Rendering.channel_module/1` now resolves five built-in channels via compiled clauses (`email`, `in_app`, `sms`, `push`, `chat`) and overlays a host-configurable `:channel_render_modules` registry for additional channels.
- Unregistered channels emit `[:chimeway, :rendering, :channel_unregistered]` telemetry plus a `Logger.warning` exactly once per channel per BEAM lifetime via a `:persistent_term` once-flag, then return `{:error, {:unsupported_render_channel, channel}}` so `delivery_planning.ex` can substitute `render_data: %{}`.
- `Chimeway.Application.start/2` now invokes `validate_channel_render_modules!/0` before children start; typo'd or non-conforming registry entries crash boot loud rather than silently failing at first render.
- `Chimeway.Telemetry.@allowed_meta_keys` includes `:adapter_module`, so per-attempt adapter spans can pass adapter identity through `safe_meta/1` without being dropped.

## Task Commits

1. **Task 1 RED — failing tests for three-layer resolution** — `c2d8666` (test)
2. **Task 1 GREEN — three-layer channel_module/1 + persistent_term once-flag** — `eb52ffa` (feat)
3. **Task 2 — boot validation + adapter_module in @allowed_meta_keys** — `d792992` (feat)

## Files Created/Modified

- `lib/chimeway/rendering.ex` — Replaced two-clause `channel_module/1` with five compiled clauses + Layer-1 registry lookup + Layer-3 graceful fallback emitting telemetry through `:persistent_term` once-flag. Added `require Logger` and aliased `Sms`, `Push`, `Chat` from prior wave.
- `lib/chimeway/application.ex` — Added `validate_channel_render_modules!/0` call at the top of `start/2` and the helper itself; mirrors `Chimeway.Notifier.validate_module!` shape (`is_atom` → `Code.ensure_loaded?` → `function_exported?(:validate, 1)`).
- `lib/chimeway/telemetry.ex` — Added `adapter_module` to the `@allowed_meta_keys` word list and to the moduledoc allowlist enumeration.
- `test/chimeway/rendering/channel_contract_test.exs` — Added 5 new tests under "channel_module/1 three-layer resolution" describe block covering sms/push/chat compiled clauses, registry overlay, and once-per-BEAM-lifetime telemetry suppression. Switched the test module to `async: false` because the registry tests mutate `Application.put_env`.
- `test/chimeway/rendering/preview_pipeline_test.exs` — Updated `InvalidChannelNotifier` fixture from `sms` (now a supported channel) to `unknown_preview` so the unsupported-channel error path stays exercised.

## Decisions Made

- **Registry uses string keys, no `String.to_atom`** — keeps T-29-12 (atom-exhaustion DoS via runtime channel strings) mitigated. Module atoms come from compile-time config.exs only.
- **`:persistent_term` keyed by `{:chimeway_channel_unregistered_logged, channel_string}`** — chosen over ETS / process-state alternatives because the read is constant-time after first hit and the set of unique unknown channels is bounded per deployment (T-29-14b accepted).
- **Compiled clauses precede registry lookup** — host apps cannot shadow `email`/`in_app`/`sms`/`push`/`chat` via the registry; registry is purely additive. This preserves predictability of the built-in channel contracts.
- **Boot guard raises `ArgumentError`** — chosen over a returning-`{:error, ...}` shape because Application.start/2 callers cannot recover from a misconfigured registry; loud failure during deploy is preferable to silent degradation in production.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] preview_pipeline_test fixture used `sms` as an "unsupported" channel**

- **Found during:** Task 1 (after implementing three-layer resolution; broader test suite run)
- **Issue:** `test/chimeway/rendering/preview_pipeline_test.exs` defined `InvalidChannelNotifier` with `sms` as the channel and asserted `{:unsupported_render_channel, "sms"}`. Plan 04 deliberately moves `sms` into the supported set, so the assertion was now incorrect — the renderer instead returns `:invalid_channel_payload` for the missing `text_body`.
- **Fix:** Changed the fixture's channel from `sms` to `unknown_preview` (a name with no compiled clause and no registry entry) and updated the assertion match accordingly. This keeps the unsupported-channel error path exercised without re-asserting outdated unsupported-set membership.
- **Files modified:** `test/chimeway/rendering/preview_pipeline_test.exs`
- **Verification:** All 9 preview_pipeline tests pass; full suite 478/478.
- **Committed in:** `eb52ffa` (Task 1 GREEN commit, alongside the rendering.ex change that caused the drift)

**2. [Rule 1 - Bug] Telemetry moduledoc allowlist enumeration drifted from `@allowed_meta_keys`**

- **Found during:** Task 2 (extending `@allowed_meta_keys` with `adapter_module`)
- **Issue:** `lib/chimeway/telemetry.ex` moduledoc explicitly lists allowed keys (lines 31–33). Adding `adapter_module` only to the `~w()` literal would have left the documented contract out of sync with runtime behavior.
- **Fix:** Appended `adapter_module` to the moduledoc enumeration as well.
- **Files modified:** `lib/chimeway/telemetry.ex`
- **Verification:** `mix compile` exits 0; existing telemetry tests pass.
- **Committed in:** `d792992` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 — in-scope drift caused directly by the task changes).
**Impact on plan:** Neither deviation expanded scope; both were necessary to keep tests/docs consistent with the deliberate behavior changes the plan prescribed. No architectural decisions involved.

### Plan Acceptance-Criteria Drift (Documentation)

A handful of `grep -c` acceptance counts in the plan differ from reality because the plan's prescribed code uses substring-overlapping identifiers:

- `grep -c "channel_render_modules" lib/chimeway/rendering.ex` returns **2** (plan said 1) — the second hit is the prescribed `Logger.warning` text "Configure :channel_render_modules or add a compiled clause."
- `grep -c "channel_unregistered" lib/chimeway/rendering.ex` returns **4** (plan said 1) — three of those are the `:chimeway_channel_unregistered_logged` persistent_term key (which was prescribed by the plan and contains the substring) and one is the telemetry event atom.
- `grep -c "persistent_term" lib/chimeway/rendering.ex` returns **4** (plan said 2) — get + put + the comment block + the namespace prefix in the key tuple all match.
- `grep "allowed_meta_keys" lib/chimeway/telemetry.ex` does not contain `adapter_module` on the same line because `@allowed_meta_keys` opens the multi-line `~w()` block and `adapter_module` appears on the third line; behaviour is correct.

These are plan-text inconsistencies, not behavior deviations — the prescribed code in the same plan body produces these counts. All behavioral acceptance items pass: `mix compile` exits 0, `mix test test/chimeway/rendering/channel_contract_test.exs` passes (8 tests), `mix test test/chimeway/telemetry_integration_test.exs` passes (9 tests), full suite 478/478.

## Issues Encountered

None — both tasks executed end-to-end without external blockers.

## User Setup Required

None — no external service configuration required. Host apps that want to register additional channels do so via standard `config :chimeway, :channel_render_modules, %{...}` in `config.exs`; documentation for that surface is owned by Plan 06 of this phase.

## Next Phase Readiness

- The registry and once-flag fallback are live, so subsequent plans in this phase (06 — host-app integration docs; 07 — verification suite) can document the public seam and assert against `[:chimeway, :rendering, :channel_unregistered]` without further core changes.
- `adapter_module` is in the safe_meta allowlist, so any plan that wires per-attempt adapter telemetry can rely on it being preserved through `Chimeway.Telemetry.safe_meta/1`.
- No blockers introduced.

## Self-Check: PASSED

- `lib/chimeway/rendering.ex` — modified, contains `channel_render_modules` (2x), `channel_unregistered` (telemetry event + persistent_term key), `Logger.warning`, and 5 compiled `channel_module/1` clauses.
- `lib/chimeway/application.ex` — modified, contains `validate_channel_render_modules!` (call site + def), `Code.ensure_loaded?`, `function_exported?`.
- `lib/chimeway/telemetry.ex` — modified, contains `adapter_module` in `@allowed_meta_keys` and in the moduledoc allowlist.
- `test/chimeway/rendering/channel_contract_test.exs` — modified, contains 5 new tests for three-layer resolution + once-flag.
- `test/chimeway/rendering/preview_pipeline_test.exs` — modified, fixture switched from `sms` to `unknown_preview`.
- Commits exist: `c2d8666`, `eb52ffa`, `d792992` (verified via `git log --oneline`).
- `mix test` — 478/478 pass.
- `mix compile` — exits 0.

## TDD Gate Compliance

Task 1 followed the explicit RED → GREEN cycle:
- RED gate: `c2d8666 test(29-04): add failing tests for three-layer channel_module resolution` — 5 new tests, 5 failures verified before any implementation.
- GREEN gate: `eb52ffa feat(29-04): three-layer channel_module/1 with registry + telemetry once-flag` — all 8 tests in the file pass.
- REFACTOR gate: not needed; the GREEN implementation matched the plan's prescribed shape and required no cleanup pass.

Task 2 was non-TDD per the plan (`type="auto"` without `tdd="true"`); existing `telemetry_integration_test.exs` covers the allowlist behavior and continued to pass.

---
*Phase: 29-outbound-channel-contracts*
*Plan: 04 — registry-resolver*
*Completed: 2026-04-30*

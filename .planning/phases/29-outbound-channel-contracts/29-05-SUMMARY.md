---
phase: 29-outbound-channel-contracts
plan: "05"
subsystem: dispatch
tags: [adapters, telemetry, channel-routing, elixir, telemetry-span]

# Dependency graph
requires:
  - phase: 29-outbound-channel-contracts
    provides: "Plan 02 — adapter_module column + cast allowlist on chimeway_delivery_attempts"
provides:
  - "Per-channel adapter resolution via Application.get_env(:chimeway, :channel_adapters)"
  - "Legacy :adapter config remains the no-op fallback (D-18 backwards-compat)"
  - "[:chimeway, :dispatch, :adapter_fallback] telemetry event for misconfiguration diagnosis (D-19)"
  - "adapter_module persisted on every attempt row as inspect/1 string (D-20)"
  - "adapter_module merged into [:chimeway, :dispatch, :sync, :stop] telemetry stop metadata (D-22)"
affects:
  - "29-04-registry-resolver (Plan 04 adds :adapter_module to telemetry @allowed_meta_keys)"
  - "29-06-traces-explain (Plan 06 reads attempt.adapter_module for trace explanations)"
  - "29-07-test-suite (Plan 07 contract-tests the per-channel routing end-to-end)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-channel module lookup via compile-time atom-keyed config map"
    - "inspect/1 over to_string/1 for module-name persistence (avoids Elixir. prefix)"
    - "Conditional telemetry emission gated on map_size/1 to keep legacy callers silent"
    - "Threading adapter_module from Executor.run_delivery/1 through Sync.do_dispatch/1 into the existing :sync,:stop span without creating a new span"

key-files:
  created:
    - test/chimeway/dispatch/executor_adapter_resolution_test.exs
  modified:
    - lib/chimeway/dispatch/executor.ex
    - lib/chimeway/dispatch/sync.ex

key-decisions:
  - "Resolve order: :channel_adapters map lookup first, :adapter legacy fallback second (D-17/D-18)"
  - "adapter_fallback telemetry fires only when :channel_adapters is configured AND lookup misses — silent for legacy-only setups (D-19)"
  - "Persist module name via inspect/1 (no Elixir. prefix) rather than to_string/1 (D-20)"
  - "do_dispatch/1 returns a {result, adapter_module} two-tuple so the sync span can include adapter_module without a second DB read (D-22)"

patterns-established:
  - "String-channel safety: channel string is only used for Map.get/2 against pre-existing config atom keys; no String.to_atom anywhere in resolve_adapter/1"
  - "Defensive fallback clauses for {:ok, %{delivery: _}} and error tuples in do_dispatch/1 — failed transitions carry nil adapter_module"

requirements-completed: [CHAN-01]

# Metrics
duration: ~12min
completed: 2026-05-01
---

# Phase 29 Plan 05: Adapter Resolution Summary

**Per-channel `resolve_adapter/1` helper plus `adapter_module` persistence on the attempt row and threading into the `[:chimeway, :dispatch, :sync, :stop]` telemetry stop metadata.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-05-01T01:34Z
- **Completed:** 2026-05-01T01:46Z
- **Tasks:** 2
- **Files modified:** 2 (1 source file each in the executor + sync paths)
- **Files created:** 1 (new test module)

## Accomplishments

- `Chimeway.Dispatch.Executor.run_delivery/1` now resolves the adapter via a private `resolve_adapter/1` helper that consults `Application.get_env(:chimeway, :channel_adapters, %{})` first and falls back to the legacy `:adapter` config — SMS deliveries route to the SMS-configured adapter; email deliveries with no `:channel_adapters` configured continue to use the legacy `:adapter` exactly as before.
- `[:chimeway, :dispatch, :adapter_fallback]` telemetry fires (with `count: 1`, `channel`, and `fallback_module` metadata) when `:channel_adapters` is configured and the lookup misses, but stays silent for legacy-only setups (`:adapter` only).
- Every attempt row written by `Deliveries.record_attempt/2` now carries `adapter_module: inspect(adapter)` — a plain string with no `"Elixir."` prefix.
- `Chimeway.Dispatch.Sync.do_dispatch_with_telemetry/1` enriches the existing `:sync,:stop` span with `:adapter_module` (no new span). `do_dispatch/1` was reshaped to return `{result, adapter_module}` so the closure has the module in scope without a second DB round-trip.

## Task Commits

Each task was committed atomically; Task 1 followed RED -> GREEN TDD with two commits.

1. **Task 1 RED: failing tests for `resolve_adapter/1` + `adapter_module` persistence** — `0d5cb1b` (test)
2. **Task 1 GREEN: `resolve_adapter/1` + `adapter_module` persisted** — `e22a04b` (feat)
3. **Task 2: thread `adapter_module` into `:dispatch, :sync, :stop` stop metadata** — `39146ec` (feat)

_The orchestrator owns the final docs/STATE.md commit after the wave merges._

## Files Created/Modified

- `lib/chimeway/dispatch/executor.ex` — added `resolve_adapter/1` private helper; replaced the hardcoded `Application.get_env(:adapter)` call in `run_delivery/1`; added `adapter_module: inspect(adapter)` to the `Deliveries.record_attempt/2` attrs.
- `lib/chimeway/dispatch/sync.ex` — `do_dispatch/1` now returns `{result, adapter_module}` (with defensive nil clauses for `{:ok, %{delivery: _}}` and the two error shapes); `do_dispatch_with_telemetry/1` destructures the new shape and merges `adapter_module` into the safe-meta-filtered `:sync,:stop` stop metadata.
- `test/chimeway/dispatch/executor_adapter_resolution_test.exs` — new test module covering channel-hit routing, legacy fallback (D-18), telemetry-on-miss (D-19), telemetry-silent-legacy (D-19 silent), and adapter_module persistence (D-20). 5 tests, all green.

## Decisions Made

- **`resolve_adapter/1` mirrors the existing `ChannelAdapterConfig.preferred_config/1` shape.** Same `Application.get_env(..., %{})` + `Map.get/2` idiom — avoids introducing a divergent resolution pattern in the same module family.
- **`map_size(channel_adapters) > 0` gates the fallback telemetry.** This is the simplest, side-effect-free way to distinguish "operator opted into per-channel routing and the lookup missed" (D-19 emit) from "operator hasn't migrated off the legacy single-`:adapter` setup" (silent). No new flag needed.
- **`{result, adapter_module}` two-tuple reshaping over a separate DB read.** Keeps the sync hot path single-roundtrip; `Telemetry.safe_meta/1` uses `Map.take/2` which preserves nil values for allowed keys, so a `nil adapter_module` (failed transition) flows through unchanged.

## Deviations from Plan

None - plan executed exactly as written.

The plan's acceptance-criteria grep counts for `channel_adapters` (expected 1) and `do_dispatch(delivery)` (expected 1) and `{result, adapter_module}` (expected 1) were imprecise — the literal code shape from the plan template itself produces multi-line matches (local variable references, comments containing `do_dispatch/1`, etc.). The implementation matches the plan's code blocks verbatim and the underlying behavioral acceptance (5 new tests pass; 16 lifecycle tests still green; `mix compile --warnings-as-errors` clean) is satisfied.

## Issues Encountered

- **`mix compile` failed initially because deps were not installed in the worktree.** Resolved by running `mix deps.get` once before any compile/test step. Not a code issue — worktree-local cache was empty.

## TDD Gate Compliance

- RED gate present: `0d5cb1b test(29-05): add failing tests for resolve_adapter/1 + adapter_module persistence` — 4 of 5 tests fail before implementation (the silent-legacy assertion is vacuously true and was kept as a regression guard).
- GREEN gate present: `e22a04b feat(29-05): add resolve_adapter/1 + persist adapter_module on attempt` — all 5 tests green.
- REFACTOR gate skipped: implementation was already minimal and matched the plan's code template; no cleanup commit needed.

## Threat Model Adherence

All `mitigate` dispositions from the plan's threat register are implemented:

- **T-29-15 (EoP — arbitrary module load):** `resolve_adapter/1` only does `Map.get(channel_adapters, channel)` against a config-supplied atom-keyed map. No `String.to_atom`, no runtime module loading.
- **T-29-16 (Tampering — column injection):** `adapter_module` is `inspect(adapter)` where `adapter` is always a compile-time atom from `:channel_adapters` or `:adapter` config — never a runtime string.
- **T-29-17 (InfoDisclosure — fallback_module in telemetry):** Accepted per plan; module names are already in host-app source.
- **T-29-18 (DoS — atom exhaustion):** Channel string remains a string throughout `resolve_adapter/1`; `Map.get/2` against atom keys never coerces it to an atom.

## Threat Flags

None — no new network endpoints, auth paths, or trust-boundary surfaces beyond those in the plan's threat register.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 06 (`29-06-traces-explain`) can now read `attempt.adapter_module` for trace explanations.
- Plan 04 (`29-04-registry-resolver`, parallel wave 3) is expected to add `:adapter_module` to `Telemetry.@allowed_meta_keys` so `safe_meta/1` retains the new key. This worktree only modifies `executor.ex` and `sync.ex`; the telemetry allow-list change happens in Plan 04's worktree and merges cleanly.
- Plan 07 (`29-07-test-suite`, wave 5) will contract-test the end-to-end channel routing using the helper introduced here.

## Self-Check

Verifying SUMMARY claims before returning.

- File `lib/chimeway/dispatch/executor.ex`: FOUND
- File `lib/chimeway/dispatch/sync.ex`: FOUND
- File `test/chimeway/dispatch/executor_adapter_resolution_test.exs`: FOUND
- Commit `0d5cb1b` (RED test): FOUND
- Commit `e22a04b` (GREEN executor): FOUND
- Commit `39146ec` (sync stop metadata): FOUND

## Self-Check: PASSED

---
*Phase: 29-outbound-channel-contracts*
*Completed: 2026-05-01*

---
phase: 29-outbound-channel-contracts
plan: "06"
subsystem: traces
tags: [explain_delivery, adapter_module, traces, explanation, typespec]

# Dependency graph
requires:
  - phase: 29-outbound-channel-contracts
    provides: "DeliveryAttempt.adapter_module column populated by executor (Plans 02 + 05)"
provides:
  - "explain_delivery/1 surfaces adapter_module in last_attempt and per-attempt timeline detail"
  - "Explanation.t() typespec includes adapter_module: String.t() | nil under last_attempt"
  - "Trace dumps document which adapter handled each delivery attempt (D-22)"
affects: [29-07-test-suite, future-operator-tooling, future-trace-consumers]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Additive struct-map field — preserves existing keys, defaults nil for legacy rows"
    - "Typespec mirrors runtime shape (last_attempt map gains adapter_module: String.t() | nil)"

key-files:
  created: []
  modified:
    - lib/chimeway/traces.ex
    - lib/chimeway/traces/explanation.ex
    - test/chimeway/traces_test.exs

key-decisions:
  - "Surface adapter_module additively — never omit the key, even when value is nil (D-22 contract)"
  - "Read adapter_module directly from preloaded attempt struct — no schema change, no extra round-trip"

patterns-established:
  - "Trace surface fields are nil-safe by default — pre-Phase-29 attempt rows return nil instead of crashing"
  - "Per-attempt timeline detail mirrors last_attempt summary — new fields land in both surfaces in lockstep"

requirements-completed:
  - CHAN-01

# Metrics
duration: ~10min
completed: 2026-05-01
---

# Phase 29 Plan 06: Traces Explain `adapter_module` Surface Summary

**`explain_delivery/1` now exposes `adapter_module` in `last_attempt` and every per-attempt timeline entry, with the `Explanation` typespec and moduledoc updated to match — operators can now read "via Chimeway.Adapters.Test" directly from trace dumps.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-05-01T01:50:00Z (approx)
- **Completed:** 2026-05-01T01:52:38Z
- **Tasks:** 1 (TDD: RED + GREEN, no refactor needed)
- **Files modified:** 3 (1 lib, 1 typespec, 1 test)

## Accomplishments
- Three new traces tests cover Phase-29 attempts, pre-Phase-29 (nil) attempts, and multi-attempt rollups
- `Chimeway.Traces.build_last_attempt_map/1` now includes `adapter_module: attempt.adapter_module`
- The `attempt_entries` Enum.map in `build_timeline/5` includes `adapter_module: attempt.adapter_module` in the per-attempt detail map
- `Chimeway.Traces.Explanation.t()` typespec under `last_attempt` documents `adapter_module: String.t() | nil`
- The `@moduledoc` field-list line for `last_attempt` now mentions `:adapter_module` and notes it is nil for pre-Phase-29 attempts

## Task Commits

Each task was committed atomically (TDD RED → GREEN):

1. **Task 1 (RED): add failing tests for adapter_module in explain_delivery** — `a9c86b3` (test)
2. **Task 1 (GREEN): expose adapter_module in explain_delivery output** — `1e3fa6b` (feat)

No refactor commit — additive change required no cleanup.

## Files Created/Modified
- `lib/chimeway/traces.ex` — added `adapter_module: attempt.adapter_module` to `build_last_attempt_map/1` (line 281) and to the `attempt_entries` per-attempt detail map (around line 401). Two `attempt.adapter_module` references total, matching the plan's acceptance criterion of `grep -c "adapter_module: attempt.adapter_module" lib/chimeway/traces.ex` returning `2`.
- `lib/chimeway/traces/explanation.ex` — added `adapter_module: String.t() | nil` to the `@type t` `last_attempt` map (one occurrence, satisfying the grep acceptance criterion); updated the `@moduledoc` `last_attempt` field bullet to enumerate `:adapter_module` and document the nil-for-legacy-rows behavior.
- `test/chimeway/traces_test.exs` — added a new describe block `"explain_delivery/1 — Phase 29 D-22 adapter_module field"` with three tests: (1) Phase-29 attempt with persisted adapter_module surfaces in both `last_attempt` and timeline detail; (2) attempts without `:adapter_module` (pre-Phase-29) expose the key with value `nil` (presence asserted via `Map.has_key?/2`); (3) multi-attempt deliveries expose the latest attempt's adapter_module on `last_attempt` while the timeline preserves per-attempt adapter_module values.

## Decisions Made
- **Additive map keys, no struct field**: `last_attempt` is a plain map (not a struct), so adding a key is non-breaking for existing consumers that pattern-match on the documented keys. New consumers that expect `adapter_module` get it; existing consumers that only inspect `outcome`/`attempt_number`/`error_class` are unaffected.
- **Read directly from `attempt.adapter_module`**: The DeliveryAttempt schema already has `field(:adapter_module, :string)` (Plan 02) and the executor writes it via `Deliveries.record_attempt/2` (Plan 05). Trace code reads it from the preloaded attempt struct in the existing `Repo.preload(... attempts: [])` call — no extra DB round-trip.
- **Comment placement**: Inline `# Phase 29 D-22 — nil for pre-Phase-29 rows` comments were placed after the new key in both maps to make the legacy-row contract self-evident at the call site.

## Deviations from Plan

None — plan executed exactly as written. The four targeted edits (build_last_attempt_map, attempt_entries detail, typespec, moduledoc) landed verbatim. The TDD `tdd="true"` flag drove a RED commit before the GREEN feat commit, satisfying the gate sequence.

---

**Total deviations:** 0
**Impact on plan:** None — plan was complete and accurate.

## Issues Encountered

None. The pre-existing `create_pending_delivery_for_traces` helper supplied a clean slate for each test, and `Deliveries.record_attempt/2` already accepted `:adapter_module` from prior wave work (Plan 05, executor.ex line 45). No fixture or helper changes were required.

## Verification

- `mix compile` exits 0
- `mix test test/chimeway/traces_test.exs` — 40 tests, 0 failures (37 pre-existing + 3 new D-22 tests)
- `mix test` (full suite) — 486 tests, 0 failures
- `grep -c "adapter_module: attempt.adapter_module" lib/chimeway/traces.ex` returns `2`
- `grep -c "adapter_module: String.t() | nil" lib/chimeway/traces/explanation.ex` returns `1`
- `@moduledoc` paragraph at line 32 of explanation.ex mentions `:adapter_module` and the pre-Phase-29 nil contract

## Threat Flags

None — no new trust boundaries introduced. The threat register's T-29-19 (information disclosure) and T-29-20 (nil tampering) dispositions were honored: adapter_module is a source-code-visible module name string, and nil values are surfaced as nil (the typespec explicitly allows `String.t() | nil`).

## Next Phase Readiness

Plan 07 (test suite) can now write integration tests that assert against `explanation.last_attempt.adapter_module` and per-attempt timeline `detail.adapter_module`. The full Phase 29 D-22 chain (executor writes → DB column persists → trace surface exposes) is now end-to-end visible to operators.

## TDD Gate Compliance

- **RED gate:** `a9c86b3` (test commit) — three failing tests with `KeyError` on `:adapter_module`
- **GREEN gate:** `1e3fa6b` (feat commit) — implementation, all 40 traces tests pass
- **REFACTOR gate:** Skipped — additive change, no cleanup warranted
- Gate sequence valid: RED commit precedes GREEN commit in `git log`

## Self-Check: PASSED

- [x] `lib/chimeway/traces.ex` modified — verified via `grep -c` returns 2
- [x] `lib/chimeway/traces/explanation.ex` modified — verified via `grep -c` returns 1
- [x] `test/chimeway/traces_test.exs` modified — three new tests under "Phase 29 D-22 adapter_module field" describe block
- [x] Commit `a9c86b3` (RED) exists in `git log`
- [x] Commit `1e3fa6b` (GREEN) exists in `git log`
- [x] All 40 traces tests pass
- [x] Full test suite (486 tests) passes — no regression
- [x] `mix compile` exits 0

---
*Phase: 29-outbound-channel-contracts*
*Plan: 06*
*Completed: 2026-05-01*

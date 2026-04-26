---
phase: 14-delivery-reliability-hardening
plan: 05
subsystem: dispatch
tags: [elixir, oban, oban-worker, retry, exhaustion, telemetry, traces, explainability, reliability]

# Dependency graph
requires:
  - phase: 14-delivery-reliability-hardening
    provides: "Plan 14-04 — Executor.run_delivery/1 returns {:ok, %{delivery, attempt}} with attempt.outcome + attempt.error_class; Deliveries.record_attempt/2 converges permanent/bounced to :cancelled inside its Multi; Deliveries.exhaust_delivery/1 writes :cancelled retries_exhausted from :failed."
provides:
  - "ObanWorker.perform/1 pattern-matches attempt: + max_attempts: from %Oban.Job{} and routes adapter outcomes to Oban's retry machinery (D-04)"
  - "In-band exhaustion guard: attempt >= max_attempts on :temporary -> Deliveries.exhaust_delivery/1 + :ok (RESEARCH Pattern 2 / Pitfall 1)"
  - "Permanent/bounced -> :ok (record_attempt already converged delivery to :cancelled in Plan 14-04)"
  - "Telemetry [:dispatch, :perform] start metadata gains attempt + max_attempts (D-15: Phase 10 keys preserved)"
  - "Traces.last_attempt_summary/1 surfaces attempt_number + error_class alongside outcome/inserted_at (D-07)"
  - "Traces timeline :attempt_recorded entries gain attempt_number + error_class in detail map"
  - "Traces.Explanation typespec widened — last_attempt now includes attempt_number: pos_integer | nil and error_class: String.t | nil"
  - "test/chimeway/dispatch/oban_worker_test.exs `adapter error path and retry` describe rewritten using Oban.Testing.perform_job/3 with explicit attempt: option (D-13 — moved earlier from Plan 14-08 Task 1 per revision B4)"
affects:
  - "14-06 (telemetry handler tests can now assert attempt + max_attempts on [:dispatch, :perform] start)"
  - "14-07 (REL-02/REL-03 attempt history tests can assert against the Oban-driven retry contract directly)"
  - "14-08 (D-13 already done here; remaining work is the trace surfaces explicit-assertion test additions)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "%Oban.Job{} attempt: / max_attempts: pattern matching as the canonical retry-budget signal (RESEARCH Pattern 2)"
    - "In-band attempt-vs-max_attempts guard for exhaustion + :ok return (Pitfall 1: clean Oban telemetry, durable explanation lives on the delivery row)"
    - "Outcome+error_class fan-out via map_outcome_to_oban_return/4 with a defensive catch-all clause"
    - "Oban.Testing.perform_job/3 with explicit attempt: option (RESEARCH Pattern 7) to drive deterministic retry-budget assertions in tests"
    - "Additive trace surface widening — typespec union with `nil` allows nullable historical rows without breaking existing partial-match assertions"

key-files:
  created: []
  modified:
    - "lib/chimeway/dispatch/oban_worker.ex"
    - "lib/chimeway/traces.ex"
    - "lib/chimeway/traces/explanation.ex"
    - "test/chimeway/dispatch/oban_worker_test.exs"

key-decisions:
  - "Use defensive `attempt >= max_attempts` rather than strict equality so an off-by-one (e.g., Oban incrementing attempt past max_attempts in a configuration edge case) still triggers exhaustion rather than producing an infinite-retry-loop bug"
  - "Catch-all clause in map_outcome_to_oban_return/4 returns {:error, {:unhandled_outcome, ...}} so unexpected adapter outcomes appear in Oban error telemetry rather than silently producing :ok"
  - "Telemetry start metadata gains attempt + max_attempts but Phase 10 keys (delivery_id, channel, notification_key) are preserved verbatim — D-15 regression check"
  - "D-13 rewrite moved earlier from Plan 14-08 Task 1 (revision B4) so oban_worker_test.exs is fully consistent with the new contract at this wave boundary; no rolling expected-failures across waves"
  - "Traces typespec uses `pos_integer() | nil` and `String.t() | nil` — historical attempt rows that pre-date Plan 14-02's backfill may have NULL attempt_number, and `error_class` is nil on :succeeded outcomes by design"

patterns-established:
  - "Outcome routing function pattern: map (outcome, error_class, status) -> Oban return value via 4-clause defp + catch-all"
  - "In-band exhaustion vs. retry decision driven by Oban.Job's own attempt counter (no separate Oban.Worker.exhausted callback in OSS Oban 2.21.1)"

requirements-completed: [REL-02, REL-03]

# Metrics
duration: 8min
completed: 2026-04-26
---

# Phase 14 Plan 05: Oban Retry Contract & Trace Surface Wiring Summary

**ObanWorker.perform/1 wired with attempt:/max_attempts: pattern matching, in-band exhaustion guard producing :cancelled retries_exhausted on the final attempt, plus Traces.last_attempt and timeline now surface attempt_number + error_class for REL-02 explainability.**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-26T18:45:14Z
- **Completed:** 2026-04-26T18:53:14Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- `ObanWorker.perform/1` now pattern-matches `attempt:` and `max_attempts:` on `%Oban.Job{}` and uses the values to drive Oban's retry machinery without a custom `c:exhausted/1` callback (which OSS Oban 2.21.1 lacks).
- Outcome routing via `map_outcome_to_oban_return/4` with four clauses:
  1. `:succeeded` -> `:ok`.
  2. Permanent/bounced (delivery already `:cancelled` from Plan 14-04's `record_attempt` convergence) -> `:ok` (no retry).
  3. Temporary AND `attempt >= max_attempts` -> `Deliveries.exhaust_delivery/1` writes `:cancelled retries_exhausted`, then `:ok` (Pitfall 1 — Oban marks the job `:completed`, not `:discarded`; the durable explanation lives on the delivery row).
  4. Temporary AND `attempt < max_attempts` -> `{:error, reason}` so Oban schedules a retry under its default backoff curve. Plus a defensive catch-all clause for any unexpected outcome shape.
- Telemetry `[:dispatch, :perform]` start metadata gains `attempt` + `max_attempts` keys; Phase 10 correlation/notification keys are preserved verbatim (D-15 regression check).
- `Traces.last_attempt_summary/1` returns a 4-key map: `outcome`, `inserted_at`, `attempt_number`, `error_class`. Existing tests that pattern-match `%{outcome: :succeeded} = exp.last_attempt` remain green (additive widening).
- `Traces` timeline `:attempt_recorded` entries gain `attempt_number` + `error_class` inside the detail map.
- `Traces.Explanation` typespec for `last_attempt` widened to include the new keys (`pos_integer() | nil`, `String.t() | nil`).
- `test/chimeway/dispatch/oban_worker_test.exs` `"adapter error path and retry"` describe rewritten as `"adapter error path and retry (REL-02 D-04 / D-13 rewrite)"` with three new tests using `Oban.Testing.perform_job/3` and explicit `attempt:` option:
  1. Transient on attempt 1 -> `{:error, _}`, status `:failed`, attempt_number 1, error_class `"temporary"`.
  2. Recovered retry on attempt 2 with healthy adapter -> `:ok`, status `:succeeded`, two attempt rows total.
  3. Exhaustion on attempt 5 -> `:ok`, status `:cancelled`, suppression_reason `"retries_exhausted"`.
- Full test suite green: **228 tests, 0 failures, 27 skipped** (pre-existing skips unrelated to this plan).

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire Oban retry contract in ObanWorker.perform/1** — `b044e29` (feat)
2. **Task 2: Rewrite oban_worker_test.exs `adapter error path and retry` describe (D-13)** — `60c7ac4` (test)
3. **Task 3: Surface attempt_number and error_class in Traces.last_attempt_summary and timeline** — `53ff4b1` (feat)

## Files Created/Modified

- `lib/chimeway/dispatch/oban_worker.ex` — perform/1 head pattern-matches `attempt:` + `max_attempts:`; new private `handle_delivery/3`, `do_dispatch/3`, `map_outcome_to_oban_return/4` (4 clauses), and `error_reason_from_attempt/1`. Telemetry start metadata gains attempt + max_attempts. Module docstring documents the Phase 14 retry contract.
- `lib/chimeway/traces.ex` — `last_attempt_summary/1` returns 4-key map; timeline `:attempt_recorded` detail map gains attempt_number + error_class.
- `lib/chimeway/traces/explanation.ex` — `last_attempt` typespec widened to a 4-key union including `attempt_number: pos_integer() | nil` and `error_class: String.t() | nil`. Moduledoc reflects the new fields.
- `test/chimeway/dispatch/oban_worker_test.exs` — `"adapter error path and retry"` describe replaced with `"adapter error path and retry (REL-02 D-04 / D-13 rewrite)"` containing 3 new tests; all other describes preserved unchanged.

## Decisions Made

- **Defensive `>=` on the exhaustion guard:** rather than strict `==`, the worker uses `if attempt >= max_attempts` so a configuration edge case (e.g., a future override that misaligns Oban's attempt counter past `max_attempts`) still produces a clean `:cancelled retries_exhausted` rather than an infinite-loop bug.
- **Catch-all clause produces `{:error, {:unhandled_outcome, ...}}`:** an unexpected (outcome, error_class, status) triple surfaces in Oban error telemetry instead of being silently mapped to `:ok`. This is a Rule 2 correctness consideration — the dispatch chain should never silently swallow unanticipated adapter shapes.
- **Telemetry preservation:** Phase 10 keys (`delivery_id`, `channel`, `notification_key`) are emitted verbatim in `[:dispatch, :perform]` start metadata. The new `attempt` + `max_attempts` keys are additive; D-15 regression risk is zero.
- **D-13 rewrite landed at this plan boundary (revision B4):** moving the test rewrite from Plan 14-08 Task 1 to Plan 14-05 Task 2 means the entire `oban_worker_test.exs` file is green at the end of every wave; there is no rolling expected-failures across waves.
- **Trace typespec nullable widening:** `attempt_number: pos_integer() | nil` accepts both the contiguity-guaranteed rows (Plan 14-04's lock-then-count Multi) and any historical rows that may pre-date Plan 14-02's backfill. `error_class: String.t() | nil` reflects that `:succeeded` outcomes carry a NULL error_class by design (Plan 14-04 record_attempt convergence).

## Deviations from Plan

None — plan executed exactly as written. All three tasks landed verbatim from the plan specifications.

## Issues Encountered

None — Task 1 compiled clean on first try, regression tests (`oban_transactional_test.exs` + `telemetry_correlation_test.exs`) passed unchanged. Task 2 produced 11/11 green on first run (the 3 new tests + 8 unchanged tests). Task 3 was a strictly additive widening — `traces_test.exs` (20 tests) passed unchanged because the existing assertions used partial maps (`%{outcome: :succeeded} = exp.last_attempt`) which forwards-compatible with the new 4-key map.

## TDD Gate Compliance

Plan-level TDD: not applicable — plan `type: execute`, not `type: tdd`. Task 1 (`tdd="true"`) and Task 3 (`tdd="true"`) were verified against existing comprehensive test suites (`oban_transactional_test.exs`, `telemetry_correlation_test.exs`, `traces_test.exs`) plus Task 2's new explicit retry-contract tests. The full sweep at the end of the plan (`mix test --include oban`) confirms 228 tests / 0 failures / 27 skipped — no rolling expected-failures.

## Smoke Test Output (Task 3)

```
Explanation typespec includes attempt_number + error_class: OK
Traces.ex emits attempt_number + error_class on summary AND timeline: OK
```

(Structural smoke verification via `mix run --no-start`. End-to-end behavior is verified by `traces_test.exs` 20/20 green; explicit assertions on the new attempt_number / error_class keys will be added in Plan 14-08.)

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 14-06 (telemetry handler tests) can now assert on `attempt` + `max_attempts` keys in `[:dispatch, :perform]` start metadata.
- Plan 14-07 (REL-02/REL-03 attempt history tests) has a stable Oban-driven retry contract to assert against (`perform_job/3 attempt: 1..5`).
- Plan 14-08 (sync convergence parity + trace explicit assertions): D-13 already done here, so Plan 14-08 Task 1 has nothing further on `oban_worker_test.exs`. The remaining work is to add explicit `assert exp.last_attempt.attempt_number == ...` / `assert exp.last_attempt.error_class == ...` tests in `traces_test.exs`, plus any sync-side parity assertions for the new trace fields.

## Self-Check: PASSED

Verified files exist:
- `lib/chimeway/dispatch/oban_worker.ex` — FOUND
- `lib/chimeway/traces.ex` — FOUND
- `lib/chimeway/traces/explanation.ex` — FOUND
- `test/chimeway/dispatch/oban_worker_test.exs` — FOUND

Verified commits exist (`git log --oneline | grep`):
- `b044e29` (Task 1) — FOUND
- `60c7ac4` (Task 2) — FOUND
- `53ff4b1` (Task 3) — FOUND

Verified contract markers via grep:
- `oban_worker.ex` contains `attempt: attempt,` and `max_attempts: max_attempts` (perform/1 head + telemetry start meta) — OK
- `oban_worker.ex` contains `if attempt >= max_attempts do` and `Deliveries.exhaust_delivery(delivery)` and `error_class in ["permanent", "bounced"]` — OK
- `oban_worker.ex` contains 4 `defp map_outcome_to_oban_return` clauses — OK
- `oban_worker.ex` does NOT contain `@terminal_states` (Plan 14-03 already removed it) — OK
- `traces.ex` `last_attempt_summary/1` and `attempt_entries` both surface `attempt_number` + `error_class` — OK
- `explanation.ex` typespec for `last_attempt` includes `attempt_number:` and `error_class:` keys — OK
- `oban_worker_test.exs` contains the new describe header, the `attempt: 1` `{:error, _reason}` assertion, the `for n <- 1..4 do` loop, the `attempt: 5` `:ok` assertion, the `retries_exhausted` suppression_reason assertion, and 2 occurrences of `Deliveries.terminal_states()` — OK
- Legacy phrase `"retries failed delivery and succeeds with two attempts"` is gone — OK
- Full test suite: 228 tests, 0 failures, 27 skipped — OK

---
*Phase: 14-delivery-reliability-hardening*
*Plan: 05*
*Completed: 2026-04-26*

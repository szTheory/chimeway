---
phase: 14-delivery-reliability-hardening
plan: 03
subsystem: deliveries
tags: [elixir, ecto, state-machine, oban, dispatch, reliability]

# Dependency graph
requires:
  - phase: 14-delivery-reliability-hardening
    provides: Plan 14-02 reliability test scaffolding (test/chimeway/reliability/) and adapter classification contract
provides:
  - "Chimeway.Deliveries.exhaust_delivery/1 — single legitimate entry point for failed -> :cancelled (T-14-01 mitigation)"
  - "Chimeway.Deliveries.terminal_states/0 promoted as the single source of truth — sync.ex and oban_worker.ex stop duplicating the list"
  - "Documentation comment above @allowed_transitions explaining intentional omission of failed -> :cancelled"
  - "Behavior tests in test/chimeway/deliveries_test.exs covering all six exhaust_delivery/1 cases plus general-path rejection"
affects: [14-04 (record_attempt convergence), 14-05 (Oban worker exhausted-attempt path), 14-06, 14-07, 14-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Guarded named transition helper (mirrors suppress_delivery/3) for terminal-state writes that bypass @allowed_transitions"
    - "Promote module-attribute lists into public 0-arity accessor functions when the same list is referenced across multiple modules"

key-files:
  created: []
  modified:
    - lib/chimeway/deliveries.ex
    - lib/chimeway/dispatch/sync.ex
    - lib/chimeway/dispatch/oban_worker.ex
    - test/chimeway/deliveries_test.exs

key-decisions:
  - "exhaust_delivery/1 is the ONLY entry point for failed -> :cancelled — @allowed_transitions[:failed] stays [:dispatched] and the general transition_status/2 path continues to reject the transition"
  - "exhaust_delivery/1 mirrors suppress_delivery/3's pattern (direct change/2 |> Repo.update() bypassing the transition table) so the audit story for both terminal-state writes is identical"
  - "Convert sync.ex's `when status in @terminal_states` guard to an `if` because Deliveries.terminal_states() is a remote function call and cannot appear in a `when` clause (RESEARCH Pitfall 6)"
  - "Preserve Phase 10 correlation metadata (correlation_id, event_id, notification_key) when writing the policy_checkpoint=\"perform\" key — use ensure_metadata_map/1 + Map.put to avoid clobbering"

patterns-established:
  - "Named-helper terminal-state writes: when a transition needs to land outside the @allowed_transitions table, model it on suppress_delivery/3 — pattern-match the from-status, run change/2 |> Repo.update(), return {:error, {:invalid_<verb>_from, status}} for the catch-all"
  - "Single source of truth for shared atom lists: promote @attr to a public accessor function (def attr, do: @attr) when more than one module references the list"

requirements-completed: [REL-03]

# Metrics
duration: ~10min
completed: 2026-04-26
---

# Phase 14 Plan 03: Exhaustion State Machine + Terminal States SoT Summary

**Adds Deliveries.exhaust_delivery/1 (the only legitimate failed -> :cancelled path) and promotes terminal_states/0 to the single source of truth used by both sync and Oban dispatchers.**

## Performance

- **Duration:** ~10 min (one wave, two atomic tasks)
- **Started:** 2026-04-26T18:30:33Z
- **Completed:** 2026-04-26T18:36:43Z
- **Tasks:** 2 (1 TDD: RED + GREEN; 1 direct refactor)
- **Files modified:** 4

## Accomplishments

- Added `Chimeway.Deliveries.exhaust_delivery/1` (two clauses: happy path on `:failed`, catch-all returning `{:error, {:invalid_exhaust_from, status}}`).
- Wrote 6 behavior tests in `test/chimeway/deliveries_test.exs` plus a general-path rejection test for `failed -> :cancelled` and a canonical-list test for `terminal_states/0`.
- Removed the duplicated `@terminal_states` module attribute from `lib/chimeway/dispatch/sync.ex` and `lib/chimeway/dispatch/oban_worker.ex`.
- `grep -rn '@terminal_states' lib/chimeway/dispatch/` now returns **0 matches**; the only remaining references are inside `lib/chimeway/deliveries.ex` (the source-of-truth definition + accessor body).
- Full test suite remains green: **226 tests, 0 failures, 27 skipped** (pre-existing skip count).

## Task Commits

Each task was committed atomically (TDD task 1 had RED + GREEN commits; no refactor needed):

1. **Task 1 RED (test):** `2e1f813` — `test(14-03): add failing tests for Deliveries.exhaust_delivery/1`
2. **Task 1 GREEN (feat):** `d94c1c1` — `feat(14-03): add Deliveries.exhaust_delivery/1 named helper`
3. **Task 2 (refactor):** `0abd22c` — `refactor(14-03): use Deliveries.terminal_states/0 in dispatchers`

_Note: Task 1 followed the TDD RED/GREEN cycle. No REFACTOR commit was needed — implementation is minimal and clean._

## Where exhaust_delivery/1 was inserted

Inserted into `lib/chimeway/deliveries.ex` at lines **159–193**, between the closing `end` of `suppress_delivery/3` (line 153) and the `@doc """Atomically inserts an attempt row...` line that begins `record_attempt/2` (line 195+). The module-attribute comment was inserted at lines 23–27 directly above the `@allowed_transitions` map.

Function structure:

```elixir
@doc """ ... ObanWorker-only contract documented ... """
@spec exhaust_delivery(Delivery.t()) :: {:ok, Delivery.t()} | {:error, term()}
def exhaust_delivery(%Delivery{status: :failed} = delivery) do
  metadata =
    delivery.metadata
    |> ensure_metadata_map()
    |> Map.put("policy_checkpoint", "perform")

  delivery
  |> change(
    status: :cancelled,
    suppression_reason: "retries_exhausted",
    metadata: metadata
  )
  |> Repo.update()
end

def exhaust_delivery(%Delivery{status: status}),
  do: {:error, {:invalid_exhaust_from, status}}
```

## Diff: sync.ex (guard-to-if conversion)

Before (line 25 + lines 57–66):

```elixir
@terminal_states [:succeeded, :suppressed, :cancelled]
# ...
defp dispatch_delivery(%{status: status} = delivery) when status in @terminal_states do
  {:ok, delivery}
end

defp dispatch_delivery(delivery) do
  case Policy.evaluate(delivery, check_read_state: delivery.delay_fallback) do
    {:suppress, reason} -> Deliveries.suppress_delivery(delivery, reason, checkpoint: :perform)
    {:ok, :proceed} -> do_dispatch_with_telemetry(delivery)
  end
end
```

After (single clause using `if`, attribute removed):

```elixir
defp dispatch_delivery(%{status: status} = delivery) do
  if status in Deliveries.terminal_states() do
    {:ok, delivery}
  else
    case Policy.evaluate(delivery, check_read_state: delivery.delay_fallback) do
      {:suppress, reason} -> Deliveries.suppress_delivery(delivery, reason, checkpoint: :perform)
      {:ok, :proceed} -> do_dispatch_with_telemetry(delivery)
    end
  end
end
```

Reason for guard-to-if conversion: a remote function call (`Deliveries.terminal_states()`) cannot appear in a `when` clause (RESEARCH Pitfall 6). The two clauses collapse into one with an inner `if`/`else`.

## Diff: oban_worker.ex (one-line swap)

Before (line 38 + line 44):

```elixir
@terminal_states [:succeeded, :suppressed, :cancelled]
# ...
if delivery.status in @terminal_states do
```

After (attribute removed; line 42 now reads):

```elixir
if delivery.status in Deliveries.terminal_states() do
```

The `perform/1` body was otherwise untouched; Plan 14-05 lands the `attempt`/`max_attempts` retry contract on top of this scaffolding.

## Confirmation: no @terminal_states left in dispatch

```
$ grep -rn '@terminal_states' lib/chimeway/dispatch/
(empty — 0 matches)

$ grep -rn '@terminal_states' lib/chimeway/
lib/chimeway/deliveries.ex:15:  @terminal_states [:succeeded, :suppressed, :cancelled]
lib/chimeway/deliveries.ex:21:  def terminal_states, do: @terminal_states
```

Single source of truth confirmed.

## Behavior tests passing (deliveries_test.exs)

The plan's behavior section enumerated seven test cases. All seven were written in this plan and pass:

| # | Test | Status |
|---|------|--------|
| 1 | `transition_status(failed_delivery, :dispatched)` still succeeds (existing retry path) | PASS (pre-existing) |
| 2 | `transition_status(failed_delivery, :cancelled)` returns `{:error, {:invalid_transition, from: :failed, to: :cancelled}}` | PASS (new test) |
| 3 | `exhaust_delivery(failed_delivery)` returns `{:ok, delivery}` with `:cancelled` + `"retries_exhausted"` | PASS (new) |
| 4 | `exhaust_delivery(pending_delivery)` returns `{:error, {:invalid_exhaust_from, :pending}}` | PASS (new) |
| 5 | `exhaust_delivery(succeeded_delivery)` returns `{:error, {:invalid_exhaust_from, :succeeded}}` | PASS (new) |
| 6 | `exhaust_delivery(failed_delivery).metadata["policy_checkpoint"] == "perform"` | PASS (new) |
| 7 | `terminal_states/0` returns `[:succeeded, :suppressed, :cancelled]` (unchanged) | PASS (new) |

Plus a bonus test asserting Phase 10 correlation metadata is preserved through `exhaust_delivery/1` (correlation_id, event_id, notification_key all retained alongside the new policy_checkpoint key).

`mix test test/chimeway/deliveries_test.exs` reports `26 tests, 0 failures`.

## Smoke-test output for invalid_exhaust_from path

```
$ mix run --no-start -e 'IO.inspect(Chimeway.Deliveries.exhaust_delivery(%Chimeway.Delivery{status: :pending}))'
{:error, {:invalid_exhaust_from, :pending}}
```

Exit 0, output matches plan's expected smoke-test result exactly.

## Files Created/Modified

- `lib/chimeway/deliveries.ex` — Added `exhaust_delivery/1` (two clauses, lines 159–193) + explanatory comment above `@allowed_transitions` (lines 23–27); `terminal_states/0` and `@terminal_states` line UNCHANGED at lines 15 and 21.
- `lib/chimeway/dispatch/sync.ex` — Removed `@terminal_states` attribute; collapsed two `dispatch_delivery/1` clauses into a single clause using `if status in Deliveries.terminal_states()`.
- `lib/chimeway/dispatch/oban_worker.ex` — Removed `@terminal_states` attribute; swapped the perform-time terminal check to `Deliveries.terminal_states()`.
- `test/chimeway/deliveries_test.exs` — Added 8 new tests across `transition_status/2` (general-path rejection), `terminal_states/0`, and `exhaust_delivery/1` describes.

## Decisions Made

None beyond the plan as written. The plan was specified at task-step granularity (exact code blocks, exact comment text, exact test names) and executed verbatim. Decisions enumerated in the frontmatter were made by the planner; this executor confirmed each one in code.

## Deviations from Plan

None — plan executed exactly as written.

The `<read_first>` lines, `<action>` directives, and `<acceptance_criteria>` matched up perfectly with the existing source. Both Tasks 1 and 2 landed on the first attempt; both verifications passed first try; full test suite green first try (226 tests, 0 failures).

## Issues Encountered

- Initial `mix test` invocation reported missing dependencies because the worktree was freshly reset to the wave base. Resolved with `mix deps.get`. This is normal worktree initialization, not a deviation.
- No other issues.

## TDD Gate Compliance

Plan 14-03 has only one `tdd="true"` task (Task 1). The required commit sequence is satisfied:

- RED gate: `2e1f813` (`test(14-03): add failing tests for Deliveries.exhaust_delivery/1`) — 6 new tests fail with `UndefinedFunctionError`.
- GREEN gate: `d94c1c1` (`feat(14-03): add Deliveries.exhaust_delivery/1 named helper`) — all 26 deliveries tests pass.
- REFACTOR gate: skipped — implementation was minimal and clean; no commit warranted.

Plan-level `type: execute` (not `tdd`), so no plan-level gate sequence is required.

## Threat Model Coverage

| Threat ID | Disposition | How this plan addresses it |
|-----------|-------------|----------------------------|
| T-14-01 (E: arbitrary callers driving failed -> cancelled) | mitigate | `@allowed_transitions[:failed]` stays `[:dispatched]`; general-path rejection is asserted by the new test "rejects general-path failed → cancelled (reserved for exhaust_delivery/1)". `exhaust_delivery/1` is the only function that can perform this transition, and its moduledoc plus comment above `@allowed_transitions` document the ObanWorker-only contract. |
| T-14-06 (T: suppression_reason overwrite) | accept | `:failed` deliveries do not carry a meaningful `suppression_reason` (set only on `:suppressed` writes via `suppress_delivery/3`). Overwriting with `"retries_exhausted"` is the durable explanation of the new terminal state. |
| T-14-07 (I: policy_checkpoint overwrite) | accept | Trace-level metadata; not user-controlled. The new test "preserves prior metadata keys" confirms `correlation_id`, `event_id`, `notification_key` are NOT clobbered when `policy_checkpoint` is added. |

No new threat surface introduced. No threat flags raised.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Plans 14-04 and 14-05 can now call `Chimeway.Deliveries.exhaust_delivery/1` directly:

- **14-04 (record_attempt convergence):** Will use the same single-source-of-truth `terminal_states/0` and may extend `record_attempt/2` to reuse the named-helper pattern established here.
- **14-05 (Oban worker exhausted-attempt path):** Will wire `if job.attempt == job.max_attempts` to call `Deliveries.exhaust_delivery(delivery)` from inside `ObanWorker.perform/1`. Plan 14-03 deliberately did NOT touch the perform/1 body beyond the terminal-state lookup so that 14-05 lands cleanly on top.

No blockers.

## Self-Check: PASSED

**Files exist:**

- `lib/chimeway/deliveries.ex` — FOUND (modified, contains `def exhaust_delivery(%Delivery{status: :failed}` at line 176)
- `lib/chimeway/dispatch/sync.ex` — FOUND (modified, contains `if status in Deliveries.terminal_states() do` at line 56; no `@terminal_states`)
- `lib/chimeway/dispatch/oban_worker.ex` — FOUND (modified, contains `if delivery.status in Deliveries.terminal_states() do` at line 42; no `@terminal_states`)
- `test/chimeway/deliveries_test.exs` — FOUND (modified, 26 tests, 0 failures)
- `.planning/phases/14-delivery-reliability-hardening/14-03-SUMMARY.md` — FOUND (this file)

**Commits exist:**

- `2e1f813` (test RED) — FOUND in `git log --oneline --all`
- `d94c1c1` (feat GREEN) — FOUND in `git log --oneline --all`
- `0abd22c` (refactor) — FOUND in `git log --oneline --all`

**Verification:**

- `mix compile --warnings-as-errors --force` exits 0.
- `mix test test/chimeway/deliveries_test.exs` reports `26 tests, 0 failures`.
- `mix test test/chimeway/dispatch/` reports `40 tests, 0 failures`.
- `mix test` reports `226 tests, 0 failures, 27 skipped` (no regression).
- `grep -rn '@terminal_states' lib/chimeway/dispatch/` returns 0 matches.
- `grep -c 'def exhaust_delivery' lib/chimeway/deliveries.ex` returns `2`.

---
*Phase: 14-delivery-reliability-hardening*
*Plan: 03*
*Completed: 2026-04-26*

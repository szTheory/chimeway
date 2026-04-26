---
phase: 14-delivery-reliability-hardening
plan: 07
subsystem: testing

tags:
  - oban
  - retry
  - exhaustion
  - terminal-convergence
  - attempt-history
  - telemetry
  - rel-02
  - rel-03

# Dependency graph
requires:
  - phase: 14-delivery-reliability-hardening
    provides: "Plan 14-02 attempt schema fields; Plan 14-03 exhaust_delivery/1; Plan 14-04 SELECT FOR UPDATE row lock + record_attempt/2 multi steps; Plan 14-05 ObanWorker in-band exhaustion guard"
provides:
  - "test/chimeway/reliability/attempt_history_test.exs (10 tests, 4 describes) — REL-02 D-07/D-14"
  - "test/chimeway/reliability/retry_exhaustion_test.exs (5 tests, 3 describes) — REL-02 D-04/D-10/D-11"
  - "test/chimeway/reliability/terminal_convergence_test.exs (6 tests, 6 describes) — REL-03 D-12"
  - "B5 robust drain_queue contract assertion (no hard-coded success/failure counts)"
affects:
  - "Plan 14-08 (traces / regression spot-checks) — uses these as the green baseline before adding traces_test.exs assertions"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "B5 robust drain_queue assertion: assert observable contract (terminal status + attempt history + total_executed >= 1) instead of hard-coding the drain result map shape"
    - "Local test-only adapter modules at file top (PermanentAdapter / BouncedAdapter / TemporaryAdapter) so each reliability test file runs in isolation without depending on sibling test files being loaded"

key-files:
  created: []
  modified:
    - "test/chimeway/reliability/attempt_history_test.exs"
    - "test/chimeway/reliability/retry_exhaustion_test.exs"
    - "test/chimeway/reliability/terminal_convergence_test.exs"
    - "lib/chimeway/telemetry.ex (Task 1 commit only — added attempt_number + error_class to @allowed_meta_keys)"

key-decisions:
  - "Use observable-contract assertions for drain_queue (B5) — total_executed >= 1, delivery converged, attempt_count == 5 — rather than hard-coding result-shape counts because Oban drain semantics for retryable jobs are version-dependent."
  - "Define a local TemporaryAdapter inside terminal_convergence_test.exs rather than reusing Chimeway.Test.RetryFailingAdapter from retry_exhaustion_test.exs. Test files must be runnable in isolation (mix test path/to/file)."
  - "Skip re-implementation of the deliveries_test.exs exhaust_delivery/1 describe — the existing block (lines 177-244) already covers all of Task 3's deliveries_test.exs acceptance criteria with richer coverage."

patterns-established:
  - "B5 robust contract assertion for queue drains"
  - "Per-file local test adapters keep reliability test files independent"

requirements-completed: [REL-02, REL-03]

# Metrics
duration: 12min
completed: 2026-04-26
---

# Phase 14 Plan 07: Reliability Test Coverage Summary

**REL-02 + REL-03 contract test coverage — attempt history ordinality + telemetry, Oban retry exhaustion (in-band + drain_queue), and six-path terminal convergence to `Deliveries.terminal_states/0`.**

## Performance

- **Duration:** ~12 min (continuation run for Tasks 2 + 3; Task 1 salvaged from prior worktree)
- **Started:** 2026-04-26T19:43:00Z (continuation agent start)
- **Completed:** 2026-04-26T19:55:00Z
- **Tasks:** 3 (Task 1 = salvaged; Tasks 2 + 3 = new commits in this run)
- **Files modified:** 3 test files (plus telemetry.ex from the salvaged Task 1)

## Accomplishments

- REL-02 D-07/D-14 attempt-history assertions in place (Task 1 — salvaged): attempt_number ordinality 1..N, error_class taxonomy ("temporary" | "permanent" | "bounced" | nil), changeset whitelist, concurrent attempt_number race deterministic via the Plan 14-04 Task 2 SELECT FOR UPDATE row lock.
- REL-02 D-04/D-10/D-11 Oban retry contract verified end-to-end (Task 2): `perform_job/3` with attempt 1..4 returns `{:error, _}`; attempt 5 (max_attempts) writes `:cancelled retries_exhausted` and returns `:ok`; integration `Oban.drain_queue` test passes with B5 robust contract assertions (no hard-coded counts).
- REL-03 D-12 terminal convergence verified across all six paths (Task 3): succeeded, retries_exhausted, permanent_failure, bounced, suppressed, manual cancelled — every assertion uses `in Deliveries.terminal_states()` membership, never a hardcoded list.

## Task Commits

Each task was committed atomically:

1. **Task 1: REL-02 D-07 attempt history assertions** — `f06378f` (test)  *salvaged from prior agent run; landed before this continuation started*
2. **Task 2: REL-02 retry exhaustion contract tests** — `9b9ba76` (test)
3. **Task 3: REL-03 terminal convergence tests** — `ded6a1b` (test)

_Note: This continuation run did not produce a final plan-metadata commit because the orchestrator instructed not to update STATE.md / ROADMAP.md (parallel-executor mode, not standard plan completion). SUMMARY.md will be committed as a separate trailing commit._

## Files Created/Modified

- `test/chimeway/reliability/attempt_history_test.exs` *(via salvaged f06378f)* — 4 describes / 10 tests for REL-02 D-07 + D-14 + W3 telemetry stop metadata.
- `test/chimeway/reliability/retry_exhaustion_test.exs` *(this run)* — 3 describes / 5 tests for REL-02 D-04 + D-10 + D-11 + B5 drain_queue contract.
- `test/chimeway/reliability/terminal_convergence_test.exs` *(this run)* — 6 describes / 6 tests for REL-03 D-12, plus three local test-only adapters at file top.
- `lib/chimeway/telemetry.ex` *(via salvaged f06378f)* — added `attempt_number` + `error_class` to `@allowed_meta_keys` so the W3 telemetry stop event preserves them after `safe_meta/1` filtering. **NOT TOUCHED in Tasks 2 / 3.**

## Decisions Made

- **B5 drain_queue assertion shape (Task 2):** Asserts `total_executed = success + failure + discard >= 1` AND delivery converged terminally AND `attempt_count == 5`. Does not hard-code the drain result map fields because Oban 2.21.x retryable-job drain semantics are version-dependent (RESEARCH Open Question 2 — RESOLVED). The observable contract is what matters; the drain-result shape is incidental.
- **Local TemporaryAdapter in terminal_convergence_test.exs (Task 3 deviation):** Reusing `Chimeway.Test.RetryFailingAdapter` from `retry_exhaustion_test.exs` made `mix test test/chimeway/reliability/terminal_convergence_test.exs` (single-file) fail with `UndefinedFunctionError` because Elixir test files compile in isolation. Defined a local `Chimeway.Reliability.TerminalConvergenceTest.TemporaryAdapter` instead.
- **Skip deliveries_test.exs edits (Task 3):** The existing `exhaust_delivery/1` describe (lines 177-244 of `test/chimeway/deliveries_test.exs`) and the existing transition_status guard test (line 155 — "rejects general-path failed → cancelled") already satisfy every Task 3 deliveries_test.exs acceptance criterion. Re-inserting the plan's literal text would have produced a duplicate describe block. Existing coverage is strictly richer (6 tests vs. 4 in plan).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Local TemporaryAdapter in terminal_convergence_test.exs**
- **Found during:** Task 3 (initial run)
- **Issue:** First draft of `terminal_convergence_test.exs` referenced `Chimeway.Test.RetryFailingAdapter` which is defined at the top of `retry_exhaustion_test.exs`. Single-file `mix test path/to/terminal_convergence_test.exs` failed with `UndefinedFunctionError` because Elixir test files do not transitively load sibling test files at compile time. The combined run worked because both files happened to be loaded.
- **Fix:** Added a local `Chimeway.Reliability.TerminalConvergenceTest.TemporaryAdapter` module at the top of the file (alongside `PermanentAdapter` + `BouncedAdapter`) and referenced it via the alias group.
- **Files modified:** `test/chimeway/reliability/terminal_convergence_test.exs`
- **Verification:** `mix test test/chimeway/reliability/terminal_convergence_test.exs --include oban` exits 0 in isolation.
- **Committed in:** `ded6a1b` (Task 3 commit)

**2. [Rule 2 — Missing Critical] No deliveries_test.exs edit needed**
- **Found during:** Task 3 (planning)
- **Issue:** The plan instructed inserting an `exhaust_delivery/1` describe block, but reading `test/chimeway/deliveries_test.exs` showed the block already exists (lines 177-244) with strictly richer coverage than the plan specified (6 tests vs. 4). The plan's general-path-rejection test is also already present (lines 155-164 — "rejects general-path failed → cancelled (reserved for exhaust_delivery/1)") inside the `transition_status/2` describe.
- **Fix:** Skipped the deliveries_test.exs edit. All Task 3 deliveries_test.exs acceptance criteria pass against the existing file unchanged.
- **Verification:** `grep -c 'describe "exhaust_delivery/1"' test/chimeway/deliveries_test.exs` returns 1; full assertion-pattern grep for the four required assertion strings matches; `mix test test/chimeway/deliveries_test.exs` exits 0 (26 tests).
- **Documented here only:** No commit needed — file already in correct state.

---

**Total deviations:** 2 (1 Rule 3 blocking fix, 1 Rule 2 "no-op required" — work was already complete in source).
**Impact on plan:** Acceptance criteria fully met for Tasks 2 and 3. No scope creep. No source-code (`lib/`) changes outside the salvaged Task 1 commit.

## Issues Encountered

### Pre-existing failure: W3 telemetry test in attempt_history_test.exs (Task 1, line 148)

Running `mix test test/chimeway/reliability/attempt_history_test.exs --include oban` produces 9 passing tests and 1 failure:

```
test telemetry stop metadata (W3 — Phase 10 enrichment preserved)
[:attempts, :record, :stop] event meta carries attempt_number and error_class
  Expected truthy, got false
  code: assert Map.has_key?(meta, :delivery_id)
  meta = %{attempt_id: ..., attempt_number: 1, error_class: "temporary", outcome: :failed, telemetry_span_context: ...}
```

This test was authored on the assumption that `Chimeway.Telemetry.span/3` automatically merges start metadata into stop metadata (the Phase 10-02 enrichment fix). That fix is **NOT present** in this worktree — per orchestrator instructions (parallel_execution: "Do NOT modify lib/chimeway/telemetry.ex. The Phase 10-02 span/3 fix is currently sitting as in-progress local edits in the main worktree — leave telemetry.ex alone in your worktree").

**Resolution path:** When the Phase 10-02 telemetry.ex fix lands on main, this test will pass without further changes — the assertions are correct against the intended span/3 contract; only the implementation is pending in another agent's worktree.

**Scope decision:** This failure is out-of-scope for this continuation run. It came in on the salvaged Task 1 commit (`f06378f`) which I was instructed not to redo, and the fix lives in a file I was instructed not to touch.

### B5 drain_queue result shape (observed for future readers)

The `drain_queue` test in `retry_exhaustion_test.exs` asserts on observable outcome state, not the drain result map shape. Observed result on Oban 2.21.1 in this worktree:

```elixir
# Approximate observed shape (varies by Oban version):
%{success: 0, failure: N, ...}  # where 1 <= N <= max_attempts
```

The B5 assertion `total_executed = success + failure + discard >= 1` is robust to whatever shape Oban reports because the contract we care about is "queue made progress AND delivery converged AND attempt history accumulated to max_attempts" — all of which are checked separately and pass deterministically.

### Concurrency observation (W8 row lock — attempt_history_test.exs concurrent describe)

The `concurrent record_attempt calls produce contiguous attempt_numbers` test in `attempt_history_test.exs` uses `Task.async_stream` with 5 parallel callers. With Plan 14-04 Task 2's `:lock_delivery` step (`SELECT ... FOR UPDATE`) in `Deliveries.record_attempt/2`, the test passes deterministically including under `--seed 0`. **No flakes observed across the runs in this session.** The lock makes contiguity invariant by construction, not by retry — the test asserts both `length == length(Enum.uniq)` AND `sorted == 1..N` and both invariants hold every run.

## Verification

- `mix test test/chimeway/reliability/retry_exhaustion_test.exs --include oban --include integration` → **5 tests, 0 failures** (Task 2)
- `mix test test/chimeway/reliability/retry_exhaustion_test.exs --include oban --include integration --seed 0` → **5 tests, 0 failures** (deterministic)
- `mix test test/chimeway/reliability/terminal_convergence_test.exs --include oban` → **6 tests, 0 failures** (Task 3)
- `mix test test/chimeway/reliability/terminal_convergence_test.exs --include oban --seed 0` → **6 tests, 0 failures** (deterministic)
- `mix test test/chimeway/deliveries_test.exs` → **26 tests, 0 failures**
- `mix test test/chimeway/deliveries_test.exs --seed 0` → **26 tests, 0 failures**
- Combined Task 2/3 run with `--seed 0`: **32 tests, 0 failures**

Combined plan run including Task 1 salvage: **54 tests, 1 failure** — the failure is the cross-worktree-dependent W3 telemetry test discussed above.

### Acceptance criteria check (per task)

**Task 2 — retry_exhaustion_test.exs:**
- `@moduletag :skip` removed ✓
- `Chimeway.Test.RetryFailingAdapter` defined at top ✓
- `assert {:error, _reason} = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 1)` ✓
- `for n <- 1..4 do` block expecting `{:error, _}` per iteration ✓
- `assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 5)` ✓
- `assert updated.suppression_reason == "retries_exhausted"` ✓
- `Oban.drain_queue(queue: :chimeway_delivery,` ✓
- B5 robust assertion: `total_executed = Map.get(...) + Map.get(...) + Map.get(...)` AND `assert total_executed >= 1` ✓
- No hard-coded count assertions on the drain result ✓
- `assert attempt_count == 5` ✓
- `assert updated.status in Deliveries.terminal_states()` 3× (criteria: at least twice) ✓

**Task 3 — terminal_convergence_test.exs:**
- `@moduletag :skip` removed ✓
- 6 describes (succeeded, retries_exhausted, permanent_failure, bounced, suppressed, manual cancelled) ✓
- `assert ... in Deliveries.terminal_states()` 6× ✓
- No hardcoded `[:succeeded, :suppressed, :cancelled]` literal in the file ✓

**Task 3 — deliveries_test.exs (already met by existing file):**
- `describe "exhaust_delivery/1"` block ✓
- 4+ tests covering success, pending-rejection, succeeded-rejection, general-transition-rejection ✓ (file has 6 such tests)
- `assert exhausted.status == :cancelled` AND `assert exhausted.suppression_reason == "retries_exhausted"` ✓
- `assert {:error, {:invalid_exhaust_from, :pending}} = Deliveries.exhaust_delivery(delivery)` ✓
- `assert {:error, {:invalid_transition, from: :failed, to: :cancelled}} = Deliveries.transition_status(failed, :cancelled)` ✓ (in `transition_status/2` describe at line 162)

## W3 Telemetry Assertion Location

**File:** `test/chimeway/reliability/attempt_history_test.exs`
**Describe:** `"telemetry stop metadata (W3 — Phase 10 enrichment preserved)"` (lines 147-182)
**Test:** `"[:attempts, :record, :stop] event meta carries attempt_number and error_class"`

**Assertions on the captured stop event meta:**
- `meta.attempt_number == 1`
- `meta.error_class == "temporary"`
- `Map.has_key?(meta, :delivery_id)` — *currently failing pending Phase 10-02 span/3 fix*
- `meta.delivery_id == delivery.id` — *blocked by the same dependency*

**Observed metadata fields (this worktree, without the Phase 10-02 fix):**
```
%{attempt_id, attempt_number, error_class, outcome, telemetry_span_context}
```

When the Phase 10-02 fix lands the start-metadata keys (`delivery_id`, `channel`, `notification_key`) merge into the stop metadata and the test passes.

## Self-Check

**Files exist:**
- `test/chimeway/reliability/attempt_history_test.exs` — FOUND
- `test/chimeway/reliability/retry_exhaustion_test.exs` — FOUND
- `test/chimeway/reliability/terminal_convergence_test.exs` — FOUND
- `test/chimeway/deliveries_test.exs` — FOUND
- `.planning/phases/14-delivery-reliability-hardening/14-07-SUMMARY.md` — FOUND (this file)

**Commits exist:**
- `f06378f` (Task 1 salvage) — FOUND
- `9b9ba76` (Task 2) — FOUND
- `ded6a1b` (Task 3) — FOUND

## Self-Check: PASSED

## Next Phase Readiness

- REL-02 + REL-03 contract test coverage in place. Plan 14-08 (traces / regression spot-checks) can begin against these files as the green baseline.
- One pre-existing test failure (`attempt_history_test.exs:148`) blocks until the Phase 10-02 telemetry.ex `span/3` fix lands on main from its own worktree. Tracking note for orchestrator: this is not a regression introduced by Plan 14-07; it surfaces a cross-worktree coordination dependency that should be resolved when Phase 10-02 merges.

---
*Phase: 14-delivery-reliability-hardening*
*Plan: 07*
*Completed: 2026-04-26*

---
phase: 14-delivery-reliability-hardening
verified: 2026-04-26T23:00:00Z
status: passed
score: 10/10 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 7/10
  gaps_closed:
    - "Concurrent record_attempt/2 callers do not race attempt_number or clobber metadata (BL-01 + WR-01)"
    - "Every delivery converges to a durable, explainable final state in all anticipated and defensive paths (BL-02 + WR-06)"
    - "Trace explanation surfaces are accurate and consistent with the durable final state (WR-05 + WR-07)"
  gaps_remaining: []
  regressions: []

---

# Phase 14: Delivery Reliability Hardening — Re-Verification Report

**Phase Goal:** Make delivery retries durable, de-duplicated, and convergent — every delivery reaches a final state, attempt history is preserved, and duplicate triggers are inert.
**Verified:** 2026-04-26T23:00:00Z
**Status:** PASSED
**Re-verification:** Yes — after gap closure plans 14-09, 14-10, 14-11

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | Retry paths do not create duplicate events, notifications, or deliveries (ROADMAP SC-1 / REL-01) | ✓ VERIFIED | `test/chimeway/reliability/duplicate_protection_test.exs` 10 tests (D-02a/b/c/d + D-03 + D-14a/b/c) all pass. `trigger.ex` `@moduledoc` §"Duplicate-trigger contract" + inline D-03 comments at lines 294-298, 330. |
| 2  | Delivery attempts preserve backoff and retry history (ROADMAP SC-2 / REL-02) | ✓ VERIFIED | `chimeway_delivery_attempts.attempt_number` + `error_class` columns in migration `20260426150000_add_attempt_history_columns.exs`. `DeliveryAttempt.@required_fields ~w(delivery_id outcome attempt_number)a`. `attempt_history_test.exs` covers ordinality, taxonomy, W3 telemetry stop metadata, and concurrent W8 lock race (10 acquirers). `retry_exhaustion_test.exs` covers all 5 attempts + drain_queue end-to-end. |
| 3  | Every delivery reaches a durable, explainable final state (ROADMAP SC-3 / REL-03) | ✓ VERIFIED | `terminal_convergence_test.exs` verifies all 6 D-12 paths via `delivery.status in Deliveries.terminal_states()`. `deliveries_test.exs` `describe "exhaust_delivery/1"` covers happy-path + invalid-from + D-10 general-path guard rejection. |
| 4  | Retry contract: temporary → {:error,_} on attempt < max; → exhaust_delivery + :ok on attempt == max; permanent/bounced → :ok; succeeded → :ok | ✓ VERIFIED | `oban_worker.ex:164-246` `map_outcome_to_oban_return/4` has 4 documented clauses + new two-branch catch-all (BL-02 fix). `oban_worker_test.exs` D-13 rewrite covers attempt-1 retry, recovered retry, and attempt-5 exhaustion. BL-02 regression tests cover Branch A (converge via `exhaust_delivery/1`) and Branch B (raise `UnhandledOutcomeError`). |
| 5  | Adapter classification preserved end-to-end: classify/1 returns 3-tuple; error_class strings persist on attempts | ✓ VERIFIED | `executor.ex:49-59` classify/1 has 4 documented clauses + fallback clause (`defp classify(other)`) mapping unknown shapes to `{:rejected, "unknown_classification", _}`. `run_delivery/1` passes `error_class:` to `record_attempt`. `sync_test.exs` permanent → :cancelled/"permanent_failure", bounced → :cancelled/"bounced". |
| 6  | terminal_states/0 is a single source of truth — no duplicate hardcoded lists in `lib/chimeway/dispatch/` | ✓ VERIFIED | `grep -rn '@terminal_states' lib/chimeway/dispatch/` returns 0 matches. `oban_worker.ex:112` and `sync.ex:56` both call `Deliveries.terminal_states()`. |
| 7  | Telemetry [:dispatch, :perform] start metadata gains attempt + max_attempts; [:attempts, :record, :stop] meta carries attempt_number + error_class | ✓ VERIFIED | `oban_worker.ex:121-122` adds `attempt:` + `max_attempts:` to start meta. `deliveries.ex:282-283` adds `attempt_number` + `error_class` to extra. `telemetry.ex:104` `Map.merge(meta, extra)` wires stop metadata enrichment. `attempt_history_test.exs` W3 telemetry test asserts `meta.attempt_number == 1` and `meta.error_class == "temporary"`. |
| 8  | Concurrent record_attempt/2 callers do not race attempt_number or clobber concurrent metadata writes (W8 row lock) | ✓ VERIFIED | **BL-01 fixed (Plan 14-09 Task 1):** `deliveries.ex:250-270` — `:next_attempt_number` destructures `%{lock_delivery: locked}` and uses `^locked.id`; `:attempt` destructures `%{next_attempt_number: n, lock_delivery: locked}` and re-asserts `delivery_id: locked.id`; `:delivery` destructures `%{lock_delivery: locked}` and calls `terminal_or_failed_transition(locked, ...)`. **WR-01 fixed (Plan 14-09 Task 2):** "10 concurrent W8 lock acquirers each get a unique attempt_number 1..10" test directly exercises the (SELECT FOR UPDATE + count + insert) primitive. BL-01 regression test proves `test_marker` probe key written between snapshot and lock acquisition survives `cancel_with_reason/2`. |
| 9  | Every delivery converges to a terminal state in all paths including defensive catch-alls | ✓ VERIFIED | **BL-02 fixed (Plan 14-10 Task 1):** `oban_worker.ex:210-243` catch-all uses two-branch cond: Branch A (`attempt_n >= max and delivery.status == :failed`) → `Deliveries.exhaust_delivery/1`; Branch B → `Logger.error` + `raise UnhandledOutcomeError`. `executor.ex:59-61` adds fallback `classify(other)` so unexpected adapter shapes reach the catch-all instead of crashing before. `DeliveryAttempt.@error_classes` extended with `"unknown_classification"`. **WR-06 fixed (Plan 14-11 Task 1):** `traces.ex` `build_timeline/4` emits a `:cancelled` timeline entry (parallel to `:suppressed`) when `delivery.status == :cancelled and delivery.suppression_reason`. |
| 10 | Trace explanation accurately surfaces the most recent attempt and stays consistent with the :cancelled reason set | ✓ VERIFIED | **WR-05 fixed (Plan 14-11 Task 1):** `traces.ex:154` now `Enum.max_by(attempts, & &1.attempt_number)`. `traces_test.exs` WR-05 tie-break test confirms deterministic selection by attempt_number even when inserted_at timestamps are identical (microsecond: {0,6}). **WR-07 fixed (Plan 14-11 Task 1):** `explanation.ex:18-24` documents `suppression_reason` is non-nil for both `:suppressed` AND `:cancelled`; lists all four reason strings. WR-06 regression tests cover retries_exhausted, permanent_failure, bounced timeline entries and no-double-count guard. |

**Score:** 10/10 truths verified

### Gaps Closed Since Previous Verification

| Gap | Status | Closed By |
|-----|--------|-----------|
| BL-01 — stale closure struct in record_attempt/2 Multi downstream steps | CLOSED | Plan 14-09 Task 1 — `%{lock_delivery: locked}` threaded through :next_attempt_number, :attempt, :delivery steps |
| WR-01 — concurrent test races transition_status, not record_attempt | CLOSED | Plan 14-09 Task 2 — new "10 concurrent W8 lock acquirers" test directly exercises (lock + count + insert) primitive |
| BL-02 — catch-all bypasses exhaust_delivery on final attempt | CLOSED | Plan 14-10 Task 1 — two-branch cond (Branch A: converge; Branch B: raise) + classify/1 fallback |
| WR-05 — last_attempt_summary orders by inserted_at instead of canonical attempt_number | CLOSED | Plan 14-11 Task 1 — `Enum.max_by(attempts, & &1.attempt_number)` |
| WR-06 — no :cancelled timeline entry for new reason set | CLOSED | Plan 14-11 Task 1 — `cancellation_entries` builder in `build_timeline/4` |
| WR-07 — Explanation moduledoc stale on suppression_reason contract | CLOSED | Plan 14-11 Task 1 — moduledoc updated with four reason strings and :suppressed/:cancelled mapping |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|---------|--------|---------|
| `priv/repo/migrations/20260426150000_add_attempt_history_columns.exs` | Additive migration with attempt_number + error_class + ROW_NUMBER backfill | ✓ VERIFIED | `up/down` (not `change`); ROW_NUMBER window function; error_class index present. |
| `lib/chimeway/delivery_attempt.ex` | Schema with attempt_number+error_class fields, error_classes/0 helper, validate_inclusion + positive integer check | ✓ VERIFIED | `@error_classes ~w(temporary permanent bounced unknown_classification)` (extended by Plan 14-10); `@required_fields ~w(delivery_id outcome attempt_number)a`; all validation logic present. |
| `lib/chimeway/deliveries.ex` | exhaust_delivery/1, record_attempt/2 with locked-row threading, terminal_or_failed_transition/3, cancel_with_reason/2 | ✓ VERIFIED | All three Multi steps destructure `%{lock_delivery: locked}` (BL-01 fixed); `exhaust_delivery/1` two clauses; `cancel_with_reason/2` reads from locked row. |
| `lib/chimeway/dispatch/oban_worker.ex` | perform/1 with attempt+max_attempts; 4 documented clauses + two-branch catch-all; telemetry enriched | ✓ VERIFIED | BL-02 fixed; `UnhandledOutcomeError` defined; `require Logger` present; both `exhaust_delivery/1` calls (existing temporary path + new catch-all Branch A). |
| `lib/chimeway/dispatch/sync.ex` | Uses Deliveries.terminal_states() in if-form; no @terminal_states attribute | ✓ VERIFIED | Line 56 uses `if status in Deliveries.terminal_states() do`. |
| `lib/chimeway/dispatch/executor.ex` | classify/1 3-tuple in all 4 cases + fallback clause | ✓ VERIFIED | Lines 49-59 — 4 documented clauses + `defp classify(other)` fallback. |
| `lib/chimeway/traces.ex` | last_attempt_summary orders by attempt_number; timeline :cancelled entry emitted for cancelled deliveries | ✓ VERIFIED | Line 154 `Enum.max_by(attempts, & &1.attempt_number)`; `cancellation_entries` builder at lines 198-209; concatenation includes cancellation_entries. |
| `lib/chimeway/traces/explanation.ex` | last_attempt typespec includes attempt_number + error_class; moduledoc updated for :cancelled reasons | ✓ VERIFIED | Typespec lines 38-40; moduledoc lines 18-24 list all four reason strings. |
| `lib/chimeway/trigger.ex` | @moduledoc §"Duplicate-trigger contract"; inline D-03 comments | ✓ VERIFIED | Lines 5, 294-298, 330. |
| `test/chimeway/reliability/duplicate_protection_test.exs` | 10 tests D-02/D-03/D-14; no @moduletag :skip | ✓ VERIFIED | 0 `@moduletag :skip`; 10 tests pass. |
| `test/chimeway/reliability/attempt_history_test.exs` | Ordinality + taxonomy + W3 telemetry + concurrent W8 lock race | ✓ VERIFIED | 0 `@moduletag :skip`; "10 concurrent W8 lock acquirers" test exercises lock directly; BL-01 probe-key regression test; W3 telemetry test passes with `Map.merge(meta, extra)` fix in telemetry.ex. |
| `test/chimeway/reliability/retry_exhaustion_test.exs` | perform_job/3 attempt: 1 → {:error,_}; attempt: 5 → :ok retries_exhausted; drain_queue B5 | ✓ VERIFIED | 0 `@moduletag :skip`; all tests pass. |
| `test/chimeway/reliability/terminal_convergence_test.exs` | All 6 D-12 paths assert membership in Deliveries.terminal_states() | ✓ VERIFIED | 0 `@moduletag :skip`; 6 tests pass. |
| `test/chimeway/deliveries_test.exs` | describe "exhaust_delivery/1" with happy + invalid-from + general-path-rejection | ✓ VERIFIED | Describe at line 177 covers 4 cases. |
| `test/chimeway/dispatch/sync_test.exs` | Permanent → :cancelled/permanent_failure; bounced → :cancelled/bounced; temporary asserts error_class | ✓ VERIFIED | Plans 14-04 Task 4 edits committed and green. |
| `test/chimeway/dispatch/oban_worker_test.exs` | D-13 rewrite; BL-02 regression tests (Branch A + Branch B) | ✓ VERIFIED | D-13 rewrite (Plan 14-05 Task 2) green; BL-02 regression describe with `UnexpectedAdapter`, Branch A (converges) and Branch B (assert_raise + attempt-row-persisted check) all pass. |
| `test/chimeway/traces_test.exs` | REL-02 D-07 describe; WR-05 tie-break test; WR-06 four cancelled-reason tests | ✓ VERIFIED | Lines 316-400 (REL-02 D-07); lines 403-551 (WR-05/WR-06 describe). All pass. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `Executor.run_delivery/1` | `Deliveries.record_attempt/2` | `Deliveries.record_attempt(dispatched, %{outcome:, error_class:, provider_response:})` | ✓ WIRED | executor.ex:39-43 — concrete call with 3 keys. |
| `record_attempt/2 :lock_delivery step` | `:next_attempt_number`, `:attempt`, `:delivery` steps via Multi changes map | `%{lock_delivery: locked}` destructured in each downstream step | ✓ WIRED | deliveries.ex:250-270 — all three downstream steps destructure `%{lock_delivery: locked}` and use `locked.id` / `locked` struct. BL-01 closed. |
| `ObanWorker.perform/1` | `Deliveries.exhaust_delivery/1` (temporary path) | called when attempt >= max_attempts after temporary failure | ✓ WIRED | oban_worker.ex:191 — in the temporary/max-attempts branch. |
| `map_outcome_to_oban_return/4` catch-all | `Deliveries.exhaust_delivery/1` (catch-all Branch A) | `attempt_n >= max and delivery.status == :failed` guard | ✓ WIRED | oban_worker.ex:212-222 — Branch A calls exhaust_delivery. BL-02 closed. |
| `Executor.classify/1` fallback | `map_outcome_to_oban_return/4` catch-all | fallback clause maps unexpected shape to recognized form | ✓ WIRED | executor.ex:59-61 — `defp classify(other)` produces `{:rejected, "unknown_classification", _}`. |
| `oban_worker.ex` + `sync.ex` | `Deliveries.terminal_states/0` | `if status in Deliveries.terminal_states() do` | ✓ WIRED | Both files call the function; 0 `@terminal_states` module attributes remain in lib/chimeway/dispatch/. |
| `Trigger.dispatch_after_trigger/4` catch-all | `:duplicate` inert path | returns input unchanged | ✓ WIRED | trigger.ex:330-332. |
| `Traces.last_attempt_summary/1` | `DeliveryAttempt.attempt_number` ordering field | `Enum.max_by(attempts, & &1.attempt_number)` | ✓ WIRED | traces.ex:154. WR-05 closed. |
| `Traces.build_timeline/4` :cancelled clause | `:cancelled` timeline entry in explain_delivery output | `if delivery.status == :cancelled and delivery.suppression_reason` | ✓ WIRED | traces.ex:198-209 `cancellation_entries` builder. WR-06 closed. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `record_attempt/2` | `attempt.attempt_number` | `:next_attempt_number` Multi step — `count(*) + 1` scoped to `locked.id` | Yes | ✓ FLOWING |
| `record_attempt/2` | `attempt.error_class` | Executor.classify/1 → Map.put → DeliveryAttempt.changeset | Yes | ✓ FLOWING |
| `cancel_with_reason/2` | `delivery.metadata` | `locked.metadata` (fresh locked row via `%{lock_delivery: locked}`) | Yes | ✓ FLOWING (BL-01 fixed) |
| `exhaust_delivery/1` | `delivery.suppression_reason = "retries_exhausted"` | direct `change/2 |> Repo.update` | Yes | ✓ FLOWING |
| `Traces.last_attempt_summary/1` | `last_attempt.attempt_number` | `Enum.max_by(attempts, & &1.attempt_number)` | Yes | ✓ FLOWING (WR-05 fixed) |
| `Traces.build_timeline/4` | `:cancelled` timeline entry | `cancellation_entries` builder when status == :cancelled and suppression_reason set | Yes | ✓ FLOWING (WR-06 fixed) |
| `Telemetry [:attempts, :record, :stop]` meta | `attempt_number`, `error_class`, `delivery_id` | extra map merged via `Map.merge(meta, extra)` in telemetry.ex:104 | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Locked row threaded through all Multi steps | `grep -c '%{lock_delivery: locked}' lib/chimeway/deliveries.ex` | at least 2 matches | ✓ PASS |
| BL-01 stale pattern absent inside record_attempt/2 | `awk 'NR>=241 && NR<=275' lib/chimeway/deliveries.ex \| grep -c 'terminal_or_failed_transition(delivery,'` | 0 | ✓ PASS |
| Silent unhandled_outcome return removed | `grep -c '{:error, {:unhandled_outcome,' lib/chimeway/dispatch/oban_worker.ex` | 0 at top-level catch-all | ✓ PASS |
| classify/1 fallback exists | `grep -n 'defp classify(other)' lib/chimeway/dispatch/executor.ex` | 1 match at line 59 | ✓ PASS |
| WR-05 ordering corrected | `grep -E 'Enum.max_by\(attempts, & &1.inserted_at' lib/chimeway/traces.ex` | 0 matches | ✓ PASS |
| WR-05 new ordering | `grep -E 'Enum.max_by\(attempts, & &1.attempt_number\)' lib/chimeway/traces.ex` | 1 match | ✓ PASS |
| WR-06 cancellation_entries present | `grep -c 'cancellation_entries' lib/chimeway/traces.ex` | at least 2 | ✓ PASS |
| WR-07 stale text removed | `grep -E 'suppression_reason — reason atom string when status is :suppressed, else nil' lib/chimeway/traces/explanation.ex` | 0 matches | ✓ PASS |
| @moduletag :skip absent from all 4 reliability files | `grep -c '@moduletag :skip' test/chimeway/reliability/*.exs` | 0 each | ✓ PASS |
| WR-01 broken concurrent pattern gone | `grep -c 'with {:ok, dispatched} <- Deliveries.transition_status(current, :dispatched)' test/chimeway/reliability/attempt_history_test.exs` | 0 | ✓ PASS |
| terminal_states is single source of truth | `grep -rn '@terminal_states' lib/chimeway/dispatch/ \| wc -l` | 0 | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| REL-01 | 14-01, 14-06, 14-09, 14-10, 14-11 | Prevents duplicate events, notifications, deliveries on retry | ✓ SATISFIED | `duplicate_protection_test.exs` 10 tests; D-03 documented in trigger.ex. |
| REL-02 | 14-01, 14-02, 14-04, 14-05, 14-07, 14-09, 14-10, 14-11 | Attempt records preserve retry history, backoff, terminal failure | ✓ SATISFIED | `attempt_history_test.exs` including direct W8 lock race + BL-01 regression; `retry_exhaustion_test.exs`; telemetry stop meta verified. |
| REL-03 | 14-01, 14-03, 14-04, 14-05, 14-07, 14-10, 14-11 | Every delivery resolves to a durable final state | ✓ SATISFIED | `terminal_convergence_test.exs` all 6 D-12 paths; BL-02 fixed with two-branch catch-all; WR-06 cancellation timeline entries; WR-07 moduledoc corrected. |

All three Phase 14 requirement IDs (REL-01, REL-02, REL-03) satisfied without caveats.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `priv/repo/migrations/20260426150000_add_attempt_history_columns.exs` | 35 | B-tree index on `error_class` with at most 5 distinct values | ℹ️ Info | Low-cardinality index; advisory. No functional impact. (WR-04 — carried from initial verification, not a blocker.) |
| `lib/chimeway/deliveries.ex` | record_attempt @spec | `@spec` does not declare `:lock_delivery` failure case | ℹ️ Info | `{:error, :lock_delivery, :delivery_not_found, _}` bubbles up undocumented. Advisory. (WR-08.) |
| `lib/chimeway/delivery_attempt.ex` | 63-69 | `validate_attempt_number_positive/1` nil clause is now dead (validate_required runs first with attempt_number required) | ℹ️ Info | Dead defensive clause; no functional issue. (WR-09.) |
| `lib/chimeway/trigger.ex` | 267-290 | `[:deliveries, :plan]` Telemetry span fires on duplicate-trigger path | ⚠️ Warning | Inflates histograms. Advisory; not a reliability/convergence issue. (WR-03.) |

No BLOCKERs remain.

### Human Verification Required

None. All findings are codebase-observable through grep and test-suite assertions; none require visual or production-environment confirmation.

### Gaps Summary

All three gap clusters from the initial verification are closed:

1. **BL-01 (stale-struct in record_attempt/2)** — Closed by Plan 14-09 Task 1. The locked row from `:lock_delivery` is now threaded through all three downstream Multi steps. The W8 row lock genuinely defends concurrent metadata writes.

2. **WR-01 (concurrent test did not exercise record_attempt concurrency)** — Closed by Plan 14-09 Task 2. New "10 concurrent W8 lock acquirers" test directly exercises the (SELECT FOR UPDATE + count + insert) primitive. The BL-01 probe-key regression test verifies the metadata preservation invariant.

3. **BL-02 (catch-all bypassed exhaust_delivery on final attempt)** — Closed by Plan 14-10 Task 1. The `map_outcome_to_oban_return/4` catch-all now uses a two-branch cond policy (Branch A: converge via `exhaust_delivery/1` when possible; Branch B: raise `UnhandledOutcomeError` for genuinely unexpected states). The `classify/1` fallback makes the catch-all reachable and tested.

4. **WR-05/06/07 (trace surface drift)** — Closed by Plan 14-11. `last_attempt_summary` orders by canonical `attempt_number`. `build_timeline/4` emits a `:cancelled` entry for the three new reason strings. `Explanation` moduledoc is accurate about the `:cancelled` reason contract.

The phase goal — "Make delivery retries durable, de-duplicated, and convergent — every delivery reaches a final state, attempt history is preserved, and duplicate triggers are inert" — is fully achieved.

---

_Verified: 2026-04-26T23:00:00Z_
_Verifier: Claude (gsd-verifier)_

---
phase: 14-delivery-reliability-hardening
verified: 2026-04-26T17:00:00Z
status: gaps_found
score: 7/10 must-haves verified
overrides_applied: 0
gaps:
  - truth: "Concurrent record_attempt/2 callers do not race attempt_number or clobber metadata"
    status: partial
    reason: "BL-01 — record_attempt/2 Multi steps acquire :lock_delivery row lock but downstream :next_attempt_number, :attempt insert, and :delivery transition all use closure-captured `delivery` parameter, NOT the locked row from the changes map. This means: (a) `cancel_with_reason/2` and `terminal_or_failed_transition/3` build new metadata from the stale `delivery.metadata`, silently dropping any concurrent metadata writes (e.g., correlation_id from a concurrent suppress_delivery/3 callsite) made between caller's read and lock acquisition. (b) WR-01 — the only concurrent test (attempt_history_test.exs:184-232) does not actually exercise concurrent record_attempt/2 — `transition_status(_, :dispatched)` is the de facto critical section, so 4 of 5 tasks fail at the transition gate and never reach record_attempt/2. The W8 row lock contract is documented but not exercised by any test."
    artifacts:
      - path: "lib/chimeway/deliveries.ex"
        issue: "Lines 250-266 — :next_attempt_number step uses `^delivery.id` (closure), :attempt step builds changeset from `safe_attrs` (closure-derived), :delivery step calls `terminal_or_failed_transition(delivery, ...)` with the stale closure-captured struct. Should read `%{lock_delivery: locked}` and pipe `locked` through every subsequent step."
      - path: "test/chimeway/reliability/attempt_history_test.exs"
        issue: "Lines 184-232 — concurrent describe seeds delivery in :pending and serializes via transition_status before reaching record_attempt; does not exercise the W8 row lock under contention. Recommended: seed delivery already in :dispatched and race only on record_attempt/2 (or document the test exercises transition_status serialization, not the lock)."
    missing:
      - "Read locked row from Multi changes map and pipe through :next_attempt_number, :attempt, and :delivery steps so writes operate on the freshly-locked snapshot."
      - "Add a regression test that interleaves a metadata writer (suppress_delivery/3 or transition_status to a metadata-bearing state) with record_attempt/2 and asserts the interleaving writer's metadata survives."
      - "Either rewrite the concurrent attempt_number test to seed :dispatched and bypass transition_status serialization, or document that the test exercises transition_status (the secondary serialization layer) rather than the W8 lock."

  - truth: "Every delivery converges to a durable, explainable final state in all anticipated and defensive paths"
    status: partial
    reason: "BL-02 — `map_outcome_to_oban_return/4` catch-all (oban_worker.ex:160-162) returns `{:error, {:unhandled_outcome, ...}}` without consulting `attempt_n` or `max_attempts`. On the final attempt with an unexpected (outcome, error_class, status) tuple, the worker returns `{:error, _}` and Oban discards/retries the job, but `exhaust_delivery/1` is never invoked. The delivery row is left non-terminal. In current code this is unreachable because `Executor.classify/1` has no fallback (would crash), but the catch-all itself violates the REL-03 D-12 invariant by silently bypassing exhaustion. WR-06 — `Traces.build_timeline/4` emits a `:suppressed` timeline entry only when status == :suppressed; a delivery in :cancelled with suppression_reason in {\"retries_exhausted\", \"permanent_failure\", \"bounced\"} carries no `:cancelled` timeline entry, so operators using explain_delivery/1 cannot answer 'why was this cancelled and when?' from the timeline alone."
    artifacts:
      - path: "lib/chimeway/dispatch/oban_worker.ex"
        issue: "Lines 158-162 — defensive catch-all violates REL-03 D-12 D-12 invariant. Should route the catch-all through exhaust_delivery/1 when attempt_n >= max_attempts and delivery.status not in terminal_states/0, OR convert to a hard crash so unexpected outcomes are loud."
      - path: "lib/chimeway/traces.ex"
        issue: "Lines 176-193 — suppression_entries builder only emits an entry for status == :suppressed; cancelled deliveries with retries_exhausted/permanent_failure/bounced reasons get no timeline entry naming the cancellation cause or its timestamp. Operators must read suppression_reason field separately and infer cancellation timestamp from delivery.updated_at."
    missing:
      - "Either add explicit clauses to `map_outcome_to_oban_return/4` for every (outcome, error_class, status) combination and reduce the catch-all to a Logger.error + raise, OR force convergence in the catch-all when attempt_n >= max_attempts."
      - "Emit a `:cancelled` timeline entry parallel to `:suppressed` in `Traces.build_timeline/4` so cancelled deliveries (retries_exhausted/permanent_failure/bounced) have a self-explanatory timeline."

  - truth: "Trace explanation surfaces are accurate and consistent with the durable final state"
    status: partial
    reason: "WR-05 — `last_attempt_summary/1` orders attempts by `inserted_at` (microsecond precision) instead of `attempt_number`. After REL-02 made attempt_number contiguous and 1-indexed, attempt_number is the authoritative ordering field. Two attempts with truncated identical inserted_at would resolve non-deterministically via Enum.max_by. WR-07 — `Explanation.t` typespec doc states `suppression_reason` is set 'when status is :suppressed, else nil', but Phase 14 introduced three `:cancelled` reasons (retries_exhausted, permanent_failure, bounced). Library consumers who pattern-match per the docstring will miss the :cancelled case."
    artifacts:
      - path: "lib/chimeway/traces.ex"
        issue: "Line 151 — `last = Enum.max_by(attempts, & &1.inserted_at, DateTime)` should be `Enum.max_by(attempts, & &1.attempt_number)` now that attempt_number is the canonical ordinal."
      - path: "lib/chimeway/traces/explanation.ex"
        issue: "Line 18 docstring — `suppression_reason — reason atom string when status is :suppressed, else nil` is stale; Phase 14 makes :cancelled deliveries also carry a reason."
    missing:
      - "Order attempts by `attempt_number` (the canonical 1-indexed ordinal) in `last_attempt_summary/1`."
      - "Update `Explanation` moduledoc to list the four :suppressed and :cancelled reason strings (channel_disabled, retries_exhausted, permanent_failure, bounced)."

deferred: []

human_verification: []

---

# Phase 14: Delivery Reliability Hardening Verification Report

**Phase Goal:** Make delivery retries and duplicate protection safe under real-world concurrency and failure.
**Verified:** 2026-04-26T17:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Executive Summary

Phase 14 lands real reliability hardening: a `SELECT … FOR UPDATE` row lock in `record_attempt/2`, single-source-of-truth `terminal_states/0`, named-helper terminal writes (`exhaust_delivery/1`, `cancel_with_reason/2`), in-band Oban exhaustion, sync/Oban convergence parity, and 31 reliability contract tests that all pass under `--seed 0`. The phase goal — "make delivery retries and duplicate protection safe under real-world concurrency and failure" — is **substantially achieved** but **not fully achieved** because of three concurrency- and convergence-edge findings that the code review surfaced and that this verifier confirmed in the actual codebase.

REL-01 (duplicate protection) is fully verified end-to-end. REL-02 (attempt history) is verified for the 1-indexed contiguous-attempt-number contract under serial execution and for telemetry/error_class taxonomy, but the W8 row-lock claim — that concurrent `record_attempt/2` callers cannot tie or clobber each other — is partially undermined by BL-01 (closure-captured stale struct) and not actually exercised by the concurrent test (WR-01). REL-03 (durable terminal convergence) is verified for the documented (succeeded, retries_exhausted, permanent_failure, bounced, suppressed, manual-cancelled) paths but BL-02 leaves a non-terminal exit on an unexpected-shape catch-all path.

The full `mix test` suite (236 tests) passes with 0 failures on current HEAD (relies on uncommitted Phase 10-02 telemetry.span/3 enrichment in the main worktree per the prompt's caveat). `mix compile --warnings-as-errors --force` is green. None of these passing tests cover the BL-01 stale-struct race or the BL-02 unhandled-outcome final-attempt path.

## Goal Achievement

### Observable Truths

| #  | Truth                                                                                                                                                          | Status     | Evidence |
|----|----------------------------------------------------------------------------------------------------------------------------------------------------------------|------------|----------|
| 1  | Retry paths do not create duplicate events, notifications, or deliveries (ROADMAP SC-1 / REL-01)                                                                | ✓ VERIFIED | `test/chimeway/reliability/duplicate_protection_test.exs` covers D-02a (serial), D-02b (plan re-entry), D-02c (sync + Oban terminal short-circuit), D-02d (Phase 12 atomicity through real Oban.dispatch/2 seam), D-03 (inert-on-duplicate for both dispatchers), D-14a/b/c (10× concurrent each with Sandbox.allow). 9 tests pass; `lib/chimeway/trigger.ex` documents the D-03 contract via @moduledoc + 2 inline comments at lines 5, 294, 298, 330. |
| 2  | Delivery attempts preserve backoff and retry history (ROADMAP SC-2 / REL-02)                                                                                    | ✓ VERIFIED | `chimeway_delivery_attempts.attempt_number :integer` + `error_class :string` columns added by `priv/repo/migrations/20260426150000_add_attempt_history_columns.exs` with `ROW_NUMBER()` backfill. `DeliveryAttempt.@required_fields ~w(delivery_id outcome attempt_number)a`; `error_classes/0` returns `["temporary","permanent","bounced"]`. `attempt_history_test.exs` proves 1-indexed contiguity (serial), error_class taxonomy across 4 outcomes, telemetry stop metadata carries attempt_number + error_class. `retry_exhaustion_test.exs` proves all 5 attempts persist with attempt_number 1..5 and error_class "temporary" through Oban's perform_job + drain_queue. |
| 3  | Every delivery reaches a durable, explainable final state (ROADMAP SC-3 / REL-03)                                                                               | ✓ VERIFIED | `terminal_convergence_test.exs` verifies all 6 paths (succeeded, retries_exhausted, permanent_failure, bounced, suppressed, manual cancelled) end with `delivery.status in Deliveries.terminal_states()`. `Deliveries.exhaust_delivery/1` (deliveries.ex:177) is the sole entry point for `failed → :cancelled`; `@allowed_transitions[:failed]` (deliveries.ex:32) stays `[:dispatched]` so general-path `transition_status(failed, :cancelled)` is rejected. `deliveries_test.exs` `describe "exhaust_delivery/1"` covers happy-path, two invalid-from-status cases, and the general-path D-10 guard rejection. |
| 4  | Retry contract: temporary → {:error, _} on attempt < max; → exhaust_delivery + :ok on attempt == max; permanent/bounced → :ok (record_attempt converged); succeeded → :ok | ✓ VERIFIED | `oban_worker.ex:121-156` map_outcome_to_oban_return/4 has the four documented clauses. `oban_worker_test.exs` `describe "adapter error path and retry (REL-02 D-04 / D-13 rewrite)"` covers attempt-1 retry, recovered retry, and attempt-5 exhaustion. `retry_exhaustion_test.exs` covers all of the above plus drain_queue end-to-end. |
| 5  | Adapter classification preserved end-to-end: classify/1 returns 3-tuple (outcome, error_class, detail); error_class strings persist on attempts                  | ✓ VERIFIED | `executor.ex:49-52` classify/1 has 4 clauses (`{:succeeded, nil, _}`, `{:failed, "temporary", _}`, `{:rejected, "permanent", _}`, `{:bounced, "bounced", _}`). `executor.ex:39-43` run_delivery passes `error_class:` into Deliveries.record_attempt. Sync convergence parity (sync_test.exs permanent → :cancelled / "permanent_failure", bounced → :cancelled / "bounced"). |
| 6  | terminal_states/0 is a single source of truth — no duplicate hardcoded `[:succeeded, :suppressed, :cancelled]` lists in `lib/chimeway/dispatch/`                  | ✓ VERIFIED | `grep -rn '@terminal_states' lib/chimeway/dispatch/` returns 0 matches. `oban_worker.ex:69` and `sync.ex:56` both call `Deliveries.terminal_states()`. The only `@terminal_states` reference remaining is the source of truth at `deliveries.ex:16,22`. |
| 7  | Telemetry [:dispatch, :perform] start metadata gains `attempt` + `max_attempts`; [:attempts, :record, :stop] meta carries attempt_number + error_class           | ✓ VERIFIED | `oban_worker.ex:78-79` adds `attempt:` and `max_attempts:` to the start meta. `deliveries.ex:282-283` adds `attempt_number` + `error_class` to extra. `lib/chimeway/telemetry.ex:80-83` whitelist includes both new keys. attempt_history_test.exs:147-181 verifies the W3 telemetry handler test directly (relies on uncommitted span/3 enrichment in main worktree per prompt). |
| 8  | Concurrent record_attempt/2 callers do not race attempt_number or clobber concurrent metadata writes (W8 row lock)                                              | ✗ FAILED   | **BL-01:** `deliveries.ex:241-266` — `:lock_delivery` step locks the row and binds `locked` in changes; `:next_attempt_number`, `:attempt`, and `:delivery` all use the closure-captured `delivery` parameter, not `%{lock_delivery: locked}`. Concurrent `cancel_with_reason/2` builds new metadata from `delivery.metadata` (stale), silently overwriting any metadata-bearing writes interleaved between caller read and lock acquisition. **WR-01:** the concurrent test in attempt_history_test.exs:184-232 seeds delivery in `:pending` and races on `transition_status(_, :dispatched)` — `@allowed_transitions[:dispatched]` does NOT include `:dispatched`, so 4 of 5 tasks return `{:error, :invalid_transition, ...}` and never reach record_attempt/2. The "concurrent" assertion passes because the chain is serial via transition_status, NOT because the W8 lock works. The lock is documented; not exercised. |
| 9  | Every delivery converges to a terminal state in all paths (including defensive catch-alls)                                                                       | ✗ FAILED   | **BL-02:** `oban_worker.ex:158-162` defensive catch-all returns `{:error, {:unhandled_outcome, ...}}` ignoring `_attempt_n` and `_max`. On the final attempt with an unexpected (outcome, error_class, status) tuple, the worker returns `{:error, _}` and Oban gives up, but `exhaust_delivery/1` is never called — delivery is left non-terminal. In current code, `Executor.classify/1` has no fallback (would crash), so the catch-all is unreachable today, but the catch-all itself violates the REL-03 D-12 invariant. **WR-06:** `Traces.build_timeline/4` emits no timeline entry for `:cancelled` deliveries; operators using explain_delivery/1 cannot answer "why was this cancelled and when?" from the timeline alone for retries_exhausted/permanent_failure/bounced. |
| 10 | Trace explanation accurately surfaces the most recent attempt and stays consistent with the new :cancelled reason set                                            | ✗ FAILED   | **WR-05:** `traces.ex:151` orders by `inserted_at` (microsecond precision) instead of the now-canonical `attempt_number`; with truncated identical inserted_at, Enum.max_by resolves the "last" non-deterministically. **WR-07:** `Explanation.t` moduledoc (explanation.ex:18) says `suppression_reason — reason atom string when status is :suppressed, else nil`; this is stale — Phase 14 makes :cancelled carry "retries_exhausted", "permanent_failure", "bounced". |

**Score:** 7/10 truths verified. ROADMAP SC-1, SC-2, SC-3 are all surface-verified by the test suite, but truths 8–10 expose latent issues that undermine the "safe under real-world concurrency and failure" framing of the phase goal.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|---------|--------|---------|
| `priv/repo/migrations/20260426150000_add_attempt_history_columns.exs` | Additive migration with attempt_number + error_class + ROW_NUMBER backfill + error_class index | ✓ VERIFIED | All required text present; `up/down` (not `change`) for irreversible execute; index on `:error_class` (note WR-04: low-cardinality, no documented use case — advisory). |
| `lib/chimeway/delivery_attempt.ex` | Schema with attempt_number+error_class fields, error_classes/0 helper, validate_inclusion + positive integer check | ✓ VERIFIED | Lines 28, 36, 41-42, 51, 58, 63-69 — all required content present. WR-09: `nil → changeset` clause is dead defensively (`validate_required` already runs); advisory only. |
| `lib/chimeway/deliveries.ex` | exhaust_delivery/1 (2 clauses, mirrors suppress_delivery/3 idiom), record_attempt/2 with :lock_delivery + :next_attempt_number Multi steps, terminal_or_failed_transition/3 fan-out, cancel_with_reason/2 helper | ⚠️ ORPHANED  | All required text/structure present BUT BL-01 and WR-02: closure-captured `delivery` is used in :next_attempt_number, :attempt, :delivery steps and inside `terminal_or_failed_transition/3` / `cancel_with_reason/2` — should use `%{lock_delivery: locked}` from the changes map. Lock exists, lock is acquired, but downstream writers operate on stale data. |
| `lib/chimeway/dispatch/oban_worker.ex` | perform/1 with attempt+max_attempts; map_outcome_to_oban_return/4 with 4 clauses; telemetry start meta enriched with attempt+max_attempts | ⚠️ ORPHANED | All structure present BUT BL-02: catch-all clause at line 160-162 violates REL-03 D-12 D-12 on final-attempt unexpected-outcome path; ignores `_attempt_n`/`_max`. |
| `lib/chimeway/dispatch/sync.ex` | Uses Deliveries.terminal_states() in `if`-form (Pitfall 6); no @terminal_states attribute | ✓ VERIFIED | Line 25 module attribute removed; line 56 uses `if status in Deliveries.terminal_states() do` (correct guard-to-if conversion). |
| `lib/chimeway/dispatch/executor.ex` | classify/1 returns 3-tuple in all 4 cases; run_delivery/1 passes error_class into record_attempt | ✓ VERIFIED | Lines 34-43, 49-52 — all required content present. |
| `lib/chimeway/traces.ex` | last_attempt_summary surfaces attempt_number + error_class; timeline :attempt_recorded carries both | ⚠️ ORPHANED | Lines 156-157, 200-204 — surfaces are present BUT WR-05: ordering still uses inserted_at instead of attempt_number; WR-06: no `:cancelled` timeline entry for the new reason set. |
| `lib/chimeway/traces/explanation.ex` | last_attempt typespec includes attempt_number + error_class with nil unions; moduledoc updated | ⚠️ ORPHANED | Typespec correct (lines 38-40); moduledoc line 18 stale (WR-07). |
| `lib/chimeway/trigger.ex` | @moduledoc § "Duplicate-trigger contract"; inline comments at dispatch_after_trigger/4 | ✓ VERIFIED | Lines 5, 294-298, 330 — three D-03 documentation surfaces present. WR-03 (telemetry [:deliveries, :plan] span fires on duplicate) is advisory. |
| `test/chimeway/reliability/duplicate_protection_test.exs` | 10 tests across D-02/D-03/D-14; @moduletag :skip removed; failing_multi flows through real Oban.dispatch/2 | ✓ VERIFIED | 8 describes, 0 `@moduletag :skip`, all 10 tests pass; W2 contract met. |
| `test/chimeway/reliability/attempt_history_test.exs` | Ordinality + taxonomy + W3 telemetry + concurrent attempt_number describes | ⚠️ PARTIAL | All 10 tests pass and structure is right; concurrent describe (lines 184-232) does NOT actually exercise concurrent record_attempt/2 (WR-01). |
| `test/chimeway/reliability/retry_exhaustion_test.exs` | perform_job/3 attempt: 1 → {:error, _}; attempt: 5 → :ok cancelled retries_exhausted; drain_queue B5 robust assertion | ✓ VERIFIED | 3 describes, 5 tests, all pass. |
| `test/chimeway/reliability/terminal_convergence_test.exs` | All 6 D-12 paths assert `in Deliveries.terminal_states()` | ✓ VERIFIED | 6 describes, 6 tests, all pass. |
| `test/chimeway/deliveries_test.exs` | New `describe "exhaust_delivery/1"` block with happy + invalid-from + general-path-rejection tests | ✓ VERIFIED | Describe at line 177 covers all four cases (happy, pending-rejection, succeeded-rejection, dispatched-rejection, general-path-rejection). |
| `test/chimeway/dispatch/sync_test.exs` | Permanent → :cancelled / permanent_failure; bounced → :cancelled / bounced; temporary asserts error_class | ✓ VERIFIED | Plan 14-04 Task 4 sync convergence parity edits committed and green. |
| `test/chimeway/dispatch/oban_worker_test.exs` | D-13 rewrite using perform_job/3 attempt: option | ✓ VERIFIED | Plan 14-05 Task 2 rewrite committed and green. |
| `test/chimeway/traces_test.exs` | New describe asserting last_attempt + timeline detail carry attempt_number + error_class | ✓ VERIFIED | Lines 316-400 — three new tests, all pass. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `Executor.run_delivery/1` | `Deliveries.record_attempt/2` | `Deliveries.record_attempt(dispatched, %{outcome:, error_class:, provider_response:})` | ✓ WIRED | executor.ex:39-43 — concrete call with 3 keys; tested by sync_test.exs and reliability suite. |
| `Deliveries.record_attempt/2` | `DeliveryAttempt.changeset/2` | `Map.put(safe_attrs, :attempt_number, n)` | ✓ WIRED | deliveries.ex:262 — concrete call. |
| `ObanWorker.perform/1` | `Deliveries.exhaust_delivery/1` | called when attempt >= max_attempts after a temporary failure | ✓ WIRED | oban_worker.ex:148 — concrete call inside the temporary/max-attempts branch. retry_exhaustion_test.exs and terminal_convergence_test.exs cover the path. |
| `oban_worker.ex` + `sync.ex` | `Deliveries.terminal_states/0` | `if status in Deliveries.terminal_states() do` | ✓ WIRED | Both files call the function; no @terminal_states module attributes remain in lib/chimeway/dispatch/. |
| `Trigger.dispatch_after_trigger/4` (catch-all) | `:duplicate` / `:error` inert path | catch-all returns input unchanged | ✓ WIRED | trigger.ex:330-332 — `defp dispatch_after_trigger(result, _, _, _), do: result`. |
| `record_attempt/2` :lock_delivery step | `:next_attempt_number`, `:attempt`, `:delivery` steps via Multi changes map | should pass `%{lock_delivery: locked}` to downstream steps | ✗ NOT_WIRED | deliveries.ex:250 (`^delivery.id`), 261 (`safe_attrs`), 264 (`terminal_or_failed_transition(delivery, ...)`) — all use the closure-captured `delivery`, not `locked`. The `lock_delivery` step's `{:ok, locked}` return value is computed and discarded. **This is BL-01.** |
| `map_outcome_to_oban_return/4` catch-all | `Deliveries.exhaust_delivery/1` on final attempt | should call exhaust_delivery when attempt_n >= max and status non-terminal | ✗ NOT_WIRED | oban_worker.ex:160-162 — catch-all returns `{:error, {:unhandled_outcome, ...}}` and never invokes exhaust_delivery. **This is BL-02.** Currently unreachable because Executor.classify/1 has no fallback, but the violation of D-12 is on the books. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `Deliveries.record_attempt/2` | `attempt.attempt_number` | computed by `:next_attempt_number` Multi step from `count(*) + 1` against DeliveryAttempt rows | Yes — verified by ordinality test (1, 2, 3 contiguous) and retry_exhaustion (1..5 across 5 attempts) | ✓ FLOWING |
| `Deliveries.record_attempt/2` | `attempt.error_class` | passed by Executor.classify/1 from adapter return tuple → Map.put → DeliveryAttempt.changeset | Yes — verified by 4-case taxonomy test (nil/temporary/permanent/bounced) | ✓ FLOWING |
| `Deliveries.record_attempt/2` | `delivery.suppression_reason` for :cancelled | `terminal_or_failed_transition/3` → `cancel_with_reason/2` → `change(suppression_reason: reason)` | Yes for permanent/bounced — verified by sync_test.exs and terminal_convergence_test.exs | ✓ FLOWING |
| `Deliveries.exhaust_delivery/1` | `delivery.suppression_reason = "retries_exhausted"` | direct change/2 |> Repo.update | Yes — verified by retry_exhaustion_test.exs and terminal_convergence_test.exs | ✓ FLOWING |
| `Traces.last_attempt_summary/1` | `attempt_number`, `error_class` | preloaded `attempts` association → Enum.max_by(_, & &1.inserted_at) → fields | Surface flows but ordering is stale (uses inserted_at instead of attempt_number — WR-05) | ⚠️ STATIC (ordering field is correct in the read but misleading wrt the canonical ordinal) |
| `Telemetry [:attempts, :record, :stop]` meta | `attempt_number`, `error_class`, `delivery_id` | extra map merged into meta by uncommitted Phase 10-02 span/3 enrichment | Yes (with caveat: the merge depends on the uncommitted edit in lib/chimeway/telemetry.ex; the test passes only because that edit is live in the worktree) | ✓ FLOWING (with documented dependency on Phase 10-02 fix) |
| `cancel_with_reason/2` `metadata` | `delivery.metadata |> ensure_metadata_map |> Map.put("policy_checkpoint", "perform")` | uses closure-captured `delivery.metadata` (stale — see BL-01) | Stale source under concurrency; correct under serial execution | ⚠️ HOLLOW under contention (BL-01) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full test suite passes | `mix test` | 236 tests, 0 failures | ✓ PASS |
| Compile clean (warnings as errors) | `mix compile --warnings-as-errors --force` | exits 0 | ✓ PASS |
| Reliability suite passes | `mix test test/chimeway/reliability/ --include oban --include integration` | 31 tests, 0 failures | ✓ PASS |
| Reliability suite deterministic | `mix test test/chimeway/reliability/attempt_history_test.exs --include oban --seed 0` | 10 tests, 0 failures | ✓ PASS |
| `Deliveries.exhaust_delivery/1` rejects non-:failed | (asserted in deliveries_test.exs:202-216 + retry_exhaustion_test.exs) | tests pass | ✓ PASS |
| General path rejects failed → :cancelled | (asserted in deliveries_test.exs:218-225) | test passes | ✓ PASS |
| terminal_states is single source of truth | `grep -rn '@terminal_states' lib/chimeway/dispatch/ \| wc -l` | 0 | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| REL-01 | 14-01, 14-06 | Prevents duplicate events, notifications, deliveries on retry | ✓ SATISFIED | duplicate_protection_test.exs (10 tests across D-02/D-03/D-14); trigger.ex moduledoc + inline D-03 comments. |
| REL-02 | 14-01, 14-02, 14-04, 14-05, 14-07 | Attempt records preserve retry history, backoff, terminal failure | ✓ SATISFIED with caveat | attempt_history_test.exs (10), retry_exhaustion_test.exs (5), oban_worker_test.exs D-13 rewrite, traces_test.exs. Caveat: W8 row lock (concurrent attempt_number contiguity) is documented but BL-01 makes it data-integrity-incomplete and WR-01 means the contract is not actually exercised under contention. |
| REL-03 | 14-01, 14-03, 14-04, 14-05, 14-07 | Every delivery resolves to a durable final state | ✓ SATISFIED with caveat | terminal_convergence_test.exs (6 paths), exhaust_delivery/1 happy/invalid/guard tests in deliveries_test.exs. Caveat: BL-02 unhandled-outcome catch-all violates D-12; currently unreachable but defensive contract is incomplete. |

All three Phase 14 requirement IDs (REL-01, REL-02, REL-03) are accounted for and satisfied at the surface level. The two concurrency/convergence caveats above are partial-completeness gaps within the satisfied requirements, not orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/chimeway/deliveries.ex` | 250-266 | Closure-captured stale struct used after row-lock acquisition | 🛑 Blocker | BL-01 — defeats the W8 row-lock claim; metadata writes from concurrent suppress_delivery/transition_status callsites are silently clobbered. Roughly: lock is acquired but write operates on the snapshot from before the lock. |
| `lib/chimeway/dispatch/oban_worker.ex` | 158-162 | Catch-all returns `{:error, {:unhandled_outcome, ...}}` without convergence | 🛑 Blocker | BL-02 — defensive contract violates REL-03 D-12. Currently unreachable due to absent classify/1 fallback; still a paper violation. |
| `test/chimeway/reliability/attempt_history_test.exs` | 184-232 | Concurrent describe seeds :pending and races on transition_status, not record_attempt | ⚠️ Warning | WR-01 — the W8 lock contract is not actually exercised by any test. Test passes because chain is serial via transition_status. |
| `lib/chimeway/traces.ex` | 151 | Order by inserted_at instead of canonical attempt_number | ⚠️ Warning | WR-05 — non-deterministic on truncated-identical timestamps; ordering field is stale relative to REL-02 contract. |
| `lib/chimeway/traces.ex` | 176-193 | suppression_entries fires only for :suppressed; no `:cancelled` timeline entry | ⚠️ Warning | WR-06 — operators using explain_delivery/1 cannot see when/why a :cancelled (retries_exhausted/permanent_failure/bounced) delivery converged from the timeline alone. |
| `lib/chimeway/traces/explanation.ex` | 18 | Moduledoc says suppression_reason is set "when status is :suppressed, else nil" | ⚠️ Warning | WR-07 — stale; Phase 14 makes :cancelled also carry the reason. Misleads pattern-matching consumers. |
| `lib/chimeway/trigger.ex` | 267-290 | `[:deliveries, :plan]` Telemetry span fires on duplicate-trigger path despite no planning | ⚠️ Warning | WR-03 — inflates histograms/counters with no-op duplicate trigger calls. |
| `priv/repo/migrations/20260426150000_add_attempt_history_columns.exs` | 35 | B-tree index on `:error_class` with at most 4 distinct values | ⚠️ Warning | WR-04 — low-cardinality; index is dead weight without a documented operator query. Advisory; no functional impact. |
| `lib/chimeway/deliveries.ex` | 219-221 | `@spec` does not declare `:lock_delivery` failure case | ⚠️ Warning | WR-08 — `{:error, :lock_delivery, :delivery_not_found, _}` bubbles up undocumented; advisory. |
| `lib/chimeway/delivery_attempt.ex` | 63-69 | `validate_attempt_number_positive/1` accepts `nil` even though `:attempt_number` is required | ℹ️ Info | WR-09 — dead defensive clause now that `validate_required` runs first; no functional issue, but maintainer intent is muddled. |

### Human Verification Required

None. All findings are codebase-observable through grep + test-suite reading + manual code review; they do not require visual or production-environment confirmation.

### Gaps Summary

The phase delivers the right artifacts and the right test surfaces, but two BLOCKERs that the code review surfaced are real and verifiable in the codebase:

1. **BL-01 stale-struct in `record_attempt/2`** — the `:lock_delivery` Multi step exists but its result is never threaded through downstream steps. The Multi continues to operate on the closure-captured `delivery` parameter for `attempt_number` count, attempt insert, and final transition. This is a single-line conceptual mistake (replace `_changes` destructuring with `%{lock_delivery: locked}` and use `locked` everywhere) that completely defeats the W8 row-lock contract under any concurrency where another writer (suppress_delivery/3, transition_status to a metadata-bearing state) interleaves with record_attempt/2 between the caller's read and the lock acquisition.

2. **BL-02 catch-all bypasses exhaust_delivery on the final attempt** — defensive catch-all violates REL-03 D-12. Currently unreachable due to classify/1's strict pattern matching (would crash before reaching the catch-all), but the catch-all that is in the code does NOT preserve the "every delivery converges" invariant. Either route through exhaust_delivery on `attempt_n >= max_attempts` or replace the catch-all with a hard crash so unexpected combinations are loud.

3. **WR-01 concurrent test does not actually exercise concurrency** — the only test claiming to validate the W8 row lock under concurrent record_attempt/2 callers actually only exercises transition_status serialization (4/5 tasks fail at the `dispatched -> dispatched` gate). The phase ships with no test that would have caught BL-01.

4. **WR-05/06/07 trace surface drift** — reliability-related but on the explainability side. `last_attempt_summary` orders by `inserted_at` instead of the canonical `attempt_number`; the timeline emits no entry for the new `:cancelled` reasons (retries_exhausted/permanent_failure/bounced), so explain_delivery cannot self-document the cancellation event; `Explanation` moduledoc is stale on the suppression_reason contract.

These are not deferred — Phase 15 (Observability & Supportability) and Phase 16 (Integration Hardening) goals do not match BL-01/BL-02/WR-05/WR-06. The reliability and convergence claims belong inside Phase 14.

The phase goal — "Make delivery retries and duplicate protection safe under real-world concurrency and failure" — is achieved for the documented happy paths and well-formed adversarial paths. It is not achieved for (a) concurrent metadata writes interleaved with record_attempt/2 (BL-01), (b) the defensive convergence claim (BL-02), or (c) the coverage of (a) under any test (WR-01). The phase should not advance to Phase 15 until BL-01 and BL-02 are fixed and a real concurrent record_attempt test is added.

---

_Verified: 2026-04-26T17:00:00Z_
_Verifier: Claude (gsd-verifier)_

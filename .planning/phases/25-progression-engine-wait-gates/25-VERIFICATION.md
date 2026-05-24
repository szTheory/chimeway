---
phase: 25-progression-engine-wait-gates
verified: 2026-04-29T21:00:00Z
status: verified
score: 8/9 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: verified
  previous_score: 6/9
  gaps_closed:
    - "CR-01: wait_until elapsed-time advancement path — advance_after_wait/5 wires the canonical seam; regression test proves single-delivery emission and noop re-entry."
    - "WR-01: Race-suite moduledoc narrowed to in-process re-entry scope; cross-connection FOR UPDATE coverage backlogged in deferred-items.md."
    - "WR-02: temporary_failure early-fire warning added in progression_outcome.ex @moduledoc and above @progress_outcomes in notifier.ex."
  gaps_remaining:
    - "BLOCKER (CR-01 regression): advance_after_wait/5 appends reactivated_from_wait transition before resolving to_step; an :unknown_to_step failure returns {:noop,...} (not Repo.rollback) committing an orphan transition row. No regression test covers this path."
    - "WARNING (WR-05): WR-02 warning in notifier.ex is a # code comment above @progress_outcomes, not in @moduledoc — invisible in generated docs and IEx h/1."
  regressions: []
gaps:
  - truth: "Repeated worker retries or duplicate claims do not emit duplicate next-step deliveries (ROADMAP SC#3, ESC-03) — specifically: when advance_after_wait/5 encounters an unresolvable to_step, each retry must not accumulate transition rows."
    status: failed
    reason: |
      advance_after_wait/5 (lib/chimeway/workflows/progression.ex:385-437) appends the
      reactivated_from_wait transition (step 2 of the with chain, lines 386-396) BEFORE
      resolving the next_step via Workflows.fetch_step_by_key (step 3, lines 397-399).
      When fetch_step_by_key returns nil (to_step key absent from the workflow definition),
      the || short-circuit converts it to {:error, :unknown_to_step}. The else clause
      matches this with:
        {:error, :unknown_to_step} -> {:noop, run, :unknown_to_step}
      This is NOT Repo.rollback/1. Returning {:noop,...} from inside Repo.transaction/1
      commits the transaction, leaving the reactivated_from_wait row persisted while the
      run state is unchanged (still :waiting, same current_step_id, same status_context).

      Consequences:
      1. Every subsequent progress_run/2 call on the same stuck run re-enters the same
         path — run is still :waiting, still past-due, status_context still has the bad
         to_step — and appends another orphan reactivated_from_wait row. The due-step
         worker runs on every tick (e.g., every 60 seconds), accumulating 1,440 rows/day
         per stuck run, directly violating ESC-03 idempotency guarantees for transition
         rows (not just delivery rows).
      2. The audit trail (T-25-05 repudiation) is corrupted: reactivated_from_wait rows
         appear for reactivations that never completed.
      3. The CR-01 regression test covers only the happy path (valid to_step). The
         :unknown_to_step error path has no test coverage, so the defect is invisible
         to the test suite.

      The fix: move fetch_step_by_key to before any transition is appended in the with
      chain, so reads happen before writes. The REVIEW.md CR-01 finding (lines 36-91)
      provides the exact reordered with chain.
    artifacts:
      - path: "lib/chimeway/workflows/progression.ex"
        issue: "advance_after_wait/5 (lines 379-438): append_transition at step 2, fetch_step_by_key at step 3. Step 3 failure returns {:noop,...} from inside the transaction, committing the orphan reactivated_from_wait row."
      - path: "test/chimeway/orchestration/workflow_progression_test.exs"
        issue: "No test exercises the :unknown_to_step path. The CR-01 regression describe block only proves the valid-to_step happy path. REVIEW.md specifies a 5-assertion regression test for the orphan-free unknown_to_step path."
    missing:
      - "Reorder the with chain in advance_after_wait/5 so fetch_anchor_delivery and Workflows.fetch_step_by_key both succeed before any Workflows.append_transition is called. See REVIEW.md CR-01 fix sketch lines 60-91."
      - "Add a regression test that: (1) stamps a :waiting run with status_context[to_step] pointing to a non-existent step key; (2) calls progress_run/2 with now: past due_at; (3) asserts {:ok, {:noop, _, :unknown_to_step}}; (4) asserts ZERO reactivated_from_wait transitions on the run; (5) calls progress_run/2 a second time and asserts ZERO new transitions (idempotent non-accumulation proof)."
human_verification:
  - test: "Confirm WR-02 warning is visible in generated docs (HexDocs / IEx h/1 for Chimeway.Notifier)"
    expected: "Running `h Chimeway.Notifier` in IEx should surface the temporary_failure early-fire warning in the module documentation output. Currently the warning lives as a # code comment above @progress_outcomes (line 544), not in @moduledoc, so it will NOT appear."
    why_human: "Verifier cannot run IEx or mix docs in a headless grep check. The WR-05 finding in REVIEW.md identifies this: the @moduledoc of Chimeway.Notifier (lines 2-10) does not contain the warning; only the companion in Chimeway.Workflows.ProgressionOutcome (line 27) is in @moduledoc and thus generated-doc visible."
---

# Phase 25: Progression Engine & Wait Gates Verification Report (Re-verification)

**Phase Goal:** Advance workflows safely based on elapsed time and prior delivery outcome.
**Verified:** 2026-04-29T21:00:00Z
**Status:** gaps_found
**Re-verification:** Yes — after Wave 4 gap closure (plans 25-04, 25-05, 25-06)

## Re-verification Context

The original `25-VERIFICATION.md` flagged:
- **CR-01 BLOCKER** — `wait_until` elapsed-time path not wired (infinite loop in `maybe_reactivate_due/3`)
- **WR-01 PARTIAL** — race test scope overclaimed (Sandbox single-connection, not cross-connection FOR UPDATE)
- **WR-02 PARTIAL** — `temporary_failure` early-fire semantics undocumented

Wave 4 added three gap-closure plans (25-04, 25-05, 25-06) plus a subsequent code review (25-REVIEW.md). This re-verification assesses all three closures against the REVIEW.md findings to determine whether the phase goal is now achieved.

## Gap Closure Assessment

### CR-01: wait_until elapsed-time advancement — PARTIALLY CLOSED

Plan 25-04 implemented `advance_after_wait/5` in `lib/chimeway/workflows/progression.ex` and added a regression test (`describe "wait_until rule advancement after due_at elapses (CR-01 regression)"`). The regression test passes and proves the headline behavior: a past-due `wait_until` run advances to the persisted `to_step`, emits exactly one next-step delivery, and noops on re-entry.

**However**, the REVIEW.md identifies a BLOCKER in the implementation: `advance_after_wait/5` appends the `reactivated_from_wait` transition (write) at `with` step 2 before resolving `next_step` via `fetch_step_by_key` at step 3. If step 3 fails (`to_step` key absent from the workflow definition), the `else` branch returns `{:noop, run, :unknown_to_step}` — NOT `Repo.rollback/1`. This commits the orphan transition row. On every subsequent `progress_run/2` call the same bad path re-runs, accumulating one `reactivated_from_wait` row per call with no advancement. This violates ESC-03 idempotency for transition rows and corrupts the T-25-05 audit trail.

The happy-path coverage (valid `to_step`) is correct and proven. The error-path (invalid `to_step`) is broken and unexercised. Because the REVIEW.md explicitly classifies this as a BLOCKER and it directly undermines ESC-03 (ROADMAP SC#3), it remains an open gap.

### WR-01: Race-suite scope overclaim — CLOSED

Plan 25-05 replaced the `@moduledoc` of `test/chimeway/reliability/workflow_progression_race_test.exs` with a three-section doc: "What this suite proves" (in-process re-entry safety), "What this suite does NOT prove (WR-01)" (cross-connection FOR UPDATE), and "Why we did not add a non-sandboxed test here". The `deferred-items.md` backlog entry "Cross-connection FOR UPDATE proof for workflow progression engine (WR-01)" was added. All 2 existing race tests continue to pass. The scope of the concurrency claim is now honest. WR-01 is CLOSED via resolution (b).

### WR-02: temporary_failure early-fire documentation — CLOSED (with a residual WARNING)

Plan 25-06 added the early-fire warning:
- In `lib/chimeway/workflows/progression_outcome.ex` `@moduledoc` (line 27) — **visible in generated docs**
- As an inline comment above `@progress_outcomes` in `lib/chimeway/notifier.ex` (line 544) — **NOT in @moduledoc, NOT visible in generated docs or IEx `h/1`**

The REVIEW.md WR-05 finding documents this: the warning at the authoring boundary (`Chimeway.Notifier`) is a `#` code comment, not an `@moduledoc` section, so operators using HexDocs or IEx cannot discover it without reading source. This is a WARNING (not a BLOCKER): the contract itself is correct, the `ProgressionOutcome` moduledoc carries the machine-readable warning, and the fix (promote to `@moduledoc`) is non-breaking. WR-02 is closed at the contract level; WR-05 is a follow-up documentation-surface improvement.

## Goal Achievement

### Observable Truths

| #   | Truth                                                                                                                     | Status        | Evidence                                                                                                                                                                                                                                                                           |
| --- | ------------------------------------------------------------------------------------------------------------------------- | ------------- | -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1   | Workflow step configs persist explicit progression rules with one active-step source of truth (Plan 25-01).               | VERIFIED      | `lib/chimeway/notifier.ex` normalizes `progress` rules with exact-key validation, allow-list anchors/outcomes, and tagged errors. 26 tests pass.                                                                                                                                   |
| 2   | Curated workflow outcomes resolve from persisted delivery facts to a stable vocabulary or `:not_branchable_yet`.          | VERIFIED      | `lib/chimeway/workflows/progression_outcome.ex` (157 lines) implements `from_delivery/2` with explicit clauses for all six curated outcomes plus `:not_branchable_yet`. 13 unit tests pass.                                                                                       |
| 3   | Invalid progression declarations fail normalization before persistence (Plan 25-01).                                      | VERIFIED      | Contract tests cover tagged errors for invalid anchor, invalid outcome, blank `to_step`, mixed wait/outcome rule bodies, unknown rule kinds, non-positive `delay_seconds`.                                                                                                         |
| 4   | A workflow run can enter `:waiting` with a durable due timestamp anchored to prior delivery's terminal outcome (D-01).    | VERIFIED      | `enter_waiting/6` writes full `status_context` with `rule_kind`, `anchor`, `anchor_delivery_id`, `anchor_delivery_status`, `anchor_timestamp`, `due_at`, `to_step`. Asserted by `workflow_progression_test.exs` test at L#123.                                                    |
| 5   | A `wait_until` rule advances after `due_at` elapses through the canonical progression seam (ROADMAP SC#1, phase goal).    | VERIFIED      | `advance_after_wait/5` wires advancement. Regression test at L#188 drives `progress_run/2` past `due_at` and asserts: run advances to email step, exactly one next-step delivery, noop on re-entry, exactly 1 `reactivated_from_wait` transition. 37 tests pass, 0 failures.       |
| 6   | Outcome-driven progression appends explicit transition facts and emits exactly one next-step delivery via canonical seam. | VERIFIED      | `advance_run/8` appends `progressed_on_delivery_outcome` transition + evidence, updates cursor, appends `step_activated`, calls `DeliveryPlanning.plan_next_step_delivery/3`. Asserted by test at L#268 (bounced).                                                                |
| 7   | Repeated progression re-entry no-ops safely once advanced or not-branchable (in-process). (ROADMAP SC#3 in-process)       | VERIFIED      | Engine returns deterministic noop reasons for every non-actionable state. Asserted across `workflow_progression_test.exs`, worker tests, and race suite.                                                                                                                           |
| 8   | Repeated retries on an unresolvable `wait_until` rule do not accumulate orphan transition rows (ROADMAP SC#3, ESC-03).    | **FAILED**    | **BLOCKER (REVIEW.md CR-01):** `advance_after_wait/5` appends `reactivated_from_wait` (write) before resolving `next_step` (read). An `:unknown_to_step` failure returns `{:noop,...}` not `Repo.rollback/1`, committing the orphan row. Each retry accumulates another row. No test exercises this path. |
| 9   | Oban-backed due progression and non-Oban hosts share identical internal semantics (Plan 25-03 truth).                     | VERIFIED      | `WorkflowProgressionWorker.perform/1` takes only `workflow_run_id`, delegates to `Progression.progress_run/2`. `progress_due_runs/1` calls the same engine. Both seams converge. 4 worker tests pass.                                                                             |

**Score:** 8/9 truths verified, 1 failed

### Required Artifacts

| Artifact                                                       | Expected                                                          | Status   | Details                                                                                   |
| -------------------------------------------------------------- | ----------------------------------------------------------------- | -------- | ------------------------------------------------------------------------------------------|
| `lib/chimeway/notifier.ex`                                     | Workflow progress-rule normalization and validation               | VERIFIED | 768 lines; `wait_until`, `on_outcome`, `prior_delivery_terminal_at`, `workflow_resolution_failed` all present. WR-02 warning present as code comment (not @moduledoc — WR-05 warning). |
| `lib/chimeway/workflows/progression_outcome.ex`                | Pure delivery-facts-to-workflow-outcome mapper                    | VERIFIED | 157 lines; `from_delivery/2`, `:not_branchable_yet`, all six curated outcomes, WR-02 early-fire warning in `@moduledoc`. |
| `lib/chimeway/workflows/progression.ex`                        | Durable progression service for wait gates and branch evaluation  | VERIFIED (with caveat) | 554 lines; `advance_after_wait/5`, `maybe_reactivate_due/3` pattern-match, `reactivate_run/3` removed. Happy-path advancement works. Error-path ordering BLOCKER (CR-01 in REVIEW.md). |
| `lib/chimeway/workflows.ex`                                    | Workflow-run helpers                                              | VERIFIED | `lock_run`, `fetch_step_by_key`, `append_transition`, `update_run` all present.           |
| `lib/chimeway/dispatch/workflow_progression_worker.ex`         | Thin Oban worker delegating to engine                             | VERIFIED | 73 lines; `workflow_run_id`, `Chimeway.Workflows.Progression`, `def perform` present.    |
| `test/chimeway/workflows/progression_outcome_test.exs`         | Unit proof for curated vocabulary                                 | VERIFIED | 13 tests covering all six outcomes + non-branchable cases.                                |
| `test/chimeway/orchestration/workflow_progression_test.exs`    | Integration proof including CR-01 regression                      | VERIFIED (happy path only) | 5 tests pass. CR-01 regression block exists and passes for valid `to_step`. Missing test for `:unknown_to_step` orphan-transition path. |
| `test/chimeway/dispatch/workflow_progression_worker_test.exs`  | Worker-level proof for thin delegation, noop, single enqueue      | VERIFIED | 4 tests pass.                                                                             |
| `test/chimeway/reliability/workflow_progression_race_test.exs` | Concurrency regression proof with scoped moduledoc                | VERIFIED | Updated `@moduledoc` accurately documents in-process vs cross-connection scope. WR-01 backlog entry in `deferred-items.md`. 2 tests pass. |

### Key Link Verification

| From                                                   | To                                              | Via                                                         | Status  | Details                                                                                          |
| ------------------------------------------------------ | ----------------------------------------------- | ----------------------------------------------------------- | ------- | -------------------------------------------------------------------------------------------------|
| `lib/chimeway/notifier.ex`                             | `lib/chimeway/workflows/progression_outcome.ex` | shared curated outcome vocabulary                           | WIRED   | Same six outcome strings in both files; notifier allow-list matches `from_delivery/2` clauses.  |
| `lib/chimeway/deliveries.ex`                           | `lib/chimeway/workflows/progression.ex`         | convergence hook via `maybe_apply_progression/1`            | WIRED   | `record_attempt/2`, `suppress_delivery/3`, `exhaust_delivery/1` call `Progression.progress_run/2`. |
| `lib/chimeway/workflows/progression.ex`                | `lib/chimeway/delivery_planning.ex`             | `plan_next_step_delivery/3` for next-step emission          | WIRED   | `advance_run/8` and `advance_after_wait/5` both call `DeliveryPlanning.plan_next_step_delivery/3`. |
| `lib/chimeway/dispatch/workflow_progression_worker.ex` | `lib/chimeway/workflows/progression.ex`         | worker delegates to `progress_run/2` with only run id      | WIRED   | Worker `perform/1` calls `Progression.progress_run(workflow_run_id, [])`.                        |
| `advance_after_wait/5` step 2 (write) → step 3 (read) | (ordering defect)                               | `append_transition` fires before `fetch_step_by_key`        | BROKEN  | REVIEW.md CR-01: write before read; `{:noop,...}` return commits orphan row on unknown_to_step. |

### Data-Flow Trace (Level 4)

| Artifact                                        | Data Variable                              | Source                                                   | Produces Real Data                                    | Status       |
| ----------------------------------------------- | ------------------------------------------ | -------------------------------------------------------- | ----------------------------------------------------- | -------------|
| `progression.ex` `on_outcome` next-step delivery | `next_delivery` from `plan_next_step_delivery/3` | `DeliveryPlanning.plan_one_channel/5` → `Deliveries.plan_delivery/3` | YES — real Delivery row, asserted by integration test | FLOWING |
| `progression.ex` `wait_until` next-step delivery (valid `to_step`) | `next_delivery` from `advance_after_wait/5` | `DeliveryPlanning.plan_next_step_delivery/3` via `advance_after_wait/5` | YES — real Delivery row, asserted by CR-01 regression test | FLOWING |
| `progression.ex` `wait_until` next-step delivery (invalid `to_step`) | n/a — orphan transition row written | `Workflows.append_transition/2` commits, `fetch_step_by_key` fails, `{:noop,...}` returned | NO — transition committed, delivery never created, run stuck | DISCONNECTED (BLOCKER) |
| `progression.ex` transition rows                | `Workflows.append_transition/2` writes     | `WorkflowTransition.changeset/2`                         | YES — real rows persisted                             | FLOWING (except orphan path above) |

### Behavioral Spot-Checks

| Behavior                                                                  | Command                                               | Result                                                                          | Status      |
| ------------------------------------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------- | ------------|
| All 37 Phase 25 test suites pass                                          | `mix test` on all 5 Phase 25 test files               | 37 tests, 0 failures                                                            | PASS        |
| wait_until past due_at advances correctly (happy path)                    | CR-01 regression test at L#188                        | `{:ok, {:advanced, ...}}`, state `:active`, email step cursor, 1 delivery       | PASS        |
| unknown_to_step path returns noop with zero orphan transitions            | Not covered by any test                               | No test — REVIEW.md CR-01 specifies this regression at lines 94-100            | FAIL (gap)  |

### Requirements Coverage

| Requirement | Source Plan        | Description                                                                                                   | Status                 | Evidence                                                                                                                                                                                      |
| ----------- | ------------------ | ------------------------------------------------------------------------------------------------------------- | ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| WRK-02      | 25-01, 25-02, 25-03, 25-04 | Each workflow step can define explicit progression rules based on elapsed time or the prior delivery outcome. | PARTIALLY SATISFIED    | Outcome-based rules: SATISFIED end-to-end. Elapsed-time rules (wait_until): SATISFIED for valid `to_step` (happy path proven by Plan 25-04 regression test). BLOCKED for invalid `to_step` path (orphan transition accumulation). The functional capability works in practice for well-formed workflow definitions. |
| ESC-03      | 25-02, 25-03, 25-05 | Workflow progression and escalation remain idempotent and concurrency-safe under retries, duplicate claims, or repeated host calls. | PARTIALLY SATISFIED    | In-process noop idempotency: SATISFIED for delivery rows and the valid-to_step advancement path. BLOCKED for the invalid-to_step error path (`advance_after_wait/5` orphan transition per retry). Cross-connection FOR UPDATE contention: documented as not-proven by race test; WR-01 closed via scope-narrowing and backlog entry. |

No orphaned requirements: WRK-02 and ESC-03 appear in plan `requirements` fields.

### Anti-Patterns Found

| File                                          | Line     | Pattern                                                                                                                         | Severity | Impact                                                                                                  |
| --------------------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------- | -------- | --------------------------------------------------------------------------------------------------------|
| `lib/chimeway/workflows/progression.ex`       | 385-399  | `advance_after_wait/5`: `append_transition` (write) at `with` step 2 fires before `fetch_step_by_key` (read) at step 3. `{:noop,...}` return on step 3 failure commits the orphan row. | BLOCKER  | ESC-03 idempotency violation: each retry on a stuck `:unknown_to_step` run accumulates one orphan `reactivated_from_wait` row. Audit trail (T-25-05) corrupted for non-advancing waits. |
| `lib/chimeway/notifier.ex`                    | 544      | WR-02 early-fire warning is `#` code comment above `@progress_outcomes`, not in `@moduledoc`. Invisible in generated docs and `IEx.h`. | WARNING  | Operators reading HexDocs or using `h Chimeway.Notifier` in IEx cannot discover the `temporary_failure` early-fire caveat. The companion in `ProgressionOutcome` `@moduledoc` IS visible. |
| `lib/chimeway/workflows/progression.ex`       | 27-31    | Moduledoc claims both workflow run row AND active-step delivery row are `FOR UPDATE` locked. The `advance_after_wait/5` path only locks the run row; anchor delivery is read without a lock. | WARNING  | Moduledoc is inaccurate for the wait-elapse path. Acceptable for correctness (anchor delivery is already terminal), but misleads operators reasoning about lock discipline. REVIEW.md WR-02. |
| `test/chimeway/reliability/workflow_progression_race_test.exs` | 119 | Moduledoc cites `lock_active_step_delivery/3` at "lines 372-378" — stale after Wave 4 edits shifted the function to line 458. | WARNING  | Hard-coded line numbers in moduledoc rot on every subsequent edit. REVIEW.md WR-03. |
| `test/chimeway/orchestration/workflow_progression_test.exs` | 222-226 | `status_reason in ["progressed_on_delivery_outcome", "step_activated", "reactivated_from_wait"]` — over-permissive assertion admits the old CR-01 buggy value (`"reactivated_from_wait"`) as passing. | WARNING  | Weakens CR-01 regression test: a future reintroduction of the loop bug (where status_reason stays `"reactivated_from_wait"`) would still pass this assertion. REVIEW.md WR-01. |

### Human Verification Required

1. **temporary_failure warning visibility in generated docs (WR-05)**

   **Test:** Run `mix docs` or open the published HexDocs for this build; navigate to `Chimeway.Notifier` module documentation. Also run `h Chimeway.Notifier` in IEx.
   **Expected:** The warning should NOT appear in generated docs for `Chimeway.Notifier` because it is a `#` code comment, not an `@moduledoc` section. The companion warning in `Chimeway.Workflows.ProgressionOutcome` WILL appear. If the product decision is that operator-authors ONLY read source files, this is acceptable. If the decision is that generated docs must surface the caveat, the fix is to add a section to `Chimeway.Notifier`'s `@moduledoc`.
   **Why human:** Verifier cannot run IEx or `mix docs` in a headless grep check. REVIEW.md WR-05 identifies this as a WARNING but not a BLOCKER.

### Gaps Summary

Wave 4 successfully closed two of the three original gaps and made significant progress on the third:

- **WR-01 (race suite scope):** CLOSED. Moduledoc is now honest about in-process vs cross-connection scope. Deferred backlog entry added.
- **WR-02 (temporary_failure documentation):** CLOSED at the contract level. The `ProgressionOutcome` moduledoc and a code comment in `notifier.ex` both document the early-fire behavior. Residual WR-05 WARNING: the notifier.ex warning is not in `@moduledoc`, so it does not appear in generated docs. Non-blocking.
- **CR-01 (wait_until advancement):** The headline behavior IS wired and proven. `advance_after_wait/5` drives elapsed-time advancement through the canonical seam. The 37 Phase 25 tests pass, including the new CR-01 regression test.

**One new BLOCKER identified by the code review (25-REVIEW.md):**

The `advance_after_wait/5` implementation has a write-before-read ordering defect in its `with` chain. The `reactivated_from_wait` transition (a write) is appended at step 2 before `fetch_step_by_key` (a read) at step 3. If `fetch_step_by_key` returns `nil` (unknown `to_step`), the `else` clause returns `{:noop, run, :unknown_to_step}` rather than `Repo.rollback/1`, committing the orphan transition row inside the wrapping `Repo.transaction/1`. On each subsequent `progress_run/2` call the stuck run re-enters the same path and appends another orphan row. This directly violates ESC-03 (ROADMAP SC#3: "Repeated worker retries do not emit duplicate next-step deliveries") — the guarantee holds for Delivery rows but is broken for WorkflowTransition rows on this error path.

The fix is a one-operation reorder: move `fetch_step_by_key` to before `append_transition` in the `with` chain (all reads before all writes), and add a regression test for the `{:ok, {:noop, _, :unknown_to_step}}` path that asserts zero transition rows on the run both after the first call and after the second call.

**Assessment:** The phase GOAL ("Advance workflows safely based on elapsed time") is achieved for all well-formed workflow definitions (where `to_step` resolves to an existing step). The BLOCKER affects only the error-recovery path for misconfigured or migrated workflow definitions. However, because it constitutes a direct ESC-03 idempotency violation with no test coverage and a real write-before-read correctness defect in a transaction boundary, it must be resolved before the phase can be marked complete.

---

_Verified: 2026-04-29T21:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Re-verification: Yes — after Wave 4 gap closure (plans 25-04, 25-05, 25-06) and code review (25-REVIEW.md)_

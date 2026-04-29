---
phase: 25-progression-engine-wait-gates
verified: 2026-04-29T00:00:00Z
status: gaps_found
score: 6/9 must-haves verified
overrides_applied: 0
gaps:
  - truth: "Workflow steps can wait until a due time and then advance through a durable progression seam (ROADMAP SC#1, phase goal: 'elapsed time'-based advancement)."
    status: failed
    reason: |
      The wait_until rule has no advancement path. After due_at elapses,
      `maybe_reactivate_due/3` flips :waiting -> :active, then
      `do_progress_active_run/3` re-evaluates the same step's progress rules
      against the same converged delivery. `match_wait_until/2` matches again
      (the outcome is still :branchable), `enter_waiting/6` re-stamps the run
      as :waiting with the same due_at, and the next sweep loops. The
      persisted `to_step` value in `status_context` is purely informational —
      no code reads it to drive advancement.

      Behaviorally confirmed by the verifier with a spot-check that drove
      `progress_run/2` past `due_at` twice in a row:
        * 1st past-due call: result `{:ok, {:waiting, ...}}`, run state still
          `:waiting`, current_step_id unchanged, 0 email deliveries created.
          Transition log gained `reactivated_from_wait` then immediately
          another `waiting_for_step_progression`.
        * 2nd past-due call: same — run still `:waiting`, 0 email deliveries,
          another `reactivated_from_wait` + `waiting_for_step_progression`
          pair appended (7 transitions total, growing on every sweep).

      The integration test at `test/chimeway/orchestration/workflow_progression_test.exs:122`
      only asserts the initial wait entry on a not-yet-due gate. It never
      drives `now` past `due_at`, so the loop is invisible to the test
      suite. The race test's "not-yet-due waiting" scenario also only
      exercises the not-due branch.
    artifacts:
      - path: "lib/chimeway/workflows/progression.ex"
        issue: |
          `evaluate_step/5` (lines 149-175) and `match_wait_until/2` (194-206)
          can only emit `enter_waiting/6` for the wait_until path — there is
          no `advance_run/8` call reachable from `match_wait_until`. The
          persisted `to_step` value in `status_context` (line 223) is never
          read to drive advancement.
      - path: "test/chimeway/orchestration/workflow_progression_test.exs"
        issue: |
          The `wait_until` test (line 122) only asserts initial wait entry
          and a `:wait_not_due` noop on re-entry. It never drives `now` past
          the persisted `due_at`, so the missing advancement path escapes
          coverage.
    missing:
      - "Wire reactivation through to advancement: after `maybe_reactivate_due/3` succeeds, advance via the persisted `wait_until` rule's `to_step` instead of re-evaluating the step's progress rules. One option: replace the `reactivate_run/3` call with an `advance_after_wait/5` helper that reloads the anchor delivery, appends `reactivated_from_wait` once, then runs the existing `advance_run` post-cursor logic (cursor update + `step_activated` transition + `plan_next_step_delivery`)."
      - "Add a regression test that drives `Progression.progress_run(workflow_run.id, now: due_at + 1.second)` and asserts (a) the run advances to the wait's `to_step`, (b) exactly one next-step delivery is created, (c) repeated past-due calls return a noop without emitting a second next-step delivery."
  - truth: "Repeated worker retries or duplicate claims do not emit duplicate next-step deliveries (ROADMAP SC#3, ESC-03), verified across separate database connections."
    status: partial
    reason: |
      The race test (`test/chimeway/reliability/workflow_progression_race_test.exs`)
      uses `Task.async_stream` with `Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())`
      to fan out 10 progression calls. In SQL Sandbox manual mode every
      `allow`-ed process shares the same checked-out database connection, so
      Postgres `FOR UPDATE` is non-blocking inside that single connection.
      The 10 tasks therefore exercise the engine's in-process noop
      short-circuit logic (which is correct), but they do NOT prove that
      two production processes hitting the same `workflow_run_id` over
      separate connections collapse to one winner via row-level locking.
      The engine's `FOR UPDATE` discipline is correct in code, but the
      claimed concurrency proof is weaker than advertised.
    artifacts:
      - path: "test/chimeway/reliability/workflow_progression_race_test.exs"
        issue: "Lines 148-261 use the SQL Sandbox shared connection, so the assertions verify in-process re-entry safety rather than DB-level lock contention."
    missing:
      - "Either (a) add a separate test that uses `Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)` (or a non-sandboxed test mode) to exercise true `FOR UPDATE` contention across separate connections, or (b) update the moduledoc to clarify that this suite verifies in-process re-entry safety only and add an explicit gap note for cross-connection coverage."
  - truth: "Progression rules can branch based on prior delivery outcome without surprising side effects (ROADMAP SC#2)."
    status: partial
    reason: |
      `temporary_failure` is treated as branchable from `delivery.status == :failed`,
      which is the explicit non-terminal state Oban uses while a delivery is
      still being retried (`@allowed_transitions` permits `failed: [:dispatched]`).
      A notifier authoring `on_outcome temporary_failure -> escalate_to_email`
      will fire `escalate_to_email` on the FIRST transient failure (before
      any retry has been attempted), even though the original delivery may
      succeed on its second Oban attempt. The host then has both a successful
      primary delivery and an escalation delivery for the same notification —
      the duplicate-side-effect outcome the workflow exists to prevent. The
      25-02 plan calls this out as intentional, so this is partly a contract
      decision; the gap is that the contract obscures the operational
      consequence and there is no documentation warning.
    artifacts:
      - path: "lib/chimeway/workflows/progression_outcome.ex"
        issue: "Lines 75-77 map `%Delivery{status: :failed}` to `{:branchable, :temporary_failure, ...}` even though `:failed` is non-terminal."
      - path: "lib/chimeway/notifier.ex"
        issue: "`@progress_outcomes` (line 543) accepts `temporary_failure` without any moduledoc warning that it fires before retry exhaustion."
    missing:
      - "Either (a) remove `temporary_failure` from `@progress_outcomes` and from `ProgressionOutcome` so authors must explicitly opt into `retries_exhausted` for the post-retry scenario, or (b) document the early-fire behavior in both moduledocs and recommend pairing with idempotency keys at the next step."
human_verification:
  - test: "Visual confirmation that no production-relevant `wait_until` flow exists in the demo or reference notifier suite that would mask CR-01 from a quick boot test."
    expected: "No reference notifier currently relies on a wait_until elapsed-advance to demonstrate the SaaS journey; otherwise the broken loop will surface as repeated transition rows in any host that boots Phase 25 against an Oban dispatcher."
    why_human: "Verifier cannot confirm the absence of an integration host outside the test suite."
---

# Phase 25: Progression Engine & Wait Gates Verification Report

**Phase Goal:** Advance workflows safely based on elapsed time and prior delivery outcome.
**Verified:** 2026-04-29
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth                                                                                                                     | Status     | Evidence                                                                                                                                                                                                                                                                                                                                                                       |
| --- | ------------------------------------------------------------------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1   | Workflow step configs persist explicit progression rules with one active-step source of truth (Plan 25-01).               | VERIFIED   | `lib/chimeway/notifier.ex:521-685` normalizes `progress` rules with exact-key validation, allow-list anchors/outcomes, and tagged `{:workflow_resolution_failed, ...}` errors. 26 tests pass in `notifier_contract_test.exs` + `progression_outcome_test.exs`.                                                                                                                  |
| 2   | Curated workflow outcomes resolve from persisted delivery facts to a stable vocabulary or `:not_branchable_yet`.          | VERIFIED   | `lib/chimeway/workflows/progression_outcome.ex` (127 lines) implements `from_delivery/2` with explicit clauses for all six curated outcomes plus the `:not_branchable_yet` catch-all for `:pending`/`:dispatched`/`:digested` and unknown-bucket cancelled rows.                                                                                                                |
| 3   | Invalid progression declarations fail normalization before persistence (Plan 25-01).                                      | VERIFIED   | `notifier_contract_test.exs` covers tagged errors for invalid anchor, invalid outcome, blank `to_step`, mixed wait/outcome rule bodies, unknown rule kinds, and non-positive `delay_seconds`.                                                                                                                                                                                  |
| 4   | A workflow run can ENTER `:waiting` with a durable due timestamp anchored to prior delivery's terminal outcome (D-01).    | VERIFIED   | `enter_waiting/6` writes `state: :waiting`, `status_reason: "waiting_for_step_progression"`, and a `status_context` map containing `rule_kind`, `anchor`, `anchor_delivery_id`, `anchor_delivery_status`, `anchor_timestamp`, `due_at`, `to_step`. Asserted by `workflow_progression_test.exs:122-185`.                                                                         |
| 5   | **A `wait_until` rule advances after due_at elapses (ROADMAP SC#1, phase goal "elapsed time").**                          | **FAILED** | **CR-01 confirmed behaviorally.** Verifier ran a spot-check that drove `progress_run/2` past `due_at` twice. Both calls returned `{:ok, {:waiting, ...}}`, the run never advanced, 0 next-step deliveries were created, and the transition log accumulated `reactivated_from_wait` + `waiting_for_step_progression` pairs on every sweep — confirming the infinite loop.       |
| 6   | Outcome-driven progression appends explicit transition facts and emits exactly one next-step delivery via canonical seam. | VERIFIED   | `advance_run/8` appends `progressed_on_delivery_outcome` transition with curated `workflow_outcome` + raw evidence, updates the run cursor, appends a `step_activated` transition, then calls `DeliveryPlanning.plan_next_step_delivery/3`. Asserted by `workflow_progression_test.exs:187-248` (bounced advances to email, exactly one email delivery created).               |
| 7   | Repeated progression re-entry no-ops safely once advanced or not-branchable (in-process). (ROADMAP SC#3 in-process)       | VERIFIED   | The engine returns `{:noop, run, reason}` for `:run_not_active`, `:no_active_step_delivery`, `:no_progress_rules`, `:no_matching_progress_rule`, `:prior_delivery_not_converged`, `:wait_not_due`, `:unknown_to_step`, `:wait_missing_due_at`, `:invalid_due_at`. Asserted across `workflow_progression_test.exs`, `workflow_progression_worker_test.exs`, and the race suite. |
| 8   | **Concurrency-focused tests prove duplicate-safety under DB-level row locking (ROADMAP SC#4).**                           | **PARTIAL**| The race test uses `Task.async_stream` with `Sandbox.allow`, which shares one checked-out connection. `FOR UPDATE` is non-blocking inside a single connection, so the test verifies in-process re-entry safety, not cross-connection lock contention. The engine code uses `FOR UPDATE` correctly (lines 372-378 of `progression.ex`), but the claimed proof is weaker.        |
| 9   | Oban-backed due progression and non-Oban hosts share the same internal semantics (Plan 25-03 truth).                      | VERIFIED   | `WorkflowProgressionWorker.perform/1` (lines 44-59) takes only `workflow_run_id` and delegates to `Progression.progress_run/2`. `progress_due_runs/1` (lines 113-128) calls the same engine. Both seams converge on the shared engine — but inherit the wait_until loop bug.                                                                                                    |

**Score:** 6/9 truths verified, 1 failed, 2 partial

### Required Artifacts

| Artifact                                                       | Expected                                                          | Status     | Details                                                              |
| -------------------------------------------------------------- | ----------------------------------------------------------------- | ---------- | -------------------------------------------------------------------- |
| `lib/chimeway/notifier.ex`                                     | Workflow progress-rule normalization and validation               | VERIFIED   | 735 lines; contains `wait_until`, `on_outcome`, `prior_delivery_terminal_at`, `workflow_resolution_failed`. |
| `lib/chimeway/workflows/progression_outcome.ex`                | Pure delivery-facts-to-workflow-outcome mapper                    | VERIFIED   | 127 lines (≥50); contains `from_delivery/2`, `:not_branchable_yet`, all six curated outcomes. |
| `lib/chimeway/workflows/progression.ex`                        | Durable progression service for wait gates and branch evaluation  | EXISTS — but logic GAP | 467 lines (≥140); all required strings present (`FOR UPDATE`, `waiting_for_step_progression`, `progressed_on_delivery_outcome`, `anchor_delivery_id`, `due_at`, `progress_run`, `progress_due_runs`); BUT no advancement path for `wait_until` after reactivation. |
| `lib/chimeway/workflows.ex`                                    | Workflow-run helpers                                              | VERIFIED   | 327 lines; provides `lock_run`, `get_run!`, `get_current_step!`, `fetch_step_by_key`, `append_transition`, `update_run`. |
| `lib/chimeway/dispatch/workflow_progression_worker.ex`         | Thin Oban worker delegating to engine                             | VERIFIED   | 73 lines (≥60); contains `workflow_run_id`, `Chimeway.Workflows.Progression`, `def perform`, normalizes engine results to `:ok`.|
| `test/chimeway/workflows/progression_outcome_test.exs`         | Unit proof for curated vocabulary                                 | VERIFIED   | Exists, 13 tests covering all six outcomes + non-branchable cases.   |
| `test/chimeway/orchestration/workflow_progression_test.exs`    | Integration proof for due waiting, outcome branching, noops       | EXISTS — coverage GAP | 4 tests; misses past-due elapsed-wait advancement (CR-01).             |
| `test/chimeway/dispatch/workflow_progression_worker_test.exs`  | Worker-level proof for thin delegation, noop, single enqueue      | VERIFIED   | 4 tests pass.                                                        |
| `test/chimeway/reliability/workflow_progression_race_test.exs` | Concurrency regression proof                                      | PARTIAL    | Tests pass but exercise in-process re-entry, not multi-connection `FOR UPDATE` contention (WR-01). |

### Key Link Verification

| From                                                | To                                          | Via                                                                                  | Status   | Details                                                                                                    |
| --------------------------------------------------- | ------------------------------------------- | ------------------------------------------------------------------------------------ | -------- | ---------------------------------------------------------------------------------------------------------- |
| `lib/chimeway/notifier.ex`                          | `lib/chimeway/workflows/progression_outcome.ex` | shared curated outcome vocabulary                                                | WIRED    | Both files use the same six outcome strings; allow-list in notifier matches `from_delivery/2` clauses.     |
| `lib/chimeway/deliveries.ex`                        | `lib/chimeway/workflows/progression.ex`     | `record_attempt/2`, `suppress_delivery/3`, `exhaust_delivery/1` invoke progression seam | WIRED | `maybe_apply_progression/1` and `maybe_progress_workflow/1` (lines 1144-1161) call `Chimeway.Workflows.Progression.progress_run/2`. |
| `lib/chimeway/workflows/progression.ex`             | `lib/chimeway/delivery_planning.ex`         | next-step emission via `plan_next_step_delivery/3`                                   | WIRED    | Line 299-305: `advance_run/8` calls `DeliveryPlanning.plan_next_step_delivery(notification, next_step.channel, ...)`.|
| `lib/chimeway/dispatch/workflow_progression_worker.ex` | `lib/chimeway/workflows/progression.ex` | worker args carry only `workflow_run_id`, delegate to `progress_run/2`               | WIRED    | Line 44-59: `def perform(%Oban.Job{args: %{"workflow_run_id" => workflow_run_id}}) ... |> Progression.progress_run([])`.|

### Data-Flow Trace (Level 4)

| Artifact                                       | Data Variable                            | Source                                                  | Produces Real Data                                              | Status                            |
| ---------------------------------------------- | ---------------------------------------- | ------------------------------------------------------- | --------------------------------------------------------------- | --------------------------------- |
| `progression.ex` next-step delivery emission   | `next_delivery` from `plan_next_step_delivery/3` | Canonical `DeliveryPlanning.plan_one_channel/5` path | YES (real Delivery row inserted, asserted by integration tests) | FLOWING for `on_outcome` branch   |
| `progression.ex` `wait_until` next-step emission | n/a — no advancement path             | (none)                                                  | NO — wait_until rule never produces a next-step delivery        | DISCONNECTED (CR-01)              |
| `progression.ex` transition rows               | `Workflows.append_transition/2` writes   | `WorkflowTransition.changeset/2`                        | YES — real rows persisted                                       | FLOWING                           |
| `progression.ex` `due_at` from `status_context`| `parse_due_at/1` reads `status_context["due_at"]`| `enter_waiting/6` persists ISO-8601 string         | YES — value persisted and parseable                             | FLOWING (but consumer noops loop) |

### Behavioral Spot-Checks

| Behavior                                                                  | Command                                                                                              | Result                                                                                                                                                          | Status                |
| ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| All Phase 25 test suites pass                                             | `mix test test/chimeway/orchestration/workflow_progression_test.exs test/chimeway/dispatch/workflow_progression_worker_test.exs test/chimeway/reliability/workflow_progression_race_test.exs test/chimeway/workflows/progression_outcome_test.exs test/chimeway/notifier_contract_test.exs` | 36 tests, 0 failures                                                                                                                                            | PASS                  |
| Wait_until past `due_at` actually advances workflow run (verifier-authored spot-check, then removed) | Trigger workflow with `wait_until 1800s -> email`; converge in_app to `:succeeded`; call `Progression.progress_run/2` with `now: due_at + 1.second` (twice) | First call: `{:ok, {:waiting, ...}}`, run state still `:waiting`, current_step_id unchanged, 0 email deliveries. Second call: same; 7 transitions accumulated showing `reactivated_from_wait` + `waiting_for_step_progression` looping. | **FAIL — CR-01 confirmed** |

### Requirements Coverage

| Requirement | Source Plan        | Description                                                                                            | Status            | Evidence                                                                                                                                                                                                                                                                                                                            |
| ----------- | ------------------ | ------------------------------------------------------------------------------------------------------ | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| WRK-02      | 25-01, 25-02, 25-03 | "Each workflow step can define explicit progression rules based on elapsed time or the prior delivery outcome." | **PARTIALLY SATISFIED** | Outcome-based rules: SATISFIED (on_outcome branch end-to-end). **Elapsed-time rules: BLOCKED — wait_until rules can be DEFINED and persisted, but they do not advance after the elapsed time, so the requirement is not functionally met. The author can declare "wait 30 minutes then escalate" but the runtime never escalates.** |
| ESC-03      | 25-02, 25-03       | "Workflow progression and escalation remain idempotent and concurrency-safe under retries, duplicate claims, or repeated host calls." | **PARTIALLY SATISFIED** | Idempotency in-process: SATISFIED via engine noop short-circuits and deterministic worker normalization. Cross-connection `FOR UPDATE` contention: NOT PROVEN by the race test (WR-01). The engine code uses `FOR UPDATE` correctly, but the claim of "concurrency-safe under retries" leans on a sandbox single-connection test.   |

No orphaned requirements: every requirement ID in REQUIREMENTS.md mapped to Phase 25 (WRK-02, ESC-03) appears in at least one plan's `requirements:` field.

### Anti-Patterns Found

| File                                          | Line     | Pattern                                                                                                                                                                                                                                                                                                                       | Severity | Impact                                                                                                                                                                                                                                                                                                                              |
| --------------------------------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/chimeway/workflows/progression.ex`       | 149-175, 321-367 | Missing advancement code path for `wait_until` rules — `match_wait_until/2` only emits `enter_waiting/6`, never `advance_run/8`; reactivation re-evaluates the same rules and re-enters the same wait state. | BLOCKER  | Phase 25 headline goal ("Advance workflows safely based on elapsed time") not achieved. Production hosts using `wait_until` rules will accumulate `reactivated_from_wait` / `waiting_for_step_progression` transition pairs forever and never emit the next-step delivery the rule promised.                                       |
| `lib/chimeway/workflows/progression.ex`       | 250-256  | `advance_run` queries `notification.workflow_definition_id` instead of `run.workflow_definition_id`. The notification is loaded fresh outside the run's lock; the locked, authoritative source is the run row.                                                                                                                | WARNING  | Couples progression to a denormalized field on `chimeway_notifications` that is not under the engine's `FOR UPDATE` discipline. If the field is ever nil or stale, `fetch_step_by_key/2` crashes on its `is_binary` guard. (Review WR-03.)                                                                                          |
| `lib/chimeway/workflows/progression.ex`       | 149-175  | `evaluate_step` checks `match_on_outcome` before `match_wait_until`. Precedence is undocumented in the moduledoc and not asserted as a contract — a future maintainer could reorder and silently drop wait gates.                                                                                                              | WARNING  | Precedence is correct for the test fixtures, but a normalization-time validation that rejects mixing `wait_until` with `on_outcome` rules whose `to_step` differs would prevent silent surprises. (Review WR-04.)                                                                                                                  |
| `lib/chimeway/notifier.ex`                    | 550-685  | `to_step` references are not validated against the workflow's actual step keys at declaration time. A typo persists silently, then noops at runtime as `:unknown_to_step`. No log, telemetry, or transition row exposes the misconfiguration.                                                                                  | WARNING  | Misconfigured workflows wedge silently. Compounds with CR-01: even a fixed `wait_until` advancement path would noop forever on a typoed `to_step`. (Review WR-05.)                                                                                                                                                                  |
| `lib/chimeway/workflows/progression.ex`       | 395-400  | `anchor_timestamp_for/1` silently falls back to `DateTime.utc_now/0` if `delivery.updated_at` is not a `DateTime`. Schema is non-nullable `:utc_datetime_usec`, so this branch indicates a real bug worth surfacing.                                                                                                            | INFO     | Audit trail integrity loss: persisted `anchor_timestamp` would not match the `anchor_delivery_id`'s actual `updated_at`, breaking D-13 explainability. (Review IN-01.)                                                                                                                                                              |
| `lib/chimeway/deliveries.ex`                  | 1153-1159 | `maybe_progress_workflow/1` discards engine errors as a bare `:error` atom with no telemetry, log, or propagation.                                                                                                                                                                                                              | INFO     | Operators get no visibility when progression fails after a successful terminal write. The "terminal write succeeds even if progression fails" invariant is correct, but the failure should be observable. (Review IN-02.)                                                                                                           |
| `lib/chimeway/workflows/progression.ex`       | 75-77 (`temporary_failure` mapping in `progression_outcome.ex`) | `:temporary_failure` is treated as branchable from a non-terminal `:failed` row. A notifier authoring `on_outcome temporary_failure -> escalate` will fire on the FIRST transient failure before any retry has been attempted.                                                | WARNING  | Risk of duplicate user-visible deliveries — primary delivery may still succeed on retry while escalation has already fired. (Review WR-02.)                                                                                                                                                                                         |

### Human Verification Required

1. **Confirm no production demo or reference notifier exposes the wait_until loop**

   - **Test:** Search the repo for any reference notifier, demo app, or seed data that defines a `wait_until` rule, then boot it against an Oban-backed dispatcher.
   - **Expected:** No reference notifier currently relies on a `wait_until` elapsed-advance to demonstrate the SaaS journey; otherwise the broken loop will surface as exponentially growing `chimeway_workflow_transitions` rows in any host that boots Phase 25.
   - **Why human:** Verifier cannot enumerate every host's notifier configuration outside the test suite.

### Gaps Summary

The Phase 25 progression engine establishes:

- A correct, replay-safe `progress` rule contract with curated outcomes (Plan 25-01 — solid).
- A working `on_outcome` advancement path that emits next-step deliveries through the canonical planner (Plan 25-02 — solid for outcome rules).
- A thin Oban worker that delegates to a shared engine seam (Plan 25-03 — solid as a delegation shim).

But the **headline elapsed-time advancement capability is missing**. The wait_until rule path enters `:waiting` with a durable `due_at`, reactivates correctly when due elapses, and then RE-ENTERS the same `:waiting` state instead of advancing. This is a contract-level correctness defect for the phase goal "Advance workflows safely based on elapsed time and prior delivery outcome." The verifier behaviorally confirmed this with a spot-check that exercised the past-due path twice and observed zero next-step deliveries plus a growing transition log.

Two compounding issues lower confidence in the rest of the work:

- The race test does not exercise multi-connection `FOR UPDATE` contention because `Sandbox.allow` shares one connection across the spawned tasks. The engine's locking discipline is correct, but the proof of cross-connection idempotency is not what the test claims to be.
- `temporary_failure` is treated as branchable from a non-terminal `:failed` row, so workflows authored with an `on_outcome temporary_failure` rule will fire escalations BEFORE retry exhaustion, possibly producing duplicate user-visible deliveries.

WRK-02 is partially satisfied (outcome rules work, elapsed-time rules do not advance). ESC-03 is partially satisfied (in-process idempotency proven, multi-connection idempotency unproven by the test suite). Phase 25 should not be marked complete until the wait_until advancement path lands and a regression test drives `progress_run/2` past `due_at`.

---

_Verified: 2026-04-29_
_Verifier: Claude (gsd-verifier)_

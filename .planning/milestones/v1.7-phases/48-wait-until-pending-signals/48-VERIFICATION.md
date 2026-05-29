---
phase: 48
name: wait-until-pending-signals
status: passed
score: 23/23
requirements:
  READ-01: passed
verified_at: 2026-05-29
---

# Phase 48 Verification: `wait_until` Pending Signals

**Goal:** Close READ-01 — workflow runs entering `wait_until` automatically persist canonical `pending_signals` so signal routing works without host glue.

**Status:** `passed` — all must-haves verified against codebase and automated tests.

## Requirements Traceability

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| **READ-01** | Workflow runs entering `wait_until` persist canonical `pending_signals` derived from progress rules (no host glue required) | **passed** | `enter_waiting/6` sets `pending_signals` from rule `cancel_signals`; progression + SignalRouterWorker integration tests pass without manual `Workflows.update_run/3` |

## ROADMAP Success Criteria

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Run entering `:waiting` via `wait_until` has `pending_signals` from progress-rule config | **passed** | `lib/chimeway/workflows/progression.ex` `enter_waiting/6` — `Map.get(rule, "cancel_signals", [])` written to `Workflows.update_run/3` |
| `SignalRouterWorker` matches injected signal without host `pending_signals` assignment | **passed** | `workflow_progression_test.exs` — `"injected signal resumes waiting run via SignalRouterWorker without host update_run glue"` |
| Journey guide no longer documents READ-01 as an engine gap | **passed** | `guides/flows/multi-step-journeys.md` — no `Engine gap today`; shipped `enter_waiting/6` behavior documented |

## Explicit Verification Checks

| Check | Status | Evidence |
|-------|--------|----------|
| `lib/chimeway/notifier.ex` has `normalize_cancel_signals/1` and `cancel_signals` in `wait_until` allowlist | **passed** | `extra_keys(rule, ~w(kind anchor delay_seconds to_step cancel_signals))`; `defp normalize_cancel_signals/1` with 3+ clauses |
| `lib/chimeway/workflows/progression.ex` `enter_waiting/6` sets `pending_signals` from rule `cancel_signals` | **passed** | Lines 268–275: `pending_signals = Map.get(rule, "cancel_signals", [])` in `update_run` attrs |
| `test/chimeway/notifier_contract_test.exs` has `cancel_signals` tests | **passed** | Describe `"wait_until cancel_signals normalization (READ-01)"` with 7 tests |
| `test/chimeway/orchestration/workflow_progression_test.exs` has READ-01 auto-population + SignalRouterWorker proof | **passed** | Describe `"wait_until auto-populates pending_signals (READ-01)"` with 3 tests including SignalRouterWorker e2e |
| `guides/flows/multi-step-journeys.md` documents `cancel_signals`, no engine gap, keeps READ-02 deferral | **passed** | 6+ `cancel_signals` mentions; `chimeway.notification.read`/`.seen`; READ-02 in Deferred section; no `Engine gap today` |
| `test/chimeway/doc_contract_test.exs` has `cancel_signals` in `@required` and `Engine gap today` in `@forbidden_strings` | **passed** | Journey guide doc contract describe block |
| Specified test suite passes | **passed** | 122 tests, 0 failures (2026-05-29) |

## Plan 48-01 Must-Haves

| Truth / Artifact / Link | Status | Evidence |
|-------------------------|--------|----------|
| `wait_until` accepts optional `cancel_signals` at normalization (D-03, D-04) | **passed** | `normalize_wait_until_rule/1` extended |
| Invalid shapes fail fast with `{:invalid_cancel_signals, _}` | **passed** | Contract tests: blank, non-list, too_many, mixed_rule_shape |
| Time-only rules omit `cancel_signals` key (D-06) | **passed** | `"omits cancel_signals key for an explicit empty list"` test |
| `lib/chimeway/notifier.ex` artifact | **passed** | `normalize_cancel_signals/1`, `@max_cancel_signals 10` |
| `test/chimeway/notifier_contract_test.exs` artifact | **passed** | READ-01 describe block |
| Allowlist key link | **passed** | `extra_keys(... cancel_signals)` |
| `normalize_cancel_signals/1` key link | **passed** | Called in `with` chain before output map |

## Plan 48-02 Must-Haves

| Truth / Artifact / Link | Status | Evidence |
|-------------------------|--------|----------|
| `enter_waiting/6` persists `pending_signals` atomically with `:waiting` (D-01) | **passed** | Single `Workflows.update_run/3` transaction |
| Time-only waits persist `pending_signals == []` (D-03, D-06) | **passed** | Time-only regression test + D-01 test assertion |
| SignalRouterWorker works without host glue (D-08) | **passed** | E2e test via `Signal.track/4` + `perform_job/2` |
| `route_signal/1` matching unchanged (D-02, D-07) | **passed** | No Phase 48 edits to `lib/chimeway/workflows.ex` `route_signal/1` body |
| `lib/chimeway/workflows/progression.ex` artifact | **passed** | `pending_signals:` in `enter_waiting/6` |
| `test/chimeway/orchestration/workflow_progression_test.exs` artifact | **passed** | `WorkflowProgressionWithSignals` fixture + READ-01 describe |
| `pending_signals` → `WorkflowRun` key link | **passed** | `Workflows.update_run/3` attrs map |
| SignalRouterWorker test key link | **passed** | `perform_job(SignalRouterWorker, ...)` in READ-01 describe |

## Plan 48-03 Must-Haves

| Truth / Artifact / Link | Status | Evidence |
|-------------------------|--------|----------|
| Journey guide documents optional `cancel_signals` with canonical inbox events (D-05, D-09) | **passed** | §1 example, §2 table, §7 canonical event names |
| READ-01 engine-gap callout removed | **passed** | No `Engine gap today`; no READ-01 bullet in Deferred |
| READ-02 deferral remains documented | **passed** | Deferred section retains READ-02 bullet |
| Doc contract requires `cancel_signals`, forbids gap language | **passed** | `@required` + `@forbidden_strings` updated |
| `guides/flows/multi-step-journeys.md` artifact | **passed** | Shipped behavior documented |
| `test/chimeway/doc_contract_test.exs` artifact | **passed** | Doc contract guards in place |
| Guide → DSL key link | **passed** | `cancel_signals` in example, table, and §7 prose |
| Doc contract → guide key link | **passed** | `@required` includes `cancel_signals` |

## Automated Gates

| Gate | Result |
|------|--------|
| `mix test test/chimeway/notifier_contract_test.exs test/chimeway/orchestration/workflow_progression_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors` | PASS (122 tests, 0 failures) |

## Human Verification

None required — all acceptance criteria automated.

## Notes

- READ-01 requirement checkbox in `REQUIREMENTS.md` remains unchecked at planning-doc level; functional closure is verified here. Milestone traceability update is out of scope for this verification artifact.
- Inbox signal emission (`Chimeway.mark_read/3` / `mark_seen/3`) correctly deferred to Phase 49 (READ-02).

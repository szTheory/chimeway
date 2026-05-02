---
phase: 34-feedback-contract-e2e-proof
reviewed: 2026-05-02T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs
  - test/chimeway/traces_test.exs
findings:
  critical: 0
  warning: 2
  info: 5
  total: 7
status: issues_found
---

# Phase 34: Code Review Report

**Reviewed:** 2026-05-02
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Phase 34's actual production-code surface is two test files. The bulk of the
diff is the wholly-new E2E test
(`examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs`,
364 lines, all new in commit `9a61387`); the work in `test/chimeway/traces_test.exs`
is two single-line fixture-string corrections (lines 416 and 523) changing
`"chimeway.delivery.delivered"` to `"chimeway.delivery.succeeded"` to align
synthetic fixtures with the canonical signal-name vocabulary. The diff base
includes the rest of `traces_test.exs` because it was added before
the diff window — those parts are pre-existing code, but I reviewed them in
scope as instructed.

The new E2E test correctly threads through the real Phoenix endpoint, real
plug pipeline, real `Chimeway.Webhooks.process/4`, and real
`Oban.drain_queue/1` for both queues. Both progress and stop scenarios assert
the right observable artifacts: HTTP 200, ingress row, DeliveryAttempt, Signal
event_name, WorkflowRun state transitions, signal_received/workflow_stopped
WorkflowTransition rows with `delivery_id`, and trace timeline projection
(including the `signal_event_name` enrichment via the Phase 32 D-02 join key).
The two-line drift fix in `traces_test.exs` is correct and minimal.

Findings below: zero blockers, two warnings around test robustness, and five
informational items around clarity/duplication.

## Warnings

### WR-01: `Oban.drain_queue/1` total count omits `:cancelled` and `:snoozed` states

**File:** `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs:51-54, 78-81, 141-144`
**Issue:** The "drain shape robustness" comment (line 48) claims the assertion
is robust by computing
`Map.get(result1, :success, 0) + Map.get(result1, :failure, 0) + Map.get(result1, :discard, 0)`.
Oban's documented `drain_result` type (`deps/oban/lib/oban.ex:105-111`) is
`%{cancelled: _, discard: _, failure: _, snoozed: _, success: _}`. The sum
silently ignores `:cancelled` and `:snoozed`. If a worker accidentally snoozes
(reschedules via `{:snooze, n}`) or is cancelled mid-drain in some future
config change, the assertion `total >= 1` would falsely report "expected
worker to run" failure even though a job DID run. The comment claims
robustness but the implementation only handles three of five buckets.

**Fix:** Sum across the entire result map (or use `Enum.sum(Map.values(result1))`)
so the `total >= 1` check truly proves "any job ran":

```elixir
total1 = result1 |> Map.values() |> Enum.sum()

assert total1 >= 1,
       "expected ProcessFeedbackWorker to run; got #{inspect(result1)}"
```

This is a 1-line change, matches the comment's stated intent, and is forward-
compatible if Oban adds new result keys.

### WR-02: Stop-path test silently discards SignalRouterWorker drain result

**File:** `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs:181`
**Issue:** `_ = Oban.drain_queue(queue: :chimeway_signals, with_scheduled: true)`
discards the drain result with no assertion. The narrative comment correctly
explains the expected behaviour ("`route_signal/1` finds zero matching runs
and returns `{:ok, %{}}`"), but if the SignalRouterWorker raises an exception
(e.g. a future regression where `route_signal/1` crashes on `:stopped` runs),
the test will not notice — `Oban.drain_queue` catches exceptions and records
them as `:failure`. Combined with the absence of a "no `signal_received`
transition exists" assertion, a worker crash on the stop path could pass
this test silently.

**Fix:** Either assert the worker did not record a failure, or assert the
absence of the signal_received row to bound the behaviour:

```elixir
result2 = Oban.drain_queue(queue: :chimeway_signals, with_scheduled: true)

# Worker must complete cleanly even when no waiting run matches.
assert Map.get(result2, :failure, 0) == 0,
       "SignalRouterWorker should not fail on stopped runs; got #{inspect(result2)}"

# And no signal_received transition is written for the :stopped run.
assert [] =
         Repo.all(
           from(wt in WorkflowTransition,
             where:
               wt.workflow_run_id == ^run.id and wt.reason == "signal_received"
           )
         )
```

Either form (or both) closes the silent-failure window.

## Info

### IN-01: Strict-length assertions are fragile across test extension

**File:** `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs:41, 62, 69, 133, 151, 157`
**Issue:** Multiple `assert [%X{} = x] = Repo.all(X)` and `assert length(xs) == 1`
patterns assume there is exactly one row in the sandbox. With `async: false`
and per-test sandbox checkout, this is true today, but if the fixture grows
(e.g. someone adds a second delivery to test multi-delivery progression), the
match destructure will silently bind the first row and skip checking the
second, while the `length == 1` guard fires a misleading error message.

**Fix:** Filter explicitly by the row that the assertion targets, e.g.
`Repo.all(from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id))`,
and use `[%X{} = x] = ...` only after the filter narrows scope. This makes
the assertion robust to additional rows the fixture may grow.

### IN-02: Setup mutates global Application env in `:async`-safe-only-by-coincidence test

**File:** `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs:19`
**Issue:** `Application.put_env(:demo_host, :chimeway_adapter_config, [])` is a
process-global write. The module is correctly `async: false`, and the
neighbouring `webhooks_controller_test.exs:13` uses the same line, so this
mirrors an established pattern. The risk is forward: if another test module
sets `:demo_host, :chimeway_adapter_config` to a non-empty value and runs
between these tests in a `--seed` ordering quirk, the put_env in *this*
setup re-establishes `[]` only at the start of each test in this module —
which is fine — but never restores the original on `on_exit`. A future
parallelisation refactor that sets `async: true` would silently break.

**Fix:** Capture and restore via `on_exit`, or wrap with a tag guard so a
future `async: true` change is impossible to land without revisiting the
config side effect:

```elixir
setup do
  prior = Application.get_env(:demo_host, :chimeway_adapter_config)
  Application.put_env(:demo_host, :chimeway_adapter_config, [])
  on_exit(fn -> Application.put_env(:demo_host, :chimeway_adapter_config, prior) end)
  # …
end
```

Low priority — matches the existing pattern in
`webhooks_controller_test.exs` — but worth tightening if Phase 34 gets
copy-pasted as the model for future E2E tests.

### IN-03: Drain-shape robustness pattern is duplicated three times verbatim

**File:** `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs:51-57, 78-84, 141-147`
**Issue:** The `total = Map.get(...) + Map.get(...) + Map.get(...)` +
`assert total >= 1, "..."` block is repeated three times with the same
shape, only the worker name in the message differing. This is a trivial
helper extract that would also remove the WR-01 footgun in one place
instead of three.

**Fix:** Extract a private helper:

```elixir
defp assert_drained(result, worker_label) do
  total = result |> Map.values() |> Enum.sum()

  assert total >= 1,
         "expected #{worker_label} to run; got #{inspect(result)}"
end
```

Then each call site becomes a single line:
`assert_drained(result1, "ProcessFeedbackWorker")`. Folds WR-01's fix
into the helper.

### IN-04: Progress-path test does not assert ingress reaches `:processed`

**File:** `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs:39-45`
**Issue:** The test asserts the ingress row is committed and that
`normalized_status == "delivered"`, but never asserts that the worker's
`mark_processed/1` step (`process_feedback_worker.ex:121-128`) ran. If the
worker silently fails between `record_attempt` and `mark_processed` (or
if the order ever changes), the ingress row stays in `:received` /
`:pending` state and a poll-based reprocess could double-emit the signal.
The test currently passes such a regression silently because all the
downstream observable artifacts (attempt, signal, transition) were already
written before `mark_processed` is called.

**Fix:** After `result1`'s drain, re-fetch the ingress and assert
`ingress.ingress_state == :processed` (or the equivalent atom for the
processed state per `lib/chimeway/webhooks/ingress.ex`). One line:
`assert Repo.get!(Ingress, ingress.id).ingress_state == :processed`.
Tightens coverage of the worker's three-step `with` chain.

### IN-05: Pre-existing `traces_test.exs` Helper rebinds `delivery` across `dispatched` calls — confusing

**File:** `test/chimeway/traces_test.exs:43-47, 52-56, 690-714`
**Issue:** Several helpers rebind the same variable name across the dispatched-
to-terminal chain (`{:ok, dispatched}` then ignored, then `{:ok, %{delivery: updated}}`
shadows). Inside `last_attempt reflects the most recent attempt across multiple records`
(lines 686-723), the chain `dispatched_a -> failed_a -> dispatched_b -> failed_b -> dispatched_c -> succeeded`
is harder to read than the equivalent pipeline. Not a bug, but a maintainability
smell. NOTE: this code is *pre-existing* — the diff base
(`62f86c0f456a1542816cdea1f90aa6fbdfdeab2c^`) treats the whole file as new only
because it predates the base, but the actual Phase 34 changes are limited to
lines 416 and 523. Listing here for completeness only.

**Fix:** No action required for Phase 34. If a future phase touches these
helpers, consider extracting a `dispatched_then_record/2` helper that
returns the post-attempt delivery in a single call.

---

_Reviewed: 2026-05-02_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

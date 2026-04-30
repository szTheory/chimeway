---
phase: 27-journey-traces-host-signal-api
reviewed: 2026-04-30T17:07:07Z
depth: standard
files_reviewed: 18
files_reviewed_list:
  - lib/chimeway/dispatch/signal_router_worker.ex
  - lib/chimeway/signal.ex
  - lib/chimeway/signals/signal.ex
  - lib/chimeway/trigger.ex
  - lib/chimeway/workflows.ex
  - lib/chimeway/workflows/workflow_run.ex
  - config/config.exs
  - config/dev.exs
  - config/test.exs
  - priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs
  - test/chimeway/dispatch/signal_router_worker_test.exs
  - test/chimeway/integration/trigger_explain_test.exs
  - test/chimeway/migration_contract_test.exs
  - test/chimeway/signal_test.exs
  - test/chimeway/trigger_pipeline_test.exs
  - test/chimeway/workflows/workflow_run_test.exs
  - test/chimeway/workflows_inspection_test.exs
  - test/chimeway/workflows_test.exs
findings:
  critical: 1
  warning: 2
  info: 0
  total: 3
status: issues_found
---

# Phase 27: Code Review Report

**Reviewed:** 2026-04-30T17:07:07Z
**Depth:** standard
**Files Reviewed:** 18
**Status:** issues_found

## Summary

Reviewed the effective Phase 27 implementation after plans 27-01 through 27-06, with extra attention on the gap-closure work from 27-04/05/06.

The earlier blockers called out in the prior review are fixed in the current code: the migration now backfills before `NOT NULL`, trigger-created runs carry the host tenant, the signal worker queue is declared in config, and `route_signal/1` now acquires its `FOR UPDATE` locks inside the transaction. The Phase 27-focused test slice also passes (`55 tests, 0 failures`), although the run emitted local `too_many_connections` warnings from `Oban.Notifiers.Postgres`.

One critical correctness defect remains: signal routing still ignores `actor_id`, so a signal from one actor can resume every waiting workflow in the same tenant that shares the same `event_name`. Two additional warnings remain around stale state-spine data on resume and missing migration regression coverage.

## Critical Issues

### CR-01: `route_signal/1` ignores `actor_id`, so one actor's signal can resume other actors' workflows in the same tenant

**File:** `lib/chimeway/workflows.ex:367-435`
**Issue:** `Chimeway.Signal.track/4` requires and persists `actor_id` (`lib/chimeway/signal.ex:20-34`), and the Phase 27 research contract explicitly describes routing on the `(tenant_id, actor_id)` pair. The current `route_signal/1` implementation destructures only `tenant_id` and `event_name`, and `find_runs_waiting_for_signal/2` filters only on those two fields plus `state == :waiting`. That means any signal such as `("acme", "user-a", "email_opened")` will wake every `acme` run waiting on `"email_opened"`, including runs belonging to `user-b`. This is a real host-boundary leak within a tenant and can produce incorrect deliveries, transitions, and operator traces for the wrong recipient.

**Fix:**
```elixir
def route_signal(%Signal{tenant_id: tenant_id, actor_id: actor_id, event_name: event_name})
    when is_binary(tenant_id) and is_binary(actor_id) and is_binary(event_name) do
  Repo.transaction(fn ->
    matched_runs = find_runs_waiting_for_signal(tenant_id, actor_id, event_name)
    now = DateTime.utc_now()
    ...
  end)
end

defp find_runs_waiting_for_signal(tenant_id, actor_id, event_name) do
  Repo.all(
    from(wr in WorkflowRun,
      join: n in Chimeway.Notifications.Notification,
      on: n.id == wr.notification_id,
      where:
        wr.tenant_id == ^tenant_id and
          n.recipient_identity == ^actor_id and
          wr.state == :waiting and
          ^event_name in wr.pending_signals,
      lock: "FOR UPDATE"
    )
  )
end
```
Add regression coverage proving that two waiting runs in the same tenant with the same `pending_signals` do not both resume when only one matching `actor_id` is signaled.

## Warnings

### WR-01: Resumed runs keep stale `suspended_until`, so `explain/2` can report an active run as still suspended

**File:** `lib/chimeway/workflows.ex:301-309`, `lib/chimeway/workflows.ex:396-402`
**Issue:** `explain/2` exposes `suspended_until` directly from `WorkflowRun`, but `route_signal/1` does not clear that field when a waiting run is reactivated. A run that was waiting on a signal with a timeout/deadline can become `state: :active` while still carrying the old `suspended_until` value, which makes the state spine self-contradictory for operators and any code that trusts `explain/2` to answer "where is this run now, and why?"

**Fix:**
```elixir
update_run(Repo, run, %{
  state: :active,
  suspended_until: nil,
  pending_signals: [],
  status_reason: "signal_received",
  last_transition_at: now
})
```
Add a regression test that seeds a waiting run with both `pending_signals` and `suspended_until`, routes a signal, and asserts `Workflows.explain/2` returns `suspended_until: nil` afterward.

### WR-02: The migration test only checks the final schema, not the populated-database upgrade path that 27-04 was meant to protect

**File:** `test/chimeway/migration_contract_test.exs:16-23`
**Issue:** The current migration contract test verifies that the Phase 27 columns and table exist, but it never exercises the actual upgrade scenario from 27-04: pre-existing `chimeway_workflow_runs` rows created before the spine columns existed. That leaves the most failure-prone part of the migration unguarded. A future edit could accidentally reintroduce the old `ADD tenant_id NOT NULL` behavior or remove the `pending_signals` backfill and this test would still pass.

**Fix:** Add a migration regression test that runs the Phase 27 migration against a database containing legacy `chimeway_workflow_runs` rows, then asserts:
```elixir
assert workflow_runs_column("tenant_id") == {false, "character varying"}
assert no_row_matches?("SELECT 1 FROM chimeway_workflow_runs WHERE tenant_id IS NULL")
assert no_row_matches?("SELECT 1 FROM chimeway_workflow_runs WHERE pending_signals IS NULL")
```
The important part is to verify the backfill path on pre-existing rows, not just the steady-state schema.

---

_Reviewed: 2026-04-30T17:07:07Z_
_Reviewer: Codex (gsd-code-reviewer)_
_Depth: standard_

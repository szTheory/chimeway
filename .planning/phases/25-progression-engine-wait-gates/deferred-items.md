# Deferred Items - Phase 25

## Pre-existing test failure: `record_attempt/2 rolls back attempt insert if status transition fails`

- **File:** `test/chimeway/deliveries_test.exs:646`
- **Status:** Failed before Plan 25-02 changes (verified by stashing the worktree's working changes and re-running the test against the worktree's base commit `489750e`).
- **Symptom:** `Repo.aggregate(DeliveryAttempt, :count, :id)` returns `1` instead of the expected `0` after `Deliveries.record_attempt/2` is invoked from a `:pending` delivery.
- **Out of scope:** The defect is in `Chimeway.Deliveries.record_attempt/2` Multi rollback semantics, not in any file owned by Plan 25-02.
- **Recommendation:** Investigate in a follow-up plan or as a small `fix(deliveries)` once a parent plan owns the `Deliveries.record_attempt/2` file.

## Cross-connection FOR UPDATE proof for workflow progression engine (WR-01)

**Source:** Phase 25 verification report (`25-VERIFICATION.md`) gap WR-01, code review (`25-REVIEW.md`) WR-01.
**Status:** deferred to future test-infrastructure phase.

### What is missing

`test/chimeway/reliability/workflow_progression_race_test.exs` uses
`Task.async_stream` + `Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())`,
which shares one checked-out database connection across all spawned tasks.
PostgreSQL `FOR UPDATE` is non-blocking inside a single connection, so the
suite proves in-process re-entry safety only. Cross-connection
`FOR UPDATE` contention against the workflow_run row and the active-step
delivery row is not directly exercised.

### Why this is non-blocking for Phase 25

The engine's `FOR UPDATE` discipline is correct in code:

  * `Chimeway.Workflows.lock_run/2` is called at the top of `progress_run/2`
    and issues `SELECT ... FOR UPDATE` on the workflow_runs row.
  * `lock_active_step_delivery/3` (`lib/chimeway/workflows/progression.ex:372-378`)
    issues `SELECT ... FOR UPDATE` on the workflow-linked delivery row.

The verifier confirmed both locks exist by grep on the production code. The
gap is in the *proof shape* of the existing race test, not in the engine.

### What an actual cross-connection proof needs

  * A test mode (or dedicated CI lane) that does NOT use SQL Sandbox manual
    mode for the duration of the test — e.g.,
    `Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)` plus manual
    truncate/cleanup, OR a separate Ecto repo started just for this suite.
  * Multiple BEAM processes (or a process pool) where each opens its own
    Ecto connection (`Repo.checkout/2`) before calling
    `Progression.progress_run/2` against the shared workflow_run_id.
  * Assertions that survive non-isolated DB state — the suite has to clean
    up its own rows because Sandbox rollback is no longer in play.

### Suggested follow-up phase

Track in a future test-infrastructure phase that introduces a
cross-connection regression suite for any of the engine seams that rely on
`FOR UPDATE` (workflow progression, delivery convergence, digest emission).
The same suite shape can cover `Deliveries.record_attempt/2`,
`Digests.Emission.emit_bucket/2`, and `Progression.progress_run/2` because
they share the same in-transaction `FOR UPDATE` discipline.

### Decision

Phase 25 closes WR-01 by narrowing the race-suite moduledoc to match the
test's actual scope and tracking the cross-connection coverage gap here.
ESC-03 remains partially satisfied with respect to cross-connection proof,
but the production locking discipline is in place and verified by code
review.

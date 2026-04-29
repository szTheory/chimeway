# Deferred Items - Phase 25

## Pre-existing test failure: `record_attempt/2 rolls back attempt insert if status transition fails`

- **File:** `test/chimeway/deliveries_test.exs:646`
- **Status:** Failed before Plan 25-02 changes (verified by stashing the worktree's working changes and re-running the test against the worktree's base commit `489750e`).
- **Symptom:** `Repo.aggregate(DeliveryAttempt, :count, :id)` returns `1` instead of the expected `0` after `Deliveries.record_attempt/2` is invoked from a `:pending` delivery.
- **Out of scope:** The defect is in `Chimeway.Deliveries.record_attempt/2` Multi rollback semantics, not in any file owned by Plan 25-02.
- **Recommendation:** Investigate in a follow-up plan or as a small `fix(deliveries)` once a parent plan owns the `Deliveries.record_attempt/2` file.

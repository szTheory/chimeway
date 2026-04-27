# Phase 12: Oban Transactional Dispatch Consistency — Research

**Phase:** 12
**Goal:** Guarantee planning and enqueue paths stay transactionally consistent in optional Oban dispatch mode.
**Researched:** 2026-04-24

---

## Summary

Phase 12 is a targeted repair of two defects in `lib/chimeway/dispatch/oban.ex`:

1. **Atomicity gap** — `DeliveryPlanning.plan_notifications/2` commits delivery rows before the `Ecto.Multi` transaction starts, so a failed enqueue cannot roll back the planning rows.
2. **Atom table risk** — `String.to_atom("enqueue_delivery_#{delivery.id}")` creates atoms from database-generated UUIDs, which can exhaust the finite Erlang atom table in high-volume deployments.

Both defects are confined to `oban.ex`. The fix path is well-understood and does not require changes to any other module.

---

## Defect Analysis

### Defect 1: Planning-before-Transaction Gap (HIGH confidence)

**Location:** `lib/chimeway/dispatch/oban.ex:38–49` (dispatch/2 body)

```elixir
case DeliveryPlanning.plan_notifications(notifications, opts) do
  {:ok, deliveries} ->
    pending_deliveries = pending_deliveries(deliveries)
    case enqueue_deliveries(pending_deliveries, multi_opt) do
      ...
    end
  ...
end
```

`plan_notifications/2` calls `Chimeway.Deliveries.plan_delivery/3` → `Repo.insert(on_conflict: :nothing)` for each delivery. These inserts happen **outside** any transaction. By the time `enqueue_deliveries/2` runs its `Repo.transaction(multi_with_jobs)`, the delivery rows are already durably committed.

**Consequence:** If enqueue fails (e.g., Oban table constraint, external failure, caller multi rollback), delivery rows remain in `:pending` state with no corresponding Oban job. These orphaned rows will never be processed.

**Non-multi path:** The `enqueue_deliveries(deliveries, nil)` path (line 56–63) has no transaction at all — same gap, worse: each `Oban.insert/2` call is independent.

### Defect 2: Atom Table Exhaustion Risk (HIGH confidence)

**Location:** `lib/chimeway/dispatch/oban.ex:68`

```elixir
job_name = String.to_atom("enqueue_delivery_#{delivery.id}")
```

`delivery.id` is a PostgreSQL UUID (randomly generated). Each unique UUID creates a new atom. The Erlang atom table defaults to 1,048,576 atoms. Under sustained load or across restarts with many unique deliveries, this causes a system crash.

`Ecto.Multi` accepts **any Elixir term** as a step name (not just atoms) — tuples, strings, integers are all valid. There is no reason to create atoms here.

---

## Fix Approach

### Unified Multi-based Implementation (HIGH confidence)

**Pattern:** Merge non-multi and multi paths using `base_multi = Keyword.get(opts, :multi, Ecto.Multi.new())`.

**Mechanism:** Wrap `DeliveryPlanning.plan_notifications/2` inside `Ecto.Multi.run/3`. When a function is called inside `Ecto.Multi.run`, it uses the **checked-out connection** — meaning all `Repo.insert` calls inside `plan_notifications` execute within the transaction boundary. If any later step fails, all planning rows are rolled back.

```elixir
# Canonical shape (not final — illustrative)
def dispatch(notifications, opts) do
  base_multi = Keyword.get(opts, :multi, Ecto.Multi.new())

  multi =
    base_multi
    |> Ecto.Multi.run(:plan_notifications, fn _repo, _changes ->
      DeliveryPlanning.plan_notifications(notifications, opts)
    end)
    |> Ecto.Multi.run(:enqueue_jobs, fn _repo, %{plan_notifications: deliveries} ->
      # iterate pending deliveries, Oban.insert/2 each
      ...
    end)

  case Repo.transaction(multi) do
    {:ok, %{plan_notifications: deliveries}} -> {:ok, deliveries}
    {:error, :plan_notifications, reason, _} -> {:error, {:planning_failed, reason}}
    {:error, :enqueue_jobs, reason, _} -> {:error, reason}
    {:error, _step, reason, _} -> {:error, reason}  # caller multi step failures
  end
end
```

### Atom-safe Step Names (HIGH confidence)

Replace `String.to_atom("enqueue_delivery_#{delivery.id}")` with `{:enqueue_delivery, idx}` tuple step names, where `idx` is the enumeration index. Tuples are valid `Ecto.Multi` step names and are GC'd normally — no atom table impact.

However, if enqueue logic is moved inside a single `Ecto.Multi.run(:enqueue_jobs, ...)` step (the unified approach above), the per-delivery step naming issue disappears entirely — only one `Ecto.Multi.run` step wraps all enqueues.

### `Oban.insert/2` vs `Oban.insert/3` inside `Ecto.Multi.run` (MEDIUM confidence)

Two valid approaches for enqueuing inside a transaction:

**Option A: `Oban.insert/2` inside `Ecto.Multi.run`**
```elixir
Ecto.Multi.run(:enqueue_jobs, fn _repo, %{plan_notifications: deliveries} ->
  Enum.reduce_while(pending(deliveries), {:ok, []}, fn d, {:ok, acc} ->
    case Oban.insert(ObanWorker.new(%{delivery_id: d.id})) do
      {:ok, job} -> {:cont, {:ok, [job | acc]}}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end)
end)
```
`Oban.insert/2` uses the process's checked-out connection when called within a transaction — jobs are part of the same transaction.

**Option B: `Oban.insert/3` (multi step per job)**
```elixir
Enum.reduce(pending_deliveries, base_multi |> plan_step, fn d, acc ->
  Oban.insert(acc, {:enqueue_delivery, idx}, ObanWorker.new(%{delivery_id: d.id}))
end)
```
`Oban.insert/3` adds each job as a named `Ecto.Multi` step — more granular error reporting but more complex step name management.

**Recommendation:** Option A (single `Ecto.Multi.run` wrapping all enqueues) is cleaner, eliminates the per-job step naming problem, and is consistent with how planning is wrapped. The CONTEXT.md decisions allow either approach.

---

## Existing Code Assets

### `DeliveryPlanning.plan_notifications/2` (HIGH confidence)

`lib/chimeway/delivery_planning.ex:13–29` — accepts `(notifications, opts)`, calls `Deliveries.plan_delivery/3` → `Repo.insert(on_conflict: :nothing)` internally. Safe to call inside `Ecto.Multi.run` — its DB calls will use the checked-out connection.

The `on_conflict: :nothing` + reload pattern in `plan_delivery/3` (line 60–66) makes planning idempotent — retries after partial rollback are safe.

### `Repo.transaction/1` with `Ecto.Multi` (HIGH confidence)

Pattern already used throughout the codebase (e.g., `Deliveries.record_attempt/2` at line 176). Returns `{:ok, changes_map}` or `{:error, step_name, reason, changes_so_far}`.

### Error shape conventions (HIGH confidence)

From `oban.ex` line 89 and CONTEXT.md D-04:
- Planning failure → `{:error, {:planning_failed, reason}}`
- Enqueue failure → `{:error, reason}`
- Caller multi step failure → must not bubble raw `Ecto.Multi` step tuples to callers

### `oban_transactional_test.exs` gap (HIGH confidence)

The existing rollback test (`test "rolled-back multi leaves no job enqueued"`) uses `create_pending_delivery()` which pre-creates delivery rows in the test. This bypasses the planning gap — it proves jobs are rolled back, but does NOT prove planning rows are rolled back.

The existing commit test also uses `create_pending_delivery()` then passes a `multi:` opt — since delivery rows were pre-created, the test is not exercising the planning-inside-transaction path.

**Coverage needed:**
- **D-07:** Rollback-path test that triggers planning from scratch (using `create_notification()`), then forces rollback, then asserts no delivery rows exist.
- **D-08:** Enqueue-failure-after-successful-planning test — asserts no `pending` delivery rows remain after rollback.

---

## Scope Boundaries

### In scope
- `lib/chimeway/dispatch/oban.ex` — the only file requiring changes
- `test/chimeway/dispatch/oban_transactional_test.exs` — extend for planning-level rollback coverage

### Out of scope (per CONTEXT.md)
- `DeliveryPlanning.plan_notifications/2` — do not change its contract; wrap with `Ecto.Multi.run` instead
- `lib/chimeway/dispatch/sync.ex` — sync path is not affected
- Caller-visible async outcome metadata beyond existing `{:ok, deliveries}` / `{:error, reason}` shape (Phase 8 scope)
- New dispatch modes, channels, or business logic

---

## Risk Assessment

| Risk | Severity | Confidence |
|------|----------|------------|
| `plan_notifications` uses `Repo.get_by!` reload after `on_conflict: :nothing` (line 66) — this read uses the transaction connection and will see the uncommitted row correctly | LOW | HIGH |
| Caller-provided `:multi` steps may have overlapping step names with `:plan_notifications` or `:enqueue_jobs` | LOW | MEDIUM — document reserved step names |
| Oban's transactional behavior with `Oban.insert/2` inside `Ecto.Multi.run` is well-established | LOW | HIGH |
| `create_pending_delivery()` in existing tests pre-creates rows — tests still valid but mask the new atomicity guarantee | LOW | HIGH — new tests add coverage without breaking old |

---

## Test File Inventory

| File | Relevance |
|------|-----------|
| `test/chimeway/dispatch/oban_transactional_test.exs` | Primary: extend with D-07 and D-08 tests |
| `test/chimeway/dispatch/oban_test.exs` | Secondary: existing dispatch tests should continue passing |
| `test/support/chimeway/dispatch_helpers.ex` | `create_notification/1` (no delivery) and `create_pending_delivery/1` (with delivery) — both needed |

---

## Confidence Summary

| Finding | Confidence |
|---------|------------|
| Defect location: planning-before-transaction in `oban.ex` | HIGH |
| Defect location: atom creation from delivery.id | HIGH |
| Fix approach: unified multi with `Ecto.Multi.run` wrapping | HIGH |
| `Oban.insert/2` transactional behavior inside `Ecto.Multi.run` | HIGH |
| Error shape mapping (D-04 convention) | HIGH |
| Test gap: existing rollback test bypasses planning atomicity | HIGH |
| Atom-safe step names using tuples or single run step | HIGH |
| No changes needed outside `oban.ex` and `oban_transactional_test.exs` | HIGH |

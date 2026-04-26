---
phase: 14-delivery-reliability-hardening
reviewed: 2026-04-26T00:00:00Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - lib/chimeway/deliveries.ex
  - lib/chimeway/delivery_attempt.ex
  - lib/chimeway/dispatch/executor.ex
  - lib/chimeway/dispatch/oban_worker.ex
  - lib/chimeway/dispatch/sync.ex
  - lib/chimeway/telemetry.ex
  - lib/chimeway/traces.ex
  - lib/chimeway/traces/explanation.ex
  - priv/repo/migrations/20260426150000_add_attempt_history_columns.exs
  - test/chimeway/deliveries_test.exs
  - test/chimeway/delivery_attempt_test.exs
  - test/chimeway/dispatch/oban_worker_test.exs
  - test/chimeway/reliability/attempt_history_test.exs
  - test/chimeway/reliability/duplicate_protection_test.exs
  - test/chimeway/reliability/retry_exhaustion_test.exs
  - test/chimeway/reliability/terminal_convergence_test.exs
  - test/chimeway/traces_test.exs
findings:
  critical: 1
  warning: 4
  info: 2
  total: 7
status: issues_found
---

# Phase 14: Code Review Report

**Reviewed:** 2026-04-26
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found

## Summary

Phase 14 introduces delivery reliability hardening: `attempt_number` and `error_class`
columns on `chimeway_delivery_attempts`, concurrent-safe attempt recording via a
SELECT FOR UPDATE lock, permanent/bounced terminal convergence inside the same
transaction, retry exhaustion via an in-band `attempt == max_attempts` guard, and
an updated telemetry/traces surface.

The overall architecture is sound. The W8 lock correctly serializes concurrent
`record_attempt/2` callers, the :delivery Multi step correctly threads the locked
row (not the stale closure), the BL-02 unknown-adapter-return catch-all has both a
convergence branch (final attempt) and a loud-failure branch (earlier attempts), and
the migration is correctly additive.

One critical bug was found: `Traces.last_attempt_summary/1` uses `Enum.max_by/2`
on `attempt_number`, but in Elixir's term ordering `nil > 5` is `true` (atoms sort
after numbers). Any pre-migration row with `attempt_number = nil` would be selected
as the "last" attempt over a row with `attempt_number = 5`. Four warnings and two
info items round out the findings.

---

## Critical Issues

### CR-01: `Traces.last_attempt_summary/1` selects wrong attempt when any row has `nil` `attempt_number`

**File:** `lib/chimeway/traces.ex:154`

**Issue:** `Enum.max_by(attempts, & &1.attempt_number)` is used to select the most
recent attempt. In Elixir's term ordering, atoms sort _after_ numbers. `nil` is the
atom `:nil`, so `nil > 5` evaluates to `true`:

```elixir
iex> nil > 5
true
```

Pre-migration attempt rows whose `attempt_number` was not backfilled (either because
they existed before the migration, or because they were inserted during the narrow
window between the `ALTER TABLE` and the `UPDATE` backfill statement in
`20260426150000_add_attempt_history_columns.exs`) will have `attempt_number = nil`.
`Enum.max_by` will pick any such nil-numbered row as the "last" attempt in preference
to a row with `attempt_number = 5`. The result:

- `explain_delivery/1` returns stale or wrong `last_attempt` data for any delivery
  that has a mix of nil and non-nil `attempt_number` rows.
- Operators debugging a retries-exhausted delivery would see an earlier failed
  attempt reported as the "last" attempt instead of the final one.
- The timeline's `:attempt_recorded` entries (built separately via
  `Enum.map(attempts, ...)`) are unaffected, but `last_attempt` in the
  `Explanation` struct would point to the wrong row.

The `WR-05` test in `traces_test.exs` verifies the tie-break when `inserted_at`
values are equal, but it does not cover the nil-vs-integer case.

**Fix:**

```elixir
defp last_attempt_summary([]), do: nil

defp last_attempt_summary(attempts) do
  # nil > integer is true in Elixir's term ordering (atoms > numbers),
  # so Enum.max_by on attempt_number would erroneously pick a nil row
  # over attempt_number=5. Partition numbered rows first.
  case Enum.filter(attempts, &is_integer(&1.attempt_number)) do
    [] ->
      # All rows are pre-migration with nil attempt_number; fall back to
      # inserted_at ordering (best available approximation).
      last = Enum.max_by(attempts, & &1.inserted_at, DateTime)
      build_last_attempt_map(last)

    numbered ->
      last = Enum.max_by(numbered, & &1.attempt_number)
      build_last_attempt_map(last)
  end
end

defp build_last_attempt_map(attempt) do
  %{
    outcome: attempt.outcome,
    inserted_at: attempt.inserted_at,
    attempt_number: attempt.attempt_number,
    error_class: attempt.error_class
  }
end
```

---

## Warnings

### WR-01: Migration backfill has non-deterministic `ROW_NUMBER` ordering for same-timestamp attempts

**File:** `priv/repo/migrations/20260426150000_add_attempt_history_columns.exs:27`

**Issue:** The backfill assigns `attempt_number` via:

```sql
ROW_NUMBER() OVER (PARTITION BY delivery_id ORDER BY inserted_at)
```

`inserted_at` has microsecond precision, but two attempt rows for the same
`delivery_id` can share an identical timestamp (demonstrated by the WR-05 test in
`traces_test.exs` which injects `shared_at` with `microsecond: {0, 6}` on both rows).
When there is a tie, PostgreSQL's `ROW_NUMBER()` assigns ordinals in an unspecified
order — both rows could receive `1, 2` or `2, 1` on different plan executions. The
resulting `attempt_number` values would not reflect actual attempt order for those
rows, undermining the REL-02 ordering guarantee for historical data.

**Fix:** Add a stable secondary sort key to the window function. The UUID primary
key `id` is not sequentially sortable, but PostgreSQL's `ctid` physical tuple
identifier gives a stable ordering within a single sweep:

```sql
ROW_NUMBER() OVER (PARTITION BY delivery_id ORDER BY inserted_at, id)
```

Using `id` (UUID) as the tiebreaker is not semantically perfect (UUID v4 is random,
not time-ordered), but it eliminates non-determinism. Alternatively, if the table
has an auto-increment surrogate from a prior migration, use that. Document the
choice explicitly.

---

### WR-02: `handle_delivery/3` performs `Policy.evaluate` on the stale pre-lock delivery struct, creating a TOCTOU gap

**File:** `lib/chimeway/dispatch/oban_worker.ex:132-143`

**Issue:** `perform/1` fetches `delivery = Deliveries.get_delivery!(delivery_id)` and
checks terminal status at line 112. Then `handle_delivery/3` calls
`Policy.evaluate(delivery, ...)` and `do_dispatch/3` passes the same struct into
`Executor.run_delivery/1`. Between the `get_delivery!` call and the `record_attempt`
transaction, another process could transition the delivery to a terminal state (e.g.,
a concurrent Oban attempt that succeeded, or a manual cancellation via an operator
console).

`Executor.run_delivery/1` calls `transition_status(delivery, :dispatched)` which will
return `{:error, {:invalid_transition, ...}}` for an already-terminal delivery, so
there is no double-delivery risk. However, `do_dispatch/3` maps
`{:error, step, reason, _changes}` from the failed Multi to `{:error, {step, reason}}`,
causing Oban to schedule a retry. The next execution finds the delivery terminal and
returns `:ok`. This wastes a retry slot and emits misleading error telemetry.

**Fix:** Re-check the terminal state with a freshly fetched row inside `do_dispatch/3`,
or reload inside `Executor.run_delivery/1` before calling `transition_status`:

```elixir
defp do_dispatch(%Delivery{id: id}, attempt, max_attempts) do
  fresh = Deliveries.get_delivery!(id)

  if fresh.status in Deliveries.terminal_states() do
    :ok
  else
    case Executor.run_delivery(fresh) do
      {:ok, %{attempt: %DeliveryAttempt{} = recorded, delivery: %Delivery{} = updated}} ->
        map_outcome_to_oban_return(recorded, updated, attempt, max_attempts)
      {:error, step, reason, _changes} ->
        {:error, {step, reason}}
      {:error, _reason} = error ->
        error
    end
  end
end
```

---

### WR-03: `sanitize_metadata/1` does not sanitize string-keyed `"provider_response"` in `record_attempt/2`

**File:** `lib/chimeway/deliveries.ex:234-236`

**Issue:** `record_attempt/2` sanitizes `provider_response` with:

```elixir
safe_attrs =
  attrs
  |> Map.update(:provider_response, nil, &sanitize_metadata/1)
  |> Map.put(:delivery_id, delivery.id)
```

`Map.update/4` only matches the exact atom key `:provider_response`. If a caller
passes `attrs = %{"provider_response" => %{"password" => "secret"}}` with a string
key (a valid input — `Ecto.Changeset.cast/3` accepts string keys), then:

1. `Map.update(:provider_response, nil, ...)` inserts `:provider_response => nil`
   (the default) without touching the original `"provider_response"` string key.
2. `safe_attrs` now contains both `:provider_response => nil` and
   `"provider_response" => %{"password" => "secret"}`.
3. Ecto's `cast/3` processes string keys and persists the sensitive data.

The current executor path always passes atom keys, so the immediate risk is low. The
public `record_attempt/2` spec accepts `map()`, making this a latent security gap for
external callers.

**Fix:** Normalize the key to atom before sanitizing:

```elixir
safe_attrs =
  attrs
  |> coerce_provider_response_to_atom_key()
  |> Map.update(:provider_response, nil, &sanitize_metadata/1)
  |> Map.put(:delivery_id, delivery.id)

defp coerce_provider_response_to_atom_key(attrs) do
  case Map.pop(attrs, "provider_response") do
    {nil, attrs} -> attrs
    {val, attrs} -> Map.put_new(attrs, :provider_response, val)
  end
end
```

---

### WR-04: Manually-cancelled deliveries produce no `:cancelled` timeline entry in `build_timeline/4`

**File:** `lib/chimeway/traces.ex:199-213`

**Issue:** `cancellation_entries` is built as:

```elixir
cancellation_entries =
  if delivery.status == :cancelled and delivery.suppression_reason do
    [...]
  else
    []
  end
```

A delivery cancelled via `Deliveries.transition_status(delivery, :cancelled)` has
`suppression_reason = nil`. The timeline for such a delivery shows status `:cancelled`
in the `Explanation` struct but contains no `:cancelled` timeline entry explaining
when it was cancelled. Operators debugging a manually-cancelled delivery see an
incomplete trace with no event marking the cancellation.

The `terminal_convergence_test.exs` test at line 142 asserts
`cancelled.suppression_reason == nil` for the manual-cancel path but does NOT check
whether a `:cancelled` timeline entry is present — this gap is untested.

**Fix:** Emit the `:cancelled` entry even when `suppression_reason` is nil, using a
sentinel reason string:

```elixir
cancellation_entries =
  if delivery.status == :cancelled do
    reason = delivery.suppression_reason || "manual"
    [
      %{
        at: delivery.updated_at,
        event: :cancelled,
        detail: %{
          reason: reason,
          policy_checkpoint:
            Map.get(delivery.metadata || %{}, "policy_checkpoint", "unknown")
        }
      }
    ]
  else
    []
  end
```

---

## Info

### IN-01: Commented-out `IO.inspect` debug lines left in the production telemetry module

**File:** `lib/chimeway/telemetry.ex:131-132`

**Issue:** Two commented-out debug lines remain inside `safe_meta/1`:

```elixir
# IO.inspect(meta, label: "SAFE_META INPUT")
# IO.inspect(result, label: "SAFE_META OUTPUT")
```

If uncommented accidentally during a debugging session, these emit all telemetry
metadata (delivery IDs, notification keys) to stdout in production.

**Fix:** Remove the two comment lines entirely.

---

### IN-02: `oban_worker_test.exs:315` comment incorrectly states `import Ecto.Query` must be at the top of the file

**File:** `test/chimeway/dispatch/oban_worker_test.exs:315`

**Issue:** The comment reads:

```elixir
# The `from` macro is in scope via
# `import Ecto.Query` at the top of the test file (verify if missing).
```

`import Ecto.Query` is not at the top of this file. It is available because
`Chimeway.DataCase` (`test/support/data_case.ex:14`) imports `Ecto.Query` for all
modules that `use Chimeway.DataCase`. The comment is factually wrong and its
parenthetical "verify if missing" may lead a developer to add a redundant import.

**Fix:** Replace with an accurate comment:

```elixir
# `from/2` is available via `Chimeway.DataCase`, which imports `Ecto.Query`.
```

---

_Reviewed: 2026-04-26_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

---
phase: 14-delivery-reliability-hardening
reviewed: 2026-04-26T00:00:00Z
depth: standard
files_reviewed: 19
files_reviewed_list:
  - lib/chimeway/deliveries.ex
  - lib/chimeway/delivery_attempt.ex
  - lib/chimeway/dispatch/executor.ex
  - lib/chimeway/dispatch/oban_worker.ex
  - lib/chimeway/dispatch/sync.ex
  - lib/chimeway/telemetry.ex
  - lib/chimeway/traces.ex
  - lib/chimeway/traces/explanation.ex
  - lib/chimeway/trigger.ex
  - priv/repo/migrations/20260426150000_add_attempt_history_columns.exs
  - test/chimeway/deliveries_test.exs
  - test/chimeway/delivery_attempt_test.exs
  - test/chimeway/dispatch/oban_worker_test.exs
  - test/chimeway/dispatch/sync_test.exs
  - test/chimeway/reliability/attempt_history_test.exs
  - test/chimeway/reliability/duplicate_protection_test.exs
  - test/chimeway/reliability/retry_exhaustion_test.exs
  - test/chimeway/reliability/terminal_convergence_test.exs
  - test/chimeway/traces_test.exs
findings:
  blocker: 2
  warning: 7
  total: 9
status: issues_found
---

# Phase 14: Code Review Report

**Reviewed:** 2026-04-26T00:00:00Z
**Depth:** standard
**Files Reviewed:** 19
**Status:** issues_found
**Diff Base:** a1c65192fd82d573425f04d8672f39cad2f1095f..HEAD

## Summary

Phase 14 introduces meaningful reliability hardening: the `record_attempt/2`
Multi gains a `SELECT ... FOR UPDATE` lock that genuinely serializes concurrent
callers (W8), permanent/bounced classifications converge to `:cancelled`
inside the same transaction (REL-03), and Oban exhaustion is handled in-band.
The migration is correctly additive.

However, I found two BLOCKER-class problems and several quality defects:

1. **Stale-struct writes inside `record_attempt/2`'s transaction** — the
   `:lock_delivery` step locks the row but `terminal_or_failed_transition`
   then calls `change(...) |> Repo.update()` on the *closure-captured* stale
   `delivery` struct, so any metadata or columns updated between the caller's
   original read and the lock acquisition are silently overwritten. The serial
   tests pass because contention is rare in tests, but the documented
   "concurrent contiguity invariant" is weaker than advertised.
2. **`map_outcome_to_oban_return/4` catch-all violates REL-03 D-12** — the
   defensive catch-all returns `{:error, {:unhandled_outcome, ...}}` without
   ever invoking `exhaust_delivery/1`, even when `attempt == max_attempts`. A
   delivery hitting that branch on its final attempt is left non-terminal and
   the REL-03 "every delivery converges" invariant is broken.
3. The Phase 14 concurrent attempt-number test does NOT actually exercise true
   concurrent `record_attempt/2` calls against the same `:dispatched`
   delivery — `transition_status(_, :dispatched)` is the de facto critical
   section, so 4 of 5 tasks fail and never reach `record_attempt/2`. The
   passing test is not evidence that the W8 lock works under contention.
4. Several smaller concerns: stale-struct closure in `terminal_or_failed_transition`,
   misleading `[:deliveries, :plan]` telemetry on duplicate triggers, low-cardinality
   index on `error_class`, `last_attempt_summary` ordering by `inserted_at` instead
   of `attempt_number`, `traces.ex` building no `:cancelled` timeline entry for
   permanent/bounced/retries_exhausted, an `Explanation.t` typespec note that no
   longer matches behaviour, and a typespec gap on the `Multi.run` tuple shape.

The committed Phase 14 telemetry diff (additive `attempt_number error_class`
whitelist entries) is correct and out of scope per the prompt's note about
uncommitted Phase 10-02 edits in `lib/chimeway/telemetry.ex`.

## Blocker Issues

### BL-01: `record_attempt/2` writes the stale closure-captured delivery struct, not the locked row

**File:** `lib/chimeway/deliveries.ex:241-266`
**Issue:**
The `:lock_delivery` Multi step acquires `SELECT ... FOR UPDATE` and binds the
result to `locked` in `Multi`'s `changes` map (the step returns `{:ok, locked}`).
But neither `:next_attempt_number` nor `:delivery` reads from that
`changes` map — both use the closure-captured `delivery` parameter:

```elixir
|> Multi.run(:next_attempt_number, fn repo, _changes ->
  next_n =
    from(a in DeliveryAttempt,
      where: a.delivery_id == ^delivery.id,    # <-- closure, not changes.lock_delivery
      ...
|> Multi.run(:delivery, fn _repo, _changes ->
  terminal_or_failed_transition(delivery, outcome, error_class)  # <-- closure
end)
```

Inside `terminal_or_failed_transition/3`, `transition_status/2` and
`cancel_with_reason/2` then do
`delivery |> change(...) |> Repo.update()`. Because Ecto's `Repo.update/1`
on a non-versioned struct uses a `WHERE id = ?` predicate (not optimistic
locking), it will:

- overwrite the `metadata` JSONB column with the closure's stale value,
  silently dropping concurrent metadata writes between the caller's original
  read and the lock acquisition (e.g., a concurrent `suppress_delivery/3`
  that wrote `policy_checkpoint` would be clobbered);
- in `cancel_with_reason/2`, build the new `metadata` map from
  `delivery.metadata` (the stale value), so `policy_checkpoint: "perform"`
  is added on top of stale metadata, not the row's current metadata.

The W8 lock prevents two `record_attempt` callers from racing each other, but
it does NOT prevent a non-`record_attempt` writer (e.g., a `suppress_delivery/3`
callsite, which does NOT take the lock) from sandwiching its write between the
caller's read and the lock-protected update. Worse, even between two
`record_attempt` callers: caller A commits, releases lock, and writes
`status: :failed, metadata: %{... "policy_checkpoint" => "perform"}`. Caller
B's closure has the OLD `delivery` from before A's commit — when B's
`transition_status(delivery, :failed)` calls `Repo.update`, it writes its
stale metadata back, dropping any of A's metadata fields that aren't part of
the changeset.

**Fix:**
Read the locked row out of `changes` and pass it through every subsequent step:

```elixir
|> Multi.run(:next_attempt_number, fn repo, %{lock_delivery: locked} ->
  next_n =
    from(a in DeliveryAttempt,
      where: a.delivery_id == ^locked.id,
      select: count(a.id)
    )
    |> repo.one()
    |> Kernel.+(1)
  {:ok, next_n}
end)
|> Multi.insert(:attempt, fn %{lock_delivery: locked, next_attempt_number: n} ->
  DeliveryAttempt.changeset(%DeliveryAttempt{},
    safe_attrs |> Map.put(:delivery_id, locked.id) |> Map.put(:attempt_number, n))
end)
|> Multi.run(:delivery, fn _repo, %{lock_delivery: locked} ->
  terminal_or_failed_transition(locked, outcome, error_class)
end)
```

Then `terminal_or_failed_transition/3` operates on the freshly-locked row.
Add a regression test that interleaves `suppress_delivery/3` with
`record_attempt/2` and asserts the suppression metadata survives.

### BL-02: `map_outcome_to_oban_return/4` catch-all violates REL-03 D-12 on the final attempt

**File:** `lib/chimeway/dispatch/oban_worker.ex:160-162`
**Issue:**
The defensive catch-all clause:

```elixir
defp map_outcome_to_oban_return(%DeliveryAttempt{} = attempt, %Delivery{} = delivery, _attempt_n, _max) do
  {:error, {:unhandled_outcome, attempt.outcome, attempt.error_class, delivery.status}}
end
```

ignores `attempt_n` and `max` entirely. Concretely, on `attempt_n == max`
with an unexpected outcome+status combination, the worker returns
`{:error, ...}` and Oban discards/retries the job — but `exhaust_delivery/1`
is NEVER called. The delivery row is left in whatever non-terminal state
`record_attempt` produced (e.g., `:failed`, `:dispatched`), and once Oban
gives up on the job, no further dispatching occurs.

This breaks the REL-03 D-12 invariant ("every delivery converges to a state
in `Deliveries.terminal_states/0`") on the unexpected-shape path. The
specific "temporary + :failed" clause at lines 136-156 is the ONLY path
that handles exhaustion; any drift between `record_attempt`'s outputs and
the worker's matchers (e.g., a future addition to the `error_class`
taxonomy without a worker update) silently bypasses exhaustion.

**Fix:**
Either route the catch-all through `exhaust_delivery/1` when at the final
attempt, or keep the `{:error, _}` return but let Oban's `c:Oban.Worker.discard/1`
handle the post-discard convergence. Minimum viable fix:

```elixir
defp map_outcome_to_oban_return(
       %DeliveryAttempt{} = attempt,
       %Delivery{status: status} = delivery,
       attempt_n,
       max_attempts
     ) do
  reason = {:unhandled_outcome, attempt.outcome, attempt.error_class, status}

  if attempt_n >= max_attempts and status not in Deliveries.terminal_states() do
    # Force convergence: write a generic terminal state so REL-03 D-12 holds.
    case Deliveries.exhaust_delivery(%{delivery | status: :failed}) do
      {:ok, _} -> :ok
      _ -> {:error, reason}
    end
  else
    {:error, reason}
  end
end
```

Better: add explicit clauses for every documented (outcome, error_class,
status) tuple and reduce the catch-all to a `Logger.error` + crash so
unexpected combinations are loud rather than silently leaving rows
non-terminal.

## Warnings

### WR-01: Concurrent `attempt_number` test does not actually exercise concurrent `record_attempt/2`

**File:** `test/chimeway/reliability/attempt_history_test.exs:184-232`
**Issue:**
The test fans out 5 tasks, each of which runs:

```elixir
with {:ok, dispatched} <- Deliveries.transition_status(current, :dispatched) do
  Deliveries.record_attempt(dispatched, %{outcome: :failed, ...})
```

`@allowed_transitions[:dispatched]` does NOT include `:dispatched`, so only
the first task (whichever wins the `pending -> :dispatched` race) reaches
`record_attempt/2`. The other 4 tasks return `{:error, {:invalid_transition, ...}}`
from `transition_status/2` and never call `record_attempt/2`. After task 1
records its attempt the row is `:failed`; only then can subsequent tasks
re-enter. The "concurrent contention" is therefore artificial — the
fan-out collapses into a serial chain via `transition_status/2`, not via
the W8 row lock the test claims to validate.

The test passes because the chain is serial, not because the lock works.
The actual lock contention path (two `record_attempt/2` calls against an
already-`:dispatched` delivery, e.g., from two retries triggered before the
first commits) is untested.

**Fix:**
Either (a) bypass `transition_status/2` and seed the delivery in
`:dispatched` so all 5 tasks race on `record_attempt/2`, or (b) document
that the test exercises the secondary serialization layer
(`transition_status/2`) rather than the W8 lock. Recommended (a):

```elixir
%{delivery: delivery} = create_pending_delivery()
{:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

1..5
|> Task.async_stream(fn n ->
  Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
  # All 5 race against the same :dispatched delivery; W8 lock must serialize.
  Deliveries.record_attempt(dispatched, %{outcome: :failed, error_class: "temporary", ...})
end, ...)
```

Note: with the BL-01 fix, even (a) requires `transition_status` to allow
`:failed -> :failed` reentry or callers must accept that some tasks will
get `{:error, :delivery, ...}` from a now-terminal delivery. The point is
to prove that *no two* attempts ever share `attempt_number`, regardless of
how many tasks actually succeed.

### WR-02: `terminal_or_failed_transition/3` and `cancel_with_reason/2` operate on the closure-captured delivery

**File:** `lib/chimeway/deliveries.ex:264-265, 298-331`
**Issue:**
Same root cause as BL-01 but worth calling out separately for the
`cancel_with_reason/2` helper specifically. It builds the new metadata
from `delivery.metadata`:

```elixir
metadata =
  delivery.metadata
  |> ensure_metadata_map()
  |> Map.put("policy_checkpoint", "perform")
```

If a concurrent caller wrote `delivery.metadata.correlation_id = "xyz"` between
the caller's read and `record_attempt/2` acquiring the lock, that
correlation_id is silently dropped from the post-write row. This breaks
trace fidelity (Phase 10 enrichment).

**Fix:**
Use the locked delivery from the Multi `changes` map — see BL-01 fix.

### WR-03: Telemetry `[:deliveries, :plan]` span fires on duplicate triggers despite no planning happening

**File:** `lib/chimeway/trigger.ex:267-290`
**Issue:**
`plan_deliveries_span/4` wraps `dispatch_after_trigger/4` in
`Telemetry.span([:deliveries, :plan], ...)` unconditionally, but on the
duplicate path (`{:duplicate, event}`) `dispatch_after_trigger/4` is INERT
and returns the duplicate tuple unchanged — no deliveries are planned, no
notifications are processed. Operators subscribing to
`[:chimeway, :deliveries, :plan, :stop]` will see a span emission that
implies planning happened.

The `extra` block correctly skips emitting any `event_id`/`correlation_id`
on the duplicate path (only matches `{:ok, %{event: event}}`), but the
span itself is still emitted with potentially-stale meta from the outer
closure (`notification_key` from `notifier.notification_key()` only).
Histograms/counters on this event will be inflated by no-op duplicate
trigger calls.

**Fix:**
Skip the `[:deliveries, :plan]` span when the trigger result is
`{:duplicate, _}` or `{:error, _}`. For example:

```elixir
defp plan_deliveries_span({:duplicate, _} = result, _, _, _), do: result
defp plan_deliveries_span({:error, _} = result, _, _, _), do: result
defp plan_deliveries_span(result, notifier, params, opts) do
  Telemetry.span([:deliveries, :plan], ..., fn -> ... end)
end
```

### WR-04: Migration creates a low-cardinality index on `error_class` without a documented use case

**File:** `priv/repo/migrations/20260426150000_add_attempt_history_columns.exs:35`
**Issue:**
`create index(:chimeway_delivery_attempts, [:error_class])` builds a B-tree
index on a column with at most 4 distinct values (`"temporary"`,
`"permanent"`, `"bounced"`, `NULL`). On a large attempts table the index is
both expensive to maintain (one entry per row) and useless for selective
queries — Postgres' planner will almost always choose a sequential scan
over a 25%-selective index. There's no comment, no test, no callsite, and
no operator-query documentation that justifies it.

A partial index (e.g., `WHERE error_class = 'permanent'`) might be
defensible if there's a known operator query, but a full B-tree on
`error_class` alone is dead weight on every insert.

**Fix:**
Either delete the index, or convert to a partial/composite index with a
documented use case. Example composite:

```elixir
create index(:chimeway_delivery_attempts, [:delivery_id, :error_class])
```

would actually accelerate "what was the last failure mode for this
delivery?" queries.

### WR-05: `last_attempt_summary/1` orders by `inserted_at` instead of `attempt_number`

**File:** `lib/chimeway/traces.ex:148-159`
**Issue:**
```elixir
defp last_attempt_summary(attempts) do
  last = Enum.max_by(attempts, & &1.inserted_at, DateTime)
  ...
end
```

Now that `attempt_number` is contiguous and 1-indexed (REL-02), it is the
authoritative ordering field. `inserted_at` has microsecond precision; under
concurrent inserts (post-fix for BL-01), two attempts could share a
truncated timestamp. With the W8 lock those two attempts cannot share an
`attempt_number`, but they might share `inserted_at`, in which case
`Enum.max_by` returns the first encountered match — a non-deterministic
choice for "last".

**Fix:**
```elixir
last = Enum.max_by(attempts, & &1.attempt_number)
```

`attempt_number` is non-null on all new rows (changeset enforces it after
Plan 14-04 Task 3). Add a fallback for backfilled historical rows whose
`attempt_number` came from `ROW_NUMBER()` and is still authoritative.

### WR-06: `traces.build_timeline/4` emits no timeline entry for `:cancelled` deliveries

**File:** `lib/chimeway/traces.ex:176-193`
**Issue:**
`suppression_entries` only fires when `delivery.status == :suppressed`:

```elixir
if delivery.status == :suppressed and delivery.suppression_reason do
  [%{at: delivery.updated_at, event: :suppressed, detail: %{...}}]
else
  []
end
```

But Phase 14 introduces THREE new ways for a delivery to land at
`:cancelled` with a `suppression_reason` set (`"retries_exhausted"`,
`"permanent_failure"`, `"bounced"`). For those rows, the timeline
contains `:event_created`, `:notification_created`, `:delivery_planned`,
and `:attempt_recorded` entries but **no entry that names the
cancellation reason or its timestamp**. Operators using
`explain_delivery/1` to answer "why was this cancelled?" must read the
`suppression_reason` field separately and infer the cancellation
timestamp from `delivery.updated_at` — defeating the purpose of the
timeline.

**Fix:**
Emit a `:cancelled` timeline entry analogous to `:suppressed`:

```elixir
cancellation_entries =
  if delivery.status == :cancelled and delivery.suppression_reason do
    [%{at: delivery.updated_at, event: :cancelled,
       detail: %{reason: delivery.suppression_reason,
                 policy_checkpoint:
                   Map.get(delivery.metadata || %{}, "policy_checkpoint", "unknown")}}]
  else
    []
  end

(base ++ suppression_entries ++ cancellation_entries ++ attempt_entries)
|> Enum.sort_by(& &1.at, DateTime)
```

### WR-07: `Explanation.t` typespec doc says `suppression_reason` is set "when status is `:suppressed`, else nil" — now stale

**File:** `lib/chimeway/traces/explanation.ex:18`
**Issue:**
```
- `suppression_reason` — reason atom string when status is :suppressed, else nil
```

Phase 14 makes `:cancelled` deliveries carry `suppression_reason`
(`"retries_exhausted"`, `"permanent_failure"`, `"bounced"`). The doc string
is now misleading. Library consumers writing pattern matches against this
struct based on the docstring will miss the `:cancelled` case.

**Fix:**
Update the docstring:

```
- `suppression_reason` — reason string when status is :suppressed or
  :cancelled (e.g., "channel_disabled", "retries_exhausted",
  "permanent_failure", "bounced"); nil otherwise.
```

### WR-08: `record_attempt/2` `@spec` does not declare the `:lock_delivery` failure case

**File:** `lib/chimeway/deliveries.ex:219-221`
**Issue:**
The `@spec` says
`{:error, atom(), term(), map()}` for the failure tuple, which is correct
for `Multi` failures generally. But the `:lock_delivery` step can return
`{:error, :delivery_not_found}` when the delivery was hard-deleted between
the caller's read and the Multi's lock attempt. Callers (`Executor`,
`ObanWorker`) destructure on `{:error, step, reason, _changes}` — the
`step` will be `:lock_delivery` and `reason` will be the atom
`:delivery_not_found`. This isn't a bug per se (the spec covers it via
`atom()` for step name and `term()` for reason), but neither
`Dispatch.Executor` nor `ObanWorker.do_dispatch/3` has explicit handling
for `step == :lock_delivery`. The error bubbles up as
`{:error, {:lock_delivery, :delivery_not_found}}` — operators reading
Oban error telemetry will get a tuple they have to decode.

**Fix:**
Either:
1. Document the failure case explicitly in the `@doc` and a regression
   test, OR
2. Convert `:lock_delivery` failure into a typed error
   (`{:error, :delivery_not_found}`) that callers match on directly. For
   example, intercept the Multi result:

```elixir
case Repo.transaction(multi) do
  {:error, :lock_delivery, :delivery_not_found, _} ->
    {:error, :delivery_not_found}
  other ->
    other
end
```

### WR-09: `validate_attempt_number_positive/1` accepts `nil` even though `:attempt_number` is required

**File:** `lib/chimeway/delivery_attempt.ex:63-69`
**Issue:**
```elixir
defp validate_attempt_number_positive(changeset) do
  case get_field(changeset, :attempt_number) do
    n when is_integer(n) and n >= 1 -> changeset
    nil -> changeset                                 # <-- silently accepts nil
    _ -> add_error(changeset, :attempt_number, "must be a positive integer")
  end
end
```

The `nil` clause is a leftover from when `:attempt_number` was optional
(Plan 14-02 → 14-04 staging). Now that the field is in
`@required_fields`, `validate_required/2` will already add a
`"can't be blank"` error for nil; the `nil -> changeset` clause is dead
defensively. The dead clause is harmless but obscures intent: a future
maintainer might think nil is acceptable.

**Fix:**
Drop the `nil` clause. `validate_required/2` runs before this validator
and emits the right error; this validator should only assert "if a value
is present, it must be a positive integer":

```elixir
defp validate_attempt_number_positive(changeset) do
  case get_field(changeset, :attempt_number) do
    n when is_integer(n) and n >= 1 -> changeset
    n when is_nil(n) -> changeset  # validate_required handles this
    _ -> add_error(changeset, :attempt_number, "must be a positive integer")
  end
end
```

…or fold the nil case into the catch-all and rely on `validate_required/2`'s
output exclusively.

---

_Reviewed: 2026-04-26T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

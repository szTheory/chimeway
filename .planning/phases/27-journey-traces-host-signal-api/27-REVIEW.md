---
phase: 27-journey-traces-host-signal-api
reviewed: 2026-04-30T00:00:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - lib/chimeway/dispatch/signal_router_worker.ex
  - lib/chimeway/signal.ex
  - lib/chimeway/signals/signal.ex
  - lib/chimeway/workflows.ex
  - lib/chimeway/workflows/workflow_run.ex
  - priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs
  - test/chimeway/dispatch/signal_router_worker_test.exs
  - test/chimeway/signal_test.exs
  - test/chimeway/workflows/workflow_run_test.exs
  - test/chimeway/workflows_inspection_test.exs
  - test/chimeway/workflows_test.exs
findings:
  critical: 4
  warning: 7
  info: 4
  total: 15
status: issues_found
---

# Phase 27: Code Review Report

**Reviewed:** 2026-04-30
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

Phase 27 introduces the host-facing `Chimeway.Signal.track/4` API, a `chimeway_signals` table, the `SignalRouterWorker` Oban worker, the State Spine columns on `chimeway_workflow_runs`, and `Workflows.explain/2` / `Workflows.list_traces/3` inspection helpers.

The shape of the design is sound — durable signal row, Multi-wrapped enqueue, FOR UPDATE locking on matched runs, structural-only context, tenant-scoped reads. But the implementation ships with several **BLOCKER**-class defects that will fail in any environment with pre-existing data or a non-default Oban configuration:

1. The migration adds `tenant_id NOT NULL` to an existing populated table without backfill — guaranteed migration failure on upgrade.
2. `Chimeway.Workflows.create_initial_run/4` hardcodes `tenant_id: "default"`, undermining the entire tenant isolation property the rest of the phase enforces.
3. `SignalRouterWorker` uses queue `:signals`, which is not declared in the project's Oban config — jobs will be enqueued but never executed.
4. The `route_signal/1` transaction takes `FOR UPDATE` row locks **outside** the transaction that performs the writes, so the locks are released before the update — concurrent signals can double-resume the same waiting run.

Additional warnings cover authorization (no host-supplied tenant verification), missing DB-level indices for the hot signal-routing query, and contract-test gaps (multi-run `route_signal/1` results assertion is too loose).

---

## Critical Issues

### CR-01: Migration adds NOT NULL `tenant_id` without backfill — breaks any host with existing workflow_runs

**File:** `priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs:5-10`
**Issue:** The migration alters `chimeway_workflow_runs` to add `tenant_id` with `null: false`. PostgreSQL will reject this `ALTER TABLE` on any non-empty table because the column has no default and no existing rows can satisfy the constraint. Hosts running the prior phases (24/25/26) will already have `chimeway_workflow_runs` rows in production — running this migration aborts with `ERROR: column "tenant_id" of relation "chimeway_workflow_runs" contains null values` and leaves the database in a half-migrated state.

**Fix:** Add the column nullable, backfill, then enforce NOT NULL in a follow-up step:
```elixir
def change do
  alter table(:chimeway_workflow_runs) do
    add :tenant_id, :string  # nullable initially
    add :suspended_until, :utc_datetime_usec
    add :pending_signals, {:array, :string}, default: []
    add :terminal_reason, :string
  end

  # Backfill: any pre-existing run gets a deterministic tenant. The host can
  # re-tenant later, but the column must be non-null before we set the
  # constraint.
  execute(
    "UPDATE chimeway_workflow_runs SET tenant_id = 'default' WHERE tenant_id IS NULL",
    ""
  )

  alter table(:chimeway_workflow_runs) do
    modify :tenant_id, :string, null: false, from: :string
  end
end
```
Also add `create index(:chimeway_workflow_runs, [:tenant_id, :state])` — see WR-02.

---

### CR-02: `route_signal/1` takes `FOR UPDATE` locks **outside** the write transaction — locks released before update; double-resume race

**File:** `lib/chimeway/workflows.ex:377-412`, helper at `lib/chimeway/workflows.ex:418-428`
**Issue:** `find_runs_waiting_for_signal/2` issues a `Repo.all(... lock: "FOR UPDATE")` query against `Repo` directly (no `Repo.transaction/1` wrapping it). PostgreSQL releases row locks at transaction commit — but there is no enclosing transaction here, so the locks are released the moment the query returns. The subsequent `Repo.transaction(multi)` call on lines 408-411 starts a **new** transaction in which the rows are no longer locked.

Two concurrent `SignalRouterWorker` jobs for the same `(tenant_id, event_name)` (e.g., from a retried Oban job, or from two distinct signals carrying the same `event_name` arriving simultaneously) can each:
1. Read the same waiting run.
2. Open separate `Multi` transactions.
3. Both succeed in updating `state: :active, pending_signals: []` and inserting a `signal_received` transition.

The result is a duplicate `signal_received` transition row for one logical resumption — directly violating the audit-truth promise the moduledoc on lines 357-375 makes ("immutable WorkflowTransition recording the event_name", "atomically consistent").

The idempotency test on lines 178-194 of `workflows_test.exs` only covers the *sequential* case (where the second call legitimately finds no matching runs because the first already updated them). It does not exercise the concurrent case.

**Fix:** Move the locking query **inside** the transaction, then build and execute the per-run mutations within the same transaction:
```elixir
def route_signal(%Signal{tenant_id: tenant_id, event_name: event_name} = _signal)
    when is_binary(tenant_id) and is_binary(event_name) do
  Repo.transaction(fn ->
    matched_runs = find_runs_waiting_for_signal(tenant_id, event_name)
    now = DateTime.utc_now()

    Enum.reduce_while(matched_runs, %{}, fn run, acc ->
      with {:ok, updated_run} <-
             Workflows.update_run(Repo, run, %{
               state: :active,
               pending_signals: [],
               status_reason: "signal_received",
               last_transition_at: now
             }),
           {:ok, transition} <-
             Workflows.append_transition(Repo, %{
               workflow_run_id: run.id,
               from_state: :waiting,
               to_state: :active,
               reason: "signal_received",
               context: %{"event_name" => event_name},
               inserted_at: now
             }) do
        {:cont,
         acc
         |> Map.put({:run_updated, run.id}, updated_run)
         |> Map.put({:transition_inserted, run.id}, transition)}
      else
        {:error, reason} -> {:halt, Repo.rollback(reason)}
      end
    end)
  end)
end
```
The `find_runs_waiting_for_signal/2` query (still using `lock: "FOR UPDATE"`) now runs inside the same transaction as the writes, so the locks are held until commit and the second concurrent worker blocks on the lock and re-reads after the first commits — at which point the runs are already `:active` and `pending_signals == []`, so its `where: ^event_name in wr.pending_signals` no longer matches.

---

### CR-03: `SignalRouterWorker` uses undeclared Oban queue `:signals` — jobs enqueue but never run

**File:** `lib/chimeway/dispatch/signal_router_worker.ex:16`, `config/test.exs:25`
**Issue:** The worker declares `use Oban.Worker, queue: :signals`. The project's Oban configuration declares only `queues: [chimeway_delivery: 10]` (`config/test.exs:25`); there is no `:signals` queue anywhere in `config/`. With Oban's default behavior, jobs inserted into a queue that no Oban instance is configured to drain accumulate in the `oban_jobs` table forever in `:available` state. This means:

* In tests using `Oban.Testing` `:manual` mode the test suite happens to pass because tests use `perform_job/2` directly instead of running the queue (see `signal_router_worker_test.exs:85`, `signal_test.exs:34`).
* In any host environment that runs Oban "for real," every `Chimeway.Signal.track/4` call inserts a job that is never picked up. Workflows stay `:waiting` forever despite a signal having been recorded — the host's product behavior (e.g., advancing on `email_opened`) silently breaks.

This is a textbook "tests pass, prod is dead" defect.

**Fix:** Either align the worker to an existing queue, or add the queue to the application's Oban config. The conventional fix is the latter — Phase 27 introduces a new dispatch surface so it should declare its own queue:
```elixir
# config/config.exs (or wherever the host wires Oban)
config :chimeway, Oban,
  queues: [chimeway_delivery: 10, signals: 5],
  ...
```
Also add the queue to `config/test.exs` and to the host-facing documentation so embedders know to configure it. Alternative naming: rename to `:chimeway_signals` to match the existing `:chimeway_delivery` convention.

---

### CR-04: `create_initial_run/4` hardcodes `tenant_id: "default"` — entire tenant-isolation story collapses for trigger-created runs

**File:** `lib/chimeway/workflows.ex:166`
**Issue:** Phase 27 spends substantial code adding tenant scoping to `route_signal/1`, `explain/2`, and `list_traces/3`. But every `WorkflowRun` born through the trigger pipeline (`Chimeway.Trigger.insert_workflow_runs/2` → `Workflows.create_initial_run/4`) is stamped with the literal string `"default"`. So:

* `Workflows.explain("acme", run.id)` against a real production run returns `{:error, :not_found}` even when the host is querying its own data — because the row's `tenant_id` is `"default"`, not `"acme"`. The inspection API is unusable in any multi-tenant deployment.
* `Workflows.route_signal(%Signal{tenant_id: "acme"})` will not match any of these runs, because the runs are all tenanted to `"default"`. Signals never resume real workflow runs.
* If a host *does* call `Chimeway.Signal.track("default", ...)` to compensate, the entire tenant-isolation property advertised in T-27-03 is null and void — every host shares a single tenant namespace.

The unit tests pass because the test fixtures explicitly set `tenant_id: "acme"` — but no test covers the `create_initial_run` → `explain`/`route_signal` round-trip.

**Fix:** Thread tenant identity from the trigger context. The notification or event already carries enough data; if not, expose an explicit parameter:
```elixir
@spec create_initial_run(
  Ecto.Repo.t(),
  Ecto.UUID.t(),
  WorkflowDefinition.t(),
  DateTime.t(),
  String.t()
) :: {:ok, WorkflowRun.t()} | {:error, term()}
def create_initial_run(repo, notification_id, %WorkflowDefinition{} = definition, timestamp, tenant_id)
    when is_binary(notification_id) and is_binary(tenant_id) do
  ...
  WorkflowRun.changeset(%WorkflowRun{}, %{
    ...
    tenant_id: tenant_id,
    ...
  })
  ...
end
```
Update `Chimeway.Trigger` to pass through the host-provided tenant. Add an end-to-end test: `Trigger.fire/1` → `Workflows.explain(tenant_id, run.id)` returns `{:ok, _}` and `route_signal/1` resumes it. Without this, Phase 27 is functionally inert for any host that isn't also running on the literal string `"default"`.

---

## Warnings

### WR-01: `Chimeway.Signal.track/4` accepts caller-supplied `tenant_id` with no host-side authorization hook

**File:** `lib/chimeway/signal.ex:22-40`
**Issue:** `track/4` accepts an arbitrary `tenant_id` string from the caller and persists it directly. There is no callback, behaviour, or even a doc note instructing the host to verify that the calling principal is authorized to write signals against that tenant. A bug or compromised path in a host endpoint that lets user-controlled data flow into `tenant_id` would let an attacker resume *another tenant's* waiting workflows by submitting a signal with their `event_name` and the victim's `tenant_id` — every other isolation gate (route_signal, explain, list_traces) trusts the persisted tenant_id as truth.

This is a defense-in-depth issue rather than a direct vulnerability (the host owns auth, per AGENTS.md "Preserve host ownership boundaries"), but the moduledoc should make the trust boundary explicit so embedders don't assume Chimeway is checking it.

**Fix:** Add a moduledoc warning calling this trust boundary out, and consider exposing an optional `:authorize` keyword that runs the host's authorization function before the insert. At minimum:
```elixir
@moduledoc """
...
> **Trust boundary:** `track/4` does NOT verify that the caller is authorized
> to record a signal under the supplied `tenant_id`. Hosts must enforce that
> check at their entry point — anyone able to call `track/4` with an arbitrary
> tenant_id can resume waiting workflow runs in that tenant.
"""
```

---

### WR-02: No DB index for the hot `route_signal/1` lookup — table scan + GIN-less array filter on every signal

**File:** `priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs:5-10`
**Issue:** The hot path query in `find_runs_waiting_for_signal/2` (lib/chimeway/workflows.ex:418-428) filters on `tenant_id == ? AND state == :waiting AND ? IN pending_signals` plus a `FOR UPDATE` lock. There's no supporting index — neither a B-tree on `(tenant_id, state)` nor a GIN index on `pending_signals`. Every signal arrival triggers a sequential scan across all `chimeway_workflow_runs` and applies the array-membership predicate per row. At even modest scale (tens of thousands of runs) this becomes the dominant cost of every signal, and the `FOR UPDATE` clause holds locks during the scan.

(Performance is out of v1 scope per the review charter, but I'm flagging this because it affects correctness too: the longer the query takes, the wider the window in which CR-02 can manifest.)

**Fix:** Add two indices in the migration:
```elixir
create index(:chimeway_workflow_runs, [:tenant_id, :state])
create index(:chimeway_workflow_runs, [:pending_signals], using: "GIN")
```
PostgreSQL will combine the B-tree index with the GIN index for the array predicate.

---

### WR-03: `WorkflowRun.changeset/2` does not validate `tenant_id` non-empty

**File:** `lib/chimeway/workflows/workflow_run.ex:54-63`
**Issue:** The schema declares `tenant_id` as required (`@required_fields`), but the changeset never calls `validate_length(:tenant_id, min: 1)` or any other content check. So `WorkflowRun.changeset(%WorkflowRun{}, %{tenant_id: "", ...})` is currently `valid?: true` — only the database `null: false` constraint catches it (and only when the empty string is treated as "not null", which it is in PostgreSQL). The `Signal` schema validates this correctly (`signals/signal.ex:35-37`); the asymmetry will produce mysterious "tenant `""` not found" results in `explain/2`.

**Fix:**
```elixir
|> validate_required(@required_fields)
|> validate_inclusion(:state, @state_values)
|> validate_length(:tenant_id, min: 1)
|> put_default_status_context()
|> ...
```

---

### WR-04: `WorkflowDefinition.changeset` upsert path bypasses `Repo.update` change tracking — `updated_at` set unconditionally even when nothing changes

**File:** `lib/chimeway/workflows.ex:51-54`
**Issue:** Not introduced by this phase, but exposed by the new tenant query. The `on_conflict` clause writes `updated_at: DateTime.utc_now()` every time the upsert runs, even on no-op matches. This produces phantom audit churn that, combined with `route_signal/1` reading `FOR UPDATE`-locked rows, increases lock contention. Lower priority — flagging because it's adjacent code that the new code calls into.

**Fix:** Use `:nothing` on conflict when notification_key is unchanged:
```elixir
on_conflict: {:replace_all_except, [:id, :inserted_at]},
```
Or skip the timestamp update when the new notification_key equals the existing value.

---

### WR-05: Multi-run `route_signal/1` test does not assert per-run keys in the result map

**File:** `test/chimeway/workflows_test.exs:166-175` and `signal_router_worker_test.exs:99-114`
**Issue:** The "routes multiple waiting runs" test asserts only that both runs end in `:active` state — it never checks the *return value's* shape (`{:run_updated, run1.id}`, `{:transition_inserted, run1.id}`, etc.). A regression where `route_signal/1` silently drops one of the runs from the Multi (e.g., key collision after refactor to maps with `run.id` rather than `{:run_updated, run.id}`) would not be caught. The lone shape assertion `assert is_map(results) or is_list(results)` (line 97) is too loose — `{}` and `[]` both pass.

**Fix:** Tighten the assertions:
```elixir
assert {:ok, results} = Workflows.route_signal(signal)
assert Map.has_key?(results, {:run_updated, run1.id})
assert Map.has_key?(results, {:run_updated, run2.id})
assert Map.has_key?(results, {:transition_inserted, run1.id})
assert Map.has_key?(results, {:transition_inserted, run2.id})
```

---

### WR-06: `list_traces/3` accepts `:limit` opt in docstring but silently ignores it

**File:** `lib/chimeway/workflows.ex:325-354`
**Issue:** The `@doc` block on lines 325-327 promises an `:limit` option ("max number of traces to return (default: all)"), but the implementation matches the opts as `_opts \\ []` and never reads them. A caller passing `limit: 100` gets back the full unbounded result and has no signal that the option was a no-op. For long-running workflows with thousands of transitions, this can blow up the inspection caller's heap or response payload.

**Fix:** Either implement it:
```elixir
def list_traces(tenant_id, execution_id, opts \\ [])
    when is_binary(tenant_id) and is_binary(execution_id) do
  limit = Keyword.get(opts, :limit)
  ...
  base_query =
    from(wt in WorkflowTransition,
      where: wt.workflow_run_id == ^execution_id,
      order_by: [asc: wt.inserted_at]
    )

  query = if limit, do: from(q in base_query, limit: ^limit), else: base_query
  ...
end
```
Or remove the option from the docstring and `@spec` until it's wired up.

---

### WR-07: `route_signal/1` emits no transition when `pending_signals` contains the event but `state` is already `:active`

**File:** `lib/chimeway/workflows.ex:418-428`
**Issue:** The worker's contract says it routes the signal to "all waiting workflow runs that are suspended on the signal's `event_name`" (signal_router_worker.ex:3-5). The implementation correctly filters `state == :waiting`, but consider the race: a wait's `due_at` elapses just before a matching signal arrives, so the run's state has already flipped to `:active` via `progress_due_runs/1`. The signal silently does nothing — no transition recorded, no audit trail of why the host's `track/4` call was a no-op for this run. Operators looking at journey traces see "wait elapsed → active", then nothing, with no explanation that a signal was also received and ignored.

This is a behavior-by-omission gap rather than a crash, but it violates Chimeway's core principle ("every notification decision must be explainable") because the signal's effect is invisible.

**Fix:** Either widen the match to `:active` runs and append a no-op `signal_received_after_resume` transition for traceability, or have `track/4` itself write a "signal observed but no waiting runs matched" trace at the tenant level. Document the chosen behavior either way.

---

## Info

### IN-01: `signals/signal.ex` does not validate `event_name` format

**File:** `lib/chimeway/signals/signal.ex:31-38`
**Issue:** `event_name` is a free-form string with no character-set or length-cap validation. A host that accidentally passes a stringified JSON blob, a 1MB string, or a name with embedded whitespace gets stored as-is and routed as-is. Recommend `validate_format(:event_name, ~r/^[a-z0-9_.]+$/i)` and `validate_length(:event_name, max: 255)` to make the routing key well-formed.

---

### IN-02: `Workflows.route_signal/1` log output: returned results map nests `{tuple_key, value}` pairs which are not iterable as JSON

**File:** `lib/chimeway/workflows.ex:373-411`
**Issue:** Returning a map keyed by `{:run_updated, run.id}` and `{:transition_inserted, run.id}` is idiomatic for `Ecto.Multi`, but it means callers cannot serialize the result to JSON for logs/telemetry without first transforming the keys. The `SignalRouterWorker` discards `_results` (line 30), so this is harmless today — but if a future caller wants to emit a `[:chimeway, :signal, :routed]` telemetry event with the results, they'll have to convert. Consider changing to a flat list (`%{updated_runs: [...], transitions: [...]}`) or document the expected key shape in `@spec`.

---

### IN-03: `Signal.changeset` allows arbitrary `payload` map with no size cap

**File:** `lib/chimeway/signals/signal.ex:23-38`
**Issue:** The `payload` field is a `:map` with no size validation. A pathological host could pass a 10MB map (or arbitrarily nested structure) into `track/4`, blowing up Ecto's JSON encoding and PostgreSQL's `jsonb` storage. While T-27-04 (payload safety) is enforced at the transition-context boundary (`route_signal/1` only writes `event_name`), the raw payload is still durably persisted on the `chimeway_signals` row. A `byte_size(:erlang.term_to_binary(payload)) <= some_limit` check would harden the API.

---

### IN-04: `Workflows.explain/2` `pending_signals` and `terminal_reason` defaults are inconsistent

**File:** `lib/chimeway/workflows.ex:289-312`, `lib/chimeway/workflows/workflow_run.ex:30-31`
**Issue:** `pending_signals` defaults to `[]` in the schema, while `terminal_reason` defaults to `nil`. The `explain/2` return type shows `pending_signals: [String.t()]` (never nil) and `terminal_reason: String.t() | nil`. Today this lines up because schema defaults run before the row is inserted — but a row that pre-dated this migration (e.g., one created by Phase 24/25 before the column existed) will read `pending_signals: nil` from the DB despite the schema default, breaking pattern matches downstream. This intersects with CR-01: backfill should also set `pending_signals = '{}'::text[]` for legacy rows.

**Fix:** In the migration backfill (CR-01 fix), include:
```sql
UPDATE chimeway_workflow_runs SET pending_signals = '{}' WHERE pending_signals IS NULL;
```

---

_Reviewed: 2026-04-30_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

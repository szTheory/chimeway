# Phase 14: Delivery Reliability Hardening - Research

**Researched:** 2026-04-26
**Domain:** Oban-driven retry semantics, Ecto migration patterns, state-machine extension for terminal convergence
**Confidence:** HIGH

## Summary

Phase 14 sits squarely in the Elixir/Phoenix/Ecto/Oban ecosystem. All three requirements (REL-01, REL-02, REL-03) are well-served by idiomatic, documented patterns in Oban 2.21.1 (the project's pinned version) — there is no new technology to adopt, no library to add, and no architectural shift required. The work is precise plumbing across the existing `Adapter -> Executor -> Worker -> Deliveries` chain.

The two most decision-critical findings:

1. **There is no `c:Oban.Worker.exhausted/1` callback in OSS Oban 2.21.1.** The canonical pattern is to detect the final attempt inside `perform/1` itself by guarding on `job.attempt == job.max_attempts`. The Oban 2.21.1 docs and source confirm this. Phase 14 must use this in-band detection — there is no out-of-band exhaustion hook to wire.

2. **Return `{:error, reason}` for transient failures, not `{:snooze, n}`.** `:snooze` increments `max_attempts` to "preserve" retries, but `attempt` still increments and Oban's own issue tracker (#476, #245) acknowledges this leads to runaway attempt counts and broken backoff curves. `{:error, reason}` is the documented contract for "this failed, retry under the budget."

**Primary recommendation:** Use `{:error, reason}` from `perform/1` on `:temporary`, detect `job.attempt == job.max_attempts` inline inside `perform/1` to write the `:cancelled` (`suppression_reason: "retries_exhausted"`) terminal state via the same `Ecto.Multi` discipline established in Phase 12, and let Oban's default exponential-with-jitter backoff handle scheduling. Add `attempt_number` and `error_class` columns via an additive migration with a `row_number()` backfill. Replace the three duplicated `@terminal_states` lists with calls to the promoted `Deliveries.terminal_states/0`.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REL-01 | Prevent duplicate events, notifications, deliveries when creation/planning is retried | Existing unique constraints + `on_conflict: :nothing` mechanism (D-01) is the dedup contract. Concurrency assertions follow the established `Task.async_stream + Sandbox.allow` pattern from `idempotency_constraint_test.exs`. `assert_enqueued`/`refute_enqueued` from Oban.Testing covers the dispatch-side contract. |
| REL-02 | Delivery attempts preserve retry history, backoff behavior, terminal failure outcomes | `{:error, reason}` return from `perform/1` triggers Oban's documented retry under `max_attempts: 5`. `attempt_number :integer` and `error_class :string` are added via additive Ecto migration. `perform_job(Worker, args, attempt: N)` from `Oban.Testing` simulates specific attempt numbers without driving the queue. `drain_queue` returns `%{success, failure, snoozed, discard, cancelled}` for state-level assertions. |
| REL-03 | Every delivery resolves to a durable final state | Promoted `Deliveries.terminal_states/0` becomes the single source of truth. `failed -> cancelled` widening (with `suppression_reason: "retries_exhausted"`) is gated to a private transition helper called only from the in-band `job.attempt == job.max_attempts` guard inside `perform/1`. Permanent/bounced classifications also converge to `:cancelled` (with their own reasons). All five terminal paths get regression tests asserting membership in `Deliveries.terminal_states/0`. |
</phase_requirements>

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Duplicate protection contract (REL-01):**
- **D-01:** Existing dedup is locked. Unique constraints on `chimeway_events.idempotency_key`, `chimeway_notifications.(event_id, recipient_identity)`, `chimeway_deliveries.(notification_id, channel)` (with `Deliveries.plan_delivery/3` using `on_conflict: :nothing, conflict_target: [:notification_id, :channel]`) are the dedup mechanism. Phase 14 must NOT redesign this schema or these conflict targets.
- **D-02:** Add explicit duplicate-trigger contract tests covering: (a) `Trigger.fire/...` returning `{:duplicate, event}` on a re-fire; (b) `plan_notifications/2` re-entering cleanly when called twice for the same event (returning the existing pending deliveries without creating duplicate rows); (c) sync and Oban dispatch paths short-circuiting against already-terminal deliveries via the canonical terminal-state helper (D-09); (d) preservation of the Phase 12 atomicity guarantee — partial enqueue failures still roll back planning rows.
- **D-03:** Keep `Trigger.dispatch_after_trigger/4` inert on `{:duplicate, event}` for Phase 14. Do NOT add a "resume dispatch on duplicate" path. Document this contract in module docs and trace explanations.

**Oban-driven retry for transient failures (REL-02):**
- **D-04:** `ObanWorker.perform/1` must trigger Oban retry machinery on transient adapter failures. When `Executor.run_delivery/1` records an attempt classified as `:temporary`, return `{:error, reason}` (default; `{:snooze, n}` only if backoff tuning is justified). On `:permanent`/`:bounced`, return `:ok` so Oban does NOT retry. Successful sends remain `:ok`.
- **D-05:** Preserve `:temporary | :permanent | :bounced` end-to-end. `Executor.classify/1` currently collapses `:temporary -> :failed`. Phase 14 must preserve the classification both in worker return value (for retry) and in the persisted attempt row (D-07).
- **D-06:** Each Oban-driven retry continues to write exactly one `DeliveryAttempt` row through the existing `Executor.run_delivery/1` seam. No change to executor write path.

**Attempt history schema additions (REL-02):**
- **D-07:** Add two columns to `chimeway_delivery_attempts`:
  - `attempt_number :integer` — 1-indexed ordinal of this attempt for its delivery, computed at insert time (in same multi as the attempt insert).
  - `error_class :string` — one of `"temporary" | "permanent" | "bounced"` for `:failed | :rejected | :bounced` outcomes; null for `:succeeded`.
  Migration is additive (nullable + backfill). `DeliveryAttempt` schema and changeset get the new fields. `Executor.classify/1` plumbs `error_class` into `Deliveries.record_attempt/...`. `Traces.last_attempt_summary` exposes both fields.
- **D-08:** Do NOT encode `error_class` or `attempt_number` inside `provider_response` JSON. Operators must query these directly.

**Terminal-state durability (REL-03):**
- **D-09:** Promote `Chimeway.Deliveries.terminal_states/0` as single source of truth. Replace duplicated `@terminal_states` lists in `dispatch/sync.ex:25` and `dispatch/oban_worker.ex:38` with calls to the helper. Do NOT delete the helper.
- **D-10:** Close "`:failed` is not terminal" gap. Add explicit terminal write triggered when Oban exhausts retries: reuse `:cancelled` with new `suppression_reason: "retries_exhausted"` and add `failed -> cancelled` to `@allowed_transitions`. Transition must be guarded so it can only fire from the Oban exhaustion hook, not arbitrary callers.
- **D-11:** Wire exhausted-retries write through canonical Oban callback (per researcher). Write executes within Phase 12's transactional discipline: single multi for state transition + (optional) final attempt log if not already written.
- **D-12:** Every delivery must converge to a state in `Deliveries.terminal_states/0`. Regression tests cover: `:succeeded` (success), `:cancelled` with reason `"retries_exhausted"` (Oban gave up), `:cancelled` with permanent/bounced reason (adapter said don't retry), `:suppressed` (policy), `:cancelled` (manual). Tests assert `Deliveries.terminal_states/0` membership, not hardcoded lists.

**Test rewrites and regressions:**
- **D-13:** Rewrite `test/chimeway/dispatch/oban_worker_test.exs:109-149`. Current test calls `perform_job/2` manually after swapping the adapter. Must become a true Oban retry assertion using `Oban.Testing.assert_enqueued/1` semantics or equivalent.
- **D-14:** Add concurrency regression tests for REL-01 alongside `test/chimeway/idempotency_constraint_test.exs`: concurrent re-fires of same trigger; concurrent `plan_notifications/2` calls for same event; concurrent dispatch re-entry against already-terminal delivery. None must produce duplicate rows or extra attempts.
- **D-15:** Phase 14 must not regress Phase 10 correlation enrichment, Phase 11 string-channel safety, or Phase 12 transactional dispatch atomicity.

### Claude's Discretion

- Whether `perform/1` returns `{:error, reason}` (default Oban backoff) vs `{:snooze, computed_seconds}` (custom curve reading `job.attempt`). Default to `{:error, reason}` unless backoff tuning is justified.
- Exact `error_class` enum representation (string column with whitelist vs Postgres enum vs `Ecto.Enum`) — pick project-idiomatic shape; persisted values must remain `"temporary" | "permanent" | "bounced"`.
- Whether to add new status atom (e.g. `:exhausted`) instead of reusing `:cancelled` with `suppression_reason: "retries_exhausted"`. Reuse `:cancelled` unless researcher surfaces strong reason.
- Migration backfill strategy for `attempt_number` on existing rows — `row_number() over (partition by delivery_id order by inserted_at)` is the obvious fill. `error_class` may be null on historical rows.

### Deferred Ideas (OUT OF SCOPE)

- Self-healing dispatch on `{:duplicate, event}` (resume pending deliveries after crash between event-insert and enqueue) — D-03 explicitly defers.
- Host-app surfaces for manual retry orchestration / re-enqueueing terminal-failed deliveries — INT-* phase territory.
- Hierarchical retry policies per-channel or per-category — Phase 14 uses one Oban backoff schedule.
- Replacing `:failed` non-terminal status with richer state model (`:retrying`, `:exhausted`, `:bounced` as first-class statuses) — D-10 chooses minimal change.
- Metrics dashboards for retry counts, exhaustion rates, error_class distribution — Phase 15 (Observability & Supportability).
</user_constraints>

## Project Constraints (from CLAUDE.md)

`./CLAUDE.md` does not exist in this repository. Inheriting constraints from `.planning/PROJECT.md`:

- **Tech Stack:** Elixir/Phoenix/Ecto-first with Oban and Swoosh integration seams.
- **Architecture:** Stable notification keys persisted as durable identity; avoid module-name coupling.
- **Composability:** Channel/provider integrations use replaceable adapter behaviours.
- **Operability:** Redacted, queryable traces — explainability is core, not optional polish.
- **Quality Bar:** Named `mix verify.*` and `mix ci.*` workflows; `compile --warnings-as-errors`; `credo --strict`; `format --check-formatted`. All Phase 14 code must clear `mix ci`.
- **Compatibility:** Track active Phoenix/Elixir LTS norms; OSS Oban only (no Pro).

Pinned versions verified from `mix.lock`:
- `oban` 2.21.1 [VERIFIED: mix.lock]
- `ecto` 3.13.5 [VERIFIED: mix.lock]
- `ecto_sql` 3.13.5 [VERIFIED: mix.lock]
- `postgrex` 0.22.0 [VERIFIED: mix.lock]
- `jason` 1.4.4 [VERIFIED: mix.lock]
- `telemetry` 1.4.1 [VERIFIED: mix.lock]
- Elixir 1.19.5 / OTP 28 [VERIFIED: `elixir --version`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Duplicate event/notification dedup | Database (unique constraints) | Application (changeset error handling in `Trigger`) | Postgres unique indexes are the only safe concurrent-insert dedup mechanism. App-level checks lose races. |
| Duplicate delivery dedup | Database (unique on `(notification_id, channel)`) | Application (`on_conflict: :nothing` in `plan_delivery/3`) | Same as above; `on_conflict: :nothing` makes the insert idempotent and reload returns canonical row. |
| Retry scheduling and backoff | Oban (queue + retryable state) | Application (worker return value triggers it) | Oban owns the retry timing wheel. Worker only has to return `{:error, reason}`. |
| Final-attempt detection | Application (worker `perform/1` guard) | — | OSS Oban 2.21.1 has no exhaustion callback; in-band `job.attempt == job.max_attempts` guard is the only place to know "this is the last try" before the discard transition. |
| Terminal state convergence | Application (`Deliveries` state machine) | Database (status enum + suppression_reason) | State transitions are guarded by `@allowed_transitions`; the enum value plus reason is the durable explanation. |
| Attempt-row history | Database (append-only `chimeway_delivery_attempts`) | Application (`Executor.run_delivery/1` writes one row per call) | Schema-enforced no-update via no `updated_at`; one-row-per-call is the immutable history contract. |
| Retry-test isolation | Application (Oban.Testing helpers + Ecto Sandbox) | — | `perform_job/3` with explicit `attempt:` option simulates final attempt without queue side effects. `assert_enqueued`/`drain_queue` covers queue-level assertions. |

## Standard Stack

### Core (already pinned)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `oban` | 2.21.1 [VERIFIED: mix.lock, hex.pm release notes] | Background job execution, retry scheduling | OSS standard for Elixir job queues; project already uses it. |
| `ecto` | 3.13.5 [VERIFIED: mix.lock] | Schema, changesets, multi transactions | Core data layer; Phase 12 already establishes multi-based transactional dispatch. |
| `ecto_sql` | 3.13.5 [VERIFIED: mix.lock] | Migrations, sandbox testing | Same. |
| `postgrex` | 0.22.0 [VERIFIED: mix.lock] | PostgreSQL driver | `row_number()` window function (used for backfill) is native Postgres. |

### Supporting (already pinned)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `jason` | 1.4.4 [VERIFIED: mix.lock] | JSON encoding for `provider_response` | Existing dependency; no change needed. |
| `telemetry` | 1.4.1 [VERIFIED: mix.lock] | Span emission | Phase 10 correlation metadata flow continues; new retry/exhaustion telemetry must reuse `Telemetry.safe_meta/1`. |

### Not Adding Anything

Phase 14 introduces zero new dependencies. All work is plumbing across existing modules.

**Version verification step (planner reference):** No `npm view` equivalent — this is an Elixir project. Versions are pinned via `mix.lock`. Verified above.

## Architecture Patterns

### System Architecture Diagram

```
[Trigger.trigger]
       |
       v
[Multi: insert event + notifications] ----------(idempotency_key collision)----> {:duplicate, event}
       |                                                                                |
       | (success path)                                                                 v
       v                                                                          (NO dispatch — D-03)
[dispatch_after_trigger]
       |
       +---> Sync.dispatch                       Oban.dispatch (transactional)
       |          |                                    |
       |          v                                    v
       |   [DeliveryPlanning.plan_notifications]  [Multi: plan_notifications + enqueue_jobs]
       |          |                                    |
       |          | (per delivery, not terminal)       v (commit on success)
       |          v                              [Oban queue: chimeway_delivery]
       |   [Executor.run_delivery]                     |
       |          |                                    | (worker dispatch)
       |          v                                    v
       |   adapter.deliver -> classify/1         [ObanWorker.perform/1]
       |          |                                    |
       |          v                                    v (delivery already-terminal? short-circuit)
       |   [Deliveries.record_attempt           [Executor.run_delivery] (shared seam)
       |    (Multi: insert attempt              [classify -> outcome + error_class]
       |     + transition_status)]              [Deliveries.record_attempt]
       |                                              |
       |                                              | outcome:
       |                                              |   :succeeded -> status :succeeded   (TERMINAL)
       |                                              |   :failed (temporary) -> status :failed
       |                                              |       AND IF job.attempt == job.max_attempts:
       |                                              |          transition failed -> :cancelled
       |                                              |          (suppression_reason: "retries_exhausted")
       |                                              |          return :ok  (don't keep retrying)
       |                                              |       ELSE: return {:error, reason}  (Oban schedules retry)
       |                                              |   :rejected (permanent) ->
       |                                              |          attempt logged with error_class "permanent",
       |                                              |          delivery transitioned :failed -> :cancelled
       |                                              |          (suppression_reason: "permanent_failure")
       |                                              |          return :ok (NO retry)
       |                                              |   :bounced ->
       |                                              |          attempt logged with error_class "bounced",
       |                                              |          delivery transitioned :failed -> :cancelled
       |                                              |          (suppression_reason: "bounced")
       |                                              |          return :ok (NO retry)
       |                                              v
       |                                       [Oban marks job: completed | retryable | discarded]
```

### Recommended File Touch List (planner reference)

```
lib/chimeway/
├── deliveries.ex          # promote terminal_states/0; widen @allowed_transitions; add private exhaust transition; record_attempt persists error_class + attempt_number
├── delivery_attempt.ex    # add attempt_number, error_class fields + changeset validations
├── dispatch/
│   ├── executor.ex        # classify/1 returns {outcome, error_class, detail}; preserve :temporary distinction
│   ├── oban_worker.ex     # use Deliveries.terminal_states/0; in-band job.attempt == job.max_attempts guard; map outcomes to :ok | {:error, reason}
│   └── sync.ex            # use Deliveries.terminal_states/0
├── traces.ex              # last_attempt_summary returns attempt_number + error_class
└── trigger.ex             # docstring on {:duplicate, event} no-dispatch contract (D-03)

priv/repo/migrations/
└── <ts>_add_attempt_number_and_error_class_to_chimeway_delivery_attempts.exs

test/chimeway/
├── dispatch/
│   └── oban_worker_test.exs               # rewrite lines 109-149 (D-13)
├── idempotency_constraint_test.exs        # extend with D-14 concurrency cases
├── reliability/
│   ├── retry_exhaustion_test.exs          # NEW — D-12 final terminal regression
│   ├── duplicate_protection_test.exs      # NEW — D-02 duplicate contract
│   └── terminal_convergence_test.exs      # NEW — every delivery in terminal_states/0
└── traces_test.exs                        # last_attempt_summary surfaces new fields
```

### Pattern 1: Oban perform/1 Return-Value Contract

**What:** Map adapter classification to Oban's documented return values. `{:error, reason}` triggers retry under `max_attempts`; `:ok` does not.
**When to use:** Inside `ObanWorker.perform/1` after `Executor.run_delivery/1` returns.
**Example:**
```elixir
# Source: https://hexdocs.pm/oban/2.21.1/Oban.Worker.html (perform/1 callback)
@impl Oban.Worker
def perform(%Oban.Job{args: %{"delivery_id" => delivery_id}, attempt: attempt, max_attempts: max_attempts}) do
  delivery = Deliveries.get_delivery!(delivery_id)

  if delivery.status in Deliveries.terminal_states() do
    :ok  # Idempotent re-entry; never re-dispatch terminal deliveries.
  else
    case dispatch_delivery(delivery) do
      {:ok, _} ->
        :ok

      # Adapter said "permanent" or "bounced" — terminal-failure write already done
      # inside record_attempt's expanded multi (see Pattern 4 below). Tell Oban to stop.
      {:terminal, _reason} ->
        :ok

      # Adapter said "temporary" — let Oban retry, unless this was the final attempt.
      {:retry, reason} when attempt < max_attempts ->
        {:error, reason}

      {:retry, reason} when attempt == max_attempts ->
        # Final attempt — write terminal :cancelled state with suppression_reason "retries_exhausted"
        # before returning. Use Deliveries.exhaust_delivery/1 (D-10 guarded helper).
        {:ok, _} = Deliveries.exhaust_delivery(delivery)
        # Returning {:error, reason} on max_attempts causes Oban to discard.
        # Returning :ok marks the job completed. Either way, our terminal write has happened.
        # Choose :ok so the job isn't recorded as a failure for telemetry purposes — the delivery
        # itself carries the cancelled+retries_exhausted state, which is the durable explanation.
        :ok
    end
  end
end
```

### Pattern 2: Detecting Final Attempt In-Band

**What:** OSS Oban 2.21.1 has no `exhausted/1` callback. Detect "this is the last try" via `job.attempt == job.max_attempts` guard.
**When to use:** Inside `perform/1` whenever you need to write durable "we gave up" state before returning the result that causes Oban to discard.
**Example:**
```elixir
# Source: https://hexdocs.pm/oban/2.21.1/Oban.Worker.html ("Workers can change perform/1 behavior based on attempt")
# Source: ElixirForum — community-validated pattern (multiple threads cited)
def perform(%Oban.Job{attempt: attempt, max_attempts: max_attempts} = job)
    when attempt == max_attempts do
  # Last chance — write terminal state.
  ...
end

def perform(%Oban.Job{} = job) do
  # Normal path; if this fails, Oban will schedule retry.
  ...
end
```
**Confidence: HIGH** — confirmed by Oban 2.21.1 docs and community pattern. `job.attempt` is **1-indexed** (first execution sees `attempt = 1`); on the Nth execution `attempt = N`. With `max_attempts: 5`, on the 5th execution `attempt == max_attempts == 5`.

### Pattern 3: Additive Ecto Migration with Backfill

**What:** Add nullable columns to an existing table, backfill via SQL, then optionally tighten constraints in a follow-up migration.
**When to use:** Adding `attempt_number` and `error_class` to `chimeway_delivery_attempts` without breaking existing rows.
**Example:**
```elixir
# Source: existing project pattern — priv/repo/migrations/20260424093908_add_correlation_id_to_chimeway_events.exs
# Combined with Ecto 3.13 idiom for execute/2 backfill
defmodule Chimeway.Repo.Migrations.AddAttemptNumberAndErrorClassToChimewayDeliveryAttempts do
  use Ecto.Migration

  def up do
    alter table(:chimeway_delivery_attempts) do
      add :attempt_number, :integer, null: true
      add :error_class, :string, null: true
    end

    # Backfill attempt_number for existing rows using a window function.
    # Postgres-only; the project pins postgrex and uses Postgres exclusively.
    execute(
      """
      UPDATE chimeway_delivery_attempts AS a
      SET attempt_number = sub.rn
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY delivery_id ORDER BY inserted_at) AS rn
        FROM chimeway_delivery_attempts
      ) AS sub
      WHERE a.id = sub.id;
      """,
      # `down` reverse — just clear the columns.
      "UPDATE chimeway_delivery_attempts SET attempt_number = NULL;"
    )

    # error_class stays NULL for historical rows; cannot be derived from existing data.
    # Optional: index for operator queries on error_class distribution.
    create index(:chimeway_delivery_attempts, [:error_class])
  end

  def down do
    drop index(:chimeway_delivery_attempts, [:error_class])

    alter table(:chimeway_delivery_attempts) do
      remove :error_class
      remove :attempt_number
    end
  end
end
```
**Important:** `attempt_number` stays **nullable at the column level** — making it `NOT NULL` would force a default for backfill, and the multi-step "alter -> backfill -> tighten" pattern adds a second migration for marginal value. The changeset can `validate_required(:attempt_number)` to enforce it on **new** rows without a database constraint that the backfill would break.

**Confidence: HIGH** — Postgres `ROW_NUMBER() OVER (PARTITION BY ...)` is documented stable SQL. `execute/2` is standard Ecto migration API.

### Pattern 4: Computing attempt_number Inside the Same Multi

**What:** Compute `attempt_number` at insert time atomically, not at read time. Avoids race conditions where two concurrent perform_job calls would both compute `count + 1` and tie.
**When to use:** Inside `Deliveries.record_attempt/2`, in the same `Ecto.Multi` that inserts the attempt.
**Example:**
```elixir
# Source: project Multi pattern — lib/chimeway/deliveries.ex record_attempt/2
# The new step computes the next ordinal *inside* the transaction so the SELECT runs
# under the same connection as the INSERT.
def record_attempt(%Delivery{} = delivery, attrs) do
  Multi.new()
  |> Multi.run(:next_attempt_number, fn repo, _changes ->
    next_n =
      from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id, select: count(a.id))
      |> repo.one()
      |> Kernel.+(1)
    {:ok, next_n}
  end)
  |> Multi.insert(:attempt, fn %{next_attempt_number: n} ->
    DeliveryAttempt.changeset(%DeliveryAttempt{}, Map.put(attrs, :attempt_number, n))
  end)
  |> Multi.run(:delivery, fn _repo, _changes ->
    transition_status(delivery, delivery_status_for(attrs))
  end)
  |> Repo.transaction()
end
```

**Edge case:** Two concurrent calls *can still race* unless we serialize them. The existing `Executor.run_delivery/1` already transitions delivery `pending -> dispatched` before recording the attempt; that transition acts as a serialization point because two concurrent transitions on the same row will conflict at the database level. **Verify this with the D-14 concurrency tests.** If a race is observed in test, escalate to a row-level lock (`for_update: true` on the delivery row inside the multi).

**Confidence: MEDIUM** — pattern is sound, but the concurrency test in D-14 must explicitly verify that two simultaneous `record_attempt` calls cannot produce two attempts with the same `attempt_number`. If they can, the planner needs an explicit row lock task.

### Pattern 5: State-Machine Widening with Guarded Transition

**What:** Add `failed -> cancelled` to `@allowed_transitions`, but expose the transition only through a private helper that documents the single legitimate caller.
**When to use:** D-10's exhaustion write.
**Example:**
```elixir
# In lib/chimeway/deliveries.ex

@allowed_transitions %{
  pending: [:dispatched, :suppressed, :cancelled],
  dispatched: [:succeeded, :failed, :suppressed],
  failed: [:dispatched, :cancelled]   # <-- widened (D-10)
}

@doc """
Transitions a `:failed` delivery to `:cancelled` with `suppression_reason: "retries_exhausted"`.
This is the ONLY entry point for the `failed -> cancelled` transition. It must be called
exclusively from `Chimeway.Dispatch.ObanWorker.perform/1` when `job.attempt == job.max_attempts`.
"""
@spec exhaust_delivery(Delivery.t()) :: {:ok, Delivery.t()} | {:error, term()}
def exhaust_delivery(%Delivery{status: :failed} = delivery) do
  metadata =
    delivery.metadata
    |> ensure_metadata_map()
    |> Map.put("policy_checkpoint", "perform")

  delivery
  |> change(status: :cancelled, suppression_reason: "retries_exhausted", metadata: metadata)
  |> Repo.update()
end

def exhaust_delivery(%Delivery{status: status}),
  do: {:error, {:invalid_exhaust_from, status}}
```
**Confidence: HIGH** — the project already uses the named-helper-with-guard pattern (`suppress_delivery/2` and `suppress_delivery/3`). Adding `exhaust_delivery/1` is consistent with the existing idiom.

### Pattern 6: Concurrency Tests via Task.async_stream + Sandbox.allow

**What:** Project's established pattern for concurrent-write tests.
**When to use:** D-14 concurrency assertions.
**Example:**
```elixir
# Source: test/chimeway/idempotency_constraint_test.exs (existing pattern)
test "concurrent re-fires of the same trigger produce one event" do
  parent = self()

  results =
    1..10
    |> Task.async_stream(
      fn _attempt ->
        Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
        Trigger.trigger(IdempotentNotifier, %{}, idempotency_key: "concurrent-key")
      end,
      ordered: false,
      max_concurrency: 10,
      timeout: 15_000
    )
    |> Enum.map(fn {:ok, result} -> result end)

  assert Enum.count(results, &match?({:ok, _}, &1)) == 1
  assert Enum.count(results, &match?({:duplicate, _}, &1)) == 9
  # ... assert single canonical row in DB
end
```
**Confidence: HIGH** — pattern is in active use and verified.

### Pattern 7: Oban.Testing Helpers for Retry Assertion (D-13 Rewrite)

**What:** Replace manual swap-the-adapter-twice retry simulation with the Oban-native assertion API.
**When to use:** Rewriting `oban_worker_test.exs:109-149` per D-13.
**Example:**
```elixir
# Source: https://hexdocs.pm/oban/2.21.1/Oban.Testing.html
use Oban.Testing, repo: Chimeway.Repo

test "transient failure causes Oban to schedule a retry" do
  Application.put_env(:chimeway, :adapter, Chimeway.Test.ObanWorkerFailingAdapter)
  %{delivery: delivery} = create_pending_delivery()

  # First execution — adapter returns :temporary, worker returns {:error, _}.
  # perform_job returns the {:error, _} tuple as-is (does not raise).
  assert {:error, _reason} = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 1)

  # Delivery row state-machine assertion: status is :failed (not yet :cancelled,
  # because attempt 1 != max_attempts).
  updated = Deliveries.get_delivery!(delivery.id)
  assert updated.status == :failed
  assert updated.suppression_reason == nil

  # Attempt-row assertion: one row written with error_class "temporary".
  [attempt] = Repo.all(from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id))
  assert attempt.outcome == :failed
  assert attempt.error_class == "temporary"
  assert attempt.attempt_number == 1
end

test "exhaustion: final attempt writes :cancelled with retries_exhausted" do
  Application.put_env(:chimeway, :adapter, Chimeway.Test.ObanWorkerFailingAdapter)
  %{delivery: delivery} = create_pending_delivery()

  # Simulate the 5th (final) attempt directly — Oban.Testing.perform_job/3 supports `attempt:`.
  # This avoids needing to drain a real queue across simulated backoff intervals.
  assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 5)

  updated = Deliveries.get_delivery!(delivery.id)
  assert updated.status == :cancelled
  assert updated.suppression_reason == "retries_exhausted"
  assert updated.status in Deliveries.terminal_states()
end

test "after enqueue, a transient-failing job remains in retryable state" do
  # Higher-fidelity end-to-end retry assertion using drain_queue.
  # Adapter is configured to fail on every call; queue drains until max_attempts is reached.
  Application.put_env(:chimeway, :adapter, Chimeway.Test.ObanWorkerFailingAdapter)
  %{delivery: delivery} = create_pending_delivery()

  {:ok, _job} = ObanWorker.new(%{delivery_id: delivery.id}) |> Oban.insert()
  assert_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})

  # drain_queue executes all available jobs (including those that become retryable
  # after their backoff elapses, when with_scheduled is true). Returns counts by terminal state.
  result = Oban.drain_queue(queue: :chimeway_delivery, with_scheduled: true, with_recursion: true)

  # Five attempts, all errored — Oban discards on the 5th.
  # But our perform/1 returns :ok on the final attempt (after writing :cancelled),
  # so result.success will be 1 (the final attempt) and result.failure will be 4.
  assert result.failure == 4
  assert result.success == 1
end
```

**Important on `:ok` vs `{:error, _}` on final attempt:** If the worker returns `{:error, _}` on the final attempt, Oban marks the job `:discarded` (which appears in `drain_queue` as `discard`). If the worker returns `:ok` (after writing the durable cancelled state), the job is marked `:completed`. The latter is recommended — the delivery row carries the durable explanation, and we don't want operator dashboards to show "discarded jobs" for cases we already accounted for.

**Confidence: HIGH** — `perform_job/3` accepting `attempt:` is documented in Oban 2.21.1; `drain_queue` return shape is documented; `assert_enqueued` is documented.

### Anti-Patterns to Avoid

- **Adding `c:Oban.Worker.exhausted/1`-style callback.** It does not exist in OSS Oban 2.21.1. If you find Oban Pro material referencing such a callback, ignore it — this project is OSS-only.
- **Returning `{:snooze, n}` from `perform/1` for transient failures.** `:snooze` increments `attempt` AND `max_attempts`, breaking the "exactly N retries" budget Phase 14 wants. Use `{:error, reason}` and let Oban's built-in `c:backoff/1` schedule.
- **Computing `attempt_number` at read time** (e.g., `Repo.aggregate(..., :count) + 1` in the changeset). This races under concurrent perform_job calls. Compute inside the multi as in Pattern 4, and rely on the `pending -> dispatched` transition to serialize.
- **Atom creation from runtime strings** (Phase 11 rule). Do not introduce `String.to_atom/1` or `String.to_existing_atom/1` for `error_class` in any path — the column is a string and the changeset whitelists string values.
- **Forking sync vs Oban behavior.** Phase 11 established `Executor.run_delivery/1` as the shared seam. Phase 14's `error_class` plumbing must flow through the shared seam — sync dispatch records the same fields even though it doesn't drive Oban retries.
- **Using `Ecto.Enum` for `error_class` if the column is a plain `:string`.** Mixing them confuses introspection. Either use `Ecto.Enum` (with a migration default) OR a string column with an explicit changeset whitelist — pick one and document. The CONTEXT says "persisted values must remain `temporary | permanent | bounced`" — recommendation is **string column + changeset whitelist** for symmetry with the existing `outcome` field representation choices and minimum migration churn.
- **Hardcoding `[:succeeded, :suppressed, :cancelled]` in tests.** D-09 promotes `Deliveries.terminal_states/0`; tests must assert membership in the helper, not in a duplicated list.
- **Re-driving dispatch on `{:duplicate, event}`.** D-03 explicitly defers this; document the contract in module docs and trace explanations as inert.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Retry scheduling | Custom GenServer with `:timer.send_after` | Oban's built-in retry + backoff machinery | Oban handles persistence, backoff, jitter, distributed coordination — all things a custom scheduler will get wrong. |
| Final-attempt detection | `Process` dictionary or ETS counter | `job.attempt == job.max_attempts` guard inside `perform/1` | The job struct already carries the data; introducing process state is a leaky abstraction. |
| Backoff curve | Custom math in `c:backoff/1` | Default `Oban.Worker.backoff/1` | Default is exponential with jitter and 15s padding — well-tested for transient SaaS adapter failures. Tune only if the project ships with measured evidence the default is wrong. |
| Concurrent insert dedup | Application-level "check then insert" | Postgres unique constraints + `on_conflict: :nothing` | Project already does this for events/notifications/deliveries (D-01). The only correct concurrent dedup. |
| `attempt_number` ordering | Reading `inserted_at` and sorting at trace time | Persist `attempt_number :integer` via window function backfill + multi-time computation on insert | Deterministic, queryable, and avoids timestamp-precision tie issues. |
| Test simulation of "this is attempt N" | Manually swapping adapter and re-calling `perform_job` | `Oban.Testing.perform_job/3` with `attempt: N` option | Built-in API (Oban 2.21.1 docs); avoids brittle adapter-swap dance in `oban_worker_test.exs:127-149`. |
| State-machine validation | Hand-rolled `if/case` validating allowed states | Existing `@allowed_transitions` map + `transition_status/2` | Pattern is established and tested. D-10 widens it; doesn't replace it. |

**Key insight:** Phase 14 is plumbing across known good substrates (Oban, Ecto.Multi, Postgres unique indexes). Every "build a thing" instinct should be checked against "is there an existing seam?" first.

## Runtime State Inventory

> Phase 14 is not a rename/refactor/migration phase. **Section omitted by Step 2.5 trigger rule.**
>
> Note: the `attempt_number` backfill in Pattern 3 is a data migration, but it's a one-time data shape change for new schema columns, not the "renamed string lives in 5 different runtime stores" risk that Step 2.5 targets.

## Common Pitfalls

### Pitfall 1: Returning `{:error, reason}` on the final attempt creates "discarded" telemetry noise

**What goes wrong:** Operators watching the `[:oban, :job, :exception]` telemetry stream see the final attempt as a failure event, even though our delivery state correctly recorded `:cancelled` with `"retries_exhausted"`. Dashboard rates show inflated "discarded" counts.
**Why it happens:** `{:error, reason}` on the final attempt causes Oban to record the error and mark the job `:discarded`. From Oban's point of view, the worker did fail.
**How to avoid:** On the final attempt, after writing the `:cancelled` terminal state via `Deliveries.exhaust_delivery/1`, return `:ok` so Oban marks the job `:completed`. The delivery row is the durable explanation; the Oban job is just the executor.
**Warning signs:** Looking at `Oban.drain_queue` results in tests — the `failure`/`discard` count vs `success` count tells you which path the worker took on the final attempt.

### Pitfall 2: Sync dispatch path doesn't write `:cancelled` on permanent/bounced

**What goes wrong:** D-12 requires every delivery to converge to a terminal state. Sync dispatch goes through `Executor.run_delivery/1`, which records an attempt and transitions to `:failed`. Today, sync has no follow-up step that turns `:failed` into `:cancelled` for permanent/bounced. So sync deliveries with permanent/bounced outcomes stay non-terminal forever.
**Why it happens:** Phase 14's exhaustion write is wired through the Oban worker, but permanent/bounced are not exhaustion — they're "adapter said don't retry on the first attempt."
**How to avoid:** Move the permanent/bounced -> `:cancelled` transition into `Deliveries.record_attempt/2` itself, gated by `error_class`. This makes both sync and Oban paths converge on a terminal state without forking. Suppression reason is `"permanent_failure"` or `"bounced"`.
**Warning signs:** D-12 regression test for sync-path permanent/bounced fails because delivery is `:failed`, not in `terminal_states/0`.

### Pitfall 3: Concurrent `record_attempt` calls produce duplicate `attempt_number` values

**What goes wrong:** Two simultaneous worker executions for the same delivery (which CAN happen if Oban unique config drifts or in test races) both compute `count(*) + 1 = 2`, and both insert attempts with `attempt_number = 2`.
**Why it happens:** Reading the count and inserting are two operations even inside a multi; without a row lock they're not serialized.
**How to avoid:** Rely on the `pending -> dispatched` transition that already occurs in `Executor.run_delivery/1` — that update will conflict at the database level for the second concurrent caller. **Verify via a D-14 concurrency test** that explicitly fires two `record_attempt` calls in parallel against the same delivery and asserts no duplicate `attempt_number`. If the verification fails, escalate to `lock("FOR UPDATE")` on the delivery row inside the multi.
**Warning signs:** D-14 test asserting "10 concurrent perform_job calls produce at most one attempt per attempt_number" fails or flakes.

### Pitfall 4: The `unique: [period: 60]` Oban config and retry interaction

**What goes wrong:** `ObanWorker` already declares `unique: [fields: [:args], keys: [:delivery_id], period: 60]`. After a transient failure, Oban schedules a retry. If a host app re-fires the trigger within 60 seconds, the unique constraint blocks re-enqueuing, but does NOT block the existing retryable job from running. The retry will fire the original delivery_id, which may be already-terminal by then if the host app cancelled it through some other path.
**Why it happens:** Oban uniqueness is on inserts, not on already-enqueued jobs.
**How to avoid:** This is already handled by the worker's terminal-state short-circuit (D-09). The pre-existing test at `oban_worker_test.exs:75-105` proves it. **Phase 14 must not regress this.** D-15 requires that proof to keep passing.
**Warning signs:** "INTG-02: oban worker uses channel_adapter_configs" or terminal-state short-circuit tests fail.

### Pitfall 5: Trigger re-fire short-circuits dispatch but pending deliveries stay stranded

**What goes wrong:** First trigger inserts event + notifications, but enqueue fails. Phase 12's transactional dispatch rolls back delivery rows AND the event/notification. So far so good. BUT: if the first call inserts event+notifications successfully and then a *crash* happens between event-insert commit and the dispatcher being called, deliveries are never planned. A re-fire returns `{:duplicate, event}` and per D-03 does NOT re-drive dispatch. The deliveries are now stranded.
**Why it happens:** Phase 12's transaction wraps planning + enqueue but not event creation; Phase 14 does not re-drive dispatch on duplicate (D-03 explicitly defers).
**How to avoid:** Phase 14 cannot fix this — D-03 puts it explicitly out of scope. Phase 14's job is to make this contract **explicit in module docs and trace surfaces** so operators understand the gap. The fix is a future operability/recovery phase.
**Warning signs:** None in Phase 14 — this is documented behavior. But the planner must add docstrings on `Trigger.trigger/3` and `Trigger.dispatch_after_trigger/4` calling out this contract, and the trace `Explanation` should surface "no deliveries planned (event was duplicate)" for forensic clarity.

### Pitfall 6: Replacing `@terminal_states` lists naively breaks compile order

**What goes wrong:** `dispatch/sync.ex` and `dispatch/oban_worker.ex` use `@terminal_states` as a module attribute, which is evaluated at compile time. Replacing with `Deliveries.terminal_states()` (a function call) means the value is evaluated at runtime. Pattern matches like `def dispatch_delivery(%{status: status} = delivery) when status in @terminal_states` will need to be rewritten.
**Why it happens:** `when` guards cannot call arbitrary functions — `in` works for compile-time lists or non-bound function calls.
**How to avoid:** Convert pattern-match guards to plain `if`/`case` statements. For sync.ex line 57 `def dispatch_delivery(%{status: status} = delivery) when status in @terminal_states`: rewrite as `def dispatch_delivery(%{status: status} = delivery) do; if status in Deliveries.terminal_states(), do: ..., else: ... end`.
**Warning signs:** Compilation errors saying "cannot invoke remote function in guard."

## Code Examples

### Example: Wiring error_class through Executor

```elixir
# lib/chimeway/dispatch/executor.ex
def run_delivery(%Delivery{} = delivery) do
  with {:ok, dispatched} <- Deliveries.transition_status(delivery, :dispatched) do
    adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    adapter_config = ChannelAdapterConfig.resolve(delivery.channel, [])

    {attempt_outcome, error_class, provider_response} =
      dispatched
      |> adapter.deliver(adapter_config)
      |> classify()

    Deliveries.record_attempt(dispatched, %{
      outcome: attempt_outcome,
      error_class: error_class,
      provider_response: provider_response
    })
  end
end

defp classify({:ok, meta}), do: {:succeeded, nil, meta}
defp classify({:error, :temporary, detail}), do: {:failed, "temporary", detail}
defp classify({:error, :permanent, detail}), do: {:rejected, "permanent", detail}
defp classify({:error, :bounced, detail}), do: {:bounced, "bounced", detail}
```

### Example: DeliveryAttempt changeset whitelist

```elixir
# lib/chimeway/delivery_attempt.ex
@error_classes ~w(temporary permanent bounced)

schema "chimeway_delivery_attempts" do
  field(:outcome, Ecto.Enum, values: [:succeeded, :failed, :bounced, :rejected])
  field(:provider_response, :map)
  field(:attempt_number, :integer)         # NEW
  field(:error_class, :string)             # NEW — string + whitelist (not Ecto.Enum)
  field(:inserted_at, :utc_datetime_usec)

  belongs_to(:delivery, Chimeway.Delivery)
end

@required_fields ~w(delivery_id outcome attempt_number)a
@optional_fields ~w(provider_response error_class)a

def changeset(attempt, attrs) do
  attempt
  |> cast(attrs, @required_fields ++ @optional_fields)
  |> validate_required(@required_fields)
  |> validate_inclusion(:error_class, @error_classes)
  |> validate_attempt_number_positive()
  |> put_inserted_at()
end

defp validate_attempt_number_positive(changeset) do
  case get_field(changeset, :attempt_number) do
    n when is_integer(n) and n >= 1 -> changeset
    nil -> changeset
    _ -> add_error(changeset, :attempt_number, "must be a positive integer")
  end
end
```

### Example: Promoted terminal_states/0 usage in sync.ex

```elixir
# lib/chimeway/dispatch/sync.ex (replace @terminal_states list)
defp dispatch_delivery(%{status: status} = delivery) do
  if status in Deliveries.terminal_states() do
    {:ok, delivery}
  else
    case Policy.evaluate(delivery, check_read_state: delivery.delay_fallback) do
      {:suppress, reason} -> Deliveries.suppress_delivery(delivery, reason, checkpoint: :perform)
      {:ok, :proceed} -> do_dispatch_with_telemetry(delivery)
    end
  end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `c:Oban.Worker.exhausted/1` callback (rumored / from Pro extensions) | In-band `job.attempt == job.max_attempts` guard inside `perform/1` | Always — never existed in OSS Oban | Phase 14 must use the in-band guard. |
| Manually swapping adapter and calling `perform_job/2` to simulate retry | `perform_job/3` with explicit `attempt: N` option | Oban 2.x | D-13 rewrites `oban_worker_test.exs:127-149` using this. |
| `[:oban, :failure]` telemetry event | `[:oban, :job, :exception]` | Oban 2.0 upgrade | Already in use; no change for Phase 14. |
| `perform/2` callback | `perform/1` taking `Oban.Job` struct | Oban 2.0 upgrade | Already in use; pattern-match `%Oban.Job{}` directly. |
| `Oban.Job.attempt` 0-indexed | 1-indexed (first execution has `attempt: 1`) | Always — confirmed via current docs | Critical for `attempt == max_attempts` guard. |

**Deprecated/outdated:**
- Nothing material to Phase 14. The Oban API surface used here (`perform/1`, `assert_enqueued`, `drain_queue`, `perform_job/3`) is stable across the 2.x line and the 2.21.1 docs match what's in the project.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Computing `attempt_number` via `count(*) + 1` inside `Multi.run` is sufficient because the `pending -> dispatched` row update serializes concurrent callers | Pattern 4, Pitfall 3 | Concurrent perform_job calls could produce duplicate `attempt_number` values. Mitigation: D-14 concurrency test explicitly verifies; if it flakes, escalate to `for_update: true`. |
| A2 | Returning `:ok` from `perform/1` on the final attempt (after writing `:cancelled`) is preferred over returning `{:error, reason}` because operator dashboards should not see "discarded" jobs for cases we already accounted for | Pitfall 1 | If the host app's telemetry conventions actually want `:discard` to fire on retry exhaustion, our recommendation is wrong. Mitigation: discuss with maintainer if telemetry semantics matter beyond Phase 14 scope; planner should make this explicit in module docs. |
| A3 | Permanent/bounced should converge to `:cancelled` via `record_attempt`-driven multi (not via worker logic), so sync and Oban paths share the same terminal-write path | Pitfall 2 | If sync and Oban diverge on this, D-12 regression tests fail for sync. Mitigation: Pattern 4's example puts the convergence inside `record_attempt` so it works for both paths. Verify with D-12 sync-permanent and sync-bounced regression tests. |
| A4 | `Oban.Testing.perform_job/3` with explicit `attempt:` option does NOT mutate the queue or insert a job row — it strictly executes `perform/1` with a synthetic `%Oban.Job{}` | Pattern 7 | If `perform_job/3` actually persists a job row, D-13's test will leak rows into other tests. Verified via the public docstring quoted from Oban 2.21.1 ("constructs a job and executes it"); risk is low. |
| A5 | `Deliveries.terminal_states/0` is safe to call from inside guard contexts via `if`/`case` rather than `when` clauses, because converting guards to plain conditionals does not change behavior under the project's existing dispatch tests | Pitfall 6 | If any callsite relies on `when` clause exhaustiveness checking, the conversion silently changes the dispatch table. Mitigation: planner audits every replaced `@terminal_states` usage and writes a regression test for the changed function. |
| A6 | `:snooze` is unsuitable for REL-02's "exactly 5 retries before exhaustion" budget because attempt counter still increments | Anti-Patterns | Confirmed via Oban issues #245 and #476 (community-acknowledged); confidence HIGH. |

**Risk summary:** A1 and A3 are the two assumptions the planner should explicitly turn into test-driven verifications. A2 is a doc-level clarification. A4-A6 are low-risk verified findings.

## Open Questions

1. **Should `:permanent` adapter outcomes write `suppression_reason: "permanent_failure"` or `"rejected"`?**
   - What we know: Adapter outcome enum is `:rejected` for permanent. Suppression reasons today are free-form strings.
   - What's unclear: Whether operators expect `"rejected"` (mirroring the outcome name) or `"permanent_failure"` (mirroring the error_class).
   - Recommendation: Use `"permanent_failure"` and `"bounced"` to match the `error_class` taxonomy — operators will correlate suppression_reason with error_class on traces. Planner should make this explicit and update `Deliveries.suppress_delivery/3` whitelist if there is one.

2. **Does the existing `Oban.drain_queue` execute retryable jobs after their backoff elapses?**
   - What we know: `drain_queue` accepts `with_scheduled` and `with_recursion` options.
   - What's unclear: Whether `with_scheduled: true` includes jobs in the retryable state (which is technically scheduled into the future via backoff) or only jobs explicitly scheduled by `schedule_in`.
   - Recommendation: Planner verifies with a small spike test before relying on `drain_queue` for end-to-end retry assertion. Falls back to `perform_job/3` with explicit attempt simulation (Pattern 7) which is documented to work.

3. **Should the rewritten oban_worker_test.exs:109-149 keep the manual two-step adapter swap as a complementary test?**
   - What we know: D-13 says to rewrite using "real Oban-driven retry" semantics.
   - What's unclear: Whether the existing two-step adapter-swap test (which proves the seam works) is worth keeping alongside the new assertion, or replaced entirely.
   - Recommendation: Replace entirely. The new `perform_job/3 attempt: N` pattern (Pattern 7) is more direct and reads cleaner. The two-step pattern was a workaround for missing semantics that now exist.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | All implementation | ✓ | 1.19.5 | — |
| Erlang/OTP | All implementation | ✓ | 28 (erts-16.3) | — |
| Mix | Build/test | ✓ | 1.19.5 | — |
| Oban (compiled in deps) | REL-02 retry, REL-03 exhaustion | ✓ | 2.21.1 | — |
| Ecto | Schema/migrations | ✓ | 3.13.5 | — |
| Postgrex | Postgres driver, `ROW_NUMBER()` backfill | ✓ | 0.22.0 | — |
| PostgreSQL | Database with window functions | Assumed available (project Postgres-only) | — | — |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.19.5 stdlib) + `Oban.Testing` 2.21.1 + `Ecto.Adapters.SQL.Sandbox` 3.13.5 |
| Config file | `test/test_helper.exs` (existing); `mix.exs` aliases `ci.test: ["test"]` |
| Quick run command | `mix test test/chimeway/dispatch/oban_worker_test.exs` (single file) |
| Full suite command | `mix test` (all phases) |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REL-01 | `Trigger.trigger` returns `{:duplicate, event}` on serial re-fire | unit | `mix test test/chimeway/idempotency_constraint_test.exs:29` | exists |
| REL-01 | Concurrent re-fires produce one canonical row | unit/concurrency | `mix test test/chimeway/idempotency_constraint_test.exs:49` | exists |
| REL-01 | `plan_notifications/2` is idempotent on re-entry for same event | unit | `mix test test/chimeway/reliability/duplicate_protection_test.exs::"plan_notifications re-entry"` | Wave 0 |
| REL-01 | Sync dispatch short-circuits on terminal delivery | unit | `mix test test/chimeway/dispatch/sync_test.exs::"terminal short-circuit"` | exists (extend) |
| REL-01 | Oban dispatch short-circuits on terminal delivery | unit | `mix test test/chimeway/dispatch/oban_worker_test.exs::"terminal state short-circuit"` | exists |
| REL-01 | Phase 12 transactional rollback still rolls back planning rows | unit | `mix test test/chimeway/dispatch/oban_transactional_test.exs` | exists |
| REL-01 | Concurrent `plan_notifications/2` for same event produces no duplicates | concurrency | `mix test test/chimeway/reliability/duplicate_protection_test.exs::"concurrent plan re-entry"` | Wave 0 |
| REL-01 | Concurrent dispatch re-entry against terminal delivery records no extra attempts | concurrency | `mix test test/chimeway/reliability/duplicate_protection_test.exs::"concurrent terminal re-entry"` | Wave 0 |
| REL-02 | Transient failure causes Oban to schedule retry (return `{:error, _}`) | unit | `mix test test/chimeway/dispatch/oban_worker_test.exs::"perform/1 transient retry"` | Wave 0 (rewrite) |
| REL-02 | Permanent failure does NOT trigger retry (return `:ok`, status converges) | unit | `mix test test/chimeway/dispatch/oban_worker_test.exs::"perform/1 permanent terminal"` | Wave 0 |
| REL-02 | Bounced failure does NOT trigger retry (return `:ok`, status converges) | unit | `mix test test/chimeway/dispatch/oban_worker_test.exs::"perform/1 bounced terminal"` | Wave 0 |
| REL-02 | `attempt_number` is 1-indexed and contiguous per delivery | unit | `mix test test/chimeway/reliability/attempt_history_test.exs::"attempt_number ordinality"` | Wave 0 |
| REL-02 | `error_class` persists `"temporary" \| "permanent" \| "bounced"`; nil on success | unit | `mix test test/chimeway/reliability/attempt_history_test.exs::"error_class taxonomy"` | Wave 0 |
| REL-02 | Concurrent `record_attempt` calls do not duplicate `attempt_number` | concurrency | `mix test test/chimeway/reliability/attempt_history_test.exs::"concurrent attempt_number"` | Wave 0 |
| REL-02 | `Traces.last_attempt_summary` exposes both new fields | unit | `mix test test/chimeway/traces_test.exs::"last_attempt includes attempt_number and error_class"` | exists (extend) |
| REL-02 | Final attempt (job.attempt == max_attempts) writes `:cancelled` retries_exhausted | unit | `mix test test/chimeway/dispatch/oban_worker_test.exs::"final attempt exhausts"` | Wave 0 |
| REL-02 | drain_queue end-to-end: 5 retries then terminal | integration | `mix test test/chimeway/reliability/retry_exhaustion_test.exs::"end-to-end exhaustion"` | Wave 0 |
| REL-03 | Promoted `terminal_states/0` is the single source of truth (sync uses it) | unit | `mix test test/chimeway/dispatch/sync_test.exs::"uses Deliveries.terminal_states/0"` | exists (extend) |
| REL-03 | Promoted `terminal_states/0` is the single source of truth (Oban uses it) | unit | `mix test test/chimeway/dispatch/oban_worker_test.exs::"uses Deliveries.terminal_states/0"` | exists (extend) |
| REL-03 | `failed -> cancelled` transition allowed via `exhaust_delivery/1` only | unit | `mix test test/chimeway/deliveries_test.exs::"exhaust_delivery transition"` | Wave 0 |
| REL-03 | `transition_status(failed_delivery, :cancelled)` (general path) is rejected | unit | `mix test test/chimeway/deliveries_test.exs::"failed->cancelled requires exhaust_delivery"` | Wave 0 |
| REL-03 | Every terminal path lands in `Deliveries.terminal_states/0` (success) | unit | `mix test test/chimeway/reliability/terminal_convergence_test.exs::"succeeded path"` | Wave 0 |
| REL-03 | Every terminal path lands in `terminal_states/0` (retries_exhausted) | unit | `mix test test/chimeway/reliability/terminal_convergence_test.exs::"retries_exhausted path"` | Wave 0 |
| REL-03 | Every terminal path lands in `terminal_states/0` (permanent failure) | unit | `mix test test/chimeway/reliability/terminal_convergence_test.exs::"permanent_failure path"` | Wave 0 |
| REL-03 | Every terminal path lands in `terminal_states/0` (bounced) | unit | `mix test test/chimeway/reliability/terminal_convergence_test.exs::"bounced path"` | Wave 0 |
| REL-03 | Every terminal path lands in `terminal_states/0` (suppressed) | unit | `mix test test/chimeway/reliability/terminal_convergence_test.exs::"suppressed path"` | Wave 0 |
| REL-03 | Every terminal path lands in `terminal_states/0` (cancelled manual) | unit | `mix test test/chimeway/reliability/terminal_convergence_test.exs::"manual cancelled path"` | Wave 0 |
| REL-03 | Sync path also converges permanent/bounced to `:cancelled` (parity with Oban) | unit | `mix test test/chimeway/dispatch/sync_test.exs::"permanent terminal convergence"` | Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test test/chimeway/dispatch/oban_worker_test.exs test/chimeway/reliability/` (the affected test files for that task)
- **Per wave merge:** `mix ci` (`format --check-formatted`, `compile --warnings-as-errors`, `credo --strict`, `test`)
- **Phase gate:** `mix ci` green AND every test file in the requirements -> test map green before `/gsd-verify-work`.

### Failure Mode Hypotheses (drive Wave 0 / VALIDATION.md)

| Failure Mode | Hypothesis | Validation Observable |
|--------------|------------|----------------------|
| Concurrent re-fire collision | Two simultaneous triggers with same idempotency_key both succeed because dedup check ran outside the transaction | Postgres unique constraint name in error tuple; `assert Repo.aggregate(Event, :count) == 1` |
| Partial enqueue rollback | Dispatch fails after planning rows are inserted; planning rows survive | `Repo.aggregate(Delivery, :count, where: notification_id == ^id) == 0` after forced enqueue failure |
| Terminal-state divergence between sync and Oban | Sync `:permanent` outcome leaves delivery `:failed`, Oban path correctly converges to `:cancelled` | `Deliveries.get_delivery!(id).status in Deliveries.terminal_states()` for both paths |
| `:snooze` budget runaway (anti-pattern) | Worker returns `{:snooze, n}` and `attempt` keeps climbing past 5 | `assert job.attempt <= max_attempts` after drain; if violated, the implementation chose the wrong return path |
| Final-attempt write missed | `job.attempt == job.max_attempts` guard misfires (wrong comparison, off-by-one) and exhaustion path never runs | After `drain_queue` with always-failing adapter: `assert delivery.status == :cancelled and suppression_reason == "retries_exhausted"` |
| `attempt_number` duplicate under concurrency | Two concurrent `record_attempt` calls both compute `count(*) + 1` and tie | Concurrent test asserts `Repo.aggregate(DeliveryAttempt, :count, distinct: :attempt_number) == count(:id)` |

### Dual Implementation Hypotheses

| Decision Point | Hypothesis A | Hypothesis B | Resolution |
|----------------|--------------|--------------|-----------|
| Worker return on transient failure | `{:error, reason}` (default Oban backoff) | `{:snooze, computed_seconds}` (custom curve from `attempt`) | **A wins.** B breaks the 5-attempt budget per Oban issues #245/#476. CONTEXT D-04 defaults to A unless backoff tuning is justified — no tuning is justified. |
| Final-attempt return value | `{:error, reason}` -> Oban discards | `:ok` -> Oban completes (after writing `:cancelled`) | **B wins.** A inflates `:discard` telemetry; B keeps `:cancelled+retries_exhausted` as the sole durable explanation. Validation: drain_queue result has `success` for the final iteration, not `discard`. |
| `error_class` representation | `Ecto.Enum` field with values `[:temporary, :permanent, :bounced]` | `:string` field with changeset `validate_inclusion` whitelist | **B wins.** D-07 says persisted values must be strings (`"temporary"` etc.); A would require Ecto to handle the atom<->string mapping in a way that doesn't add value. B is also consistent with `:channel` being a plain string post-Phase-11. |
| `failed -> cancelled` transition gate | Add to `@allowed_transitions` openly; gate on `suppression_reason` whitelist in changeset | Add to `@allowed_transitions` and expose only via private `Deliveries.exhaust_delivery/1` helper | **B wins.** Pattern 5 in research; consistent with existing `suppress_delivery/2` named-helper idiom. |
| Permanent/bounced terminal path | Worker writes `:cancelled` after `record_attempt` returns `:failed` | `record_attempt` itself writes `:cancelled` (driven by `error_class`) | **B wins.** Sync dispatch goes through `record_attempt` but does NOT call the worker; for sync to converge (D-12), the convergence must live inside `record_attempt`. Pitfall 2 documents this. |

### Wave 0 Gaps (test infrastructure to create before implementation)
- [ ] `test/chimeway/reliability/duplicate_protection_test.exs` — D-02/D-14 covers concurrent re-fire, concurrent plan re-entry, concurrent terminal re-entry
- [ ] `test/chimeway/reliability/attempt_history_test.exs` — REL-02: attempt_number ordinality, error_class taxonomy, concurrent attempt_number
- [ ] `test/chimeway/reliability/retry_exhaustion_test.exs` — REL-02 end-to-end via `drain_queue` + always-failing adapter
- [ ] `test/chimeway/reliability/terminal_convergence_test.exs` — REL-03 D-12: every terminal path asserts membership in `Deliveries.terminal_states/0`
- [ ] Extend `test/chimeway/dispatch/oban_worker_test.exs` — D-13 rewrite of lines 109-149 using `perform_job/3` with `attempt:`
- [ ] Extend `test/chimeway/dispatch/sync_test.exs` (if exists; otherwise new) — REL-03 sync-path convergence for permanent/bounced
- [ ] Extend `test/chimeway/deliveries_test.exs` (if exists; otherwise new) — `exhaust_delivery/1` happy path + invalid-transition path
- [ ] Extend `test/chimeway/traces_test.exs` (if exists; otherwise new) — `last_attempt_summary` includes `attempt_number` + `error_class`

## Sources

### Primary (HIGH confidence)
- [Oban 2.21.1 Worker docs](https://hexdocs.pm/oban/2.21.1/Oban.Worker.html) — `perform/1` return values, `backoff/1` callback, no `exhausted/1` callback exists
- [Oban 2.21.1 Testing docs](https://hexdocs.pm/oban/2.21.1/Oban.Testing.html) — `perform_job/3` accepts `attempt:` option; `assert_enqueued`/`refute_enqueued` semantics
- [Oban 2.21.1 main module docs](https://hexdocs.pm/oban/2.21.1/Oban.html) — `drain_queue/2` options and return shape
- [Oban 2.21.1 Error Handling guide](https://hexdocs.pm/oban/error_handling.html) — retry behavior, `max_attempts`, `:snooze` semantics
- [Context7: /oban-bg/oban](https://github.com/oban-bg/oban) — code examples for perform/1, backoff/1, telemetry handlers
- `mix.lock` — pinned versions verified
- Repository source files cited inline (lib/chimeway/deliveries.ex, dispatch/*, delivery_attempt.ex, etc.)

### Secondary (MEDIUM confidence)
- [Oban issue #476 — make snooze not affect default retry backoff base](https://github.com/oban-bg/oban/issues/476) — confirms `:snooze` increments attempt counter
- [Oban issue #245 — snoozing jobs interferes with backoff calculations](https://github.com/oban-bg/oban/issues/245) — same as above; community-validated
- [ElixirForum — Handling failed Oban jobs](https://elixirforum.com/t/handling-failed-oban-jobs/38409) — confirms `job.attempt == job.max_attempts` pattern is community-standard
- [Oban GitHub source: lib/oban/worker.ex](https://github.com/oban-bg/oban/blob/main/lib/oban/worker.ex) — direct source for callback signatures

### Tertiary (LOW confidence — none in this research)
- N/A — no LOW-confidence claims in this research.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every version verified against `mix.lock`; Oban API surface verified against 2.21.1 docs
- Architecture: HIGH — patterns map directly to existing project idioms (Multi-based transactions, named-helper transitions, string-channel safety)
- Pitfalls: HIGH for #1, #2, #4, #5, #6 (verified via existing tests or docs); MEDIUM for #3 (concurrency hazard requires test verification)
- Validation: HIGH — Oban.Testing helpers documented and in active use in the project
- Migration recipe: HIGH — Postgres window functions are stable SQL; pattern matches existing project migration style

**Research date:** 2026-04-26
**Valid until:** 2026-05-26 (30 days for stable Oban 2.21.1 + Ecto 3.13.5)

## RESEARCH COMPLETE

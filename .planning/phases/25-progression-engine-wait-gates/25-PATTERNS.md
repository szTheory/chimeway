# Phase 25: Progression Engine & Wait Gates - Pattern Map

**Mapped:** 2026-04-29
**Files analyzed:** 9
**Analogs found:** 9 / 9

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/chimeway/notifier.ex` | utility | transform | `lib/chimeway/notifier.ex` | exact |
| `lib/chimeway/workflows.ex` | service | CRUD | `lib/chimeway/workflows.ex` | exact |
| `lib/chimeway/workflows/progression.ex` | service | event-driven | `lib/chimeway/digests/emission.ex` | exact |
| `lib/chimeway/workflows/progression_outcome.ex` | utility | transform | `lib/chimeway/notifier.ex` | partial |
| `lib/chimeway/dispatch/workflow_progression_worker.ex` | worker | event-driven | `lib/chimeway/dispatch/deferred_resume_worker.ex` | exact |
| `test/chimeway/notifier_contract_test.exs` | test | transform | `test/chimeway/notifier_contract_test.exs` | exact |
| `test/chimeway/orchestration/workflow_progression_test.exs` | test | event-driven | `test/chimeway/orchestration/deferred_resume_test.exs` | exact |
| `test/chimeway/dispatch/workflow_progression_worker_test.exs` | test | event-driven | `test/chimeway/orchestration/deferred_resume_test.exs` | role-match |
| `test/chimeway/reliability/workflow_progression_race_test.exs` | test | event-driven | `test/chimeway/reliability/duplicate_protection_test.exs` | exact |

## Pattern Assignments

### `lib/chimeway/notifier.ex` (utility, transform)

**Analog:** `lib/chimeway/notifier.ex`

**Workflow config normalization pattern** ([lib/chimeway/notifier.ex](/Users/jon/projects/chimeway/lib/chimeway/notifier.ex:342)):
```elixir
with :ok <- require_workflow_fields(workflow_key, workflow_version, steps),
     {:ok, normalized_source} <- normalize_workflow_source(source),
     {:ok, normalized_workflow_key} <- normalize_workflow_key(workflow_key),
     {:ok, normalized_workflow_version} <- normalize_workflow_version(workflow_version),
     {:ok, normalized_steps} <- normalize_workflow_steps(steps) do
  {:ok,
   %{
     workflow_key: normalized_workflow_key,
     workflow_version: normalized_workflow_version,
     steps: normalized_steps,
     source: normalized_source
   }}
else
  :error -> {:error, {:workflow_resolution_failed, {:invalid_workflow_declaration, declaration}}}
  {:error, reason} -> {:error, {:workflow_resolution_failed, reason}}
end
```

**Ordered step validation pattern** ([lib/chimeway/notifier.ex](/Users/jon/projects/chimeway/lib/chimeway/notifier.ex:428)):
```elixir
with {:ok, normalized_steps} <- normalize_workflow_step_list(steps),
     :ok <- validate_unique_workflow_step_keys(normalized_steps),
     :ok <- validate_unique_workflow_step_orders(normalized_steps),
     :ok <- validate_sequential_workflow_step_orders(normalized_steps) do
  {:ok, Enum.sort_by(normalized_steps, & &1.step_order)}
end
```

**Per-step config shape pattern** ([lib/chimeway/notifier.ex](/Users/jon/projects/chimeway/lib/chimeway/notifier.ex:455)):
```elixir
step_key = Map.get(step, :step_key, Map.get(step, "step_key"))
step_order = Map.get(step, :step_order, Map.get(step, "step_order"))
channel = Map.get(step, :channel, Map.get(step, "channel"))
config = Map.get(step, :config, Map.get(step, "config", %{}))

with {:ok, normalized_step_key} <- normalize_workflow_step_key(step_key),
     {:ok, normalized_step_order} <- normalize_workflow_step_order(step_order),
     {:ok, normalized_channel} <- normalize_workflow_channel(channel),
     {:ok, normalized_config} <- normalize_workflow_config(config) do
  {:ok,
   %{
     step_key: normalized_step_key,
     step_order: normalized_step_order,
     channel: normalized_channel,
     config: normalized_config
   }}
end
```

Use this same data-first normalization style for new `progress` declarations inside `step.config`; return tagged `{:workflow_resolution_failed, reason}` errors instead of raising.

---

### `lib/chimeway/workflows.ex` (service, CRUD)

**Analog:** `lib/chimeway/workflows.ex`

**Imports and aliases pattern** ([lib/chimeway/workflows.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:4)):
```elixir
import Ecto.Query

alias Ecto.Multi
alias Chimeway.Repo

alias Chimeway.Workflows.{
  WorkflowDefinition,
  WorkflowRun,
  WorkflowStep,
  WorkflowTransition
}
```

**Active-step lookup pattern** ([lib/chimeway/workflows.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:123)):
```elixir
query =
  from(wr in WorkflowRun,
    join: ws in WorkflowStep,
    on: wr.current_step_id == ws.id,
    where: wr.notification_id == ^notification_id,
    select: %{
      workflow_run_id: wr.id,
      workflow_step_id: ws.id,
      channel: ws.channel
    }
  )

{:ok, Repo.one(query)}
```

**Run + transition persistence pattern** ([lib/chimeway/workflows.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows.ex:152)):
```elixir
with {:ok, first_step} <- fetch_first_step(definition),
     {:ok, workflow_run} <-
       repo.insert(
         WorkflowRun.changeset(%WorkflowRun{}, %{
           notification_id: notification_id,
           workflow_definition_id: definition.id,
           current_step_id: first_step.id,
           state: @active_state,
           started_at: timestamp,
           last_transition_at: timestamp,
           status_reason: @workflow_started_reason,
           status_context: @trigger_context
         })
       ),
     {:ok, _started_transition} <-
       insert_transition(repo, %{
         workflow_run_id: workflow_run.id,
         to_state: @active_state,
         reason: @workflow_started_reason,
         context: @trigger_context,
         inserted_at: timestamp
       }) do
```

Phase 25 should extend this module rather than create a second workflow state store. New progression helpers should update `current_step_id`, `state`, `last_transition_at`, `status_reason`, and `status_context` while appending explicit `WorkflowTransition` rows.

---

### `lib/chimeway/workflows/progression.ex` (service, event-driven)

**Analog:** `lib/chimeway/digests/emission.ex`

**Transactional claim-and-emit pattern** ([lib/chimeway/digests/emission.ex](/Users/jon/projects/chimeway/lib/chimeway/digests/emission.ex:17)):
```elixir
@spec emit_bucket(binary() | DigestBucket.t(), keyword()) ::
        {:ok, emit_result()} | {:error, term()}
def emit_bucket(bucket_or_id, opts \\ []) do
  emitted_at =
    opts
    |> Keyword.get(:emitted_at, DateTime.utc_now())
    |> normalize_datetime()

  case Repo.transact(fn ->
         bucket = lock_bucket!(bucket_id!(bucket_or_id))

         cond do
           bucket.flush_state == :emitted and is_binary(bucket.digest_delivery_id) ->
             ...

           DateTime.compare(bucket.window_ends_at, emitted_at) == :gt ->
             Repo.rollback({:bucket_not_due, bucket.id})

           true ->
             ...
         end
       end) do
    {:ok, %{digest_delivery: digest_delivery} = result} ->
      dispatch_after_commit(dispatch_mode, digest_delivery, immediate_deliveries)
      {:ok, result}

    {:error, reason} ->
      {:error, reason}
  end
end
```

**Durable row lock pattern** ([lib/chimeway/digests/emission.ex](/Users/jon/projects/chimeway/lib/chimeway/digests/emission.ex:97)):
```elixir
defp lock_bucket!(bucket_id) do
  from(bucket in DigestBucket, where: bucket.id == ^bucket_id, lock: "FOR UPDATE")
  |> Repo.one!()
end
```

**Claim then mutate canonical rows pattern** ([lib/chimeway/digests/emission.ex](/Users/jon/projects/chimeway/lib/chimeway/digests/emission.ex:46)):
```elixir
bucket =
  bucket
  |> Ecto.Changeset.change(flush_state: :claimed, claimed_at: emitted_at)
  |> Repo.update!()

{digest_delivery, bucket} =
  create_digest_delivery!(bucket, unresolved_memberships, emitted_at)
```

**Canonical delivery handoff pattern** ([lib/chimeway/delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:88)):
```elixir
{:ok, delivery} <-
  Deliveries.plan_delivery(notification.id, channel,
    ...,
    workflow_run_id: workflow_linkage[:workflow_run_id],
    workflow_step_id: workflow_linkage[:workflow_step_id]
  ),
{:ok, delivery} <- maybe_apply_workflow_linkage(delivery, workflow_linkage)
```

Build Phase 25 progression like digest emission: lock one canonical row, no-op when already progressed, persist claim/wait/advance facts durably, then emit at most one next-step delivery through the existing delivery planning path.

---

### `lib/chimeway/workflows/progression_outcome.ex` (utility, transform)

**Analog:** `lib/chimeway/notifier.ex`

**Pure normalization pattern** ([lib/chimeway/notifier.ex](/Users/jon/projects/chimeway/lib/chimeway/notifier.ex:403)):
```elixir
defp normalize_workflow_source(source) when source in [:notifier, :planner_override], do: {:ok, source}
defp normalize_workflow_source("notifier"), do: {:ok, :notifier}
defp normalize_workflow_source("planner_override"), do: {:ok, :planner_override}
defp normalize_workflow_source(source), do: {:error, {:invalid_workflow_source, source}}
```

**Canonical fact-to-outcome mapping inputs** ([lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:1020)):
```elixir
defp terminal_or_failed_transition(delivery, :succeeded, _error_class),
  do: transition_status(delivery, :succeeded)

defp terminal_or_failed_transition(delivery, _outcome, "permanent"),
  do: cancel_with_reason(delivery, "permanent_failure")

defp terminal_or_failed_transition(delivery, _outcome, "bounced"),
  do: cancel_with_reason(delivery, "bounced")

defp terminal_or_failed_transition(delivery, _outcome, _error_class),
  do: transition_status(delivery, :failed)
```

**Operator-facing vocabulary pattern** ([lib/chimeway/traces/explanation.ex](/Users/jon/projects/chimeway/lib/chimeway/traces/explanation.ex:26)):
```elixir
- `suppression_reason` — reason atom string when status is `:suppressed` OR `:cancelled`,
  else nil. The four documented reason strings are:
    * `"channel_disabled"`
    * `"retries_exhausted"`
    * `"permanent_failure"`
    * `"bounced"`
```

No exact analog exists for a workflow-facing outcome mapper. Keep it as a pure module that derives one stable branch value from durable `delivery.status`, `suppression_reason`, and last-attempt evidence, then returns branchable vs not-branchable explicitly.

---

### `lib/chimeway/dispatch/workflow_progression_worker.ex` (worker, event-driven)

**Analog:** `lib/chimeway/dispatch/deferred_resume_worker.ex`

**Thin worker definition pattern** ([lib/chimeway/dispatch/deferred_resume_worker.ex](/Users/jon/projects/chimeway/lib/chimeway/dispatch/deferred_resume_worker.ex:12)):
```elixir
use Oban.Worker,
  queue: :chimeway_delivery,
  max_attempts: 5,
  replace: [scheduled: [:scheduled_at]],
  unique: [fields: [:args], keys: [:delivery_id], period: 60, timestamp: :scheduled_at]
```

**Perform/transaction wrapper pattern** ([lib/chimeway/dispatch/deferred_resume_worker.ex](/Users/jon/projects/chimeway/lib/chimeway/dispatch/deferred_resume_worker.ex:22)):
```elixir
def perform(%Oban.Job{args: %{"delivery_id" => delivery_id}}) do
  Multi.new()
  |> Multi.run(:resume_delivery, resume_delivery_step(delivery_id))
  |> Multi.run(:dispatch_job, &dispatch_job_step/2)
  |> Repo.transaction()
  |> normalize_transaction_result()
end
```

**No-op normalization pattern** ([lib/chimeway/dispatch/deferred_resume_worker.ex](/Users/jon/projects/chimeway/lib/chimeway/dispatch/deferred_resume_worker.ex:39)):
```elixir
defp normalize_resume_result({:ok, delivery}), do: {:ok, {:resumed, delivery}}
defp normalize_resume_result({:noop, delivery}), do: {:ok, {:noop, delivery}}
```

Keep the worker thin. Its args should carry only stable IDs, and the worker should call the new internal progression seam rather than owning branching policy itself.

---

### `test/chimeway/notifier_contract_test.exs` (test, transform)

**Analog:** `test/chimeway/notifier_contract_test.exs`

**Embedded notifier fixture pattern** ([test/chimeway/notifier_contract_test.exs](/Users/jon/projects/chimeway/test/chimeway/notifier_contract_test.exs:120)):
```elixir
defmodule WorkflowNotifier do
  @behaviour Notifier

  @impl true
  def workflow(_params, _recipient) do
    {:ok,
     %{
       workflow_key: "comment.escalation",
       workflow_version: 3,
       steps: [
         %{step_key: "email", step_order: 2, channel: :email, config: %{"delay_minutes" => 30}},
         %{step_key: "in_app", step_order: 1, channel: "in_app", config: %{}}
       ]
     }}
  end
end
```

**Tagged validation assertion pattern** ([test/chimeway/notifier_contract_test.exs](/Users/jon/projects/chimeway/test/chimeway/notifier_contract_test.exs:301)):
```elixir
assert {:error, {:workflow_resolution_failed, {:duplicate_workflow_step_key, "email"}}} =
         Notifier.normalize_workflow_declaration(%{
           workflow_key: "comment.escalation",
           workflow_version: 1,
           steps: [
             %{step_key: "email", step_order: 1, channel: "email", config: %{}},
             %{step_key: "email", step_order: 2, channel: "in_app", config: %{}}
           ]
         })
```

Add Phase 25 tests here for valid/invalid `progress` config shapes inside `step.config`.

---

### `test/chimeway/orchestration/workflow_progression_test.exs` (test, event-driven)

**Analog:** `test/chimeway/orchestration/deferred_resume_test.exs`

**DataCase + Oban testing harness** ([test/chimeway/orchestration/deferred_resume_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/deferred_resume_test.exs:1)):
```elixir
use Chimeway.DataCase, async: false
use Oban.Testing, repo: Chimeway.Repo

import Ecto.Query

alias Chimeway.{Deliveries, Delivery, Dispatch.DeferredResumeWorker, Dispatch.ObanWorker, Repo, Traces}
```

**Idempotent due-action assertion pattern** ([test/chimeway/orchestration/deferred_resume_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/deferred_resume_test.exs:28)):
```elixir
assert {:ok, resumed_delivery} =
         Deliveries.resume_deferred_delivery(
           delivery.id,
           now: ~U[2026-01-15 13:05:00Z],
           source: "scheduled_resume"
         )

assert {:noop, already_resumed} =
         Deliveries.resume_deferred_delivery(
           delivery.id,
           now: ~U[2026-01-15 13:06:00Z],
           source: "scheduled_resume"
         )
```

Use this file shape for end-to-end progression tests: waiting until due, branching on prior delivery outcome, persisting one explainable transition history, and proving repeated progression calls no-op safely.

---

### `test/chimeway/dispatch/workflow_progression_worker_test.exs` (test, event-driven)

**Analog:** `test/chimeway/orchestration/deferred_resume_test.exs`

**Exactly-one enqueue assertion pattern** ([test/chimeway/orchestration/deferred_resume_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/deferred_resume_test.exs:255)):
```elixir
refute_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})

assert :ok = perform_job(DeferredResumeWorker, %{delivery_id: delivery.id})

assert_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})
assert length(all_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})) == 1

assert :ok = perform_job(DeferredResumeWorker, %{delivery_id: delivery.id})

assert length(all_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})) == 1
```

**Terminal/noop worker assertion pattern** ([test/chimeway/orchestration/deferred_resume_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/deferred_resume_test.exs:282)):
```elixir
assert :ok = perform_job(DeferredResumeWorker, %{delivery_id: ready_delivery.id})
assert :ok = perform_job(DeferredResumeWorker, %{delivery_id: cancelled_delivery.id})

refute_enqueued(worker: ObanWorker, args: %{delivery_id: ready_delivery.id})
refute_enqueued(worker: ObanWorker, args: %{delivery_id: cancelled_delivery.id})
```

Use this as the direct analog for the new progression worker test file.

---

### `test/chimeway/reliability/workflow_progression_race_test.exs` (test, event-driven)

**Analog:** `test/chimeway/reliability/duplicate_protection_test.exs`

**Concurrent sandbox pattern** ([test/chimeway/reliability/duplicate_protection_test.exs](/Users/jon/projects/chimeway/test/chimeway/reliability/duplicate_protection_test.exs:271)):
```elixir
parent = self()

results =
  1..10
  |> Task.async_stream(
    fn _attempt ->
      Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
      Trigger.trigger(
        IdempotentNotifier,
        %{"body" => "hello"},
        idempotency_key: "rel01-d14a-concurrent"
      )
    end,
    ordered: false,
    max_concurrency: 10,
    timeout: 15_000
  )
  |> Enum.map(fn {:ok, result} -> result end)
```

**Exactly-one row assertion pattern** ([test/chimeway/reliability/duplicate_protection_test.exs](/Users/jon/projects/chimeway/test/chimeway/reliability/duplicate_protection_test.exs:315)):
```elixir
assert Enum.all?(results, &match?({:ok, [%Delivery{}]}, &1))

delivery_count =
  Repo.aggregate(
    from(d in Delivery, where: d.notification_id == ^ctx.notification.id),
    :count,
    :id
  )

assert delivery_count == 1
```

Copy this structure for due-step race tests: concurrent calls into the same progression seam should yield one next-step emission and stable workflow state.

## Shared Patterns

### Durable Workflow State
**Sources:** [lib/chimeway/workflows/workflow_run.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows/workflow_run.ex:15), [lib/chimeway/workflows/workflow_transition.ex](/Users/jon/projects/chimeway/lib/chimeway/workflows/workflow_transition.ex:15)
**Apply to:** `lib/chimeway/workflows.ex`, `lib/chimeway/workflows/progression.ex`
```elixir
@state_values [:active, :waiting, :completed, :stopped]

field(:status_context, :map, default: %{})
field(:context, :map, default: %{})
```

Phase 25 should reuse the existing `:waiting` run state and transition `context` map instead of adding parallel state storage.

### Row-Level Claiming And Idempotency
**Sources:** [lib/chimeway/digests/emission.ex](/Users/jon/projects/chimeway/lib/chimeway/digests/emission.ex:27), [lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:972), [lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:655)
**Apply to:** progression claim logic, due-step advancement, duplicate-safe worker retries
```elixir
bucket = lock_bucket!(bucket_id!(bucket_or_id))

case repo.one(from(d in Delivery, where: d.id == ^delivery.id, lock: "FOR UPDATE")) do
  nil -> {:error, :delivery_not_found}
  locked -> {:ok, locked}
end

{updated_count, _rows} =
  Repo.update_all(
    from(d in Delivery,
      where:
        d.id == ^delivery_id and d.status == :pending and d.orchestration_state == :deferred and
          not is_nil(d.next_eligible_at) and d.next_eligible_at <= ^now
    ),
    set: [orchestration_state: :ready, metadata: metadata, updated_at: now]
  )
```

Prefer row locks or conditional `update_all` claims on Chimeway-owned rows. Do not use queue uniqueness as the correctness boundary.

### Thin Worker Boundary
**Source:** [lib/chimeway/dispatch/deferred_resume_worker.ex](/Users/jon/projects/chimeway/lib/chimeway/dispatch/deferred_resume_worker.ex:22)
**Apply to:** `lib/chimeway/dispatch/workflow_progression_worker.ex`
```elixir
Multi.new()
|> Multi.run(:resume_delivery, resume_delivery_step(delivery_id))
|> Multi.run(:dispatch_job, &dispatch_job_step/2)
|> Repo.transaction()
|> normalize_transaction_result()
```

The worker should only load IDs, call the internal engine, and normalize `:ok`/`:noop`; business rules stay in the progression service.

### Canonical Delivery Path
**Source:** [lib/chimeway/delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:88)
**Apply to:** next-step emission in progression
```elixir
{:ok, delivery} <-
  Deliveries.plan_delivery(notification.id, channel,
    ...,
    workflow_run_id: workflow_linkage[:workflow_run_id],
    workflow_step_id: workflow_linkage[:workflow_step_id]
  ),
{:ok, delivery} <- maybe_apply_workflow_linkage(delivery, workflow_linkage)
```

Advance by planning the next canonical delivery, not by mutating historical deliveries or inventing a second dispatch seam.

### Operator-Facing Vocabulary
**Source:** [lib/chimeway/traces/explanation.ex](/Users/jon/projects/chimeway/lib/chimeway/traces/explanation.ex:19)
**Apply to:** outcome mapping docs, transition context payloads, tests
```elixir
- `status` — final delivery status: :succeeded | :failed | :suppressed | :pending | :cancelled
- `suppression_reason` — reason atom string when status is `:suppressed` OR `:cancelled`
- `last_attempt` — map with :outcome, :inserted_at, :attempt_number, :error_class
```

Persist both the curated workflow outcome and the raw supporting facts that produced it.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| None | - | - | The repo already has strong analogs for validation, durable claim logic, thin scheduled workers, and concurrency tests. |

## Metadata

**Analog search scope:** `lib/chimeway/**`, `test/chimeway/**`, `.planning/**`
**Files scanned:** 18
**Pattern extraction date:** 2026-04-29

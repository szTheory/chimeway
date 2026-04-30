# Phase 23: Digest Flush Scheduling & Audit Closure - Pattern Map

**Mapped:** 2026-04-28
**Files analyzed:** 10
**Analogs found:** 10 / 10

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/chimeway/digests/accumulation.ex` | service | transform | `lib/chimeway/digests/accumulation.ex` | exact |
| `lib/chimeway/digests/emission.ex` | service | event-driven | `lib/chimeway/digests/emission.ex` | exact |
| `lib/chimeway/dispatch/oban.ex` | service | event-driven | `lib/chimeway/dispatch/oban.ex` | exact |
| `lib/chimeway/dispatch/digest_flush_worker.ex` | service | event-driven | `lib/chimeway/dispatch/deferred_resume_worker.ex` | role+flow |
| `lib/chimeway/deliveries.ex` | service | event-driven | `lib/chimeway/deliveries.ex` | exact |
| `test/chimeway/digests/flush_scheduling_test.exs` | test | event-driven | `test/chimeway/digests/accumulation_test.exs` | role+domain |
| `test/chimeway/integration/digest_delivery_lifecycle_test.exs` | test | event-driven | `test/chimeway/integration/digest_delivery_lifecycle_test.exs` | exact |
| `test/chimeway/orchestration/recovery_test.exs` | test | event-driven | `test/chimeway/orchestration/recovery_test.exs` | exact |
| `.planning/phases/20-digest-emission-explainability/20-VERIFICATION.md` | config | transform | `.planning/phases/22-recovery-outcome-analytics/22-VERIFICATION.md` | role+recency |
| `.planning/REQUIREMENTS.md` | config | transform | `.planning/REQUIREMENTS.md` | exact |
| `.planning/ROADMAP.md` | config | transform | `.planning/ROADMAP.md` | exact |

## Pattern Assignments

### `lib/chimeway/digests/accumulation.ex` (service, transform)

**Analog:** `lib/chimeway/digests/accumulation.ex`

**Imports pattern** (`lib/chimeway/digests/accumulation.ex:4-10`):
```elixir
import Ecto.Query, only: [from: 2]

alias Chimeway.{Delivery, Repo}
alias Chimeway.Digests
alias Chimeway.Digests.{DigestBucket, DigestMembership, DigestRule}
alias Chimeway.Events.Event
alias Chimeway.Notifications.Notification
```

**Transactional service pattern** (`lib/chimeway/digests/accumulation.ex:35-57`):
```elixir
def accumulate_delivery(%Delivery{} = delivery, opts \\ []) when is_list(opts) do
  accumulated_at =
    opts
    |> Keyword.get(:accumulated_at, DateTime.utc_now())
    |> normalize_datetime()

  case Repo.transact(fn ->
         locked_delivery = lock_delivery!(delivery.id)

         if accumulatable?(locked_delivery) do
           {:ok,
            do_accumulate(
              locked_delivery,
              accumulated_at,
              Keyword.get(opts, :lookup_attrs, %{})
            )}
         else
           {:ok, :noop}
         end
       end) do
    {:ok, result} -> {:ok, result}
    {:error, reason} -> {:error, reason}
  end
end
```

**Bucket upsert + membership write pattern** (`lib/chimeway/digests/accumulation.ex:79-92`, `210-268`):
```elixir
bucket =
  upsert_bucket!(
    rule,
    Map.get(lookup, :recipient_id),
    Map.get(lookup, :channel),
    grouping_value,
    window_starts_at,
    window_ends_at
  )

case insert_membership(bucket, delivery, accumulated_at) do
  :inserted -> refresh_bucket!(bucket.id)
  :existing -> refresh_bucket!(bucket.id)
end
```

```elixir
%DigestBucket{}
|> DigestBucket.changeset(attrs)
|> Repo.insert(on_conflict: :nothing, conflict_target: @bucket_conflict_target)

Repo.get_by!(DigestBucket,
  digest_rule_id: rule.id,
  recipient_id: recipient_id,
  channel: channel,
  grouping_value: grouping_value,
  window_starts_at: window_starts_at,
  window_ends_at: window_ends_at
)
```

**Rollback/error pattern** (`lib/chimeway/digests/accumulation.ex:157-159`, `183-186`, `298-303`):
```elixir
defp grouping_value!(%DigestRule{group_by: group_by}, _event, _category, _digest_key) do
  Repo.rollback({:missing_grouping_value, group_by})
end
```

### `lib/chimeway/digests/emission.ex` (service, event-driven)

**Analog:** `lib/chimeway/digests/emission.ex`

**Imports pattern** (`lib/chimeway/digests/emission.ex:4-9`):
```elixir
import Ecto.Query

alias Chimeway.{Deliveries, Delivery, Repo}
alias Chimeway.Digests.{DigestBucket, DigestMembership}
alias Chimeway.Events.Event
alias Chimeway.Notifications.Notification
```

**Due/duplicate idempotency pattern** (`lib/chimeway/digests/emission.ex:27-43`):
```elixir
case Repo.transact(fn ->
       bucket = lock_bucket!(bucket_id!(bucket_or_id))

       cond do
         bucket.flush_state == :emitted and is_binary(bucket.digest_delivery_id) ->
           digest_delivery = Repo.get!(Delivery, bucket.digest_delivery_id)
           immediate_deliveries = immediate_deliveries_for_bucket(bucket.id)
           {:ok, %{bucket: bucket, digest_delivery: digest_delivery, immediate_deliveries: immediate_deliveries}}

         DateTime.compare(bucket.window_ends_at, emitted_at) == :gt ->
           Repo.rollback({:bucket_not_due, bucket.id})
```

**Membership resolution pattern** (`lib/chimeway/digests/emission.ex:167-223`):
```elixir
Enum.reduce(memberships, [], fn membership, acc ->
  resolution = resolve_membership(membership)

  membership
  |> DigestMembership.changeset(%{
    resolution: resolution.kind,
    resolution_reason: resolution.reason,
    resolved_at: emitted_at,
    resolved_rule_key: bucket.rule_key,
    resolved_rule_version: bucket.rule_version,
    resolved_window_starts_at: bucket.window_starts_at,
    resolved_window_ends_at: bucket.window_ends_at,
    digest_delivery_id: digest_delivery_id
  })
  |> Repo.update!()
```

**Dispatch split pattern** (`lib/chimeway/digests/emission.ex:296-324`):
```elixir
defp dispatch_in_transaction(:oban, digest_delivery, immediate_deliveries) do
  enqueue_delivery!(digest_delivery.id)

  Enum.each(immediate_deliveries, fn delivery ->
    enqueue_delivery!(delivery.id)
  end)

  :ok
end

defp dispatch_after_commit(:sync, digest_delivery, immediate_deliveries) do
  dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
  _ = dispatcher.dispatch_delivery(digest_delivery.id, pre_planned: true, post_commit: true)
```

### `lib/chimeway/dispatch/oban.ex` (service, event-driven)

**Analog:** `lib/chimeway/dispatch/oban.ex`

**Multi orchestration pattern** (`lib/chimeway/dispatch/oban.ex:35-48`):
```elixir
def dispatch(notifications, opts) when is_list(notifications) do
  base_multi =
    case Keyword.get(opts, :multi, Multi.new()) do
      %Multi{} = multi -> multi
      _ -> Multi.new()
    end

  multi =
    base_multi
    |> Multi.run(:plan_notifications, &do_plan(notifications, opts, &1, &2))
    |> Multi.run(:enqueue_jobs, &do_enqueue(&1, &2))

  handle_transaction_result(Repo.transaction(multi))
end
```

**Scheduled job pattern to copy for digest flush** (`lib/chimeway/dispatch/oban.ex:94-108`):
```elixir
defp enqueue_delivery(
       %{
         status: :pending,
         orchestration_state: :deferred,
         next_eligible_at: %DateTime{}
       } = delivery
     ) do
  job =
    DeferredResumeWorker.new(
      %{delivery_id: delivery.id},
      scheduled_at: delivery.next_eligible_at
    )

  enqueue_job(delivery, job)
end
```

**Telemetry-wrapped insert pattern** (`lib/chimeway/dispatch/oban.ex:116-128`):
```elixir
Telemetry.span(
  [:dispatch, :enqueue],
  Telemetry.safe_meta(%{
    delivery_id: delivery.id,
    channel: delivery.channel,
    notification_key: Map.get(delivery.metadata || %{}, "notification_key")
  }),
  fn ->
    result = Oban.insert(job)
    {result, %{}}
  end
)
```

### `lib/chimeway/dispatch/digest_flush_worker.ex` (service, event-driven)

**Analog:** `lib/chimeway/dispatch/deferred_resume_worker.ex`

**Worker options pattern** (`lib/chimeway/dispatch/deferred_resume_worker.ex:12-17`):
```elixir
use Oban.Worker,
  queue: :chimeway_delivery,
  max_attempts: 5,
  replace: [scheduled: [:scheduled_at]],
  unique: [fields: [:args], keys: [:delivery_id], period: 60, timestamp: :scheduled_at]
```

**Thin-worker delegation pattern** (`lib/chimeway/dispatch/digest_flush_worker.ex:1-19`):
```elixir
defmodule Chimeway.Dispatch.DigestFlushWorker do
  @moduledoc "Thin Oban worker that delegates due digest bucket execution to the emission service."

  use Oban.Worker,
    queue: :chimeway_delivery,
    max_attempts: 5,
    unique: [fields: [:args], keys: [:bucket_id], period: 60]

  alias Chimeway.Digests

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"bucket_id" => bucket_id}}) do
```

**Perform transaction/result normalization pattern** (`lib/chimeway/dispatch/deferred_resume_worker.ex:22-29`, `52-53`):
```elixir
def perform(%Oban.Job{args: %{"delivery_id" => delivery_id}}) do
  Multi.new()
  |> Multi.run(:resume_delivery, resume_delivery_step(delivery_id))
  |> Multi.run(:dispatch_job, &dispatch_job_step/2)
  |> Repo.transaction()
  |> normalize_transaction_result()
end

defp normalize_transaction_result({:ok, _changes}), do: :ok
defp normalize_transaction_result({:error, _step, reason, _changes}), do: {:error, reason}
```

### `lib/chimeway/deliveries.ex` (service, event-driven)

**Analog:** `lib/chimeway/deliveries.ex`

**Recovery dispatch options pattern** (`lib/chimeway/deliveries.ex:196-249`):
```elixir
dispatch_opts = [
  event_id: event.id,
  notification_key: event.notification_key,
  correlation_id: event.correlation_id,
  post_commit: true,
  use_persisted_channels: true
]

case dispatcher.dispatch(notifications, dispatch_opts) do
  {:ok, deliveries_or_results} ->
    deliveries =
      deliveries_or_results
      |> dispatched_deliveries()
      |> stamp_recovery_metadata(source, reason, now)
```

**Persisted orchestration write pattern** (`lib/chimeway/deliveries.ex:444-460`):
```elixir
def apply_planning_decision(%Delivery{} = delivery, decision) when is_map(decision) do
  with {:ok, state} <-
         normalize_orchestration_state(Map.get(decision, :orchestration_state, :ready)),
       {:ok, planning_reason} <- normalize_optional_string(Map.get(decision, :planning_reason)),
       {:ok, planning_context} <- normalize_optional_map(Map.get(decision, :planning_context)),
       {:ok, next_eligible_at} <-
         normalize_optional_datetime(Map.get(decision, :next_eligible_at)) do
    delivery
    |> change(%{
      orchestration_state: state,
      planning_reason: planning_reason,
      planning_context: planning_context,
      next_eligible_at: next_eligible_at
    })
    |> Repo.update()
  end
end
```

**Digest outcome convergence pattern** (`lib/chimeway/deliveries.ex:1002-1039`):
```elixir
{updated_count, _rows} =
  Repo.update_all(
    from(d in Delivery,
      where:
        d.id == ^delivery_id and d.status == :pending and
          d.orchestration_state == :digest_held
    ),
    set: [
      status: status,
      orchestration_state: :ready,
      digest_flush_outcome: digest_flush_outcome,
      digest_flush_reason: reason,
      digest_flush_resolved_at: resolved_at,
      digest_delivery_id: digest_delivery_id,
      updated_at: resolved_at
    ]
  )
```

### `test/chimeway/digests/flush_scheduling_test.exs` (test, event-driven)

**Analog:** `test/chimeway/digests/accumulation_test.exs`

**Test module/setup pattern** (`test/chimeway/digests/accumulation_test.exs:1-15`):
```elixir
defmodule Chimeway.Digests.AccumulationTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.{Deliveries, Repo}
  alias Chimeway.Digests
  alias Chimeway.Digests.{Accumulation, DigestBucket, DigestMembership}
```

**Fixture helper pattern** (`test/chimeway/digests/accumulation_test.exs:328-440`):
```elixir
defp insert_rule(overrides) do
  attrs =
    %{
      rule_key: "digest.rule",
      rule_version: 1,
      channel: "email",
      match_notification_key: "comment.created",
      ...
    }
    |> Map.merge(overrides)

  assert {:ok, rule} = Digests.upsert_rule(attrs)
  rule
end
```

**Supporting Oban assertion pattern** (`test/chimeway/integration/digest_delivery_lifecycle_test.exs:1-4`, `89-125`):
```elixir
use Oban.Testing, repo: Chimeway.Repo
...
assert_enqueued(worker: ObanWorker, args: %{delivery_id: emitted.id})
assert :ok = perform_job(DigestFlushWorker, %{bucket_id: bucket.id})
assert :ok = perform_job(DigestFlushWorker, %{bucket_id: bucket.id})
```

### `test/chimeway/integration/digest_delivery_lifecycle_test.exs` (test, event-driven)

**Analog:** `test/chimeway/integration/digest_delivery_lifecycle_test.exs`

**Integration setup pattern** (`test/chimeway/integration/digest_delivery_lifecycle_test.exs:13-34`):
```elixir
setup do
  Repo.delete_all(DigestMembership)
  Repo.delete_all(DigestBucket)
  Repo.delete_all(Chimeway.Digests.DigestRule)
  Repo.delete_all(Delivery)
  Repo.delete_all(Notification)
  Repo.delete_all(Event)
```

**End-to-end scheduled/dispatch assertion posture** (`test/chimeway/integration/digest_delivery_lifecycle_test.exs:89-125`):
```elixir
Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Oban)
...
assert {:ok, %{digest_delivery: emitted}} =
         Digests.emit_bucket(bucket.id, emitted_at: emitted_at, dispatch: :oban)

assert_enqueued(worker: ObanWorker, args: %{delivery_id: emitted.id})
```

**Planning fixture pattern** (`test/chimeway/integration/digest_delivery_lifecycle_test.exs:144-177`):
```elixir
{:ok, updated} =
  Deliveries.apply_planning_decision(delivery, %{
    orchestration_state: :digest_held,
    planning_reason: "digest_rule",
    planning_context: %{
      "channel" => attrs.channel,
      "source" => "notifier",
      "rule_identity" => "digest_rule"
    },
    next_eligible_at: nil
  })
```

### `test/chimeway/orchestration/recovery_test.exs` (test, event-driven)

**Analog:** `test/chimeway/orchestration/recovery_test.exs`

**Dispatcher stub + setup pattern** (`test/chimeway/orchestration/recovery_test.exs:42-95`, `106-131`):
```elixir
defmodule Chimeway.Orchestration.RecoveryDispatcherStub do
  @behaviour Chimeway.Dispatch
  ...
  def dispatch(notifications, opts) do
    send(test_pid!(), {:dispatch, Enum.map(notifications, & &1.id), opts})
```

**Recovery assertion pattern** (`test/chimeway/orchestration/recovery_test.exs:151-190`):
```elixir
assert {:ok, recovery} =
         Deliveries.recover_event(event.id,
           now: ~U[2026-01-15 12:30:00Z],
           older_than: 60,
           source: "ops_console",
           reason: "trigger_commit_gap"
         )

assert_receive {:dispatch, [^notification_id], dispatch_opts}
assert dispatch_opts[:event_id] == event.id
assert dispatch_opts[:post_commit] == true
assert dispatch_opts[:use_persisted_channels] == true
```

### `.planning/phases/20-digest-emission-explainability/20-VERIFICATION.md` (config, transform)

**Analog:** `.planning/phases/22-recovery-outcome-analytics/22-VERIFICATION.md`

**Frontmatter pattern** (`.planning/phases/22-recovery-outcome-analytics/22-VERIFICATION.md:1-14`):
```markdown
---
phase: 22-recovery-outcome-analytics
verified: 2026-04-28T22:50:13Z
status: passed
score: 10/10 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 8/8
  gaps_closed:
```

**Verification report structure** (`.planning/phases/22-recovery-outcome-analytics/22-VERIFICATION.md:16-39`):
```markdown
# Phase 22: Recovery & Outcome Analytics Verification Report

**Phase Goal:** Close the remaining operational trust gaps with reconciliation paths and aggregate outcome queries.
**Verified:** 2026-04-28T22:50:13Z
**Status:** passed
**Re-verification:** Yes - after gap closure

## Goal Achievement

### Observable Truths
```

**Requirements coverage section pattern** (`.planning/phases/22-recovery-outcome-analytics/22-VERIFICATION.md:83-88`):
```markdown
### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| `OPS-01` | `22-01`, `22-02`, `22-04` | Operators can detect and reconcile persisted events or deliveries that were never fully dispatched after trigger-time failures. | ✓ SATISFIED | ...
```

### `.planning/REQUIREMENTS.md` (config, transform)

**Analog:** `.planning/REQUIREMENTS.md`

**Requirement checkbox pattern** (`.planning/REQUIREMENTS.md:15-20`):
```markdown
### Digests

- [x] **DIGEST-01**: Teams can define digest rules that group repeated notifications by recipient, notification key or category, and delivery window.
- [ ] **DIGEST-02**: Digest generation is idempotent and records which source events and notifications were included in each digest delivery.
- [ ] **DIGEST-03**: Operators can explain why a notification was included in a digest, skipped from a digest, or emitted immediately instead.
```

**Traceability table pattern** (`.planning/REQUIREMENTS.md:53-67`):
```markdown
## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DIGEST-01 | Phase 19 | Complete |
| DIGEST-02 | Phase 23 | Pending |
| DIGEST-03 | Phase 23 | Pending |
```

### `.planning/ROADMAP.md` (config, transform)

**Analog:** `.planning/ROADMAP.md`

**Phase plan block pattern** (`.planning/ROADMAP.md:96-129`):
```markdown
### Phase 23: Digest Flush Scheduling & Audit Closure
**Goal**: ...
**Depends on**: Phase 22
**Requirements**: DIGEST-02, DIGEST-03
**Plans:** 3/6 plans complete

Plans:
- [x] 23-01-PLAN.md — ...
- [ ] 23-04-PLAN.md — ...
```

**Summary/next-up wording pattern** (`.planning/ROADMAP.md:146-160`):
```markdown
## Next Up

**Milestone close-out** — follow the resolved verification artifact and current gate state rather than claiming closure early.
```

## Shared Patterns

### Scheduled Oban Jobs
**Source:** `lib/chimeway/dispatch/oban.ex:94-108`, `lib/chimeway/dispatch/deferred_resume_worker.ex:12-17`
**Apply to:** `lib/chimeway/digests/accumulation.ex`, `lib/chimeway/dispatch/digest_flush_worker.ex`, scheduler tests
```elixir
job =
  DeferredResumeWorker.new(
    %{delivery_id: delivery.id},
    scheduled_at: delivery.next_eligible_at
  )

use Oban.Worker,
  queue: :chimeway_delivery,
  max_attempts: 5,
  replace: [scheduled: [:scheduled_at]],
  unique: [fields: [:args], keys: [:delivery_id], period: 60, timestamp: :scheduled_at]
```

### Transactional Idempotency
**Source:** `lib/chimeway/digests/accumulation.ex:41-57`, `lib/chimeway/digests/emission.ex:27-43`
**Apply to:** accumulation, emission, recovery replay
```elixir
case Repo.transact(fn ->
       locked_delivery = lock_delivery!(delivery.id)
       ...
     end) do
  {:ok, result} -> {:ok, result}
  {:error, reason} -> {:error, reason}
end
```

### Persisted Orchestration Facts
**Source:** `lib/chimeway/deliveries.ex:444-460`, `196-223`
**Apply to:** `lib/chimeway/deliveries.ex`, recovery tests
```elixir
delivery
|> change(%{
  orchestration_state: state,
  planning_reason: planning_reason,
  planning_context: planning_context,
  next_eligible_at: next_eligible_at
})
|> Repo.update()
```

### Digest Explainability Contract
**Source:** `lib/chimeway/traces.ex:627-758`
**Apply to:** recovery regression, integration verification, `20-VERIFICATION.md` evidence
```elixir
%{
  "outcome" => delivery.digest_flush_outcome |> to_string(),
  "digest_delivery_id" => delivery.digest_delivery_id,
  "resolution_reason" => delivery.digest_flush_reason
}
...
%{
  at: delivery.digest_flush_resolved_at || delivery.updated_at,
  event: :digested,
  detail: %{
    digest_delivery_id: delivery.digest_delivery_id,
    resolution_reason: delivery.digest_flush_reason,
    rule_identity: digest_context["rule_identity"]
  }
}
```

### Verification Artifact Shape
**Source:** `.planning/phases/22-recovery-outcome-analytics/22-VERIFICATION.md:16-107`, `.planning/phases/20-digest-emission-explainability/20-VALIDATION.md:16-64`
**Apply to:** `20-VERIFICATION.md`
```markdown
## Goal Achievement
### Observable Truths
### Required Artifacts
### Key Link Verification
### Behavioral Spot-Checks
### Requirements Coverage
### Gaps Summary
```

## No Analog Found

None.

## Metadata

**Analog search scope:** `lib/chimeway/digests/`, `lib/chimeway/dispatch/`, `lib/chimeway/`, `test/chimeway/digests/`, `test/chimeway/integration/`, `test/chimeway/orchestration/`, `.planning/phases/`, `.planning/REQUIREMENTS.md`
**Files scanned:** 15
**Pattern extraction date:** 2026-04-28

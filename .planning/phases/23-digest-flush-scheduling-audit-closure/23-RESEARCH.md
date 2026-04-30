# Phase 23: Digest Flush Scheduling & Audit Closure - Research

**Researched:** 2026-04-28 [VERIFIED: environment_context]
**Domain:** Automatic digest flush scheduling, durable replay safety, and audit/verification closure for the digest pipeline [VERIFIED: .planning/ROADMAP.md]
**Confidence:** HIGH for repo-fit architecture and current gaps; MEDIUM for exact scope boundary between Phase 23 and a possible follow-on recovery-hardening phase [VERIFIED: codebase read + Phase 22 review]

<user_constraints>
## User Constraints (from CONTEXT.md)

No Phase 23 `23-CONTEXT.md` exists yet. [VERIFIED: gsd-sdk init.phase-op + phase directory listing]

Planner-operable scope from the roadmap and explicit user brief:

### Locked Scope
- Close the Phase 20 digest handoff gap by scheduling emitted digest dispatch automatically from durable bucket state. [VERIFIED: .planning/ROADMAP.md]
- Re-verify the end-to-end path from trigger through digest-held accumulation to emitted digest dispatch and document it in `20-VERIFICATION.md`. [VERIFIED: .planning/ROADMAP.md + user brief]
- Repair requirements traceability, checkbox state, and audit artifacts for the digest work and the carried Phase 22 audit cleanup. [VERIFIED: .planning/ROADMAP.md + .planning/REQUIREMENTS.md + user brief]

### Claude's Discretion
- Determine whether the `recover_event/2` digest-orchestration replay warning from Phase 22 belongs in this phase because it can bypass digest accumulation during recovery. [VERIFIED: .planning/phases/22-recovery-outcome-analytics/22-REVIEW.md + .planning/STATE.md]
- Choose whether scheduling happens at accumulation time, window-close scan time, or both, so long as correctness comes from durable bucket state rather than runtime memory. [VERIFIED: .planning/ROADMAP.md + lib/chimeway/digests/accumulation.ex + lib/chimeway/digests/emission.ex]

### Deferred Ideas (OUT OF SCOPE)
- Broad workflow-journey modeling and multi-stage batching remain outside this phase. [VERIFIED: .planning/REQUIREMENTS.md]
- Hosted control-plane UX and non-local-first orchestration remain out of scope. [VERIFIED: AGENTS.md + .planning/REQUIREMENTS.md]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DIGEST-02 | Digest generation is idempotent and records which source events and notifications were included in each digest delivery. [VERIFIED: .planning/REQUIREMENTS.md] | Schedule `DigestFlushWorker` from bucket/window identity, keep `emit_bucket/2` as the DB-backed correctness boundary, and add production-shaped verification that the scheduled path reuses the same emitted digest identity under duplicates. [VERIFIED: lib/chimeway/digests/emission.ex + lib/chimeway/dispatch/digest_flush_worker.ex + test/chimeway/digests/emission_test.exs] |
| DIGEST-03 | Operators can explain why a notification was included in a digest, skipped from a digest, or emitted immediately instead. [VERIFIED: .planning/REQUIREMENTS.md] | Preserve the existing `Chimeway.Traces` digest reasoning contract, then verify that scheduled flushes and any recovery re-drive still preserve `:digest_held` accumulation semantics and explanation continuity. [VERIFIED: lib/chimeway/traces.ex + .planning/phases/22-recovery-outcome-analytics/22-REVIEW.md] |
</phase_requirements>

## Summary

Phase 23 is not a greenfield digest feature. The repo already has durable digest rules, buckets, memberships, emitted digest rows, explicit source-row outcomes, and a thin `DigestFlushWorker`; what is missing is the handoff that turns a newly accumulated or now-due bucket into a scheduled runtime action without manual `emit_bucket/2` calls. [VERIFIED: lib/chimeway/digests/accumulation.ex + lib/chimeway/digests/emission.ex + lib/chimeway/dispatch/digest_flush_worker.ex + .planning/phases/20-digest-emission-explainability/20-02-SUMMARY.md]

The cleanest plan is to mirror Phase 18's deferred-resume posture: schedule one thin Oban job from canonical DB state, carry only durable identifiers in job args, and let the service layer re-check due-ness and idempotency under transaction/row lock at execution time. [VERIFIED: lib/chimeway/dispatch/deferred_resume_worker.ex + lib/chimeway/dispatch/oban.ex + lib/chimeway/digests/emission.ex] Oban supports future scheduling with `scheduled_at` and uniqueness keyed to `scheduled_at`, but its uniqueness is advisory rather than the primary correctness boundary, so bucket state must remain authoritative. [CITED: https://hexdocs.pm/oban/Oban.Job.html] [CITED: https://hexdocs.pm/oban/unique_jobs.html]

Phase 23 should also absorb the remaining audit debt instead of treating it as paperwork. There is no `20-VERIFICATION.md` today, only `20-VALIDATION.md`, and the Phase 22 review found that `recover_event/2` replays persisted channels but drops notifier-defined orchestration snapshots such as `:digest_held`, which can bypass digest accumulation during recovery. [VERIFIED: phase-20 directory listing + .planning/phases/20-digest-emission-explainability/20-VALIDATION.md + .planning/phases/22-recovery-outcome-analytics/22-REVIEW.md + .planning/STATE.md]

**Primary recommendation:** Use bucket-scheduled Oban jobs as the automatic flush path, keep `emit_bucket/2` as the DB-enforced truth boundary, and include recovery-orchestration replay plus `20-VERIFICATION.md` creation in Phase 23 so DIGEST-02/DIGEST-03 can be truthfully closed. [VERIFIED: codebase read + roadmap success criteria]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Schedule digest flush when a bucket becomes due | API / Backend [VERIFIED: repo architecture] | Database / Storage [VERIFIED: bucket state lives in Postgres tables] | The scheduling decision is triggered from persisted digest bucket state and materialized as a worker job; DB fields such as `window_ends_at` and `flush_state` define due-ness. [VERIFIED: lib/chimeway/digests/digest_bucket.ex + lib/chimeway/digests/emission.ex] |
| Enforce idempotent flush execution | Database / Storage [VERIFIED: row locks + bucket state] | API / Backend [VERIFIED: service layer owns transaction] | `emit_bucket/2` already locks the bucket, rejects not-due buckets, and reuses an emitted digest identity on retries. [VERIFIED: lib/chimeway/digests/emission.ex] |
| Dispatch the emitted digest and immediate-release rows | API / Backend [VERIFIED: dispatcher seam] | Database / Storage [VERIFIED: delivery rows are canonical truth] | The repo routes all execution through `dispatch_delivery/2` by delivery id, not through queue-owned state. [VERIFIED: lib/chimeway/dispatch.ex + lib/chimeway/dispatch/oban.ex + lib/chimeway/dispatch/sync.ex] |
| Preserve explainability and audit closure | API / Backend [VERIFIED: `Chimeway.Traces` owns operator reasoning] | Database / Storage [VERIFIED: durable facts power traces] | Trace reasoning is derived from delivery and membership rows; verification/traceability docs are produced from the verified backend behavior. [VERIFIED: lib/chimeway/traces.ex + .planning/REQUIREMENTS.md] |
| Replay recoverable events without losing digest semantics | API / Backend [VERIFIED: `recover_event/2` re-drives planning] | Database / Storage [VERIFIED: missing persisted orchestration snapshot is the gap] | The defect is in the recovery orchestration handoff, but the durable fix requires persisting enough orchestration facts on notifications to reproduce digest-held planning. [VERIFIED: lib/chimeway/deliveries.ex + .planning/phases/22-recovery-outcome-analytics/22-REVIEW.md] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ecto_sql` | `3.13.5` current on Hex, published 2026-03-03; repo constraint `~> 3.11` and lock `3.13.5`. [VERIFIED: mix.exs + mix.lock + hex.pm API] | Transactions, row locking, migrations, and query composition for bucket scheduling and replay-safe updates. [VERIFIED: lib/chimeway/digests/emission.ex] | The repo already uses `Repo.transact/1`, `Ecto.Multi`, and `FOR UPDATE` locking patterns; Phase 23 should extend those instead of inventing a second correctness model. [VERIFIED: lib/chimeway/digests/accumulation.ex + lib/chimeway/dispatch/deferred_resume_worker.ex] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] |
| `oban` | Repo lock `2.21.1`; latest stable on Hex is `2.22.0`, published 2026-04-28. [VERIFIED: mix.lock + hex.pm API] | Automatic scheduled execution of due digest flushes when Oban is present. [VERIFIED: lib/chimeway/dispatch/digest_flush_worker.ex] | The project already uses Oban for deferred resume and delivery execution, and Oban supports future scheduling plus scheduled-time uniqueness that matches the Phase 18 pattern. [VERIFIED: lib/chimeway/dispatch/deferred_resume_worker.ex + lib/chimeway/dispatch/oban.ex] [CITED: https://hexdocs.pm/oban/Oban.Job.html] [CITED: https://hexdocs.pm/oban/unique_jobs.html] |
| PostgreSQL | Project target `15+`; local CLI detected `14.17`. [VERIFIED: AGENTS.md + local `psql --version`] | Durable bucket state, row locks, idempotent insert/update boundaries, and production-shaped verification. [VERIFIED: repo architecture] | Bucket due-ness and duplicate collapse are already expressed as Postgres-backed row state, not in-memory timers or queue-only uniqueness. [VERIFIED: lib/chimeway/digests/digest_bucket.ex + lib/chimeway/digests/emission.ex] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `ecto` | `3.13.5` current on Hex, published 2025-11-09; repo lock `3.13.5`. [VERIFIED: mix.lock + hex.pm API] | Schema/changeset/query primitives backing `Delivery`, `DigestBucket`, and `DigestMembership`. [VERIFIED: lib/chimeway/delivery.ex + lib/chimeway/digests/digest_bucket.ex] | Use for any new persisted orchestration snapshot fields or due-bucket query helpers. [VERIFIED: codebase read] |
| `ExUnit` + `Ecto.Adapters.SQL.Sandbox` | Bundled with Elixir/Ecto test setup. [VERIFIED: test/support/data_case.ex + test/test_helper.exs] | Fast contract and integration coverage for digest scheduling, recovery regression, and trace continuity. [VERIFIED: current test suite] | Use for every Phase 23 task; current digest/recovery slice already runs in `0.6s` locally for 19 tests. [VERIFIED: local `mix test` run] |
| `Oban.Testing` | Available in current test setup. [VERIFIED: test files using `use Oban.Testing`] | Worker enqueue assertions, scheduled-job assertions, and queue draining for the production-shaped path. [VERIFIED: test/chimeway/integration/digest_delivery_lifecycle_test.exs] | Use in new scheduler tests and in the end-to-end verification path that proves scheduled jobs transition to real dispatch. [VERIFIED: codebase read] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Per-bucket scheduled `DigestFlushWorker` [VERIFIED: recommendation] | Periodic due-bucket scanner that calls `emit_bucket/2` on all due buckets [ASSUMED] | A scanner preserves correctness if it still relies on DB state, but it weakens latency guarantees and is a poorer fit than the existing per-row scheduling pattern from Phase 18. [VERIFIED: Phase 18 pattern + current gap] |
| Automatic scheduling under Oban [VERIFIED: project-recommended async seam] | Host-managed manual `Digests.emit_bucket/2` or ad hoc cron wrappers [VERIFIED: current public API] | Manual invocation is the current gap and does not satisfy the roadmap success criterion that scheduling happen automatically from durable state. [VERIFIED: .planning/ROADMAP.md + lib/chimeway/digests.ex] |

**Installation:**
```bash
mix deps.get
```

**Version verification:** Verify current pinned/current versions with Hex before implementation decisions, especially if the planner considers an Oban upgrade:
```bash
curl -s https://hex.pm/api/packages/oban | jq -r '.latest_stable_version, (.releases[] | select(.version == .version) | .inserted_at)'
curl -s https://hex.pm/api/packages/ecto_sql | jq -r '.latest_stable_version'
```

## Architecture Patterns

### System Architecture Diagram

```text
trigger/event persisted
        |
        v
DeliveryPlanning.apply_declared_orchestration
        |
        +--> immediate/ready ----------> normal dispatch path
        |
        +--> deferred -----------------> DeferredResumeWorker scheduled at next_eligible_at
        |
        +--> digest_held
               |
               v
      Digests.Accumulation.accumulate_delivery
               |
               v
      chimeway_digest_buckets + chimeway_digest_memberships
               |
               +--> schedule DigestFlushWorker at bucket.window_ends_at
               |         |
               |         v
               |   Oban job args: %{bucket_id}
               |
               v
      Digests.Emission.emit_bucket
               |
               +--> lock bucket / reject not due / reuse emitted identity
               +--> resolve memberships and converge source rows
               +--> create emitted digest delivery row
               +--> dispatch_delivery(digest_delivery_id)
               |
               v
      Chimeway.Traces + 20-VERIFICATION.md + REQUIREMENTS traceability

recovery path
event with no deliveries
        |
        v
Deliveries.recover_event/2
        |
        +--> must replay persisted orchestration snapshot
        +--> otherwise digest_held can degrade to ready and bypass accumulation
```

### Recommended Project Structure

```text
lib/chimeway/digests/
├── accumulation.ex          # extend to schedule per-bucket flush after durable membership insert
├── emission.ex              # keep DB truth boundary for due-ness and idempotent flush
└── digest_bucket.ex         # add any schedule-tracking fields only if a real gap remains

lib/chimeway/dispatch/
├── oban.ex                  # enqueue scheduled DigestFlushWorker jobs using bucket_id + scheduled_at
├── digest_flush_worker.ex   # keep thin worker contract
└── deferred_resume_worker.ex# reference pattern; do not duplicate logic divergently

lib/chimeway/
├── deliveries.ex            # recovery replay fix if Phase 23 absorbs the review warning
└── traces.ex                # keep digest reasoning contract stable through scheduled execution

test/chimeway/digests/
├── flush_scheduling_test.exs
├── emission_test.exs
└── accumulation_test.exs

test/chimeway/integration/
└── digest_delivery_lifecycle_test.exs

test/chimeway/orchestration/
└── recovery_test.exs
```

### Pattern 1: Schedule once from the bucket identity, not from source deliveries

**What:** Insert a future `DigestFlushWorker` job keyed by `bucket_id` and `scheduled_at: bucket.window_ends_at` as soon as a pending bucket is created or extended. [VERIFIED: repo gap + recommended pattern]

**When to use:** Whenever accumulation creates or touches a bucket that is still `flush_state: :pending`. [VERIFIED: lib/chimeway/digests/accumulation.ex + lib/chimeway/digests/digest_bucket.ex]

**Example:**
```elixir
# Source: repo pattern + Oban scheduling docs
job =
  Chimeway.Dispatch.DigestFlushWorker.new(
    %{bucket_id: bucket.id},
    scheduled_at: bucket.window_ends_at
  )

Oban.insert(job)
```
Source posture: `scheduled_at` and unique scheduling are supported by Oban, while the worker still carries only durable identifiers. [CITED: https://hexdocs.pm/oban/Oban.Job.html] [CITED: https://hexdocs.pm/oban/unique_jobs.html]

### Pattern 2: Re-check due-ness and emitted identity under lock inside `emit_bucket/2`

**What:** Keep all correctness inside the existing emission transaction even after a scheduled worker is added. [VERIFIED: lib/chimeway/digests/emission.ex]

**When to use:** Every worker execution, duplicate job execution, and manual replay path. [VERIFIED: codebase read]

**Example:**
```elixir
# Source: lib/chimeway/digests/emission.ex
case Repo.transact(fn ->
       bucket = lock_bucket!(bucket_id)

       cond do
         bucket.flush_state == :emitted and is_binary(bucket.digest_delivery_id) ->
           {:ok, Repo.get!(Delivery, bucket.digest_delivery_id)}

         DateTime.compare(bucket.window_ends_at, emitted_at) == :gt ->
           Repo.rollback({:bucket_not_due, bucket.id})

         true ->
           # resolve members, create/reuse digest delivery, converge rows
       end
     end) do
  {:ok, result} -> {:ok, result}
  {:error, reason} -> {:error, reason}
end
```
This is the same Ecto transaction posture the repo already uses elsewhere. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]

### Pattern 3: Mirror Phase 18's thin-worker + canonical-row ownership pattern

**What:** Keep the worker small and let service modules own state transitions. [VERIFIED: lib/chimeway/dispatch/deferred_resume_worker.ex + lib/chimeway/dispatch/digest_flush_worker.ex]

**When to use:** For digest flush just as for deferred resume. [VERIFIED: codebase read]

**Example:**
```elixir
# Source: lib/chimeway/dispatch/deferred_resume_worker.ex
use Oban.Worker,
  queue: :chimeway_delivery,
  max_attempts: 5,
  replace: [scheduled: [:scheduled_at]],
  unique: [fields: [:args], keys: [:delivery_id], period: 60, timestamp: :scheduled_at]
```
Phase 23 should copy the pattern but swap `delivery_id` for `bucket_id`. [VERIFIED: repo architecture] [CITED: https://hexdocs.pm/oban/unique_jobs.html]

### Pattern 4: Recovery replay must use persisted orchestration, not notifier defaults

**What:** Persist and replay enough orchestration snapshot data so recovered events can still produce `:digest_held` rows when that was the original plan. [VERIFIED: Phase 22 review]

**When to use:** If Phase 23 includes the carried review defect, which I recommend. [VERIFIED: .planning/phases/22-recovery-outcome-analytics/22-REVIEW.md + .planning/STATE.md]

**Example:**
```elixir
# Source: recommended repair based on Phase 22 review
dispatch_opts = [
  event_id: event.id,
  notification_key: event.notification_key,
  correlation_id: event.correlation_id,
  post_commit: true,
  use_persisted_channels: true,
  orchestration: persisted_orchestration_snapshot
]
```

### Anti-Patterns to Avoid

- **In-memory bucket timers:** They are not durable and violate the repo's local-first explainability posture. [VERIFIED: AGENTS.md + codebase architecture]
- **Queue-owned truth:** Oban uniqueness can reduce duplicate work but is not the correctness boundary for emitted digests. [CITED: https://hexdocs.pm/oban/unique_jobs.html]
- **Scheduling by source delivery row:** The due artifact is the bucket window, not any one member row. [VERIFIED: lib/chimeway/digests/digest_bucket.ex]
- **Claiming success without `20-VERIFICATION.md`:** The roadmap explicitly names that artifact, and it does not exist today. [VERIFIED: .planning/ROADMAP.md + phase-20 directory listing]
- **Leaving `recover_event/2` on default immediate orchestration:** That can bypass digest accumulation during recovery and makes DIGEST-02/DIGEST-03 closure misleading. [VERIFIED: .planning/phases/22-recovery-outcome-analytics/22-REVIEW.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Future digest execution | Custom timer process or ETS scheduler [ASSUMED] | Oban `scheduled_at` jobs with thin worker args and DB-backed idempotency [VERIFIED: repo pattern + Oban docs] | The project already has an async seam, test harness, and transaction posture for this. [VERIFIED: lib/chimeway/dispatch/oban.ex + config/test.exs] |
| Duplicate suppression | Application-memory mutexes or queue uniqueness alone [VERIFIED: anti-pattern] | Existing bucket lock + `flush_state` + `digest_delivery_id` reuse inside `emit_bucket/2` [VERIFIED: lib/chimeway/digests/emission.ex] | DB state survives retries, crashes, and duplicate job inserts. [VERIFIED: codebase behavior] |
| Recovery semantics replay | Re-running notifier callbacks and hoping modules still exist [VERIFIED: current recovery posture avoids notifier callbacks] | Persisted orchestration snapshot on notifications, replayed via explicit override [VERIFIED: Phase 22 review recommendation] | Recovery is supposed to work from durable state when notifier callbacks are unavailable. [VERIFIED: lib/chimeway/deliveries.ex + .planning/phases/22-recovery-outcome-analytics/22-REVIEW.md] |
| Verification closure | Unit-only confidence or summary files alone [VERIFIED: current artifact gap] | Production-shaped integration test + `20-VERIFICATION.md` + requirements traceability update [VERIFIED: roadmap + existing artifacts] | The roadmap success criteria explicitly require end-to-end verification and audit cleanup. [VERIFIED: .planning/ROADMAP.md] |

**Key insight:** Phase 23 is a wiring-and-proof phase, not a new digest model phase. Reuse the repo's existing delivery, bucket, worker, and trace seams; only add new persisted fields if an actual correctness hole remains after wiring scheduled bucket jobs. [VERIFIED: codebase read]

## Common Pitfalls

### Pitfall 1: Scheduling flush from the wrong identity

**What goes wrong:** A plan schedules by source `delivery_id` or notification instead of by `bucket_id`, creating duplicate or incomplete flushes when multiple members land in the same window. [VERIFIED: bucket identity model]
**Why it happens:** Deferred resume already schedules by delivery row, and it is tempting to copy it mechanically. [VERIFIED: lib/chimeway/dispatch/deferred_resume_worker.ex]
**How to avoid:** Treat the bucket as the scheduled aggregate and keep worker args to `%{bucket_id: ...}` only. [VERIFIED: roadmap goal + existing `DigestFlushWorker`]
**Warning signs:** Tests pass for single-member digests but not for multi-member windows or duplicate worker execution. [VERIFIED: current test coverage shape]

### Pitfall 2: Letting Oban uniqueness stand in for correctness

**What goes wrong:** The plan assumes a unique job means only one digest can ever emit. [CITED: https://hexdocs.pm/oban/unique_jobs.html]
**Why it happens:** Oban uniqueness feels like deduplication, but the docs state uniqueness is checked at insert time and is not the same as strong runtime execution exclusivity. [CITED: https://hexdocs.pm/oban/unique_jobs.html]
**How to avoid:** Keep bucket lock and emitted-identity reuse in `emit_bucket/2` as the real authority. [VERIFIED: lib/chimeway/digests/emission.ex]
**Warning signs:** The design has no answer for duplicate worker perform calls or crash/retry between insert and perform. [VERIFIED: codebase risk analysis]

### Pitfall 3: Closing DIGEST-02/DIGEST-03 without fixing recovery replay

**What goes wrong:** Ordinary trigger flow works, but recovered events default to `:ready` and skip digest accumulation entirely. [VERIFIED: .planning/phases/22-recovery-outcome-analytics/22-REVIEW.md]
**Why it happens:** `recover_event/2` replays persisted channels but not persisted orchestration semantics. [VERIFIED: lib/chimeway/deliveries.ex + review]
**How to avoid:** Either include the persisted orchestration snapshot fix in Phase 23 or explicitly refuse to mark digest requirements complete until a follow-on phase lands. [VERIFIED: roadmap + review + requirement traceability]
**Warning signs:** Recovery tests cover channel fanout only and never assert `orchestration_state: :digest_held`. [VERIFIED: test/chimeway/orchestration/recovery_test.exs]

### Pitfall 4: Audit closure that updates summaries but not authoritative artifacts

**What goes wrong:** Checkboxes flip to complete while the required verification artifact remains missing or stale. [VERIFIED: current artifact state]
**Why it happens:** There is already a `20-VALIDATION.md`, which can create false confidence that verification documentation exists. [VERIFIED: phase-20 directory listing]
**How to avoid:** Create or replace with `20-VERIFICATION.md`, update `REQUIREMENTS.md` traceability, and ensure roadmap/phase status reflects verified Phase 23 closure. [VERIFIED: roadmap + requirements]
**Warning signs:** The plan never names doc creation/update work, only code and tests. [VERIFIED: roadmap success criteria]

## Code Examples

Verified patterns from official sources and the current repo:

### Schedule a future Oban job
```elixir
# Source: https://hexdocs.pm/oban/Oban.Job.html
scheduled_time = bucket.window_ends_at

%{bucket_id: bucket.id}
|> Chimeway.Dispatch.DigestFlushWorker.new(scheduled_at: scheduled_time)
|> Oban.insert()
```

### Keep complex scheduling work inside one transaction
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Repo.html
Multi.new()
|> Multi.run(:plan_notifications, &do_plan/4)
|> Multi.run(:enqueue_jobs, &do_enqueue/2)
|> Repo.transact()
```

### Current repo pattern for due-state worker scheduling
```elixir
# Source: /Users/jon/projects/chimeway/lib/chimeway/dispatch/oban.ex
job =
  DeferredResumeWorker.new(
    %{delivery_id: delivery.id},
    scheduled_at: delivery.next_eligible_at
  )
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual or test-only digest flush via direct `emit_bucket/2` or manual `DigestFlushWorker` perform. [VERIFIED: codebase + tests] | Automatic scheduled bucket execution should enqueue `DigestFlushWorker` at `window_ends_at`, while `emit_bucket/2` remains the authoritative idempotent execution boundary. [VERIFIED: roadmap + recommended architecture] | Needed now in Phase 23 because Phase 20 stopped at durable emission without runtime scheduling. [VERIFIED: .planning/ROADMAP.md + 20-02 summary] | Closes the last runtime handoff gap for DIGEST-02 and enables truthful end-to-end verification. [VERIFIED: roadmap] |
| Recovery re-drive preserves persisted channels only. [VERIFIED: lib/chimeway/deliveries.ex] | Recovery should also preserve persisted orchestration snapshots when re-planning notifications. [VERIFIED: Phase 22 review recommendation] | Became a visible audit gap in the 2026-04-28 Phase 22 review. [VERIFIED: .planning/phases/22-recovery-outcome-analytics/22-REVIEW.md] | Prevents recovered digestable events from incorrectly becoming immediate sends. [VERIFIED: review] |
| Phase 20 validation intent lives in `20-VALIDATION.md`, but no verification artifact exists. [VERIFIED: phase-20 directory listing] | Phase 23 should produce `20-VERIFICATION.md` and align traceability checkboxes with actual verified behavior. [VERIFIED: roadmap + requirements] | Required by Phase 23 success criteria. [VERIFIED: .planning/ROADMAP.md] | Repairs audit closure and requirement bookkeeping. [VERIFIED: roadmap + requirements] |

**Deprecated/outdated:**
- Treating direct `Digests.emit_bucket/2` invocation as an acceptable steady-state runtime path is outdated for milestone closure because the roadmap now requires automatic scheduling from durable bucket state. [VERIFIED: .planning/ROADMAP.md + lib/chimeway/digests.ex]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A periodic due-bucket scanner would be a viable fallback if the project decides not to schedule one job per bucket. [ASSUMED] | Standard Stack / Alternatives Considered | Planner may over-prescribe a fallback the maintainers do not want; core recommendation still stands without it. |
| A2 | Custom in-memory timer or ETS scheduling would be one of the likely bad alternatives if a developer tries to avoid Oban. [ASSUMED] | Don't Hand-Roll | Low technical risk; this is advisory framing, not a required implementation fact. |

## Open Questions (RESOLVED)

1. **Does Phase 23 own the Phase 22 recovery-orchestration defect?**
   - Resolution: yes. Phase 23 should absorb the `recover_event/2` replay defect because DIGEST-02 and DIGEST-03 remain behaviorally leaky if recovered notifications can degrade from `:digest_held` to immediate send. [VERIFIED: .planning/phases/22-recovery-outcome-analytics/22-REVIEW.md + .planning/REQUIREMENTS.md]
   - Planning impact: include durable orchestration snapshot persistence plus recovery replay coverage in Phase 23 plans and verification artifacts. [VERIFIED: research recommendation]

2. **Should Phase 23 support sync-only installs as "automatic scheduling"?**
   - Resolution: the verified automatic path for milestone closure should be Oban-backed because Oban is the project's recommended async seam, but the phase must also make the non-Oban boundary explicit instead of silently narrowing scope. [VERIFIED: AGENTS.md + .planning/ROADMAP.md]
   - Planning impact: Phase 23 plans should implement automatic bucket scheduling when Oban is configured, add a durable due-bucket fallback seam or explicit host-integration handoff for non-Oban installs, and avoid marking requirement closure until the verification artifact states that scope precisely. [VERIFIED: project stack + checker feedback]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Build and test execution | ✓ [VERIFIED: `elixir --version`] | `1.19.5` [VERIFIED: local command] | — |
| Mix | Test and task entrypoints | ✓ [VERIFIED: `mix --version`] | `1.19.5` [VERIFIED: local command] | — |
| PostgreSQL client | Local DB-backed verification tooling | ✓ [VERIFIED: `psql --version`] | `14.17` client only; project target is `15+`. [VERIFIED: local command + AGENTS.md] | Use existing local test DB for development, but do not claim PG15-shaped verification unless CI/runtime is confirmed on 15+. [VERIFIED: risk assessment] |
| Repo-backed test DB | ExUnit integration tests | ✓ [VERIFIED: local `mix test` pass] | Active enough to run current digest/recovery slice. [VERIFIED: local test run] | — |
| Oban dependency/test config | Scheduled worker testing and production-shaped digest scheduling | ✓ [VERIFIED: mix.lock + config/test.exs] | Repo lock `2.21.1`. [VERIFIED: mix.lock] | Sync dispatcher remains available for non-Oban hosts, but it does not by itself satisfy automatic scheduling. [VERIFIED: config/config.exs + roadmap] |
| Node/npm | Context7 CLI research tooling only | ✓ [VERIFIED: `node --version`, `npm --version`] | Node `22.14.0`, npm `11.1.0`. [VERIFIED: local commands] | Not required for implementation. [VERIFIED: task scope] |

**Missing dependencies with no fallback:**
- None for planning research. [VERIFIED: environment audit]

**Missing dependencies with fallback:**
- PostgreSQL 15 runtime confirmation is missing locally; planner should treat "production-shaped" verification as requiring CI or an explicitly confirmed PG15 environment. [VERIFIED: AGENTS.md + local `psql --version`]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Ecto SQL Sandbox + Oban.Testing where async worker paths are involved. [VERIFIED: test/support/data_case.ex + test files] |
| Config file | `config/test.exs`. [VERIFIED: config/test.exs] |
| Quick run command | `mix test test/chimeway/digests/accumulation_test.exs test/chimeway/digests/emission_test.exs test/chimeway/integration/digest_delivery_lifecycle_test.exs test/chimeway/orchestration/digest_explainability_test.exs test/chimeway/orchestration/recovery_test.exs` [VERIFIED: local command run] |
| Full suite command | `mix test` or `mix ci.test`. [VERIFIED: mix.exs] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DIGEST-02 | Accumulation schedules one flush job for the due bucket automatically, and duplicate scheduling/execution still reuses one emitted digest identity. [VERIFIED: roadmap + current gap] | integration | `mix test test/chimeway/digests/flush_scheduling_test.exs test/chimeway/digests/emission_test.exs test/chimeway/integration/digest_delivery_lifecycle_test.exs` | ❌ Wave 0 |
| DIGEST-03 | Scheduled end-to-end flow preserves digest-held accumulation, emitted digest trace continuity, and recovery replay semantics. [VERIFIED: roadmap + review gap] | integration | `mix test test/chimeway/integration/digest_delivery_lifecycle_test.exs test/chimeway/orchestration/digest_explainability_test.exs test/chimeway/orchestration/recovery_test.exs test/chimeway/traces_test.exs` | ✅ partial / ❌ scheduler-specific gaps |

### Sampling Rate

- **Per task commit:** run the smallest affected digest/recovery slice. [VERIFIED: existing validation posture + local test timing]
- **Per wave merge:** run `mix ci.test`. [VERIFIED: mix.exs]
- **Phase gate:** full suite green plus `20-VERIFICATION.md` updated before `/gsd-verify-work`. [VERIFIED: roadmap success criteria]

### Wave 0 Gaps

- [ ] `test/chimeway/digests/flush_scheduling_test.exs` — proves accumulation schedules exactly one future `DigestFlushWorker` per bucket window and refreshes/respects `scheduled_at` deterministically. [VERIFIED: missing file + current gap]
- [ ] Extend `test/chimeway/integration/digest_delivery_lifecycle_test.exs` — prove a scheduled flush job, not a manual `emit_bucket/2` call, drives the emitted digest through the canonical dispatch path. [VERIFIED: current integration file only covers manual emit/perform]
- [ ] Extend `test/chimeway/orchestration/recovery_test.exs` — add a regression for recovered events that originally require `:digest_held`. [VERIFIED: Phase 22 review + current test file]
- [ ] Create `20-VERIFICATION.md` — document the verified production-shaped path named by the roadmap. [VERIFIED: .planning/ROADMAP.md + phase-20 directory listing]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no [VERIFIED: phase scope] | Host app owns auth boundaries. [VERIFIED: AGENTS.md] |
| V3 Session Management | no [VERIFIED: phase scope] | Not in scope for backend digest scheduling. [VERIFIED: roadmap] |
| V4 Access Control | no direct new surface [VERIFIED: phase scope] | Keep operator APIs under existing host-owned boundaries. [VERIFIED: AGENTS.md] |
| V5 Input Validation | yes [VERIFIED: worker args + persisted snapshots] | Keep worker args to durable IDs only and validate any persisted orchestration snapshot shape through changesets. [VERIFIED: repo pattern + Phase 22 recommendation] |
| V6 Cryptography | no [VERIFIED: phase scope] | No crypto feature is introduced here. [VERIFIED: roadmap] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Duplicate scheduled job insertion or duplicate worker execution | Tampering / DoS | Combine Oban uniqueness with bucket row lock, `flush_state`, and `digest_delivery_id` reuse inside `emit_bucket/2`. [VERIFIED: lib/chimeway/digests/emission.ex] [CITED: https://hexdocs.pm/oban/unique_jobs.html] |
| Recovery replay changes user-visible orchestration outcome | Tampering | Persist orchestration snapshots and replay them explicitly during `recover_event/2`. [VERIFIED: .planning/phases/22-recovery-outcome-analytics/22-REVIEW.md] |
| Sensitive payload leakage in digest/operator surfaces | Information Disclosure | Continue the existing trace posture that exposes rule/window/reason facts only and omits rendered bodies/provider responses. [VERIFIED: AGENTS.md + lib/chimeway/traces.ex] |
| Forged or malformed worker args | Tampering | Keep args to `%{bucket_id}` only and resolve all business facts from canonical DB rows. [VERIFIED: lib/chimeway/dispatch/digest_flush_worker.ex + repo pattern] |

## Sources

### Primary (HIGH confidence)
- Repo code: `lib/chimeway/digests/accumulation.ex`, `lib/chimeway/digests/emission.ex`, `lib/chimeway/dispatch/digest_flush_worker.ex`, `lib/chimeway/dispatch/deferred_resume_worker.ex`, `lib/chimeway/dispatch/oban.ex`, `lib/chimeway/deliveries.ex`, `lib/chimeway/traces.ex`. [VERIFIED: codebase read]
- Project planning artifacts: `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/phases/20-digest-emission-explainability/20-RESEARCH.md`, `.planning/phases/20-digest-emission-explainability/20-02-SUMMARY.md`, `.planning/phases/20-digest-emission-explainability/20-03-SUMMARY.md`, `.planning/phases/22-recovery-outcome-analytics/22-REVIEW.md`, `.planning/phases/22-recovery-outcome-analytics/22-VERIFICATION.md`. [VERIFIED: file reads]
- Oban official docs: `https://hexdocs.pm/oban/Oban.Job.html`, `https://hexdocs.pm/oban/unique_jobs.html`. [CITED]
- Ecto official docs: `https://hexdocs.pm/ecto/Ecto.Repo.html`. [CITED]
- Hex package registry API: `https://hex.pm/api/packages/oban`, `https://hex.pm/api/packages/ecto`, `https://hex.pm/api/packages/ecto_sql`, `https://hex.pm/api/packages/postgrex`. [VERIFIED: hex.pm API]

### Secondary (MEDIUM confidence)
- Context7 `/oban-bg/oban` snippets for scheduled jobs and unique job options, used to cross-check the official Oban docs. [CITED: https://context7.com/oban-bg/oban/llms.txt]
- Context7 `/elixir-ecto/ecto` snippet for `Repo.transact/1` and `Ecto.Multi` examples, used to cross-check the official Ecto docs. [CITED: https://context7.com/elixir-ecto/ecto/llms.txt]

### Tertiary (LOW confidence)
- None beyond the explicitly marked assumptions. [VERIFIED: research log]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - the repo stack, current lock versions, and scheduling docs were all verified directly. [VERIFIED: mix.exs + mix.lock + hex.pm API + official docs]
- Architecture: HIGH - the gap and the reusable Phase 18/20 patterns are explicit in code and roadmap artifacts. [VERIFIED: codebase + roadmap]
- Pitfalls: MEDIUM - the main pitfalls are strongly evidenced by current gaps, while a few cautionary alternatives are advisory. [VERIFIED: codebase + review + assumptions log]

**Research date:** 2026-04-28 [VERIFIED: environment_context]
**Valid until:** 2026-05-05 for package/current-doc currency; architecture findings remain stable unless Phase 23 begins implementation first. [VERIFIED: moving-package dates + phase proximity]

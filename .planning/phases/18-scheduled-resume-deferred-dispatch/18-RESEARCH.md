# Phase 18: Scheduled Resume & Deferred Dispatch - Research

**Researched:** 2026-04-28 [VERIFIED: system clock]
**Domain:** Deferred delivery resume orchestration on Ecto + Oban [VERIFIED: codebase grep]
**Confidence:** MEDIUM [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/oban/Oban.Job.html]

<user_constraints>
## User Constraints (from CONTEXT.md)

Copied verbatim from `.planning/phases/18-scheduled-resume-deferred-dispatch/18-CONTEXT.md`. [VERIFIED: `.planning/phases/18-scheduled-resume-deferred-dispatch/18-CONTEXT.md`]

### Locked Decisions
### Resume Source of Truth
- **D-01:** Deferred resume scheduling should use the existing canonical `chimeway_deliveries` row as the durable source of truth, keyed by `orchestration_state == :deferred` and `next_eligible_at`, instead of introducing a second primary scheduling store.

### Resume Execution Path
- **D-02:** Scheduled resume should transition the existing deferred delivery row back to a dispatchable `:ready` state and then reuse the normal Oban worker execution path for that same delivery.

### Identity and Trace Continuity
- **D-03:** Resume jobs should continue to identify work by `delivery_id` only and must not create replacement delivery rows or move delivery identity into ad hoc scheduler payloads.

### Duplicate Prevention and Final Convergence
- **D-04:** Phase 18 must add durable resume idempotency on the existing delivery row so multiple resume attempts cannot produce duplicate sends, and resumed, cancelled, or superseded deliveries still converge to one durable final outcome.

### the agent's Discretion
- Exact naming of resume helpers, workers, and internal transition APIs.
- Whether scheduling is implemented as a direct-at-time Oban job, a sweep job over eligible deferred rows, or a hybrid, as long as delivery rows remain the source of truth and duplicate execution is prevented.
- Exact metadata or planning-context fields added to improve trace clarity, provided they do not become a second identity source.

### Deferred Ideas (OUT OF SCOPE)
None — analysis stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ORCH-03 | Deferred deliveries resume automatically through durable async scheduling without losing lifecycle traceability. [VERIFIED: `.planning/REQUIREMENTS.md`] | Use a scheduled resume worker keyed by `delivery_id`, promote `:deferred -> :ready` inside a transaction, enqueue the existing `ObanWorker` in the same transaction, and extend trace surfaces with durable resume evidence. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/oban/Oban.Job.html] [CITED: https://hexdocs.pm/oban/2.18.3/Oban.html] |
</phase_requirements>

## Summary

Phase 17 already persists deferral facts on the canonical `chimeway_deliveries` row, gates sync/Oban execution on `orchestration_state == :ready`, and proves that held rows stay `:pending` with zero attempts until a later phase resumes them. [VERIFIED: `.planning/phases/17-delivery-windows-deferral-semantics/17-03-SUMMARY.md`] [VERIFIED: `.planning/phases/17-delivery-windows-deferral-semantics/17-VALIDATION.md`] [VERIFIED: codebase grep]

The best fit for ORCH-03 in this codebase is a dedicated scheduled resume worker, distinct from `Chimeway.Dispatch.ObanWorker`, because the locked phase decision requires a `:deferred -> :ready` transition before the existing dispatch worker runs. [VERIFIED: `.planning/phases/18-scheduled-resume-deferred-dispatch/18-CONTEXT.md`] [VERIFIED: `lib/chimeway/dispatch/oban_worker.ex`] [CITED: https://hexdocs.pm/oban/Oban.Job.html] This is an inference from the current code plus Oban’s built-in `scheduled_at`/`schedule_in` support and unique job options. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/oban/2.19.0/scheduling_jobs.html] [CITED: https://hexdocs.pm/oban/Oban.Job.html]

The highest-risk edge in this phase is not “can Oban wait until a time,” but “can resume remain idempotent when scheduling, promotion, cancellation, and dispatch race each other.” [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/oban/Oban.Job.html] The plan should therefore center on one transactional seam that reloads and conditionally promotes the delivery row, enqueues the normal dispatch worker only after promotion succeeds, and records durable resume evidence for trace continuity. [VERIFIED: `lib/chimeway/dispatch/oban.ex`] [VERIFIED: `lib/chimeway/dispatch/oban_worker.ex`] [VERIFIED: `lib/chimeway/traces.ex`]

**Primary recommendation:** Add a dedicated Oban resume worker that schedules on `next_eligible_at`, atomically promotes `status: :pending, orchestration_state: :deferred` rows back to `:ready`, and inserts the existing `Chimeway.Dispatch.ObanWorker` in the same `Ecto.Multi`. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/oban/2.18.3/Oban.html] [CITED: https://hexdocs.pm/oban/Oban.Job.html]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Deferred-delivery source of truth | Database / Storage | API / Backend | Delivery rows already persist `orchestration_state`, `planning_reason`, `planning_context`, and `next_eligible_at`, and the migration added an index on `[:orchestration_state, :next_eligible_at]`. [VERIFIED: `lib/chimeway/delivery.ex`] [VERIFIED: `priv/repo/migrations/20260428093000_add_delivery_orchestration_fields_to_chimeway_deliveries.exs`] |
| Future-time resume scheduling | API / Backend | Database / Storage | Oban stores scheduled jobs durably and promotes them from `:scheduled` to `:available` after `scheduled_at`; the worker args stay JSON and currently carry only `delivery_id`. [VERIFIED: `lib/chimeway/dispatch/oban_worker.ex`] [CITED: https://hexdocs.pm/oban/Oban.Job.html] [CITED: https://hexdocs.pm/oban/2.19.0/scheduling_jobs.html] |
| Resume promotion and duplicate prevention | API / Backend | Database / Storage | Promotion must mutate the canonical delivery row and reuse the existing dispatch worker, so conditional row updates and transactional enqueue are backend-owned. [VERIFIED: `.planning/phases/18-scheduled-resume-deferred-dispatch/18-CONTEXT.md`] [VERIFIED: `lib/chimeway/dispatch/oban.ex`] |
| Final delivery execution | API / Backend | Database / Storage | The existing `ObanWorker` and shared `Executor` already own dispatch, retries, and terminal convergence. [VERIFIED: `lib/chimeway/dispatch/oban_worker.ex`] [VERIFIED: `lib/chimeway/dispatch/executor.ex`] |
| Operator trace continuity | API / Backend | Database / Storage | `Chimeway.Traces.explain_delivery/2` reconstructs lifecycle explanations from the durable event -> notification -> delivery -> attempt chain. [VERIFIED: `lib/chimeway/traces.ex`] [VERIFIED: `lib/chimeway/traces/explanation.ex`] |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ecto_sql` | `3.13.5` published 2026-03-03 [VERIFIED: `mix.lock`] [CITED: https://hex.pm/packages/ecto_sql/versions] | Transactional row updates and `Ecto.Multi` orchestration. [VERIFIED: `mix.lock`] [VERIFIED: `lib/chimeway/dispatch/oban.ex`] | The current code already uses `Ecto.Multi` for atomic planning + enqueue, which is the correct seam for transactional resume promotion. [VERIFIED: `lib/chimeway/dispatch/oban.ex`] |
| `oban` | `2.21.1` published 2026-03-26 [VERIFIED: `mix.lock`] [CITED: https://hex.pm/packages/oban/versions] | Durable async scheduling, unique jobs, and worker execution. [VERIFIED: `mix.lock`] [VERIFIED: `lib/chimeway/dispatch/oban_worker.ex`] | Oban already supports future scheduling and uniqueness keyed by args and `scheduled_at`, which avoids building a second scheduler store. [CITED: https://hexdocs.pm/oban/Oban.Job.html] |
| `ecto` | `3.13.5` published 2025-11-09 [VERIFIED: `mix.lock`] [CITED: https://hex.pm/packages/ecto/versions] | Changesets, row fetching, and conditional state transitions. [VERIFIED: `mix.lock`] [VERIFIED: `lib/chimeway/deliveries.ex`] | Delivery lifecycle state is already encoded in Ecto schemas and transitions, so resume should extend that layer rather than bypass it. [VERIFIED: `lib/chimeway/delivery.ex`] [VERIFIED: `lib/chimeway/deliveries.ex`] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `postgrex` | `0.22.0` published 2026-01-10 [VERIFIED: `mix.lock`] [CITED: https://hex.pm/packages/postgrex/versions] | PostgreSQL driver backing Ecto + Oban persistence. [VERIFIED: `mix.lock`] | Use for all durable scheduling and row-locking behavior already in the app’s repo path. [VERIFIED: `lib/chimeway/deliveries.ex`] |
| `ExUnit` | bundled with Elixir `1.19.5` in this environment. [VERIFIED: `elixir --version`] | Existing test harness for integration, reliability, and Oban worker tests. [VERIFIED: `test/test_helper.exs`] | Use for resume scheduling, race-condition, and trace regression tests. [VERIFIED: codebase grep] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| One scheduled resume job per delivery row | Sweep worker over `orchestration_state == :deferred AND next_eligible_at <= now()` | A sweep job can work within the phase discretion, but it adds batch fan-out logic and larger concurrency windows before the canonical row is promoted. [VERIFIED: `.planning/phases/18-scheduled-resume-deferred-dispatch/18-CONTEXT.md`] [ASSUMED] |
| Dedicated resume worker + existing dispatch worker | Schedule `Chimeway.Dispatch.ObanWorker` directly in the future | Directly scheduling the dispatch worker would violate D-02 because the worker currently no-ops when `orchestration_state != :ready`. [VERIFIED: `.planning/phases/18-scheduled-resume-deferred-dispatch/18-CONTEXT.md`] [VERIFIED: `lib/chimeway/dispatch/oban_worker.ex`] |

**Installation:** Existing dependencies already cover this phase; no new Hex package is required if the plan keeps the Oban-backed design. [VERIFIED: `mix.exs`] [VERIFIED: `mix.lock`]

```bash
mix deps.get
```

## Architecture Patterns

### System Architecture Diagram

```text
trigger/planning policy
  -> canonical delivery row (`status: pending`, `orchestration_state: deferred`, `next_eligible_at`)
  -> resume job scheduled at `next_eligible_at`
  -> resume worker reloads delivery by `delivery_id`
  -> conditional promotion transaction
       -> if row is still `pending + deferred + eligible`: update to `:ready`
       -> insert normal `Chimeway.Dispatch.ObanWorker` job in same transaction
       -> record durable resume evidence for traces
       -> else: no-op
  -> existing Oban dispatch worker
  -> `Executor.run_delivery/1`
  -> attempt row + final delivery state
  -> `Traces.explain_delivery/2`
```

The critical boundary is that the resume worker owns only scheduling-to-readiness promotion; it must not fork delivery execution logic away from `Chimeway.Dispatch.ObanWorker` or `Executor.run_delivery/1`. [VERIFIED: `.planning/phases/18-scheduled-resume-deferred-dispatch/18-CONTEXT.md`] [VERIFIED: `lib/chimeway/dispatch/oban_worker.ex`] [VERIFIED: `lib/chimeway/dispatch/executor.ex`]

### Recommended Project Structure

```text
lib/chimeway/
├── deliveries.ex                 # add resume transition/query helpers
├── dispatch/oban.ex              # schedule resume jobs transactionally
├── dispatch/oban_worker.ex       # unchanged execution path, possibly shared enqueue helper
├── dispatch/resume_worker.ex     # new scheduled promotion worker
├── traces.ex                     # add durable resume timeline shaping
└── traces/explanation.ex         # expand explanation contract if resume fields are exposed

test/chimeway/
├── orchestration/deferred_resume_test.exs
├── orchestration/traces_resume_test.exs
├── integration/delivery_lifecycle_test.exs
└── reliability/deferred_resume_race_test.exs
```

This file map is prescriptive for planning boundaries, not a guarantee that every listed file must change. [VERIFIED: codebase grep] [ASSUMED]

### Pattern 1: Transactional Resume Promotion
**What:** Reload the delivery row inside an `Ecto.Multi`, promote it from `:deferred` to `:ready` only when it is still eligible, and insert the normal dispatch worker before committing. [VERIFIED: `lib/chimeway/dispatch/oban.ex`] [VERIFIED: `lib/chimeway/deliveries.ex`] [CITED: https://hexdocs.pm/oban/2.18.3/Oban.html]
**When to use:** Every automated resume path for ORCH-03. [VERIFIED: `.planning/REQUIREMENTS.md`]
**Example:**
```elixir
# Source: existing Multi pattern in lib/chimeway/dispatch/oban.ex
Ecto.Multi.new()
|> Ecto.Multi.run(:promote_delivery, fn _repo, _changes ->
  Chimeway.Deliveries.promote_deferred_delivery(delivery_id, DateTime.utc_now())
end)
|> Oban.insert(:dispatch_job, fn %{promote_delivery: delivery} ->
  Chimeway.Dispatch.ObanWorker.new(%{delivery_id: delivery.id})
end)
|> Chimeway.Repo.transaction()
```

### Pattern 2: Scheduled Resume Job Per Delivery
**What:** Insert one dedicated resume job keyed by `delivery_id` and scheduled at `next_eligible_at`, using Oban job uniqueness to prevent duplicate scheduled resumes. [CITED: https://hexdocs.pm/oban/2.19.0/scheduling_jobs.html] [CITED: https://hexdocs.pm/oban/Oban.Job.html]
**When to use:** When `apply_planning_decision/2` or later orchestration logic leaves a row in `:deferred` with a non-nil `next_eligible_at`. [VERIFIED: `lib/chimeway/deliveries.ex`] [VERIFIED: `lib/chimeway/policy/settings.ex`]
**Example:**
```elixir
# Source: Oban scheduling and uniqueness docs
Chimeway.Dispatch.ResumeWorker.new(
  %{delivery_id: delivery.id},
  scheduled_at: delivery.next_eligible_at,
  unique: [fields: [:args], keys: [:delivery_id], timestamp: :scheduled_at]
)
```

### Pattern 3: Durable Trace Preservation
**What:** Preserve deferral facts and record resume facts durably on the same delivery row so `Traces.explain_delivery/2` can show both the hold and the resume without relying on transient Oban state. [VERIFIED: `lib/chimeway/traces.ex`] [VERIFIED: `.planning/phases/17-delivery-windows-deferral-semantics/17-03-SUMMARY.md`]
**When to use:** On every successful or skipped resume attempt. [VERIFIED: `.planning/ROADMAP.md`] [ASSUMED]
**Example:**
```elixir
# Source: trace contract in lib/chimeway/traces.ex and lib/chimeway/traces/explanation.ex
%{
  "resume_scheduled_at" => delivery.next_eligible_at,
  "resumed_at" => DateTime.utc_now(),
  "resume_source" => "scheduled_resume"
}
```

### Anti-Patterns to Avoid
- **Scheduling `ObanWorker` directly for future execution:** The current worker exits early unless the row is already `:ready`, so this would silently skip deferred deliveries instead of resuming them. [VERIFIED: `lib/chimeway/dispatch/oban_worker.ex`]
- **Clearing planning facts without copying them elsewhere:** `planning_reason`, `planning_context`, and `next_eligible_at` are the current trace explanation inputs, so dropping them would regress explainability. [VERIFIED: `lib/chimeway/traces.ex`] [VERIFIED: `lib/chimeway/traces/explanation.ex`]
- **Using `delivery.updated_at` as the only resume timestamp:** later attempt or cancellation updates overwrite `updated_at`, so it cannot be the sole durable source for a resume timeline entry. [VERIFIED: `lib/chimeway/traces.ex`] [ASSUMED]
- **Promoting to `:ready` outside the same transaction that enqueues dispatch:** that creates “ready but orphaned” rows if enqueue fails after the state change. [VERIFIED: `lib/chimeway/dispatch/oban.ex`] [VERIFIED: `test/chimeway/dispatch/oban_transactional_test.exs`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Future-time resume scheduling | Custom polling table or in-memory timer registry | Oban scheduled jobs with `scheduled_at`/`schedule_in` | Oban already persists future execution and transitions jobs from `:scheduled` to `:available`. [CITED: https://hexdocs.pm/oban/Oban.Job.html] |
| Duplicate scheduled resumes | Ad hoc “resume lock” metadata only | Oban job uniqueness plus conditional row promotion | Uniqueness prevents redundant job rows, and the canonical delivery-row check handles races that uniqueness alone cannot eliminate. [CITED: https://hexdocs.pm/oban/Oban.Job.html] [VERIFIED: `lib/chimeway/deliveries.ex`] |
| Resume execution logic | Second adapter/attempt pipeline | Existing `Chimeway.Dispatch.ObanWorker` + `Executor.run_delivery/1` | Retry mapping, terminal convergence, and delivery-id execution already live there. [VERIFIED: `lib/chimeway/dispatch/oban_worker.ex`] [VERIFIED: `lib/chimeway/dispatch/executor.ex`] |
| Operator-facing explanation | Reading Oban job state directly in traces | Delivery-row planning/resume facts surfaced through `Traces.explain_delivery/2` | Current explainability is intentionally built from durable lifecycle rows, not background-job internals. [VERIFIED: `.planning/phases/17-delivery-windows-deferral-semantics/17-03-SUMMARY.md`] [VERIFIED: `lib/chimeway/traces.ex`] |

**Key insight:** Oban should be the durable clock, but `chimeway_deliveries` must remain the durable truth about whether a delivery is still deferred, resumed, cancelled, or already terminal. [VERIFIED: `.planning/phases/18-scheduled-resume-deferred-dispatch/18-CONTEXT.md`] [CITED: https://hexdocs.pm/oban/Oban.Job.html]

## Common Pitfalls

### Pitfall 1: Duplicate Resume Jobs Rescheduling the Same Delivery
**What goes wrong:** multiple planning passes or manual re-schedules insert multiple future resume jobs for the same `delivery_id`, which can produce redundant ready transitions or redundant dispatch job inserts. [VERIFIED: `test/chimeway/dispatch/oban_transactional_test.exs`] [CITED: https://hexdocs.pm/oban/Oban.Job.html]
**Why it happens:** the current worker uniqueness is `delivery_id` plus a 60-second period on the dispatch worker, not a dedicated scheduled-resume uniqueness strategy. [VERIFIED: `lib/chimeway/dispatch/oban_worker.ex`]
**How to avoid:** use a dedicated resume worker with uniqueness keyed by `delivery_id` and `scheduled_at`, and make the row promotion conditional on `status == :pending` and `orchestration_state == :deferred`. [CITED: https://hexdocs.pm/oban/Oban.Job.html] [VERIFIED: `lib/chimeway/delivery.ex`]
**Warning signs:** more than one scheduled resume job for the same delivery or a delivery that flips to `:ready` multiple times in tests. [ASSUMED]

### Pitfall 2: Lost Dispatch After Successful Promotion
**What goes wrong:** a delivery becomes `:ready` but never dispatches because enqueue failed after the state update. [VERIFIED: `test/chimeway/dispatch/oban_transactional_test.exs`]
**Why it happens:** promotion and dispatch enqueue happen in separate transactions or separate code paths. [VERIFIED: `lib/chimeway/dispatch/oban.ex`] [ASSUMED]
**How to avoid:** reuse the existing transactional Oban insertion pattern and fail the whole resume transaction if dispatch job insertion fails. [VERIFIED: `lib/chimeway/dispatch/oban.ex`] [CITED: https://hexdocs.pm/oban/2.18.3/Oban.html]
**Warning signs:** rows stuck in `:ready` with zero attempts and no enqueued job. [ASSUMED]

### Pitfall 3: Trace Regression After Resume
**What goes wrong:** once the delivery resumes, `Traces.explain_delivery/2` can no longer answer why it was held or when it resumed. [VERIFIED: `lib/chimeway/traces.ex`] [ASSUMED]
**Why it happens:** the current trace contract only knows about a `:deferred` timeline event and derives that event from mutable delivery fields. [VERIFIED: `lib/chimeway/traces.ex`] [VERIFIED: `lib/chimeway/traces/explanation.ex`]
**How to avoid:** keep original planning facts durable and add explicit durable resume evidence that traces can surface as a second timeline entry. [VERIFIED: `.planning/phases/17-delivery-windows-deferral-semantics/17-03-SUMMARY.md`] [ASSUMED]
**Warning signs:** resumed deliveries show attempts and final state but no clear “held until / resumed at” explanation. [ASSUMED]

### Pitfall 4: Terminal-State Races
**What goes wrong:** a cancelled or suppressed delivery is resumed anyway and produces an unnecessary dispatch job. [VERIFIED: `test/chimeway/reliability/terminal_convergence_test.exs`] [ASSUMED]
**Why it happens:** the resume path checks only `delivery_id` without validating the current durable status. [VERIFIED: `.planning/phases/18-scheduled-resume-deferred-dispatch/18-CONTEXT.md`] [ASSUMED]
**How to avoid:** the promotion helper must no-op unless the row is still `pending`, `deferred`, and eligible by timestamp. [VERIFIED: `lib/chimeway/delivery.ex`] [ASSUMED]
**Warning signs:** extra dispatch jobs or attempts appear after a manual cancellation path in tests. [ASSUMED]

## Code Examples

Verified patterns from official sources and the current codebase:

### Schedule a Durable Future Resume
```elixir
# Source: https://hexdocs.pm/oban/2.19.0/scheduling_jobs.html
%{delivery_id: delivery.id}
|> Chimeway.Dispatch.ResumeWorker.new(scheduled_at: delivery.next_eligible_at)
|> Oban.insert()
```

### Insert a Worker Inside an Ecto.Multi
```elixir
# Source: lib/chimeway/dispatch/oban.ex and https://hexdocs.pm/oban/2.18.3/Oban.html
Ecto.Multi.new()
|> Oban.insert(:dispatch_job, Chimeway.Dispatch.ObanWorker.new(%{delivery_id: delivery.id}))
|> Chimeway.Repo.transaction()
```

### Guard Final Execution on Delivery State
```elixir
# Source: lib/chimeway/dispatch/oban_worker.ex
if delivery.status in Deliveries.terminal_states() or delivery.orchestration_state != :ready do
  :ok
else
  handle_delivery(delivery, attempt, max_attempts)
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Held rows could still flow into immediate dispatch paths. [VERIFIED: `.planning/phases/17-delivery-windows-deferral-semantics/17-03-SUMMARY.md`] | Sync and Oban now require `orchestration_state == :ready` before execution. [VERIFIED: `lib/chimeway/dispatch/sync.ex`] [VERIFIED: `lib/chimeway/dispatch/oban.ex`] [VERIFIED: `lib/chimeway/dispatch/oban_worker.ex`] | Phase 17 on 2026-04-28. [VERIFIED: `.planning/phases/17-delivery-windows-deferral-semantics/17-03-SUMMARY.md`] | Phase 18 must add an explicit resume promotion step; there is no accidental execution path left. [VERIFIED: codebase grep] |
| Deferral could have been modeled only in scheduler state. [VERIFIED: `.planning/phases/17-delivery-windows-deferral-semantics/17-03-SUMMARY.md`] | Deferral facts now live on the delivery row via `planning_reason`, `planning_context`, and `next_eligible_at`. [VERIFIED: `lib/chimeway/delivery.ex`] [VERIFIED: `lib/chimeway/deliveries.ex`] | Phase 17 on 2026-04-28. [VERIFIED: `.planning/phases/17-delivery-windows-deferral-semantics/17-03-SUMMARY.md`] | Resume design must preserve delivery-row explainability rather than shifting to Oban-only visibility. [VERIFIED: `.planning/phases/18-scheduled-resume-deferred-dispatch/18-CONTEXT.md`] |

**Deprecated/outdated:**
- “Held rows remain pending with zero attempts until a later phase adds explicit resume scheduling” is the deliberate pre-Phase-18 contract and should be replaced only by a transactional resume design, not by loosening ready-state gates. [VERIFIED: `.planning/phases/17-delivery-windows-deferral-semantics/17-03-SUMMARY.md`] [VERIFIED: `lib/chimeway/dispatch/sync.ex`] [VERIFIED: `lib/chimeway/dispatch/oban_worker.ex`]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A per-delivery scheduled resume worker is preferable to a sweep job for this phase’s scope and risk profile. | Standard Stack / Architecture Patterns | Planner may choose the wrong task shape if batch sweeping is actually simpler in this repo. |
| A2 | `delivery.updated_at` should not be the only durable resume timestamp because later lifecycle updates will overwrite it. | Architecture Patterns / Common Pitfalls | Traces could lose resume-time evidence if the planner treats `updated_at` as sufficient. |
| A3 | The phase will likely need new targeted orchestration/reliability test files rather than only modifying existing tests. | Recommended Project Structure | Plan boundaries may be too wide or too narrow. |

## Open Questions (RESOLVED)

1. **`next_eligible_at` remains populated after resume as durable historical evidence.**
   - Resolution: Phase 18 should preserve the original deferred-until timestamp on the canonical delivery row because current explanation surfaces already depend on `planning_reason`, `planning_context`, and `next_eligible_at`. [VERIFIED: `lib/chimeway/traces.ex`] [VERIFIED: `lib/chimeway/traces/explanation.ex`]
   - Implementation consequence: resume logic must add separate durable audit fields such as `resume_scheduled_at` and `resumed_at` rather than clearing `next_eligible_at` and losing the original deferral fact. [VERIFIED: codebase grep] [ASSUMED]

2. **Digest-held rows remain untouched in Phase 18.**
   - Resolution: Phase 18 stays strictly deferred-only; digest-held rows continue to short-circuit exactly as they do today, and Phase 19 remains the first phase allowed to change digest accumulation or digest execution behavior. [VERIFIED: `.planning/REQUIREMENTS.md`] [VERIFIED: `.planning/ROADMAP.md`] [VERIFIED: `test/chimeway/orchestration/dispatch_gating_test.exs`]
   - Implementation consequence: helper names and tests may defensively reject `:digest_held`, but no Phase 18 task should schedule, resume, or mutate digest-held rows beyond preserving their existing no-op execution behavior. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Compile and run phase tests. [VERIFIED: `mix.exs`] | ✓ [VERIFIED: `elixir --version`] | `1.19.5` [VERIFIED: `elixir --version`] | — |
| Mix | Run `mix test` and existing `ci.*` / `verify.*` entrypoints. [VERIFIED: `mix.exs`] | ✓ [VERIFIED: `mix --version`] | `1.19.5` [VERIFIED: `mix --version`] | — |
| PostgreSQL client | Local DB inspection and psql-driven debugging. [VERIFIED: environment probe] | ✓ [VERIFIED: `psql --version`] | `14.17` [VERIFIED: `psql --version`] | Existing test setup already works without direct `psql` usage. [VERIFIED: `mix test test/chimeway/orchestration/dispatch_gating_test.exs test/chimeway/integration/delivery_lifecycle_test.exs --trace`] |
| Oban dependency | Scheduled resume and worker execution. [VERIFIED: `mix.exs`] | ✓ in codebase deps [VERIFIED: `mix.lock`] | `2.21.1` [VERIFIED: `mix.lock`] | No acceptable fallback inside ORCH-03 scope because Roadmap Phase 18 success criteria explicitly call for Oban-backed scheduling. [VERIFIED: `.planning/ROADMAP.md`] |

**Missing dependencies with no fallback:**
- None found during research. [VERIFIED: environment probe]

**Missing dependencies with fallback:**
- Local `psql` is `14.17` while project guidance says PostgreSQL `15+`; this matters only if a planner task requires direct local server setup rather than the current test harness. [VERIFIED: `AGENTS.md`] [VERIFIED: `psql --version`]

## Validation Architecture

This section is warranted because `.planning/config.json` has `workflow.nyquist_validation: true`, the project already keeps adjacent phase validation artifacts, and ORCH-03 introduces new concurrency and trace-regression risk that should be captured in `18-VALIDATION.md`. [VERIFIED: `.planning/config.json`] [VERIFIED: `.planning/phases/17-delivery-windows-deferral-semantics/17-VALIDATION.md`] [VERIFIED: `.planning/REQUIREMENTS.md`]

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit on Elixir `1.19.5`. [VERIFIED: `test/test_helper.exs`] [VERIFIED: `elixir --version`] |
| Config file | `test/test_helper.exs`. [VERIFIED: `test/test_helper.exs`] |
| Quick run command | `mix test test/chimeway/orchestration/dispatch_gating_test.exs test/chimeway/integration/delivery_lifecycle_test.exs --trace` [VERIFIED: command run] |
| Full suite command | `mix test` [VERIFIED: `mix.exs`] |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ORCH-03 | Scheduling a deferred row creates exactly one durable future resume job keyed by `delivery_id` and due time. [VERIFIED: `.planning/REQUIREMENTS.md`] [ASSUMED] | unit/integration | `mix test test/chimeway/orchestration/deferred_resume_test.exs --trace` | ❌ Wave 0 |
| ORCH-03 | Resume worker promotes only `pending + deferred + eligible` rows and enqueues the normal dispatch worker transactionally. [VERIFIED: `.planning/ROADMAP.md`] [ASSUMED] | integration | `mix test test/chimeway/orchestration/deferred_resume_test.exs test/chimeway/dispatch/oban_transactional_test.exs --trace` | ❌ Wave 0 |
| ORCH-03 | Duplicate resume execution, cancellation races, and re-entry do not create duplicate sends or extra attempts. [VERIFIED: `.planning/ROADMAP.md`] [ASSUMED] | reliability/concurrency | `mix test test/chimeway/reliability/deferred_resume_race_test.exs --trace` | ❌ Wave 0 |
| ORCH-03 | Trace surfaces still explain why the delivery was deferred and when/how it resumed. [VERIFIED: `.planning/REQUIREMENTS.md`] [ASSUMED] | unit/integration | `mix test test/chimeway/orchestration/traces_resume_test.exs test/chimeway/integration/delivery_lifecycle_test.exs --trace` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** run the smallest targeted file set for the seam being changed. [VERIFIED: codebase testing pattern]
- **Per wave merge:** run all Phase 18 targeted tests plus existing gating/lifecycle coverage. [VERIFIED: `.planning/phases/17-delivery-windows-deferral-semantics/17-VALIDATION.md`] [ASSUMED]
- **Phase gate:** `mix test` must be green before `/gsd-verify-work`. [VERIFIED: `mix.exs`]

### Wave 0 Gaps
- [ ] `test/chimeway/orchestration/deferred_resume_test.exs` — scheduling + promotion coverage for ORCH-03. [ASSUMED]
- [ ] `test/chimeway/orchestration/traces_resume_test.exs` — resume timeline / explanation coverage. [ASSUMED]
- [ ] `test/chimeway/reliability/deferred_resume_race_test.exs` — concurrent resume, terminal-race, and duplicate-send coverage. [ASSUMED]
- [ ] Existing `17-VALIDATION.md` style commands should use `--trace` instead of `-x` on this Mix version. [VERIFIED: `.planning/phases/17-delivery-windows-deferral-semantics/17-03-SUMMARY.md`] [VERIFIED: command run]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no for this internal worker phase. [ASSUMED] | Host app owns auth boundaries per project guidance. [VERIFIED: `AGENTS.md`] |
| V3 Session Management | no for this internal worker phase. [ASSUMED] | — |
| V4 Access Control | yes [ASSUMED] | Preserve tenancy/correlation ownership boundaries and keep trace queries on the canonical delivery row rather than cross-tenant scheduler payloads. [VERIFIED: `AGENTS.md`] [VERIFIED: `lib/chimeway/traces.ex`] |
| V5 Input Validation | yes [VERIFIED: codebase grep] | Continue validating worker args around `delivery_id` and durable row state before promotion/execution. [VERIFIED: `lib/chimeway/dispatch/oban_worker.ex`] [ASSUMED] |
| V6 Cryptography | no for this phase. [ASSUMED] | — |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Duplicate send through concurrent resume paths | Tampering | Oban uniqueness plus conditional row promotion and existing terminal-state short-circuits. [CITED: https://hexdocs.pm/oban/Oban.Job.html] [VERIFIED: `lib/chimeway/dispatch/oban_worker.ex`] |
| Resume of cancelled/suppressed delivery | Elevation of Privilege / Tampering | Re-check durable status in the promotion helper and no-op unless the row is still eligible. [VERIFIED: `lib/chimeway/delivery.ex`] [ASSUMED] |
| Payload leakage in traces or telemetry | Information Disclosure | Extend only sanitized trace surfaces and avoid putting raw payload/provider response into resume metadata. [VERIFIED: `AGENTS.md`] [VERIFIED: `lib/chimeway/traces.ex`] |
| Orphan `:ready` rows after partial failure | Repudiation / Availability | Keep promotion and dispatch enqueue in one transaction using the existing Oban Multi pattern. [VERIFIED: `lib/chimeway/dispatch/oban.ex`] [VERIFIED: `test/chimeway/dispatch/oban_transactional_test.exs`] |

## Sources

### Primary (HIGH confidence)
- `lib/chimeway/delivery.ex` - orchestration fields and delivery schema surface.
- `lib/chimeway/deliveries.ex` - planning persistence, transition semantics, and existing transactional attempt logic.
- `lib/chimeway/dispatch/oban.ex` - current transactional Oban enqueue seam.
- `lib/chimeway/dispatch/oban_worker.ex` - delivery-id worker contract, uniqueness, retry mapping, and ready-state short-circuit.
- `lib/chimeway/traces.ex` - current explanation and timeline logic.
- `.planning/phases/18-scheduled-resume-deferred-dispatch/18-CONTEXT.md` - locked phase decisions and scope.
- `.planning/phases/17-delivery-windows-deferral-semantics/17-03-SUMMARY.md` - carry-forward constraints from Phase 17.
- `.planning/phases/17-delivery-windows-deferral-semantics/17-VALIDATION.md` - prior validation boundary.
- `https://hexdocs.pm/oban/Oban.Job.html` - scheduled jobs, unique jobs, job states.
- `https://hexdocs.pm/oban/2.19.0/scheduling_jobs.html` - scheduled-at / schedule-in behavior and UTC scheduling.
- `https://hexdocs.pm/oban/2.18.3/Oban.html` - `Oban.insert` inside `Ecto.Multi` and worker option guidance.

### Secondary (MEDIUM confidence)
- `https://hex.pm/packages/oban/versions` - package version and publish date.
- `https://hex.pm/packages/ecto_sql/versions` - package version and publish date.
- `https://hex.pm/packages/ecto/versions` - package version and publish date.
- `https://hex.pm/packages/postgrex/versions` - package version and publish date.

### Tertiary (LOW confidence)
- None. [VERIFIED: research log]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - existing deps and official package/docs sources are explicit. [VERIFIED: `mix.lock`] [CITED: https://hex.pm/packages/oban/versions]
- Architecture: MEDIUM - the recommended resume-worker shape is a reasoned fit to locked decisions and current code, but it remains a design recommendation until implemented. [VERIFIED: `.planning/phases/18-scheduled-resume-deferred-dispatch/18-CONTEXT.md`] [ASSUMED]
- Pitfalls: MEDIUM - most are grounded in current code constraints, but some failure modes are predictive until dedicated Phase 18 tests exist. [VERIFIED: codebase grep] [ASSUMED]

**Research date:** 2026-04-28 [VERIFIED: system clock]
**Valid until:** 2026-05-28 for codebase findings; re-check Oban docs sooner if package versions move. [VERIFIED: codebase grep] [CITED: https://hex.pm/packages/oban/versions]

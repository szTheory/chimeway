# Phase 25: Progression Engine & Wait Gates - Research

**Researched:** 2026-04-29
**Domain:** Workflow progression outcome model for wait gates and duplicate-safe branching
**Confidence:** HIGH for repo-fit recommendation; MEDIUM for the exact curated outcome vocabulary

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| WRK-02 | Each workflow step can define explicit progression rules based on elapsed time or the prior delivery outcome. | Use a curated workflow-facing outcome layer derived deterministically from persisted delivery state and last-attempt facts, then branch on that layer instead of raw delivery status or raw attempt outcome. [ASSUMED] |
| ESC-03 | Workflow progression and escalation remain idempotent and concurrency-safe under retries, duplicate claims, or repeated host calls. | Keep delivery rows as canonical truth, resolve the branch outcome from persisted rows inside the same transaction/lock that appends workflow transitions, and persist the chosen outcome in transition context for replay-safe explainability. [ASSUMED] |

</phase_requirements>

## Summary

Chimeway already models delivery lifecycle truth and attempt-level execution detail as separate concepts. `Delivery.status` is the durable lifecycle state, `Delivery.suppression_reason` carries operator-visible cause for suppressed/cancelled endings, and `DeliveryAttempt` is append-only execution history with `outcome`, `attempt_number`, and `error_class`. `Traces.explain_delivery/1` also presents `status` and `last_attempt` as separate fields rather than collapsing them into one outcome. [VERIFIED: repo grep]

That separation is the key design signal for Phase 25. Branching directly on canonical delivery status is durable but too coarse for least-surprise workflow semantics. Branching directly on last-attempt outcome is too volatile and too coupled to retry machinery. The best fit is a curated workflow-facing outcome layer that is derived from canonical persisted rows at progression time and then persisted into workflow transition context for replay, operator clarity, and idempotency. [ASSUMED]

**Primary recommendation:** Branch workflows on curated workflow-facing outcomes derived from `delivery.status`, `delivery.suppression_reason`, and, when needed, the latest persisted `attempt.error_class`; do not branch directly on raw `last_attempt.outcome`. [ASSUMED]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Determine whether a prior step is branchable yet | Workflow progression service | Delivery row | The workflow engine should decide when to advance, but the decision must read canonical delivery facts rather than queue state. [VERIFIED: repo grep] |
| Provide durable delivery truth | `chimeway_deliveries` | `chimeway_delivery_attempts` | Delivery rows already own lifecycle status and suppression reasons; attempts are append-only evidence of provider calls. [VERIFIED: repo grep] |
| Explain why a workflow advanced | `chimeway_workflow_transitions` | traces layer later | Workflow transitions already exist as append-only reason-bearing history rows. [VERIFIED: repo grep] |
| Prevent duplicate progression | Workflow progression transaction/lock | Oban uniqueness | Oban can help prevent duplicate workers, but domain idempotency still needs persisted run/step guards because job uniqueness is queue-level rather than workflow-domain truth. [CITED: https://hexdocs.pm/oban/Oban.Job.html] [CITED: https://hexdocs.pm/oban/Oban.Worker.html] [ASSUMED] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---|---|---|---|
| Elixir | 1.17+ baseline | Runtime and language | Project baseline requires Elixir 1.17+. [VERIFIED: AGENTS.md] |
| Ecto | 3.13.5 | Durable workflow/delivery persistence and transactional progression | Existing Chimeway delivery/workflow state is already modeled with Ecto schemas and transactions. [VERIFIED: mix deps] [VERIFIED: repo grep] |
| Oban | 2.21.1 | Scheduled wait gates and duplicate-resistant background progression | Existing async orchestration already uses Oban, and its uniqueness/scheduling model fits due-step workers without replacing Chimeway-owned workflow truth. [VERIFIED: mix deps] [CITED: https://hexdocs.pm/oban/Oban.Worker.html] [CITED: https://hexdocs.pm/oban/Oban.Job.html] |

### Supporting

| Library | Version | Purpose | When to Use |
|---|---|---|---|
| Existing workflow schemas | current repo | Persist workflow run state and append-only transitions | Use for all progression decisions so wait/branch history remains replayable from Chimeway-owned rows. [VERIFIED: repo grep] |
| Existing delivery/attempt schemas | current repo | Compute prior-step outcome | Use whenever progression depends on delivery result rather than external host signal input. [VERIFIED: repo grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Curated workflow-facing outcomes | Raw delivery status | Simpler storage, but it hides important distinctions inside `suppression_reason` and makes branch rules harder to read. [VERIFIED: repo grep] [ASSUMED] |
| Curated workflow-facing outcomes | Raw last-attempt outcome | More direct access to provider result, but it binds workflow semantics to retry noise and can change across attempts before durable convergence. [VERIFIED: repo grep] [ASSUMED] |

## Repo Findings

### Current delivery truth model

- `Delivery.status` is an `Ecto.Enum` with `:pending | :dispatched | :succeeded | :failed | :suppressed | :cancelled | :digested`. [VERIFIED: repo grep]
- `Delivery.suppression_reason` stores operator-facing reasons such as policy suppression and terminal cancellation reasons. [VERIFIED: repo grep]
- `DeliveryAttempt.outcome` is an `Ecto.Enum` with `:succeeded | :failed | :bounced | :rejected`, and `error_class` is stored separately as a string. [VERIFIED: repo grep]
- `Deliveries.record_attempt/2` serializes concurrent attempt writes with `SELECT ... FOR UPDATE`, computes `attempt_number` inside the same `Ecto.Multi`, and maps permanent/bounced failures to terminal delivery cancellation in the same transaction. [VERIFIED: repo grep]
- `Chimeway.Traces.Explanation` exposes `status`, `suppression_reason`, and `last_attempt` as separate fields, which strongly suggests the product already treats them as distinct operator concepts. [VERIFIED: repo grep]

### Consequence for branching

- A workflow branch model that ignores `suppression_reason` loses distinctions that operators already rely on, such as `"channel_disabled"`, `"retries_exhausted"`, `"permanent_failure"`, and `"bounced"`. [VERIFIED: repo grep]
- A workflow branch model that ignores final `delivery.status` can misread transient retry behavior as terminal truth because Chimeway keeps temporary failure on `:failed` until convergence later lands on `:succeeded` or `:cancelled`. [VERIFIED: repo grep]

## Comparison Memo

### Option A: Branch on canonical delivery status

**What it means:** Step rules match directly on `delivery.status`. [VERIFIED: repo grep]

**Pros**

- Durable and queryable from one canonical row without reconstructing provider history. [VERIFIED: repo grep]
- Idiomatic fit for Ecto/Phoenix libraries because status enums are easy to index, preload, query, and expose in operator UIs. [VERIFIED: repo grep]
- Safer than attempt-based branching under retries because `status` reflects Chimeway's convergence rules instead of each provider call. [VERIFIED: repo grep]

**Cons**

- Too coarse for Chimeway's current semantics because `:cancelled` collapses `"retries_exhausted"`, `"permanent_failure"`, and `"bounced"` into one bucket. [VERIFIED: repo grep]
- Too coarse for suppressed flows because `:suppressed` still needs `suppression_reason` to tell policy block from later workflow stop/cancel designs. [VERIFIED: repo grep] [ASSUMED]
- Makes DSL rules feel underpowered or surprising because teams will immediately ask for branches like "bounce vs exhausted retry budget" and "policy suppression vs explicit workflow stop". [ASSUMED]

**DX / operator tradeoff**

- Easy to teach, but easy to regret once support asks why two `:cancelled` deliveries produced different workflow behavior. [ASSUMED]

**Footguns**

- Engineers may start overloading `status` with new workflow-specific values, which would blur delivery lifecycle truth with workflow semantics. [ASSUMED]
- Phase 26 stop conditions would likely need special-case side channels because status alone does not encode enough reason detail. [ASSUMED]

### Option B: Branch on last attempt outcome

**What it means:** Step rules inspect the most recent `DeliveryAttempt.outcome` and optionally `error_class`. [VERIFIED: repo grep]

**Pros**

- Captures provider-specific result detail such as `:bounced` and `:rejected` without needing extra translation. [VERIFIED: repo grep]
- Feels close to the event that triggered a follow-up branch. [ASSUMED]

**Cons**

- Not durable enough as workflow truth because Chimeway explicitly treats attempts as append-only evidence while delivery rows hold lifecycle convergence. [VERIFIED: repo grep]
- Volatile under retries because the "last" attempt can change from temporary failure to success later, which means branch meaning changes unless the workflow waits for terminal convergence. [VERIFIED: repo grep]
- Harder to explain to operators because "workflow advanced on last attempt outcome `:failed`" is ambiguous unless you also know whether retries remained and what final delivery status became. [VERIFIED: repo grep] [ASSUMED]
- Querying or enforcing idempotency becomes more awkward because you must reason about ordered attempt history rather than one canonical delivery row. [VERIFIED: repo grep] [ASSUMED]

**Idiomatic fit**

- This is a weaker Elixir/Ecto fit for Chimeway because the repo already uses attempt rows as immutable evidence and presentation detail, not as the primary branch input. [VERIFIED: repo grep]

**DX / operator tradeoff**

- Attractive for implementers because it reuses existing rows directly, but it teaches users a retry-internal mental model instead of a product-level lifecycle model. [ASSUMED]

**Footguns**

- Branches can fire on temporary failure even though the same delivery later succeeds. [VERIFIED: repo grep]
- Teams may accidentally couple workflow semantics to adapter classifications like `"temporary"` vs `"permanent"` instead of to stable library-level semantics. [VERIFIED: repo grep] [ASSUMED]
- "Last attempt" is conceptually unstable whenever duplicate workers or manual retries append more evidence after an earlier progression read. Chimeway's row lock prevents duplicate attempt numbers, but it does not make "latest attempt seen by one reader" a good business semantic. [VERIFIED: repo grep] [ASSUMED]

### Option C: Branch on curated workflow-facing outcomes

**What it means:** The progression engine derives a small, explicit branch vocabulary from canonical delivery state plus attempt/suppression detail, then persists the selected branch outcome in workflow transition context. [ASSUMED]

**Pros**

- Best match for durable explainability because the branch reason can be phrased in domain language while still being reproducible from persisted facts. [ASSUMED]
- Best match for idempotency because the engine can compute the same outcome from the same delivery snapshot and persist that decision once in workflow transitions. [ASSUMED]
- Best operator clarity because DSL and traces can say `delivered`, `suppressed`, `temporary_failure`, `permanent_failure`, `bounced`, or `retries_exhausted` instead of forcing users to decode raw status + attempt details manually. [ASSUMED]
- Preserves least surprise by keeping canonical delivery lifecycle untouched while offering workflow rules a vocabulary tailored to progression. [ASSUMED]

**Cons**

- Adds one more abstraction layer, so the library must document the mapping precisely. [ASSUMED]
- Requires disciplined translation rules and regression tests so the mapping stays stable across future channels and feedback phases. [ASSUMED]

**Idiomatic fit**

- Strong fit for Elixir/Ecto because the mapping can live in a pure function module, be covered with exhaustive table-driven tests, and be persisted as explicit context on append-only workflow transitions. [ASSUMED]
- Strong fit for Phoenix/operator surfaces because the same curated value can drive UI labels while raw delivery and attempt rows remain available for drill-down. [ASSUMED]

**DX / operator tradeoff**

- Slightly more work for maintainers up front, but it gives host applications and support staff a stable public contract instead of leaking internal retry mechanics. [ASSUMED]

**Footguns**

- If the curated vocabulary is too broad, it becomes a shadow copy of delivery/attempt state and loses clarity. [ASSUMED]
- If the curated vocabulary is too narrow, teams will immediately reach for raw `status`/`attempt` escape hatches and defeat the abstraction. [ASSUMED]

## Lessons From Other Libraries

### Elixir ecosystem

- Oban models queue/job lifecycle separately from application-domain state, with distinct job states like `:scheduled`, `:executing`, `:retryable`, `:completed`, `:cancelled`, and `:discarded`, and it exposes uniqueness controls over queue states rather than over application business outcomes. That is a good reminder that queue state is infrastructure truth, not workflow-product truth. [CITED: https://hexdocs.pm/oban/Oban.Job.html] [CITED: https://hexdocs.pm/oban/Oban.Worker.html]
- Oban Pro's workflow worker coordinates dependency ordering between jobs, but its docs still frame workflows around job execution dependencies rather than user-facing notification semantics. That reinforces that Chimeway should keep workflow meaning in its own delivery/workflow tables rather than outsourcing progression semantics to the queue. [CITED: https://hexdocs.pm/oban/2.3.4/workflow.html] [ASSUMED]
- Machinery emphasizes persisted state plus explicit transition logging callbacks. That pattern aligns with Chimeway's append-only workflow transition rows and argues against deriving branch truth from whichever attempt happened last. [CITED: https://hexdocs.pm/machinery/readme.html] [CITED: https://hexdocs.pm/machinery/Machinery.Transition-function-log_transition.html]
- AshDispatch uses a receipt-first pattern, keeps one delivery receipt state machine for dispatch lifecycle, and stores delivery/open/click timestamps separately. That is another example of keeping canonical delivery state distinct from downstream attention or feedback signals. [CITED: https://hexdocs.pm/ash_dispatch/readme.html] [CITED: https://hexdocs.pm/ash_dispatch/AshDispatch.Resources.DeliveryReceipt.html]

### Other ecosystems

- Laravel Notifications creates one queued job per recipient-and-channel combination and separately supports database notifications with read tracking. That separation mirrors Chimeway's need to keep delivery execution facts distinct from higher-level workflow/attention branching. [CITED: https://laravel.com/docs/12.x/notifications]
- Noticed recommends a fallback pattern that creates the notification record immediately, sends a real-time channel first, then delays email and checks `read?` later. The docs explicitly say the app chooses when to mark notifications as read. That is a useful caution: progression should branch on stable, explicit library contracts, not on implicit timing guesses. [CITED: https://github.com/excid3/noticed]
- Noticed also warns that renaming notifier classes can break persisted data because class names are serialized into records. Chimeway already rejects module-name durability in favor of stable string keys, so a curated branch vocabulary should also use stable strings/atoms rather than module references. [CITED: https://github.com/excid3/noticed] [VERIFIED: repo grep]
- Temporal's core pitch is durable execution that resumes after crashes and treats retries/timers/signals as workflow infrastructure. The lesson for Chimeway is not to conflate retried activity detail with workflow-level outcome vocabulary. [CITED: https://docs.temporal.io/] [ASSUMED]

## Recommendation

### Choose curated workflow-facing outcomes

Branching should use a curated outcome layer resolved from persisted delivery facts at the moment the workflow progression transaction runs. The progression engine should read the linked prior delivery row, preload or query its latest attempt when needed, map those facts into one stable branch value, and persist both the branch value and the raw supporting facts in `workflow_transition.context`. [ASSUMED]

### Why this is the best fit for Chimeway

1. It preserves durable explainability.
   The operator can see both the friendly branch outcome and the supporting delivery facts that produced it. That matches Chimeway's existing `status` plus `last_attempt` explanation model. [VERIFIED: repo grep] [ASSUMED]

2. It preserves idempotency.
   Recomputing the curated outcome from the same persisted delivery snapshot yields the same answer, so duplicate workers or retries can no-op once the workflow transition already exists. Oban uniqueness can reduce duplicate execution, but the durable dedupe still belongs on Chimeway's side. [CITED: https://hexdocs.pm/oban/Oban.Job.html] [VERIFIED: repo grep] [ASSUMED]

3. It preserves least surprise.
   Users write workflow rules in product language rather than in transport internals like `attempt.outcome == :rejected and error_class == "permanent"`. [ASSUMED]

4. It preserves operator clarity.
   Support can answer "why did we escalate to email?" with one branch value plus the stored raw facts, instead of reverse-engineering multiple attempts and statuses. [ASSUMED]

### Suggested branch vocabulary

The exact names should stay small and explicit. A strong starting set is: `delivered`, `suppressed`, `temporary_failure`, `retries_exhausted`, `permanent_failure`, and `bounced`. [ASSUMED]

### Suggested mapping

| Workflow-facing outcome | Derived from persisted facts | Why |
|---|---|---|
| `delivered` | `delivery.status == :succeeded` | Terminal success is already explicit on the canonical row. [VERIFIED: repo grep] |
| `suppressed` | `delivery.status == :suppressed` | Policy/config suppression is business-meaningful for workflow branching. [VERIFIED: repo grep] [ASSUMED] |
| `temporary_failure` | `delivery.status == :failed` | Current Chimeway semantics use `:failed` for transient failure before exhaustion, and Phase 25 should expose that as an explicit workflow-facing branch only when the step declares an `on_outcome temporary_failure` rule. [VERIFIED: repo grep] [ASSUMED] |
| `retries_exhausted` | `delivery.status == :cancelled` and `suppression_reason == "retries_exhausted"` | This distinguishes retry-budget exhaustion from other terminal failures. [VERIFIED: repo grep] |
| `permanent_failure` | `delivery.status == :cancelled` and `suppression_reason == "permanent_failure"` | Permanent provider failure should branch differently from exhaustion or bounce. [VERIFIED: repo grep] |
| `bounced` | `delivery.status == :cancelled` and `suppression_reason == "bounced"` | Bounce is a distinct operator and product outcome already captured durably. [VERIFIED: repo grep] |

`delivery.status == :pending`, `:dispatched`, or `:digested` should usually mean "not branchable yet" for Phase 25 rather than a branch outcome. That keeps progression gates deterministic and avoids advancing before the prior step has converged. [ASSUMED]

## Architecture Pattern

### Pattern: Resolve, persist, then branch

**What:** Read the previous step's canonical delivery row under the same progression claim/lock, derive one curated outcome, append one workflow transition that records both the curated outcome and its evidence, then decide the next step from that persisted transition context. [ASSUMED]

**When to use:** For all outcome-driven progression in Phase 25. [ASSUMED]

**Example:**

```elixir
# Source inspiration: current delivery/attempt split in lib/chimeway/delivery.ex,
# lib/chimeway/delivery_attempt.ex, and lib/chimeway/traces.ex
case ProgressionOutcome.from_delivery(delivery, last_attempt) do
  {:branchable, :delivered, evidence} ->
    append_transition(run, step, "progressed_on_delivery_outcome", %{
      "workflow_outcome" => "delivered",
      "delivery_status" => "succeeded",
      "attempt_outcome" => nil,
      "evidence" => evidence
    })

  {:branchable, :retries_exhausted, evidence} ->
    append_transition(run, step, "progressed_on_delivery_outcome", %{
      "workflow_outcome" => "retries_exhausted",
      "delivery_status" => "cancelled",
      "suppression_reason" => "retries_exhausted",
      "evidence" => evidence
    })

  :not_branchable_yet ->
    {:wait, :prior_delivery_not_converged}
end
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Workflow dedupe | Queue-only duplicate prevention | Domain-level persisted progression guard plus optional Oban uniqueness | Queue uniqueness reduces duplicate jobs but does not replace run/step idempotency. [CITED: https://hexdocs.pm/oban/Oban.Job.html] [ASSUMED] |
| Branch semantics | Ad hoc checks scattered through workers | One translation module from delivery facts to workflow outcomes | Centralized mapping is easier to test, document, and keep stable. [ASSUMED] |
| Explainability | Reconstructing decisions from attempt history after the fact | Persist curated outcome and raw evidence on workflow transitions | Chimeway's product value is explainability from durable rows. [VERIFIED: repo grep] [ASSUMED] |

## Common Pitfalls

### Pitfall 1: Treating queue/retry state as workflow truth

**What goes wrong:** A worker retry or duplicate claim changes runtime behavior even though the underlying workflow should make the same business decision. [ASSUMED]
**Why it happens:** Oban job states and attempts are infrastructure semantics, not the product contract. [CITED: https://hexdocs.pm/oban/Oban.Job.html] [ASSUMED]
**How to avoid:** Branch from persisted delivery/workflow rows only, and persist the resolved workflow outcome once. [ASSUMED]
**Warning signs:** Rules mention `attempt`, `retryable`, or job state names directly in workflow DSL or transition reasons. [ASSUMED]

### Pitfall 2: Letting `cancelled` mean too many things

**What goes wrong:** Operators see one delivery lifecycle status while the workflow behaves differently for bounce, exhaustion, and permanent failure. [VERIFIED: repo grep] [ASSUMED]
**Why it happens:** `delivery.status` is intentionally compact, but workflow progression needs a more expressive branch vocabulary. [VERIFIED: repo grep] [ASSUMED]
**How to avoid:** Derive curated workflow outcomes from `status` plus `suppression_reason`. [VERIFIED: repo grep] [ASSUMED]
**Warning signs:** Planning discussions keep adding exceptions like "cancelled, except when...". [ASSUMED]

### Pitfall 3: Branching on the latest attempt before convergence

**What goes wrong:** A workflow escalates after a temporary failure even though a later retry would have succeeded. [VERIFIED: repo grep] [ASSUMED]
**Why it happens:** Attempt rows capture evidence of each provider call, not final business meaning. [VERIFIED: repo grep]
**How to avoid:** Consider `:failed` branchable only if the intended workflow meaning really is "temporary failure observed"; otherwise wait for terminal convergence or an explicit host signal in later phases. [ASSUMED]
**Warning signs:** Tests need sleeps or timing races to make branching deterministic. [ASSUMED]

## Code Examples

### Existing Chimeway evidence split

```elixir
# Source: lib/chimeway/traces/explanation.ex
%Explanation{
  status: delivery.status,
  suppression_reason: delivery.suppression_reason,
  last_attempt: last_attempt
}
```

This existing explanation contract already models delivery lifecycle truth separately from attempt evidence, which is the strongest in-repo argument for a curated workflow-facing outcome layer. [VERIFIED: repo grep]

## Open Questions (RESOLVED)

1. **Should temporary failure be branchable immediately, or only after retry exhaustion?**
   - What we know: current delivery semantics use `:failed` for transient failure before later success or exhaustion. [VERIFIED: repo grep]
   - Resolved: Phase 25 treats `temporary_failure` as a real workflow-facing outcome. When the active step declares an explicit `on_outcome temporary_failure` rule, the progression engine may branch immediately from the persisted `:failed` delivery row; otherwise the engine records a noop and later retries may still converge the delivery to another outcome. [ASSUMED]
   - Implementation consequence: the mapper and runtime seam must support `temporary_failure` end to end, while duplicate-safe claim logic ensures only one branch decision is emitted even if later retries or duplicate workers revisit the same row. [ASSUMED]

2. **Should `digested` ever become a workflow-facing outcome later?**
   - What we know: delivery status includes `:digested`, and digest flows already preserve canonical rows. [VERIFIED: repo grep]
   - Resolved: no for Phase 25. Digest holding/emission remains orthogonal orchestration, not a workflow branch outcome, unless a later phase introduces a concrete journey use case that requires it. [ASSUMED]
   - Implementation consequence: `:digested` stays in the non-branchable bucket with other not-yet-converged or orthogonal states. [ASSUMED]

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit / DataCase / integration tests [VERIFIED: repo grep] |
| Config file | `mix.exs`-driven test setup inferred from existing `test/chimeway/**` suites [VERIFIED: repo grep] |
| Quick run command | `mix test test/chimeway/delivery_attempt_test.exs test/chimeway/trigger_pipeline_test.exs` [VERIFIED: repo grep] |
| Full suite command | `mix test test/chimeway/**/*workflow* test/chimeway/**/*delivery*` [VERIFIED: repo grep] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| WRK-02 | Due/branch engine derives one stable workflow outcome from prior delivery facts | unit + integration | `mix test test/chimeway/delivery_attempt_test.exs test/chimeway/trigger_pipeline_test.exs` | ✅ |
| ESC-03 | Duplicate progression claims do not emit duplicate next-step actions | integration + concurrency | `mix test test/chimeway/**/*workflow* test/chimeway/**/*delivery*` | ⚠️ workflow-specific Phase 25 tests not yet present |

### Wave 0 Gaps

- [ ] Add a focused progression outcome mapper test file covering all status/suppression/attempt combinations. [ASSUMED]
- [ ] Add concurrency-focused workflow progression tests proving duplicate-safe next-step emission. [ASSUMED]

## Sources

### Primary (HIGH confidence)

- Repo inspection of `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, `lib/chimeway/workflows*.ex`, `lib/chimeway/delivery*.ex`, `lib/chimeway/delivery_attempt.ex`, and delivery/workflow tests. [VERIFIED: repo grep]
- Oban job state and uniqueness docs: https://hexdocs.pm/oban/Oban.Job.html [CITED: https://hexdocs.pm/oban/Oban.Job.html]
- Oban worker docs: https://hexdocs.pm/oban/Oban.Worker.html [CITED: https://hexdocs.pm/oban/Oban.Worker.html]
- Machinery state persistence and transition logging docs: https://hexdocs.pm/machinery/readme.html [CITED: https://hexdocs.pm/machinery/readme.html]
- Machinery transition logging reference: https://hexdocs.pm/machinery/Machinery.Transition-function-log_transition.html [CITED: https://hexdocs.pm/machinery/Machinery.Transition-function-log_transition.html]
- AshDispatch receipt/state-machine docs: https://hexdocs.pm/ash_dispatch/AshDispatch.Resources.DeliveryReceipt.html [CITED: https://hexdocs.pm/ash_dispatch/AshDispatch.Resources.DeliveryReceipt.html]
- AshDispatch design principles: https://hexdocs.pm/ash_dispatch/readme.html [CITED: https://hexdocs.pm/ash_dispatch/readme.html]

### Secondary (MEDIUM confidence)

- Laravel Notifications docs: https://laravel.com/docs/12.x/notifications [CITED: https://laravel.com/docs/12.x/notifications]
- Noticed README/docs: https://github.com/excid3/noticed [CITED: https://github.com/excid3/noticed]
- Temporal docs homepage: https://docs.temporal.io/ [CITED: https://docs.temporal.io/]
- Oban Pro workflow worker docs: https://hexdocs.pm/oban/2.3.4/workflow.html [CITED: https://hexdocs.pm/oban/2.3.4/workflow.html]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | The best public DSL for Phase 25 is a curated workflow-facing outcome vocabulary rather than raw status matching. | Summary / Recommendation | Planner may overfit tasks around a translator layer the user does not want. |
| A2 | `:pending`, `:dispatched`, and `:digested` should be treated as not-branchable-yet in the initial Phase 25 model. | Recommendation | Some valid workflow behaviors could require additional interim outcomes. |
| A3 | The initial curated vocabulary should include `temporary_failure`, `retries_exhausted`, `permanent_failure`, and `bounced` as distinct workflow outcomes. | Recommendation | The vocabulary could prove too granular or not granular enough for intended SaaS journeys. |

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - existing repo and locked deps already determine the implementation stack. [VERIFIED: mix deps] [VERIFIED: repo grep]
- Architecture: HIGH - Chimeway's current delivery/attempt/transition split strongly constrains the safest branching model. [VERIFIED: repo grep]
- Pitfalls: MEDIUM - the failure modes are well supported by repo semantics and comparable libraries, but some escalation semantics remain Phase 26 territory. [VERIFIED: repo grep] [ASSUMED]

**Research date:** 2026-04-29
**Valid until:** 2026-05-29

# Phase 25: Progression Engine & Wait Gates - Context

**Gathered:** 2026-04-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Advance workflow runs safely based on elapsed time and the prior delivery outcome. This phase covers durable wait-gate timing, outcome-driven progression, duplicate-safe internal advancement, and concurrency-focused verification. Escalation policies, terminal stop/cancel behavior, host-submitted progression signals, and richer journey inspection stay in later phases.

</domain>

<decisions>
## Implementation Decisions

### Wait timing semantics
- **D-01:** Default wait windows must start from the prior step delivery reaching a durable terminal outcome, not from step activation and not from first dispatch time.
- **D-02:** Phase 25 should treat step-activation timers as a possible future explicit feature for entry-delay semantics, but not as the default meaning of workflow waits.

### Branching model
- **D-03:** Outcome-driven progression must branch on a small curated workflow-facing outcome vocabulary derived from persisted delivery facts, not directly on raw `delivery.status` alone and not directly on raw `last_attempt.outcome`.
- **D-04:** The starting curated vocabulary should stay small and product-level: `delivered`, `suppressed`, `temporary_failure`, `retries_exhausted`, `permanent_failure`, and `bounced`.
- **D-05:** Progression must treat non-terminal prior delivery states such as `:pending`, `:dispatched`, and other not-yet-converged states as “not branchable yet”, not as branch outcomes.

### Rule authoring shape
- **D-06:** Progression rules should live on the current step as explicit outgoing rules: “from this step, after X / on outcome Y, advance to Z or wait”.
- **D-07:** Phase 25 should avoid next-step-owned entry predicates and avoid a mixed source-plus-destination rule model. The active step is the single source of progression truth.
- **D-08:** Progression declarations must stay data-first and replay-safe inside persisted step config. Do not use runtime lambdas, callback re-entry, or queue-only logic to decide later progression.

### Progression engine posture
- **D-09:** Chimeway should own time-based and outcome-based progression internally in Phase 25 through one durable progression seam. Host-managed/manual progression is not the primary posture for this phase.
- **D-10:** Oban may schedule or wake due progression work, but queue state is never the correctness boundary. The progression transaction must reload persisted workflow and delivery state by ID, claim work durably, append workflow transitions, and emit at most one next-step delivery through the normal canonical delivery path.
- **D-11:** Sync-first and Oban-backed hosts must share the same progression semantics. If a non-Oban host needs a manual “tick due runs” seam, it must call the same internal engine rather than reimplement progression policy externally.

### Explainability and DX posture
- **D-12:** Every progression decision must persist both the workflow-facing outcome and the raw supporting facts in workflow transition context so operators can answer “why did this advance, wait, or noop?” from durable rows alone.
- **D-13:** Progression traces should carry explicit anchor facts for wait gates, including the anchor source, anchor delivery, anchor outcome, and anchor timestamp, rather than inferring timing later from ad hoc timestamps.
- **D-14:** Downstream agents should default to one cohesive recommendation set and escalate only for high-blast-radius or public-model-defining choices. Reversible implementation-local choices should be decided by the agent and documented, not pushed back to the user.

### the agent's Discretion
- Exact module names, worker names, and transition reason strings for the progression engine.
- Exact serialized shape for step `progress` config, provided it stays explicit, data-first, and validates deterministically.
- Exact locking and claim strategy, provided it prevents duplicate next-step emission under retries and concurrent due-step races.
- Exact internal naming of curated workflow outcomes, provided the public vocabulary remains small, stable, and operator-readable.

</decisions>

<specifics>
## Specific Ideas

- The canonical example for this phase is SaaS-style fallback/escalation such as `in_app -> email`, where the second step should wait relative to the first step’s durable outcome rather than queue timing.
- Product-level workflow rules should read like explicit state-machine transitions, not like adapter internals or retry plumbing.
- Operator explanations should feel like Chimeway’s existing trace posture: concrete reasons and durable facts, not inferred queue archaeology.
- Keep the developer story least-surprise: one active step, one internal progression seam, one canonical delivery path, and one clear branch vocabulary.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone and phase scope
- `.planning/ROADMAP.md` — Phase 25 goal, requirements, and success criteria.
- `.planning/REQUIREMENTS.md` — `WRK-02` and `ESC-03` requirement mapping.
- `.planning/PROJECT.md` — local-first explainability posture, workflow milestone direction, and DX constraints.
- `.planning/STATE.md` — carried-forward milestone state and prior orchestration/workflow decisions.
- `.planning/METHODOLOGY.md` — project-wide recommendation bias, escalation gate, durable explainability bias, and least-surprise DX posture.

### Prior workflow and orchestration decisions
- `.planning/phases/18-scheduled-resume-deferred-dispatch/18-CONTEXT.md` — canonical-row resume pattern, thin worker posture, and duplicate-safe due work.
- `.planning/phases/20-digest-emission-explainability/20-CONTEXT.md` — durable explainability and “queue is not the truth source” posture.
- `.planning/phases/24-workflow-contracts-state-spine/24-CONTEXT.md` — locked workflow declaration/run/transition spine that Phase 25 must extend.

### Phase research and examples
- `.planning/phases/25-progression-engine-wait-gates/25-RESEARCH.md` — ecosystem-backed branching-model research and repo-fit recommendation.
- `test/chimeway/notifier_contract_test.exs` — current durable workflow declaration shape and step config posture.
- `test/chimeway/trigger_pipeline_test.exs` — current workflow example declarations and initial-run persistence behavior.
- `test/chimeway/integration/delivery_lifecycle_test.exs` — canonical workflow-linked delivery lifecycle expectations.

### Current code contracts
- `lib/chimeway/notifier.ex` — normalized workflow declaration contract and replay-safe step config storage.
- `lib/chimeway/workflows.ex` — workflow definition lookup, run creation, and append-only transition persistence.
- `lib/chimeway/workflows/workflow_run.ex` — single active-step cursor and durable run state.
- `lib/chimeway/workflows/workflow_transition.ex` — append-only reason-bearing workflow history.
- `lib/chimeway/delivery.ex` — canonical delivery lifecycle fields, orchestration state, and workflow linkage.
- `lib/chimeway/deliveries.ex` — terminal convergence, attempt recording, suppression reasons, deferred resume, and named lifecycle helpers.
- `lib/chimeway/delivery_attempt.ex` — attempt-level outcome and error-class evidence.
- `lib/chimeway/delivery_planning.ex` — canonical per-channel planning seam and active-step linkage behavior.
- `lib/chimeway/dispatch/deferred_resume_worker.ex` — thin scheduled worker pattern that reloads state by `delivery_id` and reuses normal execution seams.
- `lib/chimeway/dispatch/oban_worker.ex` — retry/exhaustion behavior and terminal convergence expectations.
- `lib/chimeway/traces.ex` — current operator trace entrypoint and lifecycle explanation posture.
- `lib/chimeway/traces/explanation.ex` — delivery explanation contract, suppression reasons, and last-attempt separation.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Workflows` already persists the workflow run cursor and append-only transitions, giving Phase 25 a durable place to record wait, branch, noop, and advance decisions.
- `Chimeway.Deliveries` already owns canonical convergence for temporary failure, permanent failure, bounce, retries exhausted, suppression, and deferred resume.
- `Chimeway.Dispatch.DeferredResumeWorker` is the clearest in-repo model for due work that reloads by ID, mutates canonical state in one transaction, and then reuses the normal dispatch path.
- `Chimeway.Traces` and `Chimeway.Traces.Explanation` already separate delivery status from last-attempt evidence, which supports a derived workflow-outcome layer cleanly.

### Established Patterns
- Chimeway keeps durable product truth on Chimeway-owned Postgres rows, not in queue args, notifier callback re-entry, or opaque metadata-only blobs.
- Canonical delivery rows are the execution spine, while append-only attempt rows provide evidence and detail.
- Duplicate prevention is treated as domain behavior on durable rows and transactions; queue uniqueness is useful but not sufficient as the correctness boundary.
- Explanation surfaces favor named reasons and explicit persisted facts over inference from timestamps or transport internals.

### Integration Points
- Phase 25 progression should extend the existing workflow run and transition tables rather than introducing a second workflow state store.
- Outcome-driven branching should read the prior step’s linked canonical delivery row and its latest persisted attempt evidence inside the same progression transaction.
- Any emitted next-step delivery must still flow through `Chimeway.DeliveryPlanning` and the existing sync/Oban execution seams so lifecycle history remains canonical.
- Phase 26 stop/cancel behavior should be able to reuse the same current-step rule model and internal progression seam established here.

</code_context>

<deferred>
## Deferred Ideas

- Step-activation-based entry-delay semantics as a first-class explicit rule shape rather than the default wait meaning.
- Escalation and terminal stop/cancel actions beyond simple progression gates — Phase 26.
- Host-submitted workflow signals such as read/seen/acknowledged as explicit public inputs — Phase 27.
- Rich journey inspection APIs and operator journey views — Phase 27.
- Broader read/unread-driven branching as a primary workflow model — deferred beyond the core time/outcome spine.

</deferred>

---

*Phase: 25-progression-engine-wait-gates*
*Context gathered: 2026-04-29*

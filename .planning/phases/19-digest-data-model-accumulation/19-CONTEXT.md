# Phase 19: Digest Data Model & Accumulation - Context

**Gathered:** 2026-04-28 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Introduce first-class digest rules plus durable accumulation records for repeated notification
streams. This phase covers how digestable work is configured, grouped, and accumulated on durable
host-owned data structures. Actual digest emission, exact inclusion/exclusion operator explanations,
and rendered digest delivery behavior remain Phase 20 work.

</domain>

<decisions>
## Implementation Decisions

### Digest Persistence Model
- **D-01:** Phase 19 should introduce three first-class digest artifacts: `digest_rules`,
  `digest_buckets`, and `digest_memberships`.
- **D-02:** The existing `chimeway_deliveries` row remains the canonical source work item; digest
  accumulation must reference held source deliveries rather than replacing them or creating a
  parallel delivery identity model.
- **D-03:** `digest_memberships` must be an explicit schema, not an opaque JSON field or anonymous
  join table, because membership carries business meaning and must remain auditable.

### Rule Identity and Grouping
- **D-04:** Digest rules must use stable, durable identities separate from notifier module names,
  consistent with Chimeway's existing `notification_key` + version posture.
- **D-05:** Bucket identity should be scoped by rule, recipient, channel, grouping value, and
  window so cross-channel fanout semantics remain correct.
- **D-06:** Phase 19 should support grouping by recipient plus one of: `notification_key`,
  category, or an explicit host-provided digest key. If grouping by category, the resolved category
  value must be snapshotted durably rather than re-derived later from mutable payload shape.

### Accumulation Timing and Idempotency
- **D-07:** Accumulation should happen only after planning settles on a delivery that is still
  `status == :pending` and `orchestration_state == :digest_held`; suppressed or immediate work must
  not leak into digest buckets.
- **D-08:** Idempotency must be enforced at the database layer using durable bucket identity plus a
  unique membership boundary on source `delivery_id`, not by relying on Oban uniqueness or
  trigger-call timing.
- **D-09:** Accumulation writes should use targeted upserts and transactional boundaries that keep
  source delivery state, bucket creation/update, and membership insertion coherent under retries.

### Window Strategy and Phase Scope
- **D-10:** Phase 19 should establish durable window metadata on digest buckets, but keep the
  initial strategy set intentionally small: fixed-duration windows and scheduled boundary windows
  are enough to support the milestone without turning Chimeway into a workflow engine.
- **D-11:** Digest windowing must be modeled independently from deferred-delivery
  `next_eligible_at`; quiet-hours deferral and digest accumulation are separate orchestration
  concepts.
- **D-12:** Sliding windows, nested digests, generalized workflow graphs, and centralized
  orchestration DSLs are deferred; they add surprise and complexity faster than value for the
  current milestone.

### Explainability and Developer Experience
- **D-13:** Digest persistence must snapshot the facts Phase 20 will need for exact explanation:
  rule identity, grouping value, channel, recipient scope, window boundaries, and source-delivery
  membership.
- **D-14:** Oban remains an optional downstream execution seam, not the source of truth for digest
  state. Durable digest facts must stay queryable even in host apps that do not rely on Oban.
- **D-15:** The design should favor embedded-library ergonomics over SaaS-style workflow
  abstraction: explicit schemas, predictable keys, test/null seams, preview-friendly data, and
  least-surprise behavior for host developers.
- **D-16:** Default project posture should be cohesive and opinionated: planning/research agents
  should converge on a recommended design unless a fork is unusually high-impact, hard to reverse,
  or product-defining.

### the agent's Discretion
- Exact schema/module names for digest artifacts.
- Exact column naming for rule identity, grouping value, and window fields.
- Whether accumulation orchestration is expressed primarily through `Ecto.Multi` or smaller
  `Repo.transact/1` helpers, as long as transactional invariants remain explicit and testable.
- Exact preview/test helper API shape, provided it follows the embedded-library and explainability
  posture above.

</decisions>

<specifics>
## Specific Ideas

- Copy Knock's rigor around explicit window boundaries and batch keys, but not its full workflow
  engine complexity.
- Copy GitHub's “why am I seeing this?” posture by making digest reasons and suppression reasons
  explicit product behavior, not hidden support-only metadata.
- Copy Laravel's late send/suppress instinct: final eligibility should still be checked when a
  digest eventually flushes, not only when work first enters a bucket.
- Copy Noticed's embedded-library posture and unread-fallback sensibility where it fits future
  phases, but do not let class/module names become durable digest identity.
- Copy Discourse's previewability mindset: digest behavior should be inspectable and testable before
  rollout.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone and phase scope
- `.planning/ROADMAP.md` — Phase 19 goal, dependency, and success criteria.
- `.planning/REQUIREMENTS.md` — `DIGEST-01` scope and explicit separation from Phase 20
  explainability/emission work.
- `.planning/PROJECT.md` — local-first ownership, stable identity, and explainability constraints.
- `.planning/STATE.md` — carried-forward orchestration and identity decisions.

### Prior phase carry-forward constraints
- `.planning/phases/17-delivery-windows-deferral-semantics/17-02-SUMMARY.md` — digest intent was
  intentionally limited to state-only `:digest_held` planning in Phase 17.
- `.planning/phases/17-delivery-windows-deferral-semantics/17-VALIDATION.md` — explicit warning not
  to create Phase 19 accumulation artifacts early.
- `.planning/phases/18-scheduled-resume-deferred-dispatch/18-CONTEXT.md` — digest work was kept
  out of deferred-resume scope and held rows stayed canonical.
- `.planning/phases/18-scheduled-resume-deferred-dispatch/18-03-SUMMARY.md` — trace continuity and
  explainability expectations that Phase 19 must preserve.

### Existing orchestration and delivery model
- `lib/chimeway/notifier.ex` — channel-aware orchestration contract and stable digest-held
  declaration seam.
- `lib/chimeway/delivery_planning.ex` — planning choke point, planning-before-policy sequencing, and
  current digest-held persistence behavior.
- `lib/chimeway/delivery.ex` — canonical delivery schema and one-row-per-notification/channel
  contract.
- `lib/chimeway/deliveries.ex` — idempotent planning helpers and durable update patterns.
- `lib/chimeway/policy.ex` — current category derivation and planning/perform suppression behavior.
- `lib/chimeway/traces.ex` — current sanitized explanation surface and limits of
  `planning_context`.

### Research and architectural direction
- `.planning/research/ARCHITECTURE.md` — explicit aggregate direction for future digest work.
- `.planning/research/PITFALLS.md` — known orchestration and state-model footguns to avoid.

### Existing tests that lock behavior
- `test/chimeway/orchestration/planning_declarations_test.exs` — digest intent currently persists as
  `:digest_held` on canonical delivery rows.
- `test/chimeway/orchestration/delivery_planning_test.exs` — repeated planning keeps one canonical
  delivery row.
- `test/chimeway/orchestration/dispatch_gating_test.exs` — digest-held rows must not dispatch
  before a later phase makes them ready.
- `test/chimeway/orchestration/traces_deferral_test.exs` — explainability surfaces are sanitized and
  row-centric today.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.DeliveryPlanning.plan_notification/2`: current choke point where digest intent is
  resolved before policy and where accumulation hooks can be added safely.
- `Chimeway.Deliveries.plan_delivery/3`: existing idempotent `(notification_id, channel)` delivery
  planning boundary.
- `Chimeway.Deliveries.apply_planning_decision/2`: established durable-write pattern for explicit
  orchestration facts on canonical rows.
- `Chimeway.Traces.explain_delivery/2`: current explanation surface that future digest explanation
  work must eventually extend without moving truth into queue state.

### Established Patterns
- Delivery rows are canonical and should be mutated or linked to, not replaced.
- Orchestration is channel-aware, so digest accumulation must be channel-aware too.
- Explainability favors explicit durable fields over queue metadata or opaque JSON-only models.
- Oban is an optional execution seam; durable orchestration truth belongs in Chimeway tables.
- Stable product identity is `notification_key` + version, not module names.

### Integration Points
- Phase 19 should hook into planning immediately after `:digest_held` is resolved and after policy
  leaves the row pending.
- Future Phase 20 emission should consume digest buckets/memberships and produce one emitted digest
  delivery without rewriting source delivery identity.
- Category-based grouping needs a durable snapshot boundary because current category data is derived
  from event payload at runtime.

</code_context>

<deferred>
## Deferred Ideas

- Sliding-window and “flush first item immediately, then batch the rest” strategies.
- Nested or multi-stage digests.
- Centralized workflow/DAG orchestration similar to hosted notification platforms.
- Full operator-facing inclusion/exclusion explanation surfaces and digest emission lifecycle; these
  belong to Phase 20.
- Cross-phase unread/escalation UX beyond the current phase boundary, even though the future design
  should stay compatible with it.

</deferred>

---

*Phase: 19-digest-data-model-accumulation*
*Context gathered: 2026-04-28*

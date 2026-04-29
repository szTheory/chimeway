# Pitfalls Research

**Domain:** Durable notification workflow orchestration
**Researched:** 2026-04-29
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Split-brain workflow state

**What goes wrong:**
Workflow progression state drifts from notification and delivery history, making support answers contradictory.

**Why it happens:**
Teams bolt a workflow engine on top of an existing delivery system instead of anchoring journeys to canonical rows.

**How to avoid:**
Persist workflow runs, current step, and transition history with direct linkage to canonical notification and delivery records.

**Warning signs:**
Operators need multiple queries to understand one journey, or recovery paths can advance a workflow without durable delivery linkage.

**Phase to address:**
Phase 24

---

### Pitfall 2: Duplicate step advancement under retries or scheduler races

**What goes wrong:**
The same workflow step emits duplicate follow-up deliveries after worker retries, clock races, or concurrent claims.

**Why it happens:**
Due-step progression is treated as best-effort logic instead of an idempotent, claim-safe state transition.

**How to avoid:**
Make progression transactional, claim-based, and guarded by stable transition keys plus row-level concurrency control.

**Warning signs:**
Two workers can observe the same due step, or tests only prove happy-path progression and not race behavior.

**Phase to address:**
Phase 25

---

### Pitfall 3: Escalation semantics that over-notify

**What goes wrong:**
Follow-up channels fire even after a prior step succeeded or a workflow should have stopped.

**Why it happens:**
Stop conditions are modeled implicitly or checked outside the durable workflow state transition.

**How to avoid:**
Persist explicit terminal conditions and force every advancement to evaluate stop/cancel semantics before emitting the next step.

**Warning signs:**
The design says “we'll just check before sending,” or terminal-state rules differ between sync and async paths.

**Phase to address:**
Phase 26

---

### Pitfall 4: Read/unread state becoming the critical path too early

**What goes wrong:**
The milestone gets blocked on inbox semantics, host read events, or “seen vs read” ambiguity before journey progression is proven.

**Why it happens:**
Product intuition jumps straight to user-attention workflows, even though time/outcome progression is the lower-risk foundation.

**How to avoid:**
Keep v1.3 centered on time-based and outcome-based progression; treat read/unread-driven branching as a follow-on capability.

**Warning signs:**
Most milestone discussion shifts from workflow sequencing to inbox policy debates.

**Phase to address:**
Phase 24 and milestone scoping

---

### Pitfall 5: Chain-level explainability missing from operator surfaces

**What goes wrong:**
Each delivery is explainable in isolation, but no one can answer where a recipient is in the overall journey.

**Why it happens:**
Teams stop after implementing progression workers and never add workflow-aware trace surfaces.

**How to avoid:**
Design journey summaries and transition explanations as milestone requirements, not documentation debt.

**Warning signs:**
Operators can explain a delivery but not the journey's current step, next action, or stopping reason.

**Phase to address:**
Phase 27

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Keep workflow state inside delivery metadata only | Fastest schema change | Hard to query, validate, and evolve | Never for this milestone |
| Emit next-step deliveries without transition history | Less modeling work | Debugging and recovery become opaque | Never |
| Skip docs/examples until the end | Faster coding throughput | Adoption lag and misunderstood APIs | Only temporarily within an active phase |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Oban | Scheduling raw business payloads in jobs | Schedule stable workflow/run identifiers and load canonical state at perform time |
| Host app callbacks | Letting host code mutate workflow state directly | Expose a narrow, validated API for host signals and progression inputs |
| Future provider callbacks | Designing v1.3 around webhook feedback too early | Keep that work in the later channel-feedback milestone |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Full-table scans for due workflow steps | Progression workers slow as runs grow | Add due-step indexes and narrow claim queries | Tens of thousands of active waits |
| N+1 trace reconstruction across runs and deliveries | Operator screens time out | Preload or project step summaries intentionally | Moderate operational usage |
| Repeated re-evaluation of dynamic callbacks | CPU churn and non-deterministic replay | Persist normalized workflow declarations | As soon as workflows have multiple steps |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Exposing raw workflow input payloads in traces | Sensitive user data leaks into operator surfaces | Keep explanations payload-safe and reason-focused |
| Ignoring tenancy scoping on workflow queries | Cross-tenant support leakage | Preserve the tenancy-aware query posture already established in traces |
| Accepting arbitrary host signals without validation | Unauthorized or malformed progression | Validate signal shape, workflow ownership, and allowed transition points |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Workflow API that reads like a generic rules engine | Hard to adopt and reason about | Use notification-specific terminology: steps, waits, escalations, stops |
| Too many branching modes in v1 | Users cannot tell what is stable | Start with time/outcome progression and document deferred modes clearly |
| Hidden stop conditions | Operators lose trust in the system | Persist and surface stop reasons explicitly |

## "Looks Done But Isn't" Checklist

- [ ] **Workflow definitions:** verify identity is durable and versioned, not callback-derived
- [ ] **Progression workers:** verify duplicate claims cannot emit extra follow-up deliveries
- [ ] **Escalations:** verify terminal conditions suppress remaining steps consistently
- [ ] **Journey traces:** verify operators can answer current step, next action, and stop reason
- [ ] **Docs/examples:** verify at least one real SaaS journey is modeled end to end

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Split-brain workflow state | HIGH | Add reconciliation tooling, backfill linkages, and re-derive summaries from canonical rows |
| Duplicate step advancement | HIGH | Add dedup claims, cancel duplicate follow-up deliveries, and repair progression history |
| Missing chain-level traces | MEDIUM | Backfill journey summary queries from persisted transitions and deliveries |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Split-brain workflow state | Phase 24 | Schema and traceability tests prove workflow run to delivery linkage |
| Duplicate advancement | Phase 25 | Concurrency/race tests prove single advancement under retries |
| Over-notifying escalations | Phase 26 | End-to-end stop-condition tests prove no extra follow-up sends |
| Missing chain-level traces | Phase 27 | Operator query tests answer workflow position and reason |

## Sources

- https://github.com/excid3/noticed
- https://laravel.com/docs/12.x/notifications
- https://symfony.com/doc/current/notifier.html
- Local code and planning context across `.planning/PROJECT.md`, `.planning/STATE.md`, and `lib/chimeway/dispatch/oban_worker.ex`

---
*Pitfalls research for: durable notification workflow orchestration*
*Researched: 2026-04-29*

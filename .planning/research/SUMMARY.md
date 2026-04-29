# Project Research Summary

**Project:** Chimeway
**Domain:** Embedded notification workflow orchestration
**Researched:** 2026-04-29
**Confidence:** HIGH

## Executive Summary

Chimeway already has the hard substrate most notification libraries never finish: durable identity, policy controls, explainable lifecycle traces, deferred/digest orchestration, rendering durability, and recovery. The next product-value jump is not “more channels” or “more polish” in isolation. It is durable multi-step workflow journeys that let SaaS teams define what happens after the first notification.

Research across comparable notification systems reinforces that delay mechanics, channel fanout, and conditional delivery are expected, but chain-level workflow state and explainability are usually still app-owned or relatively light. Chimeway can differentiate by making journey progression, escalation, and stop reasoning durable first-class behavior while staying local-first and embedded.

The key risk is scope dilution: adding channel breadth, read/unread-driven branching, or UI productization too early would slow the milestone and weaken the core workflow model. The recommended approach is to ship an API-first workflow milestone centered on time-based and outcome-based journeys, then expand channels and adoption surfaces afterward.

## Key Findings

### Recommended Stack

Keep the current Elixir/Ecto/PostgreSQL/Oban stack. The main addition is conceptual, not infrastructural: add a workflow-run and transition layer that reuses Chimeway's existing planning, dispatch, recovery, and trace seams.

**Core technologies:**
- Elixir: workflow progression runtime — stays aligned with host apps and existing notifier APIs
- PostgreSQL: durable workflow state — transactional progression, locking, and explainable history
- Oban: scheduled progression — time-based waits and escalations without inventing a new async engine

### Expected Features

The table stakes for this milestone are durable workflow definitions, time-based waits, outcome-based escalation, stop conditions, and journey-level operator traces.

**Must have (table stakes):**
- Multi-step journey definitions with stable identity
- Wait/advance/escalate/stop semantics driven by time and prior outcomes
- Journey traces that explain current position and next action

**Should have (competitive):**
- Transition reasons persisted as durable data
- Host signal API seams that do not let apps mutate history directly

**Defer (v2+):**
- Read/unread-driven branching as the primary workflow driver
- Visual journey builders
- Broad channel expansion in the same milestone

### Architecture Approach

Add a workflow layer that persists declaration snapshots, workflow runs, current-step state, and transition history, then links emitted deliveries back to the journey. Reuse Oban for due-step advancement, and extend trace APIs so operators can inspect the entire journey chain safely.

**Major components:**
1. Workflow declarations — normalized key/version plus ordered step definitions
2. Workflow runs and transitions — durable current state plus append-only transition history
3. Progression engine/workers — evaluates waits, outcomes, escalations, and stop conditions
4. Journey traces — exposes step position, history, and reasoning without leaking payloads

### Critical Pitfalls

1. **Split-brain workflow state** — avoid by anchoring journeys directly to canonical notification/delivery rows
2. **Duplicate advancement under retries** — avoid with transactional claims and idempotent progression
3. **Over-notifying escalations** — avoid by persisting stop conditions and checking them before emitting the next step
4. **Read-state scope creep** — avoid by keeping v1.3 centered on time/outcome progression
5. **Missing journey-level traces** — avoid by making chain explainability a requirement, not polish

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 24: Workflow Contracts & State Spine
**Rationale:** durable identity/state must exist before any progression logic
**Delivers:** workflow declarations, run storage, transition persistence, and schema contracts
**Addresses:** durable workflow identity and explainability foundations
**Avoids:** split-brain workflow state

### Phase 25: Progression Engine & Wait Gates
**Rationale:** time/outcome-based advancement is the core new capability
**Delivers:** deterministic progression evaluation, due-step scheduling, and idempotent advancement
**Uses:** PostgreSQL locking and Oban scheduling
**Implements:** progression engine

### Phase 26: Escalations & Stop Conditions
**Rationale:** once progression exists, channel escalation and termination semantics become safe to add
**Delivers:** follow-up progression, cancellation/stop rules, and no-duplicate escalation behavior

### Phase 27: Journey Traces & Host Signal API
**Rationale:** journey-level operability and controlled host integration should land before closure
**Delivers:** workflow inspection queries, progression reasons, and stable host signal seams

### Phase 28: Docs, Reference Flows, and Closure
**Rationale:** production adoption needs concrete examples once the API stabilizes
**Delivers:** reference journey examples, docs, and final milestone verification

### Phase Ordering Rationale

- Workflow declarations and state must precede progression because later workers need durable truth to act on.
- Progression must precede escalation because fallback behavior is just a special case of controlled advancement.
- Journey traces come after the main engine exists, but before milestone closure so the product remains explainable.
- Docs and reference flows belong at the end of the milestone so they reflect the stable API rather than a moving target.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 24:** API contract and schema choices need careful local design review
- **Phase 25:** idempotent progression and worker race handling need targeted concurrency planning
- **Phase 27:** host signal API needs boundary/security review

Phases with standard patterns (skip research-phase):
- **Phase 28:** documentation and reference-flow packaging should mostly reuse existing project patterns

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Strong alignment with existing project architecture and official docs |
| Features | HIGH | Deferred requirements and ecosystem patterns point to the same next gap |
| Architecture | HIGH | The durable-state-first design follows directly from Chimeway's core value |
| Pitfalls | HIGH | Most risks are visible from adjacent notification systems and Chimeway's current trajectory |

**Overall confidence:** HIGH

### Gaps to Address

- Sync-first host progression without Oban should stay documented as a seam, but not become the milestone's design center
- Read/unread-driven branching remains a meaningful follow-on, but should not backdoor itself into v1.3 requirements

## Sources

### Primary (HIGH confidence)
- https://laravel.com/docs/12.x/notifications — channel routing, delays, and expected notification-system behaviors
- https://symfony.com/doc/current/notifier.html — transport and notifier architecture boundaries
- https://github.com/excid3/noticed — comparable OSS notification patterns for delayed and multi-delivery behavior
- Local planning and code context in `.planning/PROJECT.md`, `.planning/milestones/v1.1-ROADMAP.md`, `.planning/milestones/v1.2-ROADMAP.md`, `lib/chimeway/notifier.ex`, `lib/chimeway/inbox.ex`

---
*Research completed: 2026-04-29*
*Ready for roadmap: yes*

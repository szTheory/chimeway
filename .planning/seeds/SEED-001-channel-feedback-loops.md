---
id: SEED-001
status: dormant
planted: 2026-04-29T15:34:12Z
planted_during: Milestone v1.3 initialization
trigger_when: Workflow journeys are stable and the next value jump depends on more first-class outbound channels or provider feedback flowing back into workflow state.
scope: large
---

# SEED-001: Channel Feedback Loops

## Why This Matters

Once workflow journeys and escalations are durable, Chimeway's next major leverage point is making more outbound channels participate fully in that model. SMS, push, chat, and provider callback ingestion become much more valuable after the library can decide when to escalate and how to stop.

## When to Surface

**Trigger:** Workflow journeys are stable and the roadmap needs channel breadth or provider callback feedback.

This seed should be presented during `$gsd-new-milestone` when the milestone
scope matches any of these conditions:
- The next milestone discussion centers on SMS, push, chat, or other first-class outbound channels
- Workflow progression needs delivery receipts, bounces, or webhook callbacks to drive later steps
- Teams want receipts and transport-specific outcomes to flow back into lifecycle traces uniformly

## Scope Estimate

**large** — likely spans adapter contracts, inbound callback normalization, trace extensions, and workflow integration work.

## Breadcrumbs

Related code and decisions found in the current codebase:

- `.planning/milestones/v1.2-REQUIREMENTS.md`
- `.planning/PROJECT.md`
- `lib/chimeway/notifier.ex`
- `lib/chimeway/dispatch/oban_worker.ex`
- `lib/chimeway/traces/explanation.ex`

## Notes

This is the recommended follow-on arc after workflow journeys. It should stay behind the workflow milestone so the project expands channel breadth only after the higher-value orchestration contract is stable.

# Phase 24: Workflow Contracts & State Spine - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `24-CONTEXT.md`; this log preserves the analysis that led there.

**Date:** 2026-04-29
**Phase:** 24-workflow-contracts-state-spine
**Mode:** assumptions
**Areas analyzed:** Workflow declaration model, Workflow run spine, Transition history, Declaration seam and phase scope

## Assumptions Presented

### Workflow declaration model
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Workflow declarations should be persisted as first-class durable records with stable `workflow_key` + `workflow_version` and ordered step definitions, instead of living only in `Notification.orchestration` or `Delivery.planning_context`. | Likely | `lib/chimeway/digests/digest_rule.ex`, `lib/chimeway/digests/digest_bucket.ex`, `lib/chimeway/digests/digest_membership.ex`, `lib/chimeway/notifications/notification.ex`, `.planning/ROADMAP.md` |

### Workflow run spine
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Workflow runs should anchor on the per-recipient notification spine, with delivery rows remaining per-step execution artifacts. | Likely | `lib/chimeway/notifications/notification.ex`, `lib/chimeway/delivery.ex`, `lib/chimeway/delivery_planning.ex`, `lib/chimeway/deliveries.ex` |

### Transition history
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Workflow state changes should persist as explicit append-only history rows with reason fields and step/delivery linkage, rather than being inferred from queue state or mutable JSON. | Confident | `lib/chimeway/traces.ex`, `lib/chimeway/traces/explanation.ex`, `lib/chimeway/digests/digest_membership.ex`, `.planning/METHODOLOGY.md` |

### Declaration seam and phase scope
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 24 should add a trigger-time workflow declaration seam and durable run-state persistence, but leave wait gates, branching, escalations, and stop conditions to Phases 25-26. | Likely | `lib/chimeway/notifier.ex`, `lib/chimeway/trigger.ex`, `test/chimeway/trigger_pipeline_test.exs`, `.planning/ROADMAP.md` |

## Corrections Made

None. The user approved the recommendation set as presented.

## Methodology Applied

- `Cohesive Recommendation Default`
- `High-Impact Escalation Gate`
- `Research-First Decision Ownership`
- `One-Shot Recommendation Bias`
- `Durable Explainability Bias`
- `Least-Surprise DX Default`

## Notes for Downstream Agents

- Treat the durable declaration/state/history split as locked.
- Do not collapse workflow truth into opaque metadata blobs or job-state inference.
- Preserve the existing event -> notification -> delivery lifecycle spine while introducing workflow-specific declaration, run, and transition artifacts.

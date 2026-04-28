# Phase 20: Digest Emission & Explainability - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `20-CONTEXT.md` — this log preserves the analysis.

**Date:** 2026-04-28
**Phase:** 20-digest-emission-explainability
**Mode:** assumptions + research
**Areas analyzed:** emission lifecycle, membership resolution, explainability surface, source-row convergence

## Assumptions Presented

### Emission Lifecycle Identity
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Emit digests by creating or advancing a canonical digest delivery row, then reuse the normal dispatch lifecycle. | Likely | `lib/chimeway/dispatch/oban.ex`, `lib/chimeway/dispatch/oban_worker.ex`, `lib/chimeway/delivery_planning.ex`, `.planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md` |

### Membership Outcome Persistence
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Existing memberships are not enough; Phase 20 needs durable per-membership emission outcome facts. | Confident | `lib/chimeway/digests/digest_membership.ex`, `lib/chimeway/digests/accumulation.ex`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md` |

### Explainability Surface
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Keep digest reasoning under `Chimeway.Traces` rather than a separate primary operator API. | Likely | `lib/chimeway/traces.ex`, `lib/chimeway/traces/explanation.ex`, `test/chimeway/orchestration/traces_deferral_test.exs`, `.planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md` |

### Source Delivery Convergence
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Source `:digest_held` rows need a durable convergence rule after flush and should not remain pending forever. | Unclear | `lib/chimeway/delivery.ex`, `lib/chimeway/delivery_planning.ex`, `test/chimeway/orchestration/dispatch_gating_test.exs`, `.planning/REQUIREMENTS.md` |

## Research Applied

### Elixir/Phoenix/Ecto Codebase-Fit Research
- Recommendation: keep digest emission on the canonical delivery spine, persist explicit membership
  resolution facts, keep explainability under `Chimeway.Traces`, and converge source held rows in
  place after flush.
- Rationale: this matches the repo's existing delivery-row lifecycle model, thin-job Oban posture,
  and trace-centric operator contract.

### Cross-Ecosystem Prior Art
- GitHub: explicit durable reasons and one operator-facing notification story are strong precedents.
- Discourse: previewability and sent-summary visibility are strong DX precedents; deriving digest
  behavior from adjacent email state is a footgun.
- Knock: explicit batch/window identity and skip reasons are useful; hosted-workflow caveats,
  retention-bound logs, and first-activity shortcuts are not a fit for Chimeway's local-first
  durability model.
- Noticed/Laravel/Symfony: avoid letting notifier class names, queue timing, or background worker
  presence become accidental durable identity or hidden correctness dependencies.

## Corrections Made

User confirmed the recommendation set and asked for deeper research, cohesive tradeoff analysis, and
default recommendation bias with escalation reserved for very high-impact decisions.

## Final Recommendation Set

1. Emit digests as normal canonical delivery rows and reuse the existing delivery/attempt/dispatch
   lifecycle.
2. Persist immutable per-membership resolution facts directly on the membership model.
3. Keep digest explainability under `Chimeway.Traces`, adding digest-specific trace APIs only as
   extensions of that namespace.
4. Converge source held rows in place after flush with an explicit digest terminal outcome and link
   back to the emitted digest delivery.

## Deferred Ideas

- Hosted-style workflow debugger UX.
- Full template/render preview system beyond what digest explainability needs.
- Broader analytics/reconciliation surfaces beyond the Phase 20 boundary.

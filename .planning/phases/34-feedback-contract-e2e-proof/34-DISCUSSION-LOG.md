# Phase 34: feedback-contract-e2e-proof - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in 34-CONTEXT.md — this log preserves the analysis that produced them.

**Date:** 2026-05-02
**Phase:** 34-feedback-contract-e2e-proof
**Mode:** assumptions
**Calibration tier:** minimal_decisive (per user memory `feedback_research_first.md` — research-first one-shot decisive recommendations)
**Areas analyzed:** Canonical Outcome Vocabulary, E2E Proof Shape, Audit-Closure Artifacts

## Methodology Lenses Applied

From `.planning/METHODOLOGY.md`:
- **Cohesive Recommendation Default** — converged on one internally consistent recommendation set per area.
- **High-Impact Escalation Gate** — none of the three areas was high-blast-radius enough to require user-side option menus; all three were presentable as decisive single recommendations.
- **Research-First Decision Ownership** — every assumption cites concrete file paths + line numbers as evidence.
- **One-Shot Recommendation Bias** — single recommendation per area, alternatives surfaced only via "If wrong" framing.
- **Durable Explainability Bias** — preserved the deliberate three-axis outcome vocabulary distinction (adapter-normalized vs signal-name vs workflow-curated) rather than collapsing them.
- **Least-Surprise DX Default** — locked vocabulary to what production already emits; reused Phase 33's host-mounted harness rather than rebuilding.
- **Low-Escalation Recommendation Default** — chose forward-only audit closure over scattered retroactive Phase 31 edits.

## Assumptions Presented

### Canonical Outcome Vocabulary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Lock signal event-name axis to `chimeway.delivery.{succeeded,bounced,failed}`; fix synthetic trace fixtures only; preserve three-axis distinction (adapter-normalized vs signal-name vs workflow-curated) | Confident | `lib/chimeway/webhooks/process_feedback_worker.ex:139,159-167` (live emission); `test/chimeway/webhooks/process_feedback_worker_test.exs:77,117` (real-worker assertions); `lib/chimeway/workflows/progression_outcome.ex:12-26,74-80` (curated axis is intentional); `test/chimeway/traces_test.exs:416,523` (drifted fixtures) |

### E2E Proof Shape
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Single new test in `examples/chimeway_demo_host/test/demo_host_web/controllers/`; covers progress + stop scenarios; inline `Oban.drain_queue/1` for both `:chimeway_delivery` and `:chimeway_signals`; asserts ingress + attempt + signal + workflow state + transitions + trace projection | Confident | `examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs` (existing harness with `use Oban.Testing` + sandboxed shared Repo); `lib/chimeway/deliveries.ex:1184-1207` (synchronous progression hook in `record_attempt`); `lib/chimeway/dispatch/signal_router_worker.ex:23-33` (drain `:chimeway_signals` lands `signal_received`); `examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex:37` (`"delivery_id"` resolution clause); `test/chimeway/reliability/retry_exhaustion_test.exs:133` (drain-queue posture) |

### Audit-Closure Artifacts
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `34-VERIFICATION.md` maps FLOW-01/FLOW-02 in a requirements table citing Phase 31 emission code + Phase 32 trace projection + new Phase 34 E2E test; each Phase 34 plan SUMMARY declares `requirements-completed: [FLOW-01, FLOW-02]`; no retroactive edits to Phase 31 or Phase 30 artifacts; brief audit-stale callout points at `33-VERIFICATION.md` for FEED-01/02 closure | Likely | `.planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md:115-118` (canonical table format + FEED-01/02 already closed); `.planning/phases/33-webhook-ingress-durability/33-04-SUMMARY.md:75` (canonical frontmatter pattern); `.planning/v1.4-MILESTONE-AUDIT.md:32-39` (audit's "verification mapping must exist somewhere" rule) |

## Critical Discovery During Analysis

The v1.4 milestone audit (`.planning/v1.4-MILESTONE-AUDIT.md`) was written 2026-05-01 and lists FEED-01/FEED-02 as orphaned. However, `33-VERIFICATION.md:115-118` was rewritten on 2026-05-02 and explicitly closes FEED-01/FEED-02 with evidence. The audit's FEED claims are stale; only FLOW-01/FLOW-02 remain genuinely orphaned. This shapes Phase 34's scope: it focuses exclusively on FLOW closure, with a brief callout in 34-VERIFICATION pointing the next audit pass at the existing FEED closure.

A second contract observation: there is a real **vocabulary asymmetry** between three layers in the codebase, and they are deliberately distinct:
1. Adapter-normalized status atoms (`:delivered|:bounced|:failed`) → `Ingress.normalized_status` string column.
2. Worker-canonicalized signal event-name suffix and outcome atom (`succeeded|bounced|failed`) → `Signal.event_name` and `DeliveryAttempt.outcome`.
3. Workflow-curated branchable outcome (`:delivered|:suppressed|:temporary_failure|:retries_exhausted|:permanent_failure|:bounced`) → `ProgressionOutcome.from_delivery/2`, the rule-authoring vocabulary documented in `progression_outcome.ex:12-26,74-80`.

The audit's "vocabulary drift" claim refers only to fixture inconsistency in `traces_test.exs` between layers (1) and (2) — production code at the production paths is already correct and consistent. Collapsing axis (3) into axes (1)/(2) would break Phase 25's curated workflow contract and is explicitly rejected in 34-CONTEXT D-02.

## Corrections Made

No corrections — user selected "Yes, proceed" against all three presented assumptions.

## External Research

None performed — codebase contained all evidence needed (production worker emission, demo host harness, EchoAdapter delivery_id clause, trace projection, verification frontmatter pattern). The analyzer flagged no needs_research topics.

## Subagent Used

`gsd-assumptions-analyzer` — read 15+ source files including production webhook worker, ingress schema, workflows.ex, progression engine, traces.ex, demo host controller test harness, EchoAdapter, prior-phase CONTEXT.md/VERIFICATION.md/SUMMARY.md from phases 29-33, and the v1.4 milestone audit. Returned three areas with confidence levels and evidence-backed assumptions matching the minimal_decisive calibration tier.

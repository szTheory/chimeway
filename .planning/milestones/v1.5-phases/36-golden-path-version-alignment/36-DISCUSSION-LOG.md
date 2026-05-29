# Phase 36: Golden Path & Version Alignment - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-28
**Phase:** 36-golden-path-version-alignment
**Mode:** assumptions
**Areas analyzed:** Golden path document, Version alignment, README role, Trace query, Optional webhook appendix

## Assumptions Presented

### Golden path document shape
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add `guides/introduction/golden-path.md` as single vertical-slice DOCS-01 deliverable | Confident | ROADMAP Phase 36 success criteria; fragmented guides today |
| Link to installation.md for setup steps; don't duplicate verbatim | Confident | `guides/introduction/installation.md` already has 4-step flow |
| Notifier examples use `recipients/1` with `recipient_identity`/`recipient_type` | Confident | `lib/chimeway/notifier.ex`, `lib/chimeway/trigger.ex` |

### Version alignment strategy
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Align README, installation, golden-path to `mix.exs` `0.1.0` / `~> 0.1` | Likely | Assessment thread; Phase 35 D-14 deferral |
| Fix installation.md `~> 1.0.0` drift | Confident | `.planning/threads/2026-05-28-v1.5-milestone-assessment.md` |
| No Hex 1.0.0 bump in this phase | Likely | DOCS-02 requires one story, not necessarily 1.0.0 |

### README role
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Slim README; fix broken `resolve_recipients` example; link golden-path | Confident | `README.md` documents non-existent callback |

### Trace query in golden path
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Proof step uses `Chimeway.Traces.explain_delivery/1` on trigger result delivery_id | Confident | DOCS-01; `lib/chimeway/traces.ex` |
| Inbox listing alone insufficient for explainability proof | Confident | PROJECT.md core value |

### Optional webhook section
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Short appendix cross-linking demo host + feedback_pipeline_e2e_test | Likely | ROADMAP criterion 2 "optionally extends" |
| No full inline webhook tutorial | Likely | Demo host already proves loop |

## Corrections Made

No corrections — all assumptions confirmed by user ("1" / Yes, proceed).

## External Research

No external research performed — codebase evidence sufficient.

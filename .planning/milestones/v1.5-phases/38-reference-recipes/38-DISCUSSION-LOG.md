# Phase 38: Reference Recipes - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-28
**Phase:** 38-reference-recipes
**Mode:** assumptions
**Areas analyzed:** Recipe placement & packaging, RECP-01 password-reset support trace, RECP-02 feedback escalation workflow, Persona framing, Scope boundary, Doc-contract verification

## Assumptions Presented

### Recipe placement & packaging
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Both recipes ship under `guides/recipes/` and register in `mix.exs` HexDocs extras | Confident | Existing 3 recipes at `guides/recipes/`; Phase 36 golden-path HexDocs pattern; ROADMAP allows guides/ or examples/ |

### RECP-01 — Password-reset support trace
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Persona-driven recipe at `guides/recipes/password-reset-support-trace.md` with Feature Developer notifier/trigger + Support Operator trace diagnosis via `find_traces_for_recipient/2` and `explain_delivery/1` | Confident | SEED-004 Support Operator JTBD; `tracing-a-notification.md` lacks persona walkthrough; `traces_test.exs` uses `password_reset` key |
| 2–3 diagnostic branches: policy suppression, delivery failure, succeeded-but-user-claims-missing | Confident | RECP-01 requirement: trigger → policy/delivery outcomes → explainable trace; `lib/chimeway/deliveries.ex` suppression reasons; `lib/chimeway/policy/settings.ex` quiet hours |

### RECP-02 — Feedback escalation workflow
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Persona-driven recipe at `guides/recipes/feedback-escalation-workflow.md` narrating send → webhook → workflow progression in trace | Confident | RECP-02 requirement; `feedback_pipeline_e2e_test.exs` canonical proof |
| Cross-link demo host E2E and journey guide rather than full inline webhook setup (Phase 36 D-09 pattern) | Confident | Phase 36-CONTEXT D-09/D-10; golden-path webhook appendix already links E2E test |

### Persona framing
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Each recipe opens with "Who this is for" mapping to SEED-004 personas and ROADMAP JTBD quotes | Likely | ROADMAP success criteria names Feature Developer, Support Operator, Product Manager per recipe |

### Scope boundary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Docs-only — no engine changes, no new demo host features | Confident | Phases 36–37 pattern; PROJECT.md engine scope fixed; Phase 37 deferred recipes to Phase 38 |

### Doc-contract verification
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Extend `doc_contract_test.exs` with lightweight recipe assertions; full GATE-01 remains Phase 41 | Likely | Phase 37-REVIEW WR-03; existing journey guide doc-contract pattern in `test/chimeway/doc_contract_test.exs` |

## Corrections Made

No corrections — all assumptions confirmed by user ("Yes, proceed").

## External Research

No external research performed — codebase provided sufficient evidence.

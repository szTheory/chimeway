# Phase 59: Accrue Blueprint & Demo - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-30
**Phase:** 59-accrue-blueprint-demo
**Mode:** assumptions
**Areas analyzed:** Delivery order, Demo proof architecture, Demo event entry, Demo email adapter, Blueprint recipe scope, Doc-contract (ECOS-07), Demo host Accrue wiring, Operator traces (DEMO-07), Demo seeds API

## Assumptions Presented

### Delivery order
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Follow ROADMAP waves: demo first (59-01), blueprint + doc-contract second (59-02) | Confident | `.planning/ROADMAP.md` Wave 1–2; Phase 58 D-13 |

### Demo proof architecture
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `@moduletag :accrue` isolated from `:journey`; extend `mix verify.accrue` to demo host | Likely | `mailglass_delivery_proof_test.exs`, `mix.exs` verify aliases |

### Demo event entry
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Demo uses `Accrue.Test.trigger_event/2` — not direct `Chimeway.trigger/3` or host glue | Confident | `accrue_dunning_lifecycle_test.exs`, Phase 58 D-12 |

### Demo email adapter
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Logger adapter for dunning email steps (not Mailglass) | Likely | `test/support/accrue/fixtures.ex` |

### Blueprint recipe scope
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New `guides/recipes/accrue-dunning-blueprint.md`; golden-path guide stays Phase 60 | Confident | `mailglass-integration-blueprint.md`, Phase 57 D-02 |

### Doc-contract (ECOS-07)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| ECOS-07 describe block in `doc_contract_test.exs` mirroring ECOS-05 | Confident | `doc_contract_test.exs` mailglass blueprint block |

### Demo host Accrue wiring
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add Accrue dep + TestRepo bootstrap to demo host | Confident | demo host `mix.exs`, `test/test_helper.exs` Mailglass pattern |

### Operator traces (DEMO-07)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Admin proof shows `accrue.dunning` workflow + `invoice.paid` termination | Likely | ROADMAP SC #3, `admin_trace_live_test.exs` |

### Demo seeds API
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add `DemoHost.Seeds.seed_accrue_dunning/0` as adopter-copyable API | Likely | `DemoHost.Seeds` pattern |

## Corrections Made

No corrections — all assumptions confirmed by user ("Yes, proceed").

## Methodology Lenses Applied

- **Cohesive Recommendation Default** — Converged on Mailglass vertical-slice template for Accrue demo + blueprint (STATE.md v1.9 decision).
- **High-Impact Escalation Gate** — Logger vs Mailglass for demo email adapter surfaced as Likely (reversible); user confirmed without correction.

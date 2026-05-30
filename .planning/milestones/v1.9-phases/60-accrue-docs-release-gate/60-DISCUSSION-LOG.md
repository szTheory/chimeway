# Phase 60: Accrue Docs & Release Gate - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-30
**Phase:** 60-accrue-docs-release-gate
**Mode:** assumptions
**Areas analyzed:** Guide path & structure, Guide vs blueprint separation, Doc-contract, Release gate (CI + MAINTAINING), README discoverability

## Assumptions Presented

### Guide path & structure (DOCS-08)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New guide at `guides/introduction/accrue-dunning-integration.md` mirroring Mailglass introduction skeleton | Confident | `guides/introduction/mailglass-integration.md`, ROADMAP Wave 60-01, 59-CONTEXT D-12 |
| Billing-event trigger path (not host `Chimeway.trigger/3` as primary story); Logger email minimal path + optional Mailglass cross-link | Likely | `59-CONTEXT.md` D-05/D-06, `accrue_dunning_proof_test.exs` |
| Forbid `payment_recovered`; document `invoice.paid` Outcome Signal | Confident | `58-CONTEXT.md` D-08/D-09, ECOS-06 |

### Guide vs blueprint separation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Guide owns end-to-end path; update blueprint reciprocal link (replace Phase 60 placeholder) | Confident | Phase 57 D-02 in STATE.md, `accrue-dunning-blueprint.md` out-of-scope section |

### Doc-contract (DOCS-09)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New describe block parallel to DOCS-06/07; reuse `@recipe_forbidden_strings` + fictional-module guard | Confident | `doc_contract_test.exs` mailglass guide + ECOS-07 blueprint describes |
| Required strings = blueprint minimum + guide-specific (`mix verify.accrue`, `seed_accrue_dunning`, `ACCRUE_PATH`) | Likely | ECOS-07 `@required` list, ROADMAP SC #2 |

### Release gate (GATE-05 Accrue)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New `verify_accrue` CI job mirroring `verify_mailglass` | Confident | `.github/workflows/ci.yml`, no accrue job today |
| CI checks out sibling Accrue repo with pinned ref + `ACCRUE_PATH` | Likely | `mix.exs` verify.accrue, 59-VERIFICATION.md, 59-REVIEW IN-03 |
| MAINTAINING pre-ship: add `mix verify.accrue`; six → seven gates; inbox half deferred Phase 62 | Confident | `MAINTAINING.md`, REQUIREMENTS traceability |
| README link for new guide | Likely | `README.md` Mailglass guide entry |

### Delivery order
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| 60-01 + 60-03 parallel Wave 1; 60-02 blocked on 60-01 | Confident | `.planning/ROADMAP.md` Phase 60 waves |

## Corrections Made

No corrections — all assumptions confirmed.

## External Research

Not performed — codebase and prior phase context sufficient.

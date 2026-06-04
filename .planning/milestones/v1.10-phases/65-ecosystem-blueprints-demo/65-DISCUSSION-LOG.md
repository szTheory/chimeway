# Phase 65: Ecosystem Blueprints & Demo - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-30
**Phase:** 65-ecosystem-blueprints-demo
**Mode:** assumptions
**Areas analyzed:** Blueprint Document Shape, Demo Host Proof Structure, Doc-Contract Coverage

## Assumptions Presented

### Blueprint Document Shape
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Sigra auth blueprint follows exact structure of accrue-dunning-blueprint.md — "Who this is for," responsibility split, notifier authoring code, adopter wiring, trigger example, demo pointer, reciprocal guide cross-link | Confident | `guides/recipes/accrue-dunning-blueprint.md`, `guides/recipes/mailglass-integration-blueprint.md`, `test/chimeway/doc_contract_test.exs` lines 247/297 |

### Demo Host Proof Structure
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Both DEMO-09 and DEMO-10 are separate test files in `examples/chimeway_demo_host/test/demo_host_web/`, guarded by `Code.ensure_loaded?/1`, `@moduletag :threadline` / `:sigra`, `ConnCase + Oban.Testing`, `DemoHost.Seeds.*` trigger, `/admin/chimeway` LiveView assertion | Confident | `examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs` (DEMO-07 template), `mix.exs` ci.test excludes already include `:threadline` and `:sigra` |

### Doc-Contract Coverage (ECOS-10)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| ECOS-10 doc-contract is a new `describe` block in `test/chimeway/doc_contract_test.exs` (not separate file); `guides/recipes/sigra-auth-blueprint.md` added to `mix.exs` HexDocs extras in Phase 65 | Likely | ECOS-05 (~line 247) and ECOS-07 (~line 297) both append to same file; HexDocs extras contract test (lines ~851–901) will miss blueprint unless added now |

## Corrections Made

No corrections — all assumptions confirmed by user.

## External Research

No external research needed — codebase provided sufficient evidence for all decisions.

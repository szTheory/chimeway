# Phase 42: Close gap DOCS-02/GATE-01 - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-29
**Phase:** 42-close-gap-docs-02-gate-01-align-consumer-docs-to-1-0-0-and-f
**Mode:** assumptions
**Areas analyzed:** Phase boundary, Version alignment, Drift pattern reconciliation, ex_doc cross-package links, Demo host README auth doc, Out of scope

## Assumptions Presented

### Phase boundary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Close DOCS-02/GATE-01 regression; full pre-ship quartet must be green | Confident | `v1.5-MILESTONE-AUDIT.md`, `MAINTAINING.md` step 3 |

### Version alignment (DOCS-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Update README, installation, golden-path to `{:chimeway, "~> 1.0"}` | Confident | `doc_contract_test.exs` alignment describe; uncommitted diff |

### Drift pattern reconciliation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Dynamic `stale_drift_patterns/2` keyed off mix.exs major.minor | Confident | Audit item #2; `doc_contract_test.exs` lines 431–445 |

### ex_doc cross-package links
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Convert `../../examples/` and `../../chimeway_admin/` to GitHub URLs | Likely | `mix ci.docs` 10 warnings; Phase 36-03-SUMMARY |

### Demo host README auth doc
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Remove stale ALLOW_DEMO_ADMIN reference | Likely | Audit item #4; Phase 40 auth change |

### Out of scope
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| No engine changes, no new doc-contract blocks, no Hex publish, no Nyquist fixes | Confident | Phase name; Phase 41 deferred items |

## Corrections Made

No corrections — all assumptions confirmed via "Yes, proceed" (option 1).

## External Research

None required — codebase and re-audit artifacts sufficient.

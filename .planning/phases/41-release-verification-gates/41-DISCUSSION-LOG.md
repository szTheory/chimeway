# Phase 41: Release Verification Gates - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-29
**Phase:** 41-release-verification-gates
**Mode:** assumptions
**Areas analyzed:** Doc-contract matrix, Version alignment, Installer task gate, verify.example CI, verify.example scope, Named entrypoint, MAINTAINING.md runbook

## Assumptions Presented

### Doc-contract matrix completion
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Extend `doc_contract_test.exs` for golden-path, installation, README, oban-integration | Likely | `test/chimeway/doc_contract_test.exs` (37 tests); Phase 37 IN-01 deferred; Phases 35–40 deferred full GATE-01 matrix |

### Version alignment gate
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Automated ExUnit gate for `@version` ↔ `~> 0.1` alignment across consumer docs | Confident | `mix.exs` `@version "0.1.0"`; Phase 36 manual grep gates in `36-03-PLAN.md`; no persistent test |

### Installer task name gate
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Require `mix chimeway.gen.migrations` in installation, golden-path, README | Confident | Phase 35 D-01; `lib/mix/tasks/chimeway.gen.migrations.ex`; docs already reference task |

### verify.example in CI
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Dedicated GitHub Actions job on every push/PR; separate from `ci.test` | Likely | `mix.exs` `verify.example` alias; ROADMAP criterion #1; `.github/workflows/ci.yml` has no verify job |

### verify.example scope expansion
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Include admin/reference-flow smoke (chimeway_admin tests and/or demo-host admin route) | Likely | Phase 40 CONTEXT defers admin smoke; demo host has no admin tests; `chimeway_admin/test/` exists |

### Named pre-ship entrypoint
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add `mix ci.verify_gates` bundling doc-contract + version alignment | Likely | `AGENTS.md`; Phase 35 `ci.install_golden` pattern; doc-contract buried in full test suite |

### MAINTAINING.md runbook
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Mandate `ci.verify_gates` + `verify.example` in pre-ship steps | Confident | `MAINTAINING.md` missing GATE-01 gates; ROADMAP criterion #3 |

## Corrections Made

No corrections — all assumptions confirmed by user ("1" / Yes, proceed).

## External Research

Not performed — codebase evidence sufficient for all assumptions.

# Phase 35: Installer Task - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-28
**Phase:** 35-installer-task
**Mode:** assumptions
**Areas analyzed:** Task name & scope, Migration delivery model, Host repo wiring, Idempotency contract, Oban boundary, Verification, Documentation boundary

## Assumptions Presented

### Task name & scope
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Ship `mix chimeway.gen.migrations` only; no full `mix chimeway.install` | Confident | `guides/introduction/installation.md:30`, ROADMAP Phase 35, only 2 Mix tasks exist today |

### Migration delivery model
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Copy-based from `priv/chimeway_migrations/` templates; defer programmatic `Chimeway.Migration` API | Likely | 32 files in `priv/repo/migrations/`, installation.md "copy files", mailglass programmatic API is larger scope |

### Host repo wiring
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Detect repo from `config :chimeway, repo:`; rewrite `Chimeway.Repo.Migrations.*` → host namespace | Confident | `installation.md` config section, existing migration module naming |

### Idempotency contract
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Re-run matches by stable slug, not timestamp; prints "unchanged", creates nothing | Confident | INST-02, `prompts/chimeway-testing-and-e2e-strategy.md`, sigra/mailglass patterns |

### Oban boundary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Exclude Oban from generated bundle | Confident | Oban optional dep, `guides/recipes/oban-integration.md`, Oban has own install |

### Verification (INST-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Golden-diff + idempotency tests with named CI alias | Confident | `prompts/chimeway-testing-and-e2e-strategy.md`, mailglass `install_golden_test.exs` |

### Documentation boundary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Defer semver alignment to Phase 36 | Confident | ROADMAP phase boundaries, assessment version mismatch noted separately |

## Corrections Made

No corrections — all assumptions confirmed by user ("Yes, proceed").

## External Research

Not required — codebase and sibling library patterns (mailglass, sigra) provided sufficient evidence.

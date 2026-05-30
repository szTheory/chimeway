---
phase: 60
slug: accrue-docs-release-gate
status: passed
score: 23/23
requirements:
  DOCS-08: passed
  DOCS-09: passed
  GATE-05: passed
verified_at: 2026-05-30
---

# Phase 60 Verification: Accrue Docs & Release Gate (DOCS-08, DOCS-09, GATE-05 Accrue)

**Goal:** Documentation + release gate for Accrue dunning adoption — golden-path guide, doc-contract tests, and `mix verify.accrue` CI gate alongside existing journey/mailglass verify entrypoints.

**Status:** `passed` — all must-haves from plans 60-01, 60-02, and 60-03 verified against codebase and automated gates.

## Requirements Traceability

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| **DOCS-08** | Golden-path integration guide covers Accrue dunning setup (dependencies → config → proof) | **passed** | `guides/introduction/accrue-dunning-integration.md` — 8 sections from SEED-003 split through verification; README + HexDocs extras |
| **DOCS-09** | Doc-contract tests lock Accrue integration guide truth and forbid regressions | **passed** | `describe "accrue dunning integration guide doc contract (DOCS-08 / DOCS-09)"` in `doc_contract_test.exs`; 23 guide-specific tests within 200-test suite |
| **GATE-05 (Accrue half)** | Named verify entrypoint `mix verify.accrue` runs in CI and appears in MAINTAINING.md pre-ship checklist | **passed** | `verify_accrue` job in `.github/workflows/ci.yml`; MAINTAINING.md septet with `mix verify.accrue` + ACCRUE_PATH docs; `mix verify.inbox` correctly deferred to Phase 62 |

## ROADMAP Success Criteria

| Criterion | Status | Evidence |
|-----------|--------|----------|
| SC #1: Golden-path Accrue guide walks fresh host from dependency → config → dunning trigger → operator trace | **passed** | Guide sections 1–7 cover deps, migrations, `config :accrue`, billing events, `mix verify.accrue`, `DemoHost.Seeds.seed_accrue_dunning/0`, `/admin/chimeway` |
| SC #2: Doc-contract tests fail if guide text regresses or omits required Accrue setup steps | **passed** | 14 `@required` strings + billing-state split + dependencies section + `payment_recovered` forbid + `@recipe_forbidden_strings` guards |
| SC #3: `mix verify.accrue` runs in CI and appears in MAINTAINING pre-ship checklist without breaking existing journey/mailglass gates | **passed** | Additive `verify_accrue` job only; MAINTAINING "All seven must pass"; no `verify.inbox` yet |

## Plan 60-01 Must-Haves (DOCS-08)

| Truth / Artifact / Link | Status | Evidence |
|-------------------------|--------|----------|
| Golden-path guide walks dependency → engine config → billing-event triggers → verification (D-03, D-04) | **passed** | `accrue-dunning-integration.md` sections 1–7 |
| Guide owns end-to-end path; blueprint reciprocal link replaces Phase 60 placeholder (D-05) | **passed** | Blueprint Out of scope + Related guides link to introduction guide; no "placeholder" or "ships in Phase 60" text |
| Guide forbids `payment_recovered` and host-only `Chimeway.trigger` adoption story (D-07, D-04) | **passed** | `grep -c payment_recovered` → 0; section 6 explicitly forbids host `Chimeway.trigger(DunningNotifier, ...)` as primary path |
| README and HexDocs extras expose guide for adopters (D-08) | **passed** | `README.md` adoption link; `mix.exs` extras line 145 after `mailglass-integration.md` |
| Artifact: `guides/introduction/accrue-dunning-integration.md` | **passed** | Contains `Accrue.Integrations.Chimeway`, `config :accrue`, events, verify command |
| Artifact: `guides/recipes/accrue-dunning-blueprint.md` reciprocal link | **passed** | Links to `../introduction/accrue-dunning-integration.md` |
| Key link: guide → blueprint via copy-paste pointer | **passed** | Opening paragraph + section 4/5 blueprint cross-refs |
| Key link: guide → `DemoHost.Seeds.seed_accrue_dunning` via verification | **passed** | Section 6 verification block |

## Plan 60-02 Must-Haves (DOCS-09)

| Truth / Artifact / Link | Status | Evidence |
|-------------------------|--------|----------|
| Doc-contract describe locks required strings and forbids drift (D-09, D-11) | **passed** | `@required` list: engine, events, `cancel_signals`, `workflow/2`, keys, `mix verify.accrue`, `ACCRUE_PATH`, etc. |
| Guide forbids `payment_recovered` and fictional module references (D-12) | **passed** | Dedicated forbid test + `Chimeway.Workflow` regex guard |
| CI fails when guide text regresses or omits required setup steps | **passed** | `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` → 200 tests, 0 failures |
| Artifact: `doc_contract_test.exs` DOCS-08/09 describe | **passed** | `@accrue_integration_guide` → `guides/introduction/accrue-dunning-integration.md` |
| Key link: doc-contract → guide file via `File.read!` | **passed** | Path expand matches mailglass guide pattern |

## Plan 60-03 Must-Haves (GATE-05 Accrue)

| Truth / Artifact / Link | Status | Evidence |
|-------------------------|--------|----------|
| `verify_accrue` CI job runs `mix verify.accrue` with Postgres after sibling Accrue checkout (D-13, D-14) | **passed** | Job checks out `szTheory/accrue` ref `de7a3fef53247619d96a26eea60197d74fd14634` to `accrue/accrue`; `ACCRUE_PATH` env set |
| MAINTAINING pre-ship checklist documents `mix verify.accrue` as seventh gate (D-16) | **passed** | Command in pre-ship block; "All seven must pass"; Accrue sibling checkout subsection |
| Existing journey/mailglass verify jobs unchanged — additive CI only | **passed** | Single `verify_accrue` job id; `verify_mailglass` block intact |
| Artifact: `.github/workflows/ci.yml` `verify_accrue` job | **passed** | Postgres service, ecto create/migrate, `mix verify.accrue` final step |
| Artifact: `MAINTAINING.md` septet including accrue gate | **passed** | Lines 32, 41, 43, 45–47 |
| Key link: CI → `mix verify.accrue` alias | **passed** | Workflow final run step |
| Key link: MAINTAINING → CI parity for maintainers | **passed** | Same command + ACCRUE_PATH convention documented |

## Automated Gates

| Gate | Result |
|------|--------|
| `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | **PASS** (200 tests, 0 failures) |
| `ACCRUE_PATH=../accrue/accrue mix verify.accrue --warnings-as-errors` | **PASS** (11 root + 3 demo `:accrue` tests, 0 failures) |
| Plan 60-01 grep (guide required strings, no `payment_recovered`) | **PASS** |
| Plan 60-01 cross-link grep (blueprint, README, mix.exs) | **PASS** |
| Plan 60-03 grep (`verify_accrue`, szTheory/accrue, MAINTAINING seven) | **PASS** |
| Blueprint placeholder removed | **PASS** (no "placeholder" / "ships in Phase 60") |

## Human Verification

| Item | Required? | Notes |
|------|-----------|-------|
| Sibling Accrue checkout for local `mix verify.accrue` | Yes (local dev) | Verified green with `ACCRUE_PATH=../accrue/accrue` in this session |
| CI `verify_accrue` job green on GitHub | Recommended | Job structure verified in workflow YAML; runtime not re-run in this session |
| `.planning/REQUIREMENTS.md` DOCS-08/DOCS-09 checkboxes | Planning follow-up | Functional closure verified here; traceability table still shows DOCS-08/09 Pending until planning doc updated |
| Browser walkthrough of guide adoption path | Optional | Automated doc-contract + verify.accrue satisfy acceptance; manual read confirms deps → config → events → verify flow |

## Notes

- Phase 60 scope correctly excludes inbox guide, inbox doc-contract, and `mix verify.inbox` (Phase 62).
- Guide documents `Chimeway.trigger/3` only as internal engine behaviour — not as host adoption path — satisfying D-04/D-07 intent.
- `mix.exs` `verify.accrue` alias unchanged per D-15; CI sibling checkout at `accrue/accrue` satisfies demo host path convention.
- Doc-contract suite grew from 177 tests (Phase 59 baseline) to 200 tests (+23 guide contract tests).

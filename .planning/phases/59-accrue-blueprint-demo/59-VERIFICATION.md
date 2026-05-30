---
phase: 59
slug: accrue-blueprint-demo
status: passed
score: 21/21
requirements:
  ECOS-07: passed
  DEMO-07: passed
verified_at: 2026-05-30
---

# Phase 59 Verification: Accrue Blueprint & Demo (ECOS-07, DEMO-07)

**Goal:** Adopters can copy a published Accrue + Chimeway dunning reference recipe and see the same behaviour proven on the demo host with operator trace inspectability at `/admin/chimeway`.

**Status:** `passed` — all must-haves from plans 59-01 and 59-02 verified against codebase and automated gates.

## Requirements Traceability

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| **ECOS-07** | Published Accrue dunning reference recipe with CI doc-contract coverage (Chimeway orchestrates when/why; Accrue owns billing state) | **passed** | `guides/recipes/accrue-dunning-blueprint.md`; `doc_contract_test.exs` ECOS-07 describe (18 tests); ExDoc extras at `mix.exs` line 151 |
| **DEMO-07** | Demo host proves Accrue-driven dunning end-to-end with operator trace inspectability at `/admin/chimeway` | **passed** | `AccrueDunningProofTest` (3 `:accrue` tests); `DemoHost.Seeds.seed_accrue_dunning/0` via `Accrue.Test.trigger_event/2`; `mix verify.accrue` — 11 root + 3 demo tests green |

## ROADMAP Success Criteria

| Criterion | Status | Evidence |
|-----------|--------|----------|
| SC #1: Reference recipe documents notifier authoring, Accrue event subscription, orchestration vs billing-state split with doc-contract | **passed** | Blueprint sections for DunningNotifier, `invoice.payment_failed` / `invoice.paid`, responsibility split; ECOS-07 `@required` strings enforced |
| SC #2: Demo host proves Accrue-driven dunning — failed payment triggers escalation path; paid invoice terminates workflow | **passed** | Initial email + `:waiting` with `pending_signals: ["invoice.paid"]`; `invoice.paid` → `status_reason: "signal_received"`, zero `escalation_email` deliveries |
| SC #3: Operator traces at `/admin/chimeway` show dunning workflow progression and explainable decisions | **passed** | Admin LiveView test submits `#trace-search-form`, asserts `accrue.dunning` / `waiting_for_step_progression` on delivery detail |

## Plan 59-01 Must-Haves (DEMO-07)

| Truth / Artifact / Link | Status | Evidence |
|-------------------------|--------|----------|
| Demo proves Accrue-driven dunning via billing events — not host `Chimeway.trigger/3` glue (D-05) | **passed** | `DemoHost.AccrueSeeds.seed_accrue_dunning/0` calls `Accrue.Test.trigger_event(:invoice_payment_failed, …)` |
| Failed payment → initial Logger email → `:waiting` with `pending_signals: ["invoice.paid"]` → `invoice.paid` terminates before escalation (D-07) | **passed** | `accrue_dunning_proof_test.exs` tests 1–2 |
| Operator trace at `/admin/chimeway` shows `accrue.dunning` workflow progression (D-08) | **passed** | Admin trace test: `#trace-search-form`, delivery detail HTML |
| `@moduletag :accrue` tests isolated from `:journey` suite (D-03) | **passed** | `mix test --only journey --warnings-as-errors` (demo host) → 10 tests, 0 failures |
| `mix verify.accrue` runs root and demo host `:accrue` tests (D-04) | **passed** | Root 11 + demo 3 = 14 tests via `verify.accrue` alias |
| Artifact: `accrue_dunning_proof_test.exs` with `@moduletag :accrue` | **passed** | `@moduletag :accrue` line 19; wrapped in `Code.ensure_loaded?(Accrue)` guard |
| Artifact: `DemoHost.Seeds.seed_accrue_dunning/0` | **passed** | `seeds.ex` lines 137–144; not called from `run/0` |
| Artifact: `mix.exs` `verify.accrue` includes demo host step | **passed** | `mix.exs` line 114 — `chimeway_demo_host` cd + `--only accrue` |
| Key link: seeds → `Accrue.Test.trigger_event` | **passed** | `accrue_support/seeds.ex` line 75 |
| Key link: proof test → `/admin/chimeway` LiveView trace search | **passed** | `trace-search-form` submit in admin trace test |

## Plan 59-02 Must-Haves (ECOS-07)

| Truth / Artifact / Link | Status | Evidence |
|-------------------------|--------|----------|
| Recipe documents DunningNotifier authoring, Accrue event subscription, Chimeway vs Accrue responsibility split (D-11, SEED-003) | **passed** | Blueprint sections 4–6; `orchestrates` + billing-state language |
| Recipe cites real modules: `Accrue.Integrations.Chimeway.DunningNotifier`, `DemoHost.Seeds.seed_accrue_dunning/0` (D-14) | **passed** | Lines 24, 117 in blueprint |
| Recipe does not duplicate golden-path guide — points to Phase 60 (D-12) | **passed** | Out-of-scope section references DOCS-08, DOCS-09, GATE-05 |
| CI doc-contract fails on drift or missing required strings (D-15, D-16) | **passed** | ECOS-07 describe: 13 `@required` strings + forbidden guards + billing-state split test |
| Artifact: `guides/recipes/accrue-dunning-blueprint.md` | **passed** | Contains `Accrue.Integrations.Chimeway`, events, `/admin/chimeway` |
| Artifact: `doc_contract_test.exs` ECOS-07 describe | **passed** | `describe "accrue dunning blueprint recipe doc contract (ECOS-07)"` |
| Key link: blueprint → `DemoHost.Seeds.seed_accrue_dunning` | **passed** | Runnable demo section line 117 |
| Key link: doc-contract → blueprint file | **passed** | `@accrue_blueprint_recipe` path expand to `accrue-dunning-blueprint.md` |

## Automated Gates

| Gate | Result |
|------|--------|
| `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | **PASS** (177 tests, 0 failures) |
| `ACCRUE_PATH=../accrue/accrue mix verify.accrue --warnings-as-errors` | **PASS** (11 root + 3 demo `:accrue` tests, 0 failures) |
| `mix test --only journey --warnings-as-errors` (demo host) | **PASS** (10 tests, 0 failures) |
| `grep accrue-dunning-blueprint mix.exs` | **PASS** (extras line 151) |
| `grep "accrue dunning blueprint recipe doc contract" test/chimeway/doc_contract_test.exs` | **PASS** |
| Blueprint forbids `Chimeway.Adapter` as dunning seam | **PASS** | Explicit "not a `Chimeway.Adapter` seam" statement |

## Human Verification

| Item | Required? | Notes |
|------|-----------|-------|
| Browser walkthrough of `/admin/chimeway` after `seed_accrue_dunning/0` | Optional | Automated LiveView coverage satisfies DEMO-07; manual spot-check recommended before release demos |
| Sibling Accrue checkout with Phase 58 `cancel_signals` fix | Yes (local dev) | `ACCRUE_PATH=../accrue/accrue` required for `mix verify.accrue`; verified green in this session |
| `.planning/REQUIREMENTS.md` DEMO-07 checkbox | Planning follow-up | Functional closure verified here; traceability table still shows DEMO-07 Pending until planning doc updated |

## Notes

- Demo Accrue harness lives under `examples/chimeway_demo_host/accrue_support/` (ACCRUE_PATH-gated compile) — not `test/support/`, preserving journey suite isolation.
- `verify.accrue` demo step uses `CHIMEWAY_SKIP_ACCRUE_DEP=1` + `CHIMEWAY_PATH=../..` to break chimeway↔accrue Mix cycle (59-01 deviation).
- Phase 60 owns formal CI wiring (`GATE-05`), golden-path guide (`DOCS-08`), and guide doc-contract (`DOCS-09`) — correctly deferred per blueprint out-of-scope section.
- Cross-repo Accrue `cancel_signals` fix (59-01 deviation) must ship alongside Chimeway v1.9 for adopters using hex Accrue dep.

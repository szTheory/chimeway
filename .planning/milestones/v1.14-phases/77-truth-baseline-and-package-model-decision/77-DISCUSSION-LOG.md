# Phase 77: Truth Baseline and Package Model Decision - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-02T23:13:08Z
**Phase:** 77-truth-baseline-and-package-model-decision
**Mode:** assumptions
**Areas analyzed:** Package Model, Tag Namespace, Truth Ownership, Baseline Drift

## Assumptions Presented

### Package Model

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Record Chimeway as a root-only Hex package for v1.14; `chimeway_admin` and `chimeway_inbox` remain in-repo preview/path packages until a later explicit package-promotion milestone. | Confident | `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `mix.exs`, `chimeway_admin/mix.exs`, `chimeway_inbox/mix.exs`, Hex package API |

### Tag Namespace

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Package release tags should remain Release Please root-package SemVer tags using `vX.Y.Z`; planning milestone labels like `v1.14` must be treated only as planning identifiers, not package release tags. | Confident | `.planning/REQUIREMENTS.md`, `release-please-config.json`, `.release-please-manifest.json`, `.github/workflows/release.yml`, `mix.exs` |

### Truth Ownership

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 77 should assign package/release truth to Phase 78, public docs truth to Phase 79, and CI truth to Phase 80 while preserving current `ci-gate` as the release/publish source of truth. | Likely | `.planning/ROADMAP.md`, `mix.exs`, `.github/workflows/ci.yml`, `test/chimeway/release_gate_contract_test.exs` |

## Corrections Made

No corrections — all assumptions confirmed by user selection `1` on 2026-07-02.

## External Research

- Hex.pm package API: `https://hex.pm/api/packages/chimeway` returned 200 on 2026-07-02. Latest package version is `1.0.0`; package link currently points to `https://github.com/jonlunsford/chimeway`.
- Hex.pm package API: `https://hex.pm/api/packages/chimeway_admin` returned 404 on 2026-07-02.
- Hex.pm package API: `https://hex.pm/api/packages/chimeway_inbox` returned 404 on 2026-07-02.
- GitHub: `https://github.com/szTheory/chimeway` returned 200 on 2026-07-02 and matches the local git remote.
- GitHub: `https://github.com/jonlunsford/chimeway` returned 404 on 2026-07-02.

## Methodology

Applied project methodology lenses from `.planning/METHODOLOGY.md`:

- Cohesive Recommendation Default
- High-Impact Escalation Gate
- Research-First Decision Ownership
- One-Shot Recommendation Bias
- Durable Explainability Bias
- Least-Surprise DX Default
- Low-Escalation Recommendation Default

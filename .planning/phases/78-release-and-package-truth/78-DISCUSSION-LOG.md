# Phase 78: Release and Package Truth - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-03
**Phase:** 78-release-and-package-truth
**Mode:** assumptions
**Areas analyzed:** Root Release Identity, Canonical Package Surface, Sibling Package Status

## Assumptions Presented

### Root Release Identity

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 78 should preserve root-only `chimeway` release identity: root `@version`, `.release-please-manifest.json`, Release Please root package config, changelog release section, Hex package version, and HexDocs `source_ref: "v#{@version}"` stay aligned to package SemVer tags like `v1.0.0`, never planning labels like `v1.14`. | Confident | `.planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md`; `.planning/STATE.md`; `mix.exs`; `.release-please-manifest.json`; `release-please-config.json`; `CHANGELOG.md`; `.github/workflows/release.yml` |

### Canonical Package Surface

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 78 should normalize package-facing repository/source truth to `https://github.com/szTheory/chimeway` on root package metadata, HexDocs source URL, README package badges/links, and changelog/source-facing package claims, while leaving broader front-door rewrite and contributor docs cleanup to Phases 79/80 unless needed for package truth. | Confident | `.planning/REQUIREMENTS.md`; `.planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md`; `mix.exs`; `README.md`; `CHANGELOG.md`; `git remote -v` |

### Sibling Package Status

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 78 should keep `chimeway_admin` and `chimeway_inbox` as in-repo preview/path packages, remove any current Hex dependency claims, and contract-test docs so `{:chimeway_admin, "~> 1.0"}` or misleading current-published `chimeway_inbox` copy cannot return. | Confident | `.planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md`; `.planning/REQUIREMENTS.md`; `chimeway_admin/mix.exs`; `chimeway_inbox/mix.exs`; `guides/introduction/admin-console-integration.md`; `guides/introduction/inbox-integration.md` |

## Corrections Made

No corrections — all assumptions confirmed by the user.

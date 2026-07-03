# Package Model and Release Namespace

## Sources

- `AGENTS.md` - project quality gates and explainability boundary.
- `.planning/PROJECT.md` - v1.14 public truth and verification architecture goal.
- `.planning/ROADMAP.md` - Phase 77 boundary and Phase 78-80 ownership split.
- `.planning/REQUIREMENTS.md` - TRUTH-04 namespace separation requirement.
- `.planning/STATE.md` - active milestone state.
- `.planning/phases/77-truth-baseline-and-package-model-decision/77-CONTEXT.md` - D-01 through D-10 locked decisions.
- `.planning/phases/77-truth-baseline-and-package-model-decision/77-RESEARCH.md` - evidence-backed package, docs, and CI drift baseline.
- `.planning/phases/77-truth-baseline-and-package-model-decision/77-PATTERNS.md` - decision-record and validation patterns.
- `.planning/phases/77-truth-baseline-and-package-model-decision/77-VALIDATION.md` - source assertion and public-surface diff guard.
- `mix.exs` - root `@version "1.0.0"`, package whitelist, package links, and HexDocs `source_ref: "v#{@version}"`.
- `.release-please-manifest.json` - root Release Please manifest version source.
- `release-please-config.json` - root Release Please package configuration and `include-v-in-tag` rule.
- `.github/workflows/release.yml` - Release Please, root `mix hex.publish`, and pre-publish gate replay.
- `.github/workflows/publish-hex.yml` - recovery publish ref validation and root publish path.

## Decision Summary

| Decision | Rationale | Outcome | Decision IDs |
|----------|-----------|---------|--------------|
| `chimeway` is the only Hex-published package for v1.14. | Live package truth and current release automation are root-package only. Treating sibling preview packages as Hex packages would mislead adopters. | Record root-only package model for TRUTH-04 and hand package truth corrections to Phase 78. | D-01 |
| `chimeway_admin` and `chimeway_inbox` are in-repo preview/path packages. | The sibling Mix projects depend on `{:chimeway, path: ".."}` and are not published Hex dependencies in the current model. | Record sibling package status as preview/path until a future explicit package-promotion milestone. | D-02 |
| Phase 77 records sibling package status as Phase 78 input. | Phase 77 is a planning artifact phase, not a package promotion or public docs edit phase. | Phase 78 receives the sibling install-status input for README, guide, metadata, and package contract work. | D-03 |
| Package release tags are root-package SemVer tags such as `v1.0.0`. | Release Please is configured for the root package `"."` with `include-v-in-tag: true`. | Package tags stay tied to root package SemVer output, not planning milestone labels. | D-04 |
| Planning milestone labels such as `v1.14` are planning identifiers only. | GSD milestone labels describe workstreams, while Hex/GitHub releases describe published package versions. | Planning labels are not package release tags, HexDocs source refs, publish refs, changelog release anchors, or GitHub release names. | D-05 |
| Root package release identity is the root package version contract. | Root `mix.exs`, `.release-please-manifest.json`, Release Please output, Hex package version, and HexDocs `source_ref: "v#{@version}"` are the release identity surfaces. | Phase 78 must preserve and contract-test root release identity across package metadata, manifest, changelog, HexDocs, and release automation. | D-06 |

## Package Model

- **TRUTH-04 package model:** for the v1.14 planning milestone, `chimeway` is the only Hex-published package.
- `chimeway_admin` is an in-repo preview/path package, not a Hex dependency for adopters.
- `chimeway_inbox` is an in-repo preview/path package, not a Hex dependency for adopters.
- Publishing `chimeway_admin` or `chimeway_inbox` requires a later package-promotion milestone with explicit package metadata, SemVer policy, publish automation, and clean install smoke.
- Phase 77 does not edit package metadata, public docs, changelog, workflows, maintainer docs, runtime source, or sibling package `mix.exs` files.

## Release Namespace Rules

- Package release refs are root-package SemVer refs produced by Release Please, for example `v1.0.0`.
- Planning milestone labels such as `v1.14` are planning identifiers only.
- Planning milestone labels are not package release tags, HexDocs source refs, publish refs, changelog release anchors, or GitHub release names.
- Recovery publish refs in `.github/workflows/publish-hex.yml` must be package tags or 40-character commit SHAs, not planning milestone labels.
- Public copy must not imply `chimeway_admin` or `chimeway_inbox` are installable Hex packages before they are intentionally promoted and published.

## Root Package Release Rule

The root package release identity is the agreement among these surfaces:

| Surface | Current Rule | Owner |
|---------|--------------|-------|
| `mix.exs` | Root `@version "1.0.0"` drives `app: :chimeway`, package metadata, Hex build output, and docs config. | Phase 78 |
| `.release-please-manifest.json` | Root package entry `{ ".": "1.0.0" }` is the Release Please manifest version source. | Phase 78 |
| `release-please-config.json` | Single root package entry `packages["."]` has `include-v-in-tag: true`, yielding tags such as `v1.0.0`. | Phase 78 |
| Release Please output | Release PRs, GitHub releases, and tags come from root package SemVer. | Phase 78 |
| Hex package version | Published package version is the root `chimeway` version. | Phase 78 |
| HexDocs source ref | `source_ref: "v#{@version}"` must point to the matching package SemVer tag. | Phase 78 |

## Sibling Package Install Status Input

| Package | Current Status | Phase 78 Input |
|---------|----------------|----------------|
| `chimeway` | Root package, Hex-published, current manifest/package version `1.0.0`. | Preserve as the only published Hex package for this milestone and align package/docs metadata to root release truth. |
| `chimeway_admin` | In-repo preview/path package with `{:chimeway, path: ".."}` and no Hex package/docs metadata. | Public install copy must describe preview/path status unless a future package-promotion milestone changes the model. |
| `chimeway_inbox` | In-repo preview/path package with `{:chimeway, path: ".."}` and no Hex package/docs metadata. | Public install copy must describe preview/path status unless a future package-promotion milestone changes the model. |

## Truth Ownership

Truth ownership rows for D-07 through D-10 are added by Task 2 of Plan 77-01.

## Baseline Drift Inventory

| Surface | Current State | Expected Truth / Rule | Downstream Owner | Evidence |
|---------|---------------|-----------------------|------------------|----------|
| Root Hex package | `chimeway` is published as version `1.0.0`; package metadata currently carries old repository link drift. | Root package remains the only Hex package; repo/source links are corrected in package truth work. | Phase 78 | `77-RESEARCH.md`, `mix.exs` |
| `mix.exs` | Root `@version "1.0.0"` and `source_ref: "v#{@version}"`; package/docs links need canonical-source review later. | Preserve root release identity and align metadata without using `v1.14` as a release ref. | Phase 78 | `mix.exs` |
| Release Please files | Manifest contains only `"."`; config uses `include-v-in-tag: true`. | Preserve root package SemVer tags such as `v1.0.0`. | Phase 78 | `.release-please-manifest.json`, `release-please-config.json` |
| Release and publish workflows | Release and recovery publish root `chimeway` after CI gates pass. | Preserve root package publish model and reject planning labels as publish refs. | Phase 78 / Phase 80 | `.github/workflows/release.yml`, `.github/workflows/publish-hex.yml` |
| Sibling install copy | Some public guide copy can imply sibling Hex installability. | Public copy must state preview/path package status until promotion. | Phase 78 | `77-RESEARCH.md` |
| Public docs and README | First-hop docs need package/docs/repo truth alignment later. | Do not edit in Phase 77; route to owner phases. | Phase 79 | `77-RESEARCH.md` |
| CI gate topology | Current `ci-gate` remains release confidence source. | Phase 80 adds contributor-facing speed without weakening release confidence. | Phase 80 | `.github/workflows/ci.yml`, `MAINTAINING.md` |

## Validation Commands

```bash
test -f .planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md
rg -n "chimeway|chimeway_admin|chimeway_inbox|v1\\.14|v1\\.0\\.0|Release Please|HexDocs|source_ref" .planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md
test -z "$(git diff --name-only -- README.md mix.exs CHANGELOG.md .github/workflows MAINTAINING.md guides chimeway_admin/mix.exs chimeway_inbox/mix.exs)"
```

## Downstream Handoff

- Phase 78 receives the root package model, Release Please SemVer namespace rule, root package release identity surfaces, and sibling preview/path package status input.
- Phase 79 receives public docs/front-door drift rows without Phase 77 changing README or guide content.
- Phase 80 receives CI/contributor-gate drift rows without Phase 77 changing workflow topology.

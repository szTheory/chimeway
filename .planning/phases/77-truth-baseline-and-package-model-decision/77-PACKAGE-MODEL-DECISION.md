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

| Owner Phase | Truth Surface | Scope | Required Follow-up | Decision IDs |
|-------------|---------------|-------|--------------------|--------------|
| Phase 78 | Root package/release truth | package metadata, package files, release manifest, changelog, HexDocs source refs, README install constraints, canonical repo/source links, sibling package install-status copy, and package truth contracts | Align package/release metadata and public install claims to the root `chimeway` package model; keep `chimeway_admin` and `chimeway_inbox` as preview/path packages unless a future promotion milestone changes the model. | D-07 |
| Phase 79 | Public front-door docs truth | README decision-page rewrite, first-hop guide IA, accurate adoption snippets, stub guide completion/demotion, and clean consumer or unpacked-Hex smoke path | Rewrite first-hop documentation around local-first ownership, explainability, non-goals, host boundaries, optional surface status, and public adoption proof. | D-08 |
| Phase 80 | CI truth | fast always-running `pr-gate`, full release/publish `ci-gate`, required-check topology, local reproducibility, and cache coverage | Add contributor-facing speed while preserving full release confidence and making gate behavior reproducible locally. | D-09 |
| Phase 80 | Release confidence source | full `ci-gate` remains the release, publish, automerge, recovery, and mainline confidence source | Preserve existing release/publish confidence while adding the faster contributor `pr-gate`; do not demote `ci-gate` to a partial signal. | D-10 |

## Baseline Drift Inventory

| Surface | Current State | Expected Truth / Rule | Downstream Owner | Evidence |
|---------|---------------|-----------------------|------------------|----------|
| Root Hex package | `chimeway` is published on Hex at `1.0.0`; `chimeway_admin` and `chimeway_inbox` are not Hex packages. | Root `chimeway` remains the only Hex-published package for v1.14 planning work; sibling status is preview/path until a future promotion milestone. | Phase 78 | `curl -fsS https://hex.pm/api/packages/chimeway` returned latest version `1.0.0`; `curl -fsS -o /tmp/chimeway_admin_hex.json -w "%{http_code}" https://hex.pm/api/packages/chimeway_admin` returned `404`; `curl -fsS -o /tmp/chimeway_inbox_hex.json -w "%{http_code}" https://hex.pm/api/packages/chimeway_inbox` returned `404`; `77-RESEARCH.md`. |
| `mix.exs` | Root app is `:chimeway` at `@version "1.0.0"` with package files and docs `source_ref: "v#{@version}"`; package/docs URLs still point to `https://github.com/jonlunsford/chimeway`. | Root package identity stays `@version`/manifest/Hex aligned; repository and docs URLs must use canonical `https://github.com/szTheory/chimeway`; `v1.14` must not be used as a package ref. | Phase 78 | `mix.exs`; `git remote get-url origin`; `curl -fsS -o /tmp/chimeway_sztheory.html -w "%{http_code}" https://github.com/szTheory/chimeway` returned `200`; `curl -fsS -o /tmp/chimeway_jonlunsford.html -w "%{http_code}" https://github.com/jonlunsford/chimeway` returned `404`. |
| `.release-please-manifest.json` | Manifest contains only root package entry `{ ".": "1.0.0" }`. | Manifest remains the root package version source and must agree with root `mix.exs` and Hex package version; no planning milestone label belongs here. | Phase 78 | `.release-please-manifest.json`; `test/chimeway/release_gate_contract_test.exs` manifest/version contract. |
| `release-please-config.json` | Release Please is configured for only `packages["."]` with `include-v-in-tag: true`. | Release Please should keep producing root SemVer tags such as `v1.0.0`; it must not create tags from planning labels such as `v1.14`. | Phase 78 | `release-please-config.json`; `.github/workflows/release.yml`; `77-CONTEXT.md` D-04 through D-06. |
| `.github/workflows/release.yml` | Automated release flow runs Release Please, waits for `ci-gate`, verifies root `@version`, replays `mix ci.verify_gates` and `mix ci.docs`, then publishes root `chimeway` to Hex. | Preserve root-package publish model and full gate replay; package release refs come from Release Please output and root SemVer, not planning milestones. | Phase 78 / Phase 80 | `.github/workflows/release.yml`; `test/chimeway/release_gate_contract_test.exs`; `MAINTAINING.md`. |
| `.github/workflows/publish-hex.yml` | Recovery publish accepts a git tag or 40-character SHA plus expected root `@version`, then gates on `ci-gate` and publishes root `chimeway`. | Recovery refs must be real package tags or SHAs; planning labels such as `v1.14` are invalid publish refs. | Phase 78 / Phase 80 | `.github/workflows/publish-hex.yml`; `test/chimeway/release_gate_contract_test.exs`. |
| `.github/workflows/ci.yml` | Current CI has full `ci-gate` aggregation across lint, test, docs, release contracts, runtime prefix, journey, ecosystem, inbox, and admin lanes; no fast `pr-gate` yet. | Phase 80 adds contributor-facing `pr-gate` and required-check topology without weakening full release `ci-gate`. | Phase 80 | `.github/workflows/ci.yml`; `test/chimeway/release_gate_contract_test.exs`; `MAINTAINING.md`. |
| `README.md` | Public first-hop copy installs `{:chimeway, "~> 1.0"}` and links HexDocs, but CI badge URLs still point to `https://github.com/jonlunsford/chimeway`. | README must become truthful front-door docs: canonical repo URLs, root package install status, optional surface status, and no `v1.14` package-release implication. | Phase 79 | `README.md`; `git remote get-url origin`; GitHub `szTheory`/`jonlunsford` curl status commands above. |
| `CONTRIBUTING.md` | Contributor setup still tells contributors to clone `https://github.com/jonlunsford/chimeway.git`. | Contributor DX/gate documentation must use canonical `https://github.com/szTheory/chimeway`; Phase 80 owns this row. | Phase 80 | `CONTRIBUTING.md`; `git remote get-url origin`; GitHub `szTheory`/`jonlunsford` curl status commands above. |
| `CHANGELOG.md` | Current release section is `1.0.0` with commit links pointing to `https://github.com/szTheory/chimeway`; no `v1.14` release anchor is present. | Changelog release anchors should remain package SemVer releases and canonical repo links; future package releases must not use planning milestone labels. | Phase 78 | `CHANGELOG.md`; `.release-please-manifest.json`; `release-please-config.json`. |
| `MAINTAINING.md` | Maintainer runbook says Release Please owns version/changelog SSOT, release tags are `v*`, post-publish proof targets package versions, and pre-ship gates are twelve local commands. | Maintainer docs must stay aligned with root-package release truth and Phase 80 CI/DX topology, including full `ci-gate` as the release confidence source. | Phase 80 | `MAINTAINING.md`; `.github/workflows/release.yml`; `.github/workflows/publish-hex.yml`; `test/chimeway/release_gate_contract_test.exs`. |
| `guides/introduction/admin-console-integration.md` | Dependency snippet shows `{:chimeway_admin, "~> 1.0"}` even though `chimeway_admin` is not published on Hex. | Public copy must describe `chimeway_admin` as an in-repo preview/path package until explicitly promoted and published. | Phase 78 | `guides/introduction/admin-console-integration.md`; `chimeway_admin/mix.exs`; `curl -fsS -o /tmp/chimeway_admin_hex.json -w "%{http_code}" https://hex.pm/api/packages/chimeway_admin` returned `404`. |
| `guides/introduction/inbox-integration.md` | Dependency snippet uses `{:chimeway_inbox, path: "../chimeway_inbox"}` and future replacement copy for `{:chimeway_inbox, "~> 1.0"}` when published. | Keep current path-package truth and ensure future Hex replacement copy cannot be mistaken for current install status. | Phase 78 / Phase 79 | `guides/introduction/inbox-integration.md`; `chimeway_inbox/mix.exs`; `curl -fsS -o /tmp/chimeway_inbox_hex.json -w "%{http_code}" https://hex.pm/api/packages/chimeway_inbox` returned `404`. |
| `chimeway_admin/mix.exs` | Sibling Mix project is `app: :chimeway_admin`, version `0.1.0`, with `{:chimeway, path: ".."}` and no package/docs metadata. | Treat as in-repo preview/path package; do not advertise as Hex dependency unless a future promotion milestone adds metadata, SemVer policy, publish automation, and clean install smoke. | Phase 78 | `chimeway_admin/mix.exs`; Hex 404 command for `chimeway_admin`; `77-CONTEXT.md` D-02/D-12. |
| `chimeway_inbox/mix.exs` | Sibling Mix project is `app: :chimeway_inbox`, version `0.1.0`, with `{:chimeway, path: ".."}` and no package/docs metadata. | Treat as in-repo preview/path package; do not advertise as Hex dependency unless a future promotion milestone adds metadata, SemVer policy, publish automation, and clean install smoke. | Phase 78 | `chimeway_inbox/mix.exs`; Hex 404 command for `chimeway_inbox`; `77-CONTEXT.md` D-02/D-12. |
| `test/chimeway/release_gate_contract_test.exs` | Existing contract covers manifest/version parity, release/publish workflow gates, `ci-gate` lanes, maintainer pre-ship copy, and sibling integration checkout refs. | Phase 78 and Phase 80 should extend this anchor for package/source/release/CI truth drift instead of adding an unrelated checker. | Phase 78 / Phase 80 | `test/chimeway/release_gate_contract_test.exs`; `mix.exs` alias `ci.verify_gates`. |
| `test/chimeway/doc_contract_test.exs` | Existing doc contract covers guide truth, HexDocs extras ordering, admin/inbox guide required strings, and forbidden stale API claims. | Phase 79 should extend this anchor for front-door docs, optional surface status, README snippets, and first-hop docs IA truth. | Phase 79 | `test/chimeway/doc_contract_test.exs`; `mix.exs` alias `ci.verify_gates`. |

Baseline notes:

- **D-11 repository/source URL drift:** local git remote and reachable public GitHub are `https://github.com/szTheory/chimeway` while current package/docs metadata or public docs still contain `https://github.com/jonlunsford/chimeway`; the canonical repo returned `200` and the stale repo returned `404` in the live curl checks above.
- **D-12 sibling install-status risk:** `chimeway_admin` and `chimeway_inbox` returned Hex `404` and their Mix projects depend on `{:chimeway, path: ".."}`; public copy must describe them as in-repo preview/path packages until intentionally promoted.
- **D-13 package/docs/tag truth surfaces:** `README.md`, `CHANGELOG.md`, `.release-please-manifest.json`, `release-please-config.json`, `.github/workflows/release.yml`, `.github/workflows/publish-hex.yml`, `mix.exs`, and release/doc contract anchors must agree on root package state and must not use planning milestone `v1.14` as package release truth.

## Validation Commands

```bash
test -f .planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md
rg -n "chimeway|chimeway_admin|chimeway_inbox|v1\\.14|v1\\.0\\.0|Release Please|HexDocs|source_ref" .planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md
test -z "$(git diff --name-only -- README.md mix.exs CHANGELOG.md .github/workflows MAINTAINING.md guides chimeway_admin/mix.exs chimeway_inbox/mix.exs)"
```

## Downstream Handoff

- Phase 78 receives the sibling package install-status input plus the root package model, Release Please SemVer namespace rule, root package release identity surfaces, package metadata drift, package files drift, release manifest drift, changelog drift, HexDocs source ref drift, README install constraints, canonical repo/source link drift, and package truth contract gaps.
- Phase 79 receives front-door docs drift rows for the README decision-page rewrite, first-hop guide IA, accurate adoption snippets, stub guide completion/demotion, and clean consumer or unpacked-Hex smoke path.
- Phase 80 receives CI/contributor-gate drift rows for the fast always-running `pr-gate`, full release/publish `ci-gate`, required-check topology, local reproducibility, and cache coverage.
- Full `ci-gate` remains the release, publish, automerge, recovery, and mainline confidence source while Phase 80 adds contributor-facing speed per D-10.

# Phase 78: Release and Package Truth - Context

**Gathered:** 2026-07-03 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Align root package metadata, release manifest, changelog, HexDocs source refs, README install constraints, package files whitelist, canonical repo/source links, sibling package install-status copy, and package truth contracts. This phase owns TRUTH-01, TRUTH-02, and TRUTH-03. It does not rewrite the full README/front-door documentation experience, add clean consumer adoption proof, change contributor CI topology, or promote `chimeway_admin` / `chimeway_inbox` to Hex packages.
</domain>

<decisions>
## Implementation Decisions

### Root Release Identity

- **D-01:** Preserve root-only `chimeway` release identity: root `@version`, `.release-please-manifest.json`, Release Please root package config, changelog release section, Hex package version, and HexDocs `source_ref: "v#{@version}"` stay aligned to package SemVer tags like `v1.0.0`, never planning labels like `v1.14`.
- **D-02:** Keep Release Please and publish workflows rooted on the single root package unless implementation discovers concrete drift inside the existing root-only release path. Do not add sibling publish lanes or planning-milestone release refs in Phase 78.

### Canonical Package Surface

- **D-03:** Normalize package-facing repository/source truth to `https://github.com/szTheory/chimeway` for root package metadata, HexDocs source URL, README package badges/links, changelog/source-facing package claims, and package truth contracts.
- **D-04:** Leave broader front-door docs rewrite and contributor documentation cleanup to Phases 79 and 80 unless a narrow edit is required to make Phase 78 package/release claims truthful.

### Sibling Package Status

- **D-05:** Keep `chimeway_admin` and `chimeway_inbox` as in-repo preview/path packages until a future explicit package-promotion milestone defines package metadata, SemVer policy, publish automation, and clean install smoke.
- **D-06:** Remove current Hex dependency claims for unpublished sibling packages and contract-test public copy so `{:chimeway_admin, "~> 1.0"}` or misleading current-published `chimeway_inbox` language cannot return.

### Truth Contracts

- **D-07:** Extend existing ExUnit truth anchors instead of adding a parallel shell checker: use `test/chimeway/release_gate_contract_test.exs` for package/release/source/artifact truth and `test/chimeway/doc_contract_test.exs` for public doc snippets that mention sibling package install status.
- **D-08:** Package artifact proof should build on the existing `mix hex.build --unpack` / `verify.parity` shape and assert the root package files whitelist and unpacked Hex behavior needed by TRUTH-01.

### Claude's Discretion

Downstream agents may choose the narrowest implementation shape that satisfies these decisions. Prefer contract tests that read real files and workflows directly, because this project already treats docs/release truth as executable contracts.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Scope and Requirements

- `.planning/ROADMAP.md` - Phase 78 goal, requirements, dependencies, and success criteria.
- `.planning/REQUIREMENTS.md` - TRUTH-01, TRUTH-02, TRUTH-03, and out-of-scope package-promotion constraints.
- `.planning/STATE.md` - Active v1.14 milestone state and Phase 77 accumulated decisions.

### Package Model and Prior Decisions

- `.planning/phases/77-truth-baseline-and-package-model-decision/77-CONTEXT.md` - Locked package model, tag namespace, truth ownership, and baseline drift decisions.
- `.planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md` - Evidence-backed package/release drift inventory and downstream Phase 78 handoff.
- `.planning/phases/77-truth-baseline-and-package-model-decision/77-02-SUMMARY.md` - Validation evidence and next-phase readiness for Phase 78.

### Root Package and Release Surfaces

- `mix.exs` - Root package version, package file whitelist, package links, HexDocs extras, `source_ref`, `source_url`, and verify aliases.
- `.release-please-manifest.json` - Release Please root package manifest version.
- `release-please-config.json` - Single root package Release Please config and `include-v-in-tag` rule.
- `CHANGELOG.md` - Package SemVer release section and canonical commit links.
- `.github/workflows/release.yml` - Automated Release Please, CI gate replay, root Hex publish, and post-publish proof path.
- `.github/workflows/publish-hex.yml` - Manual recovery publish path, ref validation, root version check, and root Hex publish path.

### Public Package Copy

- `README.md` - Root package install guidance and package-facing badge/link truth.
- `guides/introduction/admin-console-integration.md` - Current admin package dependency copy that must reflect preview/path status.
- `guides/introduction/inbox-integration.md` - Current inbox package path dependency and future-published-status copy.
- `chimeway_admin/mix.exs` - Sibling preview/path package state and lack of published package metadata.
- `chimeway_inbox/mix.exs` - Sibling preview/path package state and lack of published package metadata.

### Contract Anchors

- `test/chimeway/release_gate_contract_test.exs` - Existing release, manifest, workflow, gate, and maintainer truth contracts to extend.
- `test/chimeway/doc_contract_test.exs` - Existing README/guide/version/HexDocs contract tests to extend for sibling install-status truth.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `test/chimeway/release_gate_contract_test.exs` already parses `mix.exs`, `.release-please-manifest.json`, CI workflows, release workflows, publish recovery workflow, and maintainer docs. It is the right home for root package metadata, release ref, source URL, package whitelist, and unpacked package truth.
- `test/chimeway/doc_contract_test.exs` already validates README/install/golden-path version constraints, HexDocs extras, admin guide content, and inbox guide content. It is the right home for forbidding unpublished sibling Hex dependency claims.
- `mix.exs` already has `verify.parity` using `mix hex.build --unpack --output /tmp/chimeway_verify`; planners can extend or reuse this shape for root artifact proof.

### Established Patterns

- Release and docs truth is enforced through ExUnit contracts that read project files directly and run under `mix ci.verify_gates`.
- Version truth currently flows from root `@version "1.0.0"` and `.release-please-manifest.json` `{ ".": "1.0.0" }`.
- Release Please is configured for only `packages["."]` with `include-v-in-tag: true`, producing root package tags such as `v1.0.0`.
- `chimeway_admin` and `chimeway_inbox` are sibling Mix projects at version `0.1.0` with `{:chimeway, path: ".."}` and no package/docs metadata.

### Integration Points

- Root metadata drift currently appears in `mix.exs` package/docs URLs and the README CI badge URL.
- Sibling install-status drift currently appears in `guides/introduction/admin-console-integration.md` as a published Hex dependency claim for `chimeway_admin`; inbox copy already uses a path dependency but needs a contract guard around future-Hex wording.
- Changelog links already use `https://github.com/szTheory/chimeway`; keep changelog release anchors as package SemVer, not planning milestone labels.
</code_context>

<specifics>
## Specific Ideas

- Prefer the canonical repo URL `https://github.com/szTheory/chimeway` everywhere Phase 78 touches package-facing source links.
- Package truth tests should fail if `https://github.com/jonlunsford/chimeway` appears in package-facing metadata or package-facing README/badge surfaces owned by Phase 78.
- Sibling status copy should use explicit language such as "in-repo preview/path package" and "not published on Hex yet" until a future promotion phase changes the package model.
</specifics>

<deferred>
## Deferred Ideas

- Full README/front-door decision-page rewrite, first-hop docs IA cleanup, accurate adoption snippets beyond package truth, stub guide demotion, and clean consumer/adoption proof belong to Phase 79.
- Fast `pr-gate`, required-check topology, local CI reproducibility, cache improvements, `CONTRIBUTING.md` canonical clone URL, and broader maintainer/contributor gate docs belong to Phase 80.
- Publishing `chimeway_admin` or `chimeway_inbox` as Hex packages belongs to a future explicit package-promotion milestone, not Phase 78.
</deferred>

---

*Phase: 78-release-and-package-truth*
*Context gathered: 2026-07-03*

# Phase 77: Truth Baseline and Package Model Decision - Context

**Gathered:** 2026-07-02 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 77 records the root-only package model and separates planning milestone identifiers from package release tags. It also baselines public truth drift across README, guides, package metadata, release manifests, changelog, workflows, and maintainer docs before broad edits. Phase 77 does not perform the broad public edits; Phase 78 delivers package/release truth, Phase 79 delivers front-door docs truth and adoption proof, and Phase 80 delivers CI/DX topology changes.
</domain>

<decisions>
## Implementation Decisions

### Package Model

- **D-01:** Treat `chimeway` as the only Hex-published package for v1.14.
- **D-02:** Treat `chimeway_admin` and `chimeway_inbox` as in-repo preview/path packages until a later explicit package-promotion milestone defines their package metadata, SemVer policy, publish automation, and clean install smoke.
- **D-03:** Phase 77 should record sibling package install status as an input for Phase 78, not promote or publish sibling packages itself.

### Tag Namespace

- **D-04:** Keep package release tags as Release Please root-package SemVer tags, for example `v1.0.0`.
- **D-05:** Treat planning milestone labels such as `v1.14` as planning identifiers only; they must not be used as package release tags, HexDocs source refs, publish refs, changelog release anchors, or GitHub release names.
- **D-06:** Root package release identity remains the version in root `mix.exs`, `.release-please-manifest.json`, Release Please output, Hex package version, and `mix.exs` docs `source_ref: "v#{@version}"`.

### Truth Ownership

- **D-07:** Phase 78 owns root package/release truth: package metadata, package files, release manifest, changelog, HexDocs source refs, README install constraints, canonical repo/source links, sibling package install-status copy, and package truth contracts.
- **D-08:** Phase 79 owns public front-door docs truth: README decision-page rewrite, first-hop guide IA, accurate adoption snippets, stub guide completion/demotion, and clean consumer or unpacked-Hex smoke path.
- **D-09:** Phase 80 owns CI truth: fast always-running `pr-gate`, full release/publish `ci-gate`, required-check topology, local reproducibility, and cache coverage.
- **D-10:** Preserve full `ci-gate` as the release, publish, automerge, recovery, and mainline confidence source while Phase 80 adds contributor-facing speed.

### Baseline Drift

- **D-11:** Baseline drift must explicitly include root package repository/source URL mismatch: local git remote and public GitHub are `https://github.com/szTheory/chimeway`, while current root package/docs metadata and some docs point to `https://github.com/jonlunsford/chimeway`.
- **D-12:** Baseline drift must explicitly include sibling package install-status risk: public docs must stop implying `chimeway_admin` or `chimeway_inbox` are installable Hex dependencies until they are actually promoted and published.
- **D-13:** Baseline drift must explicitly include package/docs/tag truth: `README.md`, `CHANGELOG.md`, `.release-please-manifest.json`, `release-please-config.json`, `.github/workflows/release.yml`, `.github/workflows/publish-hex.yml`, `mix.exs`, and release-gate contracts must agree on the same root package state.

### Claude's Discretion

Downstream agents may choose the narrowest implementation artifact for Phase 77: ADR, decision record, or equivalent planning artifact. The artifact must name the package model, tag namespace, root package release rule, delivery owners for package/docs/CI truth, and baseline drift inventory with evidence.

### Folded Todos

None.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Scope and Requirements

- `.planning/ROADMAP.md` — Phase 77 boundary, Phase 78-80 ownership split, and v1.14 milestone goal.
- `.planning/REQUIREMENTS.md` — TRUTH-04 and v1.14 out-of-scope package-promotion constraints.
- `.planning/PROJECT.md` — Project constraints for release truth, contributor DX, local-first explainability, and current milestone posture.
- `.planning/STATE.md` — Current milestone state and accumulated decisions.

### Package and Release Truth

- `mix.exs` — Root package version, package files, package links, docs `source_ref`, docs `source_url`, and existing verify aliases.
- `.release-please-manifest.json` — Root package Release Please version source.
- `release-please-config.json` — Single root package Release Please configuration and `include-v-in-tag` behavior.
- `CHANGELOG.md` — Current changelog release/source links to baseline for canonical repo drift.
- `.github/workflows/release.yml` — Release Please tag and Hex publish path.
- `.github/workflows/publish-hex.yml` — Manual recovery publish path and release ref validation.
- `test/chimeway/release_gate_contract_test.exs` — Existing release, manifest, CI, and publish gate contract coverage.
- `MAINTAINING.md` — Maintainer-facing release and gate instructions that must agree with package truth.

### Public Docs and Sibling Package Status

- `README.md` — Public first-hop install, badges, HexDocs, and repository claims.
- `CONTRIBUTING.md` — Contributor clone/source URL claims.
- `guides/introduction/admin-console-integration.md` — Existing `chimeway_admin` install-status language to baseline.
- `guides/introduction/inbox-integration.md` — Existing `chimeway_inbox` install-status language to baseline.
- `chimeway_admin/mix.exs` — Sibling preview/path package metadata state.
- `chimeway_inbox/mix.exs` — Sibling preview/path package metadata state.

### CI Truth

- `.github/workflows/ci.yml` — Current full `ci-gate` topology and verify lanes before Phase 80 changes.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `test/chimeway/release_gate_contract_test.exs`: Existing contract-test surface for manifest/version parity, release workflow behavior, publish gating, and CI lane parity. Phase 77 should use it as the anchor for later package truth contracts instead of inventing a parallel mechanism.
- `mix ci.verify_gates`: Existing local release-doc gate that composes doc contracts and release gate contracts.
- `.release-please-manifest.json` and `release-please-config.json`: Existing single-package Release Please source of truth for root package release identity.

### Established Patterns

- Release automation is root-package only: Release Please packages contains only `"."`, root `mix.exs` owns package/docs metadata, and publish workflows run `mix hex.publish` from the root.
- Verification parity is product behavior: named `mix verify.*` and `mix ci.*` aliases are mirrored by CI jobs and release-gate tests.
- Optional surfaces are path packages in this repo: `chimeway_admin` and `chimeway_inbox` depend on `{:chimeway, path: ".."}` and lack Hex package/docs metadata.

### Integration Points

- Phase 78 should connect to `mix.exs`, release manifests, changelog, README install constraints, package whitelist, HexDocs source refs, and release-gate contracts.
- Phase 79 should connect to README, first-hop guides, doc contracts, and clean consumer or unpacked-Hex smoke proof.
- Phase 80 should connect to `.github/workflows/ci.yml`, local scripts or Mix tasks, required-check topology, gate contracts, and maintainer/contributor docs.

### External Public Truth Checked

- `https://hex.pm/api/packages/chimeway` returned 200 on 2026-07-02 with latest version `1.0.0`, HexDocs URL `https://chimeway.hexdocs.pm/`, and package link `https://github.com/jonlunsford/chimeway`.
- `https://hex.pm/api/packages/chimeway_admin` returned 404 on 2026-07-02.
- `https://hex.pm/api/packages/chimeway_inbox` returned 404 on 2026-07-02.
- `https://github.com/szTheory/chimeway` returned 200 on 2026-07-02 and matches the local git remote.
- `https://github.com/jonlunsford/chimeway` returned 404 on 2026-07-02.
</code_context>

<specifics>
## Specific Ideas

- Use a short decision record title such as `Package Model and Release Namespace`.
- State the root package release rule directly: root `chimeway` package version drives Hex release, GitHub release/tag, HexDocs source ref, changelog release, and publish recovery refs.
- State the planning namespace rule directly: planning milestones are project management labels and never package release refs.
- Include a baseline truth table with columns for surface, current claim, expected truth owner, downstream phase, and contract evidence.
</specifics>

<deferred>
## Deferred Ideas

- Publishing `chimeway_admin` or `chimeway_inbox` as independent Hex packages is deferred to a future explicit package-promotion milestone.
- Changing runtime package architecture, admin UI behavior, inbox PubSub polish, or tenant storage behavior is out of scope for Phase 77.

### Reviewed Todos (not folded)

None.
</deferred>

---

*Phase: 77-truth-baseline-and-package-model-decision*
*Context gathered: 2026-07-02*

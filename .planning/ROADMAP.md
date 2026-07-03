# Roadmap: Chimeway

## Milestones

- ✅ **v1.0** — [Archived roadmap](.planning/milestones/v1.0-ROADMAP.md) (shipped 2026-04-25)
- ✅ **v1.1** — [Archived roadmap](.planning/milestones/v1.1-ROADMAP.md) (shipped 2026-04-27)
- ✅ **v1.2** — [Archived roadmap](.planning/milestones/v1.2-ROADMAP.md) (shipped 2026-04-29)
- ✅ **v1.3** — [Archived roadmap](.planning/milestones/v1.3-ROADMAP.md) (shipped 2026-04-30)
- ✅ **v1.4** — [Archived roadmap](.planning/milestones/v1.4-ROADMAP.md) · [Audit](.planning/milestones/v1.4-MILESTONE-AUDIT.md) (shipped 2026-05-08, closed 2026-05-28)
- ✅ **v1.5** — [Archived roadmap](.planning/milestones/v1.5-ROADMAP.md) · [Audit](.planning/milestones/v1.5-MILESTONE-AUDIT.md) (shipped 2026-05-29)
- ✅ **v1.6** — [Archived roadmap](.planning/milestones/v1.6-ROADMAP.md) · [Audit](.planning/milestones/v1.6-MILESTONE-AUDIT.md) (shipped 2026-05-29)
- ✅ **v1.7** — [Archived roadmap](.planning/milestones/v1.7-ROADMAP.md) · [Audit](.planning/milestones/v1.7-MILESTONE-AUDIT.md) (shipped 2026-05-29)
- ✅ **v1.8** — [Archived roadmap](.planning/milestones/v1.8-ROADMAP.md) · [Audit](.planning/milestones/v1.8-MILESTONE-AUDIT.md) (shipped 2026-05-30)
- ✅ **v1.9** — [Archived roadmap](.planning/milestones/v1.9-ROADMAP.md) · [Audit](.planning/milestones/v1.9-MILESTONE-AUDIT.md) (shipped 2026-05-30)
- ✅ **v1.10 Ecosystem Completions** — [Archived roadmap](.planning/milestones/v1.10-ROADMAP.md) · [Audit](.planning/milestones/v1.10-MILESTONE-AUDIT.md) (shipped 2026-06-04)
- ✅ **v1.11 Operator Console Polish & Hardening** — [Archived roadmap](.planning/milestones/v1.11-ROADMAP.md) · [Audit](.planning/milestones/v1.11-MILESTONE-AUDIT.md) (shipped 2026-06-04)
- ✅ **v1.13 Storage Isolation and Upgrade Path** — [Archived roadmap](.planning/milestones/v1.13-ROADMAP.md) · [Audit](.planning/milestones/v1.13-MILESTONE-AUDIT.md) (shipped 2026-07-02)
- **v1.14 Public Truth and Verification Architecture** — Active milestone

## Active Milestone

**v1.14 Public Truth and Verification Architecture**

**Goal:** Make every public adoption claim explainable and reproducible across package metadata, README/docs, and CI/release verification while preserving full release confidence.

**Requirements:** [REQUIREMENTS.md](.planning/REQUIREMENTS.md)

**Research:** [v1.14 research summary](.planning/research/v1.14-public-truth-and-verification-architecture/SUMMARY.md)

## Phases

### v1.14 Public Truth and Verification Architecture

- [ ] **Phase 77: Truth Baseline and Package Model Decision** (2/2 plans)
  - Record the root-only package model and milestone-vs-package tag namespace. Sibling package install status is identified here as input, then delivered in Phase 78.
  - Baseline public truth drift across README, guides, mix metadata, release manifests, changelog, workflows, and maintainer docs before broad edits.
  - Requirements: TRUTH-04
  - Success criteria: A decision record or equivalent planning artifact names the package model, tag namespace, root package release rule, and delivery owners for package/docs/CI truth.

- [ ] **Phase 78: Release and Package Truth** (0/4 plans)
  - Align root package metadata, release manifest, changelog, HexDocs source refs, README install constraints, package files whitelist, and canonical repo/source links.
  - Make `chimeway_admin` and `chimeway_inbox` install status explicit as in-repo preview/path packages unless separately promoted.
  - Add package truth contracts and `mix hex.build --unpack` proof for the root package artifact.
  - Requirements: TRUTH-01, TRUTH-02, TRUTH-03
  - Success criteria: Package/release metadata and public install claims agree, unpublished sibling packages are no longer advertised as Hex releases, and automated package truth checks fail on drift.

- [ ] **Phase 79: Front Door and Docs IA** (0/4 plans)
  - Rewrite README as the public decision page for local-first ownership, explainability, host boundaries, non-goals, optional surfaces, and install flow.
  - Add or update snippets showing stable notification keys, `tenant_id`, `idempotency_key`, storage prefix configuration, and trace/explainability proof.
  - Complete, demote, or delink stub guides so first-hop docs do not route adopters into unfinished material.
  - Add a clean consumer or unpacked-Hex smoke path that follows the final public docs rather than repo-internal assumptions.
  - Requirements: DOCS-14, DOCS-15, DOCS-16, DOCS-17, ADPT-01
  - Success criteria: A new adopter can read the first-hop docs, understand when to use or avoid Chimeway, copy accurate snippets, and verify a trigger-to-explainability path from the public package/docs story.

- [ ] **Phase 80: Verification Architecture and CI/DX** (0/5 plans)
  - Add an always-running fast `pr-gate` while preserving the full `ci-gate` for release, publish, automerge, recovery, and mainline validation.
  - Avoid required-check pending traps, add nested package/demo/npm/Playwright cache coverage, and make complex CI behavior locally reproducible through scripts or Mix tasks.
  - Update `CONTRIBUTING.md`, `MAINTAINING.md`, release contracts, and gate docs so local and CI verification language agrees.
  - Requirements: CI-01, CI-02, CI-03, CI-04, CI-05
  - Success criteria: Contributor PRs have a fast required aggregate, release/publish flows still depend on the full gate, path-filtered skips cannot strand required checks, and complex gate behavior can be run locally.

### Phase 77: Truth Baseline and Package Model Decision

**Goal:** Record the root-only package model and milestone-vs-package tag namespace, identify sibling package install status as Phase 78 input, and baseline public truth drift across docs, package metadata, release manifests, changelog, workflows, and maintainer docs before broad edits.

**Requirements:** TRUTH-04

**Plans:** 2/2 plans ready

Plans:
**Wave 1**

- [x] 77-01-PLAN.md — Package model, namespace rule, root release rule, and owner map

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 77-02-PLAN.md — Evidence-backed drift inventory and validation handoff

**Success Criteria**:

1. A decision record or equivalent planning artifact names the package model.
2. The artifact names the tag namespace and root package release rule.
3. The artifact names delivery owners for package, docs, and CI truth.
4. The baseline inventory captures README, guides, mix metadata, release manifests, changelog, workflows, and maintainer docs drift.

### Phase 78: Release and Package Truth

**Goal:** Align root package metadata, release manifest, changelog, HexDocs source refs, README install constraints, package files whitelist, canonical repo/source links, sibling package install-status copy, and package truth contracts.

**Requirements:** TRUTH-01, TRUTH-02, TRUTH-03

**Depends on:** Phase 77

**Success Criteria**:

1. Package/release metadata and public install claims agree.
2. Unpublished sibling packages are no longer advertised as Hex releases.
3. Automated package truth checks fail on package, release, install, source-ref, or sibling-status drift.
4. Root package artifact proof covers package files and unpacked Hex behavior.

### Phase 79: Front Door and Docs IA

**Goal:** Rewrite the public first-hop docs so adopters can understand Chimeway's local-first ownership model, explainability contract, host boundaries, non-goals, optional surfaces, install flow, and traceable trigger-to-explainability path.

**Requirements:** DOCS-14, DOCS-15, DOCS-16, DOCS-17, ADPT-01

**Depends on:** Phase 78

**Success Criteria**:

1. A new adopter can read the first-hop docs and understand when to use or avoid Chimeway.
2. Public snippets for stable notification keys, `tenant_id`, `idempotency_key`, storage prefix configuration, and trace/explainability proof are accurate.
3. Stub guides are completed, demoted, or delinked so first-hop docs do not route adopters into unfinished material.
4. A clean consumer or unpacked-Hex smoke path follows the final public package/docs story.

### Phase 80: Verification Architecture and CI/DX

**Goal:** Add an always-running fast `pr-gate` while preserving full `ci-gate` release confidence, avoid required-check pending traps, improve cache coverage, make complex CI behavior locally reproducible, and align contributor/maintainer gate docs.

**Requirements:** CI-01, CI-02, CI-03, CI-04, CI-05

**Depends on:** Phase 79

**Success Criteria**:

1. Contributor PRs have a fast required aggregate.
2. Release, publish, automerge, recovery, and mainline flows still depend on the full gate.
3. Path-filtered skips cannot strand required checks.
4. Nested package, demo, npm, and Playwright cache coverage is represented.
5. Complex gate behavior can be run locally and is documented for contributors and maintainers.

<details>
<summary>✅ v1.13 Storage Isolation and Upgrade Path (Phases 73-76.1) — SHIPPED 2026-07-02</summary>

- [x] Phase 73: Storage Prefix Contract (3/3 plans) — completed 2026-06-30
- [x] Phase 74: Prefixed Migration Generator (10/10 plans) — completed 2026-06-30
- [x] Phase 75: Runtime Prefix Propagation (8/8 plans) — completed 2026-07-01
- [x] Phase 76: Prefix Docs, Demo, and Gates (3/3 plans) — completed 2026-07-02
- [x] Phase 76.1: Close gap: GATE-01 - generated prefixed migration runtime proof (1/1 plan) — completed 2026-07-02

</details>

## Progress

| Milestone | Phases | Plans | Requirements | Status | Shipped |
|-----------|--------|-------|--------------|--------|---------|
| v1.14 Public Truth and Verification Architecture | 77-80 | 0/15 | 0/14 | Active | — |
| v1.13 Storage Isolation and Upgrade Path | 73-76.1 | 25/25 | 20/20 | Complete | 2026-07-02 |
| v1.11 Operator Console Polish & Hardening | 68-72 | 12/12 | 18/18 | Complete | 2026-06-04 |
| v1.10 Ecosystem Completions | 63-67 | 13/13 | 8/8 | Complete | 2026-06-04 |

---
*Roadmap updated: 2026-07-02 — v1.14 milestone initialized*

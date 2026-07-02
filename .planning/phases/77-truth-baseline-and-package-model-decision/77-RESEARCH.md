# Phase 77: Truth Baseline and Package Model Decision - Research

**Researched:** 2026-07-02
**Domain:** Elixir package/release truth, Release Please tag namespace, Hex/HexDocs metadata, documentation-contract planning
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

Provenance for this copied constraint block: [VERIFIED: .planning/phases/77-truth-baseline-and-package-model-decision/77-CONTEXT.md]

### Locked Decisions

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

### the agent's Discretion

Downstream agents may choose the narrowest implementation artifact for Phase 77: ADR, decision record, or equivalent planning artifact. The artifact must name the package model, tag namespace, root package release rule, delivery owners for package/docs/CI truth, and baseline drift inventory with evidence.

### Deferred Ideas (OUT OF SCOPE)

- Publishing `chimeway_admin` or `chimeway_inbox` as independent Hex packages is deferred to a future explicit package-promotion milestone.
- Changing runtime package architecture, admin UI behavior, inbox PubSub polish, or tenant storage behavior is out of scope for Phase 77.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRUTH-04 | Planning milestone identifiers and package release tags are separated so planning version `v1.14` cannot be mistaken for a Hex package release. [VERIFIED: .planning/REQUIREMENTS.md] | Use one phase-local decision record that states package tags are root SemVer tags like `v1.0.0`, planning labels are not release refs, and root release identity is `mix.exs` `@version` plus Release Please/Hex/HexDocs parity. [VERIFIED: .planning/phases/77-truth-baseline-and-package-model-decision/77-CONTEXT.md] |
</phase_requirements>

## Summary

Phase 77 should produce a narrow phase-local decision record plus evidence-backed baseline inventory, not public docs or metadata edits. [VERIFIED: .planning/ROADMAP.md] The planner should treat `chimeway` as the only v1.14 Hex package, record `chimeway_admin` and `chimeway_inbox` as in-repo preview/path packages, and hand all public package, docs, and CI corrections to Phases 78, 79, and 80 respectively. [VERIFIED: .planning/phases/77-truth-baseline-and-package-model-decision/77-CONTEXT.md]

The current root release model is single-package Release Please: `.release-please-manifest.json` contains only `"."`, `release-please-config.json` configures `packages["."]` with `include-v-in-tag: true`, and release/publish workflows run root `mix hex.publish`. [VERIFIED: codebase grep] Release Please action docs say manifest config is the v4 default unless `release-type` is specified, and advanced options such as `include-v-in-tag` belong in the manifest configuration. [CITED: https://github.com/googleapis/release-please-action]

The actionable drift baseline is already visible: Hex has `chimeway` `1.0.0` with docs and an old GitHub link, while live Hex lookups for `chimeway_admin` and `chimeway_inbox` return no package. [VERIFIED: curl Hex API 2026-07-02] The local git remote and reachable public repo are `https://github.com/szTheory/chimeway`, while `https://github.com/jonlunsford/chimeway` returns 404 and still appears in README badge URLs, CONTRIBUTING clone copy, root `mix.exs` package/docs metadata, and some guide links. [VERIFIED: git remote/curl/rg 2026-07-02]

**Primary recommendation:** Plan Phase 77 as a phase-local `77-PACKAGE-MODEL-DECISION.md` (or equivalent) containing the namespace decision, owner map, and drift table; do not edit README, package metadata, release workflows, or maintainer docs in this phase. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/phases/77-truth-baseline-and-package-model-decision/77-CONTEXT.md]

## Project Constraints (from AGENTS.md)

- Chimeway is an open-source embedded notification layer for Elixir and Phoenix apps; host applications own data, policies, and delivery history. [VERIFIED: AGENTS.md]
- Every notification decision must remain explainable: why sent, failed, suppressed, or deferred. [VERIFIED: AGENTS.md]
- Project stack is Elixir 1.17+/OTP 26+, Ecto 3.x/PostgreSQL 15+, Phoenix 1.7/1.8 optional surfaces, Oban 2.x optional async dispatch, and Swoosh 1.x email adapter seam. [VERIFIED: AGENTS.md]
- Durable identity must be stable `notification_key` plus version, not module names. [VERIFIED: AGENTS.md]
- Lifecycle spine must remain durable across event -> notification -> delivery -> attempt. [VERIFIED: AGENTS.md]
- Idempotency and suppression reasons are first-class product behavior. [VERIFIED: AGENTS.md]
- Adapters should stay replaceable through explicit behaviours and contract tests. [VERIFIED: AGENTS.md]
- Host ownership boundaries include auth, tenancy, URL generation, and correlation IDs. [VERIFIED: AGENTS.md]
- Named `mix verify.*` and `mix ci.*` entrypoints must be maintained with CI/local parity. [VERIFIED: AGENTS.md]
- Sensitive payload fields must not leak in telemetry or operator surfaces. [VERIFIED: AGENTS.md]
- Docs/release-gate phases 57, 60, and 62 used `mix ci.verify_gates` plus ecosystem `verify.*` CI jobs as acceptance; Phase 77 is similar in surface but has its own roadmap success criteria. [VERIFIED: AGENTS.md] [VERIFIED: .planning/ROADMAP.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Package model decision | Planning / Documentation | Release tooling | The decision lives in phase-local planning artifacts; Release Please and Hex are evidence, not implementation targets in Phase 77. [VERIFIED: .planning/ROADMAP.md] |
| Tag namespace separation | Release tooling | Planning / Documentation | Package tags are produced by Release Please from root package version; planning labels stay in GSD roadmap/state only. [VERIFIED: release-please-config.json] [VERIFIED: .planning/STATE.md] |
| Root package release identity | Release tooling | Hex / HexDocs | Root `mix.exs`, Release Please manifest, Release Please output, Hex version, and ExDoc `source_ref` define the package release identity. [VERIFIED: mix.exs] [VERIFIED: .release-please-manifest.json] |
| Sibling package install-status baseline | Planning / Documentation | Hex API | Phase 77 records current sibling status for Phase 78; it does not publish sibling packages. [VERIFIED: .planning/phases/77-truth-baseline-and-package-model-decision/77-CONTEXT.md] [VERIFIED: curl Hex API 2026-07-02] |
| Public truth drift inventory | Planning / Documentation | Docs/release tests | The baseline belongs in a decision record; later phases edit public docs and contracts. [VERIFIED: .planning/ROADMAP.md] |
| CI truth ownership handoff | CI / GitHub Actions | Maintainer docs | Phase 80 owns `pr-gate`, `ci-gate`, required-check topology, local reproducibility, and caches. [VERIFIED: .planning/ROADMAP.md] |

## Standard Stack

### Core

| Library / Surface | Version | Purpose | Why Standard |
|-------------------|---------|---------|--------------|
| Elixir / Mix | Local: Elixir 1.19.5, Mix 1.19.5; project declares `~> 1.17`; CI uses Elixir 1.17. [VERIFIED: elixir --version] [VERIFIED: mix.exs] [VERIFIED: .github/workflows/ci.yml] | Read Mix project metadata, run contract tests, and verify aliases. | This repository is Mix-first and release/package truth is rooted in `mix.exs`. [VERIFIED: mix.exs] |
| Hex / HexDocs | Local Hex 2.5.0; public package `chimeway` latest `1.0.0`. [VERIFIED: mix hex --version] [VERIFIED: curl Hex API 2026-07-02] | Verify package existence, published version, package links, docs URL, and sibling package absence. | Hex is the authoritative package registry for Elixir package truth. [CITED: https://hex.pm/docs/publish] |
| Release Please | Configured via `googleapis/release-please-action` with root manifest files. [VERIFIED: .github/workflows/release.yml] | Owns root release PRs, GitHub Releases, SemVer tags, changelog/version updates. | Existing release automation already uses Release Please manifest files and root publish flow. [VERIFIED: release-please-config.json] |
| ExUnit contract tests | `test/chimeway/doc_contract_test.exs` and `test/chimeway/release_gate_contract_test.exs`. [VERIFIED: codebase grep] | Guard documentation and release-gate parity. | Existing project pattern keeps docs/release truth testable through `mix ci.verify_gates`. [VERIFIED: mix.exs] |
| Phase-local Markdown decision artifact | Recommend `.planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md`. [VERIFIED: .planning/phases/77-truth-baseline-and-package-model-decision/77-CONTEXT.md] | Record package model, tag namespace, root release rule, owner map, and baseline drift. | Phase 77 success criteria require a decision record or equivalent artifact, not public metadata changes. [VERIFIED: .planning/ROADMAP.md] |

### Supporting

| Library / Surface | Version | Purpose | When to Use |
|-------------------|---------|---------|-------------|
| GitHub Actions | Workflows in `.github/workflows/*.yml`. [VERIFIED: codebase grep] | Baseline `ci-gate`, release, recovery publish, and automerge assumptions. | Read only in Phase 77; Phase 80 owns topology changes. [VERIFIED: .planning/ROADMAP.md] |
| GitHub CLI `gh` | 2.95.0 local. [VERIFIED: gh --version] | Optional maintainer workflow inspection. | Not required for the Phase 77 artifact unless planner wants live workflow/release checks. [VERIFIED: environment probe] |
| `curl` + `jq` | curl 8.7.1, jq 1.7.1 local. [VERIFIED: curl --version] [VERIFIED: jq --version] | Verify live Hex/GitHub status and inspect JSON. | Use for baseline evidence; avoid scraping HTML when JSON APIs exist. [VERIFIED: curl Hex API 2026-07-02] |
| `rg` | Available in this session by successful usage. [VERIFIED: codebase grep] | Find public truth drift across docs and metadata surfaces. | Use for baseline inventory and acceptance checks. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Phase-local decision record | Root `docs/adr` entry | Root public docs edits increase Phase 77 blast radius; phase-local artifact satisfies roadmap and can be promoted later if needed. [VERIFIED: .planning/ROADMAP.md] |
| Hex API checks | Hex package HTML scraping | Hex API gives structured package status; HTML scraping is more brittle. [VERIFIED: curl Hex API 2026-07-02] |
| Extend existing ExUnit contract tests | New shell script truth checker | Existing release/doc contracts already parse repo files and are wired into `mix ci.verify_gates`; a script would add a second truth mechanism. [VERIFIED: test/chimeway/release_gate_contract_test.exs] [VERIFIED: mix.exs] |

**Installation:**

```bash
# No new packages for Phase 77.
# Use existing project dependencies and local tooling.
mix deps.get
```

**Version verification:** Existing tool versions were checked with `elixir --version`, `mix --version`, `mix hex --version`, `node --version`, `npm --version`, `git --version`, `curl --version`, `jq --version`, and `gh --version`. [VERIFIED: environment probe]

## Package Legitimacy Audit

Phase 77 should not install external packages. [VERIFIED: .planning/ROADMAP.md] The Package Legitimacy Gate is not applicable because the recommended implementation uses existing project dependencies and phase-local Markdown. [VERIFIED: mix.exs]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| None | N/A | N/A | N/A | N/A | N/A | No install recommended. [VERIFIED: research scope] |

**Packages removed due to [SLOP] verdict:** none. [VERIFIED: no new package recommendation]
**Packages flagged as suspicious [SUS]:** none. [VERIFIED: no new package recommendation]

## Architecture Patterns

### System Architecture Diagram

```text
Phase 77 locked decisions + roadmap success criteria
  -> evidence collection
       -> local truth surfaces:
          mix.exs, Release Please manifest/config, workflows,
          README/guides/changelog/maintainer docs, contract tests
       -> live public truth:
          Hex API, GitHub repo URLs, HexDocs URL
  -> phase-local decision record / baseline inventory
       -> root package model and tag namespace locked for TRUTH-04
       -> drift table with owner phase:
          Phase 78 package/release truth
          Phase 79 front-door docs/adoption proof
          Phase 80 CI/DX truth
  -> planner tasks
       -> no broad public edits in Phase 77
       -> downstream phases receive evidence-backed inputs
```

### Recommended Project Structure

```text
.planning/phases/77-truth-baseline-and-package-model-decision/
+-- 77-CONTEXT.md                  # locked decisions from discuss phase
+-- 77-RESEARCH.md                 # this research artifact
+-- 77-PACKAGE-MODEL-DECISION.md   # recommended Phase 77 implementation artifact
```

### Pattern 1: Phase-Local Decision Record

**What:** Create one phase-local artifact that records package model, tag namespace, root release rule, truth ownership, and baseline drift with evidence. [VERIFIED: .planning/ROADMAP.md]  
**When to use:** Use when the phase success criteria are decision/baseline oriented and later phases own broad public edits. [VERIFIED: .planning/ROADMAP.md]  
**Example:**

```markdown
<!-- Source: .planning/phases/77-truth-baseline-and-package-model-decision/77-CONTEXT.md -->
# Package Model and Release Namespace

## Decision
- Hex package model: root package `chimeway` only for v1.14.
- Package release namespace: root SemVer tags such as `v1.0.0`.
- Planning namespace: milestone labels such as `v1.14` are planning identifiers only.

## Baseline Drift
| Surface | Current Claim | Expected Owner | Downstream Phase | Evidence |
|---------|---------------|----------------|------------------|----------|
```

### Pattern 2: Evidence-First Drift Table

**What:** Record each drift item as surface, current claim, expected truth, downstream owner phase, and evidence command/source. [VERIFIED: .planning/phases/77-truth-baseline-and-package-model-decision/77-CONTEXT.md]  
**When to use:** Use for Phase 77 so Phase 78-80 tasks can be generated from an inventory instead of rediscovering drift. [VERIFIED: .planning/ROADMAP.md]  
**Example baseline rows:**

| Surface | Current Claim / State | Expected Truth | Owner |
|---------|-----------------------|----------------|-------|
| `mix.exs` package/docs links | `https://github.com/jonlunsford/chimeway` in `links` and `source_url`. [VERIFIED: mix.exs] | Canonical repo should be `https://github.com/szTheory/chimeway`. [VERIFIED: git remote/curl 2026-07-02] | Phase 78 |
| `README.md` CI badge | Badge and workflow link point to `jonlunsford/chimeway`. [VERIFIED: README.md] | Canonical repo should be `szTheory/chimeway`. [VERIFIED: git remote/curl 2026-07-02] | Phase 78 or 79, planner should choose based on package-vs-front-door split. |
| `guides/introduction/admin-console-integration.md` | Shows `{:chimeway_admin, "~> 1.0"}`. [VERIFIED: codebase grep] | Admin package is in-repo preview/path until promoted. [VERIFIED: chimeway_admin/mix.exs] [VERIFIED: curl Hex API 2026-07-02] | Phase 78 |
| `guides/introduction/inbox-integration.md` | Uses path dependency but includes future `~> 1.0` replacement copy. [VERIFIED: guides/introduction/inbox-integration.md] | Inbox package is in-repo preview/path until promoted. [VERIFIED: chimeway_inbox/mix.exs] [VERIFIED: curl Hex API 2026-07-02] | Phase 78 |

### Pattern 3: Existing Contract Test Anchor

**What:** Extend existing ExUnit contract tests in later phases instead of introducing a new release truth checker. [VERIFIED: test/chimeway/release_gate_contract_test.exs]  
**When to use:** Use in Phase 78 for package truth contracts and Phase 80 for CI topology contracts; Phase 77 should baseline the gap. [VERIFIED: .planning/ROADMAP.md]  
**Example:**

```elixir
# Source: test/chimeway/release_gate_contract_test.exs
test "manifest version matches mix.exs @version" do
  manifest_content = File.read!(@manifest)
  mix_exs = File.read!(@mix_exs)
  [_, manifest_version] = Regex.run(~r/"\."\s*:\s*"([^"]+)"/, manifest_content)

  assert Regex.match?(~r/@version\s+"#{Regex.escape(manifest_version)}"/, mix_exs)
end
```

### Anti-Patterns to Avoid

- **Broad public edits in Phase 77:** README, package metadata, changelog, workflows, and maintainer docs are downstream implementation surfaces, not this phase's deliverable. [VERIFIED: .planning/ROADMAP.md]
- **Using `v1.14` as a package release ref:** The phase requirement exists specifically to prevent planning labels from becoming package tags, HexDocs refs, publish refs, release anchors, or GitHub release names. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/phases/77-truth-baseline-and-package-model-decision/77-CONTEXT.md]
- **Treating sibling packages as Hex dependencies:** Live Hex lookups for `chimeway_admin` and `chimeway_inbox` return no package; docs must not imply they are installable from Hex until a future promotion milestone. [VERIFIED: curl Hex API 2026-07-02]
- **Inventing a parallel truth-checking script:** Existing ExUnit contracts and `mix ci.verify_gates` already form the local release/doc truth pattern. [VERIFIED: mix.exs] [VERIFIED: test/chimeway/release_gate_contract_test.exs]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Root package release versioning | Custom tag/version script | Existing Release Please manifest and root `mix.exs` version rule. [VERIFIED: release-please-config.json] | Release Please is already wired to open release PRs, create GitHub Releases/tags, and drive publish output. [VERIFIED: .github/workflows/release.yml] |
| Package existence checks | HTML scrapers for Hex pages | Hex API or `mix hex.info`. [VERIFIED: curl Hex API 2026-07-02] [VERIFIED: mix hex.info] | Registry JSON and Hex CLI produce structured current status; sibling package absence is directly observable. [VERIFIED: curl Hex API 2026-07-02] |
| Release truth contracts | New shell-only checker | Extend `test/chimeway/release_gate_contract_test.exs` in Phase 78/80. [VERIFIED: test/chimeway/release_gate_contract_test.exs] | Existing tests already parse manifest, workflows, maintainer docs, and CI lane parity. [VERIFIED: test/chimeway/release_gate_contract_test.exs] |
| Public docs truth contracts | Ad hoc manual grep only | Extend `test/chimeway/doc_contract_test.exs` in Phase 79 when docs are edited. [VERIFIED: test/chimeway/doc_contract_test.exs] | The existing contract already covers README install copy, guide extras ordering, and integration-guide required/forbidden strings. [VERIFIED: test/chimeway/doc_contract_test.exs] |

**Key insight:** Phase 77 should make the later edits safer by fixing the decision and inventory first; it should not partially repair public truth before the package/docs/CI owner phases can add contracts. [VERIFIED: .planning/ROADMAP.md]

## Common Pitfalls

### Pitfall 1: Namespace Bleed from Milestones to Packages

**What goes wrong:** `v1.14` appears as a release tag, HexDocs source ref, changelog release anchor, publish recovery ref, or GitHub release name. [VERIFIED: .planning/REQUIREMENTS.md]  
**Why it happens:** The roadmap milestone label uses version-shaped text, while the package also uses SemVer tags. [VERIFIED: .planning/ROADMAP.md]  
**How to avoid:** State the rule in the Phase 77 decision record and list current allowed package refs as `@version`, `.release-please-manifest.json`, Release Please output, Hex version, and ExDoc `source_ref: "v#{@version}"`. [VERIFIED: .planning/phases/77-truth-baseline-and-package-model-decision/77-CONTEXT.md]  
**Warning signs:** Any package/release surface contains `v1.14` before a real root package version `1.14.0` exists. [VERIFIED: .planning/REQUIREMENTS.md]

### Pitfall 2: Baseline Becomes Cleanup

**What goes wrong:** Phase 77 starts editing README, guides, `mix.exs`, release manifests, changelog, workflows, or maintainer docs. [VERIFIED: .planning/ROADMAP.md]  
**Why it happens:** The drift is obvious and easy to patch piecemeal. [VERIFIED: codebase grep]  
**How to avoid:** Put every drift row in the decision artifact with a downstream owner phase. [VERIFIED: .planning/phases/77-truth-baseline-and-package-model-decision/77-CONTEXT.md]  
**Warning signs:** A Phase 77 plan modifies public docs or release metadata outside `.planning/phases/77-*`. [VERIFIED: .planning/ROADMAP.md]

### Pitfall 3: Sibling Package Status Is Flattened

**What goes wrong:** `chimeway_admin` or `chimeway_inbox` is described as installable via Hex even though it is only an in-repo path package today. [VERIFIED: chimeway_admin/mix.exs] [VERIFIED: chimeway_inbox/mix.exs] [VERIFIED: curl Hex API 2026-07-02]  
**Why it happens:** The optional surfaces are real Mix projects with versions, but they lack Hex package/docs metadata and do not exist on Hex. [VERIFIED: chimeway_admin/mix.exs] [VERIFIED: chimeway_inbox/mix.exs] [VERIFIED: curl Hex API 2026-07-02]  
**How to avoid:** Record preview/path status now and make Phase 78 update package/install copy. [VERIFIED: .planning/ROADMAP.md]  
**Warning signs:** `{:chimeway_admin, "~> 1.0"}` or `{:chimeway_inbox, "~> 1.0"}` appears in public install snippets before a package-promotion milestone. [VERIFIED: guides/introduction/admin-console-integration.md] [VERIFIED: guides/introduction/inbox-integration.md]

### Pitfall 4: Assuming Existing Contracts Cover This Drift

**What goes wrong:** Planner assumes `mix ci.verify_gates` already fails on root repo URL mismatch or sibling package install-status mismatch. [VERIFIED: test/chimeway/release_gate_contract_test.exs] [VERIFIED: test/chimeway/doc_contract_test.exs]  
**Why it happens:** Existing contracts cover many docs/release invariants but not every v1.14 public truth requirement. [VERIFIED: codebase grep]  
**How to avoid:** Phase 77 should list contract gaps for Phase 78/79/80 rather than claiming they are already enforced. [VERIFIED: .planning/ROADMAP.md]  
**Warning signs:** A plan claims TRUTH-01/TRUTH-02/TRUTH-03 are done after only writing the Phase 77 decision record. [VERIFIED: .planning/REQUIREMENTS.md]

### Pitfall 5: Required-Check Topology Gets Changed Too Early

**What goes wrong:** Phase 77 starts changing `ci.yml` to address `pr-gate` or required-check behavior. [VERIFIED: .planning/ROADMAP.md]  
**Why it happens:** The current `ci-gate` is visible while researching release truth. [VERIFIED: .github/workflows/ci.yml]  
**How to avoid:** Baseline current `ci-gate` and leave topology changes to Phase 80. [VERIFIED: .planning/ROADMAP.md]  
**Warning signs:** Phase 77 plan includes workflow path filters or required-check changes. [VERIFIED: .planning/ROADMAP.md]

## Code Examples

Verified patterns from existing project sources:

### Release Gate File-Parsing Contract

```elixir
# Source: test/chimeway/release_gate_contract_test.exs
test "release.yml contains gate-ci-green and ci-gate poll", %{release_yml: release_yml} do
  assert String.contains?(release_yml, "gate-ci-green")
  assert String.contains?(release_yml, "ci-gate")
end
```

### HexDocs Extras Contract Pattern

```elixir
# Source: test/chimeway/doc_contract_test.exs
for guide <- @integration_guides do
  test "requires #{guide} in HexDocs extras", %{content: content} do
    assert String.contains?(content, unquote(guide)),
           "mix.exs HexDocs extras must include #{unquote(guide)}"
  end
end
```

### Live Public Package Status Probe

```bash
# Source: Hex public API checked 2026-07-02.
curl -fsS https://hex.pm/api/packages/chimeway
curl -fsS -o /tmp/chimeway_admin_hex.json -w "%{http_code}" https://hex.pm/api/packages/chimeway_admin
curl -fsS -o /tmp/chimeway_inbox_hex.json -w "%{http_code}" https://hex.pm/api/packages/chimeway_inbox
```

## Baseline Drift Inventory

| Surface | Current State | Expected Truth / Rule | Downstream Owner | Evidence |
|---------|---------------|-----------------------|------------------|----------|
| Root Hex package | `chimeway` latest version is `1.0.0`, has docs, and Hex package metadata link points to `https://github.com/jonlunsford/chimeway`. | Root package is the only v1.14 Hex package; metadata should align to canonical repo in Phase 78. | Phase 78 | [VERIFIED: curl Hex API 2026-07-02] |
| `mix.exs` | `@version "1.0.0"`, package files whitelist includes `lib priv guides CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs`, package/docs links point to `jonlunsford/chimeway`, and docs use `source_ref: "v#{@version}"`. | Keep root version/ref rule; correct repo/source links and package truth in Phase 78. | Phase 78 | [VERIFIED: mix.exs] |
| `.release-please-manifest.json` | Contains `{ ".": "1.0.0" }`. | Root-only Release Please manifest stays the release version source. | Phase 78 | [VERIFIED: .release-please-manifest.json] |
| `release-please-config.json` | Single `packages["."]` entry with `changelog-path: CHANGELOG.md` and `include-v-in-tag: true`. | Package tags remain root `vX.Y.Z`; do not introduce milestone tags. | Phase 77 records, Phase 78 preserves | [VERIFIED: release-please-config.json] [CITED: https://github.com/googleapis/release-please-action] |
| `.github/workflows/release.yml` | Release Please creates release output, checks out `tag_name`, verifies `@version`, runs `mix ci.verify_gates`, `mix ci.docs`, builds, publishes, and verifies Hex. | Preserve root publish flow; Phase 78 can strengthen package truth contracts. | Phase 78 | [VERIFIED: .github/workflows/release.yml] |
| `.github/workflows/publish-hex.yml` | Recovery accepts a `tag` or SHA plus `release_version`, verifies `@version`, gates on `ci-gate`, and publishes root `chimeway`. | Publish recovery refs must be package refs or SHAs, not planning labels. | Phase 78/80 | [VERIFIED: .github/workflows/publish-hex.yml] |
| `.github/workflows/ci.yml` | `ci-gate` needs 13 lanes and uses `if: always()` to aggregate required lanes. | Preserve as release/publish confidence source until Phase 80 adds `pr-gate`. | Phase 80 | [VERIFIED: .github/workflows/ci.yml] [CITED: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks] |
| `README.md` | Hex badge is correct for `chimeway`; CI badge points to `jonlunsford/chimeway`; install guidance uses `{:chimeway, "~> 1.0"}`. | Repo identity and front-door truth should be corrected in owner phase without changing Phase 77 scope. | Phase 78/79 split | [VERIFIED: README.md] |
| `CONTRIBUTING.md` | Clone command points to `https://github.com/jonlunsford/chimeway.git`. | Contributor source URL should match canonical repo. | Phase 80 or Phase 79, planner should assign with docs/CI split | [VERIFIED: CONTRIBUTING.md] |
| `CHANGELOG.md` | Existing 1.0.0 commit links point to `szTheory/chimeway`; no `v1.14` release anchor exists. | Preserve changelog release anchors as package releases, not planning milestones. | Phase 78 | [VERIFIED: CHANGELOG.md] |
| `MAINTAINING.md` | Documents Release Please, `ci-gate`, root publish/recovery, and first automated release after Hex 1.0.0 targets 1.1.0. | Maintainer copy should continue to match root package truth after Phase 78/80. | Phase 78/80 | [VERIFIED: MAINTAINING.md] |
| `chimeway_admin/mix.exs` | App `:chimeway_admin`, version `0.1.0`, path dependency `{:chimeway, path: ".."}`, no package/docs metadata. | In-repo preview/path package until future promotion milestone. | Phase 78 docs copy | [VERIFIED: chimeway_admin/mix.exs] |
| `chimeway_inbox/mix.exs` | App `:chimeway_inbox`, version `0.1.0`, path dependency `{:chimeway, path: ".."}`, no package/docs metadata. | In-repo preview/path package until future promotion milestone. | Phase 78 docs copy | [VERIFIED: chimeway_inbox/mix.exs] |
| Admin integration guide | Shows `{:chimeway_admin, "~> 1.0"}`. | Must not imply Hex install before promotion. | Phase 78 | [VERIFIED: guides/introduction/admin-console-integration.md] |
| Inbox integration guide | Shows `{:chimeway_inbox, path: "../chimeway_inbox"}` and says future Hex replacement is `~> 1.0`. | Keep present path-package status explicit; future package copy should be carefully framed. | Phase 78 | [VERIFIED: guides/introduction/inbox-integration.md] |
| Release gate contracts | Validate manifest/version parity, release workflow behavior, publish gating, CI lanes, and maintainer pre-ship parity. | Extend later for repo/source/package/sibling truth; Phase 77 records gap only. | Phase 78/80 | [VERIFIED: test/chimeway/release_gate_contract_test.exs] |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Release Please v3 `command: manifest` action input | Release Please action v4 defaults to manifest mode unless `release-type` is set; config-file and manifest-file inputs select repo files. | Documented in Release Please action v4 upgrade docs. [CITED: https://github.com/googleapis/release-please-action] | Planner should preserve existing v4 manifest-style workflow and not add legacy `command` inputs. |
| Ambiguous source links in docs | ExDoc supports `source_url` plus `source_ref` to link generated docs to a specific code version, and `source_ref: "v#{@version}"` expects matching `vVERSION` tags. | Current ExDoc docs. [CITED: https://hexdocs.pm/ex_doc/ExDoc.html] | Planner should keep HexDocs source refs tied to package SemVer tags, not planning labels. |
| Required workflow with path filters | GitHub warns skipped workflows from path/branch/message filters remain Pending when required; skipped jobs inside a running workflow report Success. | Current GitHub docs. [CITED: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks] | Phase 80 should use always-running aggregate gates; Phase 77 only records ownership. |

**Deprecated/outdated:**

- `jonlunsford/chimeway` as public repo identity is outdated for this repo: local git remote is `szTheory/chimeway`, `szTheory/chimeway` returned 200, and `jonlunsford/chimeway` returned 404 on 2026-07-02. [VERIFIED: git remote/curl 2026-07-02]
- Sibling Hex dependency snippets for `chimeway_admin` or `chimeway_inbox` are outdated unless or until a future package-promotion milestone publishes those packages. [VERIFIED: curl Hex API 2026-07-02] [VERIFIED: .planning/REQUIREMENTS.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| None | All substantive claims were copied from CONTEXT.md, verified by local file inspection, checked against live Hex/GitHub endpoints, or cited from official docs. | All | N/A |

## Open Questions

1. **Should the Phase 77 artifact be committed as `77-PACKAGE-MODEL-DECISION.md` or another name?**
   - What we know: CONTEXT.md allows ADR, decision record, or equivalent. [VERIFIED: .planning/phases/77-truth-baseline-and-package-model-decision/77-CONTEXT.md]
   - What's unclear: Exact filename is not locked. [VERIFIED: .planning/phases/77-truth-baseline-and-package-model-decision/77-CONTEXT.md]
   - Recommendation: Use `77-PACKAGE-MODEL-DECISION.md` to keep the artifact phase-local and explicit. [VERIFIED: .planning/ROADMAP.md]

2. **Should Phase 77 add tests for the decision artifact?**
   - What we know: Roadmap success criteria require an artifact and baseline inventory; Phase 78 owns package truth contracts. [VERIFIED: .planning/ROADMAP.md]
   - What's unclear: Whether the planner wants an automated grep acceptance step inside Phase 77. [VERIFIED: .planning/ROADMAP.md]
   - Recommendation: Do not add ExUnit tests in Phase 77; use artifact grep/manual review for TRUTH-04, then add durable contracts in Phase 78/80. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: test/chimeway/release_gate_contract_test.exs]

3. **Which downstream phase owns `CONTRIBUTING.md` canonical repo URL?**
   - What we know: Phase 79 owns front-door docs truth and Phase 80 owns CI/contributor DX truth. [VERIFIED: .planning/ROADMAP.md]
   - What's unclear: CONTRIBUTING spans public docs and contributor DX. [VERIFIED: CONTRIBUTING.md]
   - Recommendation: Assign CONTRIBUTING clone/source URL to Phase 80 if bundled with contributor gate docs, otherwise Phase 79 if bundled with public front-door docs. [VERIFIED: .planning/ROADMAP.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | Mix metadata and ExUnit contracts | yes | 1.19.5 / OTP 28 local; project supports 1.17+ and CI uses 1.17. [VERIFIED: elixir --version] [VERIFIED: .github/workflows/ci.yml] | Use CI matrix for canonical 1.17/OTP 26/27 behavior. |
| Mix | `mix ci.verify_gates`, `mix hex.*` | yes | 1.19.5 local. [VERIFIED: mix --version] | CI setup-beam in workflows. [VERIFIED: .github/workflows/ci.yml] |
| Hex | Package status and publish docs | yes | 2.5.0 local. [VERIFIED: mix hex --version] | Hex public API via `curl`. [VERIFIED: curl Hex API 2026-07-02] |
| Git | Remote identity and diff safety | yes | 2.41.0. [VERIFIED: git --version] | None needed. |
| curl | Live Hex/GitHub checks | yes | 8.7.1. [VERIFIED: curl --version] | `mix hex.info` for Hex package status. [VERIFIED: mix hex.info] |
| jq | Optional JSON inspection | yes | 1.7.1. [VERIFIED: jq --version] | `grep`/Elixir JSON parse if needed. |
| gh | Optional GitHub workflow/release checks | yes | 2.95.0. [VERIFIED: gh --version] | GitHub web/API via `curl`. |
| Node/npm | Existing Playwright/admin smoke ecosystem, not Phase 77 core | yes | Node 22.14.0, npm 11.1.0. [VERIFIED: node --version] [VERIFIED: npm --version] | Not needed for Phase 77. |

**Missing dependencies with no fallback:**
- None for Phase 77 research/planning artifact. [VERIFIED: environment probe]

**Missing dependencies with fallback:**
- None identified. [VERIFIED: environment probe]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit through Mix; local Mix 1.19.5, CI uses Elixir 1.17/OTP 26 and 27. [VERIFIED: mix --version] [VERIFIED: .github/workflows/ci.yml] |
| Config file | `mix.exs` aliases and `test/test_helper.exs`. [VERIFIED: mix.exs] [VERIFIED: test/test_helper.exs] |
| Quick run command | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` for release contract surface; artifact-only tasks can also use `rg` acceptance checks. [VERIFIED: test/chimeway/release_gate_contract_test.exs] |
| Full suite command | `mix ci.verify_gates` for doc-contract plus release-gate contract parity. [VERIFIED: mix.exs] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| TRUTH-04 | Decision artifact states package release tags are root SemVer tags and planning labels such as `v1.14` are not package refs. [VERIFIED: .planning/REQUIREMENTS.md] | artifact grep / review | `rg -n "v1\\.14|source_ref|publish ref|GitHub release|HexDocs|Release Please|v1\\.0\\.0" .planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md` | no - Phase 77 implementation artifact to create |
| TRUTH-04 | Existing root manifest/version/package release model remains baseline-compatible. [VERIFIED: .planning/REQUIREMENTS.md] | release contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | yes |
| TRUTH-04 | Baseline inventory records drift without broad public edits. [VERIFIED: .planning/ROADMAP.md] | artifact grep / git diff review | `git diff --name-only -- README.md mix.exs CHANGELOG.md .github/workflows MAINTAINING.md guides` should be empty for Phase 77 plans unless user explicitly expands scope. | N/A command |

### Sampling Rate

- **Per task commit:** For artifact-only changes, run the focused `rg` acceptance command over the decision artifact and `git diff --name-only` to confirm public surfaces were not edited. [VERIFIED: .planning/ROADMAP.md]
- **Per wave merge:** Run `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` if release truth language changed, otherwise run artifact grep checks. [VERIFIED: test/chimeway/release_gate_contract_test.exs]
- **Phase gate:** Run `mix ci.verify_gates` if any contract/doc gate file changed; otherwise artifact review plus `git diff --name-only` scope check is sufficient for Phase 77. [VERIFIED: mix.exs] [VERIFIED: .planning/ROADMAP.md]

### Wave 0 Gaps

- [ ] `.planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md` - create decision/baseline artifact for TRUTH-04. [VERIFIED: .planning/ROADMAP.md]
- [ ] Optional: no ExUnit test gap for Phase 77 if the artifact remains planning-only; Phase 78 should add durable package truth contracts. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: test/chimeway/release_gate_contract_test.exs]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | Phase 77 does not change authentication behavior. [VERIFIED: .planning/ROADMAP.md] |
| V3 Session Management | no | Phase 77 does not change sessions. [VERIFIED: .planning/ROADMAP.md] |
| V4 Access Control | no | Phase 77 does not change runtime access control. [VERIFIED: .planning/ROADMAP.md] |
| V5 Input Validation | yes | Validate package/version/ref claims through exact artifact text, Release Please config, Hex API status, and existing ExUnit contracts. [VERIFIED: release-please-config.json] [VERIFIED: test/chimeway/release_gate_contract_test.exs] |
| V6 Cryptography | no | Phase 77 does not change cryptography or secrets. [VERIFIED: .planning/ROADMAP.md] |

### Known Threat Patterns for Package/Docs Truth

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Package confusion from unpublished sibling packages | Spoofing / Tampering | State `chimeway_admin` and `chimeway_inbox` as path/preview packages until promoted; Phase 78 should contract-test public install copy. [VERIFIED: curl Hex API 2026-07-02] |
| Release repudiation from ambiguous refs | Repudiation | Separate planning labels from package tags and keep root release identity tied to `@version`, manifest, Release Please output, Hex version, and `source_ref`. [VERIFIED: .planning/phases/77-truth-baseline-and-package-model-decision/77-CONTEXT.md] |
| Users navigate to dead or wrong source repository | Spoofing / Information integrity | Baseline repo URL drift and let Phase 78/79 correct source links consistently. [VERIFIED: git remote/curl/rg 2026-07-02] |
| Sensitive examples creep into public docs during later rewrites | Information Disclosure | Preserve AGENTS.md rule against sensitive payload leakage and keep doc contracts for raw payload/render data/provider body/token/PII language. [VERIFIED: AGENTS.md] [VERIFIED: test/chimeway/doc_contract_test.exs] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/77-truth-baseline-and-package-model-decision/77-CONTEXT.md` - locked package model, tag namespace, truth ownership, baseline drift requirements, and deferred scope. [VERIFIED: local read]
- `.planning/REQUIREMENTS.md` - TRUTH-04 and out-of-scope package-promotion constraints. [VERIFIED: local read]
- `.planning/ROADMAP.md` - Phase 77 boundary, owner split across Phases 78-80, and success criteria. [VERIFIED: local read]
- `mix.exs`, `.release-please-manifest.json`, `release-please-config.json`, `.github/workflows/*.yml`, `test/chimeway/*contract_test.exs` - local implementation truth surfaces. [VERIFIED: codebase grep]
- Hex and GitHub live endpoints checked 2026-07-02: `https://hex.pm/api/packages/chimeway`, `https://hex.pm/api/packages/chimeway_admin`, `https://hex.pm/api/packages/chimeway_inbox`, `https://github.com/szTheory/chimeway`, `https://github.com/jonlunsford/chimeway`. [VERIFIED: curl]

### Secondary (MEDIUM confidence)

- Release Please action docs - manifest mode and `include-v-in-tag` config mapping. [CITED: https://github.com/googleapis/release-please-action]
- Hex publishing docs and `mix hex.publish` docs - package metadata, files, links, docs publish, dry-run/unpack behavior. [CITED: https://hex.pm/docs/publish] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html]
- ExDoc docs - `source_url`, `source_ref`, and tag-specific source links. [CITED: https://hexdocs.pm/ex_doc/ExDoc.html]
- GitHub required status checks docs - skipped workflow pending behavior and skipped job success behavior. [CITED: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks]

### Tertiary (LOW confidence)

- None used for recommendations. [VERIFIED: research log]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - locked by repository files, project instructions, and live tool/version probes. [VERIFIED: codebase grep] [VERIFIED: environment probe]
- Architecture: HIGH - phase ownership split and package model are locked in CONTEXT.md and ROADMAP.md. [VERIFIED: .planning/phases/77-truth-baseline-and-package-model-decision/77-CONTEXT.md] [VERIFIED: .planning/ROADMAP.md]
- Pitfalls: HIGH - derived from explicit Phase 77 decisions, visible drift, and official docs on Release Please/ExDoc/GitHub checks. [VERIFIED: codebase grep] [CITED: https://github.com/googleapis/release-please-action] [CITED: https://hexdocs.pm/ex_doc/ExDoc.html] [CITED: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks]

**Research date:** 2026-07-02
**Valid until:** 2026-07-09 for live Hex/GitHub package status; 2026-08-01 for local architecture and official-doc patterns. [VERIFIED: current_date]

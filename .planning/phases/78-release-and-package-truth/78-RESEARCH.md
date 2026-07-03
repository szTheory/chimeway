# Phase 78: Release and Package Truth - Research

**Researched:** 2026-07-03
**Domain:** Elixir Hex package/release truth, ExDoc source refs, Release Please manifest releases, ExUnit contract tests
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

Source for this copied section: [VERIFIED: .planning/phases/78-release-and-package-truth/78-CONTEXT.md]

### Locked Decisions

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

### the agent's Discretion

Downstream agents may choose the narrowest implementation shape that satisfies these decisions. Prefer contract tests that read real files and workflows directly, because this project already treats docs/release truth as executable contracts.

### Deferred Ideas (OUT OF SCOPE)

## Deferred Ideas

- Full README/front-door decision-page rewrite, first-hop docs IA cleanup, accurate adoption snippets beyond package truth, stub guide demotion, and clean consumer/adoption proof belong to Phase 79.
- Fast `pr-gate`, required-check topology, local CI reproducibility, cache improvements, `CONTRIBUTING.md` canonical clone URL, and broader maintainer/contributor gate docs belong to Phase 80.
- Publishing `chimeway_admin` or `chimeway_inbox` as Hex packages belongs to a future explicit package-promotion milestone, not Phase 78.
</user_constraints>

## Summary

Phase 78 should be implemented as a package-truth contract extension, not as a broad documentation rewrite. The root package is currently `chimeway` version `1.0.0`; `.release-please-manifest.json` contains only `{ ".": "1.0.0" }`; Release Please is configured for only `packages["."]`; and the existing publish workflows build/publish from the root package path. [VERIFIED: mix.exs, .release-please-manifest.json, release-please-config.json, .github/workflows/release.yml, .github/workflows/publish-hex.yml] The live Hex API reports `chimeway` latest version `1.0.0` with release inserted `2026-05-08T21:33:45.553858Z`, and reports `404` for both `chimeway_admin` and `chimeway_inbox`. [VERIFIED: curl https://hex.pm/api/packages/chimeway, curl https://hex.pm/api/packages/chimeway_admin, curl https://hex.pm/api/packages/chimeway_inbox]

The central implementation risk is artifact truth, not just copy drift. The documented Hex inspection path is `mix hex.build --unpack --output DIR`, and the installed Hex 2.5.0 task says `--unpack` is for checking tarball contents before publishing. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html] A local default `mix hex.build --unpack --output /tmp/chimeway_phase78_research_unpack` currently fails with `Can't build package with overridden dependency sigra, remove override: true`; the same command succeeds when `CHIMEWAY_SKIP_SIGRA_DEP=1` is set. [VERIFIED: local command `mix hex.build --unpack --output /tmp/chimeway_phase78_research_unpack`] The planner should include an explicit task to make the default root package build path succeed, then assert package files and metadata from the unpacked output. [VERIFIED: mix hex.build local probe]

**Primary recommendation:** Extend `release_gate_contract_test.exs` for root package/version/source/artifact truth, extend `doc_contract_test.exs` for sibling preview/path install-status truth, and make `mix verify.parity` pass without special local-only dependency overrides. [VERIFIED: .planning/phases/78-release-and-package-truth/78-CONTEXT.md, mix.exs, test/chimeway/release_gate_contract_test.exs, test/chimeway/doc_contract_test.exs]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Root package metadata and files whitelist | Build / Package | Repository source | `mix.exs` owns `@version`, `package()`, `docs()`, aliases, and dependency declarations used by Hex builds. [VERIFIED: mix.exs] |
| Release manifest and tag namespace | Release Automation | Repository source | `.release-please-manifest.json` and `release-please-config.json` define the root package version source and root `v<version>` tag behavior. [VERIFIED: .release-please-manifest.json, release-please-config.json] |
| HexDocs source links | Documentation Build | Release Automation | ExDoc derives source links from `source_url` and `source_ref`, and the existing docs config uses `source_ref: "v#{@version}"`. [VERIFIED: mix.exs] [CITED: https://hexdocs.pm/ex_doc/0.30.3/Mix.Tasks.Docs.html] |
| Public install constraints | Documentation | Build / Package | README and guides expose dependency snippets that must match root package version and sibling preview/path status. [VERIFIED: README.md, guides/introduction/admin-console-integration.md, guides/introduction/inbox-integration.md] |
| Sibling package status | Documentation | Build / Package | `chimeway_admin` and `chimeway_inbox` are sibling Mix projects with `{:chimeway, path: ".."}` and no package metadata; live Hex returns 404 for both names. [VERIFIED: chimeway_admin/mix.exs, chimeway_inbox/mix.exs, curl Hex API] |
| Truth enforcement | Test / Verification | CI / Release Automation | Existing release/doc contract tests read project files directly and are run by `mix ci.verify_gates`. [VERIFIED: test/chimeway/release_gate_contract_test.exs, test/chimeway/doc_contract_test.exs, mix.exs] |

## Project Constraints (from AGENTS.md)

- Chimeway is an open-source embedded notification layer for Elixir and Phoenix apps; package truth must preserve host ownership of data, policies, and delivery history. [VERIFIED: AGENTS.md]
- Every notification decision must remain explainable; package/docs changes must not weaken explainability copy or leak sensitive payload fields in operator surfaces. [VERIFIED: AGENTS.md]
- The stack is Elixir 1.17+ / OTP 26+, Ecto 3.x + PostgreSQL 15+, optional Phoenix 1.7/1.8 surfaces, optional Oban 2.x async dispatch, and Swoosh 1.x email adapter seam. [VERIFIED: AGENTS.md]
- Stable `notification_key` + version, durable event -> notification -> delivery -> attempt lifecycle, first-class idempotency/suppression reasons, replaceable adapters, and host ownership boundaries are build principles that this phase must not disrupt. [VERIFIED: AGENTS.md]
- Maintain `mix verify.*` and `mix ci.*` entrypoints and keep CI/local scripts in parity. [VERIFIED: AGENTS.md]
- Docs/release-gate style phases use contract evidence from `mix ci.verify_gates` plus ecosystem `verify.*` jobs instead of conversational UAT where applicable. [VERIFIED: AGENTS.md]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRUTH-01 | Root package version, release manifest, changelog, HexDocs source ref, README install guidance, and release automation agree on the real published package state. [VERIFIED: .planning/REQUIREMENTS.md] | Root release identity is already centralized in `@version`, the manifest, Release Please config, changelog, docs `source_ref`, and publish workflows; Phase 78 must extend release-gate contracts and fix the default Hex artifact build failure. [VERIFIED: mix.exs, .release-please-manifest.json, release-please-config.json, CHANGELOG.md, local `mix hex.build` probe] |
| TRUTH-02 | Repository identity, source URLs, README badges, package links, HexDocs links, changelog links, and workflow references point to the same canonical project surface. [VERIFIED: .planning/REQUIREMENTS.md] | Canonical repo is `https://github.com/szTheory/chimeway`; root `mix.exs` and README still contain `https://github.com/jonlunsford/chimeway`, while changelog links already use `szTheory/chimeway`. [VERIFIED: git remote, mix.exs, README.md, CHANGELOG.md, curl GitHub 200/404 checks] |
| TRUTH-03 | `chimeway_admin` and `chimeway_inbox` documentation states their real install status: in-repo preview/path packages until intentionally promoted. [VERIFIED: .planning/REQUIREMENTS.md] | Admin guide currently advertises `{:chimeway_admin, "~> 1.0"}` even though Hex returns 404; inbox guide uses a path dependency but includes future-publish copy that needs a contract guard. [VERIFIED: guides/introduction/admin-console-integration.md, guides/introduction/inbox-integration.md, curl Hex API] |
</phase_requirements>

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Elixir / Mix | Elixir 1.19.5, Mix 1.19.5 locally; project requires `~> 1.17`. [VERIFIED: `elixir --version`, `mix --version`, mix.exs] | Build, package metadata, aliases, and test execution. | This project is a Mix package and all target truth surfaces are Mix/Hex/ExUnit files. [VERIFIED: mix.exs] |
| Hex / Mix Hex | Hex 2.5.0 locally. [VERIFIED: `mix hex --version`] | Hex package build, dry run, publish, and unpacked artifact inspection. | Official Hex docs define `:package`, `:files`, `mix hex.publish --dry-run`, and `mix hex.build --unpack` as the package metadata and artifact workflow. [CITED: https://hex.pm/docs/publish] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html] |
| ExDoc | Locked at 0.40.1; recent Hex release 0.40.3 on 2026-05-21. [VERIFIED: `mix deps`, `mix hex.info ex_doc`] | HexDocs generation and source-link behavior. | ExDoc documents `source_url`, `source_ref`, and source URL pattern inference for GitHub-hosted projects. [VERIFIED: deps/ex_doc/lib/ex_doc.ex] [CITED: https://hexdocs.pm/ex_doc/0.30.3/Mix.Tasks.Docs.html] |
| ExUnit | Ships with Elixir/Mix. [VERIFIED: `mix test` baseline] | Package truth contracts. | Existing project truth anchors are ExUnit tests that read real repo files and run under `mix ci.verify_gates`. [VERIFIED: test/chimeway/release_gate_contract_test.exs, test/chimeway/doc_contract_test.exs, mix.exs] |
| Release Please action | Pinned by commit SHA `0dfd8538845b8e92600d271a895a5372865d4062` in release workflow. [VERIFIED: .github/workflows/release.yml] | Root release PR, tag, GitHub release, and manifest flow. | Official release-please-action docs support `config-file`, `manifest-file`, and package options in manifest config. [CITED: https://github.com/googleapis/release-please-action] |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| curl | 8.7.1 locally. [VERIFIED: `curl --version`] | Live Hex/GitHub public truth probes. | Use for research/manual verification or a non-default published-version proof; avoid making default fast contracts depend on network unless intentionally scoped. [ASSUMED] |
| jq | 1.7.1 locally. [VERIFIED: `jq --version`] | Inspect live Hex API JSON in manual commands. | Use in research/runbook commands, not as a required ExUnit dependency. [VERIFIED: local environment] |
| gh | 2.95.0 locally. [VERIFIED: `gh --version`] | Existing workflows poll GitHub Actions and Release Please PRs. | Phase 78 should preserve root workflow behavior; broader CI topology stays Phase 80. [VERIFIED: .github/workflows/release.yml, .planning/phases/78-release-and-package-truth/78-CONTEXT.md] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Extend ExUnit contracts | New shell checker script | Rejected by D-07; would create a parallel truth surface and weaken existing `mix ci.verify_gates` parity. [VERIFIED: 78-CONTEXT.md] |
| Local unpacked artifact proof | Live Hex.pm package tarball proof in default gate | Local proof is deterministic and can fail before publish; live proof is useful post-publish but network-dependent. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html] [ASSUMED] |
| Keep sibling Hex snippets | Publish sibling packages now | Rejected by D-05/D-06; sibling package promotion is deferred to a future explicit milestone. [VERIFIED: 78-CONTEXT.md] |

**Installation:** No new packages should be installed for Phase 78. [VERIFIED: 78-CONTEXT.md, mix.exs]

```bash
mix deps.get
```

**Version verification used:**

```bash
elixir --version
mix --version
mix hex --version
mix deps
mix hex.info ex_doc
```

## Package Legitimacy Audit

This phase should not add external packages. [VERIFIED: 78-CONTEXT.md] The Package Legitimacy Gate is not required unless the planner introduces a new dependency, which would contradict the recommended stack. [VERIFIED: 78-CONTEXT.md]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| None added | - | - | - | - | OK | No install planned. [VERIFIED: mix.exs, 78-CONTEXT.md] |

**Packages removed due to [SLOP] verdict:** none. [VERIFIED: no package-legitimacy gate needed]
**Packages flagged as suspicious [SUS]:** none. [VERIFIED: no package-legitimacy gate needed]

## Architecture Patterns

### System Architecture Diagram

```text
Root package source files
  |
  |-- mix.exs (@version, package(), docs(), aliases, deps)
  |-- .release-please-manifest.json
  |-- release-please-config.json
  |-- CHANGELOG.md
  |-- README.md + sibling guides
  |-- release/publish workflows
  v
ExUnit truth contracts (mix ci.verify_gates)
  |
  |-- release_gate_contract_test.exs
  |     |-- parse root version + manifest
  |     |-- assert root-only Release Please package
  |     |-- assert canonical repo/source URLs
  |     |-- run/inspect mix hex.build --unpack in a temp dir
  |     `-- assert package file whitelist and unpacked metadata
  |
  `-- doc_contract_test.exs
        |-- assert README install constraint matches @version
        |-- forbid current Hex dependency snippets for siblings
        `-- require preview/path status language for siblings
  v
Release and publish workflows
  |
  |-- Release Please creates package SemVer tag (v<@version>)
  |-- ci-gate / ci.verify_gates / ci.docs replay
  `-- root mix hex.publish
```

### Recommended Project Structure

```text
mix.exs                                      # Root package metadata, docs config, verify aliases. [VERIFIED: mix.exs]
.release-please-manifest.json               # Root package manifest version. [VERIFIED: .release-please-manifest.json]
release-please-config.json                   # Root-only Release Please package config. [VERIFIED: release-please-config.json]
CHANGELOG.md                                 # Package SemVer release notes and canonical commit links. [VERIFIED: CHANGELOG.md]
README.md                                    # Root install guidance and package-facing badges. [VERIFIED: README.md]
guides/introduction/admin-console-integration.md
guides/introduction/inbox-integration.md     # Sibling preview/path install-status copy. [VERIFIED: guides/introduction/*.md]
test/chimeway/release_gate_contract_test.exs # Package/release/source/artifact truth. [VERIFIED: 78-CONTEXT.md]
test/chimeway/doc_contract_test.exs          # README/guide snippet truth. [VERIFIED: 78-CONTEXT.md]
```

### Pattern 1: File-Backed Release Truth Contract

**What:** Read root package, manifest, Release Please, workflow, README, and changelog files from ExUnit and assert the same package identity across surfaces. [VERIFIED: test/chimeway/release_gate_contract_test.exs]

**When to use:** Use for TRUTH-01 and TRUTH-02 because these truths are deterministic repo-file relationships. [VERIFIED: .planning/REQUIREMENTS.md]

**Example:**

```elixir
# Source: test/chimeway/release_gate_contract_test.exs
manifest_content = File.read!(".release-please-manifest.json")
mix_exs = File.read!("mix.exs")

[_, manifest_version] = Regex.run(~r/"\."\s*:\s*"([^"]+)"/, manifest_content)
assert Regex.match?(~r/@version\s+"#{Regex.escape(manifest_version)}"/, mix_exs)
```

### Pattern 2: Unpacked Artifact Proof in a Separate Mix Process

**What:** Invoke `mix hex.build --unpack --output TMPDIR` as a separate OS process, then assert expected files and metadata. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html] [VERIFIED: local `mix help hex.build`]

**When to use:** Use after fixing the default `sigra` override build failure, because Phase 78 success criterion 4 requires root artifact proof. [VERIFIED: local `mix hex.build` probe]

**Example:**

```elixir
# Source: recommended Phase 78 pattern based on Hex 2.5.0 task help
output = Path.join(System.tmp_dir!(), "chimeway-package-#{System.unique_integer([:positive])}")

try do
  {result, status} =
    System.cmd("mix", ["hex.build", "--unpack", "--output", output],
      stderr_to_stdout: true
    )

  assert status == 0, result
  assert File.exists?(Path.join(output, "mix.exs"))
  assert File.exists?(Path.join(output, "guides/introduction/admin-console-integration.md"))
after
  File.rm_rf(output)
end
```

### Pattern 3: Sibling Status Copy as Negative and Positive Contracts

**What:** Assert that public docs contain preview/path status language and forbid current Hex dependency snippets for unpublished sibling packages. [VERIFIED: 78-CONTEXT.md, guides/introduction/admin-console-integration.md, guides/introduction/inbox-integration.md]

**When to use:** Use for TRUTH-03, especially to prevent `{:chimeway_admin, "~> 1.0"}` from returning. [VERIFIED: 78-CONTEXT.md]

**Example:**

```elixir
# Source: recommended Phase 78 pattern for doc_contract_test.exs
content = File.read!("guides/introduction/admin-console-integration.md")

refute String.contains?(content, ~s({:chimeway_admin, "~> 1.0"}))
assert String.contains?(content, "in-repo preview/path package")
assert String.contains?(content, "not published on Hex")
```

### Anti-Patterns to Avoid

- **Adding sibling publish lanes:** This contradicts D-02 and D-05. [VERIFIED: 78-CONTEXT.md]
- **Using `v1.14` as a package ref:** Phase 77 established that planning milestone labels are not package release tags, HexDocs source refs, publish refs, changelog anchors, or GitHub release names. [VERIFIED: .planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md]
- **Calling `Mix.Tasks.Hex.Build` inside the already-loaded test VM:** Hex 2.5.0 task help warns that `hex.build` must be invoked before tasks that may load/start the application unless `:hex` is explicitly in `:extra_applications`; use a separate `System.cmd("mix", ...)` process for ExUnit artifact proof. [VERIFIED: local `mix help hex.build`]
- **Relying on current public Hex metadata for deterministic pre-publish tests:** Live `chimeway` metadata still reports the old GitHub link, so default contracts should prove source truth in the repo/package artifact, not demand that historical Hex metadata is already rewritten. [VERIFIED: curl Hex API] [ASSUMED]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Hex package artifact inspection | Custom tar writer or file-copy checker | `mix hex.build --unpack --output DIR` | Hex documents this as the pre-publish package-content inspection path. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html] |
| Hex package metadata and file inclusion | Separate YAML manifest | `mix.exs` `package()` and `docs()` | Hex reads package config from the Mix project and `:files` controls package contents. [CITED: https://hex.pm/docs/publish] |
| HexDocs source links | Manual source URL concatenation | ExDoc `source_url` + `source_ref` | ExDoc derives source links from those fields for GitHub/GitLab/Bitbucket. [CITED: https://hexdocs.pm/ex_doc/0.30.3/Mix.Tasks.Docs.html] [VERIFIED: deps/ex_doc/lib/ex_doc.ex] |
| Release version tracking | Custom version file | Release Please manifest + root `@version` | Release Please manifest records a version per configured package, and Chimeway already has a root-only manifest. [CITED: https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md] [VERIFIED: .release-please-manifest.json] |
| Package truth checking | Parallel shell script | Existing ExUnit contract tests | D-07 requires extending `release_gate_contract_test.exs` and `doc_contract_test.exs`. [VERIFIED: 78-CONTEXT.md] |
| JSON parsing in tests | Regex for nested JSON | `Jason.decode!` where dependency is available | The project already depends on `jason`; JSON parsing is less brittle than regex for Release Please config. [VERIFIED: mix.exs] |

**Key insight:** Hex, ExDoc, and Release Please already define the package/release mechanisms; Phase 78 should connect those mechanisms with executable contracts instead of introducing another source of truth. [VERIFIED: Hex docs, ExDoc docs, Release Please docs, 78-CONTEXT.md]

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | Live Hex package metadata for `chimeway` latest `1.0.0` currently has `meta.links.GitHub` set to `https://github.com/jonlunsford/chimeway`; `chimeway_admin` and `chimeway_inbox` return 404 from the package API. [VERIFIED: curl Hex API] | Correct `mix.exs` package links for future package builds and add package truth checks; do not plan sibling publication in Phase 78. [VERIFIED: 78-CONTEXT.md] |
| Live service config | GitHub canonical repo `https://github.com/szTheory/chimeway` returns 200, while `https://github.com/jonlunsford/chimeway` returns 404; release workflow requires `HEX_API_KEY` and optionally `RELEASE_PLEASE_TOKEN`. [VERIFIED: curl GitHub checks, .github/workflows/release.yml] | Normalize package-facing repo/source links to `szTheory/chimeway`; no secret name change is required. [VERIFIED: 78-CONTEXT.md, .github/workflows/release.yml] |
| OS-registered state | None found in phase scope; phase-owned surfaces are repo files plus Hex/GitHub public services. [VERIFIED: 78-CONTEXT.md, repo grep] | No OS registration task required. [VERIFIED: phase scope review] |
| Secrets/env vars | `HEX_API_KEY` is used for publish; `RELEASE_PLEASE_TOKEN` is optional for release creation; `CHIMEWAY_SKIP_SIGRA_DEP` exists as a dependency skip flag and makes local unpacked Hex build succeed. [VERIFIED: .github/workflows/release.yml, mix.exs, local `mix hex.build` probe] | Preserve publish secret names; fix the default package build path rather than relying only on a local skip env in release truth contracts. [ASSUMED] |
| Build artifacts | `/tmp/chimeway_phase78_research_unpack` was created by the successful research build with `CHIMEWAY_SKIP_SIGRA_DEP=1`; default build failed before writing a successful artifact. [VERIFIED: local command] | Planner should use unique temp dirs and cleanup in artifact contract tests; ensure default `mix verify.parity` succeeds after implementation. [VERIFIED: mix.exs] |

**Nothing found in category:** OS-registered state has no phase-relevant items; verified by phase scope, repo grep, and absence of graph context. [VERIFIED: 78-CONTEXT.md, `rg`, `.planning/graphs/graph.json` absent]

## Common Pitfalls

### Pitfall 1: Default Hex Build Still Fails

**What goes wrong:** A plan updates docs and metadata but leaves `mix hex.build` failing because `sigra` is declared with `override: true`. [VERIFIED: local `mix hex.build --unpack` probe]

**Why it happens:** Hex refuses overridden dependencies during package build. [VERIFIED: local Hex 2.5.0 error]

**How to avoid:** Add a task to remove/scope the override so the default root package build succeeds, then prove `mix verify.parity` or a focused artifact test passes without setting `CHIMEWAY_SKIP_SIGRA_DEP`. [VERIFIED: mix.exs, local build probe]

**Warning signs:** `mix hex.build --unpack` prints `Can't build package with overridden dependency sigra`. [VERIFIED: local command]

### Pitfall 2: Correcting Copy Without Locking Regression Tests

**What goes wrong:** `README.md` or guides are fixed once, but stale snippets like `{:chimeway_admin, "~> 1.0"}` can return later. [VERIFIED: current admin guide, 78-CONTEXT.md]

**Why it happens:** Existing doc contracts require admin/inbox content but do not yet forbid sibling current-Hex claims. [VERIFIED: test/chimeway/doc_contract_test.exs]

**How to avoid:** Add explicit positive and negative contracts for each sibling package status. [VERIFIED: 78-CONTEXT.md]

**Warning signs:** `rg -n '\{:chimeway_admin, "~> 1\.0"|\{:chimeway_inbox, "~> 1\.0"|published to hex|published on Hex' guides README.md` finds current-status claims outside future-promotion context. [VERIFIED: repo grep]

### Pitfall 3: Confusing Package Tags With Planning Milestones

**What goes wrong:** `v1.14` leaks into HexDocs `source_ref`, publish workflow refs, changelog release anchors, or release names. [VERIFIED: Phase 77 package model decision]

**Why it happens:** Planning milestone labels and package SemVer tags both look like versions. [VERIFIED: .planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md]

**How to avoid:** Contract-test `source_ref: "v#{@version}"`, Release Please root manifest parity, and absence of planning labels from package-facing release refs. [VERIFIED: 78-CONTEXT.md]

**Warning signs:** `rg -n 'v1\.14' mix.exs CHANGELOG.md README.md .github/workflows release-please-config.json .release-please-manifest.json guides` returns a package-facing hit. [VERIFIED: Phase 77 validation pattern]

### Pitfall 4: Over-Editing Phase 79/80 Surfaces

**What goes wrong:** Phase 78 becomes a front-door README rewrite or CI topology rewrite. [VERIFIED: 78-CONTEXT.md]

**Why it happens:** The README and workflows are shared surfaces for package truth, docs IA, and contributor CI. [VERIFIED: ROADMAP.md, 78-CONTEXT.md]

**How to avoid:** Limit README changes to package-facing install/badge/source truth and workflow changes to root package release truth only; defer broader docs IA and CI/DX to Phases 79 and 80. [VERIFIED: 78-CONTEXT.md]

**Warning signs:** Edits to `CONTRIBUTING.md`, required-check topology, broad README value-prop structure, or clean consumer adoption proof appear in the Phase 78 diff. [VERIFIED: 78-CONTEXT.md, Phase 77 handoff]

## Code Examples

### Root Version / Manifest Contract

```elixir
# Source: test/chimeway/release_gate_contract_test.exs
manifest_content = File.read!(".release-please-manifest.json")
mix_exs = File.read!("mix.exs")

manifest_version =
  case Regex.run(~r/"\."\s*:\s*"([^"]+)"/, manifest_content) do
    [_, version] -> version
    _ -> flunk("Could not parse version from .release-please-manifest.json")
  end

assert Regex.match?(~r/@version\s+"#{Regex.escape(manifest_version)}"/, mix_exs)
```

### Canonical URL Drift Guard

```elixir
# Source: recommended Phase 78 extension based on D-03
phase_78_package_files = [
  "mix.exs",
  "README.md",
  "CHANGELOG.md",
  ".github/workflows/release.yml",
  ".github/workflows/publish-hex.yml"
]

for path <- phase_78_package_files do
  content = File.read!(path)
  refute String.contains?(content, "https://github.com/jonlunsford/chimeway"),
         "#{path} must not point package-facing copy at the stale repository"
end
```

### Artifact File Whitelist Proof

```elixir
# Source: recommended Phase 78 extension based on mix hex.build --unpack
expected_roots = ~w(lib priv guides CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs)
output = Path.join(System.tmp_dir!(), "chimeway-hex-#{System.unique_integer([:positive])}")

try do
  {log, status} = System.cmd("mix", ["hex.build", "--unpack", "--output", output], stderr_to_stdout: true)
  assert status == 0, log

  for root <- expected_roots do
    assert File.exists?(Path.join(output, root)), "missing #{root} from unpacked Hex package"
  end
after
  File.rm_rf(output)
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Public docs as prose only | File-backed ExUnit doc/release contracts | Established across prior docs/release gates and reaffirmed in Phase 77/78 context. [VERIFIED: AGENTS.md, Phase 77 summary, 78-CONTEXT.md] | Planner should add tests before/with edits, not rely on manual review. [VERIFIED: existing test anchors] |
| Implicit package contents | Explicit `package(files: ...)` plus `mix hex.build --unpack` proof | Hex supports `:files` and `--unpack`; current project has explicit `files`. [CITED: https://hex.pm/docs/publish] [VERIFIED: mix.exs] | Planner can assert exact public artifact contents. [VERIFIED: local unpacked build with skip env] |
| Component-prefixed monorepo release tags | Root package `v<release-version>` tags | Release Please docs allow `include-component-in-tag: false`; Chimeway uses root package config with `include-v-in-tag: true`. [CITED: https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md] [VERIFIED: release-please-config.json] | Preserve root-only package release identity. [VERIFIED: 78-CONTEXT.md] |
| Advertise optional surfaces as published packages | Describe sibling surfaces as in-repo preview/path packages | Phase 77 decided siblings are not Hex packages for v1.14; live Hex returns 404. [VERIFIED: Phase 77 package model, curl Hex API] | Public install snippets must use path/preview language until future promotion. [VERIFIED: 78-CONTEXT.md] |

**Deprecated/outdated:**

- `https://github.com/jonlunsford/chimeway` in Phase 78 package-facing surfaces is stale; canonical package-facing URL is `https://github.com/szTheory/chimeway`. [VERIFIED: 78-CONTEXT.md, curl GitHub checks]
- `{:chimeway_admin, "~> 1.0"}` is not truthful current install guidance because `chimeway_admin` is not a published Hex package. [VERIFIED: admin guide, curl Hex API]
- `v1.14` is a planning milestone label, not a package release ref. [VERIFIED: Phase 77 package model decision]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Default `mix ci.verify_gates` should avoid live network checks and keep live Hex/GitHub probes as manual or post-publish proof unless explicitly scoped. [ASSUMED] | Standard Stack / Pitfalls | Planner may need a separate live verification task if maintainers want network-backed package status in CI. |
| A2 | Existing stale Hex metadata for already-published `chimeway` 1.0.0 should not block Phase 78 if repo/package artifact truth is corrected for the next publish. [ASSUMED] | Architecture Patterns / Runtime State Inventory | Planner may need a Hex owner remediation task if Hex supports editing package metadata without a new release. |
| A3 | The package-build fix should make default `mix hex.build --unpack` pass instead of relying only on `CHIMEWAY_SKIP_SIGRA_DEP=1`. [ASSUMED] | Runtime State Inventory / Pitfalls | Planner may choose an env-scoped release build path instead, but must then contract-test parity with publish workflows. |

## Open Questions

1. **How should the `sigra` `override: true` package-build blocker be fixed?** [VERIFIED: local build probe]
   - What we know: Default `mix hex.build --unpack` fails; `CHIMEWAY_SKIP_SIGRA_DEP=1` succeeds. [VERIFIED: local commands]
   - What's unclear: Whether maintainers prefer removing the override, scoping it away from package builds, or setting skip env in release/publish workflows. [ASSUMED]
   - Recommendation: Prefer a default root build that passes without special env, because release workflows currently run `mix hex.build` with no skip env. [VERIFIED: .github/workflows/release.yml, .github/workflows/publish-hex.yml]

2. **Should Phase 78 attempt live Hex metadata remediation for the existing `1.0.0` package page?** [VERIFIED: curl Hex API]
   - What we know: Live package metadata still points GitHub link at the stale repo. [VERIFIED: curl Hex API]
   - What's unclear: Whether Hex owners can update package metadata outside the documented update window without a new package version. [ASSUMED]
   - Recommendation: Correct source package metadata and contracts now; treat live metadata correction as a manual maintainer follow-up unless a documented Hex command is confirmed. [ASSUMED]

3. **How broad should stale repo URL cleanup be in Phase 78?** [VERIFIED: repo grep]
   - What we know: Phase 78 owns package-facing README, package metadata, HexDocs links, changelog/source-facing claims, and package truth contracts; Phase 80 owns contributor `CONTRIBUTING.md` drift. [VERIFIED: 78-CONTEXT.md, Phase 77 handoff]
   - What's unclear: Some guide deep links outside package-facing install truth still point to the old repo. [VERIFIED: repo grep]
   - Recommendation: Contract-test only Phase 78-owned package-facing surfaces and avoid broad guide rewrite unless the link is in package install/source truth. [VERIFIED: 78-CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | Mix project and ExUnit contracts | yes | 1.19.5 locally; project requires `~> 1.17`. [VERIFIED: `elixir --version`, mix.exs] | Use project-supported Elixir 1.17+ in CI. [VERIFIED: AGENTS.md] |
| Mix | Aliases, tests, Hex tasks | yes | 1.19.5. [VERIFIED: `mix --version`] | None needed. |
| Hex | `mix hex.build`, `mix hex.publish`, package info | yes | 2.5.0. [VERIFIED: `mix hex --version`] | None needed. |
| ExDoc | `mix ci.docs`, HexDocs source refs | yes | Locked 0.40.1. [VERIFIED: `mix deps`] | None needed. |
| git | Release refs and repo URL checks | yes | 2.41.0. [VERIFIED: `git --version`] | None needed. |
| curl | Live Hex/GitHub probes | yes | 8.7.1. [VERIFIED: `curl --version`] | `mix hex.info` for package info where authentication state permits. [VERIFIED: local command] |
| jq | Inspect JSON API output | yes | 1.7.1. [VERIFIED: `jq --version`] | Use `Jason.decode!` in Elixir tests. [VERIFIED: mix.exs] |
| gh | Existing workflow GitHub polling | yes | 2.95.0. [VERIFIED: `gh --version`] | GitHub API via `actions/github-script` in workflows already exists. [VERIFIED: .github/workflows/release.yml] |
| ctx7 | Preferred docs lookup fallback | no | - [VERIFIED: `command -v ctx7`] | Official docs via web and installed local docs were used. [VERIFIED: research commands] |

**Missing dependencies with no fallback:** none. [VERIFIED: environment audit]

**Missing dependencies with fallback:**

- `ctx7` is missing; this research used official Hex/ExDoc/Release Please docs plus local installed Mix task docs. [VERIFIED: `command -v ctx7`, web/local docs]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit through Mix. [VERIFIED: test/test_helper.exs, local `mix test`] |
| Config file | `mix.exs` aliases; no separate ExUnit config file. [VERIFIED: mix.exs, test/test_helper.exs] |
| Quick run command | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --warnings-as-errors` [VERIFIED: local command passed, 477 tests, 0 failures] |
| Full suite command | `mix ci.verify_gates` plus `mix ci.docs` plus `mix verify.parity` after the artifact build blocker is fixed. [VERIFIED: mix.exs, local build probe] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| TRUTH-01 | Root version, manifest, changelog release, HexDocs `source_ref`, README install constraint, release automation, and package artifact agree. [VERIFIED: REQUIREMENTS.md] | contract + artifact smoke | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` and `mix verify.parity` [VERIFIED: mix.exs] | yes, extend existing file. [VERIFIED: test/chimeway/release_gate_contract_test.exs] |
| TRUTH-02 | Canonical repo/source URLs align to `https://github.com/szTheory/chimeway` across package-facing surfaces. [VERIFIED: REQUIREMENTS.md, 78-CONTEXT.md] | contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors` [VERIFIED: local command] | yes, extend existing files. [VERIFIED: test files] |
| TRUTH-03 | Sibling docs state preview/path status and forbid current Hex dependency claims. [VERIFIED: REQUIREMENTS.md, 78-CONTEXT.md] | doc contract | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` [VERIFIED: local command] | yes, extend existing file. [VERIFIED: test/chimeway/doc_contract_test.exs] |

### Sampling Rate

- **Per task commit:** `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --warnings-as-errors` for contract edits; add `mix verify.parity` for package/artifact edits. [VERIFIED: mix.exs]
- **Per wave merge:** `mix ci.verify_gates`, `mix ci.docs`, and `mix verify.parity` after the default Hex build path is fixed. [VERIFIED: mix.exs, local build probe]
- **Phase gate:** Full contract gate green plus artifact proof green before verification/summary. [VERIFIED: 78 success criteria, mix.exs]

### Wave 0 Gaps

- [ ] `test/chimeway/release_gate_contract_test.exs` - add TRUTH-01 root package metadata, `package().files`, docs source URL/ref, changelog release anchor, Release Please root-only config, and artifact unpack proof. [VERIFIED: 78-CONTEXT.md]
- [ ] `test/chimeway/release_gate_contract_test.exs` - add TRUTH-02 canonical package-facing URL guard for `mix.exs`, README badge/source surfaces, changelog/source-facing links, and release/publish workflow references. [VERIFIED: 78-CONTEXT.md]
- [ ] `test/chimeway/doc_contract_test.exs` - add TRUTH-03 positive/negative sibling install-status checks for admin and inbox guides. [VERIFIED: 78-CONTEXT.md]
- [ ] `mix.exs` / dependency declaration - fix the default `mix hex.build --unpack` failure caused by `sigra` `override: true`. [VERIFIED: local build probe]
- [ ] `mix verify.parity` - update or preserve alias so it proves package files and unpacked Hex behavior without stale source links. [VERIFIED: mix.exs]

## Security Domain

Security enforcement is enabled because `.planning/config.json` does not set `security_enforcement: false`. [VERIFIED: .planning/config.json]

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no for runtime app auth; yes indirectly for package publish credentials. [VERIFIED: phase scope, workflows] | Keep `HEX_API_KEY` in GitHub Actions secrets and do not expose it in docs/tests. [VERIFIED: .github/workflows/release.yml] |
| V3 Session Management | no | No session/cookie behavior changes in this phase. [VERIFIED: 78-CONTEXT.md] |
| V4 Access Control | yes for release/publish workflow permissions | Preserve least-needed workflow permissions and root-only publish path; no sibling publish lanes. [VERIFIED: .github/workflows/release.yml, 78-CONTEXT.md] |
| V5 Input Validation | yes | Validate release refs as package tags or 40-character SHAs; parse JSON with structured parsing where feasible. [VERIFIED: .github/workflows/publish-hex.yml, mix.exs] |
| V6 Cryptography | no custom crypto | Do not hand-roll token or signature handling; rely on GitHub Actions secrets and Hex API key mechanisms. [VERIFIED: .github/workflows/release.yml] |

### Known Threat Patterns for Release/Package Truth

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Publishing from a stale or wrong source ref | Tampering | Contract-test `source_ref: "v#{@version}"`, Release Please tag namespace, and workflow checkout refs. [VERIFIED: mix.exs, release workflows] |
| Stale repository links routing users to a dead or wrong repo | Spoofing | Canonical URL drift guard for package-facing surfaces. [VERIFIED: curl GitHub checks, 78-CONTEXT.md] |
| Advertising unpublished sibling packages as Hex releases | Spoofing / Tampering | Positive/negative doc contracts and live package-status evidence in planning artifacts. [VERIFIED: curl Hex API, 78-CONTEXT.md] |
| Leaking publish credentials in docs or test output | Information Disclosure | Keep `HEX_API_KEY` only in workflow env and avoid printing secret values. [VERIFIED: .github/workflows/release.yml] |
| Shell injection through manual publish refs | Tampering / Elevation of Privilege | Existing recovery workflow validates input as existing git tag or 40-character SHA before checkout. [VERIFIED: .github/workflows/publish-hex.yml] |

## Sources

### Primary (HIGH confidence)

- `AGENTS.md` - project stack, quality gates, and package/docs constraints. [VERIFIED: AGENTS.md]
- `.planning/phases/78-release-and-package-truth/78-CONTEXT.md` - locked Phase 78 decisions and boundaries. [VERIFIED: 78-CONTEXT.md]
- `.planning/REQUIREMENTS.md` - TRUTH-01, TRUTH-02, TRUTH-03 definitions. [VERIFIED: .planning/REQUIREMENTS.md]
- `.planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md` - package model and drift inventory. [VERIFIED: Phase 77 artifact]
- `mix.exs`, release workflows, README, guides, contract tests - current codebase truth surfaces. [VERIFIED: repo inspection]
- Local commands: `mix hex.build --unpack`, `mix help hex.build`, `mix help hex.publish`, `mix test ...`. [VERIFIED: local command output]

### Secondary (MEDIUM confidence)

- Hex publish docs - package metadata, `:files`, CI publish guidance. [CITED: https://hex.pm/docs/publish]
- Hex task docs - `mix hex.publish --dry-run`, package config, unpack inspection. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html]
- ExDoc docs and installed source - `source_url`, `source_ref`, `source_url_pattern`. [CITED: https://hexdocs.pm/ex_doc/0.30.3/Mix.Tasks.Docs.html] [VERIFIED: deps/ex_doc/lib/ex_doc.ex]
- Release Please manifest docs - manifest versions and tag naming. [CITED: https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md]
- Release Please action docs - `config-file`, `manifest-file`, package option mapping. [CITED: https://github.com/googleapis/release-please-action]
- Hex API specifications - HTTP API and package-browsing purpose. [CITED: https://github.com/hexpm/specifications/blob/main/endpoints.md]
- Live Hex/GitHub curl checks from 2026-07-03. [VERIFIED: curl commands]

### Tertiary (LOW confidence)

- None used as a primary basis. [VERIFIED: research log]

## Metadata

**Confidence breakdown:**

- Standard stack: MEDIUM - local versions and official docs were verified, but Context7 was unavailable and `ctx7` fallback was missing. [VERIFIED: environment audit]
- Architecture: HIGH - based on locked Phase 78 decisions and current repo test/workflow structure. [VERIFIED: 78-CONTEXT.md, repo inspection]
- Pitfalls: HIGH for the `sigra` build blocker and stale URL/sibling status drift; MEDIUM for recommended remediation strategy. [VERIFIED: local build probe, repo grep, curl API] [ASSUMED]

**Research date:** 2026-07-03
**Valid until:** 2026-08-02 for local architecture; re-check live Hex/GitHub package status within 7 days before implementation or release. [ASSUMED]

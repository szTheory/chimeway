# Phase 77: Truth Baseline and Package Model Decision - Pattern Map

**Mapped:** 2026-07-02
**Files analyzed:** 1 new/modified implementation artifact
**Analogs found:** 1 / 1

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `.planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md` | config (planning artifact) | transform | `.planning/PROJECT.md` | role-match |

Phase 77 is planning-artifact focused. The planner should create the decision/baseline artifact only; public package metadata, README, guides, workflows, maintainer docs, and source files are evidence inputs for the table, not edit targets in this phase.

## Pattern Assignments

### `.planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md` (config, transform)

**Primary analog:** `.planning/PROJECT.md`

**Supporting analogs:** `.planning/ROADMAP.md`, `.planning/phases/77-truth-baseline-and-package-model-decision/77-VALIDATION.md`, `mix.exs`, `release-please-config.json`, `.release-please-manifest.json`, `test/chimeway/release_gate_contract_test.exs`, `test/chimeway/doc_contract_test.exs`

**Purpose pattern:** transform locked decisions plus package/docs/CI evidence into one phase-local decision record. Do not implement Phase 78-80 edits here.

**Phase boundary pattern** (`.planning/ROADMAP.md` lines 62-72):

```markdown
### Phase 77: Truth Baseline and Package Model Decision

**Goal:** Record the root-only package model and milestone-vs-package tag namespace, identify sibling package install status as Phase 78 input, and baseline public truth drift across docs, package metadata, release manifests, changelog, workflows, and maintainer docs before broad edits.

**Requirements:** TRUTH-04

**Success Criteria**:
1. A decision record or equivalent planning artifact names the package model.
2. The artifact names the tag namespace and root package release rule.
3. The artifact names delivery owners for package, docs, and CI truth.
4. The baseline inventory captures README, guides, mix metadata, release manifests, changelog, workflows, and maintainer docs drift.
```

**Decision-table pattern** (`.planning/PROJECT.md` lines 251-254 and 311-314):

```markdown
## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Root-only Hex package for v1.14 truth cleanup | Only root `chimeway` is currently published; advertising sibling packages as Hex releases would create adopter confusion | Pending v1.14 validation |
| Separate planning milestones from package release tags | Planning `v1.x` history and SemVer package releases carry different meanings and should not be conflated | Pending v1.14 validation |
| Two-tier CI gate model | Contributors need fast PR feedback; maintainers still need full release confidence before publish/automerge | Pending v1.14 validation |
| README as adoption decision page | The first public surface should answer adopter JTBD and prove explainability, not expose internals or stale stub links | Pending v1.14 validation |
```

Copy this table style for the `## Decision` section, but make the outcome explicit for Phase 77, for example "Recorded for Phase 78", "Recorded for Phase 79", or "Recorded for Phase 80".

**Scope guard / validation pattern** (`77-VALIDATION.md` lines 16-24 and 30-43):

```markdown
| **Framework** | ExUnit through Mix for release-contract surfaces; source assertions for the phase-local decision artifact. |
| **Quick run command** | `rg -n "chimeway|chimeway_admin|chimeway_inbox|v1\\.14|v1\\.0\\.0|Release Please|HexDocs|source_ref" .planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md` |
| **Full suite command** | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` |

- **After every task commit:** Run the quick `rg` assertion against `77-PACKAGE-MODEL-DECISION.md`.
- **After every plan wave:** Run `git diff --name-only -- README.md mix.exs CHANGELOG.md .github/workflows MAINTAINING.md guides` and confirm it is empty for Phase 77.
```

The planner should copy this into acceptance checks. It is the main guard that Phase 77 stays a planning artifact and does not drift into public edits.

**Baseline inventory table pattern** (`77-RESEARCH.md` lines 314-316):

```markdown
## Baseline Drift Inventory

| Surface | Current State | Expected Truth / Rule | Downstream Owner | Evidence |
|---------|---------------|-----------------------|------------------|----------|
```

Use one row per truth surface. Required rows include `README.md`, `CONTRIBUTING.md`, `mix.exs`, `.release-please-manifest.json`, `release-please-config.json`, `CHANGELOG.md`, `.github/workflows/release.yml`, `.github/workflows/publish-hex.yml`, `.github/workflows/ci.yml`, `MAINTAINING.md`, `guides/introduction/admin-console-integration.md`, `guides/introduction/inbox-integration.md`, `chimeway_admin/mix.exs`, `chimeway_inbox/mix.exs`, and release-gate contracts.

**Root package metadata evidence pattern** (`mix.exs` lines 4-17 and 203-216):

```elixir
@version "1.0.0"

def project do
  [
    app: :chimeway,
    version: @version,
    elixir: "~> 1.17",
    package: package(),
    docs: docs()
  ]
end

defp package do
  [
    files: ~w(lib priv guides CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs),
    licenses: ["MIT"],
    links: %{"GitHub" => "https://github.com/jonlunsford/chimeway"}
  ]
end

defp docs do
  [
    main: "Chimeway",
    source_ref: "v#{@version}",
    source_url: "https://github.com/jonlunsford/chimeway",
```

The decision artifact should record that `@version`, package metadata, docs `source_ref`, docs `source_url`, and repository links are Phase 78 evidence. Do not change `mix.exs` in Phase 77.

**Release Please root-package pattern** (`release-please-config.json` lines 12-18 and `.release-please-manifest.json` lines 1-3):

```json
"packages": {
  ".": {
    "changelog-path": "CHANGELOG.md",
    "include-v-in-tag": true
  }
}
```

```json
{
  ".": "1.0.0"
}
```

Use this as the evidence for root-only Release Please identity and root package SemVer tags such as `v1.0.0`.

**Release workflow evidence pattern** (`.github/workflows/release.yml` lines 1-4, 82-89, and 281-289):

```yaml
# Release Please opens/updates a Release PR from conventional commits on main.
# When that PR is merged, Release Please creates the GitHub Release + v* tag,
# gate-ci-green verifies CI passed on the release SHA, then publish-hex publishes
# to Hex with HEX_API_KEY.

- name: Run Release Please
  id: release
  uses: googleapis/release-please-action@0dfd8538845b8e92600d271a895a5372865d4062
  with:
    config-file: release-please-config.json
    manifest-file: .release-please-manifest.json

- name: Verify release version in mix.exs
  run: grep -n "@version \"${RELEASE_VERSION}\"" mix.exs

- name: Pre-publish gate replay
  run: |
    mix ci.verify_gates
    mix ci.docs
```

Record this as evidence that package release refs come from Release Please/root package output, not planning milestone labels.

**Manual recovery ref pattern** (`.github/workflows/publish-hex.yml` lines 1-17 and 45-62):

```yaml
# Manual recovery: publish an already-tagged (or pinned SHA) revision to Hex when
# automation did not run or needs a one-off retry. Default path is Release Please
# (`.github/workflows/release.yml`) on merge of the Release PR.

inputs:
  tag:
    description: 'Git tag or commit SHA to publish from (e.g. v1.1.0).'
  release_version:
    description: 'Expected @version string in mix.exs at that ref (e.g. 1.1.0).'

- name: Validate ref and resolve SHA
  run: |
    ref="${{ github.event.inputs.tag }}"
    if [[ "$ref" =~ ^[0-9a-f]{40}$ ]]; then
      git cat-file -e "${ref}^{commit}"
    elif git show-ref --verify --quiet "refs/tags/$ref"; then
      sha="$(git rev-list -n 1 "$ref")"
    else
      echo "tag must be a 40-character commit SHA or an existing git tag" >&2
      exit 1
    fi
```

Use this as evidence that publish recovery accepts package tags or SHAs. The decision artifact should explicitly say planning labels such as `v1.14` are not publish refs.

**Sibling preview/path package evidence pattern** (`chimeway_admin/mix.exs` lines 4-27 and `chimeway_inbox/mix.exs` lines 4-25):

```elixir
def project do
  [
    app: :chimeway_admin,
    version: "0.1.0",
    elixir: "~> 1.17",
    deps: deps()
  ]
end

defp deps do
  [
    {:oban, "~> 2.17"},
    {:chimeway, path: ".."},
```

```elixir
def project do
  [
    app: :chimeway_inbox,
    version: "0.1.0",
    elixir: "~> 1.17",
    deps: deps()
  ]
end

defp deps do
  [
    {:oban, "~> 2.17"},
    {:chimeway, path: ".."},
```

Use these rows to record sibling package status as in-repo preview/path packages. Do not add package/docs metadata or publish automation in Phase 77.

**Public drift evidence snippets to baseline, not edit:**

`README.md` lines 5-16:

```markdown
[![Hex.pm](https://img.shields.io/hexpm/v/chimeway.svg)](https://hex.pm/packages/chimeway)
[![CI](https://github.com/jonlunsford/chimeway/actions/workflows/ci.yml/badge.svg)](https://github.com/jonlunsford/chimeway/actions/workflows/ci.yml)

Add `chimeway` to your `mix.exs` dependencies:

{:chimeway, "~> 1.0"}
```

`CONTRIBUTING.md` lines 7-10:

```markdown
1. Clone the repository and install dependencies:
   ```bash
   git clone https://github.com/jonlunsford/chimeway.git
```

`guides/introduction/admin-console-integration.md` lines 15-26:

```markdown
Add Chimeway and `chimeway_admin` to your host `mix.exs`:

{:chimeway, "~> 1.0"},
{:chimeway_admin, "~> 1.0"}
```

`guides/introduction/inbox-integration.md` lines 15-28:

```markdown
Add Chimeway and `chimeway_inbox` to your host `mix.exs`:

{:chimeway, "~> 1.0"},
{:chimeway_inbox, path: "../chimeway_inbox"}

When `chimeway_inbox` is published to hex, replace the path dependency with `{:chimeway_inbox, "~> 1.0"}`.
```

These snippets belong in the baseline inventory with downstream owners, not as direct Phase 77 edits.

**Contract-test anchor pattern** (`test/chimeway/release_gate_contract_test.exs` lines 222-246 and 323-341):

```elixir
test "manifest version matches mix.exs @version" do
  manifest_content = File.read!(@manifest)
  mix_exs = File.read!(@mix_exs)

  manifest_version =
    case Regex.run(~r/"\."\s*:\s*"([^"]+)"/, manifest_content) do
      [_, version] -> version
      _ -> flunk("Could not parse version from #{@manifest}")
    end

  assert Regex.match?(~r/@version\s+"#{Regex.escape(manifest_version)}"/, mix_exs),
         "manifest #{manifest_version} must match mix.exs @version"
end

test "release.yml pre-publish replay includes verify_gates and docs", %{
  release_yml: release_yml
} do
  assert String.contains?(release_yml, "mix ci.verify_gates")
  assert String.contains?(release_yml, "mix ci.docs")
end
```

```elixir
defp extract_ci_job_block(yml, job_id) do
  case Regex.run(~r/#{job_id}:(.*?)(?:\n  [a-z_]+:|\z)/s, yml) do
    [_, block] -> block
    _ -> flunk("Could not extract #{job_id} job block from #{yml}")
  end
end

defp extract_ci_gate_needs(ci_yml) do
  case Regex.run(~r/ci-gate:.*?needs:\s*\[(.*?)\]/s, ci_yml) do
    [_, needs_str] ->
      needs_str
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    _ ->
      flunk("Could not extract ci-gate needs from ci.yml")
  end
end
```

Phase 77 should cite this as the downstream contract-test anchor for Phase 78/80. It should not add a parallel shell checker.

**Docs-contract anchor pattern** (`test/chimeway/doc_contract_test.exs` lines 1353-1374):

```elixir
describe "hexdocs extras doc contract" do
  setup do
    content = File.read!("mix.exs")
    %{content: content}
  end

  @integration_guides ~w(
    guides/introduction/storage-prefix-upgrade.md
    guides/introduction/mailglass-integration.md
    guides/introduction/accrue-dunning-integration.md
    guides/introduction/admin-console-integration.md
    guides/introduction/inbox-integration.md
    guides/introduction/threadline-integration.md
    guides/introduction/sigra-auth-integration.md
  )

  for guide <- @integration_guides do
    test "requires #{guide} in HexDocs extras", %{content: content} do
      assert String.contains?(content, unquote(guide)),
             "mix.exs HexDocs extras must include #{unquote(guide)}"
    end
  end
end
```

Phase 79 should use this existing doc-contract style for front-door docs truth; Phase 77 should only record the gap and owner.

## Shared Patterns

### Narrow Planning Artifact Scope

**Source:** `.planning/ROADMAP.md` lines 64-72 and `77-VALIDATION.md` lines 30-32  
**Apply to:** `77-PACKAGE-MODEL-DECISION.md`

The artifact should contain decisions, owner mapping, and baseline drift inventory. Public docs, package metadata, release workflows, maintainer docs, and guides stay read-only evidence in Phase 77.

### Root Package Release Identity

**Source:** `mix.exs` lines 4-17 and 203-216; `.release-please-manifest.json` lines 1-3; `release-please-config.json` lines 12-18  
**Apply to:** Decision section and baseline rows for package/release truth

Root `chimeway` package identity is `mix.exs @version`, Release Please manifest `"."`, Release Please package config, Hex package version, and ExDoc `source_ref: "v#{@version}"`.

### Milestone vs Package Namespace

**Source:** `.planning/PROJECT.md` lines 311-312; `.github/workflows/release.yml` lines 82-89 and 281-289; `.github/workflows/publish-hex.yml` lines 12-17 and 45-62  
**Apply to:** Decision section and validation grep

Package release refs are root package SemVer tags or SHAs. Planning labels such as `v1.14` are planning identifiers only and must not become HexDocs refs, publish refs, changelog anchors, or GitHub release names.

### Evidence-First Drift Inventory

**Source:** `77-RESEARCH.md` lines 314-316; public drift snippets above  
**Apply to:** Baseline table in `77-PACKAGE-MODEL-DECISION.md`

Use columns `Surface`, `Current State`, `Expected Truth / Rule`, `Downstream Owner`, and `Evidence`. Each row should name Phase 78, Phase 79, or Phase 80 as owner.

### Existing Contract Tests Before New Checkers

**Source:** `test/chimeway/release_gate_contract_test.exs` lines 222-246 and `test/chimeway/doc_contract_test.exs` lines 1353-1374  
**Apply to:** Validation notes and downstream handoff rows

Point Phase 78/79/80 at existing ExUnit contract-test style. Phase 77 should not add a new runtime checker unless the planner explicitly expands the phase scope.

## No Analog Found

No implementation file lacks an analog. There is no prior exact phase-local package-model decision record, but `.planning/PROJECT.md` provides the decision-table pattern and `77-RESEARCH.md` provides the exact baseline-inventory table shape.

## Metadata

**Analog search scope:** `.planning/`, `mix.exs`, `test/chimeway/*contract_test.exs`, `.github/workflows/*.yml`, `README.md`, `CONTRIBUTING.md`, `MAINTAINING.md`, `guides/introduction/*`, `chimeway_admin/mix.exs`, `chimeway_inbox/mix.exs`, Release Please manifest/config files  
**Files scanned:** 20 direct reads plus `rg` searches across planning, docs, tests, Mix metadata, and workflows  
**Strong analogs selected:** 8 source/evidence files  
**Pattern extraction date:** 2026-07-02

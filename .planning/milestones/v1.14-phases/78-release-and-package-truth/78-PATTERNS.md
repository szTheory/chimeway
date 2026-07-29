# Phase 78: Release and Package Truth - Pattern Map

**Mapped:** 2026-07-03
**Files analyzed:** 13 phase-owned source surfaces
**Analogs found:** 13 / 13

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `mix.exs` | config | transform + file-I/O | `mix.exs` | exact |
| `.release-please-manifest.json` | config | transform | `.release-please-manifest.json` + `release-please-config.json` | exact |
| `release-please-config.json` | config | event-driven release automation | `release-please-config.json` | exact |
| `CHANGELOG.md` | documentation/config | transform | `CHANGELOG.md` | exact |
| `README.md` | documentation | transform | `test/chimeway/doc_contract_test.exs` README contract | exact |
| `guides/introduction/admin-console-integration.md` | documentation | transform | `test/chimeway/doc_contract_test.exs` admin guide contract | exact |
| `guides/introduction/inbox-integration.md` | documentation | transform | `test/chimeway/doc_contract_test.exs` inbox guide contract | exact |
| `.github/workflows/release.yml` | config | event-driven release automation | `.github/workflows/release.yml` + release gate contract | exact |
| `.github/workflows/publish-hex.yml` | config | event-driven release automation | `.github/workflows/publish-hex.yml` + release gate contract | exact |
| `test/chimeway/release_gate_contract_test.exs` | test | file-I/O + transform | `test/chimeway/release_gate_contract_test.exs` | exact |
| `test/chimeway/doc_contract_test.exs` | test | file-I/O + transform | `test/chimeway/doc_contract_test.exs` | exact |
| `chimeway_admin/mix.exs` | config/evidence | dependency graph transform | `chimeway_admin/mix.exs` | evidence-only |
| `chimeway_inbox/mix.exs` | config/evidence | dependency graph transform | `chimeway_inbox/mix.exs` | evidence-only |

`chimeway_admin/mix.exs` and `chimeway_inbox/mix.exs` should normally be read and contract-tested, not edited. Phase 78 keeps them as in-repo preview/path packages and does not add sibling package metadata or publish lanes.

## Pattern Assignments

### `mix.exs` (config, transform + file-I/O)

**Analog:** `mix.exs`

**Project identity pattern** (lines 1-18):

```elixir
defmodule Chimeway.MixProject do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :chimeway,
      version: @version,
      elixir: "~> 1.17",
      deps: deps(),
      aliases: aliases(),
      description: "Explainable, durable notification library for Elixir.",
      package: package(),
      docs: docs()
    ]
  end
```

**Package/artifact alias pattern** (lines 85-89):

```elixir
# Post-publish verify trio (run locally by maintainer, not in pre-merge CI)
"verify.clean": ["cmd git diff --exit-code"],
"verify.parity": [
  "cmd mix hex.build --unpack --output /tmp/chimeway_verify && ls /tmp/chimeway_verify"
],
```

**Optional dependency skip pattern to preserve** (lines 185-199):

```elixir
defp sigra_deps do
  if System.get_env("CHIMEWAY_SKIP_SIGRA_DEP") in ["1", "true"] or
       System.get_env("CHIMEWAY_SKIP_SIGRA_TRANSITIVE_DEP") in ["1", "true"] do
    []
  else
    [sigra_dep()]
  end
end

defp sigra_dep do
  # Local dev: SIGRA_PATH=../sigra mix deps.get
  # override: true resolves ecto 3.12 vs 3.11 diamond; inert for adopters (optional transitives not pulled)
  case System.get_env("SIGRA_PATH") do
    nil -> {:sigra, "~> 0.3", optional: true, runtime: false, override: true}
    path -> {:sigra, path: path, optional: true, runtime: false, override: true}
  end
end
```

**Package/docs metadata pattern** (lines 203-216):

```elixir
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

**Planner action:** keep `@version`, package version, Release Please manifest, README install constraint, and `source_ref: "v#{@version}"` aligned. Normalize package/docs links to `https://github.com/szTheory/chimeway`. Fix the default `mix hex.build --unpack` blocker so `verify.parity` and release workflows do not require an undocumented local-only env.

---

### `.release-please-manifest.json` (config, transform)

**Analog:** `.release-please-manifest.json`

**Root manifest pattern** (lines 1-3):

```json
{
  ".": "1.0.0"
}
```

**Contract pattern:** copy the release-gate manifest parity shape from `test/chimeway/release_gate_contract_test.exs` lines 222-234:

```elixir
manifest_content = File.read!(@manifest)
mix_exs = File.read!(@mix_exs)

manifest_version =
  case Regex.run(~r/"\."\s*:\s*"([^"]+)"/, manifest_content) do
    [_, version] -> version
    _ -> flunk("Could not parse version from #{@manifest}")
  end

assert Regex.match?(~r/@version\s+"#{Regex.escape(manifest_version)}"/, mix_exs),
       "manifest #{manifest_version} must match mix.exs @version"
```

**Planner action:** preserve root-only `{ ".": version }`. Do not add sibling package entries.

---

### `release-please-config.json` (config, event-driven release automation)

**Analog:** `release-please-config.json`

**Root package config pattern** (lines 1-18):

```json
{
  "release-type": "elixir",
  "bump-minor-pre-major": false,
  "bump-patch-for-minor-pre-major": false,
  "changelog-sections": [
    {"type": "feat", "section": "Features"},
    {"type": "fix", "section": "Bug Fixes"},
    {"type": "perf", "section": "Performance Improvements"},
    {"type": "deps", "section": "Dependencies"},
    {"type": "chore", "section": "Miscellaneous", "hidden": true}
  ],
  "packages": {
    ".": {
      "changelog-path": "CHANGELOG.md",
      "include-v-in-tag": true
    }
  }
}
```

**Planner action:** keep `packages` root-only and `include-v-in-tag: true`. Add release-gate assertions here rather than adding a new shell checker. Prefer `Jason.decode!` for new nested JSON assertions because `jason` is already a dependency.

---

### `CHANGELOG.md` (documentation/config, transform)

**Analog:** `CHANGELOG.md`

**Package SemVer release section pattern** (lines 1-11):

````markdown
# Changelog

All notable changes to this project will be documented in this file.
Format: [Conventional Commits](https://www.conventionalcommits.org/).

## 1.0.0 (2026-05-08)


### Features

* **08-01:** merge dispatcher outcomes into trigger response ([c449ee4](https://github.com/szTheory/chimeway/commit/c449ee4454d64c33cb556a7a62024c351de4f945))
````

**Planner action:** preserve package SemVer release headings such as `1.0.0`, not planning labels such as `v1.14`. Keep commit/source links canonical to `https://github.com/szTheory/chimeway`.

---

### `README.md` (documentation, transform)

**Analog:** `test/chimeway/doc_contract_test.exs` README install contract

**Current package-facing README pattern** (README lines 5-16):

````markdown
[![Hex.pm](https://img.shields.io/hexpm/v/chimeway.svg)](https://hex.pm/packages/chimeway)
[![CI](https://github.com/jonlunsford/chimeway/actions/workflows/ci.yml/badge.svg)](https://github.com/jonlunsford/chimeway/actions/workflows/ci.yml)

## Installation

Add `chimeway` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:chimeway, "~> 1.0"}
````

**README contract pattern** (`test/chimeway/doc_contract_test.exs` lines 1241-1301):

```elixir
describe "README install doc contract (GATE-01)" do
  setup do
    content = File.read!("README.md")
    %{content: content}
  end

  for forbidden <- @adoption_forbidden_strings do
    test "forbids #{forbidden} in README", %{content: content} do
      refute String.contains?(content, unquote(forbidden)),
             "README must not reference #{unquote(forbidden)}"
    end
  end

  @required ~w(
    mix chimeway.gen.migrations
    Chimeway.trigger
    idempotency_key
    tenant_id
    golden-path
    guides/introduction/mailglass-integration.md
    guides/introduction/accrue-dunning-integration.md
    guides/introduction/inbox-integration.md
  )

  for required <- @required do
    test "requires #{required} in README", %{content: content} do
      assert String.contains?(content, unquote(required)),
             "README must reference #{unquote(required)}"
    end
  end
end
```

**Version alignment pattern** (`test/chimeway/doc_contract_test.exs` lines 1507-1518):

```elixir
mix_content = File.read!("mix.exs")
[_, version] = Regex.run(~r/@version "([^"]+)"/, mix_content)
[major, minor, _patch] = String.split(version, ".")
expected = "{:chimeway, \"~> #{major}.#{minor}\"}"

for path <- @consumer_files do
  content = File.read!(path)

  assert String.contains?(content, expected),
         "#{path} must include #{expected} aligned with mix.exs @version #{version}"
end
```

**Planner action:** update only package-facing README truth owned by Phase 78: badge/source URLs and install constraint. Leave broad first-hop README rewrite to Phase 79.

---

### `guides/introduction/admin-console-integration.md` (documentation, transform)

**Analog:** `test/chimeway/doc_contract_test.exs` admin guide contract

**Current dependency snippet to replace** (guide lines 15-32):

````markdown
## 1. Dependencies

Add Chimeway and `chimeway_admin` to your host `mix.exs`:

```elixir
def deps do
  [
    {:chimeway, "~> 1.0"},
    {:chimeway_admin, "~> 1.0"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```
````

**Admin guide contract pattern** (`test/chimeway/doc_contract_test.exs` lines 289-373):

```elixir
describe "admin integration guide doc contract (DOCS-12)" do
  setup do
    content = File.read!(@admin_integration_guide)
    %{content: content}
  end

  @admin_guide_required_strings [
    "Command Center",
    "Trace Lookup",
    "Trace Detail",
    "Feed Debug",
    "Definitions",
    "Health",
    "Recovery",
    "/admin/chimeway",
    "chimeway_admin_routes()",
    "config :chimeway_admin, auth_module: MyApp.AdminAuth",
    "mix verify.admin"
  ]

  for required <- @admin_guide_required_strings do
    test "requires #{required} in admin integration guide", %{content: content} do
      assert String.contains?(content, unquote(required)),
             "admin integration guide must reference #{unquote(required)}"
    end
  end

  @admin_guide_forbidden_strings [
    "trace lookup only",
    "code-registry",
    "generic CRUD",
    "template editing"
  ]

  for forbidden <- @admin_guide_forbidden_strings do
    test "forbids #{forbidden} in admin integration guide", %{content: content} do
      refute String.contains?(content, unquote(forbidden)),
             "admin integration guide must not reintroduce stale or unsafe admin claim: #{unquote(forbidden)}"
    end
  end
end
```

**Planner action:** replace the Hex dependency claim with preview/path package language and a path dependency snippet. Extend the contract with explicit negative checks for `{:chimeway_admin, "~> 1.0"}` and positive checks for "in-repo preview/path package" and "not published on Hex yet" or equivalent wording.

---

### `guides/introduction/inbox-integration.md` (documentation, transform)

**Analog:** `test/chimeway/doc_contract_test.exs` inbox guide contract

**Current path dependency pattern plus future-publish copy to tighten** (guide lines 15-29):

````markdown
## 1. Dependencies

Add Chimeway and `chimeway_inbox` to your host `mix.exs`:

```elixir
def deps do
  [
    {:chimeway, "~> 1.0"},
    {:chimeway_inbox, path: "../chimeway_inbox"}
  ]
end
```

When `chimeway_inbox` is published to hex, replace the path dependency with `{:chimeway_inbox, "~> 1.0"}`. Both packages live in the Chimeway monorepo today — no sibling checkout is required (unlike Accrue integration).
````

**Inbox guide contract pattern** (`test/chimeway/doc_contract_test.exs` lines 751-836):

```elixir
describe "inbox integration guide doc contract (DOCS-08 / DOCS-09)" do
  setup do
    content = File.read!(@inbox_integration_guide)
    %{content: content}
  end

  test "forbids Chimeway.Inbox direct module calls in inbox integration guide",
       %{content: content} do
    refute String.contains?(content, "Chimeway.Inbox."),
           "inbox integration guide must use public Chimeway.* delegates only"
  end

  @required ~w(
    ChimewayInbox.Auth
    chimeway_inbox_routes
    config :chimeway_inbox
    auth_module
    Chimeway.unread_count
    Chimeway.list_for_recipient
    Chimeway.mark_read
    Chimeway.mark_seen
    BellDropdownLive
    mix verify.inbox
    DemoHost.Seeds.seed_inbox
    /inbox
  )

  for required <- @required do
    test "requires #{required} in inbox integration guide", %{content: content} do
      assert String.contains?(content, unquote(required)),
             "inbox integration guide must reference #{unquote(required)}"
    end
  end
end
```

**Planner action:** keep the path dependency, but remove or qualify current-published Hex wording. Extend contracts to forbid `{:chimeway_inbox, "~> 1.0"}` as current install guidance and require preview/path status language.

---

### `.github/workflows/release.yml` (config, event-driven release automation)

**Analog:** `.github/workflows/release.yml`

**Release Please root manifest pattern** (lines 82-90):

```yaml
- name: Run Release Please
  id: release
  if: ${{ steps.release-preflight.outputs.should_run == 'true' }}
  uses: googleapis/release-please-action@0dfd8538845b8e92600d271a895a5372865d4062
  with:
    token: ${{ secrets.RELEASE_PLEASE_TOKEN || secrets.GITHUB_TOKEN }}
    config-file: release-please-config.json
    manifest-file: .release-please-manifest.json
```

**Publish job root package pattern** (lines 243-292):

```yaml
publish-hex:
  name: Publish to Hex.pm
  runs-on: ubuntu-latest
  needs: [release-please, gate-ci-green]
  if: ${{ needs.release-please.outputs.release_created == 'true' }}
  permissions:
    contents: read
  env:
    RELEASE_VERSION: ${{ needs.release-please.outputs.version }}
  steps:
    - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
      with:
        ref: ${{ needs.release-please.outputs.tag_name }}

    - name: Verify release version in mix.exs
      run: grep -n "@version \"${RELEASE_VERSION}\"" mix.exs

    - name: Pre-publish gate replay
      env:
        MIX_ENV: test
      run: |
        mix ci.verify_gates
        mix ci.docs

    - name: Build Hex package
      run: mix hex.build
```

**Release-gate workflow assertion pattern** (`test/chimeway/release_gate_contract_test.exs` lines 236-250):

```elixir
test "release.yml contains gate-ci-green and ci-gate poll", %{release_yml: release_yml} do
  assert String.contains?(release_yml, "gate-ci-green")
  assert String.contains?(release_yml, "ci-gate")
end

test "release.yml pre-publish replay includes verify_gates and docs", %{
  release_yml: release_yml
} do
  assert String.contains?(release_yml, "mix ci.verify_gates")
  assert String.contains?(release_yml, "mix ci.docs")
end

test "release.yml publish-hex needs gate-ci-green", %{release_yml: release_yml} do
  publish_block = extract_ci_job_block(release_yml, "publish-hex")
  assert String.contains?(publish_block, "gate-ci-green")
end
```

**Planner action:** keep root-only publish from the release tag. Do not add sibling publish jobs. If the package build fix needs env changes, keep release workflow and `verify.parity` behavior in parity.

---

### `.github/workflows/publish-hex.yml` (config, event-driven release automation)

**Analog:** `.github/workflows/publish-hex.yml`

**Manual recovery ref validation pattern** (lines 45-62):

```yaml
- name: Validate ref and resolve SHA
  id: validate
  run: |
    set -euo pipefail
    ref="${{ github.event.inputs.tag }}"

    if [[ "$ref" =~ ^[0-9a-f]{40}$ ]]; then
      git cat-file -e "${ref}^{commit}"
      echo "checkout_ref=$ref" >> "$GITHUB_OUTPUT"
      echo "sha=$ref" >> "$GITHUB_OUTPUT"
    elif git show-ref --verify --quiet "refs/tags/$ref"; then
      sha="$(git rev-list -n 1 "$ref")"
      echo "checkout_ref=$ref" >> "$GITHUB_OUTPUT"
      echo "sha=$sha" >> "$GITHUB_OUTPUT"
    else
      echo "tag must be a 40-character commit SHA or an existing git tag" >&2
      exit 1
    fi
```

**Manual publish root package pattern** (lines 171-188):

```yaml
- name: Verify release version in mix.exs
  run: grep -n "@version \"${RELEASE_VERSION}\"" mix.exs

- name: Fetch library deps
  run: mix deps.get

- name: Compile (warnings as errors)
  run: mix compile --warnings-as-errors

- name: Pre-publish gate replay
  env:
    MIX_ENV: test
  run: |
    mix ci.verify_gates
    mix ci.docs

- name: Build Hex package
  run: mix hex.build
```

**Planner action:** keep manual recovery scoped to root `chimeway` and package tags/SHAs. Do not accept planning labels as publish refs.

---

### `test/chimeway/release_gate_contract_test.exs` (test, file-I/O + transform)

**Analog:** `test/chimeway/release_gate_contract_test.exs`

**Module setup/import pattern** (lines 1-24):

```elixir
defmodule Chimeway.ReleaseGateContractTest do
  use ExUnit.Case, async: true

  @moduledoc false

  @maintaining "MAINTAINING.md"
  @mix_exs "mix.exs"
  @ci_yml ".github/workflows/ci.yml"
  @release_yml ".github/workflows/release.yml"
  @manifest ".release-please-manifest.json"
  @publish_hex_yml ".github/workflows/publish-hex.yml"
  @ci_gate_lanes ~w(lint test verify_gates verify_docs verify_example verify_runtime_prefix verify_journeys verify_mailglass verify_accrue verify_inbox verify_threadline verify_sigra verify_admin)
```

**File-backed setup pattern** (lines 173-186):

```elixir
describe "release pipeline contract (GATE-06)" do
  setup do
    ci_yml = File.read!(@ci_yml)
    release_yml = File.read!(@release_yml)
    maintaining = File.read!(@maintaining)
    publish_hex_yml = File.read!(@publish_hex_yml)

    %{
      ci_yml: ci_yml,
      release_yml: release_yml,
      maintaining: maintaining,
      publish_hex_yml: publish_hex_yml
    }
  end
```

**Core contract pattern** (lines 222-262):

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

test "publish-hex recovery exists and gates on ci-gate only", %{
  publish_hex_yml: publish_hex_yml
} do
  assert String.contains?(publish_hex_yml, "ci-gate")
  refute String.contains?(publish_hex_yml, "requiredPrefixes")
end
```

**Helper pattern** (lines 323-341):

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

**Subprocess/artifact support analog:** no exact existing Hex artifact ExUnit test exists. Use the local `System.cmd`/tmp cleanup style from `test/chimeway/install/migrations_test.exs` lines 386-449:

```elixir
unique = Integer.to_string(System.unique_integer([:positive]))
tmp = Path.join(System.tmp_dir!(), "chimeway_install_" <> unique)

on_exit(fn -> File.rm_rf!(tmp) end)

defp run_mix(tmp, args) do
  System.cmd("mix", args,
    cd: tmp,
    stderr_to_stdout: true,
    env: [{"MIX_ENV", "dev"}]
  )
end
```

**Planner action:** extend this file for TRUTH-01 and TRUTH-02: root package metadata, source URL/ref, Release Please root-only config, workflow package publish path, stale URL guards, and `mix hex.build --unpack` artifact proof. Keep tests deterministic and file-backed; avoid default live network checks.

---

### `test/chimeway/doc_contract_test.exs` (test, file-I/O + transform)

**Analog:** `test/chimeway/doc_contract_test.exs`

**Positive/negative doc contract pattern** (admin guide lines 289-373):

```elixir
describe "admin integration guide doc contract (DOCS-12)" do
  setup do
    content = File.read!(@admin_integration_guide)
    %{content: content}
  end

  for required <- @admin_guide_required_strings do
    test "requires #{required} in admin integration guide", %{content: content} do
      assert String.contains?(content, unquote(required)),
             "admin integration guide must reference #{unquote(required)}"
    end
  end

  for forbidden <- @admin_guide_forbidden_strings do
    test "forbids #{forbidden} in admin integration guide", %{content: content} do
      refute String.contains?(content, unquote(forbidden)),
             "admin integration guide must not reintroduce stale or unsafe admin claim: #{unquote(forbidden)}"
    end
  end
end
```

**HexDocs extras contract pattern** (lines 1353-1374):

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
```

**Version drift guard pattern** (lines 1521-1537):

```elixir
test "forbids stale version drift in consumer docs" do
  mix_content = File.read!("mix.exs")
  [_, version] = Regex.run(~r/@version "([^"]+)"/, mix_content)
  [major, minor, _patch] = String.split(version, ".")

  stale_patterns = stale_drift_patterns(major, minor)

  for path <- @consumer_files do
    content = File.read!(path)

    for pattern <- stale_patterns do
      refute String.contains?(content, pattern),
             "#{path} must not contain stale drift pattern #{inspect(pattern)}"
    end

    refute Regex.match?(~r/\{:chimeway,\s*"~>\s*\d+\.\d+\.\d+"/, content),
           "#{path} must use ~> MAJOR.MINOR, not a patch-level constraint"
  end
end
```

**Planner action:** extend this file for TRUTH-03 sibling preview/path language and Phase 78-owned README/package URL copy. Use explicit `refute String.contains?` checks for stale sibling Hex snippets.

---

### `chimeway_admin/mix.exs` (config/evidence, dependency graph transform)

**Analog:** `chimeway_admin/mix.exs`

**Preview/path package evidence pattern** (lines 4-27):

```elixir
def project do
  [
    app: :chimeway_admin,
    version: "0.1.0",
    elixir: "~> 1.17",
    elixirc_paths: elixirc_paths(Mix.env()),
    start_permanent: Mix.env() == :prod,
    deps: deps()
  ]
end

defp deps do
  [
    # Oban modules compile from chimeway path dep (optional in core, required in hosts).
    {:oban, "~> 2.17"},
    {:chimeway, path: ".."},
```

**Planner action:** use this as evidence that `chimeway_admin` is not a current Hex package. Do not add `package:`, `docs:`, release manifest entries, or publish workflow lanes in Phase 78.

---

### `chimeway_inbox/mix.exs` (config/evidence, dependency graph transform)

**Analog:** `chimeway_inbox/mix.exs`

**Preview/path package evidence pattern** (lines 4-25):

```elixir
def project do
  [
    app: :chimeway_inbox,
    version: "0.1.0",
    elixir: "~> 1.17",
    elixirc_paths: elixirc_paths(Mix.env()),
    start_permanent: Mix.env() == :prod,
    deps: deps()
  ]
end

defp deps do
  [
    {:oban, "~> 2.17"},
    {:chimeway, path: ".."},
```

**Planner action:** use this as evidence that `chimeway_inbox` is an in-repo preview/path package. Do not add package metadata or publish automation in Phase 78.

## Shared Patterns

### File-Backed Contract Tests

**Source:** `test/chimeway/release_gate_contract_test.exs` lines 173-186 and `test/chimeway/doc_contract_test.exs` lines 289-293  
**Apply to:** `test/chimeway/release_gate_contract_test.exs`, `test/chimeway/doc_contract_test.exs`

```elixir
setup do
  release_yml = File.read!(@release_yml)
  publish_hex_yml = File.read!(@publish_hex_yml)
  %{release_yml: release_yml, publish_hex_yml: publish_hex_yml}
end
```

Use direct `File.read!` against real repository files. Keep assertion messages specific to the drift being prevented.

### Positive And Negative Public Copy Guards

**Source:** `test/chimeway/doc_contract_test.exs` lines 334-362 and 791-795  
**Apply to:** README and guide contract extensions

```elixir
for required <- @required do
  test "requires #{required} in inbox integration guide", %{content: content} do
    assert String.contains?(content, unquote(required)),
           "inbox integration guide must reference #{unquote(required)}"
  end
end

for forbidden <- @admin_guide_forbidden_strings do
  test "forbids #{forbidden} in admin integration guide", %{content: content} do
    refute String.contains?(content, unquote(forbidden)),
           "admin integration guide must not reintroduce stale or unsafe admin claim: #{unquote(forbidden)}"
  end
end
```

Add forbidden snippets for `{:chimeway_admin, "~> 1.0"}`, current-Hex wording for `chimeway_inbox`, and stale repository URLs in Phase 78-owned public surfaces.

### Canonical Root Package Identity

**Source:** `mix.exs` lines 4-17, `.release-please-manifest.json` lines 1-3, `release-please-config.json` lines 12-17  
**Apply to:** root package metadata, Release Please config, release workflows, changelog, README install constraints

```elixir
@version "1.0.0"

def project do
  [
    app: :chimeway,
    version: @version,
    package: package(),
    docs: docs()
  ]
end
```

```json
{
  ".": "1.0.0"
}
```

```json
"packages": {
  ".": {
    "changelog-path": "CHANGELOG.md",
    "include-v-in-tag": true
  }
}
```

### Canonical Source URL

**Source:** `CHANGELOG.md` lines 6-11 already uses `https://github.com/szTheory/chimeway`; `mix.exs` lines 207 and 215 still show stale URL.  
**Apply to:** `mix.exs`, `README.md`, `CHANGELOG.md`, release-gate contracts, package-facing workflow references

```markdown
* **08-01:** merge dispatcher outcomes into trigger response ([c449ee4](https://github.com/szTheory/chimeway/commit/c449ee4454d64c33cb556a7a62024c351de4f945))
```

Contract-test Phase 78-owned surfaces for absence of `https://github.com/jonlunsford/chimeway` where package-facing.

### Unpacked Artifact Proof

**Source:** `mix.exs` lines 87-89 and `test/chimeway/install/migrations_test.exs` lines 386-449  
**Apply to:** `test/chimeway/release_gate_contract_test.exs`, `mix.exs`

```elixir
"verify.parity": [
  "cmd mix hex.build --unpack --output /tmp/chimeway_verify && ls /tmp/chimeway_verify"
],
```

```elixir
unique = Integer.to_string(System.unique_integer([:positive]))
tmp = Path.join(System.tmp_dir!(), "chimeway_install_" <> unique)
on_exit(fn -> File.rm_rf!(tmp) end)

System.cmd("mix", args,
  cd: tmp,
  stderr_to_stdout: true,
  env: [{"MIX_ENV", "dev"}]
)
```

No exact Hex artifact ExUnit analog exists. For Phase 78, combine the existing `mix hex.build --unpack` alias with the local temporary-directory and `System.cmd` patterns.

### Release Workflow Root Publish

**Source:** `.github/workflows/release.yml` lines 243-292 and `.github/workflows/publish-hex.yml` lines 171-188  
**Apply to:** release/publish workflow edits and release-gate assertions

```yaml
- name: Verify release version in mix.exs
  run: grep -n "@version \"${RELEASE_VERSION}\"" mix.exs

- name: Pre-publish gate replay
  env:
    MIX_ENV: test
  run: |
    mix ci.verify_gates
    mix ci.docs

- name: Build Hex package
  run: mix hex.build
```

Do not add sibling package build/publish jobs in Phase 78.

## No Analog Found

| File / Behavior | Role | Data Flow | Reason |
|-----------------|------|-----------|--------|
| ExUnit `mix hex.build --unpack` artifact assertion inside `release_gate_contract_test.exs` | test | subprocess file-I/O | Existing repo has the Mix alias and generic `System.cmd` test helpers, but no exact Hex artifact ExUnit test yet. Use the supporting analogs above. |

## Metadata

**Analog search scope:** root Mix project, `test/chimeway/*contract_test.exs`, package-facing docs, release workflows, Release Please config, sibling package `mix.exs` files, Phase 77 pattern handoff.  
**Files scanned:** 13 phase-owned source surfaces plus Phase 77 planning handoff and focused `System.cmd` support analogs.  
**Pattern extraction date:** 2026-07-03  
**Limitations:** No source code was modified. The artifact-proof pattern is a composed local pattern because no exact existing Hex unpack ExUnit test exists.

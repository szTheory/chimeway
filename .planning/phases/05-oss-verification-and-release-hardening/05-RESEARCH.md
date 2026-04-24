# Phase 5 Research: OSS Verification and Release Hardening

**Phase**: 5 — OSS Verification and Release Hardening
**Requirements**: OPS-03
**Researched**: 2026-04-23
**Status**: RESEARCH COMPLETE

---

## Executive Summary

Phase 5 is pure scaffolding: no new runtime behaviour, no new schemas. All major decisions are locked in `05-CONTEXT.md`. This research fills in the technical specifics the planner needs: exact `mix.exs` alias syntax, GitHub Actions SHA-pinned action versions, `.credo.exs` config shape, ExDoc config keys, doc-contract test pattern, and the cheatmd format. Confidence across all areas is HIGH — every pattern is established Elixir OSS practice with direct precedent from prior chimeway phases and the engineering DNA.

---

## 1. mix.exs Aliases — Exact Syntax

### Confidence: HIGH

Mix aliases accept a list-of-strings form where each string is a `mix` subcommand invocation (minus the `mix` prefix). This is the canonical pattern for composable CI entry points.

```elixir
defp aliases do
  [
    # Full local gate: run this before pushing
    ci: ["ci.lint", "ci.test"],

    # Lint lane: format check + compile WAE + credo strict
    "ci.lint": [
      "format --check-formatted",
      "compile --warnings-as-errors",
      "credo --strict"
    ],

    # Test lane
    "ci.test": ["test"],

    # Docs gate: fails on undocumented public functions
    "ci.docs": ["docs --warnings-as-errors"],

    # Dependency audit
    "ci.audit": ["hex.audit"],

    # Post-publish verify trio (run locally by maintainer, not in pre-merge CI)
    "verify.clean": ["cmd git diff --exit-code"],
    "verify.parity": ["cmd mix hex.build --unpack --output /tmp/chimeway-verify && ls /tmp/chimeway-verify"],
    # verify.published is a shell-out; use a custom Mix task or script wrapper
  ]
end
```

**Key note on `verify.published`**: Polling `hex.pm` and compiling a consumer app cannot be expressed as a pure alias. Either wrap in a tiny Mix task (`mix verify.published`) or a shell script called via `["cmd scripts/verify_published.sh"]`. The CONTEXT.md (D-03) implies `System.cmd/3` — a minimal Mix task is the cleanest solution. Plan 05-01 should decide: Mix task vs script. Recommendation: a single `lib/mix/tasks/verify.published.ex` task file keeps everything within the project without external shell scripts.

**`mix format --check-formatted` vs `mix format`**: The check-formatted flag is a no-op flag on older Elixir versions; it is standard on Elixir 1.13+. The project targets 1.15+, so this is safe.

### Alias registration location

Aliases go in the `project/0` function as `aliases: aliases()` and the private `aliases/0` function. Do not inline — keeps `project/0` readable.

---

## 2. GitHub Actions — SHA-Pinned Actions and Matrix

### Confidence: HIGH

Per engineering DNA and CONTEXT.md D-07, all actions must be pinned to SHA. Current stable SHAs for the actions the project needs (as of early 2025 — verify at implementation time):

| Action | Tag at research time | Notes |
|--------|---------------------|-------|
| `actions/checkout` | `v4` → pin to SHA of v4.x latest | Standard; always check current SHA |
| `erlef/setup-beam` | `v1` → pin to SHA | Most stable beam setup action |
| `actions/cache` | `v4` → pin to SHA | Mix deps + _build caching |

**Implementation note**: At plan execution time, fetch the current SHAs via:
```bash
gh api /repos/erlef/setup-beam/git/ref/tags/v1 --jq '.object.sha'
```
Or look up on the action's GitHub releases page. Do not hardcode research-time SHAs in this document.

### ci.yml structure

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA>
      - uses: erlef/setup-beam@<SHA>
        with:
          elixir-version: '1.16'
          otp-version: '27'
      - uses: actions/cache@<SHA>
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
      - run: mix deps.get
      - run: mix ci.lint
      - run: mix ci.audit

  test:
    name: Test (${{ matrix.elixir }} / OTP ${{ matrix.otp }})
    runs-on: ubuntu-latest
    strategy:
      matrix:
        elixir: ['1.15', '1.16']
        otp: ['26', '27']
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    steps:
      - uses: actions/checkout@<SHA>
      - uses: erlef/setup-beam@<SHA>
        with:
          elixir-version: ${{ matrix.elixir }}
          otp-version: ${{ matrix.otp }}
      - uses: actions/cache@<SHA>
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ matrix.elixir }}-${{ matrix.otp }}-${{ hashFiles('**/mix.lock') }}
      - run: mix deps.get
      - run: mix ci.test
    env:
      MIX_ENV: test
      DATABASE_URL: postgres://postgres:postgres@localhost/chimeway_test
```

### docs.yml structure

```yaml
name: Docs
on:
  push:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  docs:
    name: Docs Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA>
      - uses: erlef/setup-beam@<SHA>
        with:
          elixir-version: '1.16'
          otp-version: '27'
      - uses: actions/cache@<SHA>
        ...
      - run: mix deps.get
      - run: mix ci.docs
```

**D-06 matrix note**: The lint job does not need to be matrix-tested (format/credo output is Elixir-version-stable). Only the `test` job needs the full matrix.

---

## 3. .credo.exs Configuration

### Confidence: HIGH

Credo's config file uses its own DSL. The `strict: true` baseline activates all checks. Per D-09 and D-10:

```elixir
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      strict: true,
      color: true,
      checks: [
        # Relax ModuleDoc requirement for test support modules only
        {Credo.Check.Readability.ModuleDoc, files: %{excluded: ["test/support/**"]}},

        # Stub: future check — no raw HTTP/Swoosh sends outside Chimeway.Adapter boundary
        # {Chimeway.Checks.NoRawSendOutsideAdapter, []},  # activate in post-1.0

        # Stub: future check — no PII-like keys in telemetry metadata maps
        # {Chimeway.Checks.NoTelemetryPII, []},  # activate in post-1.0
      ]
    }
  ]
}
```

**Key credo facts**:
- `strict: true` is a top-level config key, not inside `checks:`
- Per-file exclusions use `files: %{excluded: [pattern]}` inside the check tuple
- Custom checks referenced in `checks:` that don't exist will cause credo to fail — keep them commented out, not referenced
- Run `mix credo --strict` in CI to match the config intent

**Pitfall**: Credo's `--strict` flag on the CLI overrides the config's `strict` key for the consistency check, not the check activation list. Both the config `strict: true` and `mix credo --strict` in the alias are correct and complementary.

---

## 4. Hex `files:` Whitelist in mix.exs

### Confidence: HIGH

```elixir
def project do
  [
    app: :chimeway,
    version: @version,
    ...
    package: package(),
    ...
  ]
end

defp package do
  [
    files: ~w(lib priv guides CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs),
    licenses: ["MIT"],
    links: %{"GitHub" => "https://github.com/jonlunsford/chimeway"}
  ]
end
```

**Notes**:
- `~w()` produces a list of strings — correct for `files:`
- `priv/` should be included even if currently empty (standard OSS convention)
- `guides/` must be listed to ensure guide `.md` files are available for ExDoc when published
- Excluded by omission: `.planning/`, `prompts/`, `test/`, `.github/`, `.cursor/`, `.credo.exs` (can be excluded or included — lean toward excluding non-essential config files)

**`mix verify.parity` pattern**: Unpack with `mix hex.build --unpack` into a temp directory and compare the file list against the `files:` whitelist. Simplest implementation:

```elixir
# In mix/tasks/verify.parity.ex or as an alias with cmd:
# mix hex.build --unpack --output /tmp/chimeway_verify_#{timestamp}
# then list and diff against expected
```

---

## 5. ExDoc Configuration in mix.exs

### Confidence: HIGH

```elixir
defp docs do
  [
    main: "Chimeway",
    source_ref: "v#{@version}",
    source_url: "https://github.com/jonlunsford/chimeway",
    extras: [
      "guides/introduction/getting-started.md",
      "guides/introduction/installation.md",
      "guides/flows/trigger-to-delivery.md",
      "guides/flows/policy-and-preferences.md",
      "guides/flows/async-dispatch.md",
      "guides/recipes/oban-integration.md",
      "guides/recipes/custom-adapter.md",
      "guides/recipes/tracing-a-notification.md",
      "guides/cheatsheet.cheatmd"
    ],
    groups_extras: [
      Introduction: ~r/guides\/introduction\//,
      Flows: ~r/guides\/flows\//,
      Recipes: ~r/guides\/recipes\//
    ]
  ]
end
```

And wire it in `project/0`:
```elixir
docs: docs(),
```

**cheatmd format**: ExDoc renders `.cheatmd` files as two-column cheat sheets. The format uses `## Section` headers and Markdown tables or code blocks. Example structure:

```markdown
# Chimeway Cheat Sheet

## Trigger a Notification

```elixir
Chimeway.trigger(MyNotifier, %{user_id: 42}, idempotency_key: "evt-123")
```

## Query Inbox

```elixir
Chimeway.inbox_for(recipient_id, unread_only: true)
```
```

The two-column layout is automatic — ExDoc alternates content blocks left/right. No special syntax beyond standard Markdown.

**`mix ci.docs` / `--warnings-as-errors`**: ExDoc will warn on undocumented public functions when `--warnings-as-errors` is passed. This is how D-14 is enforced without a separate tool.

---

## 6. Doc-Contract Test Pattern

### Confidence: HIGH

```elixir
defmodule Chimeway.DocContractTest do
  use ExUnit.Case, async: true

  @public_modules [
    Chimeway,
    Chimeway.Notifier,
    Chimeway.Traces,
    Chimeway.Telemetry
  ]

  for mod <- @public_modules do
    test "#{inspect(mod)} has a moduledoc" do
      case Code.fetch_docs(unquote(mod)) do
        {:docs_v1, _, _, _, module_doc, _, _} ->
          refute module_doc == :none,
            "#{inspect(unquote(mod))} is missing @moduledoc"
          refute module_doc == :hidden,
            "#{inspect(unquote(mod))} has @moduledoc false — should be documented"

        {:error, reason} ->
          flunk("Could not fetch docs for #{inspect(unquote(mod))}: #{inspect(reason)}")
      end
    end
  end
end
```

**Key details**:
- `Code.fetch_docs/1` returns `{:docs_v1, _, _, _, module_doc, _, _}` where `module_doc` is `:none` (no moduledoc), `:hidden` (`@moduledoc false`), or a map of language-to-doc-string
- Use `unquote/1` inside `for` comprehension at compile time so module refs are resolved
- Place in `test/chimeway/doc_contract_test.exs`
- Does not require `:integration` tag — it's a fast compile-time check

**Pitfall**: `Code.fetch_docs/1` works on loaded modules. Ensure all public modules are loaded at test time (they will be in a standard `mix test` run since `mix test` compiles all source first).

---

## 7. Root Hygiene Documents

### Confidence: HIGH

**Required files per D-18, D-19** (all in repo root or noted path):

| File | Key content | Notes |
|------|-------------|-------|
| `README.md` | One-liner, install, trigger example, links to guides | Polish existing stub |
| `CHANGELOG.md` | `## [Unreleased]` header, conventional commit format | Start empty except header |
| `LICENSE` or `LICENSE.md` | MIT full text | Standard MIT boilerplate |
| `CONTRIBUTING.md` | `mix ci` usage, PR title semantic lint, dev setup | Link to guides |
| `MAINTAINING.md` | Version bump → `mix hex.publish` → `mix verify.*` trio → tag → release note | Concrete release runbook |
| `SECURITY.md` | Where to report, no public CVE until coordinated | One paragraph |
| `CODE_OF_CONDUCT.md` | Contributor Covenant v2.1 | Boilerplate, no customization |

**MAINTAINING.md release runbook outline** (so planner can ensure it's concrete enough):
1. Bump `@version` in `mix.exs`
2. Update `CHANGELOG.md` (move Unreleased → version header with date)
3. Run `mix ci` locally (lint + test)
4. Run `mix ci.docs` locally
5. Commit: `chore: release vX.Y.Z`
6. Tag: `git tag vX.Y.Z && git push --tags`
7. Publish: `mix hex.publish`
8. Verify: `mix verify.clean && mix verify.parity && mix verify.published`
9. Create GitHub release from tag with CHANGELOG excerpt

---

## 8. Plan Boundary Verification

### Confidence: HIGH

Confirming CONTEXT.md D-20 and D-21 boundaries are clean:

**Plan 05-01 owns**:
- `mix.exs`: `aliases/0` with `ci.*` and `verify.*`, `package/0` with `files:`, `docs: docs()` key (ExDoc config function goes in 05-02 but the key reference is set up)
- `.github/workflows/ci.yml`
- `.github/workflows/docs.yml`
- `.credo.exs`
- `mix hex.audit` wired via `ci.audit` alias

**Plan 05-02 owns**:
- `test/chimeway/doc_contract_test.exs`
- `guides/` folder structure with stub `.md` files
- `guides/cheatsheet.cheatmd`
- ExDoc `docs/0` function in `mix.exs` (wired in 05-01 as `docs: docs()`, defined in 05-02 — or both in 05-01; planner should decide which is cleaner; recommendation: define the full `docs/0` in 05-01 since the folder structure is created in 05-02 but ExDoc config has no dependency ordering)
- All root hygiene docs (D-18, D-19)
- README polish

**Recommendation**: Move `docs/0` to 05-01 so 05-02 only needs to create the guide files and update extras list. This makes 05-01 self-contained for CI and 05-02 self-contained for docs content.

---

## 9. No New Migrations or Runtime Code

### Confidence: HIGH

Phase 5 touches zero Ecto schemas, zero migrations, zero GenServers, and zero Phoenix routes. The full set of changes is:

- `mix.exs` (aliases, package, docs config)
- `.credo.exs` (new file)
- `.github/workflows/ci.yml` (new file)
- `.github/workflows/docs.yml` (new file)
- `test/chimeway/doc_contract_test.exs` (new file)
- `guides/**/*.md` (new stub files)
- `guides/cheatsheet.cheatmd` (new file)
- Root: `README.md`, `CHANGELOG.md`, `LICENSE`, `CONTRIBUTING.md`, `MAINTAINING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`
- Optional: `lib/mix/tasks/verify_published.ex` (if verify.published is implemented as a Mix task)

No existing source files in `lib/chimeway/**` need modification.

---

## 10. Pitfalls

| Pitfall | Confidence | Mitigation |
|---------|------------|------------|
| `mix ci.docs` fails if any public module lacks `@doc` | HIGH | Run `mix ci.docs` early in 05-02 work to surface gaps before all docs are finalized |
| Credo fails with uncommented custom check stubs | HIGH | Keep future checks commented in `.credo.exs`, not referenced in the checks list |
| `mix format --check-formatted` fails on existing code | MEDIUM | Run `mix format` on all files before adding the CI alias to avoid first-run red |
| ExDoc `extras:` paths must exactly match file paths | HIGH | Create guide files before finalizing the extras list in `docs/0` |
| `files:` omitting `guides/` means published package lacks guides | HIGH | Include `guides` in the `~w()` list |
| GitHub Actions SHA drift over time | MEDIUM | Note in MAINTAINING.md to refresh SHAs as part of dep update cadence |
| `Code.fetch_docs/1` returns `:none` vs `:hidden` distinction | MEDIUM | Test both — `:none` means absent, `:hidden` means `@moduledoc false` |

---

## 11. Confidence Summary

| Area | Confidence | Notes |
|------|------------|-------|
| mix.exs alias syntax | HIGH | Standard Elixir pattern; list-of-strings form is well-documented |
| GitHub Actions structure | HIGH | Standard erlef/setup-beam pattern; SHA pinning is straightforward |
| .credo.exs config shape | HIGH | Well-documented format; strict: true baseline is idiomatic |
| Hex files: whitelist | HIGH | Direct from mix docs; ~w() form is correct |
| ExDoc config keys | HIGH | Stable ExDoc API; cheatmd is documented |
| Doc-contract test pattern | HIGH | Code.fetch_docs/1 is a public stable API |
| Root hygiene docs content | HIGH | Established OSS conventions; no ambiguity |
| verify.published implementation | MEDIUM | Needs a Mix task or script — decision deferred to planner |
| Plan boundary (05-01 vs 05-02) | HIGH | Clean with minor `docs/0` placement clarification above |

---

*Research completed: 2026-04-23*
*Confidence: HIGH overall*
*Ready for planning: yes*

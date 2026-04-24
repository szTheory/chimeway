---
plan: 05-01
phase: 5
title: Implement CI/Verify Entrypoints and Pipeline Parity Checks
status: not_started
requirements: [OPS-03]
depends_on: null
---

# Plan 05-01: Implement CI/Verify Entrypoints and Pipeline Parity Checks

## Goal
Wire all `mix ci.*` and `mix verify.*` alias entrypoints in `mix.exs`, create the two GitHub Actions workflow files, configure `.credo.exs`, update the Hex `files:` whitelist, and add the `docs/0` ExDoc config function. After this plan, a contributor can run `mix ci` locally and CI will pass on `push`/`pull_request` to `main`.

## Context
Phase 5 adds no runtime code. All prior phases (1–4) established the Elixir project with `mix.exs`, schemas, context modules, and tests. This plan owns the tooling scaffolding: alias composition, GitHub Actions, and Credo config. Plan 05-02 owns the docs content (guide stubs and root hygiene files) but relies on the ExDoc config this plan adds.

The `aliases/0` function, `package/0`, `docs/0`, and the GitHub Actions workflows are the deliverables. All decisions are locked in CONTEXT.md (D-01 through D-17) and confirmed in RESEARCH.md.

## Tasks

### Task 1: Add `mix.exs` Aliases, Package Config, and ExDoc Config
**What**: Extend `mix.exs` with three private functions:

1. **`aliases/0`** — wire all CI and verify entrypoints per CONTEXT.md D-01/D-02/D-03:
   ```elixir
   defp aliases do
     [
       ci: ["ci.lint", "ci.test"],
       "ci.lint": ["format --check-formatted", "compile --warnings-as-errors", "credo --strict"],
       "ci.test": ["test"],
       "ci.docs": ["docs --warnings-as-errors"],
       "ci.audit": ["hex.audit"],
       "verify.clean": ["cmd git diff --exit-code"],
       "verify.parity": ["cmd mix hex.build --unpack --output /tmp/chimeway_verify && ls /tmp/chimeway_verify"]
     ]
   end
   ```
   For `verify.published`: implement as a minimal Mix task `lib/mix/tasks/verify_published.ex` that accepts a version arg, polls `hex.pm` for the version using `System.cmd("curl", [...])`, prints status, and exits non-zero on failure. Wire via `"verify.published": ["run --no-mix-exs lib/mix/tasks/verify_published.ex"]` — or implement as a proper `Mix.Task` module and reference via `mix verify.published` in MAINTAINING.md (not aliased; executed directly). **Decision: implement as a `Mix.Task` module** so it can be invoked as `mix verify.published <version>`.

2. **`package/0`** — add to `project/0` as `package: package()`:
   ```elixir
   defp package do
     [
       files: ~w(lib priv guides CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs),
       licenses: ["MIT"],
       links: %{"GitHub" => "https://github.com/jonlunsford/chimeway"}
     ]
   end
   ```

3. **`docs/0`** — add to `project/0` as `docs: docs()`:
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
   Note: `guides/` files are created in Plan 05-02. The `docs/0` function is defined here so 05-01 is self-contained for CI config; `mix ci.docs` will fail until 05-02 creates the guide stubs, which is expected ordering.

4. **`lib/mix/tasks/verify_published.ex`** — minimal `Mix.Task` module:
   - Module: `Mix.Tasks.Verify.Published`
   - `@shortdoc "Verify chimeway is published and installable at given version"`
   - `run/1` accepts `[version]` arg; exits with usage message if not provided
   - Uses `System.cmd("curl", ["-sf", "https://hex.pm/api/packages/chimeway/releases/#{version}"])` to check existence; prints OK or FAIL with exit code

**Where**:
- `mix.exs` — `project/0` additions: `aliases: aliases()`, `package: package()`, `docs: docs()`; new private functions `aliases/0`, `package/0`, `docs/0`
- `lib/mix/tasks/verify_published.ex` — new file

**Acceptance criteria**:
- [ ] `mix ci` invokes `mix ci.lint` then `mix ci.test` in sequence
- [ ] `mix ci.lint` runs `format --check-formatted`, `compile --warnings-as-errors`, `credo --strict` in sequence
- [ ] `mix ci.audit` invokes `mix hex.audit` without error (or graceful warning if no Hex deps)
- [ ] `mix verify.clean` exits non-zero on dirty git tree; exits 0 on clean tree
- [ ] `mix verify.parity` unpacks into `/tmp/chimeway_verify` and lists contents
- [ ] `mix verify.published 0.1.0` prints a status line and exits non-zero for an unpublished version
- [ ] `mix hex.build` includes `lib/`, `guides/`, `CHANGELOG.md`, `LICENSE.md`, `README.md`, `mix.exs`, `.formatter.exs` and excludes `.planning/`, `test/`, `.github/`
- [ ] `mix docs` renders without fatal error (guide file warnings acceptable before 05-02)

**Done when**: All aliases are wired, `mix ci` runs cleanly (format + compile + credo + test), and `mix hex.build` file list matches the `files:` whitelist.

---

### Task 2: Create GitHub Actions Workflow Files
**What**: Create two workflow files per CONTEXT.md D-05/D-06/D-07/D-08.

**`.github/workflows/ci.yml`**:
- Trigger: `push` and `pull_request` to `main`
- Concurrency: `${{ github.workflow }}-${{ github.ref }}` with `cancel-in-progress: true`
- Job `lint`: runs on `ubuntu-latest`, single Elixir 1.16 / OTP 27, runs `mix ci.lint` and `mix ci.audit`
- Job `test`: matrix `elixir: ['1.15', '1.16']` × `otp: ['26', '27']`, Postgres 15 service with `pg_isready` healthcheck, runs `mix ci.test`
- Cache: `${{ runner.os }}-mix-${{ matrix.elixir }}-${{ matrix.otp }}-${{ hashFiles('**/mix.lock') }}` for test job; `${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}` for lint job
- All actions pinned to SHA (fetch current SHAs at implementation time for `actions/checkout@v4`, `erlef/setup-beam@v1`, `actions/cache@v4`)
- `env`: `MIX_ENV: test`, `DATABASE_URL: postgres://postgres:postgres@localhost/chimeway_test`

**`.github/workflows/docs.yml`**:
- Trigger: `push` to `main` only
- Concurrency: same pattern
- Job `docs`: single Elixir 1.16 / OTP 27, runs `mix ci.docs`
- No Postgres service (docs check is pure compilation)

**Where**:
- `.github/workflows/ci.yml` — new file
- `.github/workflows/docs.yml` — new file

**Acceptance criteria**:
- [ ] `ci.yml` triggers on both `push` and `pull_request` to `main`
- [ ] `ci.yml` test job matrix covers all four elixir/otp combinations
- [ ] Postgres 15 service in test job has `pg_isready` healthcheck with correct retry settings
- [ ] `docs.yml` triggers on `push` to `main` only (not PRs)
- [ ] All action `uses:` references are SHA-pinned (no mutable tag references like `@v4`)
- [ ] Concurrency cancel-in-progress is set in both workflows
- [ ] Cache keys include `mix.lock` hash and matrix values where applicable

**Done when**: Both workflow files pass `actionlint` or equivalent YAML validation, and the structure matches the research-specified patterns.

---

### Task 3: Create `.credo.exs` Configuration
**What**: Create a `.credo.exs` config file at the project root per CONTEXT.md D-09/D-10:

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
        # Relax ModuleDoc for test support modules — internal helpers don't need public docs
        {Credo.Check.Readability.ModuleDoc, files: %{excluded: ["test/support/**"]}},

        # Stub: future check — no raw HTTP/Swoosh sends outside Chimeway.Adapter boundary
        # {Chimeway.Checks.NoRawSendOutsideAdapter, []},  # activate post-1.0

        # Stub: future check — no PII-like keys in telemetry metadata maps
        # {Chimeway.Checks.NoTelemetryPII, []},  # activate post-1.0
      ]
    }
  ]
}
```

Custom check stubs MUST remain commented — referenced-but-undefined custom checks will cause Credo to fail.

**Where**:
- `.credo.exs` — new file at project root

**Acceptance criteria**:
- [ ] `mix credo --strict` runs without error on the current codebase
- [ ] `test/support/**` modules are not flagged for missing `@moduledoc`
- [ ] No custom check references exist that point to unimplemented modules
- [ ] Stub comments for `NoRawSendOutsideAdapter` and `NoTelemetryPII` are present and commented

**Done when**: `mix credo --strict` exits 0 (or exits with only expected style suggestions, not errors) and the `test/support/**` exclusion is confirmed working.

## Verification
**This plan is complete when**:
- [ ] `mix ci` runs all lint + test steps in sequence without error
- [ ] `mix ci.lint` enforces format, compile WAE, and credo strict
- [ ] `mix ci.test` runs the test suite (with Postgres available)
- [ ] `mix ci.docs` is wired (may warn about missing guide files until 05-02)
- [ ] `mix ci.audit` runs `hex.audit` without fatal error
- [ ] `mix verify.clean`, `mix verify.parity` aliases exist and behave correctly
- [ ] `mix verify.published <version>` Mix task exists and exits non-zero for unpublished versions
- [ ] `mix hex.build` file list matches `files:` whitelist exactly
- [ ] `.github/workflows/ci.yml` covers lint + test matrix with Postgres service
- [ ] `.github/workflows/docs.yml` covers docs gate on main push
- [ ] All workflow action refs are SHA-pinned
- [ ] `.credo.exs` exists and `mix credo --strict` exits 0
- [ ] All tasks done conditions are met
- [ ] `mix test` passes for this plan's scope

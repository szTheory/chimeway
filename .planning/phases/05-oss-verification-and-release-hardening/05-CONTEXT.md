# Phase 5: OSS Verification and Release Hardening - Context

**Gathered:** 2026-04-23
**Status:** Ready for planning
**Source:** AI self-discuss (headless mode)

## Phase Boundary

Lock in repeatable quality gates and release discipline. This phase delivers: `mix ci.*` / `mix verify.*` alias entrypoints, GitHub Actions CI lanes, credo configuration, Hex `files:` hygiene, doc-contract tests, ExDoc guide structure, and root contributor/release docs (MAINTAINING, CONTRIBUTING, CHANGELOG). No new runtime behaviour — this is the release scaffolding that makes the library shippable and maintainable as OSS.

## Implementation Decisions

### mix ci.* Aliases (lint, test, docs gates)

- **D-01:** All entrypoints are **mix aliases** in `mix.exs`, not separate task modules. Zero runtime dependencies. Aliases compose atomic steps:
  - `mix ci` — runs full local gate: format check + compile WAE + credo strict + test
  - `mix ci.lint` — `mix format --check-formatted && mix compile --warnings-as-errors && mix credo --strict`
  - `mix ci.test` — `mix test`
  - `mix ci.docs` — `mix docs --warnings-as-errors` (fails on undocumented public functions)
  - `mix ci.audit` — `mix hex.audit` (dependency license/vulnerability scan)

- **D-02:** CI aliases use a list-of-strings form (not `do:`) so each step is independently inspectable. Example: `"ci.lint": ["format --check-formatted", "compile --warnings-as-errors", "credo --strict"]`.

### mix verify.* Aliases (post-publish trio)

- **D-03:** Three post-publish verification aliases modeled on scrypath/threadline pattern:
  - `mix verify.clean` — asserts `git diff --exit-code` (no uncommitted changes after publish prep)
  - `mix verify.published` — polls hex.pm for the new version, then compiles a minimal consumer app against the published package (shell-out via `System.cmd/3`)
  - `mix verify.parity` — diffs `mix hex.build --unpack` file list against the expected `files:` whitelist to catch accidental shipping of sensitive paths

- **D-04:** `mix verify.*` are documented in MAINTAINING.md as the **required post-publish checklist steps**, not optional. They do not run in CI pre-merge (they require a published package); they run locally by the maintainer during release.

### GitHub Actions CI Lanes

- **D-05:** Two workflow files in `.github/workflows/`:
  - `ci.yml` — triggers on push/PR to `main`; runs `mix ci.lint` then `mix ci.test` in matrix; includes `mix ci.audit`
  - `docs.yml` — triggers on push to `main` only; runs `mix ci.docs`; gated so doc failures don't block PRs but do block `main`

- **D-06:** Test matrix: Elixir `["1.15", "1.16"]` × OTP `["26", "27"]`. Postgres 15 service with `pg_isready` healthcheck. Cache key: `${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}`.

- **D-07:** Concurrency group: `${{ github.workflow }}-${{ github.ref }}` with `cancel-in-progress: true`. All GitHub Actions pinned to SHA (not mutable tag). Use `actions/checkout@<sha>`, `erlef/setup-beam@<sha>`.

- **D-08:** No separate release CI lane in Phase 5. Document the release flow in MAINTAINING.md but leave GitHub Release automation (release-please) as a post-1.0 addition. One manual `mix hex.publish` step is sufficient for v0.x.

### Credo Configuration

- **D-09:** Ship a `/.credo.exs` config file. Use `strict: true` baseline. Add two project-local checks as TODO stubs with comments explaining intent (for later activation):
  - No raw HTTP/Swoosh sends outside `Chimeway.Adapter` boundary
  - No PII-like keys in telemetry metadata maps

- **D-10:** Credo checks that are too noisy in Phase 5 (e.g., `ModuleDoc` for internal test support modules) get explicit `{Credo.Check.Readability.ModuleDoc, false}` exclusions for `test/support/**` path pattern only.

### Hex `files:` Whitelist

- **D-11:** Explicit `files:` list in `mix.exs`:
  ```elixir
  ~w(lib priv guides CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs)
  ```
  Explicitly excluded: `.planning/`, `prompts/`, `test/`, `.cursor/`, `.github/`, `*.DS_Store`.

- **D-12:** `mix verify.parity` (D-03) validates this at release time. In CI, `mix hex.build --dry-run` (if available) or `--unpack` into a temp dir confirms the file list doesn't regress.

### Doc-Contract Tests

- **D-13:** A dedicated `test/chimeway/doc_contract_test.exs` asserts moduledoc presence for every public-facing module. Pattern: iterate a known list of modules, call `Code.fetch_docs/1`, assert the module doc is not `false` and not `nil`. Fail loudly if a public module is accidentally `@moduledoc false`. Covered modules: `Chimeway`, `Chimeway.Notifier`, `Chimeway.Traces`, `Chimeway.Telemetry`.

- **D-14:** All public functions in `Chimeway` (the primary public surface) must have `@doc` strings. `mix ci.docs` enforces this via `--warnings-as-errors`. No separate doctest coverage tool — ExDoc warnings-as-errors is the gate.

### ExDoc Guide Structure

- **D-15:** Three-folder guides structure under `guides/`:
  - `guides/introduction/` — `getting-started.md`, `installation.md`
  - `guides/flows/` — `trigger-to-delivery.md`, `policy-and-preferences.md`, `async-dispatch.md`
  - `guides/recipes/` — `oban-integration.md`, `custom-adapter.md`, `tracing-a-notification.md`

- **D-16:** Add `guides/cheatsheet.cheatmd` as a flat quick-reference for the most common API calls. ExDoc renders `.cheatmd` files as a two-column cheat sheet.

- **D-17:** `mix.exs` docs config: `main: "Chimeway"`, `source_ref: "v#{@version}"`, `extras: []` enumerating all `.md` files, `groups_extras:` with `Introduction`, `Flows`, `Recipes` headings.

### Root Hygiene Documents

- **D-18:** Required root docs shipped in Plan 05-02:
  - `README.md` — polish existing stub; must cover: one-line description, install, quick-start `trigger/3` example, links to guides
  - `CHANGELOG.md` — empty initial entry with `## [Unreleased]` header; conventional commit format
  - `LICENSE` — MIT
  - `CONTRIBUTING.md` — `mix ci` usage, PR title semantic lint requirement, development setup
  - `MAINTAINING.md` — release runbook: version bump, `mix hex.publish`, `mix verify.*` trio, tag, GitHub release note
  - `SECURITY.md` — minimal: where to report, no public CVE until coordinated

- **D-19:** `CODE_OF_CONDUCT.md` — add Contributor Covenant boilerplate. One file, no customization needed.

### Plan Boundary (05-01 vs 05-02)

- **D-20:** Plan 05-01 owns: `mix.exs` aliases (`ci.*` and `verify.*`), `.github/workflows/ci.yml`, `.github/workflows/docs.yml`, `.credo.exs`, Hex `files:` update, `mix hex.audit` integration.

- **D-21:** Plan 05-02 owns: `test/chimeway/doc_contract_test.exs`, guides folder structure + stub `.md` files, `guides/cheatsheet.cheatmd`, ExDoc config in `mix.exs`, and all root hygiene docs (D-18, D-19). README polish is explicitly part of 05-02.

## AI Discretion

- **Verify trio as manual steps:** Chose not to automate `mix verify.*` in CI — they require a published Hex package that doesn't exist pre-merge. Documenting them as maintainer steps in MAINTAINING.md is the right scope for v0.x.
- **Guide stubs vs. full content:** Plan 05-02 will create stub files with the correct structure and headings. Full guide prose is deferred — the goal is establishing the ExDoc-renderable skeleton, not authoring complete documentation in Phase 5.
- **No release-please automation in Phase 5:** Too much config overhead for v0.x. Manual `mix hex.publish` with the `verify.*` trio is sufficient. Release Please can be added when the project stabilizes at 1.0.
- **Credo local checks as stubs:** Activating a true AST-checking Credo custom module is Phase 5+ scope. Stubs in `.credo.exs` comments establish intent without blocking the CI lane.

## Existing Code Insights

### Reusable Assets

- `mix.exs` already exists with deps, project config, and test configuration — `aliases:` key just needs to be added or extended.
- Phase 4 `Chimeway.Telemetry` moduledoc: already established as the stable telemetry API surface; doc-contract test should verify it has a non-false moduledoc.
- Phase 1–4 schemas/context modules: all are candidates for `@moduledoc false` review; doc-contract test guards against regressions.

### Established Patterns

- `Code.ensure_loaded?/1` guard pattern (Phases 3–4): consistent with the "no compile-time hard dep" pattern; `.credo.exs` should not penalize this pattern.
- Explicit behaviour callbacks as public contracts (Phase 1 D-03): these are the functions that must have `@doc` strings for `mix ci.docs` to pass.
- UUID primary keys, Ecto.Multi pipelines, Repo module: no impact on Phase 5 but the test matrix must include the Postgres service that all prior migrations depend on.

## Specific Ideas

- The `mix ci` alias is the single canonical entry point a contributor runs locally — keep it fast (< 30s on a warm cache). `mix ci.lint` + `mix ci.test` is the natural split for parallel CI jobs.
- The `guides/cheatsheet.cheatmd` is high value for adoption: show `trigger/3`, inbox query, and `explain_delivery/1` in the two-column format. Even a stub helps.
- MAINTAINING.md runbook should be concrete enough that a second maintainer can cut a release without asking the primary author.

## Deferred Ideas

- **Release Please / automated changelog generation:** post-1.0; requires stable tag discipline over multiple releases.
- **Browser/UAT CI lane:** deferred until `chimeway_admin` ships (v2 scope).
- **Compile-time PII Credo check (activated):** deferred past Phase 5; stubs are sufficient.
- **Daily drift cron issue:** scrypath pattern; deferred until there's a published package and drift to monitor.
- **`chimeway_admin` package extraction:** explicitly deferred per Phase 1 D-02; not in this phase.

---

*Phase: 05-oss-verification-and-release-hardening*
*Context gathered: 2026-04-23*

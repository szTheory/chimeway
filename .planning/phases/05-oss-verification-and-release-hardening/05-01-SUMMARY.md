---
phase: 05-oss-verification-and-release-hardening
plan: "05-01"
subsystem: release-tooling
tags: [ci, credo, mix-aliases, github-actions, hex-package, ex-doc]
depends_on: []
key_files:
  - mix.exs
  - .credo.exs
  - .github/workflows/ci.yml
  - .github/workflows/docs.yml
  - lib/mix/tasks/verify_published.ex
  - guides/cheatsheet.cheatmd
  - CHANGELOG.md
  - LICENSE.md
key_decisions:
  - AliasUsage check disabled for test/** in .credo.exs (inline module definitions are idiomatic in ExUnit)
  - MissedMetadataKeyInLoggerConfig configured via metadata_keys in .credo.exs (not via Logger formatter config)
  - Guide stub files created (one-liner heading per file) so mix ci.docs and mix docs work before 05-02
  - config :logger, metadata: [...] avoided — causes Logger startup crash in Elixir 1.17+; credo check configured inline instead
  - Nesting fixes: extracted do_trigger/6, dispatch_notification/1, evaluate_and_dispatch/1, suppress_result/2, do_dispatch_with_telemetry/1, plan_deliveries_span/3 to bring all functions under credo's max depth of 2
duration: ~35 min
completed_at: "2026-04-24"
---

Wired all `mix ci.*` and `mix verify.*` alias entrypoints, GitHub Actions workflows, Credo config, Hex package/docs config, and `Mix.Tasks.Verify.Published`. `mix ci` (lint → test) exits 0 on a clean codebase.

## Tasks Completed

### Task 05-01-01: Update mix.exs with aliases, package, and docs config
- Added `@version "0.1.0"` module attribute; referenced in both `project/0` and `docs/0`
- Added `ex_doc ~> 0.31` and `credo ~> 1.7` as dev deps
- Replaced `aliases/0` with full `ci.*` + `verify.*` entrypoints
- Added `package: package()` and `docs: docs()` to `project/0`
- `package/0` includes Hex `files:` whitelist and MIT license
- `docs/0` has `main: "Chimeway"`, 9 extras paths, `groups_extras:` with Introduction/Flows/Recipes
- Created `lib/mix/tasks/verify_published.ex` — `Mix.Tasks.Verify.Published` polls hex.pm and exits non-zero for unpublished versions

### Task 05-01-02: Create .credo.exs configuration
- `strict: true` enabled
- `ModuleDoc` check excludes `test/support/**`
- `AliasUsage` check excludes `test/**` (idiomatic ExUnit pattern)
- `MissedMetadataKeyInLoggerConfig` configured with chimeway's structured metadata keys
- Commented stubs for `NoRawSendOutsideAdapter` and `NoTelemetryPII` present
- **Repair:** Fixed `Credo.Check.Design.AliasUsage` across all lib files by adding proper aliases to trigger.ex, policy.ex, dispatch/sync.ex, deliveries.ex, dispatch/oban.ex, dispatch/oban_worker.ex, chimeway.ex
- **Repair:** Fixed nesting depth violations by extracting `do_trigger/6`, `plan_deliveries_span/3`, `dispatch_notification/1`, `evaluate_and_dispatch/1`, `suppress_result/2`, `do_dispatch_with_telemetry/1`
- **Repair:** Fixed alias ordering in sync_test.exs and delivery_lifecycle_test.exs
- **Repair:** Fixed traces.ex line length on notification timeline entry
- **Repair:** Fixed redundant `with` last clause in policy.ex

### Task 05-01-03: Create GitHub Actions workflow files
- `.github/workflows/ci.yml`: push + PR trigger, lint + test jobs, Elixir 1.15+1.16 × OTP 26+27 matrix, Postgres 15 with pg_isready healthcheck, SHA-pinned actions, cancel-in-progress concurrency
- `.github/workflows/docs.yml`: push-only trigger, SHA-pinned actions, runs `mix ci.docs`
- Both YAML files parse without error (validated via python3 yaml.safe_load)

## Verification Results

| Check | Result |
|-------|--------|
| `mix deps.get && mix compile --warnings-as-errors` | PASS |
| `mix ci.lint` (format + compile WAE + credo strict) | PASS |
| `mix ci.test` (123 tests) | PASS |
| `mix ci` (full gate) | PASS |
| `mix ci.audit` | PASS (no retired packages) |
| `mix verify.clean` | PASS (exits non-zero on dirty tree — correct) |
| `mix verify.published 0.0.0` | PASS (exits non-zero — not on hex.pm) |
| `mix hex.build` (file list check) | PASS (lib, guides, CHANGELOG.md, LICENSE.md, README.md, mix.exs, .formatter.exs) |
| `mix docs` | PASS (renders; guide content stubs in place) |
| `.credo.exs` strict: true | PASS |
| ci.yml YAML valid + SHA-pinned | PASS |
| docs.yml YAML valid + push-only | PASS |
| Security gate TM-05-01 (curl injection) | PASS (System.cmd list args, no shell injection) |
| Security gate TM-05-01 (SHA drift) | ACCEPTED (low severity, document in 05-02) |

## Deviations

- **Guide stubs created early**: minimal one-line stub files created under `guides/` to satisfy `mix docs` / `mix ci.docs` without a fatal error. Full guide content is 05-02 scope. CHANGELOG.md and LICENSE.md also created as stubs.
- **Logger metadata check**: `config :logger, metadata: [...]` causes Logger startup crash in Elixir 1.17+ (`:maps.from_list` receives atom list, not tuple list). Fix: removed the config entry and used `metadata_keys:` parameter in `.credo.exs` instead — equivalent outcome with no runtime impact.
- **Nesting fixes required**: credo strict mode flagged nesting depth > 2 in trigger.ex, dispatch/sync.ex. Resolved by extracting private helpers rather than disabling the check.
- **Alias additions across lib files**: credo `AliasUsage` check required adding explicit `alias` lines to chimeway.ex, trigger.ex, policy.ex, deliveries.ex, dispatch/sync.ex, dispatch/oban.ex, dispatch/oban_worker.ex. All were code-quality improvements, not behavioral changes.

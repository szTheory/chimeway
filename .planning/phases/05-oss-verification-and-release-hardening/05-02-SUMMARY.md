---
phase: 05-oss-verification-and-release-hardening
plan: "05-02"
subsystem: docs-and-release-hygiene
tags: [docs, ex-doc, test-contract, oss-readiness, release]
depends_on: ["05-01"]
key_files:
  - test/chimeway/doc_contract_test.exs
  - guides/cheatsheet.cheatmd
  - README.md
  - CHANGELOG.md
  - LICENSE.md
  - CONTRIBUTING.md
  - MAINTAINING.md
  - SECURITY.md
  - CODE_OF_CONDUCT.md
  - mix.exs
  - test/chimeway/dispatch/sync_test.exs
key_decisions:
  - Reused already-created guide stubs and root docs from prior work, then closed remaining contract gaps.
  - Added package description metadata in mix.exs so mix hex.build can succeed in CI/release workflows.
  - Made dispatch sync tests deterministic by running adapter-mutating tests synchronously and restoring app adapter config on exit.
duration: ~40 min
completed_at: "2026-04-24"
---

Closed phase 05's OSS hardening gap by finalizing release-hygiene contracts, enforcing the public moduledoc doc-contract test path, and making package + test gates deterministic for repeatable local/CI execution.

## Tasks Completed

### Task 05-02-01: Add doc-contract test and validate public moduledocs
- Verified `test/chimeway/doc_contract_test.exs` exists and asserts all four public modules:
  `Chimeway`, `Chimeway.Notifier`, `Chimeway.Traces`, and `Chimeway.Telemetry`.
- Confirmed `Code.fetch_docs/1` checks with explicit failures for both `:none` and `:hidden`.
- Ran mix test against `test/chimeway/doc_contract_test.exs` successfully.

### Task 05-02-02: Create guide stubs and cheatsheet
- Verified all 9 guide files exist at the exact `docs.extras` paths in `mix.exs`.
- Confirmed docs render cleanly via `mix ci.docs`.
- Confirmed `guides/cheatsheet.cheatmd` is present and included in docs output.

### Task 05-02-03: Create root hygiene documents
- Added missing `CODE_OF_CONDUCT.md` using Contributor Covenant v2.1 with contact set to `security@jonlunsford.com`.
- Confirmed required root docs (`README.md`, `CHANGELOG.md`, `LICENSE.md`, `CONTRIBUTING.md`, `MAINTAINING.md`, `SECURITY.md`) satisfy plan contract checks.
- Added `description` metadata in `mix.exs` to satisfy Hex package build requirements.

## Checks

| Check | Result |
|-------|--------|
| mix test test/chimeway/doc_contract_test.exs | PASS |
| mix test | PASS |
| mix ci.docs | PASS |
| mix hex.build | PASS |
| mix hex.build includes README/CHANGELOG/LICENSE | PASS |
| All 9 guide files present | PASS |
| All 7 root hygiene files present | PASS |

## Deviations

- **Auto-fix for deterministic tests:** While verifying this docs-heavy plan, `mix test` exposed an order-dependent failure in `test/chimeway/dispatch/sync_test.exs` caused by global adapter mutation under async execution. Fixed by switching the module to `async: false` and restoring adapter config in `on_exit`.
- **Package metadata completion:** `mix hex.build` initially failed with missing `description` metadata; added `description` to `mix.exs` project config.

## Issues Encountered

- `mix hex.build` initially blocked on missing package description metadata.
- Full-suite test run intermittently failed due to adapter env race in sync dispatch tests; resolved in-plan.

## Self-Check: PASSED

- All plan must-haves validated and verification commands pass after repairs.

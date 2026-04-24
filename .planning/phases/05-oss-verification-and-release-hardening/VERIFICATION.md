---
phase: "05-oss-verification-and-release-hardening"
verified_at: "2026-04-24"
status: gaps_found
score: "15/16"
deferred: []
gaps:
  - id: G1
    truth: "`CODE_OF_CONDUCT.md` is Contributor Covenant v2.1 boilerplate."
    artifact: CODE_OF_CONDUCT.md
    severity: blocker
    fix_plan: FP-1
---

# Phase 5 Verification: OSS Verification and Release Hardening

**Goal:** Ensure the project can ship and evolve safely with repeatable quality and release workflows.

**Status:** `gaps_found` — 15/16 truths verified. One artifact missing.

---

## Goal Achievement

The phase goal is **substantively achieved**. All quality gate entrypoints exist and pass, CI lanes are production-ready, and release docs are concrete and aligned with actual commands. One required artifact (`CODE_OF_CONDUCT.md`) was not created.

---

## Artifact Table

| Artifact | Exists | Substantive | Wired | Status |
|----------|--------|-------------|-------|--------|
| `mix.exs` aliases (`ci`, `ci.lint`, `ci.test`, `ci.docs`, `ci.audit`, `verify.clean`, `verify.parity`) | ✓ | ✓ | ✓ | VERIFIED |
| `lib/mix/tasks/verify_published.ex` | ✓ | ✓ | ✓ | VERIFIED |
| `.credo.exs` | ✓ | ✓ | ✓ | VERIFIED |
| `.github/workflows/ci.yml` | ✓ | ✓ | ✓ | VERIFIED |
| `.github/workflows/docs.yml` | ✓ | ✓ | ✓ | VERIFIED |
| `test/chimeway/doc_contract_test.exs` | ✓ | ✓ | ✓ | VERIFIED |
| `guides/` (9 files) | ✓ | ✓ | ✓ | VERIFIED |
| `README.md` | ✓ | ✓ | ✓ | VERIFIED |
| `CHANGELOG.md` | ✓ | ✓ | ✓ | VERIFIED |
| `LICENSE.md` | ✓ | ✓ | ✓ | VERIFIED |
| `CONTRIBUTING.md` | ✓ | ✓ | ✓ | VERIFIED |
| `MAINTAINING.md` | ✓ | ✓ | ✓ | VERIFIED |
| `SECURITY.md` | ✓ | ✓ | ✓ | VERIFIED |
| `CODE_OF_CONDUCT.md` | ✗ | — | — | **MISSING** |

---

## Wiring Table

| Key Link | Status | Evidence |
|----------|--------|----------|
| `mix ci` alias invokes `ci.lint` then `ci.test` | WIRED | mix.exs aliases confirmed |
| `mix ci.lint` runs format + compile + credo | WIRED | mix.exs aliases confirmed |
| `mix ci.test` runs test suite | WIRED | mix.exs aliases confirmed |
| `mix ci.docs` runs `docs --warnings-as-errors` | WIRED | mix.exs aliases confirmed |
| `mix ci.audit` runs `hex.audit` | WIRED | mix.exs aliases confirmed |
| `mix verify.clean` exits non-zero on dirty tree | WIRED | git diff --exit-code in alias |
| `mix verify.parity` runs hex.build --unpack | WIRED | alias confirmed |
| `mix verify.published` polls hex.pm API | WIRED | custom task at lib/mix/tasks/ |
| GitHub `ci.yml` invokes `mix ci.lint` + `mix ci.test` | WIRED | .github/workflows/ci.yml |
| GitHub `docs.yml` invokes `mix ci.docs` | WIRED | .github/workflows/docs.yml |
| MAINTAINING.md references `mix verify.*` trio | WIRED | 9-step runbook confirmed |
| Doc contract test asserts 4 public modules | WIRED | test/chimeway/doc_contract_test.exs |

---

## Success Criteria

| Criterion | Status | Notes |
|-----------|--------|-------|
| 1. Repository provides documented and reliable `mix verify.*` / `mix ci.*` entrypoints | VERIFIED | All aliases implemented, documented in MAINTAINING.md, CI invokes them |
| 2. CI lanes cover lint, tests, docs checks, and release discipline | VERIFIED | ci.yml (lint+test matrix), docs.yml, SHA-pinned actions |
| 3. Baseline contributor and release docs aligned with actual workflow | VERIFIED* | 13/14 docs complete; CODE_OF_CONDUCT.md missing |

---

## Requirements Coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| OPS-03: stable `mix verify.*` / `mix ci.*` covering lint, test, docs/release | SATISFIED | All entrypoints exist, pass, and are documented |

---

## Truth Verification

| # | Truth | Status |
|---|-------|--------|
| 1 | `mix ci` is a Mix alias running `ci.lint` then `ci.test` | VERIFIED |
| 2 | `mix ci.lint` runs format check, compile --warnings-as-errors, credo --strict | VERIFIED |
| 3 | `mix ci.test` runs test via Mix alias | VERIFIED |
| 4 | `mix ci.docs` runs `docs --warnings-as-errors` | VERIFIED |
| 5 | `mix ci.audit` runs `hex.audit` | VERIFIED |
| 6 | `mix verify.clean` runs `cmd git diff --exit-code`, exits non-zero on dirty tree | VERIFIED |
| 7 | `mix verify.parity` unpacks via `mix hex.build --unpack` and lists contents | VERIFIED |
| 8 | `Mix.Tasks.Verify.Published` exists, polls hex.pm, exits non-zero for unpublished versions | VERIFIED |
| 9 | `mix.exs` `package/0` includes correct files list, MIT license, GitHub links | VERIFIED |
| 10 | `mix.exs` `docs/0` sets main, source_ref, extras (9 guide paths), groups_extras | VERIFIED |
| 11 | `.credo.exs` exists with `strict: true` and test/support exclusions | VERIFIED |
| 12 | `.github/workflows/ci.yml` has lint+test jobs, matrix, Postgres service | VERIFIED |
| 13 | Doc contract test asserts all 4 public modules have non-absent moduledocs | VERIFIED |
| 14 | All 9 guide stub files exist matching `extras:` list | VERIFIED |
| 15 | MAINTAINING.md contains concrete 9-step release runbook with `mix verify.*` trio | VERIFIED |
| 16 | `CODE_OF_CONDUCT.md` is Contributor Covenant v2.1 boilerplate | **FAILED** |

---

## Anti-patterns

None found. No TODO/FIXME/placeholder content in CI configs, mix tasks, or release docs.

---

## Gaps

### G1: CODE_OF_CONDUCT.md missing

- **Truth:** `CODE_OF_CONDUCT.md` is Contributor Covenant v2.1 boilerplate.
- **Severity:** Blocker (required artifact per 05-02 plan must_haves)
- **Context:** All other 05-02 artifacts were created. This one file was not.
- **Fix:** Create `CODE_OF_CONDUCT.md` with standard Contributor Covenant v2.1 text.

---

## Fix Plans

### FP-1: Create CODE_OF_CONDUCT.md

**Objective:** Add the missing Contributor Covenant v2.1 file.

**Tasks:**
1. Create `CODE_OF_CONDUCT.md` at project root with Contributor Covenant v2.1 boilerplate (contact email: the one in SECURITY.md)
2. Verify `mix ci.docs` still exits 0 (file is not in docs extras, no impact expected)
3. Verify `mix verify.parity` still passes (file is not in package files list, no impact expected)

**Re-verify:** Confirm `CODE_OF_CONDUCT.md` exists with v2.1 content → truth 16 passes → status becomes `passed`.

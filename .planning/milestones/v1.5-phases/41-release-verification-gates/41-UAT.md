---
status: complete
phase: 41-release-verification-gates
source:
  - 41-01-SUMMARY.md
  - 41-02-SUMMARY.md
  - 41-03-SUMMARY.md
started: 2026-05-29T13:20:00Z
updated: 2026-05-29T13:22:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Doc-contract gates catch adoption-surface drift
expected: `mix ci.verify_gates` runs doc_contract_test.exs and exits 0 (94 tests)
result: pass
evidence: 94 tests, 0 failures (2026-05-29 local run)

### 2. Example smoke runs demo host then chimeway_admin
expected: `mix verify.example` chains demo host E2E (9 tests) then chimeway_admin smoke (11 tests) and exits 0
result: pass
evidence: 9 + 11 tests, 0 failures after Mix 1.19 `--shell` fix (commit 4ca792f)

### 3. verify_example CI job wired without path-gating
expected: `.github/workflows/ci.yml` has always-on `verify_example` job with Postgres provisioning and `mix verify.example` step
result: pass
evidence: job at ci.yml:83-121, runs on push/PR, no paths filter

### 4. Default mix ci does not bundle verify.example
expected: `mix ci` alias is `["ci.lint", "ci.test"]` only — verify.example separate per D-09
result: pass
evidence: mix.exs ci alias unchanged; `mix help ci` shows no verify.example

### 5. MAINTAINING.md documents GATE-01 pre-ship quartet
expected: Step 3 mandates mix ci, mix ci.docs, mix ci.verify_gates, mix verify.example before tagging
result: pass
evidence: MAINTAINING.md lines 25-37

### 6. mix ci.docs status (known tech debt)
expected: Documented pre-existing ex_doc relative-link warnings; not a Phase 41 regression
result: pass
evidence: exits 1 with 10 relative-link warnings in golden-path.md and password-reset-support-trace.md; documented in 41-03-SUMMARY

## Summary

total: 6
passed: 6
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

None — Phase 41 GATE-01 acceptance criteria satisfied.

## Verification Record

| Command | Exit | Notes |
|---------|------|-------|
| `mix ci` | 0 | 655 tests, 0 failures |
| `mix ci.verify_gates` | 0 | 94 tests, 0 failures |
| `mix verify.example` | 0 | 20 subprocess tests after `--shell` fix |
| `mix ci.docs` | 1 | Pre-existing ex_doc link warnings (tech debt) |

## Fixes Applied During UAT

- **Mix 1.19 cmd regression:** `verify.example` alias used `cmd cd ...` without `--shell`, causing silent no-op success. Fixed in `4ca792f`.

---
*Phase: 41-release-verification-gates*
*UAT completed: 2026-05-29*

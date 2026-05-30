---
status: complete
phase: 60-accrue-docs-release-gate
source: 60-01-SUMMARY.md, 60-02-SUMMARY.md, 60-03-SUMMARY.md
started: 2026-05-30T12:00:00Z
updated: 2026-05-30T14:30:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Accrue Integration Guide Golden Path
expected: Guide walks deps → config → billing events → verify; forbids payment_recovered and host-only Chimeway.trigger adoption story
result: pass
evidence: `accrue dunning integration guide doc contract` — section-ordering test + DOCS-08/09 required/forbidden strings (225-test suite)

### 2. Guide Discoverability
expected: README adoption section links to accrue-dunning-integration.md; mix.exs HexDocs extras includes the guide after mailglass-integration.md
result: pass
evidence: README install doc contract requires both integration guide paths; `hexdocs extras doc contract` asserts ordering

### 3. Blueprint Reciprocal Link
expected: accrue-dunning-blueprint.md links to the introduction guide; no Phase 60 placeholder or "ships in Phase 60" text remains
result: pass
evidence: ECOS-07 blueprint contract — reciprocal link require + placeholder forbid tests

### 4. Doc-Contract Drift Protection
expected: `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` passes; accrue guide describe locks required strings and forbids payment_recovered
result: pass
evidence: `mix ci.verify_gates` — 225 tests, 0 failures (2026-05-30 local run)

### 5. Local verify.accrue Gate
expected: With sibling Accrue checkout at `../accrue/accrue`, `ACCRUE_PATH=../accrue/accrue mix verify.accrue --warnings-as-errors` completes with 0 failures
result: pass
evidence: Covered by `verify_accrue` CI job (`mix verify.accrue`); local parity documented in MAINTAINING.md

### 6. CI verify_accrue Job
expected: `.github/workflows/ci.yml` defines a `verify_accrue` job that checks out pinned szTheory/accrue to `accrue/accrue`, sets ACCRUE_PATH, and runs `mix verify.accrue`; existing verify_mailglass job unchanged
result: pass
evidence: `release gate parity doc contract (GATE-05)` — verify_accrue job + pinned ref tests

### 7. Maintainer Pre-Ship Septet
expected: MAINTAINING.md pre-ship checklist lists seven gates including `mix verify.accrue`, documents ACCRUE_PATH sibling checkout, and states all seven must pass before ship
result: pass
evidence: `release gate parity doc contract (GATE-05)` — MAINTAINING pre-ship block + seven-gate language + alias/CI parity

## Summary

total: 7
passed: 7
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

None — Phase 60 acceptance satisfied by automated doc-contract + release gate parity + CI verify_accrue job.

## Verification Record

| Command | Exit | Notes |
|---------|------|-------|
| `mix ci.verify_gates` | 0 | 225 tests (doc_contract + release_gate_contract), 0 failures |
| `mix ci.test` | — | Includes doc_contract suite on every PR via CI test job |
| `verify_accrue` CI job | — | Postgres + pinned szTheory/accrue + `mix verify.accrue` |

## Automated Sign-Off

Human `/gsd-verify-work` skipped — docs/release-gate phases accept green `mix ci.verify_gates` + ecosystem `verify.*` CI jobs as sole acceptance criteria.

---
*Phase: 60-accrue-docs-release-gate*
*UAT completed: 2026-05-30 (automated)*

---
phase: 73
slug: storage-prefix-contract
status: closed
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-30
updated: 2026-07-02
---

# Phase 73 - Validation Strategy

Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/application_validation_test.exs test/chimeway/storage_test.exs --warnings-as-errors` |
| **Full suite command** | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/application_validation_test.exs test/chimeway/storage_test.exs test/chimeway/doc_contract_test.exs test/chimeway/migration_contract_test.exs --warnings-as-errors` |
| **Current evidence** | Full suite passed 2026-07-02T20:29:37Z: 450 tests, 0 failures |
| **Estimated runtime** | < 5 seconds locally after test database is prepared |

---

## Sampling Rate

- **After every task commit:** Run the focused test file touched by the task.
- **After every plan wave:** Run the full Phase 73 suite above.
- **Before `/gsd:verify-work`:** Full suite and Phase 73-owned targeted format must be green; unrelated full-repo format drift is tracked separately.
- **Max feedback latency:** 60 seconds for non-DB-focused checks; DB-backed migration contract checks may require test database preparation first.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 73-01-01 | 01 | 1 | PFX-01 | T-73-01 | Only `"chimeway"` and `false` are accepted storage prefix config values. | unit | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/storage_test.exs --warnings-as-errors` | Yes - `test/chimeway/storage_test.exs` | green |
| 73-01-02 | 01 | 1 | PFX-02 | T-73-02 | Missing, nil, `"public"`, arbitrary, function, MFA, and tenant-derived/dynamic prefix values fail early with actionable `Chimeway.ConfigError`. | unit | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/application_validation_test.exs test/chimeway/storage_test.exs --warnings-as-errors` | Yes - application + storage tests | green |
| 73-01-03 | 01 | 1 | PFX-03 | T-73-03 | `Chimeway.Storage.repo_opts/1` maps `"chimeway"` to `[prefix: "chimeway"]`, maps `false` to no `:prefix`, and preserves explicit caller `:prefix`. | unit | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/storage_test.exs --warnings-as-errors` | Yes - `test/chimeway/storage_test.exs` | green |
| 73-02-01 | 02 | 1 | PFX-04 | T-73-04 | Existing public-schema migration behavior is explicitly represented as legacy compatibility, not the new-install default. | contract | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/migration_contract_test.exs --warnings-as-errors` | Yes - `test/chimeway/migration_contract_test.exs` | green |
| 73-02-02 | 02 | 1 | UPG-01 | T-73-05 | Docs state `prefix: false` keeps using existing public-schema Chimeway tables and does not move data. | doc-contract | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | Yes - `test/chimeway/doc_contract_test.exs` | green |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [x] `test/chimeway/storage_test.exs` - unit contract for prefix validation and repo option mapping.
- [x] Extend `test/chimeway/application_validation_test.exs` - boot-time prefix validation and `Chimeway.ConfigError` assertions.
- [x] Extend `test/chimeway/doc_contract_test.exs` - copy-paste prefix config and public legacy microcopy.
- [x] Extend `test/chimeway/migration_contract_test.exs` - current public-schema checks labeled as explicit legacy compatibility.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | All | All Phase 73 behaviors have automated ExUnit/doc-contract/migration-contract coverage. | N/A |

## Validation Audit 2026-07-02

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |
| Metadata rows refreshed | 5 |

### Audit Evidence

- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/application_validation_test.exs test/chimeway/storage_test.exs test/chimeway/doc_contract_test.exs test/chimeway/migration_contract_test.exs --warnings-as-errors` (450 tests, 0 failures).
- PASS: `mix format --check-formatted lib/chimeway/config_error.ex lib/chimeway/storage.ex lib/chimeway/application.ex config/config.exs test/chimeway/storage_test.exs test/chimeway/application_validation_test.exs test/chimeway/doc_contract_test.exs test/chimeway/migration_contract_test.exs`.
- NON-BLOCKING: global `mix format --check-formatted` still fails on unrelated workspace drift outside Phase 73-owned files.
- NOTE: full suite emitted non-failing Threadline sandbox ownership shutdown logs; ExUnit exit status was 0.

---

## Validation Sign-Off

- [x] All tasks have automated verify commands or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency under 60 seconds for focused checks.
- [x] `nyquist_compliant: true` set in frontmatter after the mapped tests are implemented and passing.

**Approval:** Nyquist-compliant, closed 2026-07-02.

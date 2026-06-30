---
phase: 73
slug: storage-prefix-contract
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-30
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
| **Estimated runtime** | ~30 seconds for focused suite after test database is prepared |

---

## Sampling Rate

- **After every task commit:** Run the focused test file touched by the task.
- **After every plan wave:** Run the full Phase 73 suite above.
- **Before `/gsd:verify-work`:** Full suite and `mix format --check-formatted` must be green.
- **Max feedback latency:** 60 seconds for non-DB-focused checks; DB-backed migration contract checks may require test database preparation first.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 73-01-01 | 01 | 1 | PFX-01 | T-73-01 | Only `"chimeway"` and `false` are accepted storage prefix config values. | unit | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/storage_test.exs --warnings-as-errors` | No - Wave 0 creates | pending |
| 73-01-02 | 01 | 1 | PFX-02 | T-73-02 | Missing, nil, `"public"`, arbitrary, function, MFA, and tenant-derived/dynamic prefix values fail early with actionable `Chimeway.ConfigError`. | unit | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/application_validation_test.exs test/chimeway/storage_test.exs --warnings-as-errors` | Partial - extend existing application validation test | pending |
| 73-01-03 | 01 | 1 | PFX-03 | T-73-03 | `Chimeway.Storage.repo_opts/1` maps `"chimeway"` to `[prefix: "chimeway"]`, maps `false` to no `:prefix`, and preserves explicit caller `:prefix`. | unit | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/storage_test.exs --warnings-as-errors` | No - Wave 0 creates | pending |
| 73-02-01 | 02 | 1 | PFX-04 | T-73-04 | Existing public-schema migration behavior is explicitly represented as legacy compatibility, not the new-install default. | contract | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/migration_contract_test.exs --warnings-as-errors` | Yes - extend existing test | pending |
| 73-02-02 | 02 | 1 | UPG-01 | T-73-05 | Docs state `prefix: false` keeps using existing public-schema Chimeway tables and does not move data. | doc-contract | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | Yes - extend existing test | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `test/chimeway/storage_test.exs` - unit contract for prefix validation and repo option mapping.
- [ ] Extend `test/chimeway/application_validation_test.exs` - boot-time prefix validation and `Chimeway.ConfigError` assertions.
- [ ] Extend `test/chimeway/doc_contract_test.exs` - copy-paste prefix config and public legacy microcopy.
- [ ] Extend `test/chimeway/migration_contract_test.exs` - current public-schema checks labeled as explicit legacy compatibility.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| PostgreSQL 15+ baseline confidence | PFX-04 | Local research environment reported PostgreSQL 14.17, below project baseline. | Confirm CI or a local PostgreSQL 15+ environment runs the Phase 73 full suite. |

---

## Validation Sign-Off

- [ ] All tasks have automated verify commands or Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags.
- [ ] Feedback latency under 60 seconds for focused checks.
- [ ] `nyquist_compliant: true` set in frontmatter after the mapped tests are implemented and passing.

**Approval:** pending

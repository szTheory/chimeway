---
phase: 74
slug: prefixed-migration-generator
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-30
---

# Phase 74 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit bundled with Elixir 1.17+ |
| **Config file** | `config/test.exs` configures `Chimeway.Repo` with `Ecto.Adapters.SQL.Sandbox` |
| **Quick run command** | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs --warnings-as-errors` |
| **Full suite command** | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs test/chimeway/migration_contract_test.exs --warnings-as-errors` |
| **CI path gate** | `mix ci.install_golden` in the `.github/workflows/ci.yml` `install_golden_contract` job |
| **Estimated runtime** | quick: < 30 seconds; full: ~1-3 minutes depending on fixture subprocess work |

---

## Sampling Rate

- **After every installer-core task commit:** Run `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs --warnings-as-errors`.
- **After every fixture or generated-output task commit:** Run the focused installer golden/idempotency command that covers the edited files.
- **After every plan wave:** Run `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs test/chimeway/migration_contract_test.exs --warnings-as-errors`.
- **Before `/gsd:verify-work`:** Run `mix ci.install_golden` plus the prefixed migration contract command and the existing `mix ci.test` gate.
- **Max feedback latency:** keep focused commands under 3 minutes; use CI Postgres 15 as authoritative for final DB contract proof because local PostgreSQL is below the project baseline.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 74-01-01 | TBD | 1 | MIG-01 | T-74-01 | Default generation is deterministic and schema-qualified for `chimeway` | unit + golden | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs --warnings-as-errors` | existing tests need expansion | pending |
| 74-01-02 | TBD | 1 | MIG-02 | T-74-02 | Prefixed templates qualify tables, indexes, references, alters, drops, and raw SQL | static + DB integration | `MIX_ENV=test mix test test/chimeway/install/prefix_contract_test.exs --warnings-as-errors` | missing Wave 0 test file | pending |
| 74-01-03 | TBD | 1 | MIG-03 | T-74-03 | Explicit `--prefix public` emits unprefixed legacy migrations without unsafe `prefix: false` options | unit + golden | `MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs --warnings-as-errors` | existing test needs public fixture root | pending |
| 74-01-04 | TBD | 2 | MIG-04 | T-74-04 | Both prefixed and public generation modes are idempotent and covered by migration contracts | integration | `MIX_ENV=test mix test test/chimeway/install/idempotency_test.exs test/chimeway/migration_contract_test.exs --warnings-as-errors` | existing tests need mode coverage | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `test/chimeway/install/prefix_contract_test.exs` - static generated-output guard for bare Ecto calls and raw SQL Chimeway references in prefixed mode.
- [ ] `test/fixtures/installer_golden_prefixed/` - committed default prefixed fixture tree and stdout.
- [ ] `test/fixtures/installer_golden_public/` - committed explicit public legacy fixture tree and stdout.
- [ ] `test/support/installer_fixture.ex` - option support for passing `--prefix chimeway` and `--prefix public` to the real subprocess.
- [ ] Prefixed migration contract setup - normal migration execution without `--prefix`, with object assertions under the `chimeway` schema and public legacy proof preserved.

---

## Manual-Only Verifications

All phase behaviors should have automated verification. The only non-automated judgment is final CI confirmation on PostgreSQL 15 when local PostgreSQL is below the project baseline.

---

## Validation Sign-Off

- [ ] All tasks have automated verification or Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags.
- [ ] Feedback latency stays under 3 minutes for focused commands.
- [ ] `nyquist_compliant: true` set in frontmatter after planner maps task IDs and executable verification is complete.

**Approval:** pending

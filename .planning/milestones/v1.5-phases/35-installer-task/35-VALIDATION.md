---
phase: 35
slug: installer-task
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-28
---

# Phase 35 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.17+) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix ci.install_golden` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | ~15 seconds (installer contracts only) |

---

## Sampling Rate

- **After every task commit:** Run `mix ci.install_golden`
- **After every plan wave:** Run `mix ci`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 35-01-01 | 01 | 1 | INST-01 | — | N/A (templates only) | unit | `mix test test/chimeway/install/migrations_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 35-01-02 | 01 | 1 | INST-01 | T-35-01 | Repo config required before generation; no path traversal outside host migrations dir | unit | `mix test test/chimeway/install/migrations_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 35-02-01 | 02 | 2 | INST-01 | — | N/A | integration | `mix test test/chimeway/install/golden_diff_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 35-02-02 | 02 | 2 | INST-02 | — | Second run creates zero new files | integration | `mix test test/chimeway/install/idempotency_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 35-03-01 | 03 | 3 | INST-02 | — | CI alias runs both contract tests | integration | `mix ci.install_golden` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/support/installer_fixture.ex` — scaffold host, subprocess runner, timestamp normalizer
- [ ] `test/chimeway/install/migrations_test.exs` — pure function unit tests for slug/namespace rewrite
- [ ] `test/fixtures/installer_golden/` — committed tree + STDOUT.txt (created during golden capture task)

*Wave 0 completes when test support and unit test stubs exist before golden capture.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Hex package ships templates | INST-01 | Tarball unpack not in default CI | `mix hex.build --unpack --output /tmp/chimeway_verify && ls /tmp/chimeway_verify/priv/chimeway_migrations \| wc -l` expect 31 |

*All other phase behaviors have automated verification via golden-diff and idempotency contracts.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

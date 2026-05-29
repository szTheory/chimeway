---
phase: 54
slug: mailglass-adapter-core
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-29
---

# Phase 54 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Mailglass.TestRepo (when mailglass dep present) |
| **Config file** | `config/test.exs`, `test/test_helper.exs` (Mailglass env) |
| **Quick run command** | `mix test test/chimeway/adapters/mailglass_adapter_test.exs --warnings-as-errors` |
| **Full suite command** | `mix test --warnings-as-errors` |
| **Estimated runtime** | ~20 seconds (adapter file); ~2 minutes (full suite) |

---

## Sampling Rate

- **After every task commit:** Run quick run command (when test file exists)
- **After every plan wave:** Run quick run command + `mix compile --warnings-as-errors`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 54-01-01 | 01 | 1 | ECOS-01 | T-54-01 | Optional dep does not force mailglass on hosts | compile | `mix compile --warnings-as-errors` | ⬜ W0 | ⬜ pending |
| 54-01-02 | 01 | 1 | ECOS-01 | T-54-02 | Mailglass test config uses Fake adapter only | unit | `mix test test/chimeway/adapters/mailglass_adapter_test.exs --warnings-as-errors` | ⬜ W0 | ⬜ pending |
| 54-02-01 | 02 | 2 | ECOS-01 | T-54-03 | Secrets read at runtime only; meta redacted | unit | `mix test test/chimeway/adapters/mailglass_adapter_test.exs --warnings-as-errors` | ⬜ W0 | ⬜ pending |
| 54-02-02 | 02 | 2 | ECOS-01 | T-54-04 | Tenancy stamped before Outbound.deliver | unit | same as above | ⬜ W0 | ⬜ pending |
| 54-03-01 | 03 | 3 | ECOS-02 | T-54-05 | ContractTest success + redaction | unit | same as above | ⬜ W0 | ⬜ pending |
| 54-03-02 | 03 | 3 | ECOS-02 | T-54-06 | Error classes :temporary/:permanent/:bounced | unit | same as above | ⬜ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ flaky · ❌ red*

---

## Wave 0 Requirements

- [ ] `test/support/chimeway/mailglass_fixtures.ex` — test mailable + sample delivery builder
- [ ] `test/chimeway/adapters/mailglass_adapter_test.exs` — ContractTest harness (may start minimal, expanded in 54-03)
- [ ] Mailglass test env in `config/test.exs` or `test/test_helper.exs` — repo + Fake adapter
- [ ] `mix.exs` — `{:mailglass, "~> 1.3", optional: true}`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Host E2E notifier → Mailglass render | ECOS-01 (roadmap criterion 1) | Requires host Mailglass mailable + SMTP/Fake in host app | Deferred to Phase 56 DEMO-06 |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

---
phase: 29
slug: outbound-channel-contracts
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-30
---

# Phase 29 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Authoritative validation architecture lives in `29-RESEARCH.md` § "Validation Architecture".
> This file is the operational contract executors enforce per task.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir built-in) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/chimeway/rendering/channel_contract_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds (quick) / ~90 seconds (full) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/chimeway/rendering/channel_contract_test.exs` (or the test file the task touches)
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~15 seconds (quick) / ~90 seconds (full)

---

## Per-Task Verification Map

> Populated by `gsd-planner` from PLAN.md frontmatter. One row per task. Status starts `⬜ pending` and is flipped during execution.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| _to be filled by planner_ | | | | | | | | | |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `lib/chimeway/rendering/channel.ex` — public behaviour MUST exist before built-in channels can `use` it (compile-order requirement)
- [ ] Migration `priv/repo/migrations/YYYYMMDD_add_adapter_module_to_chimeway_delivery_attempts.exs` — must exist before schema/integration tests can assert on `attempt.adapter_module`
- [ ] `lib/chimeway/rendering/channels/sms.ex`, `push.ex`, `chat.ex` — new modules referenced by extended `test/chimeway/rendering/channel_contract_test.exs`
- [ ] `test/chimeway/rendering/channel_contract_test.exs` — extended with Sms, Push, Chat round-trips and one registry-overlay case (file exists; add cases)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| _none — all Phase 29 behaviors have automated verification per the Coverage Matrix in RESEARCH.md_ | | | |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (channel behaviour module, migration, new channel modules)
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s (full suite)
- [ ] All 25 locked decisions D-01..D-25 covered by at least one test (see RESEARCH.md "Coverage Matrix: Decisions → Tests")
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

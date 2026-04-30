---
phase: 29
slug: outbound-channel-contracts
status: draft
nyquist_compliant: true
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

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-T1 | 01 | 1 | CHAN-01, CHAN-02 | T-29-01, T-29-02, T-29-03 | `@callback validate/1` + `__using__` macro; compiler catches missing callbacks | ExUnit (mix compile) | `mix compile 2>&1 \| grep -v "^$" \| head -20` | lib/chimeway/rendering/channel.ex | ⬜ pending |
| 02-T1 | 02 | 1 | CHAN-01 | T-29-04, T-29-05, T-29-06 | Migration adds nullable adapter_module column; no atom-from-string risk | ExUnit (mix ecto.migrate) | `mix ecto.migrate 2>&1 \| tail -5` | priv/repo/migrations/20260430120000_add_adapter_module_to_chimeway_delivery_attempts.exs | ⬜ pending |
| 02-T2 | 02 | 1 | CHAN-01 | T-29-04, T-29-06 | Schema field + optional_fields; no String.to_atom at schema boundary | ExUnit (mix compile) | `mix compile 2>&1 \| grep -E "error\|warning" \| head -10` | lib/chimeway/delivery_attempt.ex | ⬜ pending |
| 03-T1 | 03 | 2 | CHAN-01, CHAN-02 | T-29-07, T-29-08, T-29-09, T-29-10 | Sms strips vendor fields; Push/Chat accept opaque maps; @impl enforces contract | ExUnit | `mix test test/chimeway/rendering/channel_contract_test.exs 2>&1 \| tail -10` | lib/chimeway/rendering/channels/sms.ex, push.ex, chat.ex | ⬜ pending |
| 03-T2 | 03 | 2 | CHAN-01, CHAN-02 | T-29-10 | @behaviour declared; compiler warns on missing validate/1 | ExUnit (mix compile) | `mix compile 2>&1 \| grep -E "error\|undefined" \| head -10` | lib/chimeway/rendering/channels/email.ex, in_app.ex | ⬜ pending |
| 04-T1 | 04 | 3 | CHAN-01, CHAN-02 | T-29-11, T-29-12, T-29-13, T-29-14, T-29-14b | Registry lookup uses Map.get (no String.to_atom); channel_unregistered fires once via :persistent_term | ExUnit | `mix test test/chimeway/rendering/channel_contract_test.exs 2>&1 \| tail -10` | lib/chimeway/rendering.ex | ⬜ pending |
| 04-T2 | 04 | 3 | CHAN-01, CHAN-02 | T-29-11, T-29-12, T-29-14 | Boot validation rejects non-loaded modules; adapter_module in safe_meta allowlist | ExUnit | `mix compile 2>&1 \| grep -E "^(error\|warning)" \| head -10; mix test test/chimeway/telemetry_integration_test.exs 2>&1 \| tail -10` | lib/chimeway/application.ex, lib/chimeway/telemetry.ex | ⬜ pending |
| 05-T1 | 05 | 3 | CHAN-01 | T-29-15, T-29-16, T-29-17, T-29-18 | resolve_adapter uses Map.get (no String.to_atom); adapter_module persisted as inspect() string | ExUnit | `mix test test/chimeway/integration/delivery_lifecycle_test.exs 2>&1 \| tail -15` | lib/chimeway/dispatch/executor.ex | ⬜ pending |
| 05-T2 | 05 | 3 | CHAN-01 | T-29-15, T-29-17 | adapter_module threaded into :sync stop metadata via safe_meta; nil for failures | ExUnit | `mix test test/chimeway/integration/delivery_lifecycle_test.exs 2>&1 \| tail -15` | lib/chimeway/dispatch/sync.ex | ⬜ pending |
| 06-T1 | 06 | 4 | CHAN-01 | T-29-19, T-29-20 | nil adapter_module from pre-Phase-29 rows does not crash explain_delivery | ExUnit | `mix test test/chimeway/traces_test.exs 2>&1 \| tail -15` | lib/chimeway/traces.ex, lib/chimeway/traces/explanation.ex | ⬜ pending |
| 07-T1 | 07 | 4 | CHAN-01, CHAN-02 | T-29-21, T-29-22, T-29-23 | channel-tagged mailbox send; delivered_messages/0 still works | ExUnit (mix compile) | `mix compile 2>&1 \| grep -E "error" \| head -5` | lib/chimeway/adapters/test.ex | ⬜ pending |
| 07-T2 | 07 | 4 | CHAN-01, CHAN-02 | T-29-10, T-29-11 | D-13 boot raises ArgumentError; registry-overlay resolves host channel | ExUnit | `mix test test/chimeway/rendering/channel_contract_test.exs test/chimeway/application_validation_test.exs 2>&1 \| tail -15` | test/chimeway/rendering/channel_contract_test.exs, test/chimeway/application_validation_test.exs | ⬜ pending |
| 07-T3 | 07 | 4 | CHAN-01, CHAN-02 | T-29-15, T-29-19, T-29-21 | D-21 adapter_module differs across attempts; :persistent_term erased in on_exit for telemetry test | ExUnit | `mix test test/chimeway/integration/delivery_lifecycle_test.exs test/chimeway/traces_test.exs test/chimeway/telemetry_integration_test.exs 2>&1 \| tail -20` | test/chimeway/integration/delivery_lifecycle_test.exs, test/chimeway/traces_test.exs, test/chimeway/telemetry_integration_test.exs | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `lib/chimeway/rendering/channel.ex` — public behaviour MUST exist before built-in channels can `use` it (compile-order requirement)
- [ ] Migration `priv/repo/migrations/20260430120000_add_adapter_module_to_chimeway_delivery_attempts.exs` — must exist before schema/integration tests can assert on `attempt.adapter_module`
- [ ] `lib/chimeway/rendering/channels/sms.ex`, `push.ex`, `chat.ex` — new modules referenced by extended `test/chimeway/rendering/channel_contract_test.exs`
- [ ] `test/chimeway/rendering/channel_contract_test.exs` — extended with Sms, Push, Chat round-trips and one registry-overlay case (file exists; add cases)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| _none — all Phase 29 behaviors have automated verification per the Coverage Matrix in RESEARCH.md_ | | | |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify blocks
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (channel behaviour module, migration, new channel modules)
- [x] No watch-mode flags
- [x] Feedback latency < 90s (full suite)
- [x] All 25 locked decisions D-01..D-25 covered by at least one test (see RESEARCH.md "Coverage Matrix: Decisions → Tests")
- [x] D-13 boot validation test added (application_validation_test.exs — BLOCKER 3 fix)
- [x] D-21 per-attempt adapter_module diff test added (delivery_lifecycle_test.exs — WARNING 2 fix)
- [x] D-14 :persistent_term once-flag + on_exit erase added to telemetry test (WARNING 1 fix)
- [x] `nyquist_compliant: true` set — all tasks have `<automated>` verify blocks

**Approval:** pending

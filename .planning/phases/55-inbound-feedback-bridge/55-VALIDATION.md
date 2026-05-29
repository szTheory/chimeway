---
phase: 55
slug: inbound-feedback-bridge
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-29
---

# Phase 55 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Mailglass.DataCase + Chimeway.DataCase |
| **Config file** | `config/test.exs`, test setup for Postmark webhook provider |
| **Quick run command** | `mix test test/chimeway/adapters/mailglass_adapter_test.exs test/chimeway/webhooks/ --warnings-as-errors` |
| **Full suite command** | `mix test --warnings-as-errors` |
| **Estimated runtime** | ~45 seconds (webhook files); ~2 minutes (full suite) |

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
| 55-01-01 | 01 | 1 | ECOS-03 | T-55-01 | provider_message_id persisted on outbound success | unit | `mix test test/chimeway/dispatch/ --warnings-as-errors` | ⬜ W0 | ⬜ pending |
| 55-01-02 | 01 | 1 | ECOS-03 | T-55-02 | raw_body/headers threaded; optional parse_webhook_body | unit | `mix test test/chimeway/webhooks_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 55-02-01 | 02 | 2 | ECOS-03 | T-55-03 | verify_webhook rejects bad signature | unit | `mix test test/chimeway/adapters/mailglass_adapter_test.exs --warnings-as-errors` | ⬜ W0 | ⬜ pending |
| 55-02-02 | 02 | 2 | ECOS-03 | T-55-04 | normalize maps delivered/bounced/failed | unit | same as above | ⬜ W0 | ⬜ pending |
| 55-02-03 | 02 | 2 | ECOS-03 | T-55-05 | engagement events return :error | unit | same as above | ⬜ W0 | ⬜ pending |
| 55-03-01 | 03 | 3 | ECOS-03 | T-55-06 | provider_event_id dedup | unit | same as above | ⬜ W0 | ⬜ pending |
| 55-03-02 | 03 | 3 | ECOS-04 | T-55-07 | webhook → signal → trace integration | integration | `mix test test/chimeway/adapters/mailglass_webhook_pipeline_test.exs --warnings-as-errors` | ⬜ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/support/chimeway/mailglass_fixtures.ex` — Postmark Delivery/Bounce webhook payloads + auth headers
- [ ] `test/chimeway/adapters/mailglass_webhook_pipeline_test.exs` — ECOS-04 integration test (created in 55-03)
- [ ] Optional `parse_webhook_body/3` on `Chimeway.Adapter` + Mailglass implementation

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Demo host HTTP webhook route | ECOS-03 (roadmap criterion 1 host mount) | D-17 — Phase 56 scope | Deferred to Phase 56 DEMO-06 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

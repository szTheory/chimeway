---
phase: 56
slug: blueprint-demo-proof
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-29
---

# Phase 56 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.17+) |
| **Config file** | `config/test.exs`, `examples/chimeway_demo_host/config/test.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` |
| **Full suite command** | `mix verify.journeys` + `cd examples/chimeway_demo_host && mix test --only mailglass` |
| **Estimated runtime** | ~30–90 seconds |

---

## Sampling Rate

- **After every task commit:** Run the task `<verify>` command
- **After plan 56-01 (demo):** `cd examples/chimeway_demo_host && mix test --only mailglass --warnings-as-errors`
- **After plan 56-02 (recipe):** `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors`
- **Before `/gsd-verify-work`:** `mix verify.journeys` MUST exit 0
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 56-01-* | 01 | 1 | DEMO-06 | T-56-01 / — | Journey suite unchanged (Logger adapter default) | integration | `mix verify.journeys` | ✅ | ⬜ pending |
| 56-01-* | 01 | 1 | DEMO-06 | T-56-02 / — | Mailglass meta redaction in traces (no raw PII) | integration | `cd examples/chimeway_demo_host && mix test --only mailglass` | ❌ W1 | ⬜ pending |
| 56-02-* | 02 | 2 | ECOS-05 | — | Recipe forbids fictional modules | unit | `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements (Phase 54–55 Mailglass adapter, doc-contract harness, demo host journeys). Demo host adds Mailglass test config only.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Local demo browse | DEMO-06 | Optional UX check | `mix phx.server` in demo host, trigger invite, open `/admin/chimeway` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] `mix verify.journeys` green after demo host changes
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

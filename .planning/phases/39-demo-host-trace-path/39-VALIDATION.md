---
phase: 39
slug: demo-host-trace-path
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-28
---

# Phase 39 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit 1.17+ (demo host example app) |
| **Config file** | `examples/chimeway_demo_host/config/test.exs` |
| **Quick run command** | `cd examples/chimeway_demo_host && mix compile --warnings-as-errors` |
| **Full suite command** | `cd examples/chimeway_demo_host && mix test` |
| **Estimated runtime** | ~30 seconds (compile); ~60 seconds (full test) |

---

## Sampling Rate

- **After every task commit:** Run `cd examples/chimeway_demo_host && mix compile --warnings-as-errors`
- **After every plan wave:** Manual UAT — follow README IEx walkthrough end-to-end
- **Before `/gsd-verify-work`:** Maintainer confirms README steps + golden-path link
- **Max feedback latency:** 60 seconds (compile/test)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 39-01-01 | 01 | 1 | DEMO-01 | — | N/A | compile | `cd examples/chimeway_demo_host && mix compile --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 39-01-02 | 01 | 1 | DEMO-01 | — | N/A | compile | same | ❌ W0 | ⬜ pending |
| 39-02-01 | 02 | 2 | DEMO-01 | T-39-01 | No fixture insert instructions in README | grep | `rg -n 'Repo\.insert!' examples/chimeway_demo_host/README.md`; exit 1 if match | ❌ W0 | ⬜ pending |
| 39-02-02 | 02 | 2 | DEMO-01 | — | N/A | manual | Follow README IEx steps | ❌ W0 | ⬜ pending |
| 39-03-01 | 03 | 2 | DEMO-01 | — | N/A | grep | `rg 'Validate in the demo host' guides/introduction/golden-path.md` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `examples/chimeway_demo_host/README.md` — DEMO-01 primary surface
- [ ] `examples/chimeway_demo_host/lib/demo_host/notifiers/trace_demo.ex` — runnable notifier
- [ ] Extended `examples/chimeway_demo_host/config/dev.exs` — IEx Chimeway runtime

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| IEx walkthrough completes | DEMO-01 | No CI IEx harness in this phase (D-09) | From repo root: migrate DB, `cd examples/chimeway_demo_host && iex -S mix`, run README steps, confirm `explain_delivery/1` returns `:succeeded` timeline |
| Adopter can find golden-path link | DEMO-01 ROADMAP #3 | Doc navigation | Open golden-path §7, follow link to demo host README |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or manual instructions
- [ ] Sampling continuity: compile check after code tasks
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s for compile
- [ ] `nyquist_compliant: true` set in frontmatter after execute

**Approval:** pending

---
phase: 62
slug: inbox-demo-docs-gate
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-30
---

# Phase 62 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix) |
| **Config file** | `mix.exs` aliases `verify.inbox`, `ci.verify_gates`, `ci.test` excludes |
| **Quick run command** | `mix ci.verify_gates` |
| **Full suite command** | `mix verify.inbox --warnings-as-errors` |
| **Estimated runtime** | ~30–60s verify_gates; ~1–2 min verify.inbox |

---

## Sampling Rate

- **After every task commit:** Run `mix ci.verify_gates` when doc-contract or release-gate files changed
- **After every plan wave:** Run `mix verify.inbox --warnings-as-errors` after Wave 1 (62-01 + 62-03)
- **Phase acceptance:** Green `mix ci.verify_gates` + green `verify_inbox` CI job — no `/gsd-verify-work` required
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 62-01-01 | 01 | 1 | DEMO-08 | T-62-01 | Inbox auth resolves end-user recipient, not operator actor | integration | `cd examples/chimeway_demo_host && mix test --only inbox --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 62-02-01 | 02 | 2 | DOCS-08 | T-62-02 | Guide cites public Chimeway API delegates only | doc | `mix ci.docs` + guide grep | ❌ W0 | ⬜ pending |
| 62-02-02 | 02 | 2 | DOCS-09 | T-62-03 | Doc-contract locks guide required strings | unit | `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 62-03-01 | 03 | 1 | GATE-05 | T-62-04 | CI runs verify.inbox without sibling checkout | integration | `verify_inbox` CI job + release gate parity contract | ❌ W0 | ⬜ pending |
| 62-03-02 | 03 | 1 | GATE-05 | — | MAINTAINING lists eight gates | doc | `release gate parity doc contract (GATE-05)` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — no Wave 0 install.

- Doc-contract harness exists (`doc_contract_test.exs`)
- Release gate parity harness exists (`release_gate_contract_test.exs`)
- `chimeway_inbox` package tests green (Phase 61)
- `verify_mailglass` / `verify_accrue` CI jobs are copy templates

---

## Automated Acceptance (Zero-Human UAT)

All former manual checks are now machine-verified:

| Former manual item | Automated replacement |
|--------------------|----------------------|
| Demo inbox journey walkthrough | `@moduletag :inbox` proof test in demo host |
| Guide golden-path walkthrough | Section-ordering + required-string doc contracts in `doc_contract_test.exs` |
| CI job green on GitHub | `verify_inbox` job in `.github/workflows/ci.yml` + release gate parity contract |
| MAINTAINING ↔ CI parity | `release_gate_contract_test.exs` |

Prose readability remains a code-review concern, not a release gate.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

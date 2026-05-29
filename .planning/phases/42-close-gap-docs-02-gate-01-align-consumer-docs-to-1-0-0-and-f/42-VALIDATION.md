---
phase: 42
slug: close-gap-docs-02-gate-01-align-consumer-docs-to-1-0-0-and-f
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-29
---

# Phase 42 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.17+) |
| **Config file** | `mix.exs` aliases (`ci`, `ci.docs`, `ci.verify_gates`, `verify.example`) |
| **Quick run command** | `mix ci.verify_gates` |
| **Docs command** | `mix ci.docs` |
| **Full suite command** | `mix ci && mix ci.docs && mix ci.verify_gates && mix verify.example` |
| **Estimated runtime** | ~60 seconds (quartet) |

---

## Sampling Rate

- **After every task commit:** Run task `<verify><automated>` command when present; otherwise `mix ci.verify_gates` for doc-contract tasks or `mix ci.docs` for link-fix tasks
- **After every plan wave:** Run the wave's primary gate command from the table below
- **Before `/gsd-verify-work`:** Pre-ship quartet must be green (D-01)
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 42-01-01 | 01 | 1 | DOCS-02 | — | N/A | integration | `mix ci.verify_gates` | ✅ | ⬜ pending |
| 42-01-02 | 01 | 1 | DOCS-02 | T-42-01 | No stale 0.x version strings in consumer docs | unit | `mix ci.verify_gates` | ✅ | ⬜ pending |
| 42-02-01 | 02 | 2 | GATE-01 | — | N/A | docs build | `mix ci.docs` | ✅ | ⬜ pending |
| 42-02-02 | 02 | 2 | GATE-01 | — | N/A | docs build | `mix ci.docs` | ✅ | ⬜ pending |
| 42-03-01 | 03 | 3 | GATE-01 | T-42-03 | No prod auth bypass documented | grep | `! grep -q ALLOW_DEMO_ADMIN examples/chimeway_demo_host/README.md` | ✅ | ⬜ pending |
| 42-03-02 | 03 | 3 | GATE-01 | — | N/A | quartet | `mix ci && mix ci.docs && mix ci.verify_gates && mix verify.example` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements:

- [x] `test/chimeway/doc_contract_test.exs` — consumer version alignment + drift patterns
- [x] `mix ci.verify_gates` — scoped doc-contract entrypoint (Phase 41)
- [x] `mix ci.docs` — HexDocs with `--warnings-as-errors`
- [x] `mix verify.example` — demo host + chimeway_admin smoke (Phase 41)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Audit artifact status | D-02 closure | Markdown planning doc | Update `v1.5-MILESTONE-AUDIT.md` `status: gaps_found` → `passed` after quartet green |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

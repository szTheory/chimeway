---
phase: 66
slug: docs-release-gates
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-30
---

# Phase 66 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir built-in) |
| **Config file** | `test/test_helper.exs` (existing) |
| **Quick run command** | `mix ci.verify_gates` |
| **Full suite command** | `mix ci` then `mix verify.threadline` and `mix verify.sigra` |
| **Estimated runtime** | ~30 seconds (ci.verify_gates); ~2–3 min (verify.threadline / verify.sigra with dep compile) |

---

## Sampling Rate

- **After every task commit:** Run `mix ci.verify_gates`
- **After every plan wave:** Run `mix ci` (lint + test suite including updated contract tests)
- **Before `/gsd:verify-work`:** `mix verify.threadline` and `mix verify.sigra` must be green
- **Max feedback latency:** ~30 seconds (ci.verify_gates)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| Threadline guide | 01 | 1 | DOCS-10 | — | N/A | doc-contract | `mix ci.verify_gates` | ❌ Wave 0 | ⬜ pending |
| Sigra guide | 01 | 1 | DOCS-10 | — | N/A | doc-contract | `mix ci.verify_gates` | ❌ Wave 0 | ⬜ pending |
| Threadline doc-contract block | 02 | 1 | DOCS-11 | — | N/A | unit | `mix ci.verify_gates` | ❌ Wave 0 | ⬜ pending |
| Sigra doc-contract block | 02 | 1 | DOCS-11 | — | N/A | unit | `mix ci.verify_gates` | ❌ Wave 0 | ⬜ pending |
| verify.threadline alias | 03 | 2 | GATE-07 | — | N/A | integration | `mix verify.threadline` | ❌ Wave 0 | ⬜ pending |
| verify.sigra alias | 03 | 2 | GATE-07 | — | N/A | integration | `mix verify.sigra` | ❌ Wave 0 | ⬜ pending |
| verify_threadline CI job | 03 | 2 | GATE-07 | — | N/A | CI | GitHub Actions | ❌ Wave 0 | ⬜ pending |
| verify_sigra CI job | 03 | 2 | GATE-07 | — | N/A | CI | GitHub Actions | ❌ Wave 0 | ⬜ pending |
| MAINTAINING.md 10-command checklist | 03 | 2 | GATE-07 | — | N/A | doc-contract | `mix ci.verify_gates` | ❌ Wave 0 | ⬜ pending |
| release_gate_contract_test update | 02 | 1 | GATE-07 | — | N/A | unit | `mix ci.verify_gates` | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `guides/introduction/threadline-integration.md` — new guide file
- [ ] `guides/introduction/sigra-auth-integration.md` — new guide file
- [ ] `test/chimeway/doc_contract_test.exs` — two new describe blocks appended
- [ ] `test/chimeway/release_gate_contract_test.exs` — update to 10 commands, 11 CI lanes
- [ ] `mix.exs` aliases/0 — `verify.threadline` and `verify.sigra` entries
- [ ] `.github/workflows/ci.yml` — `verify_threadline` and `verify_sigra` jobs + ci-gate needs update

*All deliverables are Wave 0 — they ARE the phase. No pre-existing stubs needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `verify_threadline` and `verify_sigra` CI jobs green | GATE-07 | GitHub Actions runs only on push/PR | Push branch to GitHub, check Actions tab |
| Sibling repo SHA pins resolve correctly | GATE-07 | szTheory/threadline and szTheory/sigra HEAD SHAs must be looked up at implementation time | Check repo on GitHub before wiring CI jobs |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

---
phase: 60
slug: accrue-docs-release-gate
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-30
---

# Phase 60 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix) |
| **Config file** | `mix.exs` aliases `verify.accrue`, `ci.test` excludes |
| **Quick run command** | `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` |
| **Full suite command** | `ACCRUE_PATH="${ACCRUE_PATH:-../accrue/accrue}" mix verify.accrue --warnings-as-errors` |
| **Estimated runtime** | ~15s doc-contract; ~2–3 min verify.accrue |

---

## Sampling Rate

- **After every task commit:** Run quick doc-contract command when `doc_contract_test.exs` changed; otherwise grep/guide file check per plan
- **After every plan wave:** Run full `mix verify.accrue` when Accrue sibling available
- **Before `/gsd-verify-work`:** Doc-contract green + verify.accrue green (local or CI-equivalent env)
- **Max feedback latency:** 180 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 60-01-01 | 01 | 1 | DOCS-08 | T-60-01 | Guide uses billing-event path, not fictional modules | doc | `test -f guides/introduction/accrue-dunning-integration.md` | ✅ | ⬜ pending |
| 60-01-02 | 01 | 1 | DOCS-08 | — | Reciprocal blueprint/README links | doc | `grep accrue-dunning-integration README.md` | ✅ | ⬜ pending |
| 60-02-01 | 02 | 2 | DOCS-09 | T-60-02 | Doc-contract locks guide truth | unit | `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 60-03-01 | 03 | 1 | GATE-05 | T-60-03 | CI checks out Accrue sibling before verify | integration | `mix verify.accrue` with ACCRUE_PATH | ✅ | ⬜ pending |
| 60-03-02 | 03 | 1 | GATE-05 | — | MAINTAINING lists seven gates | doc | `grep verify.accrue MAINTAINING.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — no Wave 0 install.

- Doc-contract harness exists (`doc_contract_test.exs`)
- `mix verify.accrue` alias exists (Phase 59)
- `verify_mailglass` CI job is copy template

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Guide readability walkthrough | DOCS-08 | Prose quality | Fresh reader follows guide deps → verify without prior Accrue context |
| CI job first green on GitHub | GATE-05 | Requires push/Actions | Confirm `verify_accrue` job passes on PR |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 180s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending execution

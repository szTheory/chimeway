---
phase: 94
slug: mailglass-transactional-email-proof
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-08-08
---

# Phase 94 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit / Mix |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs` |
| **Full suite command** | `mix ci.verify_gates` |
| **Estimated runtime** | ~60 seconds |

## Sampling Rate

- **After every task commit:** Run `mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs`
- **After every plan wave:** Run `mix ci.verify_gates`
- **Before phase verification:** `mix ci.verify_gates` must be green.
- **Max feedback latency:** 60 seconds

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 94-01-01 | 01 | 1 | MAIL-01 | — | The clean consumer proves only allowlisted trace evidence and rejects unsafe proof output. | integration / contract | `mix test test/chimeway/release_gate_contract_test.exs` | ✅ | ⬜ pending |
| 94-01-02 | 01 | 1 | MAIL-02 | — | Public documentation names the Fake transport boundary and does not direct adopters to maintainer-only commands. | documentation contract | `mix test test/chimeway/doc_contract_test.exs` | ✅ | ⬜ pending |
| 94-01-03 | 01 | 1 | MAIL-01, MAIL-02 | — | Release and documentation gates remain in parity. | gate suite | `mix ci.verify_gates` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

## Wave 0 Requirements

Existing ExUnit release-gate and documentation-contract infrastructure covers all phase requirements.

## Manual-Only Verifications

All phase behaviors have automated verification.

## Validation Sign-Off

- [ ] All tasks have automated verification.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification.
- [x] Existing infrastructure covers all requirements.
- [ ] No watch-mode flags.
- [ ] Feedback latency < 60 seconds.
- [ ] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending

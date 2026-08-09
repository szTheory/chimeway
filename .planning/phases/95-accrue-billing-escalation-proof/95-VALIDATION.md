---
phase: 95
slug: accrue-billing-escalation-proof
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-09
---

# Phase 95 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci.verify_gates` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run the quick-run command above.
- **After every plan wave:** Run `mix ci.verify_gates`.
- **Before `$gsd-verify-work`:** Full suite must be green.
- **Max feedback latency:** 60 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 95-01-01 | 01 | 1 | ACCR-01, ACCR-02 | T-95-01 | Consumer proof projects only allowlisted public lifecycle and provenance fields. | integration + contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 95-01-02 | 01 | 1 | ACCR-01 | T-95-02 | `invoice.paid` evidence is `signal_received`, never a false completion claim. | integration | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 95-02-01 | 02 | 2 | ACCR-02 | T-95-03 | Documentation labels released packages only with resolved versions; pinned refs are compatibility-only. | doc contract | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Extend `test/support/artifact_consumer_fixture.ex` with the deterministic Accrue proof and strict parser.
- [ ] Extend `test/chimeway/release_gate_contract_test.exs` with lifecycle, provenance, and sensitive-output contracts.
- [ ] Extend `test/chimeway/doc_contract_test.exs` with released-package versus pinned-ref guidance contracts.

---

## Manual-Only Verifications

All phase behaviors have automated verification. The proof consumer must use an isolated temporary host/database and clean up after execution.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags.
- [ ] Feedback latency < 60 seconds.
- [ ] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending

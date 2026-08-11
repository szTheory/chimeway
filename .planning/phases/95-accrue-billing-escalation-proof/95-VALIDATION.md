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
| 95-01-01 | 01 | 1 | ACCR-01, ACCR-02 | T-95-01, T-95-03, T-95-04, T-95-05, T-95-06 | The committed runner accepts one unpacked artifact, executes the resolved public Oban/manual queue seam, and emits one allowlisted lifecycle/provenance record only after all gates pass. | integration + command contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 95-01-02 | 01 | 1 | ACCR-01, ACCR-02 | T-95-01, T-95-02, T-95-03, T-95-04, T-95-05, T-95-06 | Parser and failure-path contracts reject forged, sensitive, atomizing, mixed-provenance, source-tree, and cleanup-invalid evidence. | adversarial contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 95-02-01 | 02 | 2 | ACCR-01, ACCR-02 | T-95-07, T-95-08, T-95-09, T-95-11, T-95-12 | Guide contracts require the exact runner command and artifact/output/failure contract, natural event ordering, sanitized evidence, and non-terminal signal meaning. | doc contract | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 95-02-02 | 02 | 2 | ACCR-01, ACCR-02 | T-95-07, T-95-08, T-95-09, T-95-10, T-95-11, T-95-12 | Documentation permits release language only after exact resolved-package checks and keeps the pinned SHA compatibility-only, non-install guidance. | release + doc contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Execution-Wave Test Requirements

- [ ] In Wave 1, add `scripts/prove-accrue-consumer.exs` and extend `test/support/artifact_consumer_fixture.ex` with the deterministic Accrue proof and strict parser.
- [ ] In Wave 1, extend `test/chimeway/release_gate_contract_test.exs` with runner, lifecycle, queue-seam, provenance, and sensitive-output contracts.
- [ ] In Wave 2, extend `test/chimeway/doc_contract_test.exs` with exact-command, lifecycle-language, and released-package versus pinned-ref guidance contracts.

---

## Manual-Only Verifications

All phase behaviors have automated verification. The proof consumer must use an isolated temporary host/database and clean up after execution.

---

## Validation Sign-Off

- [ ] All four tasks have an exact `<automated>` verification command.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify.
- [ ] Wave 1 and Wave 2 test changes cover every planned behavior before each implementation expansion.
- [ ] No watch-mode flags.
- [ ] Feedback latency < 60 seconds.
- [ ] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending

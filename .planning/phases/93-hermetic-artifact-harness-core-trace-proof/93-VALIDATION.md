---
phase: 93
slug: hermetic-artifact-harness-core-trace-proof
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-08
---

# Phase 93 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix |
| **Config file** | `config/test.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci.verify_gates` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors`
- **After every plan wave:** Run `mix ci.verify_gates`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 93-01-01 | 01 | 1 | PROOF-01, PROOF-02 | T-93-01 | Consumer resolves `:chimeway` solely from an unpacked built artifact and uses its own disposable PostgreSQL database | integration contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 93-01-02 | 01 | 1 | PROOF-03, CORE-01 | T-93-02 | Consumer emits only allowlisted sanitized public explanation evidence from `Chimeway.Traces.explain_delivery/1` | integration contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/support/artifact_consumer_fixture.ex` — deterministic scaffold, command runner, unique DB cleanup, and diagnostics.
- [ ] `test/chimeway/release_gate_contract_test.exs` — Core artifact proof describe block that calls the fixture.

---

## Manual-Only Verifications

All phase behaviors have automated verification through the release-gate contract and `mix ci.verify_gates`.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

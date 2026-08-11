---
phase: 93
slug: hermetic-artifact-harness-core-trace-proof
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-08
validated: 2026-08-10
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
| **Observed runtime** | 745.4 seconds (134 tests, 0 failures on 2026-08-10) |

---

## Sampling Rate

- **After every task commit:** Run `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors`
- **After every plan wave:** Run `mix ci.verify_gates`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Observed full-file feedback latency:** ~13 minutes; the file now includes later Mailglass, Accrue, and aggregate adoption artifact contracts in addition to Phase 93 coverage.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 93-01-01 | 01 | 1 | PROOF-01, PROOF-02 | T-93-01 | Consumer resolves `:chimeway` solely from an unpacked built artifact and uses its own disposable PostgreSQL database | integration contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 93-01-02 | 01 | 1 | PROOF-03, CORE-01 | T-93-02 | Consumer emits only allowlisted sanitized public explanation evidence from `Chimeway.Traces.explain_delivery/1` | integration contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/support/artifact_consumer_fixture.ex` — deterministic scaffold, command runner, unique DB cleanup, and diagnostics.
- [x] `test/chimeway/release_gate_contract_test.exs` — Core artifact proof describe block that calls the fixture.

---

## Manual-Only Verifications

All phase behaviors have automated verification through the release-gate contract and `mix ci.verify_gates`.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Hermetic integration feedback is executable and bounded; current full-file runtime is documented above
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-08-10 — 134 tests, 0 failures

## Validation Audit 2026-08-10

| Metric | Count |
|--------|-------|
| Requirements audited | 4 |
| Task validation rows | 2 |
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Evidence: `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` completed in 745.4 seconds with 134 tests and 0 failures. The run emitted the already-documented non-failing Threadline sandbox ownership cleanup logs.

---
phase: 102
slug: alpha-digital-twin-hermetic-gate
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-25
---

# Phase 102 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit on Elixir 1.19.5 |
| **Config file** | `test/test_helper.exs` (manual Ecto SQL Sandbox mode) |
| **Quick run command** | `mix verify.physical_proof_contract` |
| **Full suite command** | `mix verify.alpha_twin && mix verify.physical_proof_contract && mix ci.verify_gates` |
| **Estimated runtime** | To be measured in Wave 0; CI timeout must remain explicit |

---

## Sampling Rate

- **After every task commit:** Run the narrow relevant `mix test` target or one named `mix verify.*` command.
- **After every plan wave:** Run `mix verify.alpha_twin && mix verify.physical_proof_contract`.
- **Before phase completion:** Run `mix ci.verify_gates` plus both named verification commands; machine-readable CI evidence replaces conversational UAT.
- **Max feedback latency:** Measure during Wave 0 and record an executable CI timeout; do not use watch mode or unbounded sleeps.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 102-01-01 | 01 | 1 | TWIN-01 | T-102-01 | Production clock remains default while the twin advances deterministic time without sleeps | unit + integration | Narrow clock-seam `mix test` target, then `mix verify.alpha_twin` | ❌ W0 | ⬜ pending |
| 102-01-02 | 01 | 1 | TWIN-01 | Sanitized host registry and scripted APNs transport expose only closed safe facts | process integration | `mix verify.alpha_twin` | ❌ W0 | ⬜ pending |
| 102-02-01 | 02 | 2 | TWIN-02 | Ordered ledger proves fan-out, suppression, rotation/revocation, retry, expiry, collapse, and crash recovery | process integration + fixture contract | `mix verify.alpha_twin` | ❌ W0 | ⬜ pending |
| 102-02-02 | 02 | 2 | TWIN-02 | Recursive leak sentinels and denied/replayed offline opens fail closed | negative integration | `mix verify.alpha_twin` | ❌ W0 | ⬜ pending |
| 102-03-01 | 03 | 3 | GATE-01 | Artifact digest and full CrossWake SHA are bound into safe proof bytes | contract + provenance | `mix verify.physical_proof_contract` | ❌ W0 | ⬜ pending |
| 102-03-02 | 03 | 3 | GATE-01 | Required CI jobs run both entrypoints without Apple credentials and reject malformed physical evidence | CI contract | `mix ci.verify_gates` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/fixtures/alpha_twin/` — committed sanitized host, copied migrations, host-owned registries, and scripted transport fixtures.
- [ ] `scripts/prove-alpha-twin.exs` and `Mix.Tasks.Verify.AlphaTwin` — immutable package and detached-checkout orchestration.
- [ ] `Mix.Tasks.Verify.PhysicalProofContract` plus a negative fixture corpus — closed physical-proof extension validation.
- [ ] Clock seam tests — prove the production default and deterministic fixture advancement without sleeps.
- [ ] Release-gate contract tests and a required `verify_alpha_twin` CI job — prove alias, job, aggregate, credential-free execution, and provenance parity.

---

## Manual-Only Verifications

All Phase 102 behaviors have automated verification. Physical device/APNs claims are explicitly out of scope; committed physical-proof fixtures are contract inputs, not human UAT.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency is measured and bounded by executable timeouts
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

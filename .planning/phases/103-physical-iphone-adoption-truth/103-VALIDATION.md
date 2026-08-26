---
phase: 103
slug: physical-iphone-adoption-truth
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-26
---

# Phase 103 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix verify.physical_proof_contract` |
| **Full suite command** | `mix ci.verify_gates && mix verify.alpha_twin && mix verify.physical_proof_contract` |
| **Estimated runtime** | Measure during Wave 0 and keep below the CI job timeout |

---

## Sampling Rate

- **After every task commit:** Run the task's focused ExUnit or contract command.
- **After every plan wave:** Run `mix ci.verify_gates && mix verify.alpha_twin && mix verify.physical_proof_contract`.
- **Before phase verification:** The full suite must be green; do not route machine-testable evidence through conversational UAT.
- **Max feedback latency:** One focused contract command per task; split slower external compatibility checks into their own explicit task.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 103-01-01 | 01 | 1 | TWIN-03 | planner-assigned | Physical proof rejects key, order, owner, revision, digest, privacy, and no-replace violations | unit/contract | `mix verify.physical_proof_contract` | ❌ W0 | ⬜ pending |
| 103-01-02 | 01 | 1 | TWIN-03 | planner-assigned | Hermetic proof v1 remains immutable | regression | `mix test test/chimeway/mobile_proof_extension_test.exs` | ✅ | ⬜ pending |
| 103-02-01 | 02 | 2 | TWIN-03 | planner-assigned | Selected CrossWake source bytes, marker, and source-bound compatibility checks pass | integration/contract | selected-SHA compatibility runner plus focused CrossWake tests | ❌ W0 | ⬜ pending |
| 103-02-02 | 02 | 2 | TWIN-03 | planner-assigned | Automation cannot produce an `observed` visible-alert attestation | unit | `mix test test/chimeway/mobile_physical_proof_test.exs` | ❌ W0 | ⬜ pending |
| 103-03-01 | 03 | 2 | DOCS-01 | planner-assigned | Guide roles, commands, vocabulary, links, support wording, and non-goals do not drift | doc contract | `mix ci.verify_gates` | ❌ W0 | ⬜ pending |

*Task and plan IDs are provisional until PLAN.md files are finalized; the planner must reconcile this map with the final decomposition.*

---

## Wave 0 Requirements

- [ ] Add the `mix verify.physical_proof_contract` alias and focused physical-proof contract tests.
- [ ] Add `test/chimeway/mobile_physical_proof_test.exs` fixtures covering attestation states and the automation/observation boundary.
- [ ] Pin the selected CrossWake SHA and provide a credential-free compatibility command that verifies the source-bound contract.
- [ ] Extend the doc/release contract exercised by `mix ci.verify_gates` for the canonical adoption guide.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| A visible notification alert appeared on the physical iPhone | TWIN-03 | The display observation is subjective and has no trustworthy machine-readable signal | On the dated sandbox run, the named observer records only the bounded `observed` attestation after seeing the alert; every provider, digest, protected-open, and no-replace assertion remains executable evidence. |

Apple signing credentials, a registered physical device, and sandbox APNs availability are external prerequisites, not conversational acceptance gates. Threshold A must remain executable and credential-free while Threshold B stays explicitly pending until those prerequisites are available.

---

## Validation Sign-Off

- [ ] All tasks have executable `<automated>` verification or explicit Wave 0 dependencies.
- [ ] Sampling continuity: no three consecutive tasks lack an automated verification command.
- [ ] Wave 0 covers every missing test or command above.
- [ ] No watch-mode flags are used.
- [ ] Machine-testable tracer and acceptance work is classified `type="auto"`; only visible-alert observation is manual.
- [ ] `nyquist_compliant: true` is set after the final plans reconcile this map.

**Approval:** pending

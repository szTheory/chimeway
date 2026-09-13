---
phase: 102
slug: alpha-digital-twin-hermetic-gate
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-25
audited: 2026-08-26
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
| **Estimated runtime** | ~75 seconds for `verify.alpha_twin`; 917.3 seconds for the 630-test aggregate gate; Alpha CI lane bounded at 20 minutes |

---

## Sampling Rate

- **After every task commit:** Run the narrow relevant `mix test` target or one named `mix verify.*` command.
- **After every plan wave:** Run `mix verify.alpha_twin && mix verify.physical_proof_contract`.
- **Before phase completion:** Run `mix ci.verify_gates` plus both named verification commands; machine-readable CI evidence replaces conversational UAT.
- **Max feedback latency:** 20 minutes, enforced by the `verify_alpha_twin` CI job; no watch mode or unbounded sleeps.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 102-01-01 | 01 | 1 | TWIN-01, TWIN-02 | T-102-01, T-102-02, T-102-03 | The packaged tracer fetches the exact public CrossWake SHA before crossing real persistence, host authority, and protected-open policy; unsafe runtime evidence blocks proof emission. | tracer + provenance + integration | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/alpha_twin_runner_test.exs --seed 0 --warnings-as-errors && mix verify.alpha_twin` | ✅ | ✅ green |
| 102-02-01 | 02 | 2 | TWIN-01, TWIN-02 | T-102-02A, T-102-03A, T-102-04A | Production-default and injected clocks, host-owned authority, and all scripted transport outcomes remain deterministic, bounded, and non-echoing. | unit + process integration | `mix verify.alpha_twin` | ✅ | ✅ green |
| 102-03-01 | 03 | 3 | TWIN-02 | T-102-05, T-102-06, T-102-09 | The exact ordered ledger derives delivery, recovery, retry, collapse, idempotency, concurrency, and lifecycle taxonomy from persisted and explained runtime state. | process integration + fixture contract | `ALPHA_PROOF_ONE=$(mix verify.alpha_twin) && ALPHA_PROOF_ONE=${ALPHA_PROOF_ONE##*$'\n'} && ALPHA_PROOF_TWO=$(mix verify.alpha_twin) && ALPHA_PROOF_TWO=${ALPHA_PROOF_TWO##*$'\n'} && test "$ALPHA_PROOF_ONE" = "$ALPHA_PROOF_TWO"` | ✅ | ✅ green |
| 102-03-02 | 03 | 3 | TWIN-02 | T-102-07, T-102-08, T-102-09 | Actual storage, traces, telemetry, exceptions, observations, and exact final proof bytes are scanned; stale, denied, and replayed opens activate nothing. | negative integration + emission contract | `mix verify.alpha_twin && CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/alpha_twin_runner_test.exs --seed 0 --warnings-as-errors` | ✅ | ✅ green |
| 102-04-01 | 04 | 4 | GATE-01, TWIN-01, TWIN-02 | T-102-10, T-102-11, T-102-12, T-102-13 | Safe proof bytes bind the actual archive digest and exact CrossWake SHA while the closed extension rejects every malformed physical-evidence class without promoting device claims. | contract + provenance + negative corpus | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/mobile_proof_extension_test.exs test/chimeway/alpha_twin_provenance_test.exs --seed 0 --warnings-as-errors && mix verify.physical_proof_contract && mix verify.alpha_twin` | ✅ | ✅ green |
| 102-04-02 | 04 | 4 | GATE-01, TWIN-01, TWIN-02 | T-102-11, T-102-14 | The credential-free CI job performs the exact public checkout and both non-vacuous gates, and both aggregate gates fail closed on missing or altered wiring. | CI topology contract | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only alpha_twin_gate_contract --seed 0 --warnings-as-errors && mix ci.verify_gates` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Credential-dependent prerequisite — exact commit `f2c502cdb1ce572a4a57257d9e3c051665704b90` is publicly fetchable from `https://github.com/szTheory/crosswake.git`; the clean-room gate re-fetches and checks it on every run.
- [x] `test/fixtures/alpha_twin/` — committed sanitized host, copied migrations, host-owned registries, scripted transport, and closed runtime-evidence scanning.
- [x] `scripts/prove-alpha-twin.exs` and `Mix.Tasks.Verify.AlphaTwin` — immutable package, detached checkout, disposable database, runtime-evidence artifact, and exact final-byte scan orchestration.
- [x] `Mix.Tasks.Verify.PhysicalProofContract` plus the ordered negative fixture corpus — closed physical-proof extension validation.
- [x] Clock seam and recovery-clock regression tests — production default, explicit resolved time, deterministic advancement, and shared stale-closeout clock without sleeps.
- [x] Release-gate contract test and required `verify_alpha_twin` CI job — alias, exact checkout, aggregate propagation, credential-free execution, provenance parity, and 20-minute bound.

The publication checkpoint is an external credential action, not one of the six implementation tasks above. Its completion is accepted only through the isolated automated fetch evidence recorded by Plan 01; it has no conversational or visual verification path.

---

## Manual-Only Verifications

All Phase 102 behaviors have automated verification. Physical device/APNs claims are explicitly out of scope; committed physical-proof fixtures are contract inputs, not human UAT.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or completed Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all formerly missing references
- [x] No watch-mode flags
- [x] Feedback latency is measured and bounded by executable timeouts
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-08-26

---

## Validation Audit 2026-08-26

| Metric | Count |
|--------|-------|
| Requirements audited | 3 |
| Task rows audited | 6 |
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Current executable evidence: 11 focused tracer/provenance/extension tests passed, the focused CI-topology contract passed, `mix verify.physical_proof_contract` passed, `mix verify.alpha_twin` emitted the provenance-bound proof, and the phase-final `mix ci.verify_gates` run passed 630 tests with 0 failures. No new test files were required.

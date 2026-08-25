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
| 102-01-01 | 01 | 1 | TWIN-01, TWIN-02 | T-102-01, T-102-02, T-102-03 | After the credential-only publication checkpoint, an isolated public fetch resolves the exact D-03 SHA before the packaged accepted tracer crosses real persistence, safe host authority, and protected-open policy. | tracer + provenance + integration | `CROSSWAKE_FETCH_DIR=$(mktemp -d) && trap 'rm -rf "$CROSSWAKE_FETCH_DIR"' EXIT && git -C "$CROSSWAKE_FETCH_DIR" init -q && git -C "$CROSSWAKE_FETCH_DIR" fetch --depth=1 https://github.com/szTheory/crosswake.git f2c502cdb1ce572a4a57257d9e3c051665704b90 && test "$(git -C "$CROSSWAKE_FETCH_DIR" rev-parse FETCH_HEAD)" = "f2c502cdb1ce572a4a57257d9e3c051665704b90" && scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/alpha_twin_runner_test.exs --only alpha_twin_tracer --seed 0 --warnings-as-errors && mix verify.alpha_twin` | ❌ W0 | ⬜ pending |
| 102-02-01 | 02 | 2 | TWIN-01 | T-102-02A, T-102-03A, T-102-04A | Production-default clock, host-owned authority, and ordered scripted transport remain closed, deterministic, and non-echoing. | unit + process integration | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/fixtures/alpha_twin/test/alpha_twin_test.exs --only alpha_twin_seams --seed 0 --warnings-as-errors && mix verify.alpha_twin` | ❌ W0 | ⬜ pending |
| 102-03-01 | 03 | 3 | TWIN-02 | T-102-05, T-102-06, T-102-09 | The exact ordered ledger proves delivery, recovery, idempotency, concurrency, and honest lifecycle taxonomy through the post-commit dispatcher seam. | process integration + fixture contract | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/fixtures/alpha_twin/test/alpha_twin_test.exs --only alpha_twin_delivery_matrix --seed 0 --warnings-as-errors && mix verify.alpha_twin && mix verify.alpha_twin` | ❌ W0 | ⬜ pending |
| 102-03-02 | 03 | 3 | TWIN-02 | T-102-07, T-102-08, T-102-09 | Recursive leak sentinels and stale, denied, or replayed offline opens fail closed with no fallback activation. | negative integration | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/fixtures/alpha_twin/test/alpha_twin_test.exs test/chimeway/alpha_twin_runner_test.exs --only alpha_twin_safety_matrix --seed 0 --warnings-as-errors && mix verify.alpha_twin` | ❌ W0 | ⬜ pending |
| 102-04-01 | 04 | 4 | GATE-01, TWIN-01, TWIN-02 | T-102-10, T-102-11, T-102-12, T-102-13 | Safe proof bytes bind the actual archive digest and exact CrossWake SHA while the closed extension rejects every malformed physical-evidence class without promoting device claims. | contract + provenance + negative corpus | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/mobile_proof_extension_test.exs test/chimeway/alpha_twin_provenance_test.exs --seed 0 --warnings-as-errors && mix verify.physical_proof_contract && mix verify.alpha_twin` | ❌ W0 | ⬜ pending |
| 102-04-02 | 04 | 4 | GATE-01, TWIN-01, TWIN-02 | T-102-11, T-102-14 | The credential-free CI job performs the exact public checkout and both non-vacuous gates, and both aggregate gates fail closed on missing or altered wiring. | CI topology contract | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only alpha_twin_gate_contract --seed 0 --warnings-as-errors && mix verify.alpha_twin && mix verify.physical_proof_contract && mix ci.verify_gates` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Credential-dependent prerequisite — an authorized maintainer publishes exact commit `f2c502cdb1ce572a4a57257d9e3c051665704b90` to `https://github.com/szTheory/crosswake.git`; the Plan 01 isolated unauthenticated fetch command must resolve `FETCH_HEAD` to that exact SHA before any implementation task starts.
- [ ] `test/fixtures/alpha_twin/` — committed sanitized host, copied migrations, host-owned registries, and scripted transport fixtures.
- [ ] `scripts/prove-alpha-twin.exs` and `Mix.Tasks.Verify.AlphaTwin` — immutable package and detached-checkout orchestration.
- [ ] `Mix.Tasks.Verify.PhysicalProofContract` plus a negative fixture corpus — closed physical-proof extension validation.
- [ ] Clock seam tests — prove the production default and deterministic fixture advancement without sleeps.
- [ ] Release-gate contract tests and a required `verify_alpha_twin` CI job — prove alias, job, aggregate, credential-free execution, and provenance parity.

The publication checkpoint is an external credential action, not one of the six implementation tasks above. Its completion is accepted only through the isolated automated fetch evidence recorded by Plan 01; it has no conversational or visual verification path.

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
- [ ] After every row is green and Wave 0 evidence exists, set `nyquist_compliant: true` in frontmatter

**Approval:** pending

---
phase: 101
slug: crosswake-registration-protected-open
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-22
---

# Phase 101 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit plus Swift XCTest/SPM |
| **Config file** | `../crosswake/mix.exs`, `../crosswake/packages/crosswake_chimeway/mix.exs`, `../crosswake/packages/crosswake-shell-core-ios/Package.swift` |
| **Quick run command** | `cd ../crosswake/packages/crosswake_chimeway && mix test test/crosswake/companions/chimeway/resolver_test.exs` |
| **Full suite command** | `cd ../crosswake && mix verify && cd packages/crosswake-shell-core-ios && swift test` |
| **Estimated runtime** | Measure during Wave 0 and record before implementation waves |

---

## Sampling Rate

- **After every task commit:** Run the focused ExUnit or Swift test command named by the task.
- **After every plan wave:** Run `cd ../crosswake && mix verify` plus `swift test` for shell changes.
- **Before phase verification:** Run the full deterministic contract, race, and privacy suite; do not request conversational UAT for machine-testable behavior.
- **Max feedback latency:** Measure during Wave 0; split focused commands if a task-level sample exceeds 60 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 101-W0-01 | TBD | 0 | OPEN-01 | T-101-01 / T-101-02 | Only the current authenticated registration revision remains usable through observation, rotation, logout, revocation, permission loss, and provider invalidation races. | Host contract/integration | Host fixture command to be finalized by the plan | ❌ W0 | ⬜ pending |
| 101-W0-02 | TBD | 0 | OPEN-02 | T-101-03 | Closed action policy normalization rejects malformed, empty, unknown, or absent routes/actions by default. | ExUnit contract | Focused schema, manifest, validator, and resolver commands to be finalized by the plan | Partial / ❌ W0 | ⬜ pending |
| 101-W0-03 | TBD | 0 | OPEN-03 | T-101-04 / T-101-05 | Opaque-only offline evidence has one consume winner and current authority is rechecked before manifest and RouteGate activation. | XCTest + ExUnit race/contract | Focused Swift and companion/host commands to be finalized by the plan | ❌ W0 | ⬜ pending |
| 101-W0-04 | TBD | 0 | OPEN-04 | T-101-04 / T-101-06 | Replay, expiry, revocation, mismatch, logout, tenant switch, and removed-route/action cases halt with sanitized denial evidence and no fallback activation. | Unit table + privacy regression | Focused resolver, denial, and RouteGate commands to be finalized by the plan | Partial / ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Host registry contract fixture with deterministic clock and concurrency tests for observation, supersession, exact-revision invalidation, and intent consume.
- [ ] CrossWake schema/builder/types/validator/resolver round-trip tests for the closed normalized action policy.
- [ ] Swift queue/delegate tests proving opaque-only storage, limits/cleanup, offline no-activation, and reconnect handoff.
- [ ] Cross-product denial matrix tests asserting no fallback activation and recursive output sanitization.

---

## Manual-Only Verifications

All phase behaviors are objectively machine-testable and require executable evidence. Human gates are reserved only for genuinely unavailable credentials, irreversible decisions, or subjective judgment.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or explicit Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags.
- [ ] Task-level feedback latency is measured and kept below 60 seconds where practical.
- [ ] `nyquist_compliant: true` set in frontmatter after validation.

**Approval:** pending

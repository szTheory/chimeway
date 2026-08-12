---
phase: 98
slug: privacy-safe-delivery-evidence
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-12
---

# Phase 98 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Ecto SQL/PostgreSQL integration |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `env MIX_ENV=test mix test test/chimeway/privacy_test.exs test/chimeway/privacy_boundary_test.exs test/chimeway/trigger_sanitization_test.exs test/chimeway/telemetry_integration_test.exs test/chimeway/traces_test.exs test/chimeway/admin_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | Measured during Wave 0 |

---

## Sampling Rate

- **After every task commit:** Run the focused ExUnit files touched by the task with `--warnings-as-errors`.
- **After every plan wave:** Run `mix ci`; additionally run `mix verify.install_golden && mix verify.runtime_prefix` after migration or installer work.
- **Before phase verification:** Full suite and all phase-specific `verify.*` commands must be green.
- **Max feedback latency:** Keep the per-task focused run below 60 seconds; split commands if measured latency exceeds this bound.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 98-01-01 | 01 | 1 | PRIV-03 | T-98-01 | Case-insensitive recursion removes forbidden keys through maps, lists, and keyword lists without allocating atoms from input. | unit | `env MIX_ENV=test mix test test/chimeway/privacy_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 98-01-02 | 01 | 1 | PRIV-03, PRIV-04 | T-98-02 | Shared closed evidence projections prevent sentinel leaks at every persistence and diagnostic boundary. | integration | `env MIX_ENV=test mix test test/chimeway/privacy_boundary_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 98-02-01 | 02 | 2 | PRIV-04 | T-98-03 | Trace, DTO, telemetry, captured log, and proof output contain only opaque references, classifications, and allowlisted facts. | integration | `env MIX_ENV=test mix test test/chimeway/privacy_boundary_test.exs test/chimeway/telemetry_integration_test.exs test/chimeway/traces_test.exs test/chimeway/admin_test.exs --warnings-as-errors` | ❌ W0 / existing focused suites | ⬜ pending |
| 98-02-02 | 02 | 2 | PRIV-04 | T-98-04 | Public and prefixed installs neutralize legacy unsafe evidence and reproduce the safe schema contract. | migration/integration | `mix verify.install_golden && mix verify.runtime_prefix` | Existing infrastructure; phase cases ❌ W0 | ⬜ pending |

*Task IDs are provisional until PLAN.md files are finalized. Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/chimeway/privacy_test.exs` — recursive case normalization, map/list/keyword handling, mixed shapes, and atom-safety regression coverage for PRIV-03.
- [ ] `test/chimeway/privacy_boundary_test.exs` — adversarial sentinel matrix proving no Chimeway-owned storage or diagnostic surface leaks values for PRIV-03/PRIV-04.
- [ ] Extend Trigger, Deliveries, Telemetry, Traces, Admin, release-gate, installer-golden, and runtime-prefix suites with phase-specific assertions.

---

## Manual-Only Verifications

All phase behaviors have automated verification. PRIV-03 and PRIV-04 are objectively machine-testable; do not create conversational UAT or human-check checkpoints for them.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags.
- [ ] Feedback latency stays below 60 seconds for focused checks.
- [ ] `nyquist_compliant: true` set in frontmatter after evidence is green.

**Approval:** pending

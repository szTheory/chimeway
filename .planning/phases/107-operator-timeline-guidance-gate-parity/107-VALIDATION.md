---
phase: "107"
slug: "operator-timeline-guidance-gate-parity"
status: validated
nyquist_compliant: true
wave_0_complete: true
created: "2026-09-12"
---

# Phase 107 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit 1.19.5; Phoenix.LiveViewTest in optional packages |
| **Config file** | `test/test_helper.exs`; `chimeway_admin/test/test_helper.exs`; `examples/chimeway_demo_host/test/test_helper.exs` |
| **Quick run command** | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/traces_test.exs test/chimeway/safe_evidence_test.exs --warnings-as-errors` |
| **Full suite command** | `mix verify.inbox` |
| **Estimated runtime** | ~180 seconds |

---

## Sampling Rate

- **After every task commit:** Run the task's focused ExUnit command.
- **After every plan wave:** Run `mix verify.inbox`.
- **Before phase sign-off:** `mix verify.inbox` and `mix ci.verify_gates` must be green; no conversational UAT is required for this docs/release-gate phase.
- **Max feedback latency:** 180 seconds for focused commands; aggregate gates may take longer.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 107-01-01 | 01 | 1 | INT-02 | T-107-01 | Empty allowlisted details; no recipient/caller metadata | integration | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/traces_test.exs test/chimeway/safe_evidence_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 107-01-02 | 01 | 1 | INT-02 | T-107-01 | Admin re-redaction and stable accessible hooks | component | `cd chimeway_admin && mix deps.get && mix test test/chimeway_admin/components/timeline_event_test.exs test/chimeway_admin/redaction_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 107-01-03 | 01 | 1 | INT-02, GATE-03 | T-107-02 | Authorized durable lifecycle; no inferred engagement | e2e LiveView | `cd examples/chimeway_demo_host && mix deps.get && mix test test/demo_host_web/inbox_bell_proof_test.exs --include inbox --warnings-as-errors` | ✅ | ✅ green |
| 107-02-01 | 02 | 2 | DOCS-03 | T-107-02 | Host/tenant/topic ownership and semantics are explicit | doc contract | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --only inbox_gate_parity --warnings-as-errors` | ✅ | ✅ green |
| 107-02-02 | 02 | 2 | GATE-03 | Cleanup cannot escape test-owned temporary roots | safety contract | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only release_cleanup_safety --warnings-as-errors` | ✅ | ✅ green |
| 107-02-03 | 02 | 2 | GATE-03 | Local alias and both CI aggregates require all evidence classes | integration aggregate | `mix verify.inbox && mix ci.verify_gates` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `chimeway_admin/test/chimeway_admin/components/timeline_event_test.exs` — focused labels/hooks/timestamp/redaction coverage.
- [x] Extend `test/chimeway/traces_test.exs` with cross-rank chronology, equal-time ordering, independence, sibling, and hostile-sentinel fixtures.
- [x] Extend `test/chimeway/safe_evidence_test.exs` with direct new-event admission and unknown-event rejection.
- [x] Add tagged inbox guide contracts in `test/chimeway/doc_contract_test.exs`.
- [x] Add tagged alias/aggregate/temp-cleanup mutation contracts in `test/chimeway/release_gate_contract_test.exs`.
- [x] Extend `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs` with mounted admin timeline assertions.

---

## Manual-Only Verifications

All phase behaviors have automated verification. Per project instructions, docs/release-gate acceptance is executable evidence rather than conversational UAT.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 180s for focused commands
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** complete — audited 2026-09-12

## Validation Audit 2026-09-12

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Current-run evidence reproduced every recorded Phase 107 verification seam:

| Requirement | Command | Result |
|-------------|---------|--------|
| INT-02 | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/traces_test.exs test/chimeway/safe_evidence_test.exs --warnings-as-errors` | 52 tests, 0 failures |
| INT-02 | `cd chimeway_admin && mix deps.get && mix test test/chimeway_admin/components/timeline_event_test.exs test/chimeway_admin/redaction_test.exs --warnings-as-errors` | 9 tests, 0 failures |
| INT-02, GATE-03 | `cd examples/chimeway_demo_host && mix deps.get && mix test test/demo_host_web/inbox_bell_proof_test.exs --include inbox --warnings-as-errors` | 5 tests, 0 failures |
| DOCS-03 | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --only inbox_gate_parity --warnings-as-errors` | 28 tests, 0 failures |
| GATE-03 | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only release_cleanup_safety --warnings-as-errors` | 3 tests, 0 failures |
| GATE-03 | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only inbox_gate_parity --warnings-as-errors` | 4 tests, 0 failures |
| GATE-03 | `mix verify.inbox` | 74 root, 24 inbox-package, 9 admin, 32 tagged contract, and 5 demo-host tests; 0 failures |
| GATE-03 | `mix ci.verify_gates` | 647 release-contract and 3 packaged-CLI tests, 0 failures; CrossWake provider-feedback docs verified |

No test files were added: the audit found complete behavioral coverage. Optional-package dependency preparation emitted the already-recorded expired Hex-session notice and advisories for locked dependencies, but resolution was unchanged and every required command exited successfully.

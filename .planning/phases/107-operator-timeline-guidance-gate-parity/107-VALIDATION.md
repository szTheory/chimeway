---
phase: "107"
slug: "operator-timeline-guidance-gate-parity"
status: draft
nyquist_compliant: false
wave_0_complete: false
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
- **Before `$gsd-verify-work`:** `mix verify.inbox` and `mix ci.verify_gates` must be green.
- **Max feedback latency:** 180 seconds for focused commands; aggregate gates may take longer.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 107-01-01 | 01 | 1 | INT-02 | T-107-01 | Empty allowlisted details; no recipient/caller metadata | integration | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/traces_test.exs test/chimeway/safe_evidence_test.exs --warnings-as-errors` | ✅ extend | ⬜ pending |
| 107-01-02 | 01 | 1 | INT-02 | T-107-01 | Admin re-redaction and stable accessible hooks | component | `cd chimeway_admin && mix deps.get && mix test test/chimeway_admin/components/timeline_event_test.exs test/chimeway_admin/redaction_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 107-01-03 | 01 | 1 | INT-02, GATE-03 | T-107-02 | Authorized durable lifecycle; no inferred engagement | e2e LiveView | `cd examples/chimeway_demo_host && mix deps.get && mix test --only inbox --warnings-as-errors` | ✅ extend | ⬜ pending |
| 107-02-01 | 02 | 2 | DOCS-03 | T-107-02 | Host/tenant/topic ownership and semantics are explicit | doc contract | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --only inbox_gate_parity --warnings-as-errors` | ✅ extend/tag | ⬜ pending |
| 107-02-02 | 02 | 2 | GATE-03 | Cleanup cannot escape test-owned temporary roots | safety contract | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only inbox_gate_parity --warnings-as-errors` | ✅ extend/tag | ⬜ pending |
| 107-02-03 | 02 | 2 | GATE-03 | Local alias and both CI aggregates require all evidence classes | integration aggregate | `mix verify.inbox && mix ci.verify_gates` | ✅ expand | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `chimeway_admin/test/chimeway_admin/components/timeline_event_test.exs` — focused labels/hooks/timestamp/redaction coverage.
- [ ] Extend `test/chimeway/traces_test.exs` with cross-rank chronology, equal-time ordering, independence, sibling, and hostile-sentinel fixtures.
- [ ] Extend `test/chimeway/safe_evidence_test.exs` with direct new-event admission and unknown-event rejection.
- [ ] Add tagged inbox guide contracts in `test/chimeway/doc_contract_test.exs`.
- [ ] Add tagged alias/aggregate/temp-cleanup mutation contracts in `test/chimeway/release_gate_contract_test.exs`.
- [ ] Extend `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs` with mounted admin timeline assertions.

---

## Manual-Only Verifications

All phase behaviors have automated verification. Per project instructions, docs/release-gate acceptance is executable evidence rather than conversational UAT.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s for focused commands
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

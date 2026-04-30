---
phase: 22
slug: recovery-outcome-analytics
status: ready
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-28
---

# Phase 22 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Ecto SQL Sandbox |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/chimeway/deliveries_test.exs test/chimeway/traces_test.exs -x` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~90 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/chimeway/deliveries_test.exs test/chimeway/traces_test.exs -x`
- **After every plan wave:** Run `mix test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 22-01-01 | 01 | 1 | OPS-01 | T-22-01 | Recoverable-row queries only select durable stuck states and exclude terminal or non-actionable rows. | unit | `mix test test/chimeway/deliveries_test.exs -x` | ✅ | ⬜ pending |
| 22-02-01 | 02 | 2 | OPS-01 | T-22-04 / T-22-06 | Event and delivery recovery reuse canonical identities, persisted render data, and duplicate recovery attempts no-op safely. | integration | `mix test test/chimeway/orchestration/recovery_test.exs test/chimeway/integration/delivery_lifecycle_test.exs -x` | ✅ | ⬜ pending |
| 22-03-01 | 03 | 3 | OPS-02 | T-22-07 / T-22-08 | Trace explanations surface recovery facts and outcome summaries stay payload-safe while grouping exact lifecycle buckets. | unit | `mix test test/chimeway/traces_test.exs -x` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Extend `test/chimeway/deliveries_test.exs` with recoverable event-gap and recoverable-row threshold coverage plus reconciliation no-op assertions.
- [ ] Add `test/chimeway/orchestration/recovery_test.exs` for event and delivery recovery flows.
- [ ] Extend `test/chimeway/traces_test.exs` with grouped outcome count assertions for `sent`, `suppressed`, `delayed`, `digested`, `failed`, and `exhausted`.
- [ ] Add or extend integration coverage proving event recovery plans from persisted `render_channels` and delivery recovery reuses the same delivery row and dispatch seam.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Operator interpretation of recovery results and aggregate summaries in IEx | OPS-01, OPS-02 | Public API ergonomics matter beyond raw counts and tuples | In `iex -S mix`, create stuck and recovered rows, call the new recovery API and aggregate trace functions, and verify results read as explicit operator-facing facts rather than opaque internals. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** ready for execution

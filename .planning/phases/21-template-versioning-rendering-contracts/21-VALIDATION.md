---
phase: 21
slug: template-versioning-rendering-contracts
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-28
---

# Phase 21 — Validation Strategy

> Per-phase validation contract for durable render identity, channel contracts, and preview parity.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with `Chimeway.DataCase` sandbox helpers and optional Oban testing for dispatch-path reuse |
| **Config file** | `test/test_helper.exs` and `test/support/data_case.ex` |
| **Quick run command** | `mix test test/chimeway/notifier_contract_test.exs test/chimeway/rendering/render_identity_integration_test.exs test/chimeway/rendering/channel_contract_test.exs test/chimeway/rendering/preview_pipeline_test.exs --trace` |
| **Full suite command** | `mix ci.test` |
| **Estimated runtime** | ~30 seconds for the quick rendering slice |

## Sampling Rate

- **After every task commit:** run the plan-scoped rendering test command for the files being changed.
- **After every plan wave:** run `mix ci.test`.
- **Before `$gsd-verify-work`:** full suite must be green.
- **Max feedback latency:** 30 seconds on the quick rendering slice.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 21-01-01 | 21-01 | 1 | TMPL-01 | T-21-03 | Delivery rows gain durable render fields and the render-identity regression test exists in the same slice that introduces those fields. | integration | `mix test test/chimeway/rendering/render_identity_integration_test.exs --trace` | ✅ W1 | ⬜ pending |
| 21-01-02 | 21-01 | 1 | TMPL-02 | T-21-01 | Notifier rendering declarations normalize through one validated seam with legacy `build/2` fallback. | unit | `mix test test/chimeway/notifier_contract_test.exs --trace` | ✅ W1 | ⬜ pending |
| 21-02-01 | 21-02 | 2 | TMPL-01, TMPL-02 | T-21-06 | Trigger persistence captures `render_assigns` once and planning stamps canonical delivery rows with stable render identity. | integration | `mix test test/chimeway/rendering/render_identity_integration_test.exs test/chimeway/orchestration/delivery_planning_test.exs --trace` | ✅ W1 | ⬜ pending |
| 21-03-01 | 21-03 | 2 | TMPL-02 | T-21-10 | `:in_app` and `:email` rendering outputs are validated explicitly and reject malformed payloads. | unit | `mix test test/chimeway/rendering/channel_contract_test.exs --trace` | ❌ W2 | ⬜ pending |
| 21-04-01 | 21-04 | 3 | TMPL-01, TMPL-02 | T-21-12 | Planning materializes validated `render_data` before dispatch and traces expose render identity without render bodies. | integration | `mix test test/chimeway/orchestration/delivery_planning_test.exs test/chimeway/integration/delivery_lifecycle_test.exs --trace` | ✅ W2 | ⬜ pending |
| 21-05-01 | 21-05 | 4 | TMPL-03 | T-21-14 | The library preview API reuses the production render pipeline and returns stable preview artifacts. | integration | `mix test test/chimeway/rendering/preview_pipeline_test.exs --trace` | ❌ W4 | ⬜ pending |
| 21-05-02 | 21-05 | 4 | TMPL-03 | T-21-15 | The Mix preview task delegates to the preview API and reports stable render identity plus validated payload fields. | integration | `mix test test/chimeway/rendering/preview_pipeline_test.exs --trace` | ❌ W4 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

## Wave 0 Requirements

None. The revised Phase 21 plan set creates each new test file in the same task that first uses it for automated verification, so no separate Wave 0 scaffold is required.

## Manual-Only Verifications

All required phase outcomes should be automatable.

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify steps or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] No task depends on a test file created only in a later task
- [ ] No watch-mode flags
- [ ] Feedback latency < 45s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

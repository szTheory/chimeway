---
phase: 20
slug: digest-emission-explainability
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-28
---

# Phase 20 — Validation Strategy

> Per-phase validation contract for digest flush execution and explainability.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Ecto SQL sandbox and Oban testing where async flush execution is covered |
| **Config file** | `config/test.exs` |
| **Quick run command** | `mix test test/chimeway/digests/emission_test.exs test/chimeway/integration/digest_delivery_lifecycle_test.exs test/chimeway/orchestration/digest_explainability_test.exs --trace` |
| **Full suite command** | `mix test` and `mix ci.test` |
| **Estimated runtime** | ~25 seconds for the quick slice, full suite longer |

## Sampling Rate

- **After every task commit:** run the plan-scoped test command for the files being changed.
- **After every plan wave:** run `mix ci.test`.
- **Before `$gsd-verify-work`:** full suite must be green.
- **Max feedback latency:** 25 seconds on the quick slice.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 20-01-01 | 20-01 | 1 | DIGEST-02 | T-20-01 | Bucket flush creates at most one emitted digest delivery and resolves memberships idempotently under duplicate execution. | integration | `mix test test/chimeway/digests/emission_test.exs --trace` | ❌ W1 | ⬜ pending |
| 20-01-02 | 20-01 | 1 | DIGEST-02 | T-20-02 | Source rows converge durably with explicit included, skipped, or immediate-send reasons on the canonical delivery row. | integration | `mix test test/chimeway/digests/emission_test.exs --trace` | ❌ W1 | ⬜ pending |
| 20-02-01 | 20-02 | 2 | DIGEST-02 | T-20-04 | Emitted digest rows hand off through the configured dispatcher seam without duplicate sends. | integration | `mix test test/chimeway/digests/emission_test.exs test/chimeway/integration/digest_delivery_lifecycle_test.exs --trace` | ❌ W2 | ⬜ pending |
| 20-03-01 | 20-03 | 3 | DIGEST-03 | T-20-07 | `Chimeway.Traces` explains included, excluded, deferred, skipped, and immediate-send digest outcomes without leaking payload/provider fields. | integration | `mix test test/chimeway/orchestration/digest_explainability_test.exs test/chimeway/traces_test.exs test/chimeway/integration/digest_delivery_lifecycle_test.exs --trace` | ❌ W3 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

## Wave 0 Requirements

- [ ] `test/chimeway/digests/emission_test.exs` — lock bucket claim, emitted digest identity reuse, membership resolution persistence, and explicit source-row included/skipped/immediate convergence.
- [ ] `test/chimeway/integration/digest_delivery_lifecycle_test.exs` — prove emitted digest deliveries reuse the configured dispatcher seam safely in both duplicate-execution and post-commit handoff paths.
- [ ] `test/chimeway/orchestration/digest_explainability_test.exs` — prove source and emitted digest explanations expose exact included, excluded, deferred, skipped, and immediate-send reasons with sanitized fields.
- [ ] Extend `test/chimeway/traces_test.exs` — preserve explanation contract stability while adding digest-specific fields/events.

## Manual-Only Verifications

All required phase outcomes should be automatable.

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify steps or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 45s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

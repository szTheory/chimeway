---
phase: 71
slug: redaction-and-explainability-contracts
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-04
updated: 2026-06-04
---

# Phase 71 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, Ecto SQL Sandbox, Phoenix LiveViewTest |
| **Config file** | Root `mix.exs`; admin package `chimeway_admin/mix.exs` |
| **Quick run command** | `mix test test/chimeway/admin_test.exs --warnings-as-errors && cd chimeway_admin && mix test test/chimeway_admin/live/privacy_leak_live_test.exs test/chimeway_admin/components/status_test.exs test/chimeway_admin/live/definitions_live_test.exs test/chimeway_admin/live/trace_search_live_test.exs test/chimeway_admin/live/recovery_live_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci.test && cd chimeway_admin && mix test --warnings-as-errors` |
| **Estimated runtime** | ~90-180 seconds targeted; full suite depends on local DB state |

## Sampling Rate

- **After every task commit:** Run the quick command above, or the narrower command listed in the task if it covers the changed files.
- **After every plan wave:** Run `mix test test/chimeway/admin_test.exs test/chimeway/traces_test.exs --warnings-as-errors` and `cd chimeway_admin && mix test --warnings-as-errors`.
- **Before `$gsd-verify-work`:** Full suite must be green.
- **Max feedback latency:** 180 seconds for targeted commands.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 71-01-01 | 01 | 1 | PRIV-02 | T-71-01 | Admin DTO maps expose exact stable fields and omit payload/render/provider/session/token/secret/auth-code/full-PII values. | ExUnit integration | `mix test test/chimeway/admin_test.exs --warnings-as-errors` | yes | covered |
| 71-01-02 | 01 | 1 | PRIV-01 | T-71-02 | Dashboard, trace detail, feed, recovery, and definitions rendered HTML omit seeded sensitive values while preserving masked/explainable operator facts. | LiveView render | `cd chimeway_admin && mix test test/chimeway_admin/live/privacy_leak_live_test.exs test/chimeway_admin/live/trace_search_live_test.exs test/chimeway_admin/live/recovery_live_test.exs --warnings-as-errors` | yes | covered |
| 71-02-01 | 02 | 2 | EXPL-01 | T-71-03 | Operator labels distinguish provider accepted, delivered, suppressed, retryable failure, and terminal failure without changing durable core status atoms. | Component/presenter + LiveView render | `cd chimeway_admin && mix test test/chimeway_admin/components/status_test.exs test/chimeway_admin/live/trace_search_live_test.exs --warnings-as-errors` | yes | covered |
| 71-02-02 | 02 | 2 | EXPL-02 | T-71-04 | Definitions rendered copy describes DB-inferred persisted history and forbids registry/skew/module-discovery/source-code claims. | LiveView render | `cd chimeway_admin && mix test test/chimeway_admin/live/definitions_live_test.exs test/chimeway_admin/live/trace_search_live_test.exs --warnings-as-errors` | yes | covered |

## Wave 0 Requirements

- [x] `test/chimeway/admin_test.exs` - exact allowlist helper coverage for command center, recent problem deliveries, definitions, feed, recovery candidates, and outcome totals.
- [x] `chimeway_admin/test/chimeway_admin/live/privacy_leak_live_test.exs` - rendered leak fixtures for dashboard, trace detail, feed, recovery, and definitions.
- [x] `chimeway_admin/test/chimeway_admin/components/status_test.exs` - status presenter contract for provider accepted, delivered, suppressed, retryable failure, and terminal failure.
- [x] `chimeway_admin/test/chimeway_admin/live/definitions_live_test.exs` - DB-inferred copy and forbidden overclaim assertions.

## Manual-Only Verifications

All phase behaviors have automated verification. Manual UAT remains useful for operator copy review after automated tests pass, but it is not the primary privacy/explainability gate.

## Threat References

| Ref | Threat | Required Mitigation |
|-----|--------|---------------------|
| T-71-01 | Admin DTO field creep leaks sensitive durable fields into optional UI packages. | Exact key allowlists and recursive forbidden key/value assertions in core admin tests. |
| T-71-02 | Rendered HTML leaks raw payload, render assigns/data, provider bodies, session/params, tokens, secrets, auth codes, or full recipient PII. | LiveView rendered leak tests with distinctive seeded sensitive values and positive masked/explainable assertions. |
| T-71-03 | Status copy overclaims delivery or hides retryable vs terminal failure distinctions. | Display presenter tests backed by existing durable status, attempt outcome, error class, webhook/workflow facts, and suppression reasons. |
| T-71-04 | Definitions UI claims code registry, module discovery, source-code skew detection, or source inventory that is not implemented. | Rendered copy tests requiring DB-inferred persisted history language and forbidding overclaim terms. |

## Validation Sign-Off

- [x] All tasks have automated verify commands or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency target is under 180 seconds for targeted runs.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** automated validation approved 2026-06-04

## Validation Audit 2026-06-04

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Phase 71 was audited after execution against the plan summaries, validation map, and current test files. The earlier `pending`, `partial`, and `missing` entries were stale: all four task requirements now have automated coverage in committed test files.

Verification evidence:

- `mix test test/chimeway/admin_test.exs --warnings-as-errors` - passed, 6 tests.
- `cd chimeway_admin && mix test test/chimeway_admin/components/status_test.exs test/chimeway_admin/live/definitions_live_test.exs test/chimeway_admin/live/privacy_leak_live_test.exs test/chimeway_admin/live/trace_search_live_test.exs test/chimeway_admin/live/recovery_live_test.exs --warnings-as-errors` - passed, 24 tests.
- `mix test test/chimeway/admin_test.exs test/chimeway/traces_test.exs --warnings-as-errors && cd chimeway_admin && mix test --warnings-as-errors` - passed, 52 root tests plus 51 admin tests.

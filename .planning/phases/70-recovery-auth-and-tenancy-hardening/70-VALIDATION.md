---
phase: 70
slug: recovery-auth-and-tenancy-hardening
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-04
---

# Phase 70 - Validation Strategy

Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix |
| **Config file** | `test/test_helper.exs`, `chimeway_admin/test/test_helper.exs` |
| **Quick run command** | `mix test test/chimeway/admin_test.exs test/chimeway/deliveries_test.exs test/chimeway/orchestration/recovery_test.exs --warnings-as-errors` |
| **Package run command** | `cd chimeway_admin && mix test --warnings-as-errors` |
| **Full suite command** | `mix ci` plus `mix verify.example` when admin package or demo-host mounted behavior changes |
| **Estimated runtime** | TBD by executor after first Wave 0 run |

## Sampling Rate

- **After every task commit:** Run the narrow ExUnit file touched by that task.
- **After every plan wave:** Run `mix test test/chimeway/admin_test.exs test/chimeway/deliveries_test.exs test/chimeway/orchestration/recovery_test.exs --warnings-as-errors` and `cd chimeway_admin && mix test --warnings-as-errors`.
- **Before `$gsd-verify-work`:** Run `mix ci`; also run `mix verify.example` if admin package or demo-host mounted behavior changed.
- **Max feedback latency:** Record after Wave 0; no watch-mode commands.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 70-W0-01 | TBD | 0 | SAFE-01 | T-70-01 | Recovery submit re-authorizes actor, action, tenant scope, resource id/type, and selected candidate facts at event time | LiveView/unit | `cd chimeway_admin && mix test test/chimeway_admin/live_auth_test.exs test/chimeway_admin/live/recovery_live_test.exs --warnings-as-errors` | Partial | pending |
| 70-W0-02 | TBD | 0 | SAFE-02 | T-70-02 | Stale or ineligible recovery candidates return explicit noop outcomes without duplicate dispatch | unit/integration | `mix test test/chimeway/orchestration/recovery_test.exs test/chimeway/deliveries_test.exs --warnings-as-errors` | yes | pending |
| 70-W0-03 | TBD | 0 | SAFE-03 | T-70-03 | Recovery requires deliberate confirmation and persists only safe operator evidence through core APIs | LiveView/core unit | `cd chimeway_admin && mix test test/chimeway_admin/live/recovery_live_test.exs --warnings-as-errors && mix test test/chimeway/deliveries_test.exs --warnings-as-errors` | Partial | pending |
| 70-W0-04 | TBD | 0 | SAFE-04 | T-70-04 | Dashboard, health, feed, definitions, and recovery reads use host-provided tenant scope | core + LiveView | `mix test test/chimeway/admin_test.exs --warnings-as-errors && cd chimeway_admin && mix test test/chimeway_admin/live/tenant_scope_test.exs --warnings-as-errors` | Partial | pending |

Status: pending until executor creates or updates the mapped tests and records green command output.

## Wave 0 Requirements

- [ ] `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs` - covers SAFE-01 and SAFE-03.
- [ ] `chimeway_admin/test/chimeway_admin/live/tenant_scope_test.exs` or equivalent per-page mounted LiveView tests - covers SAFE-04 page propagation.
- [ ] Core event recovery tenant guard test in `test/chimeway/orchestration/recovery_test.exs` or `test/chimeway/deliveries_test.exs` - covers event candidates with no delivery rows.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None planned | SAFE-01..SAFE-04 | All phase behaviors should be covered by ExUnit and LiveViewTest | N/A |

## Threat References

| Threat Ref | STRIDE | Behavior | Required Mitigation |
|------------|--------|----------|---------------------|
| T-70-01 | Elevation of privilege | Stale LiveView socket submits recovery after permission or tenant scope changes | Re-authorize in `handle_event` with actor, action, tenant scope, resource id/type, and selected candidate facts |
| T-70-02 | Tampering / Repudiation | Duplicate or stale recovery submit produces misleading additional work | Preserve core atomic recovery guards and surface `{:noop, ...}` as a normal result |
| T-70-03 | Information disclosure | Recovery metadata stores raw session, params, payloads, provider bodies, secrets, tokens, auth codes, or full PII | Allowlist only safe operator evidence: source, reason, recovered_at, actor reference, and confirmation marker |
| T-70-04 | Information disclosure | Admin reads omit tenant scope and expose cross-tenant rows | Extract host-provided admin context once and pass tenant-scoped opts to all admin reads and recovery candidate lookups |

## Validation Sign-Off

- [x] All phase requirements have an automated verification target.
- [x] Sampling continuity avoids 3 consecutive tasks without automated verify.
- [x] Wave 0 identifies missing or partial test files before implementation.
- [x] No watch-mode flags.
- [ ] Feedback latency recorded after first Wave 0 run.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending execution evidence

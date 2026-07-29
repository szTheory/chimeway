# Phase 70: Recovery, Auth, and Tenancy Hardening - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md - this log preserves the analysis.

**Date:** 2026-06-04T15:03:17Z
**Phase:** 70-recovery-auth-and-tenancy-hardening
**Mode:** assumptions
**Areas analyzed:** Authorization and Host Context, Tenant Scope Propagation, Recovery Core Boundary, Stale Candidate and Confirmation UX, Durable Operator Evidence

## Assumptions Presented

### Authorization and Host Context

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Keep `ChimewayAdmin.Auth.authorize/3` as the host-owned auth seam, but pass richer context through it: actor, action, params/session, tenant scope, resource id, recovery type, and selected candidate facts. Mutating LiveView events should re-authorize at submit time, not rely on mount authorization. | Likely | `chimeway_admin/lib/chimeway_admin/auth.ex`, `chimeway_admin/lib/chimeway_admin/live_auth.ex`, `chimeway_admin/lib/chimeway_admin/live/recovery_live.ex`, `chimeway_admin/test/chimeway_admin/live_auth_test.exs` |

### Tenant Scope Propagation

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Introduce a small admin context extraction path from LiveView session/query params into `tenant_id` read options, then use it consistently in dashboard, health, feed, definitions, and recovery reads. Keep tenancy host-provided; do not add Chimeway-owned tenant membership logic. | Likely | `lib/chimeway/admin.ex`, `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex`, `chimeway_admin/lib/chimeway_admin/live/health_live.ex`, `chimeway_admin/lib/chimeway_admin/live/feed_live.ex`, `chimeway_admin/lib/chimeway_admin/live/definitions_live.ex`, `chimeway_admin/lib/chimeway_admin/live/recovery_live.ex`, `examples/chimeway_demo_host/lib/demo_host_web/plugs/admin_actor.ex` |

### Recovery Core Boundary

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Reuse and harden the existing recovery spine instead of designing new recovery persistence: `Chimeway.recover_event/2`, `Chimeway.recover_delivery/2`, `Deliveries.begin_recovery/2`, and admin recovery candidates remain the core API path. Add tenant/resource guards and tests around these paths as needed. | Confident | `lib/chimeway.ex`, `lib/chimeway/deliveries.ex`, `test/chimeway/deliveries_test.exs`, `test/chimeway/orchestration/recovery_test.exs`, `test/chimeway/traces_test.exs` |

### Stale Candidate and Confirmation UX

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Treat stale/ineligible rows as normal `{:noop, ...}` outcomes surfaced clearly in the UI, not as errors. Keep the existing one-candidate confirmation form, but require explicit operator confirmation text or equivalent deliberate submit evidence, and preserve durable metadata on canonical rows. | Likely | `chimeway_admin/lib/chimeway_admin/live/recovery_live.ex`, `lib/chimeway/deliveries.ex`, `test/chimeway/deliveries_test.exs`, `test/chimeway/orchestration/recovery_test.exs` |

### Durable Operator Evidence

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Extend recovery metadata only with safe operator/action evidence that supports explainability, such as source, reason, recovered_at, actor reference, and confirmation marker; avoid raw session, params, payloads, provider bodies, or full PII. Leave broader DTO/rendered HTML redaction leak tests to Phase 71. | Likely | `lib/chimeway/deliveries.ex`, `lib/chimeway/traces.ex`, `test/chimeway/traces_test.exs`, `.planning/REQUIREMENTS.md`, `.planning/phases/69-console-design-system/69-CONTEXT.md` |

## Corrections Made

No corrections - all assumptions confirmed.

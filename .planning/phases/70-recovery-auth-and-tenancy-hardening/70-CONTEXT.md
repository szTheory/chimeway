# Phase 70: Recovery, Auth, and Tenancy Hardening - Context

**Gathered:** 2026-06-04 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 70 makes action-bearing admin flows safe under host auth, tenant scope, stale candidates, and durable recovery evidence. It covers SAFE-01, SAFE-02, SAFE-03, and SAFE-04: mutating LiveView events re-authorize with actor/action/resource context, recovery handles stale or ineligible candidates without duplicate work, confirmation and core API calls leave durable operator evidence, and admin reads/recovery candidates honor host-provided tenant context. It should not pull in Phase 71 rendered-HTML/DTO redaction leak testing or explanation-copy hardening, and it should not pull in Phase 72 admin docs, `mix verify.admin`, CI parity, or browser-smoke gate composition except where those later phases constrain the safety contract.
</domain>

<decisions>
## Implementation Decisions

### Authorization and Host Context

- **D-01:** Keep `ChimewayAdmin.Auth.authorize/3` as the host-owned authorization seam.
- **D-02:** Pass richer authorization context through the existing seam: actor, action, params/session, tenant scope, resource id, recovery type, and selected candidate facts where available.
- **D-03:** Re-authorize mutating LiveView events at submit time; do not rely only on mount-time `on_mount` authorization for recovery actions.

### Tenant Scope Propagation

- **D-04:** Introduce a small admin-context extraction path from LiveView session/query params into `tenant_id` read options.
- **D-05:** Apply tenant-scoped read options consistently across dashboard, health, feed, definitions, and recovery reads.
- **D-06:** Keep tenancy host-provided; do not add Chimeway-owned tenant membership, role, or policy logic.

### Recovery Core Boundary

- **D-07:** Reuse and harden the existing recovery spine instead of creating an admin-only recovery mechanism.
- **D-08:** Keep `Chimeway.recover_event/2`, `Chimeway.recover_delivery/2`, `Deliveries.begin_recovery/2`, and admin recovery candidates as the core API path.
- **D-09:** Add tenant/resource guards and tests around those existing paths where needed rather than duplicating stale/noop behavior in the UI layer.

### Stale Candidate and Confirmation UX

- **D-10:** Treat stale or ineligible recovery rows as normal `{:noop, ...}` outcomes surfaced clearly in the UI, not as exceptional failures.
- **D-11:** Keep the one-candidate recovery review flow, but require explicit operator confirmation text or an equivalent deliberate submit marker before recovery.
- **D-12:** Preserve durable recovery metadata on canonical rows so duplicate or stale recovery attempts remain explainable.

### Durable Operator Evidence

- **D-13:** Extend recovery evidence only with safe operator/action facts needed for explainability, such as source, reason, recovered_at, actor reference, and confirmation marker.
- **D-14:** Do not persist raw session, params, payloads, provider bodies, secrets, tokens, auth codes, or full PII in recovery metadata.
- **D-15:** Leave broader DTO and rendered-HTML privacy leak contracts to Phase 71.

### the agent's Discretion

Downstream agents may choose the narrowest implementation shape that satisfies the decisions above, keeps `chimeway_admin` optional and host-mounted, and matches existing LiveAuth/Admin DTO/recovery-core patterns.

### Folded Todos

None.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/STATE.md`
- `.planning/METHODOLOGY.md`
- `.planning/phases/68-admin-truth-alignment/68-CONTEXT.md`
- `.planning/phases/69-console-design-system/69-CONTEXT.md`
- `chimeway_admin/lib/chimeway_admin/auth.ex`
- `chimeway_admin/lib/chimeway_admin/live_auth.ex`
- `chimeway_admin/lib/chimeway_admin/router.ex`
- `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/health_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/feed_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/definitions_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/recovery_live.ex`
- `examples/chimeway_demo_host/lib/demo_host/admin_auth.ex`
- `examples/chimeway_demo_host/lib/demo_host_web/plugs/admin_actor.ex`
- `examples/chimeway_demo_host/lib/demo_host_web/router.ex`
- `lib/chimeway.ex`
- `lib/chimeway/admin.ex`
- `lib/chimeway/deliveries.ex`
- `test/chimeway/admin_test.exs`
- `test/chimeway/deliveries_test.exs`
- `test/chimeway/orchestration/recovery_test.exs`
- `test/chimeway/traces_test.exs`
- `chimeway_admin/test/chimeway_admin/live_auth_test.exs`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `ChimewayAdmin.Auth` already defines the host authorization callback with admin actions including `:list_recovery_candidates`, `:recover_delivery`, and `:recover_event`.
- `ChimewayAdmin.LiveAuth` already performs fail-closed mount authorization and exposes `ensure_authorized/3` for event-time rechecks.
- `Chimeway.Admin` already returns redaction-ready DTO maps and accepts `tenant_id` options for problem deliveries, definitions, feed rows, recovery candidates, and outcome totals.
- `ChimewayAdmin.Live.RecoveryLive` already has a one-candidate choose/recover flow, event-time authorization for recovery submit, and user-facing noop handling.
- `Chimeway.recover_event/2` and `Chimeway.recover_delivery/2` delegate to `Chimeway.Deliveries`, preserving a public recovery API surface.
- `Chimeway.Deliveries.begin_recovery/2`, `recover_event/2`, and `recover_delivery/2` already stamp durable recovery metadata and return explicit noop outcomes for stale/duplicate candidates.

### Established Patterns

- `chimeway_admin` remains an optional, host-mounted Phoenix LiveView package; core stays Phoenix-free and owns durable read/recovery APIs.
- Host apps provide actor/session context before mounting admin LiveViews; the demo host currently sets `"current_actor"` through `DemoHostWeb.Plugs.AdminActor`.
- Admin surfaces consume DTO maps rather than raw Ecto schemas so sensitive payload/render/provider fields are not accidentally exposed.
- Recovery explainability lives on canonical rows and trace projection; operators should be able to tell whether recovery was dispatched, skipped/noop, or failed without inspecting transient LiveView state.
- Tenant-scoped behavior is already present in core read models, but current admin LiveViews call `Chimeway.admin_*` without tenant options.

### Integration Points

- `ChimewayAdmin.Router.chimeway_admin_routes/1` wires recovery mount authorization separately from mutating recovery actions.
- Dashboard and health both surface recovery candidate counts and should use the same tenant context as the dedicated recovery page.
- Feed and definitions reads should share the same tenant-context extraction path so operator navigation does not change scope unexpectedly.
- Demo host auth should remain permissive in dev/test and fail closed in production; Phase 70 can add tenant/session examples without turning the demo into a real auth provider.
</code_context>

<specifics>
## Specific Ideas

- Add an admin context helper that extracts `tenant_id` from a host-provided session key and, where acceptable for operator debugging, query params.
- Have LiveAuth include the extracted tenant scope in authorize context so host implementations can enforce tenant/resource permissions consistently.
- Pass tenant context into `Chimeway.admin_command_center/1`, `admin_outcome_totals/1`, `admin_recent_problem_deliveries/1`, `admin_feed/1`, `admin_definitions/1`, and `admin_recovery_candidates/1`.
- Include selected recovery candidate facts in the submit-time authorization context, then call the existing `Chimeway.recover_*` APIs with source/reason/actor/confirmation evidence.
- Add tests for cross-tenant dashboard/health/recovery/feed/definitions reads, recovery submit re-authorization, stale recovery noop messaging, and safe recovery metadata.
</specifics>

<deferred>
## Deferred Ideas

None - analysis stayed within phase scope.

### Reviewed Todos (not folded)

None.
</deferred>

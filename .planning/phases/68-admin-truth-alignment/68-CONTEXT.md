# Phase 68: Admin Truth Alignment - Context

**Gathered:** 2026-06-04 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 68 reconciles planning, docs, route map, and admin information architecture around the real multi-page `chimeway_admin` operator console. It covers ADMIN-01, ADMIN-02, and ADMIN-03: command-center landing clarity, consistent navigation/page hierarchy, and truthful operator-facing docs/demo copy. It should not pull in visual design-system hardening, recovery safety contracts, redaction boundary hardening, `mix verify.admin`, or browser smoke infrastructure; those are Phase 69, Phase 70, Phase 71, and Phase 72 scope.
</domain>

<decisions>
## Implementation Decisions

### Route Map and IA

- **D-01:** Treat the current seven-page admin route map as real shipped scope for Phase 68: `/`, `/traces`, `/deliveries/:delivery_id`, `/feed`, `/definitions`, `/health`, and `/recovery`.
- **D-02:** Align planning/docs/navigation language around the existing operator page hierarchy instead of removing or hiding already-built pages.

### Landing Page Job

- **D-03:** Keep `/admin/chimeway` as the Command Center.
- **D-04:** Make Trace Lookup the primary command-center action because support debugging remains the core operator job; Health, Recovery, Definitions, and Feed Debug are secondary paths that support that investigation flow.

### Docs and Demo Drift

- **D-05:** Prioritize fixing demo/admin copy that still describes shipped pages as out of scope, especially the demo host README language that says health aggregates, notification definitions registry, and related admin pages are not included.
- **D-06:** Keep claim language honest: Definitions is a DB-inferred durable-key/version usage view, not code-registry skew detection; Feed Debug is operator lifecycle inspection, not the end-user inbox product surface.

### Verification Shape

- **D-07:** Use lightweight route, navigation, mounted-page, and doc-contract tests for Phase 68 truth alignment.
- **D-08:** Do not add browser smoke infrastructure or design-system/accessibility audits in Phase 68 planning; reserve those for later milestone phases already mapped to DES-*, GATE-08, and SMOKE-01.

### the agent's Discretion

No discretionary open items remain after user confirmation. Downstream agents may choose the narrowest implementation shape that satisfies the decisions above and matches existing `chimeway_admin` patterns.

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
- `chimeway_admin/lib/chimeway_admin/router.ex`
- `chimeway_admin/lib/chimeway_admin/routes.ex`
- `chimeway_admin/lib/chimeway_admin/components/layout.ex`
- `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/feed_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/definitions_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/health_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/recovery_live.ex`
- `lib/chimeway/admin.ex`
- `chimeway_admin/test/chimeway_admin/routes_test.exs`
- `chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs`
- `examples/chimeway_demo_host/README.md`
- `examples/chimeway_demo_host/lib/demo_host_web/router.ex`
- `examples/chimeway_demo_host/config/config.exs`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `ChimewayAdmin.Router.chimeway_admin_routes/1` already mounts all seven pages under host scope-compatible LiveView sessions.
- `ChimewayAdmin.Routes` centralizes mount-prefix-aware paths for command center, traces, delivery detail, feed, definitions, health, and recovery.
- `ChimewayAdmin.Components.Layout.admin_shell/1` already provides a shared sidebar nav with current labels.
- `ChimewayAdmin.Live.DashboardLive` already frames the landing page as a Command Center with Trace Lookup as the headline job.
- `Chimeway.Admin` already exposes DTO-style read models for command center, recent problems, definitions, feed, recovery candidates, and outcome totals.

### Established Patterns

- Optional Phoenix UI packages are host-mounted and use host-provided auth/session seams.
- Operator surfaces should consume small redaction-ready DTO maps, not raw Ecto schemas or sensitive payload/render/provider fields.
- Route helpers must respect `config :chimeway_admin, path_prefix: "/admin/chimeway"`.
- Tests already use package-level LiveView isolated mounts plus demo-host mounted route tests; Phase 68 should extend that pattern instead of introducing a new browser stack.

### Integration Points

- Demo host mounts `chimeway_admin` at `/admin/chimeway` and configures `path_prefix` to match.
- Existing demo and integration docs repeatedly point users to `/admin/chimeway` for operator trace inspection.
- The main drift target is docs/demo copy that still describes `chimeway_admin` as trace lookup only and marks now-existing pages as out of scope.
</code_context>

<specifics>
## Specific Ideas

- Update `examples/chimeway_demo_host/README.md` so the browser section names Command Center, Trace Lookup, Trace Detail, Feed Debug, Definitions, Health, and Recovery accurately.
- Replace the stale "Out of scope for `chimeway_admin` MVP" copy with a current boundary statement: not generic CRUD, not template editing/provider config, not end-user inbox, not cohort analytics, and not arbitrary bulk recovery.
- Add doc-contract coverage that prevents the stale out-of-scope claims from returning.
- Add or adjust route/nav assertions so the route map and labels remain aligned with the real mounted console.
</specifics>

<deferred>
## Deferred Ideas

None - analysis stayed within phase scope.

### Reviewed Todos (not folded)

None.
</deferred>

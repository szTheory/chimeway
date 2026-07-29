# Phase 69: Console Design System - Context

**Gathered:** 2026-06-04 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 69 raises the `chimeway_admin` UI baseline with scoped Chimeway tokens, accessible light/dark/system themes, responsive layouts, and restrained reduced-motion-safe interaction polish. It covers DES-01, DES-02, DES-03, and DES-04. It should not pull in Phase 70 recovery/auth/tenancy hardening, Phase 71 redaction/explainability contracts, or Phase 72 admin docs, `mix verify.admin`, CI parity, and browser-smoke gate work except where those later phases constrain design-system choices.
</domain>

<decisions>
## Implementation Decisions

### Token and Asset Strategy

- **D-01:** Harden the existing scoped `chimeway_admin` CSS system in `priv/static/chimeway_admin.css`; keep admin styles under `.chimeway-admin` and `--cw-*` tokens.
- **D-02:** Preserve the packaged stylesheet delivery path instead of adding a new CSS framework, global stylesheet, or build dependency.

### Theme and State Coverage

- **D-03:** Expand the current token set into explicit admin tokens for color, typography, spacing, status, radius, shadow, focus, surfaces, z-index, and motion.
- **D-04:** Retain `data-cw-theme="light|dark|system"` as the theme selector and make hover, focus, active, and status states coherent in all three modes.
- **D-05:** Use WCAG 2.2 AA contrast expectations as the planning baseline: 4.5:1 for normal text and 3:1 for applicable large text, non-text UI, and focus/state indicators.

### Responsive Core Flows

- **D-06:** Audit and adjust shared layout primitives used by all seven Phase 68 pages instead of designing page-specific responsive fixes first.
- **D-07:** Prioritize rows, search forms, tables, summary lists, copyable IDs, metric grids, page headers, and shared navigation because those surfaces carry the highest overlap and layout-shift risk.

### Motion and Browser Feature Posture

- **D-08:** Keep motion purposeful, brief, interruptible, and reduced-motion-safe using `prefers-reduced-motion`.
- **D-09:** Existing and likely CSS features such as cascade layers, `prefers-color-scheme`, `prefers-reduced-motion`, and `color-mix()` are acceptable for this admin package baseline; planners should still choose conservative fallbacks where a token can avoid unnecessary feature risk.

### Verification Boundary

- **D-10:** Produce design-system evidence compatible with later browser smoke work, including mobile/desktop visual evidence or screenshot-ready checks, but do not make the Phase 72 `mix verify.admin` or browser smoke gate the primary Phase 69 deliverable.
- **D-11:** Keep Phase 69 tests focused on design-system contracts and rendered LiveView structure where practical; defer full admin verification-gate composition to Phase 72.

### the agent's Discretion

Downstream agents may choose the narrowest implementation shape that satisfies the decisions above, keeps the package host-embeddable, and matches existing `chimeway_admin` component patterns.

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
- `chimeway_admin/lib/chimeway_admin.ex`
- `chimeway_admin/lib/chimeway_admin/assets.ex`
- `chimeway_admin/lib/chimeway_admin/router.ex`
- `chimeway_admin/lib/chimeway_admin/routes.ex`
- `chimeway_admin/lib/chimeway_admin/components/layout.ex`
- `chimeway_admin/lib/chimeway_admin/components/core.ex`
- `chimeway_admin/lib/chimeway_admin/components/status.ex`
- `chimeway_admin/lib/chimeway_admin/components/timeline_event.ex`
- `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/feed_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/definitions_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/health_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/recovery_live.ex`
- `chimeway_admin/assets/css/chimeway_admin.css`
- `chimeway_admin/priv/static/chimeway_admin.css`
- `chimeway_admin/test/chimeway_admin/routes_test.exs`
- `chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs`
- `examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex`
- `examples/chimeway_demo_host/lib/demo_host_web/layouts/root.html.heex`
- `https://www.w3.org/TR/WCAG22/`
- `https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum`
- `https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/%40layer`
- `https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@media/prefers-color-scheme`
- `https://developer.mozilla.org/en-US/docs/Web/CSS/%40media/prefers-reduced-motion`
- `https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/color_value/color-mix`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `ChimewayAdmin.Components.Layout.admin_shell/1` scopes pages under `<main class="chimeway-admin" data-cw-theme={@theme}>`.
- `chimeway_admin/priv/static/chimeway_admin.css` already uses scoped variables, cascade layers, theme overrides, breakpoints, status classes, and shared layout rules.
- `chimeway_admin/assets/css/chimeway_admin.css` imports the shipped static stylesheet, and `ChimewayAdmin.Assets.css_path/0` exposes the packaged asset path.
- `ChimewayAdmin.Components.Core` provides shared card, button, input, select, empty-state, and copyable-ID primitives.
- `ChimewayAdmin.Components.Status` centralizes status badge semantics and should remain the status styling anchor.

### Established Patterns

- `chimeway_admin` is optional and host-mounted; it should stay easy for Phoenix hosts to embed without adopting a new frontend toolchain.
- Admin UI styles should remain package-scoped to avoid leaking into host apps or being broken by host styles.
- Phase 68 locked the seven-page console shape: Command Center, Trace Lookup, Trace Detail, Feed Debug, Definitions, Health, and Recovery.
- Existing admin tests are primarily route, LiveView, and server-render assertions; Phase 69 can extend that style for design-system contracts without owning the later browser-smoke gate.

### Integration Points

- Demo host serves and links the packaged admin stylesheet through its endpoint and root layout.
- All core admin pages compose the shared shell/components, so token and responsive fixes should flow through shared CSS and component primitives.
- Later recovery, redaction, docs, and smoke phases will build on this visual baseline; Phase 69 should leave those later boundaries clean.
</code_context>

<specifics>
## Specific Ideas

- Add named spacing, font-size, line-height, z-index, and motion tokens rather than continuing to copy raw CSS values across admin selectors.
- Add or refine design-system contract tests that assert theme hooks, CSS token presence, reduced-motion rules, and core component class contracts where practical.
- Capture screenshot-ready mobile and desktop evidence during implementation, but keep reusable browser-smoke infrastructure for Phase 72 unless the smallest practical design check requires it.
</specifics>

<deferred>
## Deferred Ideas

None - analysis stayed within phase scope.

### Reviewed Todos (not folded)

None.
</deferred>

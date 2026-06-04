# Phase 69: Console Design System - Research

**Researched:** 2026-06-04
**Domain:** Embedded Phoenix LiveView admin UI design system
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
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

### Deferred Ideas (OUT OF SCOPE)
## Deferred Ideas

None - analysis stayed within phase scope.

### Reviewed Todos (not folded)

None.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DES-01 | Admin UI uses scoped Chimeway design tokens for color, spacing, typography, status, radius, shadow, focus, z-index, and motion. | Use the existing `.chimeway-admin` scoped stylesheet and expand `--cw-*` tokens in `@layer cw.tokens`. [VERIFIED: codebase grep] |
| DES-02 | Admin UI supports light, dark, and system theme behavior with accessible contrast and no broken hover, focus, or active states. | Keep `data-cw-theme="light|dark|system"` and validate WCAG 2.2 AA contrast/state pairs. [VERIFIED: codebase grep] [CITED: https://www.w3.org/TR/WCAG22/] |
| DES-03 | Admin UI remains usable on mobile and desktop, with no overlapping text or unstable layout shifts in core operator flows. | Target shared primitives used by the seven admin pages: shell, nav, search forms, rows, tables, summary lists, copyable IDs, metric grids, and page headers. [VERIFIED: codebase grep] |
| DES-04 | Admin UI uses purposeful, reduced-motion-safe microinteractions for state changes without slowing keyboard-heavy workflows. | Use CSS transition tokens and `prefers-reduced-motion`; avoid LiveView JS blocking transitions unless a later interaction needs them. [VERIFIED: codebase grep] [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion] |
</phase_requirements>

## Summary

Phase 69 should be implemented as a scoped CSS and component-contract hardening phase, not as a frontend-stack change. The existing `chimeway_admin` shell renders `<main class="chimeway-admin" data-cw-theme={@theme}>`, the shipped asset path is `ChimewayAdmin.Assets.css_path/0`, and the stylesheet already uses cascade layers, scoped variables, theme overrides, breakpoints, status classes, and reduced-motion handling. [VERIFIED: codebase grep]

The planner should concentrate work in `chimeway_admin/priv/static/chimeway_admin.css` plus small component/test adjustments where needed. The main implementation risk is not missing a library; it is allowing raw values, mixed hover colors, long IDs, table min-widths, or motion defaults to escape the design-system contract. [VERIFIED: codebase grep] [ASSUMED]

**Primary recommendation:** Expand the existing scoped `--cw-*` token system, make state tokens explicit for light/dark/system themes, add CSS/LiveView contract tests, and capture mobile/desktop evidence without introducing a new framework or permanent browser-smoke gate. [VERIFIED: .planning/phases/69-console-design-system/69-CONTEXT.md]

## Project Constraints (from AGENTS.md)

- Chimeway is an open-source embedded notification layer for Elixir and Phoenix apps; host applications own data, policies, and delivery history. [VERIFIED: AGENTS.md]
- Notification decisions must remain explainable: operators should be able to understand why work was sent, failed, or suppressed. [VERIFIED: AGENTS.md]
- The project baseline is Elixir 1.17+, OTP 26+, Ecto 3.x, PostgreSQL 15+, optional Phoenix 1.7/1.8, optional Oban 2.x, and Swoosh 1.x as an email adapter seam. [VERIFIED: AGENTS.md]
- Keep stable notification identity via `notification_key` plus version; do not make module names durable identity. [VERIFIED: AGENTS.md]
- Preserve the durable lifecycle spine: event -> notification -> delivery -> attempt. [VERIFIED: AGENTS.md]
- Treat idempotency and suppression reasons as first-class product behavior. [VERIFIED: AGENTS.md]
- Keep adapters replaceable with explicit behaviours and contract tests. [VERIFIED: AGENTS.md]
- Preserve host ownership boundaries for auth, tenancy, URL generation, and correlation IDs. [VERIFIED: AGENTS.md]
- Maintain `mix verify.*` and `mix ci.*` entrypoints with CI/local parity. [VERIFIED: AGENTS.md]
- Avoid leaking sensitive payload fields in telemetry and operator surfaces. [VERIFIED: AGENTS.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Scoped design tokens | Browser / Client | Frontend Server (SSR) | CSS variables resolve in the browser, while Phoenix components provide the scoped root and class hooks. [VERIFIED: codebase grep] |
| Theme selection | Browser / Client | Frontend Server (SSR) | `data-cw-theme` is rendered by `admin_shell/1`; actual light/dark/system CSS resolution happens in the browser. [VERIFIED: codebase grep] |
| Responsive layout | Browser / Client | Frontend Server (SSR) | Media queries, grids, overflow, wrapping, and min-width behavior are CSS responsibilities. [VERIFIED: codebase grep] |
| Core flow markup contracts | Frontend Server (SSR) | Browser / Client | LiveViews and function components emit the semantic hooks that CSS and tests depend on. [VERIFIED: codebase grep] |
| Motion and reduced motion | Browser / Client | Frontend Server (SSR) | Current motion is CSS transition based and already uses `prefers-reduced-motion`. [VERIFIED: codebase grep] |
| Design-system verification | API / Backend test runner | Browser / Client | ExUnit, LiveViewTest, and Floki can assert CSS text and rendered HTML contracts without requiring a permanent browser gate in this phase. [VERIFIED: mix deps] [CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.LiveViewTest.html] |

## Standard Stack

### Core

| Library / Surface | Version | Purpose | Why Standard |
|-------------------|---------|---------|--------------|
| `chimeway_admin/priv/static/chimeway_admin.css` | repo asset | Packaged admin stylesheet | Locked phase decision preserves static asset delivery and avoids a host build dependency. [VERIFIED: codebase grep] |
| Phoenix function components | Phoenix LiveView locked at 1.1.30 | Shared HEEx component hooks for shell, buttons, inputs, cards, status, and metrics | `Phoenix.Component` supports declared attributes, slots, and global `aria-`/`data-`/`phx-` attributes for reusable components. [VERIFIED: mix deps] [CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html] |
| CSS cascade layers | browser CSS feature | Keep tokens, base, layout, components, and utilities ordered | MDN documents `@layer` as a cascade-layer mechanism with broad availability since March 2022. [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/@layer] |
| CSS custom properties under `--cw-*` | browser CSS feature | Theme, spacing, state, focus, surface, z-index, and motion tokens | The current stylesheet already resolves admin colors through scoped variables under `.chimeway-admin`. [VERIFIED: codebase grep] |
| WCAG 2.2 AA criteria | W3C Recommendation 2024-12-12 | Contrast, non-text contrast, reflow, focus visibility, and motion baseline | W3C recommends WCAG 2.2 and defines testable success criteria for web content. [CITED: https://www.w3.org/TR/WCAG22/] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| Phoenix.LiveViewTest | locked package version 1.1.30; docs viewed at 1.1.31 | Render LiveViews and assert stable markup contracts | Use for shell/theme attributes and shared component class contracts. [VERIFIED: mix deps] [CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.LiveViewTest.html] |
| Floki | locked 0.38.3 | Parse rendered HTML and query CSS selectors | Use when string assertions are too weak for component structure. [VERIFIED: Hex registry] [CITED: https://floki.hexdocs.pm/Floki.html] |
| Chromium | `/opt/homebrew/bin/chromium` | Optional local screenshot/manual evidence | Use only for Phase 69 visual evidence if implementation wants screenshots; do not make it a durable gate yet. [VERIFIED: command -v] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Static scoped CSS | Tailwind, CSS framework, or asset build step | Contradicts the locked no-new-framework/no-build-dependency decision. [VERIFIED: 69-CONTEXT.md] |
| ExUnit CSS/markup contracts | Permanent Playwright browser smoke | Phase 72 owns the durable browser smoke and `mix verify.admin` gate. [VERIFIED: 69-CONTEXT.md] |
| Explicit semantic state tokens | Repeated `color-mix()` literals at call sites | Repeated literals make contrast/state auditing harder across themes. [ASSUMED] |

**Installation:**

```bash
# No new package installation for Phase 69. [VERIFIED: 69-CONTEXT.md]
```

**Version verification:**

```bash
cd chimeway_admin
mix deps | rg "phoenix_live_view|floki"
mix hex.info phoenix_live_view
mix hex.info floki
```

## Package Legitimacy Audit

Phase 69 should not install external packages. Existing relevant dependencies are already locked in `chimeway_admin/mix.lock`; no slopcheck gate is required for a no-install plan. [VERIFIED: 69-CONTEXT.md] [VERIFIED: mix deps]

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| `phoenix_live_view` | Hex | existing locked dep | 221,300 last 7 days from `mix hex.info` | `github.com/phoenixframework/phoenix_live_view` | not run; no install | Use existing locked dependency. [VERIFIED: Hex registry] |
| `floki` | Hex | existing locked test dep | 103,067 last 7 days from `mix hex.info` | `github.com/philss/floki` | not run; no install | Use existing locked test dependency. [VERIFIED: Hex registry] |

**Packages removed due to slopcheck [SLOP] verdict:** none. [VERIFIED: no new installs]
**Packages flagged as suspicious [SUS]:** none. [VERIFIED: no new installs]

## Architecture Patterns

### System Architecture Diagram

```text
Host Phoenix app
  -> mounted chimeway_admin route
  -> LiveView admin page renders admin_shell/1
  -> <main class="chimeway-admin" data-cw-theme="light|dark|system">
  -> packaged /chimeway_admin/chimeway_admin.css
  -> @layer cw.tokens sets semantic --cw-* variables
  -> @layer cw.layout and cw.components consume tokens
  -> browser resolves theme, contrast states, responsive layout, and reduced motion
  -> operator sees stable seven-page console flows
```

This data flow matches the current host-mounted package and stylesheet path. [VERIFIED: codebase grep]

### Recommended Project Structure

```text
chimeway_admin/
├── priv/static/chimeway_admin.css        # source of truth for shipped admin CSS [VERIFIED: codebase grep]
├── assets/css/chimeway_admin.css         # import mirror for source-copy workflows [VERIFIED: codebase grep]
├── lib/chimeway_admin/components/        # shared shell/core/status component hooks [VERIFIED: codebase grep]
├── lib/chimeway_admin/live/              # seven admin pages using shared primitives [VERIFIED: codebase grep]
└── test/chimeway_admin/                  # ExUnit, LiveViewTest, Floki contract tests [VERIFIED: rg --files]
```

### Pattern 1: Token-First CSS Layers

**What:** Define named semantic tokens in `@layer cw.tokens`, then consume only semantic tokens from layout/components. [VERIFIED: codebase grep]

**When to use:** Use for every color, surface, spacing, radius, shadow, focus, z-index, and motion value that must remain coherent across themes. [VERIFIED: 69-CONTEXT.md]

**Example:**

```css
/* Source: existing chimeway_admin/priv/static/chimeway_admin.css + MDN @layer docs */
@layer cw.tokens {
  :where(.chimeway-admin) {
    --cw-space-3: 0.75rem;
    --cw-focus-ring: var(--cw-admin-focus);
    --cw-motion-fast: 120ms ease-out;
  }
}

@layer cw.components {
  .cw-button {
    min-height: var(--cw-control-height);
    transition: background var(--cw-motion-fast), border-color var(--cw-motion-fast);
  }
}
```

### Pattern 2: Attribute-Scoped Themes

**What:** Keep theme selection on `.chimeway-admin[data-cw-theme="..."]` and use `prefers-color-scheme` only for the `system` branch. [VERIFIED: codebase grep] [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-color-scheme]

**When to use:** Use for light, dark, and system token overrides without leaking styles into host apps. [VERIFIED: 69-CONTEXT.md]

**Example:**

```css
/* Source: existing chimeway_admin/priv/static/chimeway_admin.css + MDN prefers-color-scheme docs */
:where(.chimeway-admin[data-cw-theme="dark"]) {
  --cw-admin-bg: var(--cw-night);
  color-scheme: dark;
}

@media (prefers-color-scheme: dark) {
  :where(.chimeway-admin[data-cw-theme="system"]) {
    --cw-admin-bg: var(--cw-night);
    color-scheme: dark;
  }
}
```

### Pattern 3: Contract Tests for CSS and Rendered Hooks

**What:** Add tests that assert token names, theme branches, reduced-motion rules, and rendered component hooks. [VERIFIED: existing test style]

**When to use:** Use for stable design-system contracts that should not depend on pixel screenshots. [VERIFIED: 69-CONTEXT.md]

**Example:**

```elixir
# Source: Phoenix.LiveViewTest and Floki docs
test "admin shell exposes scoped theme hook", %{conn: conn} do
  {:ok, _view, html} =
    live_isolated(conn, ChimewayAdmin.Live.DashboardLive,
      session: %{"current_actor" => "ops:1"},
      on_mount: [{ChimewayAdmin.LiveAuth, :search_traces}]
    )

  assert html =~ ~s(class="chimeway-admin")
  assert html =~ ~s(data-cw-theme="system")
end
```

### Anti-Patterns to Avoid

- **Adding a CSS framework or global stylesheet:** This contradicts the locked packaged stylesheet strategy and increases host-app leakage risk. [VERIFIED: 69-CONTEXT.md]
- **Page-specific responsive fixes first:** The seven admin pages share primitives, so page-local patches are more likely to drift. [VERIFIED: codebase grep] [ASSUMED]
- **Raw status colors at component sites:** Status colors need semantic token coverage for contrast across themes. [VERIFIED: codebase grep]
- **Motion without reduced-motion behavior:** MDN documents `prefers-reduced-motion` for users who prefer reduced non-essential motion. [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion]
- **Blocking LiveView JS transitions for simple hover/state polish:** LiveView JS transitions default to a 200ms transition time and can block during transitions; CSS is enough for this phase's current microinteractions. [CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.LiveView.JS.html]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Theme scoping | A JavaScript theme manager | CSS variables plus `data-cw-theme` and `prefers-color-scheme` | Current package already renders the theme attribute and CSS can resolve system preference. [VERIFIED: codebase grep] [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-color-scheme] |
| Accessibility baseline | Custom accessibility rules invented for this project | WCAG 2.2 AA success criteria | W3C defines contrast, reflow, focus, and motion-related criteria as testable success criteria. [CITED: https://www.w3.org/TR/WCAG22/] |
| HTML contract parsing | Regex-only assertions for nested markup | Floki selectors where structure matters | Floki parses HTML and supports selector-based node search. [CITED: https://floki.hexdocs.pm/Floki.html] |
| Component API validation | Ad hoc assign validation | `Phoenix.Component.attr/3`, `slot/3`, and `:global` attrs | Phoenix documents compile-time validation for attrs/slots and support for global `aria-`, `data-`, and `phx-` attributes. [CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html] |
| Full browser gate | New permanent Playwright lane | Phase 69 screenshot evidence; Phase 72 `mix verify.admin`/browser smoke | Phase 69 context explicitly defers durable browser-smoke gate composition to Phase 72. [VERIFIED: 69-CONTEXT.md] |

**Key insight:** The complex part is contract coverage, not rendering technology; the current package already has the correct host-mounted CSS and component architecture. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Token Inventory Without Token Adoption

**What goes wrong:** The stylesheet gains new token names but components keep raw `rem`, color, shadow, or transition literals. [ASSUMED]

**Why it happens:** Token work is planned as an additive palette instead of a usage contract. [ASSUMED]

**How to avoid:** Require tests or grep checks for key token names and migrate shared primitives to semantic tokens in the same plan. [VERIFIED: existing ExUnit style] [ASSUMED]

**Warning signs:** New `--cw-*` variables exist, but `.cw-button`, `.cw-row`, `.cw-table`, `.cw-status`, and `.cw-copy-id` still duplicate raw state values. [VERIFIED: codebase grep]

### Pitfall 2: Contrast Checks Only Cover Text on Page Background

**What goes wrong:** Base foreground/background passes, but hover backgrounds, focus rings, status dots, borders, and button text fail non-text or state contrast. [ASSUMED]

**Why it happens:** `color-mix()` produces derived colors that are harder to audit by inspection. [VERIFIED: codebase grep] [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value/color-mix]

**How to avoid:** Define state tokens for hover, active, focus, border, and status surfaces, then sample expected adjacent color pairs for light and dark modes. [CITED: https://www.w3.org/TR/WCAG22/]

**Warning signs:** Contrast evidence lists only `--cw-admin-fg` and `--cw-admin-bg`. [ASSUMED]

### Pitfall 3: Mobile Layout Treats Tables But Not Text Tokens

**What goes wrong:** `.cw-table-wrap` scrolls, but long IDs, summary labels, nav labels, and row metadata still collide or create unstable controls. [VERIFIED: codebase grep] [ASSUMED]

**Why it happens:** Tables get explicit `overflow-x: auto`, while rows and summary lists depend on flex/grid defaults. [VERIFIED: codebase grep]

**How to avoid:** Set `min-width: 0`, `overflow-wrap: anywhere`, stable control dimensions, and small-screen grid fallbacks for rows, copyable IDs, summary lists, search forms, metric grids, and page headers. [VERIFIED: codebase grep] [ASSUMED]

**Warning signs:** Mobile evidence uses only the dashboard and does not include trace detail, feed, or definitions. [VERIFIED: 69-CONTEXT.md]

### Pitfall 4: Motion Polish Slows Keyboard Workflows

**What goes wrong:** Hover/active effects add transform or transition delays that make rapid keyboard use feel sticky. [ASSUMED]

**Why it happens:** Visual polish is applied uniformly instead of limiting motion to short feedback states. [ASSUMED]

**How to avoid:** Keep motion tokens brief, avoid layout-affecting animation where possible, and keep `prefers-reduced-motion: reduce` coverage. [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion]

**Warning signs:** New animation declarations appear without matching reduced-motion behavior. [VERIFIED: codebase grep]

## Code Examples

Verified patterns from official sources and local code:

### CSS Contract Test

```elixir
# Source: existing ChimewayAdmin.Assets.inline_css/0 and ExUnit style
test "admin css exposes design system tokens" do
  css = ChimewayAdmin.Assets.inline_css()

  for token <- ~w(
    --cw-color-bg --cw-space-3 --cw-font-size-sm --cw-status-success
    --cw-focus-ring --cw-z-sidebar --cw-motion-fast
  ) do
    assert css =~ token
  end
end
```

### Reduced Motion Contract

```elixir
# Source: MDN prefers-reduced-motion and existing stylesheet pattern
test "admin css honors reduced motion preference" do
  css = ChimewayAdmin.Assets.inline_css()

  assert css =~ "@media (prefers-reduced-motion: reduce)"
  assert css =~ "transition-duration"
  assert css =~ "scroll-behavior: auto"
end
```

### Structural Hook Test

```elixir
# Source: Phoenix.LiveViewTest and Floki docs
test "core admin pages render inside scoped shell", %{conn: conn} do
  {:ok, _view, html} =
    live_isolated(conn, ChimewayAdmin.Live.DashboardLive,
      session: %{"current_actor" => "ops:1"},
      on_mount: [{ChimewayAdmin.LiveAuth, :search_traces}]
    )

  doc = Floki.parse_document!(html)
  assert [_] = Floki.find(doc, ".chimeway-admin[data-cw-theme]")
  assert [_ | _] = Floki.find(doc, ".cw-nav__item")
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Unlayered CSS specificity fights | Cascade layers for token/base/layout/component/utility order | `@layer` broadly available since March 2022 per MDN | Keep the existing layer model and avoid high-specificity selectors. [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/@layer] |
| Manual OS-theme JavaScript | `prefers-color-scheme` for system theme branch | CSS media feature documented by MDN | Keep theme behavior CSS-first. [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-color-scheme] |
| Ignoring user motion preferences | `prefers-reduced-motion` media query | CSS media feature documented by MDN | Required for reduced-motion-safe microinteractions. [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion] |
| Hand-authored derived colors only | `color-mix()` for derived state colors with token fallbacks where useful | MDN marks `color-mix()` broadly available since May 2023 | Accept existing use, but define auditable state tokens where repeated. [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value/color-mix] |

**Deprecated/outdated:**
- Treating Phoenix admin UI as a trace-only screen is outdated for v1.11; Phase 68 locked the seven-page console shape. [VERIFIED: 68-CONTEXT.md]
- Adding Phase 72 browser smoke infrastructure in Phase 69 is out of scope. [VERIFIED: 69-CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Raw repeated state values make contrast/state auditing harder than semantic tokens. | Summary, Architecture Patterns, Common Pitfalls | Planner may under-prioritize migration of existing declarations to tokens. |
| A2 | Page-specific responsive patches are more likely to drift than shared primitive fixes. | Anti-Patterns, Common Pitfalls | Planner may create too many page-local tasks. |
| A3 | Motion polish can slow keyboard-heavy workflows if transition scope grows. | Common Pitfalls | Planner may allow decorative animation beyond DES-04. |

## Open Questions

1. **Should Phase 69 persist screenshot artifacts, or only document screenshot-ready commands?**
   - What we know: Context requires mobile/desktop visual evidence compatibility but defers the permanent browser smoke gate to Phase 72. [VERIFIED: 69-CONTEXT.md]
   - What's unclear: Whether planner should create committed screenshots or a local evidence note. [ASSUMED]
   - Recommendation: Capture evidence during execution, but do not commit large binary screenshots unless an existing project convention requires it. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir / Mix | Existing ExUnit and LiveView tests | yes | Elixir 1.19.5 / OTP 28 in this environment | Project supports Elixir 1.17+ / OTP 26+, so planner should not require 1.19-only features. [VERIFIED: command output] [VERIFIED: AGENTS.md] |
| Phoenix LiveView | Admin LiveViews and tests | yes | locked 1.1.30 | Use existing locked version; do not chase 1.2.0 release candidates. [VERIFIED: mix deps] |
| Floki | Structural HTML contract tests | yes | locked 0.38.3 | Use string assertions only for trivial CSS text checks. [VERIFIED: mix deps] |
| Chromium | Optional screenshot/manual evidence | yes | command found at `/opt/homebrew/bin/chromium` | If browser automation is not scripted, use ExUnit CSS/markup contracts and manual screenshots. [VERIFIED: command -v] |
| ctx7 CLI | Documentation lookup fallback | no | unavailable | Official docs and HexDocs were used instead. [VERIFIED: command output] |

**Missing dependencies with no fallback:**
- None for Phase 69 planning; no new build/runtime package is required. [VERIFIED: 69-CONTEXT.md]

**Missing dependencies with fallback:**
- `ctx7` is unavailable; official W3C, MDN, HexDocs, and local code inspection were used. [VERIFIED: command output]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit plus Phoenix.LiveViewTest; Floki available for structural HTML parsing. [VERIFIED: mix deps] |
| Config file | `chimeway_admin/test/test_helper.exs` and package test support modules. [VERIFIED: rg --files] |
| Quick run command | `cd chimeway_admin && mix test test/chimeway_admin/design_system_test.exs` [ASSUMED] |
| Full suite command | `cd chimeway_admin && mix test` [VERIFIED: mix aliases] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| DES-01 | CSS exposes required token families and shared primitives consume semantic tokens. | unit/contract | `cd chimeway_admin && mix test test/chimeway_admin/design_system_test.exs` | no, Wave 0 |
| DES-02 | Light/dark/system theme hooks and contrast-state token branches exist. | unit/contract | `cd chimeway_admin && mix test test/chimeway_admin/design_system_test.exs` | no, Wave 0 |
| DES-03 | Core pages render shared responsive hooks for shell, nav, forms, rows, tables, summaries, copy IDs, metrics, and headers. | LiveView/structure | `cd chimeway_admin && mix test test/chimeway_admin/live/design_system_live_test.exs` | no, Wave 0 |
| DES-04 | CSS includes purposeful transition tokens and reduced-motion override. | unit/contract | `cd chimeway_admin && mix test test/chimeway_admin/design_system_test.exs` | no, Wave 0 |

### Sampling Rate

- **Per task commit:** `cd chimeway_admin && mix test test/chimeway_admin/design_system_test.exs` after that file exists. [ASSUMED]
- **Per wave merge:** `cd chimeway_admin && mix test`. [VERIFIED: current package tests]
- **Phase gate:** `cd chimeway_admin && mix test`; optionally capture mobile/desktop visual evidence locally without adding Phase 72 gate composition. [VERIFIED: 69-CONTEXT.md]

### Wave 0 Gaps

- [ ] `chimeway_admin/test/chimeway_admin/design_system_test.exs` - covers DES-01, DES-02, DES-04. [ASSUMED]
- [ ] `chimeway_admin/test/chimeway_admin/live/design_system_live_test.exs` - covers DES-03 rendered shell/component hooks. [ASSUMED]
- [ ] Optional local screenshot/evidence command or note - supports DES-03 success criterion without creating `mix verify.admin`. [ASSUMED]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no direct Phase 69 change | Preserve existing auth seams; Phase 70 owns hardening. [VERIFIED: 69-CONTEXT.md] |
| V3 Session Management | no direct Phase 69 change | Do not add client storage or theme persistence in this phase unless explicitly scoped. [VERIFIED: 69-CONTEXT.md] [ASSUMED] |
| V4 Access Control | no direct Phase 69 change | Do not alter LiveAuth or recovery authorization behavior in a design-system phase. [VERIFIED: 69-CONTEXT.md] |
| V5 Input Validation | yes, markup/CSS safety only | Preserve Phoenix component attrs and existing form controls; no new data-processing surface. [VERIFIED: codebase grep] |
| V6 Cryptography | no | No cryptography should be introduced. [VERIFIED: 69-CONTEXT.md] |
| V9 Communications | no direct Phase 69 change | Static asset and host mount behavior remain unchanged. [VERIFIED: codebase grep] |
| V14 Configuration | yes, low risk | Preserve host-embeddable packaged asset path and avoid new build config. [VERIFIED: 69-CONTEXT.md] |

### Known Threat Patterns for Embedded Admin UI

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Host CSS leakage into admin or admin CSS leakage into host | Tampering | Keep `.chimeway-admin` scoping and low-specificity `:where()` selectors. [VERIFIED: codebase grep] |
| Sensitive payload exposure during UI polish | Information Disclosure | Do not expand DTOs or rendered data in this phase; Phase 71 owns redaction contracts. [VERIFIED: 69-CONTEXT.md] |
| Action-bearing recovery UI accidentally changed by visual refactor | Elevation of Privilege / Tampering | Restrict Phase 69 changes to style hooks and shared component structure; Phase 70 owns recovery safety. [VERIFIED: 69-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)

- `AGENTS.md` - project stack, build principles, quality gates, and security constraints. [VERIFIED: file read]
- `.planning/phases/69-console-design-system/69-CONTEXT.md` - locked implementation decisions and phase boundary. [VERIFIED: file read]
- `.planning/REQUIREMENTS.md` - DES-01 through DES-04 requirement text. [VERIFIED: file read]
- `.planning/STATE.md` and `.planning/ROADMAP.md` - active milestone and phase boundaries. [VERIFIED: file read]
- `chimeway_admin/priv/static/chimeway_admin.css` - existing token, theme, layout, state, and motion CSS. [VERIFIED: codebase grep]
- `chimeway_admin/lib/chimeway_admin/components/*.ex` and `chimeway_admin/lib/chimeway_admin/live/*.ex` - shared component and LiveView hooks. [VERIFIED: codebase grep]
- W3C WCAG 2.2 - contrast, reflow, focus, and animation criteria. [CITED: https://www.w3.org/TR/WCAG22/]
- MDN `@layer`, `prefers-color-scheme`, `prefers-reduced-motion`, and `color-mix()` docs. [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/@layer] [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-color-scheme] [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion] [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value/color-mix]
- Phoenix LiveView HexDocs for `Phoenix.Component`, `Phoenix.LiveViewTest`, and `Phoenix.LiveView.JS`. [CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html] [CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.LiveViewTest.html] [CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.LiveView.JS.html]
- Floki HexDocs. [CITED: https://floki.hexdocs.pm/Floki.html]

### Secondary (MEDIUM confidence)

- `mix hex.info phoenix_live_view` and `mix hex.info floki` - current locked/recent release and download data from Hex. [VERIFIED: Hex registry]

### Tertiary (LOW confidence)

- Assumptions about planner task grouping and screenshot artifact persistence. [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - locked by context and verified against local package/dependency state. [VERIFIED: 69-CONTEXT.md] [VERIFIED: mix deps]
- Architecture: HIGH - shared shell/components/CSS path verified in code. [VERIFIED: codebase grep]
- Pitfalls: MEDIUM - most risks are inferred from the current CSS structure and standard accessibility failure modes. [ASSUMED] [CITED: https://www.w3.org/TR/WCAG22/] [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion]

**Research date:** 2026-06-04
**Valid until:** 2026-07-04 for codebase-local architecture; re-check MDN/HexDocs before changing browser or package baselines. [ASSUMED]

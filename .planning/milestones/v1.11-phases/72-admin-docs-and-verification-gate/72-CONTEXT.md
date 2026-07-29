# Phase 72: Admin Docs and Verification Gate - Context

**Gathered:** 2026-06-04 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 72 makes the already-built `chimeway_admin` operator console shippable through integration documentation, doc-contract coverage, a named local/CI verification gate, and real browser smoke. It does not add new operator pages or broaden admin capability; it packages and verifies the seven-page console delivered and hardened in Phases 68-71.
</domain>

<decisions>
## Implementation Decisions

### Admin Integration Guide

- **D-01:** Add a dedicated admin integration guide under `guides/introduction/` and include it in HexDocs extras.
- **D-02:** Treat the demo-host README as supporting proof copy, not the canonical adopter setup guide.
- **D-03:** The guide must cover router mount, packaged static assets, auth behaviour, route prefixing, recovery permissions, tenant/context expectations, redaction guarantees, and production fail-closed expectations.

### Doc Contracts

- **D-04:** Extend root `test/chimeway/doc_contract_test.exs` for admin integration doc contracts instead of keeping the contracts only inside `chimeway_admin` tests.
- **D-05:** Lock route labels, route paths, auth snippets, static asset setup, redaction claims, recovery permission language, and honest Definitions/Feed Debug claims through doc contracts.
- **D-06:** Keep `mix ci.verify_gates` as the release-doc gate that proves doc contracts and release-gate parity.

### Verify Gate And CI Parity

- **D-07:** Add root `mix verify.admin` as the named admin gate.
- **D-08:** `mix verify.admin` must compose all three required surfaces: root core admin/read-model tests, full `chimeway_admin` package tests, and demo-host mounted admin coverage.
- **D-09:** Add a CI job that invokes the same `mix verify.admin` alias so local and CI verification remain in parity.
- **D-10:** Extend release-gate contracts so `verify.admin` is counted alongside existing named ecosystem gates.

### Browser Smoke

- **D-11:** Add a real headless browser smoke against the demo-host mount at `/admin/chimeway`; do not satisfy SMOKE-01 with only `Phoenix.LiveViewTest` or static HTML assertions.
- **D-12:** Use Playwright with Chromium as the recommended smallest fit for browser smoke because it owns browser installation and CI dependencies directly.
- **D-13:** Browser smoke must prove the mounted console is nonblank, styled through the packaged admin CSS, navigable across the core pages, and usable enough to catch blank-page, asset-serving, or route/navigation regressions.

### the agent's Discretion

Downstream agents may choose the narrowest implementation shape that satisfies the decisions above. Prefer one cohesive admin guide plus focused contract tests and one smoke harness over scattered docs or broad E2E expansion.

### Folded Todos

None.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/PROJECT.md`
- `.planning/STATE.md`
- `.planning/phases/68-admin-truth-alignment/68-CONTEXT.md`
- `.planning/phases/69-console-design-system/69-CONTEXT.md`
- `.planning/phases/70-recovery-auth-and-tenancy-hardening/70-CONTEXT.md`
- `.planning/phases/71-redaction-and-explainability-contracts/71-CONTEXT.md`
- `mix.exs`
- `.github/workflows/ci.yml`
- `test/chimeway/doc_contract_test.exs`
- `test/chimeway/release_gate_contract_test.exs`
- `test/chimeway/admin_test.exs`
- `chimeway_admin/lib/chimeway_admin.ex`
- `chimeway_admin/lib/chimeway_admin/router.ex`
- `chimeway_admin/lib/chimeway_admin/assets.ex`
- `chimeway_admin/lib/chimeway_admin/live_auth.ex`
- `chimeway_admin/lib/chimeway_admin/context.ex`
- `chimeway_admin/lib/chimeway_admin/components/status.ex`
- `chimeway_admin/test/chimeway_admin/routes_test.exs`
- `chimeway_admin/test/chimeway_admin/design_system_test.exs`
- `chimeway_admin/test/chimeway_admin/live/privacy_leak_live_test.exs`
- `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs`
- `examples/chimeway_demo_host/lib/demo_host_web/router.ex`
- `examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex`
- `examples/chimeway_demo_host/lib/demo_host_web/layouts/root.html.heex`
- `examples/chimeway_demo_host/lib/demo_host/admin_auth.ex`
- `examples/chimeway_demo_host/lib/demo_host_web/plugs/admin_actor.ex`
- `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs`
- `examples/chimeway_demo_host/README.md`

External browser-smoke references:
- `https://playwright.dev/docs/next/browsers`
- `https://phoenix-test.hexdocs.pm/PhoenixTest.html`
- `https://github.com/elixir-wallaby/wallaby`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `ChimewayAdmin` moduledocs already include route and stylesheet snippets that can seed the integration guide.
- `ChimewayAdmin.Router.chimeway_admin_routes/1` is the canonical route macro for all seven pages.
- `ChimewayAdmin.Assets.css_path/0` and `inline_css/0` expose the packaged admin CSS path and content.
- `examples/chimeway_demo_host` already mounts `/admin/chimeway`, serves `/chimeway_admin/chimeway_admin.css`, and links the packaged stylesheet from the root layout.
- Existing admin tests already cover route truth, design-system contracts, privacy leak checks, recovery flow, and demo-host mounted trace behavior.

### Established Patterns

- Named `verify.*` aliases live in root `mix.exs` and shell into packages/examples where needed.
- CI mirrors important named verify aliases in `.github/workflows/ci.yml`; root release-gate tests assert CI and docs parity.
- Doc contracts are centralized in `test/chimeway/doc_contract_test.exs`, including current admin README drift checks.
- Release-gate parity is enforced in `test/chimeway/release_gate_contract_test.exs`.
- Existing docs/release-gate phases treat `mix ci.verify_gates` as the acceptance gate for doc-contract and release parity.

### Integration Points

- Admin guide work connects to `mix.exs` docs extras, `guides/introduction/`, and root doc-contract tests.
- Verify-gate work connects to `mix.exs`, `.github/workflows/ci.yml`, and `test/chimeway/release_gate_contract_test.exs`.
- Browser smoke connects to the demo host mounted route, endpoint static asset serving, root layout stylesheet link, and the eventual `mix verify.admin` gate.
</code_context>

<specifics>
## Specific Ideas

- Name the new guide something like `guides/introduction/admin-console-integration.md`.
- Include copy-paste snippets for `scope "/admin/chimeway"`, `import ChimewayAdmin.Router`, `chimeway_admin_routes()`, `config :chimeway_admin, auth_module: MyApp.AdminAuth`, and `Plug.Static` asset serving.
- Document `ChimewayAdmin.Auth.authorize/3` as host-owned and fail-closed for production.
- Explicitly state that admin DTOs and rendered HTML are redacted surfaces and must not expose raw payloads, render data, provider bodies, tokens, secrets, auth codes, or full recipient PII.
- Have Playwright smoke visit Command Center, Trace Lookup, Feed Debug, Definitions, Health, Recovery, and at least one trace detail route when seeded data provides a delivery id.
</specifics>

<deferred>
## Deferred Ideas

None - analysis stayed within phase scope.
</deferred>

# Phase 72: Admin Docs and Verification Gate - Research

**Researched:** 2026-06-04  
**Domain:** Elixir/Phoenix docs, verification gates, CI parity, and browser smoke  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
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

### Deferred Ideas (OUT OF SCOPE)
None - analysis stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOCS-12 | Maintainer can follow a canonical admin integration guide covering router mount, static assets, auth behavior, route prefixing, recovery permissions, redaction, and production fail-closed expectations. [VERIFIED: .planning/REQUIREMENTS.md] | Use a new `guides/introduction/admin-console-integration.md`, add it to `docs.extras`, and lock the exact setup claims in root doc contracts. [VERIFIED: codebase grep] |
| GATE-08 | Maintainer can run `mix verify.admin` locally and in CI to verify core admin read models, `chimeway_admin`, and demo-host mounted admin coverage. [VERIFIED: .planning/REQUIREMENTS.md] | Follow existing root alias and CI job patterns in `mix.exs`, `.github/workflows/ci.yml`, and release-gate parity tests. [VERIFIED: codebase grep] |
| SMOKE-01 | Maintainer can run a browser smoke that proves the mounted admin console is nonblank, styled, navigable, and usable across the core pages. [VERIFIED: .planning/REQUIREMENTS.md] | Use Playwright Chromium against the demo host at `/admin/chimeway`, with assertions for content, CSS, navigation, and form usability. [CITED: https://playwright.dev/docs/browsers] |
</phase_requirements>

## Summary

Phase 72 is a packaging and verification phase, not a feature expansion phase. [VERIFIED: 72-CONTEXT.md] The planner should extend the existing admin surfaces already delivered in Phases 68-71: the root admin read-model tests, the `chimeway_admin` package test suite, and the demo-host mount at `/admin/chimeway`. [VERIFIED: codebase grep]

Use repo-native contracts as the control plane: root doc contracts in `test/chimeway/doc_contract_test.exs`, release-gate parity in `test/chimeway/release_gate_contract_test.exs`, named aliases in root `mix.exs`, and mirrored jobs in `.github/workflows/ci.yml`. [VERIFIED: codebase grep] The one new domain is real browser smoke; Playwright is the locked choice, and `@playwright/test` 1.60.0 is current on npm as of 2026-06-04 with Node >=18 required. [VERIFIED: npm registry] [CITED: https://playwright.dev/docs/browsers]

**Primary recommendation:** Add one canonical admin guide, extend root doc/release contracts, define `mix verify.admin`, mirror it in CI/ci-gate, and make the browser smoke a Playwright Chromium test invoked by that same gate. [VERIFIED: codebase grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Admin integration guide | Documentation / HexDocs | Elixir docs config | `mix.exs` owns ExDoc extras, while guide content owns adopter setup truth. [VERIFIED: codebase grep] |
| Doc contracts | Test / CI | Documentation | Root ExUnit contracts already enforce docs drift and HexDocs extras. [VERIFIED: codebase grep] |
| `mix verify.admin` | Build / CLI | CI | Root `mix.exs` owns named verification aliases and CI mirrors them. [VERIFIED: codebase grep] |
| Browser smoke | Test harness | Demo host / Browser | Smoke must exercise a real browser against the Phoenix demo host mount and packaged CSS. [VERIFIED: 72-CONTEXT.md] |
| Admin auth/redaction guarantees | Host app + admin package | Core read models | Host apps own auth, tenancy, and session context; Chimeway/admin packages expose fail-closed auth and redacted DTO/rendering surfaces. [VERIFIED: codebase grep] |

## Project Constraints (from AGENTS.md)

- Chimeway is an embedded notification layer for Elixir/Phoenix apps; host applications own data, policies, and delivery history. [VERIFIED: AGENTS.md]
- Every notification decision must be explainable. [VERIFIED: AGENTS.md]
- Stack baseline is Elixir 1.17+, OTP 26+, Ecto 3.x, PostgreSQL 15+, optional Phoenix 1.7/1.8, optional Oban 2.x, and Swoosh 1.x email seams. [VERIFIED: AGENTS.md]
- Persist stable `notification_key` plus version, not module names as durable identity. [VERIFIED: AGENTS.md]
- Keep the durable lifecycle spine: event -> notification -> delivery -> attempt. [VERIFIED: AGENTS.md]
- Treat idempotency and suppression reasons as first-class product behavior. [VERIFIED: AGENTS.md]
- Keep adapters replaceable with explicit behaviours and contract tests. [VERIFIED: AGENTS.md]
- Preserve host ownership boundaries for auth, tenancy, URL generation, and correlation IDs. [VERIFIED: AGENTS.md]
- Maintain `mix verify.*` and `mix ci.*` entrypoints with CI/local parity. [VERIFIED: AGENTS.md]
- Avoid leaking sensitive payload fields in telemetry and operator surfaces. [VERIFIED: AGENTS.md]
- Docs/release-gate acceptance uses green `mix ci.verify_gates` plus ecosystem `verify.*` CI jobs; `/gsd-verify-work` is skipped for those phases. [VERIFIED: AGENTS.md]

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir / Mix | Local: Elixir 1.19.5, project target `~> 1.17` | Root aliases, ExUnit, docs build | Existing repo uses Mix aliases for all verification gates. [VERIFIED: local env] [VERIFIED: codebase grep] |
| ExUnit | Bundled with Elixir | Doc contracts, release-gate contracts, admin read-model tests | Existing contracts are ExUnit tests under `test/chimeway`. [VERIFIED: codebase grep] |
| ExDoc | Locked 0.40.1, latest 0.40.3 | HexDocs extras and guide rendering | Root docs config already uses `extras` and `groups_extras`. [VERIFIED: Hex registry] [VERIFIED: codebase grep] |
| Phoenix / LiveView | Phoenix locked 1.8.7; LiveView locked 1.1.31 | Demo host route mount and mounted admin LiveViews | Demo host mounts `ChimewayAdmin.Router` under `/admin/chimeway`. [VERIFIED: Hex registry] [VERIFIED: codebase grep] |
| Plug.Static | Plug locked 1.19.2 | Serve packaged `chimeway_admin.css` from host endpoint | Demo host already serves `/chimeway_admin/chimeway_admin.css` with `Plug.Static`. [VERIFIED: Hex registry] [VERIFIED: codebase grep] |
| `@playwright/test` | 1.60.0 | Browser smoke runner and Chromium automation | Locked by Phase 72 decision and verified on npm; Playwright docs describe browser installation through Playwright tooling. [VERIFIED: npm registry] [CITED: https://playwright.dev/docs/browsers] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `chimeway_admin` | In-repo package 0.1.0 | Mountable admin console and package test suite | Required by `mix verify.admin`. [VERIFIED: codebase grep] |
| Demo host | In-repo example app 0.0.0 | Mounted browser target and host integration proof | Required for demo-host mounted coverage and Playwright smoke. [VERIFIED: codebase grep] |
| PostgreSQL | Local `psql` 14.17; project/CI service PostgreSQL 15 | Ecto storage for root/demo tests | CI config uses PostgreSQL 15 service; local server is accepting connections. [VERIFIED: local env] [VERIFIED: codebase grep] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Playwright | Phoenix.LiveViewTest or ConnTest only | Rejected by locked D-11 because SMOKE-01 requires a real browser. [VERIFIED: 72-CONTEXT.md] |
| Playwright | Wallaby | Not chosen because Phase 72 locks Playwright as the smallest fit. [VERIFIED: 72-CONTEXT.md] |
| Canonical guide | Demo-host README only | Rejected by D-02; README remains proof copy, not adopter setup SSOT. [VERIFIED: 72-CONTEXT.md] |

**Installation:**
```bash
npm install --save-dev @playwright/test
npx playwright install --with-deps chromium
```
The npm package name was confirmed from Playwright official docs and npm registry, then slopchecked with the npm ecosystem forced. [CITED: https://playwright.dev/docs/browsers] [VERIFIED: npm registry]

**Version verification:**
```bash
npm view @playwright/test version time.created time.modified repository.url scripts.postinstall --json
mix hex.info phoenix
mix hex.info phoenix_live_view
mix hex.info ex_doc
mix hex.info plug
```

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| `@playwright/test` [VERIFIED: npm registry] | npm | Created 2020-09-24; modified 2026-06-04 | 38,641,569 last week from npm downloads API | `github.com/microsoft/playwright` | OK when run as `slopcheck install --ecosystem npm @playwright/test` | Approved |

**Packages removed due to slopcheck [SLOP] verdict:** none. [VERIFIED: slopcheck]  
**Packages flagged as suspicious [SUS]:** none. [VERIFIED: slopcheck]

Note: `slopcheck install @playwright/test` without `--ecosystem npm` defaulted to PyPI in this Elixir repo and falsely reported SLOP because the npm-scoped package does not exist on PyPI. [VERIFIED: slopcheck] Always force `--ecosystem npm` for this package. [VERIFIED: slopcheck]

## Architecture Patterns

### System Architecture Diagram

```text
Maintainer / CI
  |
  v
mix verify.admin
  |
  +--> Root ExUnit admin/read-model tests
  |       |
  |       v
  |   Chimeway.Admin redacted DTOs + recovery candidates
  |
  +--> chimeway_admin package tests
  |       |
  |       v
  |   Router labels, path prefixing, auth, LiveViews, design CSS, privacy leaks
  |
  +--> Demo host mounted admin tests
  |       |
  |       v
  |   Phoenix router scope /admin/chimeway + Plug.Static CSS + host AdminAuth
  |
  +--> Playwright Chromium smoke
          |
          v
      Running demo host -> /admin/chimeway -> pages/forms/assets assertions

Docs flow:
admin-console-integration.md -> mix.exs docs.extras -> doc_contract_test.exs -> mix ci.verify_gates -> CI verify_gates

Release parity flow:
mix.exs alias + ci.yml job + MAINTAINING pre-ship block -> release_gate_contract_test.exs -> ci-gate needs
```

### Recommended Project Structure

```text
guides/introduction/admin-console-integration.md   # Canonical adopter guide
test/chimeway/doc_contract_test.exs                # Admin guide doc-contract assertions
test/chimeway/release_gate_contract_test.exs       # verify.admin parity with CI/MAINTAINING/ci-gate
mix.exs                                           # verify.admin alias + docs extras
.github/workflows/ci.yml                          # verify_admin job and ci-gate needs
test/browser/admin_smoke.spec.ts                  # Playwright browser smoke
playwright.config.ts                              # Browser smoke config, webServer, Chromium
package.json / package-lock.json                  # npm dev dependency lock for @playwright/test
```

### Pattern 1: Canonical Guide Plus Contract
**What:** Add one `guides/introduction/admin-console-integration.md` and list it in `mix.exs` `docs.extras`. [VERIFIED: codebase grep]  
**When to use:** Use this for DOCS-12; existing integration guides live under `guides/introduction/` and doc contracts require them in HexDocs extras. [VERIFIED: codebase grep]  
**Example:**
```elixir
# Source: mix.exs docs.extras pattern [VERIFIED: codebase grep]
extras: [
  "guides/introduction/getting-started.md",
  "guides/introduction/installation.md",
  "guides/introduction/admin-console-integration.md"
]
```

### Pattern 2: Root Mix Alias Composes Sub-surfaces
**What:** Define `verify.admin` in root `mix.exs` as a composed alias that shells into package/example tests where needed. [VERIFIED: codebase grep]  
**When to use:** Use this for GATE-08; existing aliases such as `verify.example` and `verify.inbox` compose root/package/example lanes. [VERIFIED: codebase grep]  
**Example:**
```elixir
# Source: existing verify.* aliases in mix.exs [VERIFIED: codebase grep]
"verify.admin": [
  "cmd env MIX_ENV=test mix test test/chimeway/admin_test.exs --warnings-as-errors",
  "cmd --shell cd chimeway_admin && mix deps.get && mix test --warnings-as-errors",
  "cmd --shell cd examples/chimeway_demo_host && mix deps.get && mix test --only admin_truth --warnings-as-errors",
  "cmd npm ci",
  "cmd npx playwright install --with-deps chromium",
  "cmd npx playwright test test/browser/admin_smoke.spec.ts"
]
```

### Pattern 3: CI Mirrors the Alias
**What:** Add `verify_admin` job that runs `mix verify.admin`, then add it to `ci-gate` `needs`. [VERIFIED: codebase grep]  
**When to use:** Use this for local/CI parity; release-gate contracts already assert job existence and command parity for named gates. [VERIFIED: codebase grep]  
**Example:**
```yaml
# Source: .github/workflows/ci.yml verify_* job pattern [VERIFIED: codebase grep]
verify_admin:
  name: Admin docs and browser smoke gate
  runs-on: ubuntu-latest
  services:
    postgres:
      image: postgres:15
  env:
    MIX_ENV: test
    DATABASE_URL: postgres://postgres:postgres@localhost/chimeway_test
  steps:
    - uses: actions/checkout@...
    - uses: erlef/setup-beam@...
    - uses: actions/setup-node@...
    - run: mix deps.get
    - run: mix ecto.create --quiet
    - run: mix ecto.migrate --quiet
    - run: mix verify.admin
```

### Pattern 4: Browser Smoke Against Demo Host
**What:** Use Playwright Chromium with a configured web server that boots the demo host, then visit `/admin/chimeway` and navigate the core pages. [CITED: https://playwright.dev/docs/browsers] [VERIFIED: codebase grep]  
**When to use:** Use this for SMOKE-01; LiveViewTest already exists but is insufficient for D-11. [VERIFIED: 72-CONTEXT.md]  
**Example:**
```typescript
// Source: Playwright browser testing model [CITED: https://playwright.dev/docs/browsers]
import { expect, test } from "@playwright/test";

test("mounted admin console is styled and navigable", async ({ page }) => {
  await page.goto("/admin/chimeway");
  await expect(page.getByRole("heading", { name: "Command Center" })).toBeVisible();
  await expect(page.locator("link[href='/chimeway_admin/chimeway_admin.css']")).toHaveCount(1);
  await expect(page.locator(".chimeway-admin")).toBeVisible();

  for (const path of ["/traces", "/feed", "/definitions", "/health", "/recovery"]) {
    await page.goto(`/admin/chimeway${path}`);
    await expect(page.locator("body")).not.toBeEmpty();
  }
});
```

### Anti-Patterns to Avoid
- **Guide content only in README:** The README is explicitly non-canonical for adopter setup in this phase. [VERIFIED: 72-CONTEXT.md]
- **Browser smoke without CSS assertion:** SMOKE-01 requires styled proof, and demo host serves CSS through `Plug.Static`. [VERIFIED: 72-CONTEXT.md] [VERIFIED: codebase grep]
- **New CI command that does not call `mix verify.admin`:** GATE-08 requires the same named gate locally and in CI. [VERIFIED: 72-CONTEXT.md]
- **Admin auth examples that authorize by default in production:** Demo auth denies all production requests; the guide must preserve fail-closed expectations. [VERIFIED: codebase grep]
- **Doc contracts inside `chimeway_admin` only:** D-04 locks root `test/chimeway/doc_contract_test.exs`. [VERIFIED: 72-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Browser automation | Custom HTTP/html scraper or screenshots via shell | Playwright Chromium | Phase decision locks real browser smoke, and Playwright owns browser installation commands. [VERIFIED: 72-CONTEXT.md] [CITED: https://playwright.dev/docs/browsers] |
| Docs drift checks | Manual checklist | Root ExUnit doc contracts | Existing project pattern already enforces docs claims in CI. [VERIFIED: codebase grep] |
| Route URL construction | Hard-coded prefixes inside LiveViews | `ChimewayAdmin.Routes` with `:path_prefix` | Existing routes helper handles mounted prefixes. [VERIFIED: codebase grep] |
| Auth policy | Built-in admin policy engine | Host `ChimewayAdmin.Auth.authorize/3` | Host ownership of auth/tenancy is a project constraint. [VERIFIED: AGENTS.md] [VERIFIED: codebase grep] |
| Static asset serving | Inline large CSS in docs/tests as the integration path | `Plug.Static` serving `priv/static/chimeway_admin.css` and `ChimewayAdmin.Assets.css_path/0` | Existing package exposes CSS path and demo host serves the packaged asset. [VERIFIED: codebase grep] |

**Key insight:** This phase should make the existing admin console shippable by locking the integration contract and gate topology, not by broadening admin behavior. [VERIFIED: 72-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Treating Playwright as a Replacement for Existing ExUnit Coverage
**What goes wrong:** The browser smoke becomes a broad E2E suite and duplicates existing LiveView/read-model tests. [ASSUMED]  
**Why it happens:** Browser tests can drift into behavior coverage that ExUnit already owns. [ASSUMED]  
**How to avoid:** Keep Playwright to nonblank, CSS, navigation, route, and minimal form usability assertions; keep read-model/auth/recovery semantics in ExUnit. [VERIFIED: 72-CONTEXT.md]  
**Warning signs:** Smoke test seeds many domain scenarios or asserts recovery internals already covered by `chimeway_admin` tests. [VERIFIED: codebase grep]

### Pitfall 2: Forgetting Release-Gate Parity
**What goes wrong:** `verify.admin` exists but is not listed in MAINTAINING, CI, or `ci-gate` needs. [VERIFIED: codebase grep]  
**Why it happens:** Current parity contracts enumerate each verify lane explicitly. [VERIFIED: codebase grep]  
**How to avoid:** Update `@pre_ship_verify_commands`, `@ci_gate_lanes`, MAINTAINING pre-ship copy, `.github/workflows/ci.yml`, and the expected gate count together. [VERIFIED: codebase grep]  
**Warning signs:** `mix ci.verify_gates` fails in `release_gate_contract_test.exs`. [VERIFIED: codebase grep]

### Pitfall 3: Browser Smoke Cannot Start a Usable Demo Host
**What goes wrong:** Playwright opens a page before Phoenix is ready or before the test database is migrated. [ASSUMED]  
**Why it happens:** The demo host depends on Ecto/PostgreSQL and Phoenix endpoint boot. [VERIFIED: codebase grep]  
**How to avoid:** Make `verify.admin`/CI prepare the database before Playwright, and configure Playwright `webServer` with a readiness URL or sufficient timeout. [ASSUMED]  
**Warning signs:** CI flakes with connection refused, blank Phoenix error pages, or missing CSS. [ASSUMED]

### Pitfall 4: Static Asset Claim Drift
**What goes wrong:** The guide documents a CSS path or `Plug.Static` setup that diverges from `ChimewayAdmin.Assets.css_path/0`. [VERIFIED: codebase grep]  
**Why it happens:** CSS serving is split between endpoint config and layout link. [VERIFIED: codebase grep]  
**How to avoid:** Contract-test `/chimeway_admin/chimeway_admin.css`, `ChimewayAdmin.Assets.css_path()`, and the exact `Plug.Static` snippet. [VERIFIED: 72-CONTEXT.md]  
**Warning signs:** Playwright page is unstyled while LiveViewTest still passes. [ASSUMED]

### Pitfall 5: Overclaiming Definitions or Feed Debug
**What goes wrong:** Docs imply code-registry skew detection or richer feed semantics that are not implemented. [VERIFIED: 72-CONTEXT.md]  
**Why it happens:** Earlier doc contracts already guard against stale admin claims. [VERIFIED: codebase grep]  
**How to avoid:** Use honest copy: Definitions are DB-inferred definition/version history; Feed Debug is operator feed/recipient debugging, not a generic analytics engine. [VERIFIED: 72-CONTEXT.md]  
**Warning signs:** Forbidden phrases such as `skew detection` or `code-registry` reappear. [VERIFIED: codebase grep]

## Code Examples

### Admin Router Mount
```elixir
# Source: ChimewayAdmin.Router moduledoc and demo host router [VERIFIED: codebase grep]
scope "/admin/chimeway" do
  pipe_through [:browser]

  import ChimewayAdmin.Router
  chimeway_admin_routes()
end
```

### Packaged Admin CSS
```elixir
# Source: ChimewayAdmin moduledoc and demo host endpoint [VERIFIED: codebase grep]
plug Plug.Static,
  at: "/chimeway_admin",
  from: {:chimeway_admin, "priv/static"},
  gzip: false,
  only: ~w(chimeway_admin.css)
```

### Host Auth Module
```elixir
# Source: ChimewayAdmin.Auth and DemoHost.AdminAuth [VERIFIED: codebase grep]
defmodule MyApp.AdminAuth do
  @behaviour ChimewayAdmin.Auth

  @impl true
  def authorize(actor, action, context) do
    if allowed?(actor, action, context), do: :ok, else: {:error, :unauthorized}
  end
end
```

### Doc Contract Shape
```elixir
# Source: test/chimeway/doc_contract_test.exs pattern [VERIFIED: codebase grep]
@admin_guide "guides/introduction/admin-console-integration.md"

describe "admin integration guide doc contract (DOCS-12)" do
  setup do
    %{content: File.read!(@admin_guide)}
  end

  for required <- ~w(/admin/chimeway chimeway_admin_routes Plug.Static ChimewayAdmin.Auth) do
    test "requires #{required}", %{content: content} do
      assert String.contains?(content, unquote(required))
    end
  end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| LiveViewTest/ConnTest-only admin smoke was acceptable for earlier journey proof. [VERIFIED: .planning/STATE.md] | Phase 72 requires real browser smoke with Playwright Chromium. [VERIFIED: 72-CONTEXT.md] | 2026-06-04 Phase 72 decisions | Planner must include Node/Playwright setup and CI browser dependencies. |
| Demo-host README carried admin copy. [VERIFIED: codebase grep] | Canonical setup moves to `guides/introduction/admin-console-integration.md`. [VERIFIED: 72-CONTEXT.md] | 2026-06-04 Phase 72 decisions | README is supporting proof, not the adopter SSOT. |
| Release gate parity lists ten pre-ship commands. [VERIFIED: codebase grep] | Adding `verify.admin` means counts and lane lists must increase consistently. [VERIFIED: 72-CONTEXT.md] | Phase 72 implementation | Planner must update MAINTAINING and contracts together. |

**Deprecated/outdated:**
- Satisfying SMOKE-01 with only `Phoenix.LiveViewTest` is explicitly rejected by D-11. [VERIFIED: 72-CONTEXT.md]
- Describing Definitions as code-registry skew detection is stale and forbidden by existing admin doc contracts. [VERIFIED: codebase grep]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Keep browser smoke narrow to avoid duplicating ExUnit behavior coverage. | Common Pitfalls | Planner may under- or over-scope Playwright tests. |
| A2 | Playwright `webServer` with a readiness URL/timeout is the cleanest demo-host startup strategy. | Common Pitfalls | Planner may choose a shell-managed server instead. |
| A3 | CI should use `actions/setup-node` for Playwright because no Node setup action exists in current CI. | Architecture Patterns | Planner may need to pin the action SHA to match repo policy before implementation. |

## Open Questions

1. **Where should Playwright files live?**
   - What we know: No existing root `package.json` or Playwright config existed before this research. [VERIFIED: codebase grep]
   - What's unclear: The repo has no established JS test directory convention. [VERIFIED: codebase grep]
   - Recommendation: Use root `test/browser/admin_smoke.spec.ts` plus root `playwright.config.ts` so `mix verify.admin` can run from the repo root. [ASSUMED]

2. **Should `verify.admin` include `npm ci` and browser install every local run?**
   - What we know: Playwright requires browser binaries, and official docs provide install commands. [CITED: https://playwright.dev/docs/browsers]
   - What's unclear: Whether maintainers prefer faster local reruns or fully self-contained gates. [ASSUMED]
   - Recommendation: Make the alias self-contained first; optimize later if it becomes slow. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir/Mix | All ExUnit and aliases | ✓ | Elixir 1.19.5 / Mix 1.19.5 local; project target `~> 1.17` | Use CI Elixir 1.17/OTP 27 for release truth. [VERIFIED: local env] [VERIFIED: codebase grep] |
| Node.js | Playwright | ✓ | v22.14.0 | CI must add Node setup. [VERIFIED: local env] |
| npm/npx | Playwright package/scripts | ✓ | npm 11.1.0 / npx 11.1.0 | None if Playwright is implemented. [VERIFIED: local env] |
| PostgreSQL | Root/demo Ecto tests | ✓ local server | local `psql` 14.17; CI uses postgres:15 | CI service already uses PostgreSQL 15. [VERIFIED: local env] [VERIFIED: codebase grep] |
| Docker | CI parity local debugging | ✓ | Docker 29.5.2 | Not required for normal local gate if Postgres is running. [VERIFIED: local env] |
| Context7 CLI | Docs lookup fallback | ✗ | — | Official docs and registry commands used instead. [VERIFIED: local env] |

**Missing dependencies with no fallback:** none for research. [VERIFIED: local env]  
**Missing dependencies with fallback:** Context7 CLI missing; official docs and local registry commands were used. [VERIFIED: local env]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit for Elixir contracts/tests; Playwright 1.60.0 for browser smoke. [VERIFIED: codebase grep] [VERIFIED: npm registry] |
| Config file | Existing ExUnit via Mix; Playwright config missing and should be added in Wave 0. [VERIFIED: codebase grep] |
| Quick run command | `mix ci.verify_gates` for docs/release contracts; `mix verify.admin` after implementation. [VERIFIED: codebase grep] |
| Full suite command | `mix ci && mix ci.docs && mix ci.verify_gates && mix verify.admin` for this phase gate. [VERIFIED: codebase grep] [ASSUMED] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DOCS-12 | Canonical admin guide covers mount/assets/auth/prefix/recovery/redaction/fail-closed. | doc contract | `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | ✅ extend existing |
| GATE-08 | `mix verify.admin` composes root admin, package admin, demo mounted admin, and browser smoke. | release/CI contract + command smoke | `mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` and `mix verify.admin` | ✅ extend existing + ❌ alias missing |
| SMOKE-01 | Browser proves mounted admin console is nonblank, styled, navigable, usable. | browser smoke | `npx playwright test test/browser/admin_smoke.spec.ts` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix ci.verify_gates` for docs/contract tasks; targeted package/demo tests for gate tasks. [VERIFIED: codebase grep]
- **Per wave merge:** `mix verify.admin` once implemented. [VERIFIED: 72-CONTEXT.md]
- **Phase gate:** `mix ci.verify_gates` plus ecosystem `verify.*` CI jobs; for this phase include green `verify_admin` job evidence. [VERIFIED: AGENTS.md] [VERIFIED: 72-CONTEXT.md]

### Wave 0 Gaps
- [ ] `guides/introduction/admin-console-integration.md` — covers DOCS-12. [VERIFIED: codebase grep]
- [ ] Root `package.json` / `package-lock.json` — locks `@playwright/test`. [VERIFIED: codebase grep]
- [ ] `playwright.config.ts` — starts or targets the demo host. [VERIFIED: codebase grep]
- [ ] `test/browser/admin_smoke.spec.ts` — covers SMOKE-01. [VERIFIED: codebase grep]
- [ ] Root `mix verify.admin` alias — covers GATE-08. [VERIFIED: codebase grep]
- [ ] CI `verify_admin` job — covers GATE-08 CI parity. [VERIFIED: codebase grep]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | yes | Host-provided `ChimewayAdmin.Auth.authorize/3`; production must fail closed without host policy. [VERIFIED: codebase grep] |
| V3 Session Management | yes | Host Phoenix browser pipeline provides session; admin package reads `current_actor` and tenant context from socket/session. [VERIFIED: codebase grep] |
| V4 Access Control | yes | Per-action auth atoms include search, view, feed, definitions, health, list recovery, recover delivery, and recover event. [VERIFIED: codebase grep] |
| V5 Input Validation | yes | Browser smoke should avoid raw arbitrary domain assertions; existing ExUnit tests cover forms and DTO boundaries. [VERIFIED: codebase grep] |
| V6 Cryptography | no direct new crypto | Do not add crypto; rely on Phoenix session/CSRF defaults in browser pipeline. [VERIFIED: codebase grep] |

### Known Threat Patterns for Elixir/Phoenix Admin Docs + Smoke

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Docs encourage permissive production admin auth | Elevation of privilege | Guide must document host auth and fail-closed production setup. [VERIFIED: 72-CONTEXT.md] |
| Raw payload/provider/session secrets leak into docs or admin HTML | Information disclosure | Contract redaction claims and keep existing privacy leak tests in `verify.admin`. [VERIFIED: codebase grep] |
| Tenant context omitted from integration guide | Information disclosure / Tampering | Document tenant/session context expectations and host-owned authorization. [VERIFIED: 72-CONTEXT.md] |
| Recovery permission language too broad | Tampering | Lock per-resource recovery authorization language in doc contracts. [VERIFIED: 72-CONTEXT.md] |
| Browser smoke runs unauthenticated against a permissive prod-like host | Spoofing / Elevation of privilege | Demo auth is dev/test permissive and prod deny-all; docs must tell adopters to replace it. [VERIFIED: codebase grep] |

## Sources

### Primary (HIGH confidence)
- `AGENTS.md` - project stack, quality gates, security/doc constraints. [VERIFIED: codebase grep]
- `.planning/phases/72-admin-docs-and-verification-gate/72-CONTEXT.md` - locked decisions D-01 through D-13. [VERIFIED: codebase grep]
- `.planning/REQUIREMENTS.md` - DOCS-12, GATE-08, SMOKE-01. [VERIFIED: codebase grep]
- `.planning/STATE.md` - prior verification-gate and Playwright/LiveViewTest history. [VERIFIED: codebase grep]
- `mix.exs`, `.github/workflows/ci.yml`, `test/chimeway/doc_contract_test.exs`, `test/chimeway/release_gate_contract_test.exs` - local alias/docs/CI/contract patterns. [VERIFIED: codebase grep]
- `chimeway_admin/*` and `examples/chimeway_demo_host/*` - admin mount, auth, assets, route prefix, redaction, and existing tests. [VERIFIED: codebase grep]
- npm registry for `@playwright/test` 1.60.0 and package metadata. [VERIFIED: npm registry]
- Hex registry via `mix hex.info` for Phoenix, Phoenix LiveView, ExDoc, and Plug versions. [VERIFIED: Hex registry]

### Secondary (MEDIUM confidence)
- Playwright official browser docs - browser install and Chromium runner behavior. [CITED: https://playwright.dev/docs/browsers]
- Plug official docs for `Plug.Static` static asset serving. [CITED: https://hexdocs.pm/plug/Plug.Static.html]
- ExDoc/Elixir docs for documentation extras conventions. [CITED: https://hexdocs.pm/ex_doc/readme.html]
- Mix docs for aliases and task execution conventions. [CITED: https://hexdocs.pm/mix/Mix.html]

### Tertiary (LOW confidence)
- None used for locked recommendations. [VERIFIED: codebase grep]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - package versions verified via local lock/Hex/npm and phase decisions. [VERIFIED: npm registry] [VERIFIED: Hex registry]
- Architecture: HIGH - follows existing repo alias, CI, docs, and package patterns. [VERIFIED: codebase grep]
- Pitfalls: MEDIUM - most drift/security pitfalls are verified locally; Playwright startup flake guidance is based on implementation experience. [VERIFIED: codebase grep] [ASSUMED]

**Research date:** 2026-06-04  
**Valid until:** 2026-07-04 for Elixir/Phoenix docs patterns; re-check Playwright/npm metadata within 7 days before implementation because the package modified on 2026-06-04. [VERIFIED: npm registry]

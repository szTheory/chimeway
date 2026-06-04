# Phase 68: Admin Truth Alignment - Research

**Researched:** 2026-06-04
**Domain:** Phoenix LiveView embedded admin IA, docs truth alignment, route/nav/doc-contract verification
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
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

### Deferred Ideas (OUT OF SCOPE)
None - analysis stayed within phase scope.

### Reviewed Todos (not folded)

None.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ADMIN-01 | Operator can land on `/admin/chimeway` and immediately choose the right path for health, trace investigation, recipient feed debugging, definitions, or recovery. | The shipped dashboard title is "Command Center", its headline CTA is "Open Trace Lookup", and it links to Health, Recovery, and Definitions. [VERIFIED: chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex] |
| ADMIN-02 | Operator can move through command center, traces, detail, feed, definitions, health, and recovery screens with consistent navigation, labels, and page hierarchy. | The router mounts `/`, `/traces`, `/deliveries/:delivery_id`, `/feed`, `/definitions`, `/health`, and `/recovery`; the shared layout labels the sidebar Command Center, Trace Lookup, Feed Debug, Definitions, Health, and Recovery. [VERIFIED: chimeway_admin/lib/chimeway_admin/router.ex] [VERIFIED: chimeway_admin/lib/chimeway_admin/components/layout.ex] |
| ADMIN-03 | Operator-facing docs and demo copy accurately describe the current admin pages and no longer overclaim or mark shipped pages as out of scope. | The demo README still says health aggregates dashboard and notification definitions registry are not included and that the admin is trace lookup only. [VERIFIED: examples/chimeway_demo_host/README.md] |
</phase_requirements>

## Summary

Phase 68 should be planned as a narrow truth-alignment phase: update stale admin/demo wording, assert the real route/nav hierarchy, and add doc-contract coverage that prevents "trace lookup only" language from returning. [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md] The implementation should not introduce new packages, browser smoke infrastructure, design-system work, recovery safety hardening, or a new `mix verify.admin` gate. [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md]

The current `chimeway_admin` package already ships the operator console pages needed by ADMIN-01 and ADMIN-02: Command Center, Trace Lookup, Trace Detail, Feed Debug, Definitions, Health, and Recovery. [VERIFIED: chimeway_admin/lib/chimeway_admin/router.ex] [VERIFIED: chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex] [VERIFIED: chimeway_admin/lib/chimeway_admin/live/feed_live.ex] [VERIFIED: chimeway_admin/lib/chimeway_admin/live/definitions_live.ex] [VERIFIED: chimeway_admin/lib/chimeway_admin/live/health_live.ex] [VERIFIED: chimeway_admin/lib/chimeway_admin/live/recovery_live.ex] The largest confirmed mismatch is README copy that still describes those shipped pages as out of scope. [VERIFIED: examples/chimeway_demo_host/README.md]

**Primary recommendation:** Plan one docs slice and one lightweight test slice: rewrite demo/admin copy around the seven-page route map, then lock route labels, page mounts, and stale forbidden phrases with ExUnit/doc-contract tests. [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md] [VERIFIED: test/chimeway/doc_contract_test.exs]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Admin route map | Frontend Server (Phoenix Router/LiveView) | Browser / Client | `ChimewayAdmin.Router.chimeway_admin_routes/1` defines host-mounted LiveView routes; the browser consumes rendered navigation. [VERIFIED: chimeway_admin/lib/chimeway_admin/router.ex] |
| Command-center landing clarity | Frontend Server (LiveView) | API / Backend | `DashboardLive` owns page copy and links; `Chimeway.admin_command_center/1` supplies DTO facts. [VERIFIED: chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex] [VERIFIED: lib/chimeway/admin.ex] |
| Navigation labels and hierarchy | Frontend Server (shared component) | Browser / Client | `ChimewayAdmin.Components.Layout.admin_shell/1` centralizes sidebar labels and active states. [VERIFIED: chimeway_admin/lib/chimeway_admin/components/layout.ex] |
| Demo/admin copy truth | Docs | Frontend Server | README wording must describe the shipped console and avoid stale out-of-scope claims. [VERIFIED: examples/chimeway_demo_host/README.md] |
| Verification contracts | Test suite | CI | Existing ExUnit, LiveViewTest, and doc-contract patterns already cover route helpers, mounted pages, journey admin traces, and docs gates. [VERIFIED: chimeway_admin/test/chimeway_admin/routes_test.exs] [VERIFIED: chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs] [VERIFIED: examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs] [VERIFIED: test/chimeway/doc_contract_test.exs] |

## Project Constraints (from AGENTS.md)

- Chimeway is an open-source embedded notification layer for Elixir and Phoenix apps. [VERIFIED: AGENTS.md]
- Host applications own their data, policies, and delivery history. [VERIFIED: AGENTS.md]
- Every notification decision must be explainable. [VERIFIED: AGENTS.md]
- Use Elixir 1.17+ / OTP 26+, Ecto 3.x + PostgreSQL 15+, Phoenix 1.7/1.8 optional integration surfaces, Oban 2.x optional async dispatch, and Swoosh 1.x email adapter seams. [VERIFIED: AGENTS.md]
- Persist stable `notification_key` plus version, not module names as durable identity. [VERIFIED: AGENTS.md]
- Keep the durable lifecycle spine as event -> notification -> delivery -> attempt. [VERIFIED: AGENTS.md]
- Treat idempotency and suppression reasons as first-class product behavior. [VERIFIED: AGENTS.md]
- Keep adapters replaceable with explicit behaviours and contract tests. [VERIFIED: AGENTS.md]
- Preserve host ownership boundaries for auth, tenancy, URL generation, and correlation IDs. [VERIFIED: AGENTS.md]
- Maintain `mix verify.*` and `mix ci.*` entrypoints with CI/local parity. [VERIFIED: AGENTS.md]
- Avoid leaking sensitive payload fields in telemetry and operator surfaces. [VERIFIED: AGENTS.md]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir / Mix | 1.19.5 local; project requires `~> 1.17` | Runtime and test runner | Existing project and packages are Mix projects using ExUnit. [VERIFIED: mix.exs] [VERIFIED: command: elixir --version] |
| Phoenix | 1.8.7 locked locally; `chimeway_admin` declares `~> 1.7` | Host router and LiveView integration | Existing admin package and demo host use Phoenix router scopes and LiveView routes. [VERIFIED: chimeway_admin/mix.exs] [VERIFIED: chimeway_admin/mix.lock] |
| Phoenix LiveView | 1.1.30 in `chimeway_admin`; `~> 1.0` declared | Admin pages and LiveViewTest coverage | All admin pages are LiveViews and tests use `Phoenix.LiveViewTest`. [VERIFIED: chimeway_admin/mix.exs] [VERIFIED: chimeway_admin/mix.lock] [VERIFIED: chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs] |
| ExUnit | 1.19.5 local | Route, LiveView, demo, and doc-contract tests | Existing route and doc-contract tests are ExUnit modules. [VERIFIED: command: mix --version] [VERIFIED: chimeway_admin/test/chimeway_admin/routes_test.exs] [VERIFIED: test/chimeway/doc_contract_test.exs] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Ecto SQL | 3.14.0 in `chimeway_admin`; 3.13.5 root lock | Admin DTO queries and DB-backed demo/admin tests | Use existing `Chimeway.Admin` DTO APIs; do not expose schemas to UI copy/tests. [VERIFIED: chimeway_admin/mix.lock] [VERIFIED: mix.lock] [VERIFIED: lib/chimeway/admin.ex] |
| Postgrex/PostgreSQL | Postgrex 0.22.2 locked; local server 14.17, project target 15+ | DB-backed admin read-model and demo tests | Needed for demo-host route tests that seed and query Chimeway data. [VERIFIED: mix.lock] [VERIFIED: command: psql show server_version] [VERIFIED: examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Existing ExUnit + LiveViewTest | Browser smoke / Playwright | Browser smoke is explicitly Phase 72 scope, so Phase 68 should stay on route/nav/mounted-page/doc-contract tests. [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md] |
| Existing docs contract tests | New docs tooling | `test/chimeway/doc_contract_test.exs` already contains required/forbidden string patterns for guide drift. [VERIFIED: test/chimeway/doc_contract_test.exs] |

**Installation:** No new external packages should be installed for Phase 68. [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md]

## Package Legitimacy Audit

No external packages are recommended for installation in this phase. [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md]

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| none | — | — | — | — | not run | No install needed |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```text
Host browser request
  -> DemoHostWeb.Router scope "/admin/chimeway"
  -> ChimewayAdmin.Router.chimeway_admin_routes/1
  -> LiveView page selection
       "/"                    -> DashboardLive / Command Center
       "/traces"              -> TraceSearchLive / Trace Lookup
       "/deliveries/:id"      -> TraceDetailLive / Trace Detail
       "/feed"                -> FeedLive / Feed Debug
       "/definitions"         -> DefinitionsLive / DB-inferred definitions
       "/health"              -> HealthLive / lifecycle health
       "/recovery"            -> RecoveryLive / eligible recovery queue
  -> Shared Layout.admin_shell sidebar labels
  -> Core Chimeway.Admin or Chimeway.Traces DTO/read-model APIs
  -> ExUnit contracts assert route labels, mounted pages, and docs truth
```

This flow matches the mounted route map and shared layout in the current codebase. [VERIFIED: examples/chimeway_demo_host/lib/demo_host_web/router.ex] [VERIFIED: chimeway_admin/lib/chimeway_admin/router.ex] [VERIFIED: chimeway_admin/lib/chimeway_admin/components/layout.ex]

### Recommended Project Structure

```text
chimeway_admin/
├── lib/chimeway_admin/router.ex                  # Mountable LiveView route macro
├── lib/chimeway_admin/routes.ex                  # Prefix-aware route helpers
├── lib/chimeway_admin/components/layout.ex       # Shared admin sidebar/page shell
├── lib/chimeway_admin/live/*.ex                  # Admin page modules
└── test/chimeway_admin/**/*_test.exs             # Route and mounted-page contracts

examples/chimeway_demo_host/
├── README.md                                     # Demo/admin truth copy target
├── lib/demo_host_web/router.ex                   # Real host mount proof
└── test/demo_host_web/admin_trace_live_test.exs  # DB-backed mounted admin trace proof

test/chimeway/doc_contract_test.exs               # Cross-doc truth contracts
```

This structure is already present. [VERIFIED: rg --files]

### Pattern 1: Route Helper Contract

**What:** Assert every prefix-aware helper generated by `ChimewayAdmin.Routes` returns the real mounted path. [VERIFIED: chimeway_admin/test/chimeway_admin/routes_test.exs]

**When to use:** Use when labels or docs reference route paths; it prevents drift between route map and docs. [VERIFIED: chimeway_admin/lib/chimeway_admin/routes.ex]

**Example:**

```elixir
Application.put_env(:chimeway_admin, :path_prefix, "/admin/chimeway")

assert Routes.search_path() == "/admin/chimeway/"
assert Routes.traces_path() == "/admin/chimeway/traces"
assert Routes.feed_path() == "/admin/chimeway/feed"
assert Routes.definitions_path() == "/admin/chimeway/definitions"
assert Routes.health_path() == "/admin/chimeway/health"
assert Routes.recovery_path() == "/admin/chimeway/recovery"
assert Routes.delivery_path("abc") == "/admin/chimeway/deliveries/abc"
```

Source: `chimeway_admin/test/chimeway_admin/routes_test.exs`. [VERIFIED: chimeway_admin/test/chimeway_admin/routes_test.exs]

### Pattern 2: Mounted Page Contract

**What:** Use `live_isolated/3` with the matching `LiveAuth` action to assert page titles and core labels render. [VERIFIED: chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs]

**When to use:** Use for sidebar/page hierarchy truth without starting browser smoke infrastructure. [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md]

**Example:**

```elixir
pages = [
  {ChimewayAdmin.Live.FeedLive, :view_feed, "Feed Debug"},
  {ChimewayAdmin.Live.DefinitionsLive, :view_definitions, "Definitions"},
  {ChimewayAdmin.Live.HealthLive, :view_health, "Health"},
  {ChimewayAdmin.Live.RecoveryLive, :list_recovery_candidates, "Recovery"}
]

for {live_view, action, text} <- pages do
  {:ok, _view, html} =
    live_isolated(conn, live_view,
      session: %{"current_actor" => "ops:1"},
      on_mount: [{ChimewayAdmin.LiveAuth, action}]
    )

  assert html =~ text
end
```

Source: `chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs`. [VERIFIED: chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs]

### Pattern 3: Doc-Contract Required/Forbidden Strings

**What:** Add a focused doc-contract block that reads `examples/chimeway_demo_host/README.md`, requires the seven real pages, and forbids stale claims like "trace lookup only", "health aggregates dashboard ... not included", and "notification definitions registry ... not included". [VERIFIED: examples/chimeway_demo_host/README.md] [VERIFIED: test/chimeway/doc_contract_test.exs]

**When to use:** Use for ADMIN-03 because the failure mode is prose drift, not code behavior. [VERIFIED: .planning/REQUIREMENTS.md]

**Example:**

```elixir
content = File.read!("examples/chimeway_demo_host/README.md")

for required <- ["Command Center", "Trace Lookup", "Trace Detail", "Feed Debug", "Definitions", "Health", "Recovery"] do
  assert String.contains?(content, required)
end

for forbidden <- ["trace lookup only", "health aggregates dashboard", "notification definitions registry"] do
  refute String.contains?(content, forbidden)
end
```

Source pattern: `test/chimeway/doc_contract_test.exs`. [VERIFIED: test/chimeway/doc_contract_test.exs]

### Anti-Patterns to Avoid

- **Hiding shipped pages to make old docs true:** The locked decision is to align docs/navigation around the existing seven-page console. [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md]
- **Calling Definitions a code registry or skew detector:** `Chimeway.Admin.definitions/1` groups persisted event/delivery rows and its doc says code-defined registry/skew detection can be layered later. [VERIFIED: lib/chimeway/admin.ex]
- **Calling Feed Debug an end-user inbox surface:** `FeedLive` describes itself as operator lifecycle inspection outside the end-user inbox product surface. [VERIFIED: chimeway_admin/lib/chimeway_admin/live/feed_live.ex]
- **Adding browser smoke or design token audits:** Those are explicitly deferred to later phases. [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md] [VERIFIED: .planning/ROADMAP.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Route/path truth | A duplicate hardcoded route map in docs/tests | `ChimewayAdmin.Router` and `ChimewayAdmin.Routes` assertions | Route macro and helper module are the code source of truth. [VERIFIED: chimeway_admin/lib/chimeway_admin/router.ex] [VERIFIED: chimeway_admin/lib/chimeway_admin/routes.ex] |
| Navigation label truth | Separate label constants unless needed | `Layout.admin_shell/1` assertions | Sidebar labels are centralized in one component. [VERIFIED: chimeway_admin/lib/chimeway_admin/components/layout.ex] |
| Docs drift detection | Manual reviewer memory | Existing ExUnit doc-contract style | Project already uses required/forbidden string contracts for guide drift. [VERIFIED: test/chimeway/doc_contract_test.exs] |
| Admin data shape | Raw Ecto schema rendering | `Chimeway.Admin` DTO read models | Admin module intentionally returns small maps to avoid payload/render/provider leakage. [VERIFIED: lib/chimeway/admin.ex] |

**Key insight:** Phase 68 is not missing admin capability; it is missing alignment between shipped capability, operator IA language, and docs/test contracts. [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md] [VERIFIED: chimeway_admin/lib/chimeway_admin/router.ex] [VERIFIED: examples/chimeway_demo_host/README.md]

## Common Pitfalls

### Pitfall 1: Reintroducing Trace-Only Admin Language

**What goes wrong:** Docs say the admin UI is trace lookup only even though Command Center, Feed Debug, Definitions, Health, and Recovery are shipped. [VERIFIED: examples/chimeway_demo_host/README.md]  
**Why it happens:** The README retained old MVP boundary copy after the route map expanded. [VERIFIED: examples/chimeway_demo_host/README.md]  
**How to avoid:** Replace the stale out-of-scope section with current boundaries: not generic CRUD, not template editing/provider config, not end-user inbox, not cohort analytics, and not arbitrary bulk recovery. [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md]  
**Warning signs:** Phrases like "trace lookup only", "health aggregates dashboard ... not included", or "notification definitions registry ... not included". [VERIFIED: examples/chimeway_demo_host/README.md]

### Pitfall 2: Overclaiming Definitions

**What goes wrong:** Docs imply Definitions detects notifier code registry skew. [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md]  
**Why it happens:** "registry" language can read broader than the implemented DB-inferred view. [VERIFIED: chimeway_admin/lib/chimeway_admin/live/definitions_live.ex] [VERIFIED: lib/chimeway/admin.ex]  
**How to avoid:** Use "durable notification keys inferred from persisted event and delivery rows" or equivalent wording. [VERIFIED: chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex] [VERIFIED: lib/chimeway/admin.ex]  
**Warning signs:** Claims about code scanning, code registry comparison, or skew detection. [VERIFIED: lib/chimeway/admin.ex]

### Pitfall 3: Mixing Phase 68 with Later Hardening Phases

**What goes wrong:** Planning grows into browser smoke, design-system tokens, recovery auth, tenancy, or privacy leak tests. [VERIFIED: .planning/ROADMAP.md]  
**Why it happens:** The admin console is action-bearing, so adjacent safety/design work is tempting. [VERIFIED: .planning/ROADMAP.md]  
**How to avoid:** Keep Phase 68 to docs, IA labels, route map, mounted-page assertions, and doc contracts. [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md]  
**Warning signs:** New Playwright setup, `mix verify.admin`, CSS token work, recovery reauthorization changes, or raw payload leak tests in Phase 68 tasks. [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md]

## Code Examples

Verified patterns from project sources:

### Prefix-Aware Paths

```elixir
def path(suffix) when is_binary(suffix) do
  prefix =
    :chimeway_admin
    |> Application.get_env(:path_prefix, "")
    |> to_string()
    |> String.trim_trailing("/")

  suffix = if String.starts_with?(suffix, "/"), do: suffix, else: "/" <> suffix

  case prefix do
    "" -> suffix
    p -> p <> suffix
  end
end
```

Source: `chimeway_admin/lib/chimeway_admin/routes.ex`. [VERIFIED: chimeway_admin/lib/chimeway_admin/routes.ex]

### Shared Sidebar Labels

```elixir
<.nav_item active={@active == :home} path={Routes.search_path()} label="Command Center" />
<.nav_item active={@active == :traces} path={Routes.traces_path()} label="Trace Lookup" />
<.nav_item active={@active == :feed} path={Routes.feed_path()} label="Feed Debug" />
<.nav_item active={@active == :definitions} path={Routes.definitions_path()} label="Definitions" />
<.nav_item active={@active == :health} path={Routes.health_path()} label="Health" />
<.nav_item active={@active == :recovery} path={Routes.recovery_path()} label="Recovery" />
```

Source: `chimeway_admin/lib/chimeway_admin/components/layout.ex`. [VERIFIED: chimeway_admin/lib/chimeway_admin/components/layout.ex]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Admin MVP described as trace lookup only | Seven-page embedded operator console | Current v1.11 planning treats expanded admin route map as shipped scope. [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md] | Docs and navigation contracts must name all shipped pages. [VERIFIED: .planning/REQUIREMENTS.md] |
| Stale README out-of-scope list includes Health/Definitions-like capabilities | Current boundary excludes generic CRUD, template/provider config, end-user inbox, cohort analytics, and arbitrary bulk recovery | Phase 68 context locks this replacement boundary. [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md] | ADMIN-03 should be validated with doc-contract tests. [VERIFIED: .planning/REQUIREMENTS.md] |
| Route proof only covers helper paths and a few mounted pages | Phase 68 should extend route/nav/mounted-page assertions for the real IA | Phase 68 context locks lightweight route/navigation/page verification. [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md] | Planner should add focused tests, not browser smoke. [VERIFIED: .planning/ROADMAP.md] |

**Deprecated/outdated:**
- "Out of scope for `chimeway_admin` MVP" as currently written in the demo README is outdated because it marks shipped admin pages/capabilities as absent. [VERIFIED: examples/chimeway_demo_host/README.md] [VERIFIED: chimeway_admin/lib/chimeway_admin/router.ex]
- "Trace lookup only" is outdated because the router ships dashboard, feed, definitions, health, and recovery pages in addition to traces/detail. [VERIFIED: examples/chimeway_demo_host/README.md] [VERIFIED: chimeway_admin/lib/chimeway_admin/router.ex]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | No external package documentation lookup is needed because Phase 68 uses existing project stack and no new packages. [ASSUMED] | Standard Stack | Low: planner might still choose to check Phoenix docs, but implementation should use existing local patterns. |

## Open Questions

None requiring user input. The only execution caveat is environment-related: local PostgreSQL reports 14.17 while AGENTS.md calls for PostgreSQL 15+. [VERIFIED: command: psql show server_version] [VERIFIED: AGENTS.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Mix/ExUnit tests | yes | 1.19.5 | — |
| Erlang/OTP | Elixir runtime | yes | 28 | — |
| Mix | Test commands | yes | 1.19.5 | — |
| PostgreSQL server | DB-backed demo/admin tests | yes, wrong project target | 14.17 local; project target 15+ | Use isolated `chimeway_admin` tests and doc-contract tests first; upgrade local DB before treating demo DB failures as code failures. |
| psql | DB version probe | yes | 14.17 client | — |

**Missing dependencies with no fallback:** none found. [VERIFIED: command: elixir --version] [VERIFIED: command: mix --version] [VERIFIED: command: pg_isready] [VERIFIED: command: psql show server_version]

**Missing dependencies with fallback:**
- PostgreSQL 15+ is not the local server version; Phase 68 can still plan doc-contract and isolated LiveView tests, but demo-host DB-backed tests should note the mismatch. [VERIFIED: command: psql show server_version] [VERIFIED: AGENTS.md]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit 1.19.5 with Phoenix LiveViewTest. [VERIFIED: command: mix --version] [VERIFIED: chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs] |
| Config file | Root `mix.exs`, `chimeway_admin/mix.exs`, and demo-host `mix.exs`. [VERIFIED: mix.exs] [VERIFIED: chimeway_admin/mix.exs] [VERIFIED: examples/chimeway_demo_host/mix.exs] |
| Quick run command | `cd chimeway_admin && mix test test/chimeway_admin/routes_test.exs test/chimeway_admin/live/trace_search_live_test.exs` |
| Full suite command | `mix ci.verify_gates && (cd chimeway_admin && mix test) && (cd examples/chimeway_demo_host && mix test test/demo_host_web/admin_trace_live_test.exs)` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ADMIN-01 | `/admin/chimeway` lands on Command Center with Trace Lookup as primary action and secondary paths visible | LiveView unit / host route | `cd chimeway_admin && mix test test/chimeway_admin/live/trace_search_live_test.exs` | yes; extend assertions. [VERIFIED: chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs] |
| ADMIN-02 | Route helpers, mounted pages, nav labels, and page hierarchy match seven-page route map | route + LiveView unit | `cd chimeway_admin && mix test test/chimeway_admin/routes_test.exs test/chimeway_admin/live/trace_search_live_test.exs` | yes; extend assertions. [VERIFIED: chimeway_admin/test/chimeway_admin/routes_test.exs] [VERIFIED: chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs] |
| ADMIN-03 | Demo/admin copy names current pages and forbids stale out-of-scope claims | doc contract | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | yes; add README block. [VERIFIED: test/chimeway/doc_contract_test.exs] |

### Sampling Rate

- **Per task commit:** Run the narrow command for the touched surface: admin package tests for route/nav/page edits, root doc-contract for docs edits. [VERIFIED: chimeway_admin/test/chimeway_admin/routes_test.exs] [VERIFIED: test/chimeway/doc_contract_test.exs]
- **Per wave merge:** `mix ci.verify_gates && (cd chimeway_admin && mix test)`; add demo-host admin trace test if DB version is acceptable. [VERIFIED: mix.exs] [VERIFIED: chimeway_admin/mix.exs]
- **Phase gate:** Full suite command above, with PostgreSQL 14.17 caveat documented if demo-host DB tests fail only due to version mismatch. [VERIFIED: command: psql show server_version] [VERIFIED: AGENTS.md]

### Wave 0 Gaps

- [ ] `test/chimeway/doc_contract_test.exs` needs a focused demo-host README admin truth block for ADMIN-03. [VERIFIED: test/chimeway/doc_contract_test.exs] [VERIFIED: examples/chimeway_demo_host/README.md]
- [ ] `chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs` should assert sidebar labels and dashboard secondary paths, not just page titles. [VERIFIED: chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs]
- [ ] Demo-host route coverage for `/admin/chimeway` and pillar links can be added if planner wants host-mounted proof, using the existing `AdminTraceLiveTest` pattern. [VERIFIED: examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no new auth in Phase 68 | Preserve existing `ChimewayAdmin.LiveAuth` seams; auth hardening is Phase 70. [VERIFIED: .planning/ROADMAP.md] |
| V3 Session Management | no new session behavior | Do not alter host session/live_session behavior in this phase. [VERIFIED: chimeway_admin/lib/chimeway_admin/router.ex] |
| V4 Access Control | no new access-control behavior | Keep existing `on_mount` action boundaries; recovery authorization hardening is Phase 70. [VERIFIED: chimeway_admin/lib/chimeway_admin/router.ex] [VERIFIED: .planning/ROADMAP.md] |
| V5 Input Validation | yes, for tests/docs only | Use existing LiveView forms and route helpers; no new input parser needed. [VERIFIED: chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex] |
| V6 Cryptography | no | No cryptographic change in Phase 68. [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md] |

### Known Threat Patterns for Phoenix LiveView Admin Truth Alignment

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Operator misrouting from stale docs/nav labels | Repudiation / Operational safety | Lock route labels and docs claims with ExUnit assertions. [VERIFIED: chimeway_admin/test/chimeway_admin/routes_test.exs] [VERIFIED: test/chimeway/doc_contract_test.exs] |
| Overclaiming Definitions as code-registry skew detection | Repudiation | Keep DB-inferred wording and forbid skew/registry overclaims unless implemented later. [VERIFIED: lib/chimeway/admin.ex] [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md] |
| Blurring Feed Debug with end-user inbox | Information disclosure / UX confusion | Keep Feed Debug described as operator lifecycle inspection, not the inbox product surface. [VERIFIED: chimeway_admin/lib/chimeway_admin/live/feed_live.ex] [VERIFIED: .planning/phases/68-admin-truth-alignment/68-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/68-admin-truth-alignment/68-CONTEXT.md` - locked phase decisions and scope boundaries.
- `.planning/REQUIREMENTS.md` - ADMIN-01, ADMIN-02, ADMIN-03 requirement text.
- `.planning/ROADMAP.md` - v1.11 phase split and later-phase exclusions.
- `.planning/STATE.md` - milestone position and accumulated project decisions.
- `AGENTS.md` - project constraints, stack, and quality gates.
- `chimeway_admin/lib/chimeway_admin/router.ex` - seven-page route macro.
- `chimeway_admin/lib/chimeway_admin/routes.ex` - prefix-aware helpers.
- `chimeway_admin/lib/chimeway_admin/components/layout.ex` - shared navigation labels.
- `chimeway_admin/lib/chimeway_admin/live/*.ex` - current page titles and page intent.
- `lib/chimeway/admin.ex` - admin-safe DTO read models and definitions/feed/recovery semantics.
- `examples/chimeway_demo_host/README.md` - stale demo/admin copy target.
- `test/chimeway/doc_contract_test.exs` - existing doc-contract pattern.
- `chimeway_admin/test/chimeway_admin/routes_test.exs` and `chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs` - existing admin test patterns.
- `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` - host-mounted admin route test pattern.

### Secondary (MEDIUM confidence)

- Local command probes: `elixir --version`, `mix --version`, `pg_isready`, and `psql -Atqc 'show server_version;'`.

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - existing `mix.exs`/`mix.lock` files and local tool probes define the stack.
- Architecture: HIGH - route, layout, LiveView, and DTO modules directly show the shipped admin console shape.
- Pitfalls: HIGH - stale README copy and phase context identify exact drift points.

**Research date:** 2026-06-04
**Valid until:** 2026-07-04 for this narrow codebase-alignment phase.

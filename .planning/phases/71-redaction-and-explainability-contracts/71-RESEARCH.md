# Phase 71: Redaction and Explainability Contracts - Research

**Researched:** 2026-06-04  
**Domain:** Elixir/Phoenix LiveView admin privacy contracts and operator explainability  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Boundary Strategy

- **D-01:** Keep redaction as a two-layer contract: core `Chimeway.Admin` DTOs expose only stable explainability fields, while `chimeway_admin` LiveViews/components own display masking for recipient identities and timeline details.
- **D-02:** Do not move raw Ecto schemas, payloads, render snapshots/data, provider responses/bodies, session params, auth codes, tokens, secrets, or full PII into admin UI assigns as an implementation shortcut.

### DTO Contract

- **D-03:** Tighten `Chimeway.Admin` DTO tests around explicit allowlists for each admin read model: command center, recent problem deliveries, definitions, feed, recovery candidates, and outcome totals.
- **D-04:** Do not remove `recipient_id` from every DTO by default in Phase 71; preserve it where it is needed for operator filtering, recovery facts, and trace lookup, but require rendered HTML to mask full recipient PII.
- **D-05:** Treat redacted recipient display fields as an acceptable implementation-local improvement if planners find it simplifies testability, but do not make broad public API churn the default.

### Rendered HTML Leak Tests

- **D-06:** Add rendered LiveView HTML leak tests for dashboard, trace detail, feed, recovery, and definitions because those pages render sensitive-adjacent facts.
- **D-07:** Leak fixtures must include raw payloads, notification render assigns, delivery render data, provider responses/bodies, metadata, session/params, tokens, secrets, auth codes, and full recipient PII.
- **D-08:** Rendered tests should assert both absence of raw sensitive values and presence of useful redacted/explainable operator facts, so privacy hardening does not erase explainability.

### Explanation Language

- **D-09:** Centralize operator-facing lifecycle labels in `ChimewayAdmin.Components.Status` or a nearby presenter instead of changing durable core status atoms.
- **D-10:** Distinguish sent, provider accepted, delivered, suppressed, retryable failure, and terminal failure states using existing status, attempt outcome, error class, webhook/workflow facts, and suppression reason data where available.
- **D-11:** Keep lifecycle copy honest when Chimeway only knows provider acceptance or internal success; do not label a notification delivered unless durable feedback proves delivery.

### Definitions Copy

- **D-12:** Keep Definitions as DB-inferred durable notification key/version history.
- **D-13:** Add rendered-copy/tests that prevent code-registry, source-code skew detection, or notifier module discovery claims from appearing unless that capability is actually implemented.

### the agent's Discretion

Downstream agents may choose the narrowest implementation shape that satisfies the decisions above, keeps `chimeway_admin` optional and host-mounted, and follows existing core DTO plus LiveView test patterns.

### Deferred Ideas (OUT OF SCOPE)

None - analysis stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PRIV-01 | Rendered admin HTML does not expose raw payloads, render data, provider bodies, tokens, secrets, auth codes, or full recipient PII. | Rendered leak tests should target Dashboard, Trace Detail, Feed, Recovery, and Definitions LiveViews; existing redaction helpers and LiveViewTest patterns support this. [VERIFIED: `.planning/REQUIREMENTS.md`, `chimeway_admin/lib/chimeway_admin/redaction.ex`, `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs`] |
| PRIV-02 | Admin DTOs expose only stable, explainable fields needed for operator decisions. | `Chimeway.Admin` already returns small maps for command center, recent problems, definitions, feed, recovery candidates, and outcome totals; Phase 71 should add allowlist tests for each map shape. [VERIFIED: `lib/chimeway/admin.ex`, `test/chimeway/admin_test.exs`] |
| EXPL-01 | Trace/detail/status language distinguishes sent, provider accepted, delivered, suppressed, retryable failure, and terminal failure. | Current status badge humanizes raw status values; a presenter near `ChimewayAdmin.Components.Status` should map existing status, last attempt, error class, webhook/workflow facts, and suppression reason into honest operator labels. [VERIFIED: `chimeway_admin/lib/chimeway_admin/components/status.ex`, `lib/chimeway/traces.ex`] |
| EXPL-02 | Definitions screen clearly communicates DB-inferred definition/version history and does not overclaim code-registry skew detection unless implemented. | `Chimeway.Admin.definitions/1` is DB-inferred from events/notifications/deliveries; `DefinitionsLive` currently uses "registry" copy and should be tested against forbidden skew/module-discovery claims. [VERIFIED: `lib/chimeway/admin.ex`, `chimeway_admin/lib/chimeway_admin/live/definitions_live.ex`] |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Chimeway is an open-source embedded notification layer for Elixir/Phoenix apps; host applications own data, policies, and delivery history. [VERIFIED: `AGENTS.md`]
- Every notification decision must be explainable: why it was sent, failed, or suppressed. [VERIFIED: `AGENTS.md`]
- Use Elixir 1.17+ / OTP 26+, Ecto 3.x + PostgreSQL 15+, optional Phoenix 1.7/1.8 integration surfaces, optional Oban 2.x, and Swoosh 1.x email adapter seams. [VERIFIED: `AGENTS.md`]
- Persist stable `notification_key` plus version, never module names as durable identity. [VERIFIED: `AGENTS.md`]
- Keep the durable lifecycle spine: event -> notification -> delivery -> attempt. [VERIFIED: `AGENTS.md`]
- Treat idempotency and suppression reasons as first-class product behavior. [VERIFIED: `AGENTS.md`]
- Keep adapters replaceable with explicit behaviours and contract tests. [VERIFIED: `AGENTS.md`]
- Preserve host ownership boundaries for auth, tenancy, URL generation, and correlation IDs. [VERIFIED: `AGENTS.md`]
- Maintain `mix verify.*` and `mix ci.*` entrypoints and keep CI/local scripts in parity. [VERIFIED: `AGENTS.md`]
- Avoid leaking sensitive payload fields in telemetry and operator surfaces. [VERIFIED: `AGENTS.md`]

## Summary

Phase 71 should be planned as a contract-hardening slice, not as a schema redesign. [VERIFIED: `71-CONTEXT.md`, `lib/chimeway/admin.ex`] The core boundary is already mostly correct: `Chimeway.Admin` returns DTO maps rather than raw Ecto schemas, and `chimeway_admin` owns display redaction. [VERIFIED: `lib/chimeway/admin.ex`, `chimeway_admin/lib/chimeway_admin/redaction.ex`] The highest-leverage work is to turn that implicit design into explicit allowlist and rendered HTML contracts. [VERIFIED: `test/chimeway/admin_test.exs`, `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs`]

The plan should modify tests first, then small presenters/copy. [ASSUMED] DTO allowlist tests belong in `test/chimeway/admin_test.exs`; rendered leak tests belong in `chimeway_admin/test/chimeway_admin/live/*_test.exs`, with shared sensitive fixture helpers if duplication grows. [VERIFIED: `test/chimeway/admin_test.exs`, `chimeway_admin/test/support/live_view_case.ex`] Status/explainability copy should live in `ChimewayAdmin.Components.Status` or a nearby presenter so durable `Delivery.status` atoms remain unchanged. [VERIFIED: `chimeway_admin/lib/chimeway_admin/components/status.ex`, `lib/chimeway/delivery.ex`, `71-CONTEXT.md`]

**Primary recommendation:** Add explicit DTO allowlists and rendered LiveView leak tests first, then introduce a small admin status presenter plus Definitions copy updates without changing durable core atoms or deleting required `recipient_id` DTO fields. [VERIFIED: `71-CONTEXT.md`, `lib/chimeway/admin.ex`, `chimeway_admin/lib/chimeway_admin/components/status.ex`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Admin read-model field allowlists | API / Backend | Database / Storage | `Chimeway.Admin` queries durable rows and returns DTO maps; this tier decides what crosses from core into optional UI packages. [VERIFIED: `lib/chimeway/admin.ex`] |
| Rendered recipient and timeline redaction | Frontend Server (LiveView) | API / Backend | `chimeway_admin` LiveViews/components render server HTML and already call `Redaction.redact_recipient/1` and `safe_timeline_detail/1`. [VERIFIED: `chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex`, `chimeway_admin/lib/chimeway_admin/components/timeline_event.ex`] |
| Lifecycle/operator labels | Frontend Server (LiveView) | API / Backend | The UI should translate durable facts into honest operator labels while preserving core status atoms. [VERIFIED: `chimeway_admin/lib/chimeway_admin/components/status.ex`, `lib/chimeway/delivery.ex`, `71-CONTEXT.md`] |
| Definitions history copy | Frontend Server (LiveView) | API / Backend | `Admin.definitions/1` supplies DB-inferred facts; `DefinitionsLive` owns how those facts are described to operators. [VERIFIED: `lib/chimeway/admin.ex`, `chimeway_admin/lib/chimeway_admin/live/definitions_live.ex`] |
| Sensitive fixture construction | Test tier | Database / Storage | Tests must persist sensitive values in payload/render/provider/session-like locations, then prove DTOs/rendered HTML omit them. [VERIFIED: `test/chimeway/admin_test.exs`, `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs`] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir / ExUnit | 1.19.5 available locally; project requires `~> 1.17` | Core test framework and assertions | Existing project tests use ExUnit/DataCase; no new test framework is needed. [VERIFIED: local `elixir --version`, `mix.exs`, `test/chimeway/admin_test.exs`] |
| Ecto SQL | locked root 3.13.5; admin package lock 3.14.0 | Query and persist durable event/notification/delivery/attempt rows | `Chimeway.Admin` and tests already use Ecto query and sandbox patterns. [VERIFIED: `mix.lock`, `chimeway_admin/mix.lock`, `lib/chimeway/admin.ex`] |
| Postgrex / PostgreSQL | Postgrex locked 0.22.2; local `psql` 14.17; AGENTS target PostgreSQL 15+ | Test database adapter | Existing tests run against the local Postgres service; AGENTS target remains PostgreSQL 15+. [VERIFIED: `mix.lock`, local `psql --version`, `AGENTS.md`] |
| Phoenix LiveViewTest | root lock 1.1.31; admin lock 1.1.30 | Render LiveViews and simulate events for HTML leak tests | Existing admin tests use `live_isolated/3`, `render_click/1`, and `render_submit/1`; official docs describe `live_isolated` as spawning a connected isolated LiveView. [VERIFIED: `chimeway_admin/mix.lock`, `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs`; CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] |
| Floki | locked 0.38.3 | Parse rendered HTML for structural assertions | Existing admin LiveView tests parse rendered HTML with Floki for CSS hook checks. [VERIFIED: `chimeway_admin/mix.lock`, `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs`] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `lazy_html` | admin lock 0.1.11 | LiveView test HTML support dependency | Keep as existing dependency; do not add or change for this phase. [VERIFIED: `chimeway_admin/mix.lock`, `chimeway_admin/mix.exs`] |
| Oban | locked 2.23.0 | Optional async dispatch dependency | Not directly needed for Phase 71 unless existing fixtures require compiled admin package dependencies. [VERIFIED: `mix.lock`, `chimeway_admin/mix.exs`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| LiveView rendered tests | Browser smoke / Playwright | Phase 72 owns browser smoke and verify-gate composition; Phase 71 can prove privacy contracts with LiveViewTest faster and closer to existing patterns. [VERIFIED: `.planning/ROADMAP.md`, `71-CONTEXT.md`, `chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs`] |
| Small status presenter | Core status atom changes | Durable atom churn risks migrations and lifecycle semantics; presenter copy is reversible and constrained to admin display. [VERIFIED: `lib/chimeway/delivery.ex`, `71-CONTEXT.md`] |
| Removing `recipient_id` from all DTOs | Render-time masking | Locked decision D-04 preserves `recipient_id` where needed; rendered HTML masking satisfies privacy without breaking trace/feed/recovery lookup. [VERIFIED: `71-CONTEXT.md`, `lib/chimeway/admin.ex`] |

**Installation:** No new packages should be installed for Phase 71. [VERIFIED: `mix.exs`, `chimeway_admin/mix.exs`, `71-CONTEXT.md`]

**Version verification:** Existing versions were verified from `mix.lock`, `chimeway_admin/mix.lock`, and `mix hex.info` output during this session. [VERIFIED: local command output]

## Package Legitimacy Audit

Phase 71 should not install external packages, so the Package Legitimacy Gate is not applicable. [VERIFIED: `71-CONTEXT.md`, `mix.exs`, `chimeway_admin/mix.exs`] Existing packages remain part of the current project stack. [VERIFIED: `mix.lock`, `chimeway_admin/mix.lock`]

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| none | — | — | — | — | not run | No install planned. [VERIFIED: `71-CONTEXT.md`] |

**Packages removed due to slopcheck [SLOP] verdict:** none. [VERIFIED: no new package recommendations]  
**Packages flagged as suspicious [SUS]:** none. [VERIFIED: no new package recommendations]

## Architecture Patterns

### System Architecture Diagram

```text
Durable DB rows
  events(payload, key, version, correlation)
  notifications(recipient_identity, render_assigns, render_channels)
  deliveries(status, render_data, metadata, reasons)
  attempts(provider_response, outcome, error_class)
        |
        v
Core read APIs
  Chimeway.Admin.* DTOs
  Chimeway.Traces.explain_delivery/2
        |
        | allowlisted stable facts only for Admin DTOs
        | explanation structs for trace detail
        v
chimeway_admin LiveViews
  Dashboard / TraceSearch / TraceDetail / Feed / Definitions / Recovery
        |
        | Redaction.redact_recipient/1
        | Redaction.safe_timeline_detail/1
        | Status presenter labels
        v
Rendered HTML contract
  Useful operator facts present
  Raw payload/render/provider/session/token/secret/auth-code/full-PII absent
```

### Recommended Project Structure

```text
lib/chimeway/
├── admin.ex                         # Core DTO query/allowlist boundary. [VERIFIED: repo]
├── traces.ex                        # Trace explanation facts. [VERIFIED: repo]
└── delivery.ex                      # Durable status atoms; do not churn. [VERIFIED: repo]

chimeway_admin/lib/chimeway_admin/
├── redaction.ex                     # View-layer masking and timeline detail allowlist. [VERIFIED: repo]
├── components/status.ex             # Existing shared status badge; add presenter nearby. [VERIFIED: repo]
├── components/timeline_event.ex     # Timeline detail rendering via redaction. [VERIFIED: repo]
└── live/*_live.ex                   # Rendered privacy/copy surfaces. [VERIFIED: repo]

test/chimeway/
└── admin_test.exs                   # DTO field allowlist contracts. [VERIFIED: repo]

chimeway_admin/test/chimeway_admin/live/
├── trace_search_live_test.exs       # Dashboard/pillar mounting pattern; add rendered leak tests or split file. [VERIFIED: repo]
├── recovery_live_test.exs           # Existing session-secret leak pattern. [VERIFIED: repo]
└── redaction/explainability tests   # Add if clearer; keep inside package test tree. [ASSUMED]
```

### Pattern 1: DTO Allowlist Contracts

**What:** Assert exact keys for every DTO map and recursively reject forbidden sensitive keys. [VERIFIED: `test/chimeway/admin_test.exs`, `lib/chimeway/admin.ex`]  
**When to use:** For `Admin.command_center/1`, `recent_problem_deliveries/1`, `definitions/1`, `feed/1`, `recovery_candidates/1`, and `outcome_totals/1`. [VERIFIED: `lib/chimeway/admin.ex`]  
**Example:**

```elixir
# Source: test/chimeway/admin_test.exs and lib/chimeway/admin.ex [VERIFIED]
allowed_problem_keys = MapSet.new([
  :delivery_id, :event_id, :notification_key, :notification_version,
  :recipient_id, :channel, :status, :suppression_reason, :planning_reason,
  :tenant_id, :correlation_id, :inserted_at, :updated_at
])

assert MapSet.new(Map.keys(problem)) == allowed_problem_keys
refute inspect(problem) =~ "raw-payload-secret-71"
```

### Pattern 2: Rendered HTML Leak Tests With Positive Utility Assertions

**What:** Seed durable rows containing distinctive sensitive strings, render the LiveView, and assert sensitive strings are absent while masked/explainable facts are present. [VERIFIED: `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs`, `chimeway_admin/lib/chimeway_admin/redaction.ex`]  
**When to use:** Dashboard, trace detail, feed, recovery, and definitions rendered HTML. [VERIFIED: `71-CONTEXT.md`]  
**Example:**

```elixir
# Source: Phoenix.LiveViewTest docs and existing recovery_live_test.exs [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html]
{:ok, view, html} =
  live_isolated(conn, ChimewayAdmin.Live.TraceDetailLive,
    session: %{"current_actor" => "ops:1", "raw_secret" => "session-secret-71"},
    on_mount: [{ChimewayAdmin.LiveAuth, :search_traces}],
    params: %{"delivery_id" => delivery.id}
  )

html = render(view)
refute html =~ "raw-payload-secret-71"
refute html =~ "render-data-secret-71"
refute html =~ "Bearer token-71"
assert html =~ "user:***"
assert html =~ "Notification key"
```

### Pattern 3: Presenter Labels Over Durable State Churn

**What:** Add a display-only function that accepts existing delivery/explanation facts and returns label/tone semantics. [VERIFIED: `chimeway_admin/lib/chimeway_admin/components/status.ex`, `lib/chimeway/traces.ex`, `lib/chimeway/delivery.ex`]  
**When to use:** Trace detail current state, last attempt, timeline summaries, dashboard/health status badges where raw `succeeded` or `dispatched` copy is ambiguous. [VERIFIED: `chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex`, `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex`, `chimeway_admin/lib/chimeway_admin/live/health_live.ex`]  
**Example:**

```elixir
# Source: recommended local pattern based on Status.status_badge/1 [VERIFIED: chimeway_admin/lib/chimeway_admin/components/status.ex]
def lifecycle_label(%{status: :succeeded, last_attempt: %{outcome: :succeeded}}),
  do: %{status: :succeeded, label: "Provider accepted", tone: :success}

def lifecycle_label(%{status: :cancelled, suppression_reason: "retries_exhausted"}),
  do: %{status: :cancelled, label: "Terminal failure", tone: :danger}
```

### Anti-Patterns to Avoid

- **Raw schema assigns:** Passing `%Event{}`, `%Notification{}`, `%Delivery{}`, or `%DeliveryAttempt{}` into admin LiveViews can expose payload/render/provider fields. [VERIFIED: `lib/chimeway/admin.ex`, `lib/chimeway/delivery.ex`, `lib/chimeway/delivery_attempt.ex`]
- **Broad DTO field deletion:** Removing `recipient_id` everywhere conflicts with D-04 and may break operator filtering/recovery/trace lookup. [VERIFIED: `71-CONTEXT.md`, `lib/chimeway/admin.ex`]
- **Calling provider acceptance "delivered":** Chimeway can mark an internal send/provider acceptance from attempts, but delivered copy requires durable feedback evidence. [VERIFIED: `71-CONTEXT.md`, `lib/chimeway/traces.ex`]
- **Definitions as source registry:** `definitions/1` groups persisted DB rows; copy should not claim code registry, source skew, notifier discovery, or module inventory. [VERIFIED: `lib/chimeway/admin.ex`, `chimeway_admin/lib/chimeway_admin/live/definitions_live.ex`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTML rendering tests | Browser automation for this phase | Phoenix LiveViewTest `live_isolated`, `render`, `render_click`, `render_submit` | Existing tests already use LiveViewTest; official docs support isolated LiveView testing; browser smoke is Phase 72 scope. [VERIFIED: `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs`; CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] |
| HTML parsing | Regex-only structural checks | Floki for structural selectors, string checks for distinctive leaks | Existing tests use Floki for CSS hooks; raw distinctive-value absence checks can remain string assertions. [VERIFIED: `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs`] |
| Status ontology | New durable status atoms | Display presenter mapping existing facts | Core statuses are persisted Ecto enum values; changing them creates broad lifecycle risk. [VERIFIED: `lib/chimeway/delivery.ex`] |
| Sensitive timeline filtering | Custom filters in each component | `ChimewayAdmin.Redaction.safe_timeline_detail/1` | A centralized allowlist already exists for timeline details. [VERIFIED: `chimeway_admin/lib/chimeway_admin/redaction.ex`, `chimeway_admin/lib/chimeway_admin/components/timeline_event.ex`] |

**Key insight:** This phase should prove boundaries with explicit tests; the implementation should be small because most architecture already exists. [VERIFIED: `71-CONTEXT.md`, `lib/chimeway/admin.ex`, `chimeway_admin/lib/chimeway_admin/redaction.ex`]

## Common Pitfalls

### Pitfall 1: DTO Tests Only Check A Few Forbidden Keys

**What goes wrong:** A future map gains `:metadata`, `:provider_body`, `:session`, or `:params` and passes because tests only refute `:payload`, `:render_data`, and `:provider_response`. [VERIFIED: `test/chimeway/admin_test.exs`]  
**Why it happens:** Current admin test checks a narrow forbidden set for one read model. [VERIFIED: `test/chimeway/admin_test.exs`]  
**How to avoid:** Use exact key allowlists for every DTO and a shared recursive forbidden-key/value assertion. [ASSUMED]  
**Warning signs:** New `select` fields in `Chimeway.Admin` without matching tests. [VERIFIED: `lib/chimeway/admin.ex`]

### Pitfall 2: Rendered HTML Tests Miss Values Stored Outside Payload

**What goes wrong:** Tests seed payload secrets but not notification `render_assigns`, delivery `render_data`, delivery `metadata`, attempt `provider_response`, or LiveView session/params. [VERIFIED: `test/chimeway/admin_test.exs`, `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs`]  
**Why it happens:** Sensitive values enter through multiple durable and runtime paths. [VERIFIED: `lib/chimeway/delivery.ex`, `lib/chimeway/delivery_attempt.ex`, `lib/chimeway/traces.ex`]  
**How to avoid:** Use a single high-signal fixture value matrix: `raw-payload-secret-71`, `render-assign-secret-71`, `render-data-secret-71`, `provider-body-secret-71`, `metadata-secret-71`, `session-secret-71`, `params-auth-code-71`, `bearer-token-71`, `api-key-secret-71`, `alex.full-pii@example.test`, and `+15551234567`. [ASSUMED]  
**Warning signs:** A test only asserts no `"secret"` substring but does not seed unique raw values in every risky storage location. [ASSUMED]

### Pitfall 3: Status Labels Overclaim Delivery

**What goes wrong:** UI labels `:succeeded` as "Delivered" even when only adapter success/provider acceptance is known. [VERIFIED: `71-CONTEXT.md`, `lib/chimeway/traces.ex`]  
**Why it happens:** Current `status_badge/1` humanizes raw statuses and lacks lifecycle context. [VERIFIED: `chimeway_admin/lib/chimeway_admin/components/status.ex`]  
**How to avoid:** Add presenter tests for at least provider accepted, delivered-with-feedback, suppressed, retryable failure, and terminal failure. [ASSUMED]  
**Warning signs:** Display code calls `String.capitalize(to_string(status))` for operator explanations. [VERIFIED: `chimeway_admin/lib/chimeway_admin/components/status.ex`]

### Pitfall 4: Definitions Copy Revives Registry/Skew Claims

**What goes wrong:** Operators think Definitions compares DB history to source code/notifier modules. [VERIFIED: `71-CONTEXT.md`]  
**Why it happens:** `DefinitionsLive` currently uses "registry" in module/copy even though `Admin.definitions/1` is DB-inferred. [VERIFIED: `chimeway_admin/lib/chimeway_admin/live/definitions_live.ex`, `lib/chimeway/admin.ex`]  
**How to avoid:** Require positive rendered copy like "inferred from persisted events and deliveries" and forbid "registry", "skew", "code-registry", "module discovery", and "source-code" in rendered Definitions HTML. [ASSUMED]  
**Warning signs:** Copy mentions notifier module inventory or source-code mismatch. [VERIFIED: `71-CONTEXT.md`]

## Code Examples

### Existing Redaction Boundary

```elixir
# Source: chimeway_admin/lib/chimeway_admin/redaction.ex [VERIFIED]
@allowed_detail_keys ~w(
  reason outcome event_name step_key adapter adapter_module status notification_key channel
  workflow_step_key workflow_outcome from_step to_step rule_identity
)

@sensitive_key ~r/(password|token|secret|api_key|auth)/i
```

### Existing Trace Detail Rendering Pattern

```elixir
# Source: chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex [VERIFIED]
<dt>Recipient</dt>
<dd>{Redaction.redact_recipient(@explanation.recipient_id)}</dd>
<dt>Render identity</dt>
<dd>{render_identity(@explanation)}</dd>
```

### Existing LiveViewTest Pattern

```elixir
# Source: chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs [VERIFIED]
{:ok, view, html} =
  live_isolated(conn, ChimewayAdmin.Live.RecoveryLive,
    session: %{"current_actor" => "ops:1", "chimeway_admin_tenant_id" => tenant_id},
    on_mount: [{ChimewayAdmin.LiveAuth, :list_recovery_candidates}]
  )

html =
  view
  |> element("button[phx-value-id=\"#{delivery.id}\"]")
  |> render_click()
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Admin pages as trace lookup only | Multi-page command center, trace, feed, definitions, health, and recovery console | Phase 68 / v1.11 context | Phase 71 must cover all sensitive-adjacent pages, not only trace search. [VERIFIED: `.planning/ROADMAP.md`, `71-CONTEXT.md`] |
| Generic status humanization | Presenter-level lifecycle language | Phase 71 target | Keeps durable atoms stable while improving operator explanation quality. [VERIFIED: `chimeway_admin/lib/chimeway_admin/components/status.ex`, `71-CONTEXT.md`] |
| Definitions as registry/skew copy | DB-inferred durable key/version history | Phase 68/71 decisions | Prevents overclaiming unimplemented source-code comparison. [VERIFIED: `71-CONTEXT.md`, `lib/chimeway/admin.ex`] |

**Deprecated/outdated:**
- "notification definitions registry" / "skew detection" / "code-registry" admin copy is forbidden in related doc-contract tests and conflicts with Phase 71 Definitions decisions. [VERIFIED: `test/chimeway/doc_contract_test.exs`, `71-CONTEXT.md`]
- Raw status labels alone are insufficient for EXPL-01 because they cannot distinguish provider acceptance from externally delivered feedback. [VERIFIED: `chimeway_admin/lib/chimeway_admin/components/status.ex`, `71-CONTEXT.md`]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Tests should be added first, then presenters/copy, because this is contract hardening. | Summary | Low; implementation order could vary, but planning around tests improves acceptance clarity. |
| A2 | A new test module/file may be created if shared leak fixtures make existing test files too crowded. | Recommended Project Structure | Low; exact file split is implementation-local. |
| A3 | Exact sensitive fixture strings listed here are recommended but not mandatory. | Common Pitfalls | Low; any distinctive unique strings covering the same storage locations satisfy the requirement. |
| A4 | Definitions rendered copy should forbid "registry" broadly in the rendered page. | Common Pitfalls | Medium; the module doc may keep "registry" internally, but UI copy should avoid it for EXPL-02. |

## Open Questions

1. **Should `Chimeway.Traces.Explanation` become a DTO boundary too?**
   - What we know: Trace detail currently receives an explanation struct with `recipient_id`, status, last attempt summary, and timeline facts, then redacts during rendering. [VERIFIED: `chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex`, `lib/chimeway/traces.ex`]
   - What's unclear: Whether planners want to introduce a trace-detail UI DTO or keep render-time redaction only. [ASSUMED]
   - Recommendation: Keep render-time redaction in Phase 71 unless tests show raw values entering assigns that are hard to police. [ASSUMED]

2. **What durable evidence qualifies as "delivered"?**
   - What we know: Existing traces can project webhook and workflow facts such as `:webhook_received` and workflow outcomes, while D-11 says not to label delivered without durable feedback. [VERIFIED: `lib/chimeway/traces.ex`, `71-CONTEXT.md`]
   - What's unclear: The exact provider feedback rows/events that should trigger "Delivered" copy across all adapters. [ASSUMED]
   - Recommendation: In Phase 71, label `:succeeded` attempt success as "Provider accepted" and reserve "Delivered" for explicit durable feedback facts already present in timeline/workflow data; otherwise do not introduce broad adapter semantics. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | Mix/ExUnit tests | yes | 1.19.5 locally | Project supports `~> 1.17`; no fallback needed. [VERIFIED: local command, `mix.exs`] |
| Erlang/OTP | Elixir runtime | yes | OTP 28 locally | AGENTS target OTP 26+; no fallback needed. [VERIFIED: local command, `AGENTS.md`] |
| Mix | Test commands | yes | 1.19.5 locally | none. [VERIFIED: local command] |
| PostgreSQL server | Ecto sandbox tests | yes | local `pg_isready` accepting `/tmp:5432`; `psql` 14.17 | AGENTS target PostgreSQL 15+; local existing tests pass on this machine. [VERIFIED: local command, `AGENTS.md`] |
| Context7 CLI/MCP | Documentation lookup | no | `ctx7 not found`; no MCP resources exposed | Used HexDocs/WebSearch official docs fallback. [VERIFIED: local command; CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] |

**Missing dependencies with no fallback:** none for planning and existing targeted tests. [VERIFIED: local commands]  
**Missing dependencies with fallback:** Context7 unavailable; official HexDocs fallback used. [VERIFIED: local command; CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with Ecto SQL Sandbox and Phoenix LiveViewTest. [VERIFIED: `test/support/data_case.ex`, `chimeway_admin/test/support/live_view_case.ex`, `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs`] |
| Config file | Root `mix.exs`; admin package `chimeway_admin/mix.exs`. [VERIFIED: `mix.exs`, `chimeway_admin/mix.exs`] |
| Quick run command | `mix test test/chimeway/admin_test.exs --warnings-as-errors && cd chimeway_admin && mix test test/chimeway_admin/redaction_test.exs test/chimeway_admin/live/trace_search_live_test.exs test/chimeway_admin/live/recovery_live_test.exs --warnings-as-errors` [VERIFIED: local command passed] |
| Full suite command | `mix ci.test && cd chimeway_admin && mix test --warnings-as-errors` [VERIFIED: `mix.exs`, `chimeway_admin/mix.exs`] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| PRIV-01 | Rendered LiveView HTML omits raw payload/render/provider/session/token/secret/auth-code/full-PII values while showing masked useful facts. | LiveView unit/integration | `cd chimeway_admin && mix test test/chimeway_admin/live/trace_search_live_test.exs test/chimeway_admin/live/recovery_live_test.exs --warnings-as-errors` plus new rendered leak tests. [VERIFIED: existing command passed] | Partial; add Wave 0 tests. [VERIFIED: current files] |
| PRIV-02 | Admin DTO maps expose exact stable explainability fields only. | Core unit/integration | `mix test test/chimeway/admin_test.exs --warnings-as-errors` [VERIFIED: command passed] | Partial; expand allowlists. [VERIFIED: current file] |
| EXPL-01 | Labels distinguish provider accepted, delivered, suppressed, retryable failure, and terminal failure without core atom churn. | Component/presenter unit + LiveView render | `cd chimeway_admin && mix test test/chimeway_admin/live/trace_search_live_test.exs --warnings-as-errors` plus new status presenter tests. [VERIFIED: existing command passed] | Missing; add Wave 0 tests. [VERIFIED: current files] |
| EXPL-02 | Definitions copy says DB-inferred persisted history and forbids registry/skew/module-discovery claims. | LiveView render | `cd chimeway_admin && mix test test/chimeway_admin/live/trace_search_live_test.exs --warnings-as-errors` plus new Definitions copy tests. [VERIFIED: existing command passed] | Partial; mount test exists, copy test missing. [VERIFIED: `trace_search_live_test.exs`] |

### Sampling Rate

- **Per task commit:** Run the quick command above. [VERIFIED: local command passed]
- **Per wave merge:** Run `mix test test/chimeway/admin_test.exs test/chimeway/traces_test.exs --warnings-as-errors` and `cd chimeway_admin && mix test --warnings-as-errors`. [VERIFIED: current project layout]
- **Phase gate:** Full suite green before `$gsd-verify-work`; Phase 71 is not one of the docs/release-gate phases that skips UAT. [VERIFIED: `AGENTS.md`, `.planning/ROADMAP.md`]

### Wave 0 Gaps

- [ ] `test/chimeway/admin_test.exs` — add exact allowlist helpers for command center, recent problems, definitions, feed, recovery candidates, and outcome totals. [VERIFIED: current file]
- [ ] `chimeway_admin/test/chimeway_admin/live/*_test.exs` — add rendered leak fixtures for dashboard, trace detail, feed, recovery, and definitions. [VERIFIED: current files]
- [ ] `chimeway_admin/test/chimeway_admin/components/status_test.exs` or nearby presenter test — lock operator labels for provider accepted, delivered, suppressed, retryable failure, and terminal failure. [ASSUMED]
- [ ] `chimeway_admin/test/chimeway_admin/live/definitions_live_test.exs` or existing live test file — lock DB-inferred copy and forbidden skew/registry claims. [ASSUMED]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | yes, indirectly | Existing `ChimewayAdmin.LiveAuth` on_mount/authorization remains the auth boundary; Phase 71 must avoid leaking session auth values in rendered HTML. [VERIFIED: `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs`, `71-CONTEXT.md`] |
| V3 Session Management | yes | Tests should include session secret/auth-code fixtures and assert rendered HTML omission. [VERIFIED: `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs`, `71-CONTEXT.md`] |
| V4 Access Control | yes, indirectly | Tenant/auth boundaries are Phase 70; Phase 71 should not weaken host-mounted auth/tenant context while adding tests. [VERIFIED: `.planning/ROADMAP.md`, `chimeway_admin/lib/chimeway_admin/live/recovery_live.ex`] |
| V5 Input Validation / Output Encoding | yes | Use Phoenix HEEx escaping plus explicit redaction/masking; OWASP ASVS and secure coding guidance treat validation/output encoding as security controls. [VERIFIED: `chimeway_admin/lib/chimeway_admin/redaction.ex`; CITED: https://owasp.org/www-project-application-security-verification-standard/, https://owasp.org/www-project-secure-coding-practices-quick-reference-guide/stable-en/02-checklist/05-checklist] |
| V6 Cryptography | no new crypto | Do not build crypto or token parsing; treat tokens/secrets as opaque strings to omit from rendered surfaces. [VERIFIED: `71-CONTEXT.md`] |
| V9 Data Protection | yes | Rendered HTML and DTO contracts must not expose sensitive payload/provider/session/PII values. [VERIFIED: `.planning/REQUIREMENTS.md`, `71-CONTEXT.md`] |

### Known Threat Patterns for Elixir/Phoenix Admin LiveViews

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Sensitive data disclosure in HTML | Information Disclosure | DTO allowlists plus rendered leak tests for payload/render/provider/session/token/secret/auth-code/full-PII values. [VERIFIED: `.planning/REQUIREMENTS.md`, `71-CONTEXT.md`] |
| Overbroad assigns from raw schemas | Information Disclosure | Keep `Chimeway.Admin` DTOs and avoid raw Ecto schemas in UI assigns. [VERIFIED: `lib/chimeway/admin.ex`, `71-CONTEXT.md`] |
| Misleading lifecycle labels | Repudiation / Integrity | Presenter labels must distinguish provider acceptance from delivered feedback and terminal vs retryable failure. [VERIFIED: `71-CONTEXT.md`, `lib/chimeway/traces.ex`] |
| Source-registry overclaiming | Repudiation | Definitions copy/tests must state DB-inferred history only. [VERIFIED: `71-CONTEXT.md`, `lib/chimeway/admin.ex`] |

## Sources

### Primary (HIGH confidence)

- `AGENTS.md` - project stack, quality gates, privacy/explainability constraints. [VERIFIED: repo]
- `.planning/phases/71-redaction-and-explainability-contracts/71-CONTEXT.md` - locked decisions and canonical refs. [VERIFIED: repo]
- `.planning/REQUIREMENTS.md` - PRIV-01, PRIV-02, EXPL-01, EXPL-02 definitions. [VERIFIED: repo]
- `.planning/ROADMAP.md` - Phase 71 scope and Phase 72 separation. [VERIFIED: repo]
- `.planning/STATE.md` - v1.11 current focus and accumulated decisions. [VERIFIED: repo]
- `lib/chimeway/admin.ex` - DTO map shapes and DB-inferred definitions. [VERIFIED: repo]
- `lib/chimeway/traces.ex` - explanation/timeline/attempt facts. [VERIFIED: repo]
- `lib/chimeway/delivery.ex` and `lib/chimeway/delivery_attempt.ex` - durable status/attempt/provider fields. [VERIFIED: repo]
- `chimeway_admin/lib/chimeway_admin/redaction.ex` - recipient masking and safe timeline detail allowlist. [VERIFIED: repo]
- `chimeway_admin/lib/chimeway_admin/components/status.ex` - current generic status badge. [VERIFIED: repo]
- `chimeway_admin/lib/chimeway_admin/live/*.ex` - rendered admin surfaces. [VERIFIED: repo]
- `test/chimeway/admin_test.exs`, `chimeway_admin/test/chimeway_admin/*_test.exs` - existing test patterns. [VERIFIED: repo]
- Phoenix LiveViewTest official docs - `live_isolated` and rendered LiveView testing. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html]
- OWASP ASVS and Secure Coding Practices - validation/output encoding and security control framing. [CITED: https://owasp.org/www-project-application-security-verification-standard/, https://owasp.org/www-project-secure-coding-practices-quick-reference-guide/stable-en/02-checklist/05-checklist]

### Secondary (MEDIUM confidence)

- `mix hex.info phoenix_live_view`, `mix hex.info phoenix`, `mix hex.info ecto_sql` - current Hex package release context and local lock comparison. [VERIFIED: local command]

### Tertiary (LOW confidence)

- None. [VERIFIED: no unverified web/community sources used]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - existing dependencies and lock versions were inspected; no new packages recommended. [VERIFIED: `mix.lock`, `chimeway_admin/mix.lock`, local command]
- Architecture: HIGH - phase decisions and current code agree on core DTO plus LiveView redaction ownership. [VERIFIED: `71-CONTEXT.md`, `lib/chimeway/admin.ex`, `chimeway_admin/lib/chimeway_admin/redaction.ex`]
- Pitfalls: HIGH - pitfalls come from current missing/narrow tests and explicit phase decisions. [VERIFIED: current tests, `71-CONTEXT.md`]

**Research date:** 2026-06-04  
**Valid until:** 2026-07-04 for codebase-local planning; recheck lock versions if dependency upgrades land before execution. [ASSUMED]

## RESEARCH COMPLETE

Phase 71 research is complete and ready for planning. [VERIFIED: artifact written]

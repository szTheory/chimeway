# Phase 70: Recovery, Auth, and Tenancy Hardening - Research

**Researched:** 2026-06-04
**Domain:** Phoenix LiveView authorization, Ecto tenant-scoped read models, durable recovery metadata
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### the agent's Discretion

Downstream agents may choose the narrowest implementation shape that satisfies the decisions above, keeps `chimeway_admin` optional and host-mounted, and matches existing LiveAuth/Admin DTO/recovery-core patterns.

### Deferred Ideas (OUT OF SCOPE)

None - analysis stayed within phase scope.

### Reviewed Todos (not folded)

None.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SAFE-01 | Recovery actions re-authorize the actor for the specific action and resource context at event time. | Use `LiveAuth.ensure_authorized/3` in submit handlers and include selected candidate facts in `context`; LiveView docs state authorization belongs on `mount` and `handle_event`. [VERIFIED: codebase grep] [CITED: https://phoenix-live-view.hexdocs.pm/security-model.html] |
| SAFE-02 | Recovery handles stale or no-longer-eligible candidates without duplicate or misleading actions. | Existing `Deliveries.recover_delivery/2`, `recover_event/2`, and `begin_recovery/2` return explicit `{:noop, ...}` paths and tests prove duplicate/stale behavior. [VERIFIED: codebase grep] |
| SAFE-03 | Recovery UI requires explicit confirmation and records durable evidence through core recovery APIs. | Existing core stamps `recovery_source`, `recovery_reason`, and `recovered_at`; extend that path with safe actor/confirmation facts instead of introducing a separate audit mechanism. [VERIFIED: codebase grep] |
| SAFE-04 | Admin read models and LiveViews support tenant-scoped operation through host-provided auth/session/query context. | `Chimeway.Admin` already accepts `tenant_id` opts across command center, feed, definitions, outcomes, problem deliveries, and recovery candidates; LiveViews currently omit those opts. [VERIFIED: codebase grep] |
</phase_requirements>

## Summary

Phase 70 should harden the existing admin and recovery paths rather than add a new subsystem. `ChimewayAdmin.Auth.authorize/3`, `ChimewayAdmin.LiveAuth.ensure_authorized/3`, `Chimeway.Admin` read DTOs, `Chimeway.recover_event/2`, and `Chimeway.recover_delivery/2` already provide the right extension points. [VERIFIED: codebase grep] Phoenix LiveView's security model explicitly expects LiveViews to run their own checks on mount and to authorize resource-changing actions in `handle_event`; this matches the locked decision to re-authorize recovery submits. [CITED: https://phoenix-live-view.hexdocs.pm/security-model.html]

The main implementation gap is context propagation. Current dashboard, health, feed, definitions, and recovery LiveViews call `Chimeway.admin_*` without tenant options, while `Chimeway.Admin` already implements tenant filters for those read models. [VERIFIED: codebase grep] Add a small `ChimewayAdmin.Context` or equivalent helper that extracts safe host-provided admin context from session and params, stores it in assigns, passes it to authorization, and converts it to core read/recovery opts. [VERIFIED: codebase grep]

**Primary recommendation:** Add a shared admin-context helper, pass `tenant_id` through every admin read/recovery refresh, enrich submit-time authorization context, and extend existing recovery metadata with safe operator evidence only. [VERIFIED: codebase grep]

## Project Constraints (from AGENTS.md)

- Chimeway is an embedded notification layer for Elixir/Phoenix apps where host applications own data, policies, and delivery history. [VERIFIED: AGENTS.md]
- Every notification decision must be explainable. [VERIFIED: AGENTS.md]
- Use Elixir 1.17+/OTP 26+, Ecto 3.x/PostgreSQL 15+, optional Phoenix 1.7/1.8, optional Oban 2.x, and Swoosh 1.x seams. [VERIFIED: AGENTS.md]
- Persist stable `notification_key` plus version; do not use module names as durable identity. [VERIFIED: AGENTS.md]
- Keep the durable lifecycle spine: event -> notification -> delivery -> attempt. [VERIFIED: AGENTS.md]
- Treat idempotency and suppression reasons as first-class behavior. [VERIFIED: AGENTS.md]
- Keep adapters replaceable with explicit behaviours and contract tests. [VERIFIED: AGENTS.md]
- Preserve host ownership boundaries for auth, tenancy, URL generation, and correlation IDs. [VERIFIED: AGENTS.md]
- Maintain `mix verify.*` and `mix ci.*` entrypoints with CI/local parity. [VERIFIED: AGENTS.md]
- Avoid leaking sensitive payload fields in telemetry and operator surfaces. [VERIFIED: AGENTS.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Host admin authentication and authorization | Frontend Server / Host Phoenix app | Browser / Client for submitted params only | Host plug/session sets actor; LiveView `on_mount` and `handle_event` call host `authorize/3`; client inputs are untrusted context. [VERIFIED: codebase grep] [CITED: https://phoenix-live-view.hexdocs.pm/security-model.html] |
| Tenant scope extraction | Frontend Server / LiveView package | API / Backend read opts | `chimeway_admin` receives session/params and converts host context into `tenant_id` opts; core remains host-agnostic. [VERIFIED: codebase grep] |
| Tenant-scoped admin reads | API / Backend | Database / Storage | `Chimeway.Admin` owns read model queries and already applies `tenant_id` filters before `Repo.all/2`. [VERIFIED: codebase grep] |
| Recovery eligibility and stale/noop decisions | API / Backend | Database / Storage | `Deliveries` owns eligibility predicates and atomic claim/update behavior; UI should surface returned outcomes. [VERIFIED: codebase grep] |
| Durable operator evidence | Database / Storage | API / Backend | Recovery metadata is stamped on canonical delivery rows and trace projection already reads those durable facts. [VERIFIED: codebase grep] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir / Mix | 1.19.5 local, project requires `~> 1.17` | Runtime and build/test tooling | Existing project baseline and local environment support Phase 70 tests. [VERIFIED: local command] |
| Phoenix | 1.8.7 locked | Host router/session/LiveView integration | Existing `chimeway_admin` dependency and demo host mount use Phoenix route/live_session patterns. [VERIFIED: Hex registry] |
| Phoenix LiveView | 1.1.31 locked | Admin LiveViews, `on_mount`, `handle_event`, form submit | Official security docs support mount and event-time authorization; current package already uses LiveView. [VERIFIED: Hex registry] [CITED: https://phoenix-live-view.hexdocs.pm/security-model.html] |
| Ecto / Ecto SQL | Ecto 3.13.6, Ecto SQL 3.13.5 locked | Read-model queries, atomic recovery updates, repo opts | Existing code uses `Ecto.Query` and `Repo.update_all/3`; docs confirm `update_all/3` semantics and prefix opts. [VERIFIED: Hex registry] [CITED: https://ecto.hexdocs.pm/Ecto.Repo.html] |
| PostgreSQL | Project target 15+, local client 14.17 ready | JSONB recovery metadata and query storage | Existing recovery code uses PostgreSQL JSONB functions through Ecto fragments. [VERIFIED: AGENTS.md] [VERIFIED: local command] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Oban | 2.23.0 locked, optional | Async dispatch integration behind existing dispatcher | Do not add recovery UI coupling to Oban; keep using core dispatcher APIs. [VERIFIED: Hex registry] [VERIFIED: codebase grep] |
| Floki / lazy_html | Present in `chimeway_admin` tests | Rendered HTML assertions | Use if planner adds LiveView rendered confirmation/context tests. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Existing `ChimewayAdmin.Auth.authorize/3` | New policy DSL or role system | Rejected by D-01/D-06; host owns auth and tenancy. [VERIFIED: CONTEXT.md] |
| Recovery metadata on delivery rows | Separate audit table | Higher schema and trace-projection cost; current durable recovery evidence already works and is explainable. [VERIFIED: codebase grep] |
| `tenant_id` filters in core reads | Ecto query prefixes | Query prefixes are an Ecto-supported tenancy model, but Chimeway's current data model stores `tenant_id` on delivery/workflow rows; adding prefixes would be a larger public model change. [VERIFIED: codebase grep] [CITED: https://ecto.hexdocs.pm/multi-tenancy-with-query-prefixes.html] |

**Installation:**

```bash
# No new packages recommended for Phase 70.
```

**Version verification:** Versions above were checked with `mix deps`, `mix hex.info phoenix`, `mix hex.info phoenix_live_view`, `mix hex.info ecto_sql`, and `mix hex.info oban` on 2026-06-04. [VERIFIED: local command]

## Package Legitimacy Audit

No new external package install is recommended for Phase 70. [VERIFIED: codebase grep]

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| none | — | — | — | — | — | No install needed |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```text
Host Plug/session/query params
  -> ChimewayAdmin.LiveAuth.on_mount/4
  -> Admin context extraction: actor + tenant_id + params/session
  -> Host ChimewayAdmin.Auth.authorize(actor, action, context)
     -> unauthorized: redirect fail-closed
     -> authorized: assign admin_context
        -> LiveView reads call Chimeway.admin_*(tenant_id: ...)
           -> Chimeway.Admin Ecto queries
              -> Repo.all(repo_opts)
              -> redaction-ready DTOs

Recovery submit
  -> phx-submit "recover" with candidate id/type/reason/confirmation
  -> reload or find selected candidate under current tenant scope
     -> missing/stale: return normal noop UI message
     -> present: LiveAuth.ensure_authorized(actor, action, rich resource context)
        -> unauthorized: redirect fail-closed
        -> authorized: Chimeway.recover_event/2 or recover_delivery/2
           -> Deliveries eligibility guard + atomic metadata stamp
              -> {:ok, result}: refresh tenant-scoped candidates + success evidence
              -> {:noop, result}: refresh tenant-scoped candidates + skipped evidence
              -> {:error, reason}: compensate claim where applicable + safe error UI
```

### Recommended Project Structure

```text
chimeway_admin/lib/chimeway_admin/
├── auth.ex                 # Host authorization behaviour; keep seam stable
├── live_auth.ex            # Mount/event authorization wrapper
├── context.ex              # Recommended new helper for actor/tenant/resource context
└── live/
    ├── dashboard_live.ex   # Pass read opts from admin context
    ├── health_live.ex      # Pass read opts from admin context
    ├── feed_live.ex        # Pass read opts from admin context on search
    ├── definitions_live.ex # Pass read opts from admin context
    └── recovery_live.ex    # Reauthorize submit and pass recovery evidence opts

lib/chimeway/
├── admin.ex                # Tenant-scoped DTO read queries
└── deliveries.ex           # Recovery eligibility, atomic claims, durable metadata
```

### Pattern 1: Shared Admin Context Extraction

**What:** Introduce one helper that normalizes host-provided admin context into `%{actor: ..., tenant_id: ..., params: ..., session: ...}` and converts it to safe core opts. [VERIFIED: codebase grep]

**When to use:** Every admin LiveView mount, handle_params, read refresh, and recovery submit should use the same helper to avoid per-page tenant drift. [VERIFIED: codebase grep]

**Example:**

```elixir
# Source: existing LiveAuth/session pattern and Admin tenant opts. [VERIFIED: codebase grep]
context = ChimewayAdmin.Context.from(params, session, socket)
read_opts = ChimewayAdmin.Context.read_opts(context, limit: 50)
Chimeway.admin_recovery_candidates(read_opts)
```

### Pattern 2: Event-Time Authorization With Resource Facts

**What:** Re-authorize submit actions with actor, action, tenant scope, resource id/type, and selected candidate facts loaded from the tenant-scoped candidate list. [VERIFIED: codebase grep]

**When to use:** Use for `"recover"` submit before calling `Chimeway.recover_event/2` or `Chimeway.recover_delivery/2`. [VERIFIED: codebase grep]

**Example:**

```elixir
# Source: Phoenix LiveView security docs and existing LiveAuth.ensure_authorized/3. [CITED: https://phoenix-live-view.hexdocs.pm/security-model.html] [VERIFIED: codebase grep]
with {:ok, candidate} <- fetch_candidate(socket, type, id),
     {:ok, socket} <-
       LiveAuth.ensure_authorized(socket, action, %{
         tenant_id: socket.assigns.admin_context.tenant_id,
         resource_id: id,
         recovery_type: type,
         candidate: Map.take(candidate, [:type, :id, :event_id, :delivery_id, :tenant_id, :notification_key])
       }),
     {:ok, result} <- do_recover(type, id, reason, socket.assigns.admin_context) do
  {:noreply, recovery_success(socket, result)}
end
```

### Pattern 3: Atomic Recovery Claim With Durable Metadata

**What:** Keep eligibility and duplicate protection in core `Deliveries` queries using `Repo.update_all/3` predicates and the `recovered_at IS NULL` metadata guard. [VERIFIED: codebase grep]

**When to use:** Extend existing metadata writers to include safe fields rather than writing UI-only state. [VERIFIED: codebase grep]

**Example:**

```elixir
# Source: existing Deliveries.begin_recovery/2 JSONB update pattern. [VERIFIED: codebase grep]
Chimeway.recover_delivery(delivery_id,
  source: "chimeway_admin",
  reason: reason,
  actor_ref: actor_ref,
  confirmation: confirmation_marker
)
```

### Anti-Patterns to Avoid

- **Mount-only authorization:** LiveView docs state authorization also belongs in `handle_event` for resource-changing actions; do not rely only on `on_mount`. [CITED: https://phoenix-live-view.hexdocs.pm/security-model.html]
- **UI-only stale candidate checks:** Candidate rows can change between render and submit; let core recovery return `{:noop, ...}` and refresh candidates. [VERIFIED: codebase grep]
- **Raw session/params in metadata:** D-14 forbids persisting raw session, params, payloads, provider bodies, secrets, tokens, auth codes, or full PII. [VERIFIED: CONTEXT.md]
- **Tenant membership in Chimeway:** D-06 keeps tenant policy host-owned; Chimeway should only propagate tenant scope and enforce data filters. [VERIFIED: CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Authorization policy engine | Chimeway-owned roles/permissions DSL | `ChimewayAdmin.Auth.authorize/3` | Host apps own auth and tenancy; existing seam is locked. [VERIFIED: CONTEXT.md] |
| LiveView event authorization plumbing | Per-page ad hoc auth calls | `ChimewayAdmin.LiveAuth.ensure_authorized/3` plus shared context helper | Keeps mount and submit semantics consistent. [VERIFIED: codebase grep] |
| Recovery duplicate protection | Client-side button disable or selected-row state | Core `Deliveries.recover_*` and `begin_recovery/2` guards | Existing tests prove noop behavior after stale/duplicate attempts. [VERIFIED: codebase grep] |
| Tenant-scoped reads | Manual filtering in templates | `Chimeway.Admin` read opts with `tenant_id` | Queries already filter before DTOs are returned. [VERIFIED: codebase grep] |
| Audit/event store | New operator audit table | Existing canonical recovery metadata and trace projection | Recovery explainability is already durable on rows and surfaced in traces. [VERIFIED: codebase grep] |

**Key insight:** Phase 70 is a propagation and proof phase, not a new infrastructure phase. [VERIFIED: CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Authorization Context Too Sparse

**What goes wrong:** Host auth cannot distinguish "can see recovery page" from "can recover this tenant/resource." [VERIFIED: codebase grep]

**Why it happens:** Existing submit-time context passes only `resource_id` and `recovery_type`. [VERIFIED: codebase grep]

**How to avoid:** Include actor, action, params/session summary, tenant scope, resource id, recovery type, and safe selected candidate facts. [VERIFIED: CONTEXT.md]

**Warning signs:** Tests assert `authorize/3` was called but do not inspect context fields. [VERIFIED: codebase grep]

### Pitfall 2: Tenant Scope Drift Across Pages

**What goes wrong:** Dashboard, health, feed, definitions, and recovery show different data scopes for the same operator. [VERIFIED: codebase grep]

**Why it happens:** Current LiveViews call `Chimeway.admin_*` without tenant opts, despite core support for `tenant_id`. [VERIFIED: codebase grep]

**How to avoid:** One shared extraction helper and one read-options helper used by every page and every recovery refresh. [VERIFIED: codebase grep]

**Warning signs:** Tests cover `Chimeway.Admin.recovery_candidates(tenant_id: ...)` but not mounted LiveViews passing tenant opts. [VERIFIED: codebase grep]

### Pitfall 3: Treating Noop as Failure

**What goes wrong:** Operators see stale candidates as errors, or duplicate attempts look like failed recovery. [VERIFIED: codebase grep]

**Why it happens:** UI submit state is stale relative to database eligibility. [VERIFIED: codebase grep]

**How to avoid:** Preserve normal `{:noop, ...}` UI messaging and refresh candidate lists after every submit outcome. [VERIFIED: CONTEXT.md]

**Warning signs:** Branches pattern-match only `{:ok, ...}` and `{:error, ...}`. [VERIFIED: codebase grep]

### Pitfall 4: Unsafe Operator Evidence

**What goes wrong:** Recovery metadata stores raw actor/session/params or PII, creating the privacy leak Phase 71 is meant to test. [VERIFIED: CONTEXT.md]

**Why it happens:** Metadata is convenient JSONB and easy to overfill. [VERIFIED: codebase grep]

**How to avoid:** Store only `source`, `reason`, `recovered_at`, `actor_ref`, and a confirmation marker; never store raw payload/provider/session data. [VERIFIED: CONTEXT.md]

**Warning signs:** Metadata tests assert presence of operator evidence but do not assert absence of secrets/raw params. [VERIFIED: codebase grep]

## Code Examples

### Tenant-Scoped Read Refresh

```elixir
# Source: existing Chimeway.Admin opts plus LiveView assigns. [VERIFIED: codebase grep]
defp refresh_recovery(socket) do
  opts = ChimewayAdmin.Context.read_opts(socket.assigns.admin_context, limit: 50)

  assign(socket,
    candidates: Chimeway.admin_recovery_candidates(opts),
    selected: nil
  )
end
```

### Explicit Confirmation Marker

```elixir
# Source: LiveView form submit docs and Phase 70 D-11. [CITED: https://phoenix-live-view.hexdocs.pm/form-bindings.html] [VERIFIED: CONTEXT.md]
def handle_event("recover", %{"confirm" => "RECOVER"} = params, socket) do
  # Re-authorize and call core recovery.
end

def handle_event("recover", _params, socket) do
  {:noreply, assign(socket, flash_result: "Recovery skipped: confirmation did not match.")}
end
```

### Durable Safe Evidence

```elixir
# Source: existing Chimeway.recover_delivery/2 options pattern. [VERIFIED: codebase grep]
Chimeway.recover_delivery(id,
  source: "chimeway_admin",
  reason: reason,
  actor_ref: ChimewayAdmin.Context.actor_ref(context),
  confirmation: "RECOVER"
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| LiveView mount-only checks for page access | Mount checks plus event-time authorization for mutating operations | Current LiveView docs v1.1.31 | Recovery submit must re-check actor/action/resource context. [CITED: https://phoenix-live-view.hexdocs.pm/security-model.html] |
| Recovery as transient UI action | Recovery through canonical `Chimeway.recover_*` APIs and durable row metadata | Existing code before Phase 70 | Duplicate/stale behavior stays explainable and testable. [VERIFIED: codebase grep] |
| Untenant-scoped admin page reads | Tenant opts propagated from host context to core read models | Phase 70 target | Operators see consistent scope across admin pages. [VERIFIED: CONTEXT.md] |

**Deprecated/outdated:**
- Relying on client-side disable/loading states for duplicate prevention is insufficient; LiveView submit UX helps but core idempotency/noop guards own correctness. [CITED: https://phoenix-live-view.hexdocs.pm/form-bindings.html] [VERIFIED: codebase grep]

## Assumptions Log

All claims in this research were verified from local code/config, Hex registry output, official documentation, or the Phase 70 context. No `[ASSUMED]` claims are present.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | — | — | — |

## Open Questions (RESOLVED)

1. **Exact host session key for tenant scope**
   - What we know: D-04 requires extracting tenant context from LiveView session/query params, and demo host currently sets only `"current_actor"`. [VERIFIED: CONTEXT.md] [VERIFIED: codebase grep]
   - Resolution: Use a conservative helper that checks package-specific `"chimeway_admin_tenant_id"` first, then host-generic `"tenant_id"`, then explicit query param `"tenant_id"` as host/debug context. ChimewayAdmin propagates this scope and passes it to `authorize/3`; it does not treat the value as proof of tenant membership. [VERIFIED: CONTEXT.md]

2. **Event recovery tenant guard for events with no deliveries**
   - What we know: Delivery rows have `tenant_id`; event recovery candidates with no planned deliveries currently select `tenant_id: nil` in DTOs. [VERIFIED: codebase grep]
   - Resolution: Do not fake tenant membership in UI. When a tenant scope is active, event-level no-delivery candidates are eligible only if the core query can prove the candidate belongs to that tenant from durable data. If no durable tenant can be proven, tenant-scoped reads must omit that event candidate. [VERIFIED: CONTEXT.md] [VERIFIED: codebase grep]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | Build/test | yes | 1.19.5 | Project minimum is 1.17+. [VERIFIED: local command] |
| Erlang/OTP | Build/test | yes | 28 | Project minimum is OTP 26+. [VERIFIED: local command] |
| Mix | Test aliases | yes | 1.19.5 | None needed. [VERIFIED: local command] |
| PostgreSQL server | Ecto tests | yes | Server accepting on `/tmp:5432`; client 14.17 | Use configured test DB service if local server unavailable. [VERIFIED: local command] |
| Hex package metadata | Version verification | yes | `mix hex.info` available | Use lockfile if Hex offline. [VERIFIED: local command] |
| Context7 CLI | Docs lookup | no | — | Official HexDocs/web docs used. [VERIFIED: local command] |
| slopcheck | Package legitimacy | yes | Available | No new packages recommended. [VERIFIED: local command] |

**Missing dependencies with no fallback:** none

**Missing dependencies with fallback:**
- Context7 CLI missing; official HexDocs were used for framework docs. [VERIFIED: local command]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit via Mix. [VERIFIED: codebase grep] |
| Config file | `test/test_helper.exs`, `chimeway_admin/test/test_helper.exs`. [VERIFIED: codebase grep] |
| Quick run command | `mix test test/chimeway/admin_test.exs test/chimeway/deliveries_test.exs test/chimeway/orchestration/recovery_test.exs --warnings-as-errors` |
| Package run command | `cd chimeway_admin && mix test --warnings-as-errors` |
| Full suite command | `mix ci` plus `mix verify.example` for package/demo admin coverage. [VERIFIED: local command] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| SAFE-01 | Recovery submit re-authorizes with actor/action/resource/tenant/candidate context | unit/LiveView | `cd chimeway_admin && mix test test/chimeway_admin/live_auth_test.exs --warnings-as-errors` plus new RecoveryLive test | Partial |
| SAFE-02 | Stale/ineligible recovery returns noop and no duplicate dispatch | unit/integration | `mix test test/chimeway/orchestration/recovery_test.exs --warnings-as-errors` | yes |
| SAFE-03 | Confirmation required and safe operator evidence persisted through core APIs | LiveView/core unit | New `chimeway_admin` RecoveryLive test plus `mix test test/chimeway/deliveries_test.exs --warnings-as-errors` | Partial |
| SAFE-04 | Dashboard, health, feed, definitions, and recovery pass tenant-scoped read opts | core + LiveView | `mix test test/chimeway/admin_test.exs --warnings-as-errors` plus new mounted LiveView tests | Partial |

### Sampling Rate

- **Per task commit:** Run the narrow test file touched by the task. [VERIFIED: codebase grep]
- **Per wave merge:** `mix test test/chimeway/admin_test.exs test/chimeway/deliveries_test.exs test/chimeway/orchestration/recovery_test.exs --warnings-as-errors` and `cd chimeway_admin && mix test --warnings-as-errors`. [VERIFIED: local command]
- **Phase gate:** `mix ci` plus `mix verify.example` if admin package/demo mount behavior changed. [VERIFIED: local command]

### Wave 0 Gaps

- [ ] `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs` — covers SAFE-01 and SAFE-03.
- [ ] `chimeway_admin/test/chimeway_admin/live/tenant_scope_test.exs` or per-page tests — covers SAFE-04 page propagation.
- [ ] Core event recovery tenant guard test — covers SAFE-04 for event candidates with no deliveries.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | yes | Host app authenticates actor before admin LiveView session; Chimeway only consumes host actor context. [VERIFIED: CONTEXT.md] |
| V3 Session Management | yes | Host Phoenix session provides private actor/tenant context; do not persist raw session. [VERIFIED: codebase grep] [VERIFIED: CONTEXT.md] |
| V4 Access Control | yes | `ChimewayAdmin.Auth.authorize/3` on mount and submit with resource context. [VERIFIED: codebase grep] [CITED: https://phoenix-live-view.hexdocs.pm/security-model.html] |
| V5 Input Validation | yes | Normalize `tenant_id`, recovery id/type, reason, and confirmation before recovery; client params are public and modifiable. [CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.LiveView.html] |
| V6 Cryptography | no direct change | No cryptographic implementation in scope; host session/signing remains Phoenix host responsibility. [VERIFIED: codebase grep] |
| V7 Error Handling and Logging | yes | Surface stale/noop safely; avoid leaking raw params/session/provider/payload fields in operator evidence. [VERIFIED: CONTEXT.md] |

### Known Threat Patterns for Phoenix LiveView + Ecto Admin Recovery

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stale LiveView socket used after permission/scope change | Elevation of privilege | Re-authorize in `handle_event` with actor/action/resource context. [CITED: https://phoenix-live-view.hexdocs.pm/security-model.html] |
| Cross-tenant reads from missing opts | Information disclosure | Shared admin context helper and tenant-scoped core read opts. [VERIFIED: codebase grep] |
| Duplicate recovery submit | Tampering / Repudiation | Core atomic recovery claim and `{:noop, ...}` outcomes. [VERIFIED: codebase grep] |
| Sensitive data in recovery metadata | Information disclosure | Allowlist safe operator evidence fields; assert absence of raw session/params/payload/provider fields. [VERIFIED: CONTEXT.md] |
| Forged query/session values | Spoofing / Tampering | Treat params as public data; host auth must validate tenant scope before reads/actions. [CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.LiveView.html] |

## Sources

### Primary (HIGH confidence)

- Local codebase: `chimeway_admin/lib/chimeway_admin/auth.ex`, `live_auth.ex`, admin LiveViews, `lib/chimeway/admin.ex`, `lib/chimeway/deliveries.ex`, recovery/admin tests. [VERIFIED: codebase grep]
- `AGENTS.md` - project constraints, stack, quality gates. [VERIFIED: AGENTS.md]
- Phase 70 `70-CONTEXT.md` - locked decisions and boundaries. [VERIFIED: CONTEXT.md]
- Hex registry via `mix hex.info` - Phoenix 1.8.7, Phoenix LiveView 1.1.31, Ecto SQL 3.13.5, Oban 2.23.0 metadata. [VERIFIED: Hex registry]
- Phoenix LiveView security model: https://phoenix-live-view.hexdocs.pm/security-model.html [CITED: official docs]
- Phoenix LiveView form bindings: https://phoenix-live-view.hexdocs.pm/form-bindings.html [CITED: official docs]
- Phoenix LiveView lifecycle docs: https://phoenix-live-view.hexdocs.pm/Phoenix.LiveView.html [CITED: official docs]
- Ecto Repo docs: https://ecto.hexdocs.pm/Ecto.Repo.html [CITED: official docs]
- Ecto query prefix tenancy docs: https://ecto.hexdocs.pm/multi-tenancy-with-query-prefixes.html [CITED: official docs]

### Secondary (MEDIUM confidence)

- OWASP ASVS project overview and cheat sheet index for security category framing: https://owasp.org/www-project-application-security-verification-standard/ and https://cheatsheetseries.owasp.org/IndexASVS.html [CITED: official docs]

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - verified against lockfile, local Mix/Hex commands, and official docs.
- Architecture: HIGH - implementation decisions are locked and code paths already exist.
- Pitfalls: HIGH - derived from current code gaps and official LiveView security guidance.

**Research date:** 2026-06-04
**Valid until:** 2026-07-04 for local architecture; re-check HexDocs/Hex versions before dependency changes.

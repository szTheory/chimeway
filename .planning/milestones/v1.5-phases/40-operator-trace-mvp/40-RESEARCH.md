# Phase 40: Operator Trace MVP — Research

**Researched:** 2026-05-28  
**Phase:** 40-operator-trace-mvp  
**Requirements:** OPER-01, OPER-02  
**Status:** Ready for plan-phase

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01/D-02:** Sibling Mix project `chimeway_admin/` at repo root; path dep on `chimeway`; core `mix.exs` stays Phoenix-free.
- **D-03/D-04:** `ChimewayAdmin.Auth` behaviour; fail closed; host implements authorization; no Guardian/Pow assumptions.
- **D-05/D-06/D-07:** Phoenix LiveView; mountable router under host authenticated scope; MVP routes only — search + detail.
- **D-08/D-09/D-10:** Search modes map to `find_traces_for_recipient/2` and `find_traces_by_correlation_id/1`; detail uses `explain_delivery/1` only.
- **D-11/D-12:** Timeline from `Explanation.timeline`; top-level Explanation fields above timeline.
- **D-13/D-14:** View-layer redaction; Explanation fields only on detail; no raw delivery metadata blobs.
- **D-15/D-16:** Demo host mount + permissive dev auth stub; README + golden-path cross-link.
- **D-17/D-18:** No bell inbox, campaigns, health dashboard, registry browser, aggregate charts; no engine API changes unless blocking gap.

### Claude's Discretion
- Auth callback arity/action atoms; LiveView component structure; default limit 50; Hex publish timing.

### Deferred (OUT OF SCOPE)
- `mix verify.example` admin smoke — Phase 41
- Core redaction module — revisit post-MVP if PII gaps found
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OPER-01 | Optional `chimeway_admin` MVP: redacted trace lookup by user/recipient ID or correlation ID with host auth behaviour | Sibling package + Auth behaviour + search LiveView + redaction helpers |
| OPER-02 | Operator trace view links attempts, suppressions, webhooks, workflow transitions on one timeline; no bell inbox or campaign UI | Detail LiveView renders `Explanation.timeline` only; scope docs exclude inbox/campaigns |
</phase_requirements>

## Summary

Phase 40 delivers **OPER-01** and **OPER-02** by introducing an optional **`chimeway_admin`** Hex-ready sibling package with two LiveView routes (search, detail), a host-implemented **`ChimewayAdmin.Auth`** behaviour, and demo-host proof that support staff can debug deliveries in a browser without IEx.

The engine already exposes the full operator query API in `Chimeway.Traces` (Phase 32 timeline projection includes `:webhook_received`, `:workflow_*`, `:suppressed`, `:attempt_recorded`). The UI layer must not duplicate query or timeline assembly — only map `Explanation` and notification summaries into redacted HEEx.

**Primary recommendation:** Scaffold `chimeway_admin/` as a standard Phoenix library app (no standalone Endpoint), export `ChimewayAdmin.Router` macro + `ChimewayAdmin.LiveAuth` on_mount hook, add minimal `ChimewayAdmin.Redaction` for list/detail display, extend `examples/chimeway_demo_host` with browser pipeline + LiveView deps + `DemoHost.AdminAuth` stub.

**Confidence: HIGH** — APIs verified in `lib/chimeway/traces.ex` and `Explanation`; demo host already has Phoenix endpoint, PubSub, and `live_view` signing salt in config; Phase 39 provides IEx proof path to complement.

## Standard Stack

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Elixir / OTP | ~> 1.17 | Runtime | Project baseline |
| Phoenix | ~> 1.7 | Host + admin router | Demo host already on 1.7 |
| Phoenix LiveView | ~> 1.0 | Operator UI | Locked D-05; optional package boundary |
| Chimeway (path) | 0.1.0 | Traces API | `find_traces_*`, `explain_delivery/1` |
| PostgreSQL | 15+ | Durable spine | Same `chimeway_dev` DB as demo host |

**New package:** `chimeway_admin` — only consumers that mount admin UI pay Phoenix/LiveView deps.

## Architecture Patterns

### System Architecture Diagram

```
Support operator (browser)
    │
    ▼
Host router (authenticated live_session)
    │  on_mount: ChimewayAdmin.LiveAuth → ChimewayAdmin.Auth.authorize/3
    ▼
ChimewayAdmin.TraceSearchLive / TraceDetailLive
    │  assign redacted summaries
    ▼
Chimeway.Traces (existing public API)
    ├─ find_traces_for_recipient/2
    ├─ find_traces_by_correlation_id/1
    └─ explain_delivery/1 → %Explanation{timeline: [...]}
```

### Recommended Project Structure

```
chimeway_admin/
├── mix.exs
├── lib/chimeway_admin/
│   ├── application.ex          # :ok supervisor (no Endpoint)
│   ├── auth.ex                 # @callback authorize/3
│   ├── live_auth.ex            # on_mount hook
│   ├── router.ex               # __using__ macro for host scope
│   ├── redaction.ex            # recipient/tokenize helpers
│   └── live/
│       ├── trace_search_live.ex
│       └── trace_detail_live.ex
└── test/chimeway_admin/
    ├── redaction_test.exs
    └── live/trace_search_live_test.exs

examples/chimeway_demo_host/
├── mix.exs                     # + phoenix_live_view, chimeway_admin path
├── lib/demo_host/admin_auth.ex # permissive dev stub (D-15)
└── lib/demo_host_web/router.ex # browser pipeline + ChimewayAdmin routes
```

### Pattern 1: Mountable router macro [RECOMMENDED]

Hosts add a `:browser` pipeline (session, CSRF, root layout) then:

```elixir
scope "/admin/chimeway", DemoHostWeb do
  pipe_through [:browser, :require_support_role]  # host-owned plugs
  import ChimewayAdmin.Router
  chimeway_admin_routes auth: DemoHost.AdminAuth
end
```

`ChimewayAdmin.Router.chimeway_admin_routes/1` expands to `live_session` with `on_mount` calling configured auth module. Document that **host owns** `live_session` name collision avoidance and outer auth plugs.

### Pattern 2: Auth behaviour [VERIFIED: Chimeway.Notifier precedent]

```elixir
@callback authorize(actor :: term(), action :: atom(), context :: map()) ::
            :ok | {:error, :unauthorized}
```

Actions: `:search_traces`, `:view_trace`. LiveViews call before `handle_event` / `mount` data loads. Unauthorized → flash + redirect to host login or static forbidden assign.

Config: `config :chimeway_admin, auth_module: DemoHost.AdminAuth`

### Pattern 3: Search result shaping [VERIFIED: traces.ex]

**Recipient mode:** `find_traces_for_recipient(id, notification_key: key, limit: 50)` → list of `%Notification{}` with preloaded deliveries. Flatten to rows: `{delivery_id, notification_key, channel, status, inserted_at, redacted_recipient}`.

**Correlation mode:** `find_traces_by_correlation_id/1` → list of `%Event{}` with nested notifications/deliveries; flatten similarly.

**Detail:** `explain_delivery(delivery_id)` → render `status`, `suppression_reason`, `planning_reason`, `correlation_id`, `notification_key`, `channel`, `last_attempt`, and `timeline` entries (`:at`, `:event`, `:detail`).

### Pattern 4: View-layer redaction [NEW in admin package]

- Recipients: show `user:***` + last 3 chars or email local-part tokenization (mirror adapter telemetry keys: password, token, secret, api_key, auth).
- Timeline `:detail` maps: render only whitelisted keys (`reason`, `outcome`, `event_name`, `step_key`); never dump full `detail` if it contains nested metadata.
- Do not call `Repo` from LiveViews — only `Chimeway.Traces`.

### Anti-patterns to avoid

- Embedding LiveViews in `lib/chimeway/` — violates INV-001 and couples API-only consumers to Phoenix.
- Reading `Delivery.metadata` or attempt payload fields in templates — violates D-14.
- Hard-coded Guardian/session checks in admin — violates D-04.
- Building custom timeline from raw rows — duplicates engine; use `Explanation.timeline` only.

## Integration Points

| Surface | Change |
|---------|--------|
| `chimeway_admin/mix.exs` | New app `:chimeway_admin` |
| `examples/chimeway_demo_host/mix.exs` | `{:chimeway_admin, path: "../../chimeway_admin"}`, `{:phoenix_live_view, ...}` |
| `examples/chimeway_demo_host/lib/demo_host_web/router.ex` | Browser pipeline + admin routes |
| `examples/chimeway_demo_host/README.md` | Operator UI walkthrough (D-16) |
| `guides/introduction/golden-path.md` | Visual trace validation cross-link (D-16) |
| Root `mix.exs` | Optional: add chimeway_admin to CI compile path (discretion — Plan 40-03) |

## Validation Architecture

Nyquist applies: new ExUnit tests in `chimeway_admin/test/` plus demo host LiveView smoke optional.

| Behavior | Command | Type |
|----------|---------|------|
| Package compiles | `cd chimeway_admin && mix compile --warnings-as-errors` | compile |
| Redaction helpers | `cd chimeway_admin && mix test test/chimeway_admin/redaction_test.exs` | unit |
| Auth denied on search | LiveView test with stub returning `{:error, :unauthorized}` | unit |
| Demo host still tests green | `cd examples/chimeway_demo_host && mix test` | integration |
| No Phoenix dep in core | `! rg 'phoenix_live_view' mix.exs` at repo root chimeway | grep |

Manual: browser walkthrough — trigger via Phase 39 IEx/script, open `/admin/chimeway`, search recipient, open detail timeline.

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Demo host is API-only today (no browser pipeline) | Plan 40-03 adds minimal browser + LiveView session |
| LiveView tests need Endpoint | Use `Phoenix.LiveViewTest` with host Endpoint in demo or admin test helper |
| Correlation search returns many deliveries | Default flatten + sort by `inserted_at` desc; cap display at 50 rows |
| PII in timeline `:detail` | Whitelist render keys in `ChimewayAdmin.TimelineEvent` component |

## RESEARCH COMPLETE

Ready for plan-phase. No blocking engine gaps identified.

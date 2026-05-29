# Phase 40: Operator Trace MVP - Context

**Gathered:** 2026-05-28 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver **OPER-01** and **OPER-02**: an optional **`chimeway_admin`** package that gives support staff redacted trace lookup by recipient ID or correlation ID — behind a host-provided auth behaviour — without building custom tooling.

In scope: sibling Mix project with Phoenix LiveView (search + trace detail), `ChimewayAdmin.Auth` behaviour, mountable router for host apps, demo host wiring with permissive dev auth stub, documentation cross-links from golden-path and demo host README.

Out of scope: bell inbox UI, marketing/campaign tooling, health dashboard, definitions/registry browser, aggregate outcome charts, engine/API changes to trace query shapes, `mix verify.example` CI expansion (Phase 41), read/unread workflow glue.

Resolves **INV-001**: `chimeway_admin` ships as an **in-repo sibling Mix project** (`chimeway_admin/`), not LiveViews embedded in core `chimeway`.

</domain>

<decisions>
## Implementation Decisions

### Package shape (INV-001)
- **D-01:** Create **`chimeway_admin/`** as a sibling Mix project at repo root with path dependency on `chimeway` — separate Hex publish target when ready; core `chimeway` package must not gain required Phoenix/LiveView deps.
- **D-02:** `chimeway_admin` declares its own deps (`phoenix`, `phoenix_live_view`, `chimeway` path dep); API-only consumers continue depending on `chimeway` alone.

### Auth seam
- **D-03:** Define **`ChimewayAdmin.Auth` behaviour** with host-implemented authorization (e.g. `authorize(actor, action)` returning `:ok | {:error, :unauthorized}`); admin routes and LiveViews fail closed when unauthorized.
- **D-04:** No hard-coded host auth stack — no assumptions about Guardian, Pow, or session shape; host passes actor via config or mount opts; document one blessed integration pattern in demo host.

### UI surface & mounting
- **D-05:** Use **Phoenix LiveView** for the operator UI inside `chimeway_admin` — not controller-only JSON or embedded HEEx in core.
- **D-06:** Expose a **mountable router** (`ChimewayAdmin.Router` or equivalent macro/forward) so hosts mount admin under an authenticated scope (e.g. `/admin/chimeway`) with their own `live_session` auth — sigra-style mountable admin pattern.
- **D-07:** MVP ships **two routes only**: (1) trace search/index, (2) trace detail — no additional IA pillars.

### Search & result flow
- **D-08:** Search form with explicit mode selector: **Recipient ID** → `Chimeway.Traces.find_traces_for_recipient/2` | **Correlation ID** → `Chimeway.Traces.find_traces_by_correlation_id/1`.
- **D-09:** Results list shows notification/delivery summaries (redacted); selecting a delivery navigates to detail view powered by **`Chimeway.Traces.explain_delivery/1`** — do not reimplement query or timeline assembly in the UI layer.
- **D-10:** Optional `notification_key` filter on recipient search — exposed as simple form field, not advanced query builder.

### Timeline presentation
- **D-11:** Detail view renders **`Explanation.timeline`** from `explain_delivery/1` as the single unified timeline surface — delivery attempts (`:attempt_recorded`), suppressions (`:suppressed`, `:cancelled`), webhook events (`:webhook_received`), and workflow transitions (`:workflow_progressed`, `:workflow_waiting`, `:workflow_stopped`, `:workflow_completed`) are already projected by the engine (Phase 32 / TRAC-01/02).
- **D-12:** Display top-level Explanation fields (status, suppression_reason, planning_reason, last_attempt, correlation_id, notification_key, channel) above the timeline — aligned with password-reset support trace recipe diagnostic branches.

### Redaction policy
- **D-13:** **View-layer redaction for MVP** — list views show notification_key, channel, status, timestamps, and truncated recipient identity (e.g. tokenized email or `user:***123`); never render raw delivery metadata blobs or payload snapshots.
- **D-14:** Detail view uses **`Chimeway.Traces.Explanation` fields only** — no direct reads of sensitive delivery row metadata for display; align with existing telemetry/adapter redaction philosophy (password, token, secret, api_key, auth keys never shown).

### Demo host proof
- **D-15:** Wire `chimeway_admin` into **`examples/chimeway_demo_host`** with a **permissive dev/test auth stub** (always authorize in dev; document deny-by-default production pattern).
- **D-16:** Extend demo host README with mount steps and a short operator UI walkthrough; cross-link from **`guides/introduction/golden-path.md`** as the visual trace validation step complementing Phase 39 IEx path.

### Scope boundary
- **D-17:** Explicitly exclude bell inbox, campaign UI, health aggregates dashboard, notification definitions registry, and `aggregate_outcomes/1` charts — MVP is trace lookup only per ROADMAP success criterion 3.
- **D-18:** No engine changes unless a blocking gap is discovered during execute — UI consumes existing public `Chimeway.Traces` API.

### Claude's Discretion
- Exact behaviour callback arity and action atom names (`:search`, `:view_trace`, etc.) as long as fail-closed semantics hold.
- LiveView component structure, CSS styling, and timeline event rendering format (table vs vertical timeline).
- Whether recipient search defaults to limit 50 or exposes limit control.
- Hex package metadata and publish timing (in-repo path dep is sufficient for v1.5 MVP acceptance).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap
- `.planning/ROADMAP.md` — Phase 40 goal, success criteria, INV-001 resolution note
- `.planning/REQUIREMENTS.md` — OPER-01, OPER-02 acceptance text
- `.planning/PROJECT.md` — Adoption Surface milestone, explainability as core value, operator UX intent
- `.planning/STATE.md` — INV-001 open investigation (resolved by D-01/D-02 in this context)

### Prior phase decisions
- `.planning/phases/39-demo-host-trace-path/39-CONTEXT.md` — IEx path is primary non-webhook proof; operator LiveView deferred here; demo host Phoenix wiring
- `.planning/phases/38-reference-recipes/38-CONTEXT.md` — Support Operator JTBD via `find_traces_for_recipient/2` + `explain_delivery/1`; diagnostic branches for suppression/failure/success
- `.planning/phases/36-golden-path-version-alignment/36-CONTEXT.md` — cross-link patterns for golden-path integration

### Trace APIs (engine — read-only consumption)
- `lib/chimeway/traces.ex` — `find_traces_for_recipient/2`, `find_traces_by_correlation_id/1`, `explain_delivery/1`, `get_trace/1`
- `lib/chimeway/traces/explanation.ex` — Explanation struct fields and timeline entry shape
- `guides/recipes/password-reset-support-trace.md` — Support Operator diagnostic narrative template
- `guides/recipes/tracing-a-notification.md` — IEx trace query depth reference

### Operator IA & integration seams
- `prompts/chimeway-admin-ui-and-operator-ia.md` — trace lookup IA, redaction rules, host auth behaviour intent, LiveView behind optional package
- `prompts/chimeway-engineering-dna-from-prior-libs.md` — §3 sibling package recommendation (`chimeway` + `chimeway_admin`)
- `prompts/chimeway-host-app-integration-seam.md` — host owns auth; LiveView mount under host router scope

### Personas
- `.planning/seeds/SEED-004-personas-and-dx-roadmap.md` — Support Operator JTBD ("why didn't user get email?")

### Demo host (mount target)
- `examples/chimeway_demo_host/mix.exs` — Phoenix host, path dep to chimeway
- `examples/chimeway_demo_host/lib/demo_host_web/router.ex` — current minimal router (webhook-only today)
- `examples/chimeway_demo_host/README.md` — Phase 39 IEx walkthrough (complement, not replace)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Traces` — complete public query API for operator surfaces; timeline already includes webhook + workflow projection (Phase 32).
- `Chimeway.Traces.Explanation` — structured operator debugging artifact; primary data source for detail view.
- `examples/chimeway_demo_host` — Phoenix host with path dep, sync dispatcher, trace demo notifier — natural mount target for admin UI proof.
- `@behaviour` patterns throughout core (`Chimeway.Notifier`, `Chimeway.Adapter`, `Chimeway.Dispatch`) — precedent for `ChimewayAdmin.Auth`.

### Established Patterns
- Core `mix.exs` has **no Phoenix/LiveView deps** — sibling package keeps API-only consumers clean.
- Phase 39 established demo host as adoption proof surface; Phase 40 adds visual operator layer on same host.
- Recipes and golden-path use **cross-link over duplicate** — admin mount docs should link to existing trace API docs, not re-document query semantics.
- Host-owned auth boundary is a locked project principle (`prompts/chimeway-host-app-integration-seam.md`).

### Integration Points
- New `chimeway_admin/` Mix project — primary deliverable.
- `examples/chimeway_demo_host` — mount `ChimewayAdmin.Router`, auth stub, README extension.
- `guides/introduction/golden-path.md` — new cross-link for visual trace validation.
- Host apps (future): add `{:chimeway_admin, "~> x.y"}` dep, implement `ChimewayAdmin.Auth`, forward router under authenticated scope.

</code_context>

<specifics>
## Specific Ideas

- User confirmed all assumptions without corrections (assumptions mode, 2026-05-28).
- Support Operator story: search by user ID or correlation ID from a ticket, read unified timeline, copy safe summary — no IEx required.
- Phase 39 IEx path remains lowest-friction CLI validation; Phase 40 adds browser-based operator UX for the same underlying APIs.

</specifics>

<deferred>
## Deferred Ideas

- **Bell inbox / notification center UI** — INBX milestone (v1.6+)
- **Health dashboard** (failure rates, queue depth, stuck deliveries) — IA pillar 4, future phase
- **Definitions/registry browser** (notification_key registry, version skew warnings) — IA pillar 3, future phase
- **Aggregate outcomes charts** — `aggregate_outcomes/1` UI deferred; API exists but out of MVP scope
- **Marketing campaign / drip campaign UI** — explicitly out of scope per PROJECT.md
- **`mix verify.example` admin route smoke** — Phase 41 (GATE-01)
- **Dedicated trace redaction module in core** — view-layer sufficient for MVP; revisit if PII gaps found during execute

None — analysis stayed within phase scope.

</deferred>

---

*Phase: 40-operator-trace-mvp*
*Context gathered: 2026-05-28*

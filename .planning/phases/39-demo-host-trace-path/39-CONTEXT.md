# Phase 39: Demo Host Trace Path - Context

**Gathered:** 2026-05-28 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver **DEMO-01**: a documented, runnable **non-webhook** trace inspection path on `examples/chimeway_demo_host` so adopters can validate explainability (`Chimeway.Traces.explain_delivery/1` and related queries) without standing up provider webhooks or running the feedback E2E test.

In scope: demo host README (or equivalent primary doc), minimal notifier + real `Chimeway.trigger/3` walkthrough, optional `priv/scripts` or Mix alias, `config/dev.exs` so IEx works outside ExUnit, golden-path cross-link as lowest-friction validation step.

Out of scope: operator LiveView/UI (Phase 40), `mix verify.example` / doc-contract CI expansion (Phase 41), engine/API changes, new webhook routes or workflow progression proof (already covered by Phase 37–38 docs + E2E).

</domain>

<decisions>
## Implementation Decisions

### Primary surface
- **D-01:** Primary adopter path is an **IEx walkthrough** documented in `examples/chimeway_demo_host/README.md` — not a new Phoenix route or LiveView (operator UI is Phase 40).

### Trigger mechanism
- **D-02:** Add a **minimal demo host notifier** (e.g. `DemoHost.Notifiers.TraceDemo`) implementing `Chimeway.Notifier`, and document **`Chimeway.trigger/3`** in the walkthrough — do not instruct adopters to `Repo.insert!` fixtures like `feedback_pipeline_e2e_test.exs`.
- **D-03:** Use **sync dispatcher** (`Chimeway.Dispatch.Sync`) in demo host dev/IEx config so delivery completes in-session without Oban drain choreography.

### Scenario and narrative
- **D-04:** Walkthrough scenario is a **simple delivery trace** (trigger → `explain_delivery/1` → read `status`, `suppression_reason`, `planning_reason`, `timeline`) aligned with the password-reset support trace JTBD — explicitly **not** the webhook/workflow progression path.
- **D-05:** README must **contrast** this path with the existing webhook E2E (`feedback_pipeline_e2e_test.exs`) — link to golden-path webhook appendix for progression proof, not duplicate it.

### Golden-path integration
- **D-06:** Add a short **"Validate in the demo host (no webhooks)"** subsection to `guides/introduction/golden-path.md` (§6 or §7) pointing to the demo host README as the **lowest-friction** validation step after first `explain_delivery/1` (ROADMAP success criterion 3).
- **D-07:** Optionally cross-link from `guides/recipes/password-reset-support-trace.md` § Support Operator — demo host README is runnable proof of the same APIs without `MyApp` placeholders.

### Automation and CI boundaries
- **D-08:** **Optional** `priv/scripts/trace_demo.exs` or demo-host Mix alias for one-shot automation — not required for DEMO-01 acceptance.
- **D-09:** Do **not** expand root `mix verify.example` or add doc-contract gates in this phase (Phase 41 GATE-01).

### Runtime configuration
- **D-10:** Add **`examples/chimeway_demo_host/config/dev.exs`** with `Chimeway.Repo` (non-sandbox pool) and Chimeway runtime config so documented IEx steps work outside `mix test`; document DB name/migrate steps consistent with root `config/dev.exs` conventions.

### Claude's Discretion
- Notifier module name, notification_key string, and channel choice (in_app vs email) as long as sync dispatch + explainable timeline are demonstrated.
- Exact README section headings and whether script is `mix run priv/scripts/...` vs `mix demo.trace` alias.
- Minor golden-path wording and link placement within §6–§7.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap
- `.planning/ROADMAP.md` — Phase 39 goal and success criteria
- `.planning/REQUIREMENTS.md` — DEMO-01 acceptance text
- `.planning/PROJECT.md` — Adoption Surface milestone, explainability as core value

### Prior phase decisions
- `.planning/phases/36-golden-path-version-alignment/36-CONTEXT.md` — D-09/D-10 webhook appendix cross-link pattern; deferred non-webhook demo path to Phase 39
- `.planning/phases/38-reference-recipes/38-CONTEXT.md` — docs-only pattern; password-reset support trace JTBD; explicit deferral of demo host trace path

### Trace APIs and guides
- `lib/chimeway/traces.ex` — `explain_delivery/1`, `find_traces_for_recipient/2`, `find_traces_by_correlation_id/1`, IEx usage in moduledoc
- `guides/introduction/golden-path.md` — §6 trace proof, §7 what's next, webhook appendix
- `guides/recipes/password-reset-support-trace.md` — Support Operator explain flow (narrative template for D-04)
- `guides/recipes/tracing-a-notification.md` — IEx diagnostic snippets

### Demo host (current state)
- `examples/chimeway_demo_host/mix.exs` — path dep to chimeway, minimal aliases
- `examples/chimeway_demo_host/config/test.exs` — Repo + Sync dispatcher + sandbox (test-only today)
- `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` — webhook path proof (contrast only, do not replicate fixture pattern in adopter docs)

### Notifier pattern
- `lib/chimeway/notifier.ex` — notifier behaviour contract
- `test/support/chimeway/test_support_notifier.ex` — minimal notifier reference implementation

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Traces.explain_delivery/1` — primary explainability API; moduledoc includes IEx examples.
- `Chimeway.Test.SupportNotifier` — minimal notifier shape for demo host copy-adapt.
- `feedback_pipeline_e2e_test.exs` fixture helpers — **internal test pattern only**; use `Deliveries.plan_delivery/3` concepts indirectly via real trigger, not raw inserts in adopter docs.

### Established Patterns
- Golden-path and recipes use **cross-link over duplicate** (Phase 36 D-09/D-10).
- Demo host tests share `Chimeway.Repo` with SQL sandbox (`test_helper.exs`, `config/test.exs`).
- `Chimeway.Dispatch.Sync` in test config — same pattern for dev/IEx per D-03.

### Integration Points
- New `examples/chimeway_demo_host/README.md` — primary deliverable surface.
- `guides/introduction/golden-path.md` — lowest-friction link (D-06).
- Optional `examples/chimeway_demo_host/lib/demo_host/notifiers/` — new notifier module.
- `examples/chimeway_demo_host/config/dev.exs` — new file for IEx runtime (D-10).

</code_context>

<specifics>
## Specific Ideas

- User confirmed all assumptions without corrections (assumptions mode, 2026-05-28).
- Lowest-friction story: "I cloned chimeway, started demo host IEx, triggered once, ran `explain_delivery` — I see why it sent without configuring SendGrid or webhooks."
- Webhook E2E remains the reference for **progression** proof; this phase owns **explainability without webhooks** proof.

</specifics>

<deferred>
## Deferred Ideas

- **Operator trace LiveView (`chimeway_admin`)** — Phase 40 (OPER-01, OPER-02)
- **`mix verify.example` + doc-contract CI matrix** — Phase 41 (GATE-01)
- **Minimal HTTP trace lookup route on demo host** — only if IEx README proves insufficient during execute; default is IEx per D-01

None — analysis stayed within phase scope.

</deferred>

---

*Phase: 39-demo-host-trace-path*
*Context gathered: 2026-05-28*

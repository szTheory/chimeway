# Phase 38: Reference Recipes - Context

**Gathered:** 2026-05-28 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Adopters get copy-adaptable recipes for the two highest-leverage SaaS notification JTBDs (SEED-002, SEED-004). Delivers RECP-01 and RECP-02: a password-reset support trace walkthrough (Feature Developer trigger setup + Support Operator trace inspection for "why no email?") and a feedback escalation walkthrough (Product Manager flow from outbound send → webhook feedback → workflow progression visible in trace). Recipes are self-contained under `guides/recipes/` with runnable snippets and demo host cross-links. Does not implement operator UI (Phase 40), demo host trace path beyond existing E2E (Phase 39), full GATE-01 doc-contract CI matrix (Phase 41), or engine/API changes.

</domain>

<decisions>
## Implementation Decisions

### Recipe placement & packaging
- **D-01:** Ship both recipes as new markdown files under `guides/recipes/` alongside existing recipes (`tracing-a-notification.md`, `oban-integration.md`, `custom-adapter.md`) — not as separate example apps or `examples/` directories.
- **D-02:** Register both new recipe files in `mix.exs` `docs/[:extras]` so HexDocs publishes them under the existing Recipes group (`groups_extras: Recipes: ~r/guides\/recipes\//`).

### RECP-01 — Password-reset support trace
- **D-03:** Deliver at `guides/recipes/password-reset-support-trace.md`. Open with SEED-004 persona framing: Feature Developer (define + trigger) and Support Operator (diagnose "why no email?").
- **D-04:** Feature Developer section: email-channel `PasswordReset` notifier using real Notifier callback API (`notification_key`, `recipients/1`, `build/2`, `channels/2` returning `:email`) and `Chimeway.trigger/3` with required `idempotency_key` and `tenant_id` — aligned with golden-path and journey guide patterns, not fictional APIs.
- **D-05:** Support Operator section: trace lookup via `Chimeway.Traces.find_traces_for_recipient/2` (with `notification_key: "password_reset"` filter) and diagnosis via `Chimeway.Traces.explain_delivery/1`, reading `explanation.status`, `explanation.suppression_reason`, and `explanation.timeline`.
- **D-06:** Include 2–3 concrete diagnostic branches a support engineer would encounter: (1) policy suppression (quiet hours, opt-out, frequency cap via `suppression_reason`), (2) delivery failure (`:failed`, `:cancelled`, `retries_exhausted`, `permanent_failure`, `bounced`), (3) succeeded delivery but user claims non-receipt (trace shows `:succeeded` — handoff to provider/spam investigation, not Chimeway bug). Use IEx snippets with expected fields, not raw payload inspection.
- **D-07:** Cross-link golden-path (install/trigger baseline), `tracing-a-notification.md` (telemetry/correlation depth), and `guides/flows/policy-and-preferences.md` (policy model — note stub status honestly). Do not duplicate golden-path install steps verbatim.

### RECP-02 — Feedback escalation workflow
- **D-08:** Deliver at `guides/recipes/feedback-escalation-workflow.md`. Open with SEED-004 persona framing: Feature Developer (notifier + workflow authoring) and Product Manager ("if delivery feedback X, then Y" progression story).
- **D-09:** Feature Developer section: notifier with `workflow/2` callback using real progress rule kinds (`wait_until`, `on_outcome`, `stop`) — cross-link `guides/flows/multi-step-journeys.md` for full authoring reference rather than duplicating the mention-escalation example wholesale.
- **D-10:** Product Manager / operator section: narrate the end-to-end feedback loop — outbound delivery → provider webhook POST → `ProcessFeedbackWorker` → `Chimeway.Signal.track/4` with canonical `chimeway.delivery.{succeeded,bounced,failed}` → `SignalRouterWorker` → `route_signal/1` → workflow transition → visible in `Chimeway.Traces.explain_delivery/1` timeline (`:webhook_received`, `:workflow_stopped`, or signal-driven resume).
- **D-11:** Cross-link demo host E2E test (`examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs`) and golden-path webhook appendix (`guides/introduction/golden-path.md#next-webhook-feedback-loop`) for runnable proof — follow Phase 36 D-09/D-10 pattern (outcome description + links, not full inline webhook controller setup).
- **D-12:** Document both progress path (succeeded signal resumes `:waiting` run) and stop path (bounced signal → `workflow_stopped`) as separate subsections, matching demo host E2E describe blocks.

### Persona & doc differentiation
- **D-13:** Each recipe includes a "Who this is for" section with the SEED-004 JTBD quote from ROADMAP success criteria at the top.
- **D-14:** Maintain clear doc hierarchy — golden-path = first vertical slice (`:in_app` welcome); `tracing-a-notification` = telemetry/correlation; password-reset recipe = support debugging JTBD with email + suppression branches; feedback-escalation recipe = workflow progression via webhooks JTBD; journey guide = workflow authoring reference.

### Doc-contract verification (stretch)
- **D-15:** Extend `test/chimeway/doc_contract_test.exs` with lightweight assertions on both new recipe files: forbid fictional APIs (`Chimeway.Workflow`, `stop_conditions`, wrong worker namespaces); require `Chimeway.trigger/3`, `Chimeway.Traces.explain_delivery/1`, and persona-relevant trace APIs. Full GATE-01 automated matrix remains Phase 41 scope.

### Scope boundary
- **D-16:** Docs-only phase — no engine changes, no new demo host features. Optional minimal "Next Steps" cross-links from golden-path and journey guide pointing to new recipes.

### Claude's Discretion
- Exact recipe section headings and narrative tone (tutorial vs checklist)
- Whether diagnostic branches use tabular "symptom → trace field → meaning" format vs prose walkthrough
- Specific IEx snippet depth (minimal vs copy-paste runnable)
- Whether RECP-02 includes a condensed inline notifier/workflow snippet or link-only to journey guide
- CHANGELOG entry for doc-only changes
- Exact doc-contract forbidden/required string lists for recipe files

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and scope
- `.planning/ROADMAP.md` — Phase 38 goal, success criteria, RECP-01/RECP-02 mapping
- `.planning/REQUIREMENTS.md` — RECP-01, RECP-02 acceptance criteria
- `.planning/PROJECT.md` — Adoption Surface intent; persona-driven DX (SEED-004)
- `.planning/seeds/SEED-002-adoption-surface-reference-flows.md` — Reference flow seed context
- `.planning/seeds/SEED-004-personas-and-dx-roadmap.md` — Persona JTBD definitions
- `.planning/threads/2026-05-28-v1.5-milestone-assessment.md` — "support engineer traces password reset" gap evidence

### Prior phase context (doc patterns to follow)
- `.planning/phases/36-golden-path-version-alignment/36-CONTEXT.md` — Golden-path structure, webhook appendix cross-link pattern (D-09/D-10)
- `.planning/phases/37-doc-truth-journey-guides/37-CONTEXT.md` — Journey guide API truth, signal routing docs, doc-contract test pattern

### Existing guides (extend, don't duplicate)
- `guides/introduction/golden-path.md` — Install-to-trace baseline; webhook appendix link target
- `guides/recipes/tracing-a-notification.md` — Telemetry/correlation; cross-link for depth
- `guides/flows/multi-step-journeys.md` — Workflow authoring reference for RECP-02
- `guides/flows/policy-and-preferences.md` — Policy model (stub — note honestly in RECP-01)
- `guides/recipes/oban-integration.md` — Oban dispatch context if recipes mention async email delivery

### Demo host proof (RECP-02)
- `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` — Progress and stop path E2E proof
- `examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex` — Feedback normalization example

### Engine source of truth (for doc accuracy)
- `lib/chimeway/traces.ex` — `explain_delivery/1`, `find_traces_for_recipient/2`, `find_traces_by_correlation_id/1`, `get_trace/1`
- `lib/chimeway/traces/explanation.ex` — Explanation struct fields (`status`, `suppression_reason`, `timeline`)
- `lib/chimeway/notifier.ex` — Notifier callback API, workflow/2, progress rule kinds
- `lib/chimeway/trigger.ex` / `lib/chimeway.ex` — `Chimeway.trigger/3` entrypoint
- `lib/chimeway/signal.ex` — `Chimeway.Signal.track/4`
- `lib/chimeway/workflows.ex` — `route_signal/1`, `explain/2`, `list_traces/2`
- `lib/chimeway/deliveries.ex` — Suppression reasons, delivery status transitions
- `lib/chimeway/policy/settings.ex` — Quiet hours, frequency cap evaluation

### Doc-contract pattern
- `test/chimeway/doc_contract_test.exs` — Existing journey guide contract test to extend

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `guides/recipes/tracing-a-notification.md` — Telemetry attachment pattern and basic `explain_delivery/1` usage; RECP-01 extends with persona-driven support walkthrough
- `guides/introduction/golden-path.md` — Canonical trigger + trace proof; RECP-01 links here for setup baseline
- `guides/flows/multi-step-journeys.md` — Real `workflow/2` authoring with `wait_until`/`on_outcome`/`stop`; RECP-02 links here for workflow definition
- `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` — Runnable proof for progress and stop feedback paths with fixture helpers documenting `pending_signals` wiring
- `test/chimeway/traces_test.exs` — Uses `password_reset` notification_key in recipient filter tests; validates trace API contracts
- `mix.exs` docs extras — Recipes group already configured; add two new paths

### Established Patterns
- Phase 36–37 doc-only delivery: real API names only, `Chimeway.trigger/3` with `idempotency_key` + `tenant_id`, no fictional modules
- Cross-link over duplicate: golden-path webhook appendix links to demo host E2E rather than inline setup (Phase 36 D-09)
- Doc-contract grep gates: forbidden/required strings in `doc_contract_test.exs` (Phase 37 D-15)
- Persona-driven adoption docs referenced in ROADMAP success criteria and SEED-004

### Integration Points
- Golden-path §7 "What's next" and journey guide "Next Steps" — add links to new recipes
- `mix.exs` `docs/[:extras]` — register new recipe files for HexDocs
- `test/chimeway/doc_contract_test.exs` — extend with recipe file assertions (D-15 stretch)

</code_context>

<specifics>
## Specific Ideas

- Milestone assessment gap: "no documented support engineer traces a password reset walkthrough" — RECP-01 directly closes this
- Demo host proves webhooks only; feedback recipe narrates the E2E test for Product Manager persona without requiring provider webhook setup
- Password reset is the canonical Support Operator JTBD quote from SEED-004: "A user says they didn't get their password reset email. Why?"

</specifics>

<deferred>
## Deferred Ideas

- **Demo host trace inspection path (IEx/script/minimal route without webhooks)** — Phase 39 (DEMO-01)
- **Operator LiveView trace UI (`chimeway_admin`)** — Phase 40 (OPER-01, OPER-02)
- **Full GATE-01 automated doc-contract CI matrix** — Phase 41
- **Policy-and-preferences guide full rewrite** — out of scope; RECP-01 may note stub status and link
- **Read/unread auto-branching (`pending_signals` on wait entry, notification_read cancel)** — deferred READ milestone
- **Additional reference flows beyond these two (magic link, drip campaigns, SEED-003 blueprints)** — future milestone backlog

</deferred>

---

*Phase: 38-reference-recipes*
*Context gathered: 2026-05-28*

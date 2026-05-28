# Phase 37: Doc Truth & Journey Guides - Context

**Gathered:** 2026-05-28 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Workflow/journey documentation matches engine capabilities so adopters are not misled by aspirational APIs. Delivers DOCS-03: rewrite `guides/flows/multi-step-journeys.md` to describe `wait_until`, `on_outcome`/`stop` progression, and signal routing as implemented; resolve INV-002 via doc-truth (not engine changes); add lightweight doc-contract verification for journey guide API references. Does not implement `pending_signals` population on `wait_until` entry (READ milestone), reference recipes (Phase 38), full GATE-01 CI automation (Phase 41), or engine/API changes.

</domain>

<decisions>
## Implementation Decisions

### INV-002 resolution — doc-truth, not engine
- **D-01:** Resolve INV-002 by correcting journey documentation to match the engine. Do NOT implement `pending_signals` population in `enter_waiting/6` or read→signal auto-wiring in this phase — that belongs to the deferred READ milestone (READ-01/READ-02).
- **D-02:** Any aspirational read/unread early-exit behavior (`stop_conditions`, `notification_read` cancel-on-read) is removed from the primary guide flow and moved to an explicit **Deferred / Future** callout citing the engine gap (`enter_waiting` does not set `pending_signals`; `route_signal/1` only matches runs with `pending_signals` populated).

### Journey guide rewrite (`guides/flows/multi-step-journeys.md`)
- **D-03:** Full rewrite using the real authoring surface: Notifier `@callback workflow/2` returning `{:ok, %{workflow_key:, workflow_version:, steps: [...]}}` — not a fictional `Chimeway.Workflow` behaviour module.
- **D-04:** Step progression rules live in each step's `config["progress"]` array with normalized rule kinds: `wait_until`, `on_outcome`, and `stop`. Remove all references to `stop_conditions`, `type: :wait`, ISO 8601 duration strings, and separate wait-step actions — these do not exist in the engine.
- **D-05:** Primary worked example: time-based channel escalation matching test fixtures — `in_app` step with `wait_until` rule (`anchor: "prior_delivery_terminal_at"`, `delay_seconds`, `to_step: "email"`) → `email` step. This is the canonical “missed engagement → escalate” story for v1.5 docs.
- **D-06:** Trigger examples use `Chimeway.trigger/3` with required `idempotency_key` and tenant opts — not `Chimeway.Trigger.trigger/3` with wrong arity.
- **D-07:** Signal examples use correct `Chimeway.Signal.track/4` signature: `track(tenant_id, actor_id, event_name, payload \\ %{})` — not reversed tenant/actor argument order.

### Progression semantics documentation
- **D-08:** Document `wait_until` behavior as implemented: run enters `:waiting` with `status_reason: "waiting_for_step_progression"`, `status_context` carries `due_at`, `to_step`, anchor delivery metadata; past-due advancement via `Chimeway.Workflows.Progression.progress_run/2` (Oban-scheduled `WorkflowProgressionWorker` in production).
- **D-09:** Document `on_outcome` and `stop` rules with the curated outcome vocabulary from `ProgressionOutcome`: `delivered`, `suppressed`, `temporary_failure`, `retries_exhausted`, `permanent_failure`, `bounced`. Include the `temporary_failure` early-fire warning from `Chimeway.Notifier` moduledoc (fires on first `:failed`, not after retries exhausted — use `retries_exhausted` when that is the intent).
- **D-10:** Document operator inspection via `Chimeway.Workflows.explain/2` and `Chimeway.Workflows.list_traces/2` for run state and transition history — aligned with explainability product value.

### Signal routing documentation
- **D-11:** Document delivery-feedback signal routing as the proven production path: webhook ingress → `ProcessFeedbackWorker` → `Chimeway.Signal.track/4` with canonical `chimeway.delivery.{succeeded,bounced,failed}` event names → `SignalRouterWorker` → `Workflows.route_signal/1` → `on_outcome`/`stop` progression. Cross-link `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` and golden-path webhook appendix (`guides/introduction/golden-path.md`).
- **D-12:** Document generic signal routing honestly: `route_signal/1` matches `:waiting` runs whose `pending_signals` list contains the signal's `event_name`. Today, `enter_waiting/6` does not populate `pending_signals` — host applications must wire signal expectations explicitly until READ milestone ships. Do not document read-to-cancel as working out of the box.

### Related doc fixes
- **D-13:** Fix Oban worker module paths in journey guide and `guides/recipes/oban-integration.md`: `Chimeway.Dispatch.WorkflowProgressionWorker` and `Chimeway.Dispatch.SignalRouterWorker` — not `Chimeway.Workflows.Workers.*`.
- **D-14:** Align oban-integration recipe cron/queue guidance with actual dispatch worker modules and queue names (`chimeway_workflows`, `chimeway_signals` per existing recipe — verify against `lib/chimeway/dispatch/` at plan time).

### Doc-contract verification (DOCS-03 criterion #3)
- **D-15:** Add lightweight journey-guide doc-contract test (new file or extend `test/chimeway/doc_contract_test.exs`) with static assertions that `guides/flows/multi-step-journeys.md` references only existing public modules/APIs — e.g., forbids `Chimeway.Workflow`, `stop_conditions`, wrong worker namespaces; requires `Chimeway.trigger/3`, `Chimeway.Signal.track/4`, `wait_until`/`on_outcome`/`stop` rule kinds.
- **D-16:** Ship phase `37-VALIDATION.md` manual checklist mirroring Phase 36 pattern (grep gates on edited guides + `mix test` for doc-contract test + `mix ci.docs`). Full automated GATE-01 doc-contract matrix remains Phase 41 scope.

### Claude's Discretion
- Exact section headings and narrative tone in rewritten journey guide
- Whether to add a minimal inline Elixir snippet vs link-only for demo host E2E
- Specific grep patterns and assertion count in doc-contract test
- Whether oban-integration fixes land in same commit wave as journey guide or a dedicated plan task
- CHANGELOG entry for doc-only changes

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and scope
- `.planning/ROADMAP.md` — Phase 37 goal, success criteria, DOCS-03 mapping
- `.planning/REQUIREMENTS.md` — DOCS-03 acceptance criteria; READ milestone deferral table
- `.planning/PROJECT.md` — Adoption Surface intent; defer read/unread branching decision
- `.planning/STATE.md` — INV-002 open investigation
- `.planning/threads/2026-05-28-v1.5-milestone-assessment.md` — Journey guide drift evidence
- `.planning/phases/36-golden-path-version-alignment/36-CONTEXT.md` — Golden-path webhook appendix cross-link target (D-09/D-10)

### Guides to fix
- `guides/flows/multi-step-journeys.md` — Primary deliverable; currently aspirational/wrong
- `guides/recipes/oban-integration.md` — Wrong worker module paths; journey execution dependency
- `guides/introduction/golden-path.md` — Webhook feedback cross-link source

### Engine source of truth (for doc accuracy)
- `lib/chimeway/notifier.ex` — `workflow/2` callback, progress rule normalization (`wait_until`, `on_outcome`, `stop`), `@progress_outcomes`, `@progress_wait_anchors`
- `lib/chimeway/workflows/progression.ex` — `progress_run/2`, `enter_waiting/6`, wait elapse advancement
- `lib/chimeway/workflows/progression_outcome.ex` — Curated outcome vocabulary and early-fire warnings
- `lib/chimeway/workflows.ex` — `route_signal/1`, `explain/2`, `list_traces/2`, `pending_signals` query contract
- `lib/chimeway/signal.ex` — `Chimeway.Signal.track/4` public API
- `lib/chimeway/dispatch/workflow_progression_worker.ex` — Oban wait-elapse worker
- `lib/chimeway/dispatch/signal_router_worker.ex` — Oban signal routing worker
- `lib/chimeway/trigger.ex` / `lib/chimeway.ex` — `Chimeway.trigger/3` entrypoint

### Test fixtures (canonical examples for guide snippets)
- `test/chimeway/orchestration/workflow_progression_test.exs` — `wait_until` + `on_outcome` notifier fixture
- `test/chimeway/workflows_test.exs` — `route_signal/1` + `pending_signals` matching
- `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` — Delivery feedback → signal → progression E2E

### Doc-contract patterns
- `test/chimeway/doc_contract_test.exs` — Existing minimal doc-contract test (moduledoc only)
- `.planning/phases/36-golden-path-version-alignment/36-VALIDATION.md` — Checklist pattern to mirror

### Methodology
- `.planning/METHODOLOGY.md` — Least-Surprise DX Default, Durable Explainability Bias, One-Shot Recommendation Bias

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/chimeway/orchestration/workflow_progression_test.exs` — Copy-adaptable notifier `workflow/2` fixture for guide examples (`wait_until` + `on_outcome` on same step)
- `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` — Runnable proof for delivery-feedback signal → progression path
- `lib/chimeway/notifier.ex` moduledoc — Authoritative progress rule shapes and WR-02 early-fire warning text to reuse/link
- `lib/chimeway/workflows/progression.ex` moduledoc — Accurate description of waiting/advanced/noop semantics for guide prose
- `test/chimeway/doc_contract_test.exs` — Extend or sibling for journey guide static assertions

### Established Patterns
- Guides under `guides/flows/` registered in `mix.exs` docs extras — rewrite is publishable without structural changes
- Phase 36 doc phases use manual grep checklist + spot `mix ci.docs` — Phase 37 follows same until Phase 41 GATE-01
- Doc examples must match real callback APIs — Phase 36 established this for golden-path/README; journey guide is the remaining major violator
- Explainability surfaces: `Chimeway.Traces.explain_delivery/1` for delivery spine; `Chimeway.Workflows.explain/2` for run state

### Integration Points
- `guides/flows/multi-step-journeys.md` — Primary rewrite target
- `guides/recipes/oban-integration.md` — Worker name corrections; cron scheduling for `WorkflowProgressionWorker`
- `guides/introduction/golden-path.md` — Cross-link for webhook feedback loop (already has brief appendix from Phase 36)
- `mix.exs` `docs/[:extras]` — Journey guide already listed; no registration change expected
- Future Phase 38 recipes will build on corrected journey guide as foundation

</code_context>

<specifics>
## Specific Ideas

- User confirmed all assumptions without corrections (assumptions mode, 2026-05-28)
- Doc-truth over engine fix for INV-002 — consistent with v1.5 scope and assessment recommendation
- Primary escalation story is time-based (`wait_until`), not read-to-cancel — read-driven branching explicitly deferred with engine gap callout
- Delivery-feedback webhook path is the “working signal routing” story to emphasize over aspirational inbox-read signals

</specifics>

<deferred>
## Deferred Ideas

- **`pending_signals` auto-population on `wait_until` entry** — READ milestone (READ-01); engine work, not Phase 37
- **Inbox read/seen → `notification_read` signal → cancel escalation** — READ milestone (READ-02); document as future, not current capability
- **Reference recipes (password-reset trace, feedback escalation walkthrough)** — Phase 38 (RECP-01, RECP-02)
- **Full GATE-01 automated doc-contract CI matrix** — Phase 41
- **`Chimeway.Workflow` behaviour module** — Not planned; workflows authored via Notifier callback only
- **Engine/API changes of any kind** — Out of scope for v1.5 adoption surface phases

</deferred>

---

*Phase: 37-doc-truth-journey-guides*
*Context gathered: 2026-05-28*

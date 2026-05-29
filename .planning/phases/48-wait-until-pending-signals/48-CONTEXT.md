# Phase 48: `wait_until` Pending Signals - Context

**Gathered:** 2026-05-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Close READ-01: when a workflow run enters `:waiting` via a `wait_until` progress rule, the engine automatically persists canonical `pending_signals` derived from that rule's configuration — so `SignalRouterWorker` / `route_signal/1` can match injected signals without host glue.

**In scope:** `enter_waiting` population of `pending_signals`, optional `cancel_signals` DSL on `wait_until` rules, notifier normalization, progression tests, doc-truth update for READ-01 gap in the journey guide.

**Out of scope:** `mark_read` / `mark_seen` signal emission (READ-02, Phase 49), read-cancel escalation semantics / JOUR-06 (Phases 49–51), demo seed refactor (Phase 50), mention-escalation recipe rewrite (DEMO-04, Phase 50).

</domain>

<decisions>
## Implementation Decisions

### Implementation seam
- **D-01:** Populate `pending_signals` inside `enter_waiting/6` in `lib/chimeway/workflows/progression.ex`, in the same `Repo.transaction` that sets `state: :waiting`, `status_reason`, and `status_context`.
- **D-02:** Do not change `route_signal/1` matching logic — it already queries `pending_signals`; Phase 48 only ensures waiting runs have the list set at entry.

### Progress-rule DSL
- **D-03:** Extend `wait_until` progress rules with an optional `cancel_signals` key (array of non-empty strings). When present, `enter_waiting` copies that list into `WorkflowRun.pending_signals`. When omitted, persist `[]` (time-only waits behave exactly as today).
- **D-04:** Update `normalize_wait_until_rule/1` in `lib/chimeway/notifier.ex` to accept and validate `cancel_signals` alongside existing keys (`kind`, `anchor`, `delay_seconds`, `to_step`). Reject unknown extra keys per existing mixed-rule-shape guardrails.

### Canonical event names
- **D-05:** Document `chimeway.notification.read` and `chimeway.notification.seen` as the canonical `cancel_signals` values for inbox-driven early exit. Phase 48 does **not** wire `Chimeway.mark_read/3` or `mark_seen/3` to emit these events — that is READ-02 (Phase 49).
- **D-06:** Do not auto-default inbox read/seen signals for all `wait_until` waits; authors must declare `cancel_signals` explicitly when they want signal-driven early exit.

### Post-signal behavior (boundary)
- **D-07:** Phase 48 does not change `route_signal/1` post-match behavior (`:waiting` → `:active`, `signal_received` transition, clear `pending_signals`). Read-cancel semantics that halt escalation before `due_at` (READ-03, JOUR-06) belong in Phase 49+.
- **D-08:** Phase 48 success proof: a waiting run with auto-populated `pending_signals` matches an injected signal via `SignalRouterWorker` without host `update_run` glue (mirrors existing `workflows_test.exs` / `feedback_pipeline_e2e_test.exs` patterns).

### Doc-truth
- **D-09:** Update `guides/flows/multi-step-journeys.md` in this phase — remove the READ-01 engine-gap callout, document `cancel_signals` on `wait_until`, show canonical inbox event names. Defer mention-escalation recipe rewrite to Phase 50 (DEMO-04).

### Claude's Discretion
- Exact validation rules for `cancel_signals` entries (min length, deduplication, max count).
- Whether to mirror `cancel_signals` into `status_context` for operator trace visibility (optional; not required if `explain/2` already surfaces `pending_signals`).
- Test fixture notifier shape for progression/orchestration tests exercising auto-population.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/ROADMAP.md` — Phase 48 goal, success criteria, dependency on v1.6 workflow engine
- `.planning/REQUIREMENTS.md` — READ-01 acceptance criteria
- `.planning/PROJECT.md` — v1.7 READ milestone scope, deferred read/unread decision history
- `.planning/METHODOLOGY.md` — research-first, durable explainability, least-surprise DX lenses

### Engine implementation
- `lib/chimeway/workflows/progression.ex` — `enter_waiting/6` (primary change seam)
- `lib/chimeway/workflows.ex` — `route_signal/1`, `find_runs_waiting_for_signal/3` (existing matching; no behavioral change expected)
- `lib/chimeway/workflows/workflow_run.ex` — `pending_signals` field schema
- `lib/chimeway/notifier.ex` — `normalize_wait_until_rule/1`, progress-rule DSL validation
- `lib/chimeway/dispatch/signal_router_worker.ex` — async signal routing entrypoint
- `lib/chimeway/signal.ex` — `track/4` for test signal injection

### Docs & contracts
- `guides/flows/multi-step-journeys.md` — READ-01 gap callout to remove; `wait_until` authoring reference
- `guides/recipes/feedback-escalation-workflow.md` — delivery-feedback signal routing pattern (`chimeway.delivery.*`)
- `guides/recipes/oban-integration.md` — `SignalRouterWorker` queue documentation
- `test/chimeway/doc_contract_test.exs` — doc-truth contract tests (update if journey guide changes)

### Test patterns
- `test/chimeway/orchestration/workflow_progression_test.exs` — `wait_until` entry and due-at advancement fixtures
- `test/chimeway/workflows_test.exs` — `route_signal/1` matching and transition trace assertions
- `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` — E2E signal → waiting run match (manual `pending_signals` today; replace with auto-population proof)

### Host glue to retire (downstream phases)
- `examples/chimeway_demo_host/lib/demo_host/seeds.ex` — `stage_escalation_webhook/1` manual `pending_signals` assignment (Phase 50 demo refactor)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `WorkflowRun.pending_signals` — `{:array, :string}` column already migrated (`priv/chimeway_migrations/027_create_chimeway_signals_and_spine.exs`); default `[]`.
- `Chimeway.Workflows.route_signal/1` — full match + atomic transition path; tests in `workflows_test.exs` and `signal_router_worker_test.exs`.
- `Chimeway.Workflows.Progression.enter_waiting/6` — sets `:waiting`, `status_context` with `due_at`/`to_step`; only missing `pending_signals` assignment.
- `Chimeway.Notifier` progress-rule normalization — strict per-kind key allowlists; extend `wait_until` allowlist for `cancel_signals`.

### Established Patterns
- Progress rules are persisted JSON on `WorkflowStep.config["progress"]`; one shape per kind enforced at notifier normalization time.
- Waiting transitions use `status_reason: "waiting_for_step_progression"` and curated `status_context` (no raw payloads).
- Signal routing matches on `tenant_id` + `recipient_identity` (actor) + `event_name in pending_signals` + `state == :waiting`.
- Canonical delivery signals use `chimeway.delivery.*` namespace; inbox signals should follow `chimeway.notification.*` for consistency.

### Integration Points
- `enter_waiting/6` → `Workflows.update_run/3` — add `pending_signals` to the same update map.
- `normalize_wait_until_rule/1` → persisted step config → read by progression engine at runtime.
- `SignalRouterWorker` → `route_signal/1` — no change; becomes usable without host `update_run` once population ships.
- Journey guide + doc-contract tests — document and lock the new `cancel_signals` DSL.

</code_context>

<specifics>
## Specific Ideas

No user corrections — all assumptions confirmed as-is.

</specifics>

<deferred>
## Deferred Ideas

- **READ-02 / inbox signal emission** — Wire `Chimeway.mark_read/3` and `mark_seen/3` to `Signal.track/4` with canonical event names (Phase 49).
- **Read-cancel escalation halt** — Prevent `due_at` advancement after read signal; `signal_received` → stop or complete semantics (READ-03, Phase 49; JOUR-06, Phase 51).
- **Demo seed choreography removal** — Replace `stage_escalation_webhook/1` with READ-driven TeamPulse escalation (Phase 50).
- **Mention-escalation recipe** — Document read-cancel + `wait_until` fallback as canonical PM JTBD path (DEMO-04, Phase 50).

None — analysis stayed within phase scope.

</deferred>

---

*Phase: 48-`wait_until` Pending Signals*
*Context gathered: 2026-05-29 (assumptions mode)*

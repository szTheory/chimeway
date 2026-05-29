# Phase 50: Natural Escalation Demo - Context

**Gathered:** 2026-05-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace staged webhook choreography in the TeamPulse payment-escalation demo with READ-driven workflow progression, and publish a mention-escalation reference recipe documenting read-cancel plus time-based `wait_until` fallback as the canonical PM JTBD path.

**In scope:** Refactor `DemoHost.Notifiers.PaymentReminder` workflow to `wait_until` + `cancel_signals`; simplify `DemoHost.Seeds` escalation path (remove `stage_escalation_webhook/1` and `PendingWebhookAdapter` swap); rewrite JOUR-03 to prove `mark_read` → signal → resume; create `guides/recipes/mention-escalation.md`; align `multi-step-journeys.md` intro with read-cancel + wait_until pattern; extend doc-contract tests.

**Out of scope:** JOUR-06 time-elapse escalation proof (Phase 51), JOUR-07/JOUR-08 admin persona journeys (Phase 51), README webhook-contradiction fix (Phase 52 DOCS), engine changes to `route_signal/1` or progression post-match behavior (Phases 48–49 locked), `feedback_pipeline_e2e_test.exs` webhook proof (retain as delivery-feedback reference).

</domain>

<decisions>
## Implementation Decisions

### PaymentReminder workflow redesign (DEMO-03)
- **D-01:** Refactor `DemoHost.Notifiers.PaymentReminder` from webhook-driven progression (`chimeway.delivery.succeeded`) to the mention-escalation pattern: `in_app` step with `wait_until` (`delay_seconds: 7200`, `to_step: "email_escalation"`) and `cancel_signals: ["chimeway.notification.read"]`, followed by an `email` escalation step. Morgan persona keeps payment-reminder copy; workflow mechanics match PM JTBD ("if they don't open in 2 hours, send email").

### Seed simplification (DEMO-03)
- **D-02:** `seed_escalation_waiting/0` becomes trigger-only — call `Chimeway.trigger/3` with `PaymentReminder` and return the normalized result. Delete `stage_escalation_webhook/1` and remove the temporary `PendingWebhookAdapter` `Application.put_env` swap. Natural engine progression after in_app delivery succeeds leaves the run `:waiting` with auto-populated `pending_signals` from `cancel_signals`.

### JOUR-03 journey test rewrite (DEMO-03)
- **D-03:** Rewrite JOUR-03 from webhook POST to READ-driven path: seed escalation → identify in_app notification → `Chimeway.mark_read/3` → drain `:chimeway_signals` → assert run transitions `:waiting` → `:active` with `signal_received` transition (`event_name` only in context). Time-elapse escalation (email fires after `due_at`) is deferred to JOUR-06 (Phase 51); webhook progression remains covered by `feedback_pipeline_e2e_test.exs`.

### Mention-escalation recipe (DEMO-04)
- **D-04:** Create `guides/recipes/mention-escalation.md` as a PM persona walkthrough for read-cancel plus `wait_until` time fallback — distinct from `guides/recipes/feedback-escalation-workflow.md` (delivery-feedback / webhook path). Update `guides/flows/multi-step-journeys.md` § "Missed Engagement Escalation" intro (line 7) to position read-cancel and `wait_until` as complementary mechanisms, not mutually exclusive.

### PendingWebhookAdapter removal
- **D-05:** Delete `DemoHost.Adapters.PendingWebhookAdapter` once seeds no longer reference it. No deprecation shim — the module exists solely to support removed choreography.

### Doc contract extension
- **D-06:** Extend `test/chimeway/doc_contract_test.exs` to lock mention-escalation recipe truth (read-cancel + `wait_until` fallback pattern), mirroring Phase 48–49 doc-contract patterns. Cross-link new recipe from `multi-step-journeys.md` and relevant index surfaces if present.

### Claude's Discretion
- Exact `step_key` names and channel ordering in refactored `PaymentReminder` workflow (must satisfy D-01 semantics).
- Whether JOUR-03 asserts `pending_signals` contents on the waiting run before `mark_read`.
- Doc-contract `@required_phrases` / `@forbidden_phrases` exact strings for the new recipe.
- PaymentReminder moduledoc and `seeds.ex` `@moduledoc` scenario descriptions after refactor.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/ROADMAP.md` — Phase 50 goal, success criteria, dependency on Phase 49
- `.planning/REQUIREMENTS.md` — DEMO-03, DEMO-04 acceptance criteria
- `.planning/PROJECT.md` — v1.7 READ milestone scope, TeamPulse persona model
- `.planning/METHODOLOGY.md` — research-first, cohesive recommendation lenses

### Prior phase context
- `.planning/phases/48-wait-until-pending-signals/48-CONTEXT.md` — `cancel_signals` DSL, `enter_waiting` auto-population (D-03, D-06)
- `.planning/phases/49-inbox-read-signal/49-CONTEXT.md` — inbox signal emission, canonical event names (D-01, D-03)

### Demo host — primary change seams
- `examples/chimeway_demo_host/lib/demo_host/notifiers/payment_reminder.ex` — workflow refactor (D-01)
- `examples/chimeway_demo_host/lib/demo_host/seeds.ex` — seed simplification, delete `stage_escalation_webhook/1` (D-02)
- `examples/chimeway_demo_host/lib/demo_host/adapters/pending_webhook_adapter.ex` — delete (D-05)
- `examples/chimeway_demo_host/test/demo_host_web/journey_test.exs` — JOUR-03 rewrite (D-03)

### Docs — create / update
- `guides/recipes/mention-escalation.md` — **create** PM persona recipe (DEMO-04, D-04)
- `guides/flows/multi-step-journeys.md` — mention-escalation example + intro alignment (D-04)
- `guides/recipes/feedback-escalation-workflow.md` — webhook path reference (do not conflate with READ recipe)

### Test patterns
- `test/chimeway/orchestration/workflow_progression_test.exs` — `mark_read resumes waiting run` describe block (READ-02/03 proof pattern for JOUR-03)
- `test/chimeway/doc_contract_test.exs` — doc-truth contract extension (D-06)
- `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` — webhook progression proof (retain, out of JOUR-03 scope)

### Engine (read-only — no behavioral changes)
- `lib/chimeway/workflows/progression.ex` — `enter_waiting/6` `cancel_signals` → `pending_signals`
- `lib/chimeway/inbox.ex` — `mark_read/3` signal emission
- `lib/chimeway/workflows.ex` — `route_signal/1` matching

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Notifiers.PaymentReminder` — Morgan persona notifier; channels `[:in_app, :email]` already declared; workflow callback is the refactor seam.
- `DemoHost.Seeds` — idempotent `trigger/3` wrapper with duplicate normalization; escalation scenario is third seed in `run/0`.
- Mention-escalation workflow shape in `guides/flows/multi-step-journeys.md` — canonical `wait_until` + `cancel_signals` example to mirror in PaymentReminder.
- `workflow_progression_test.exs` — `trigger_workflow_with_signals!/1` fixture and mark_read → SignalRouterWorker → resume assertions.

### Established Patterns
- Phase 48: `enter_waiting/6` auto-populates `pending_signals` from `cancel_signals` on `wait_until` entry.
- Phase 49: `Chimeway.mark_read/3` emits `chimeway.notification.read` on first transition; `signal_received` transition carries `event_name` only.
- Signal-driven early exit resumes run to `:active` without advancing to `to_step`; time-elapse path (`advance_after_wait`) creates next-step delivery.
- Journey tests tagged `:journey` for `mix verify.journeys`; use Oban drain pattern from existing JOUR-03.

### Integration Points
- `PaymentReminder.workflow/2` → progression after in_app terminal → `:waiting` with `pending_signals`.
- `DemoHost.Seeds.seed_escalation_waiting/0` → trigger only → returns notification/trace for admin search (Morgan).
- JOUR-03 → `mark_read` on seeded in_app notification → journey proof of READ-driven demo story.
- New recipe links from journey guide; doc contract enforces recipe truth in CI.

</code_context>

<specifics>
## Specific Ideas

No user corrections — all assumptions confirmed as-is.

</specifics>

<deferred>
## Deferred Ideas

- **JOUR-06 time-elapse proof** — mark_read cancels escalation before `wait_until` due_at; email fires only when unread (Phase 51).
- **README webhook contradiction** — demo host README still says "Payment escalation awaiting webhook" and "Not this path: webhook progression" (Phase 52 DOCS).
- **Admin Morgan escalation trace** — JOUR-08 admin journey (Phase 51).

None — analysis stayed within phase scope.

</deferred>

---

*Phase: 50-Natural Escalation Demo*
*Context gathered: 2026-05-29 (assumptions mode)*

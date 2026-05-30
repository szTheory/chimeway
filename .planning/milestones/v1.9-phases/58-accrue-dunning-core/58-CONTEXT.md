# Phase 58: Accrue Dunning Core - Context

**Gathered:** 2026-05-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Accrue billing events drive Chimeway dunning **workflow lifecycle** without host glue: `invoice.payment_failed` starts a multi-step escalation run with explainable traces; payment success terminates the active run via Outcome Signal (`invoice.paid`).

**In scope:** Workflow + Signal integration, optional `accrue` dep in Chimeway, test harness (`@moduletag :accrue`), cross-repo upgrades to `Accrue.Integrations.Chimeway` / `DunningNotifier`.

**Out of scope (later phases):** Reference recipe + doc-contract (Phase 59 ECOS-07), demo host proof + operator traces (Phase 59 DEMO-07), golden-path guide + `mix verify.accrue` release gate (Phase 60).

**Depends on:** v1.8 workflow spine, Signal engine, Mailglass adapter optional for email steps.

**Requirements:** ECOS-06
</domain>

<decisions>
## Implementation Decisions

### Integration seam (not `Chimeway.Adapter`)
- **D-01:** Phase 58 delivers a **workflow + Signal bridge** only — no `Chimeway.Adapter` delivery seam. Accrue owns billing state and dunning engine dispatch; Chimeway owns orchestration (when/why, escalations, explainability).
- **D-02:** Host wiring remains runtime config: `{:chimeway, "~> 1.0"}` + `config :accrue, dunning: [engine: Accrue.Integrations.Chimeway]` — mirror Mailglass optional-dep pattern, not compile-time coupling.

### Cross-repo ownership
- **D-03:** Phase 58 spans **Accrue + Chimeway**. Accrue ships the engine seam today (`Accrue.Integrations.Chimeway`) in v1.40 **email-only `:immediate`** mode (no `workflow/2`, no WorkflowRun). Phase 58 upgrades Accrue's `DunningNotifier` and `cancel_campaign/3`; Chimeway adds integration tests and selective CI lane.
- **D-04:** Do **not** duplicate `Accrue.Dunning.Engine` anchor/idempotency semantics inside Chimeway core — `start_campaign/3` remains the single entry for failed-payment triggers.

### Start path (`invoice.payment_failed` → workflow run)
- **D-05:** Failed payment still enters via **`Accrue.Integrations.Chimeway.start_campaign/3` → `Chimeway.trigger/3`** with stable idempotency key `accrue.dunning:{subscription_id}:{anchor_iso}`.
- **D-06:** `DunningNotifier` gains **`workflow/2`**: multi-step dunning (initial email → `wait_until` escalation, e.g. 48h per SEED-003) and **non-`:immediate`-only** orchestration so `Trigger` creates a `WorkflowRun` with explainable progression.
- **D-07:** Email channel steps may use existing Mailglass adapter when host configures it; Phase 58 does not require a new outbound seam.

### Termination (`invoice.paid` / Outcome Signal)
- **D-08:** Termination uses **`Chimeway.Signal.track/4` + `cancel_signals: ["invoice.paid"]`** on dunning `wait_until` steps — same READ/cancel pattern as `chimeway.notification.read` (resume from `:waiting`, block further escalation).
- **D-09:** `cancel_campaign/3` must emit **`invoice.paid`** (canonical ECOS-06 / ROADMAP string) with **`actor_id` = customer email** (`recipient_identity`), replacing today's `"payment_recovered"` / `"accrue.dunning"` pair that routes to zero runs.
- **D-10:** Accrue anchor-clear on recovery remains the backstop preventing duplicate `start_campaign` calls; Chimeway signal routing is the workflow-termination path for in-flight runs.

### Test harness & CI (Wave 58-01)
- **D-11:** Chimeway copies Mailglass selective-CI: `{:accrue, "~> 1.2", optional: true}`, `@moduletag :accrue`, exclude `:accrue` from default `ci.test`, dedicated `mix verify.accrue` alias (GATE-05 wiring in Phase 60).
- **D-12:** Integration tests prove event → workflow start and event → signal termination using **`Accrue.Test.trigger_event/2`** (and Accrue Fake processor) — no host callback glue in test path.
- **D-13:** Phase 58 tests live in Chimeway repo; demo host Accrue proof deferred to Phase 59.

### Claude's Discretion
- Exact dunning step keys, `delay_seconds`, and render keys for `DunningNotifier` (planner/researcher align with SEED-003 48h escalation example).
- Whether `orchestration/2` returns default workflow mode vs per-channel map once `workflow/2` exists.
- Test-support shim location (`test/support/accrue_*` vs path-dep demo host) — follow Mailglass precedent.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

| Ref | Path | Why |
|-----|------|-----|
| Phase goal | `.planning/ROADMAP.md` (Phase 58) | Success criteria, waves 58-01..03, cross-cutting constraints |
| Requirement | `.planning/REQUIREMENTS.md` (ECOS-06) | Locked acceptance: payment_failed start, invoice.paid terminate, no host glue |
| SEED-003 Accrue slice | `.planning/seeds/SEED-003-ecosystem-integrations.md` | Dunning blueprint intent (48h escalation, billing-state split) |
| Accrue ↔ Chimeway engine | `../accrue/accrue/lib/accrue/integrations/chimeway.ex` | Existing `start_campaign` / `cancel_campaign` / `DunningNotifier` v1.40 baseline |
| Signal API | `lib/chimeway/signal.ex` | `Chimeway.Signal.track/4` contract |
| Signal routing | `lib/chimeway/workflows.ex` (`route_signal/1`) | `pending_signals` + `recipient_identity` matching |
| Wait + cancel_signals | `lib/chimeway/workflows/progression.ex` (`enter_waiting/6`) | How `cancel_signals` populate `pending_signals` |
| Workflow trigger | `lib/chimeway/trigger.ex` | `Chimeway.trigger/3` + workflow run creation |
| Reference workflow pattern | `examples/chimeway_demo_host/lib/demo_host/notifiers/payment_reminder.ex` | `wait_until` + `cancel_signals` authoring example |
| Mailglass CI pattern | `mix.exs` (`verify.mailglass`, `ci.test` exclude) | Template for `verify.accrue` / `@moduletag :accrue` |
| v1.9 planning decisions | `.planning/STATE.md` | Mailglass-first template; research skipped for Accrue |
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Chimeway.Signal.track/4`** + **`SignalRouterWorker`** — durable signal persist + async route to waiting runs.
- **`Workflows.route_signal/1`** — matches `:waiting` runs by `tenant_id`, `recipient_identity` (actor_id), and `pending_signals`.
- **`enter_waiting/6`** — auto-populates `pending_signals` from `cancel_signals` on `wait_until` rules (v1.7 READ spine).
- **`Chimeway.trigger/3`** — idempotent workflow start with explainable traces.
- **`payment_reminder` notifier** — in-repo multi-step workflow authoring reference (not Accrue-specific).
- **`Accrue.Integrations.Chimeway`** (sibling repo) — `Accrue.Dunning.Engine` implementation, `DunningNotifier`, idempotency key scheme already defined.

### Established Patterns
- **Optional ecosystem dep:** `Code.ensure_loaded?/1` gate (Mailglass in `lib/chimeway/adapters/mailglass.ex`; Accrue in `accrue/lib/accrue/integrations/chimeway.ex`).
- **Not an adapter:** ROADMAP explicitly excludes `Chimeway.Adapter` for Accrue — workflow/signal only.
- **Selective CI:** `@moduletag :mailglass` + `mix verify.mailglass` — replicate for `:accrue`.
- **Signal semantics:** External signals resume `:waiting` runs; they do not directly set `:stopped`/`:completed` unless progression rules say so (JOUR-06 read-cancel pattern).

### Integration Points
- **Accrue → Chimeway start:** `Accrue.Integrations.Chimeway.start_campaign/3` → `Chimeway.trigger(DunningNotifier, ...)`.
- **Accrue → Chimeway stop:** `cancel_campaign/3` → `Chimeway.Signal.track(tenant_id, recipient_email, "invoice.paid", ...)`.
- **Chimeway → Mailglass (optional):** Email step delivery via host-configured adapter when Accrue/Chimeway dunning emails use Mailglass.
- **Tests:** `Accrue.Test.trigger_event(:invoice_payment_failed, invoice)` / paid recovery — Accrue event type `invoice.payment_failed` per webhook layer.
</code_context>

<specifics>
## Specific Ideas

- Product language "Outcome Signal" = durable **`invoice.paid`** signal that satisfies `cancel_signals` on active dunning waits (not a new DSL).
- SEED-003 escalation shape: Email 1 → wait 48h → Email 2 — implement in `DunningNotifier.workflow/2`.
- Operator trace inspectability at `/admin/chimeway` is Phase 59 — Phase 58 only needs library-level explainable workflow transitions.
</specifics>

<deferred>
## Deferred Ideas

- **Signal-driven `:stopped`/`:completed` API** — only if cancel_signals + resume proves insufficient for "terminate" acceptance; evaluate during planning against ECOS-06 success criteria.
- **Demo host Accrue dunning proof** — Phase 59 (DEMO-07).
- **Reference recipe + doc-contract** — Phase 59 (ECOS-07).
- **Golden-path guide + `mix verify.accrue` CI job + MAINTAINING** — Phase 60 (DOCS-08/09, GATE-05).
- **Rename `payment_recovered` → `invoice.paid` in Accrue-only docs** — if any Accrue-internal event naming diverges from Chimeway `pending_signals`, document in plan; do not silently alias without test proof.
</deferred>

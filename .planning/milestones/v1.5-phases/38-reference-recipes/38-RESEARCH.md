# Phase 38: Reference Recipes — Research

**Researched:** 2026-05-28  
**Phase:** 38-reference-recipes  
**Requirements:** RECP-01, RECP-02  
**Status:** Ready for plan-phase

---

## user_constraints

Locked decisions from `38-CONTEXT.md` (D-01 through D-16) — **non-negotiable**:

| ID | Constraint |
|----|------------|
| D-01 | Both recipes as markdown under `guides/recipes/` (not `examples/` apps) |
| D-02 | Register both files in `mix.exs` `docs/[:extras]` under existing Recipes group |
| D-03–D-07 | RECP-01 at `guides/recipes/password-reset-support-trace.md` — Feature Developer (notifier + `Chimeway.trigger/3`) + Support Operator (`find_traces_for_recipient/2`, `explain_delivery/1`, three diagnostic branches) |
| D-08–D-12 | RECP-02 at `guides/recipes/feedback-escalation-workflow.md` — workflow/2 + feedback loop narrative + demo E2E cross-links (progress + stop paths) |
| D-13–D-14 | "Who this is for" with SEED-004 JTBD quotes; clear doc hierarchy vs golden-path / tracing / journey |
| D-15 | Extend `doc_contract_test.exs` for both recipe files (forbidden/required strings) |
| D-16 | Docs-only — no engine or demo host feature work |

**Claude's discretion:** section headings, table vs prose diagnostics, IEx snippet depth, inline vs link-only workflow snippet in RECP-02, CHANGELOG entry.

**Explicit out of scope:** Phase 39 demo trace path, Phase 40 operator UI, Phase 41 full GATE-01 matrix, policy guide rewrite, `pending_signals` auto-population (READ milestone).

---

## research_summary

Phase 38 closes **RECP-01** and **RECP-02** by adding two persona-driven recipes atop the Phase 36–37 doc foundation. The codebase already proves the APIs; the gap is adoption documentation for Support Operator ("why no password reset email?") and Product Manager ("send → webhook → workflow visible in trace") JTBDs.

**Confidence: High.** Trace APIs, explanation fields, and feedback E2E are verified in source and tests. Phase 37 journey guide and golden-path webhook appendix provide cross-link targets without duplication.

### What the codebase confirms [VERIFIED]

1. **`find_traces_for_recipient/2`:** Filters by `recipient_identity`, optional `notification_key:`, default `limit: 50` — `traces.ex:66-80`. Tests use `notification_key: "password_reset"` at `traces_test.exs:209`.
2. **`explain_delivery/1`:** Returns `Chimeway.Traces.Explanation` with `status`, `suppression_reason`, `planning_reason`, `timeline` — `explanation.ex:19-35`. Documented suppression strings: `channel_disabled`, `retries_exhausted`, `permanent_failure`, `bounced`.
3. **Policy deferral branch:** `planning_reason: "quiet_hours"` with `planning_context` appears in tests (`traces_test.exs:1239`) — use for suppression/deferral narrative alongside `:suppressed` + `suppression_reason`.
4. **Trigger contract:** `Chimeway.trigger/3` requires `idempotency_key` and `tenant_id` — same as golden-path (Phase 36).
5. **Notifier email channel:** `channels/2` returns `[:email]`; callbacks `notification_key`, `recipients/1`, `build/2` — standard `Chimeway.Notifier` pattern.
6. **Feedback loop:** `feedback_pipeline_e2e_test.exs` proves progress path (`:webhook_received`, `signal_event_name: "chimeway.delivery.succeeded"`) and stop path (`workflow_stopped` on bounce) — RECP-02 must narrate these without inlining full webhook controller setup.
7. **HexDocs registration:** `mix.exs` lists three recipes; `groups_extras: Recipes: ~r/guides\/recipes\//` — add two paths only.
8. **Existing recipe gap:** `tracing-a-notification.md` covers telemetry + basic `explain_delivery/1` but lacks persona walkthrough, `find_traces_for_recipient/2`, or password-reset JTBD — RECP-01 extends without replacing.

### Doc hierarchy (avoid duplication)

| Doc | Role | Phase 38 relationship |
|-----|------|----------------------|
| `golden-path.md` | First vertical slice (`:in_app` welcome) | RECP-01 links for install/trigger baseline; add "What's next" links to new recipes |
| `tracing-a-notification.md` | Telemetry / correlation | RECP-01 cross-link for depth |
| `multi-step-journeys.md` | Workflow authoring | RECP-02 cross-link for `workflow/2` definition |
| `policy-and-preferences.md` | Policy model (stub) | RECP-01 honest stub callout + link |
| New password-reset recipe | Support debugging JTBD | **Create** |
| New feedback-escalation recipe | Webhook → workflow trace JTBD | **Create** |

### Planning recommendation

Three plans in two waves: (1) RECP-01 recipe, (2) RECP-02 recipe in parallel; (3) `mix.exs` extras, golden-path/journey cross-links, doc-contract extension, `mix ci.docs` gate.

---

## Validation Architecture

Nyquist validation for this docs-only phase:

| Dimension | Approach |
|-----------|----------|
| Automated | `mix test test/chimeway/doc_contract_test.exs` after D-15; `mix ci.docs` per wave |
| Grep gates | Per-recipe forbidden (`Chimeway.Workflow`, `stop_conditions`, `Workflows.Workers`) and required API strings |
| Manual UAT | Support engineer follows RECP-01 in IEx; PM reads RECP-02 + opens demo E2E describe blocks |
| Wave 0 | None — extend existing `doc_contract_test.exs` in final plan |

---

## RECP-01 — Password-reset support trace (API reference)

### Notifier sketch (doc-only)

```elixir
defmodule MyApp.Notifiers.PasswordReset do
  use Chimeway.Notifier

  @impl true
  def notification_key(_params), do: "password_reset"

  @impl true
  def recipients(params), do: [params.user_identity]

  @impl true
  def build("email", params), do: %{subject: "Reset your password", body: params.reset_url}

  @impl true
  def channels(_params), do: [:email]
end
```

### Support Operator IEx flow

```elixir
# Find recent password-reset notifications for a user
notifications =
  Chimeway.Traces.find_traces_for_recipient("user:123",
    notification_key: "password_reset",
    limit: 10
  )

# Pick delivery id from head notification's deliveries, then explain
{:ok, exp} = Chimeway.Traces.explain_delivery(delivery_id)
exp.status              # :succeeded | :suppressed | :failed | :cancelled | :pending
exp.suppression_reason  # "channel_disabled" | "retries_exhausted" | ...
exp.planning_reason     # "quiet_hours" when deferred
exp.timeline            # [%{event: :event_created, ...}, ...]
```

### Diagnostic branches (from tests + Explanation moduledoc)

| Symptom | Trace signals | Meaning |
|---------|---------------|---------|
| Policy / quiet hours | `status: :suppressed` or deferred with `planning_reason: "quiet_hours"` | Chimeway blocked or deferred — not provider inbox |
| Delivery failed | `status: :failed` or `:cancelled` with `suppression_reason` in `retries_exhausted`, `permanent_failure`, `bounced` | Adapter/provider path |
| User claims missing, trace `:succeeded` | `status: :succeeded`, timeline shows terminal success | Handoff to spam/provider investigation |

---

## RECP-02 — Feedback escalation (API reference)

### Narrative chain (no inline controller)

1. Outbound delivery created via trigger + workflow notifier  
2. Provider POST → demo `/webhooks/chimeway/echo` (reference only)  
3. `Chimeway.Webhooks.ProcessFeedbackWorker` → `chimeway.delivery.{succeeded,bounced,failed}`  
4. `Chimeway.Dispatch.SignalRouterWorker` → `Workflows.route_signal/1`  
5. Inspect via `Chimeway.Traces.explain_delivery/1` — `:webhook_received`, `workflow_stopped` timeline events  

### Cross-link targets

- `guides/introduction/golden-path.md#next-webhook-feedback-loop`
- `guides/flows/multi-step-journeys.md` (Delivery feedback section)
- `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs`

---

## RESEARCH COMPLETE

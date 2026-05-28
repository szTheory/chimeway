# Phase 37: Doc Truth & Journey Guides — Pattern Mapping

**Mapped:** 2026-05-28  
**Phase:** 37-doc-truth-journey-guides  
**Requirements:** DOCS-03  

Maps every file Phase 37 creates or modifies to closest codebase analogs with copy-ready excerpts.

---

## File Inventory

| File | Action | Role |
|------|--------|------|
| `guides/flows/multi-step-journeys.md` | **Rewrite** | Primary DOCS-03 deliverable — workflow/journey truth |
| `guides/recipes/oban-integration.md` | **Edit** | Worker paths, queue names, scheduling model (D-13, D-14) |
| `test/chimeway/doc_contract_test.exs` | **Extend** | Static journey-guide API assertions (D-15) |
| `.planning/phases/37-doc-truth-journey-guides/37-VALIDATION.md` | **Exists** | Manual grep checklist (D-16) — update status at execute |

**Link-only (cross-references, no edits required):**
- `guides/introduction/golden-path.md` — webhook appendix cross-link target (D-11)
- `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` — delivery-feedback E2E proof
- `test/chimeway/orchestration/workflow_progression_test.exs` — canonical `wait_until` fixture

---

## Pattern 1: Notifier-Embedded Workflow (guide authoring surface)

**Closest analog:** `test/chimeway/orchestration/workflow_progression_test.exs`  
**Anti-pattern:** Current `multi-step-journeys.md` `@behaviour Chimeway.Workflow` module

```elixir
def workflow(_params, _recipient) do
  {:ok,
   %{
     workflow_key: "mention_escalation",
     workflow_version: 1,
     steps: [
       %{
         step_key: "in_app",
         step_order: 1,
         channel: :in_app,
         config: %{
           "progress" => [
             %{
               "kind" => "wait_until",
               "anchor" => "prior_delivery_terminal_at",
               "delay_seconds" => 7200,
               "to_step" => "email"
             }
           ]
         }
       },
       %{
         step_key: "email",
         step_order: 2,
         channel: :email,
         config: %{}
       }
     ]
   }}
end
```

**Phase 37 delta:** Use `7200` (2 hours) for narrative; show `wait_until` only in primary flow — no separate wait steps, no `stop_conditions`.

---

## Pattern 2: Trigger API (from Phase 36 golden-path)

**Closest analog:** `guides/introduction/golden-path.md` + `trigger_explain_test.exs`

```elixir
{:ok, result} = Chimeway.trigger(MyApp.Notifiers.MentionEscalation, params,
  idempotency_key: "mention-doc-789-user-123",
  tenant_id: "org_456"
)
```

**Forbidden:** `Chimeway.Trigger.trigger/3`, missing `tenant_id`, missing `idempotency_key`.

---

## Pattern 3: Signal API

**Closest analog:** `lib/chimeway/signal.ex:20-22`

```elixir
Chimeway.Signal.track("org_456", "user_123", "chimeway.delivery.succeeded", %{
  "delivery_id" => delivery_id
})
```

**Argument order:** `tenant_id`, `actor_id`, `event_name`, `payload` — not reversed.

---

## Pattern 4: Oban Workers (correct namespaces)

**Closest analog:** `lib/chimeway/dispatch/workflow_progression_worker.ex`, `signal_router_worker.ex`

| Worker | Module | Queue |
|--------|--------|-------|
| Wait elapse | `Chimeway.Dispatch.WorkflowProgressionWorker` | `:chimeway_delivery` |
| Signal routing | `Chimeway.Dispatch.SignalRouterWorker` | `:chimeway_signals` |

**Forbidden:** `Chimeway.Workflows.Workers.*`, `:chimeway_workflows` queue (unused).

**Scheduling truth:** Oban dispatcher auto-schedules `WorkflowProgressionWorker` at `due_at` per run; cron + `progress_due_runs/1` is optional fallback only.

---

## Pattern 5: Doc-Contract Test Extension

**Closest analog:** `test/chimeway/doc_contract_test.exs` (moduledoc checks)

Add a `describe "journey guide doc contract"` block that reads `guides/flows/multi-step-journeys.md` and asserts:

**Forbid (primary flow):** `Chimeway.Workflow`, `stop_conditions`, `Workflows.Workers`, `Chimeway.Trigger.trigger`, `type: :wait`, `PT2H`

**Require:** `wait_until`, `on_outcome`, `Chimeway.trigger`, `Chimeway.Signal.track`, `Chimeway.Dispatch.WorkflowProgressionWorker`, `Chimeway.Dispatch.SignalRouterWorker`, `Deferred` or `READ-0`

---

## Pattern 6: Deferred / Future Callout (INV-002)

**Closest analog:** Phase 36 golden-path webhook appendix tone — outcome description, not engine internals.

Required prose elements:
- `enter_waiting/6` does not populate `pending_signals`
- Read-to-cancel (`notification_read` signal) requires host wiring — deferred to READ milestone (READ-01/READ-02)
- Do not present read-to-cancel as the primary escalation story

---

*Phase: 37-doc-truth-journey-guides*

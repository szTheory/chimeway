# Phase 31: Feedback-Driven Progression - Research

**Researched:** 2024-05
**Domain:** Workflow Engine, Asynchronous Webhooks, Signal Routing
**Confidence:** HIGH

## Summary

The goal of Phase 31 is to enable workflow journeys to automatically progress or branch based on the asynchronous outcomes of earlier steps (such as deliveries and bounces). 

Phase 30 successfully established the webhook ingestion layer (`Chimeway.Webhooks.ProcessFeedbackWorker`) which translates vendor payloads into asynchronous delivery state updates via `Chimeway.Deliveries.record_attempt/2`. Furthermore, `record_attempt/2` already triggers `Chimeway.Workflows.Progression.progress_run/2` inline via `maybe_apply_progression/1`. This handles canonical step progression (`wait_until` and `on_outcome` rules).

However, to satisfy **FLOW-01** and the success criterion *"The webhook ingestion layer successfully emits standard workflow signals that the v1.3 signal router can consume,"* the ingestion layer must be extended to also emit durable, host-consumable workflow signals (e.g., `delivery.succeeded`, `delivery.bounced`) using the Phase 27 `Chimeway.Signal.track/4` boundary. This bridges the gap between low-level delivery rows and the generic `SignalRouterWorker`.

**Primary recommendation:** Extend `Chimeway.Webhooks.ProcessFeedbackWorker` to emit standard workflow signals (via `Chimeway.Signal.track/4`) upon successful completion of `Deliveries.record_attempt/2`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| **Feedback Ingestion** | API / Backend | — | Receives synchronous webhook payloads and enqueues async processing via Oban (`ProcessFeedbackWorker`). |
| **Outcome Normalization** | API / Backend | Database | `ProgressionOutcome` normalizes delivery state into a curated vocabulary (`:delivered`, `:bounced`, etc.) without side effects. |
| **Workflow Progression** | Database | API / Backend | `Workflows.Progression` handles atomic step branching via `Repo.transaction` with `FOR UPDATE` locking. |
| **Signal Emission** | API / Backend | Database | `ProcessFeedbackWorker` maps normalized outcomes to `Chimeway.Signals.Signal` rows to route via `SignalRouterWorker`. |

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FLOW-01 | Normalized delivery outcomes are emitted as signals to the workflow engine. | `Chimeway.Signal.track/4` is the standard seam for signal emission. `ProcessFeedbackWorker` should call this post-attempt. |
| FLOW-02 | Workflow journeys can define outcome-based progression rules driven by asynchronous feedback. | `Chimeway.Workflows.Progression` already supports `on_outcome` and `stop` rules, evaluating them inline during `record_attempt/2`. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Ecto | 3.11.x | Transactions and row locking | Required for safe, concurrent workflow state transitions (`FOR UPDATE` locks). |
| Oban | 2.17.x | Async worker execution | Native robust async processing; `ProcessFeedbackWorker` and `SignalRouterWorker` depend on it. |

## Architecture Patterns

### System Architecture Diagram

```text
[Webhook Payload] 
      │
      v
[Chimeway.Webhooks.process/4] (Synchronous validation)
      │
      v
(Enqueues Oban Job)
      │
      v
[ProcessFeedbackWorker] 
      │
      ├─> 1. Translates payload to attempt params
      │
      ├─> 2. Calls Deliveries.record_attempt/2
      │        │
      │        ├─> (Writes DeliveryAttempt, updates Delivery)
      │        └─> Calls Workflows.Progression.progress_run/2 (Handles on_outcome branching)
      │
      └─> 3. Calls Chimeway.Signal.track/4 
               (Emits durable Signal e.g., "delivery.succeeded" for v1.3 Router)
```

### Pattern 1: Durable Signal Tracking
**What:** Emitting durable events to the workflow engine using the established API boundary.
**When to use:** Whenever a host or background job generates an event that workflows might be suspended on.
**Example:**
```elixir
# After successfully recording the attempt:
signal_name = "delivery.#{outcome}" # e.g., "delivery.succeeded", "delivery.bounced"
payload = %{
  delivery_id: delivery.id,
  provider_message_id: provider_message_id,
  error_class: attempt_params[:error_class]
}

# The host app/tenant identifier needs to be resolved from the delivery's Notification.
Chimeway.Signal.track(tenant_id, actor_id, signal_name, payload)
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Progression State Evaluation | Custom rule matching inside Webhooks | `ProgressionOutcome.from_delivery/2` and `Progression.progress_run/2` | The progression engine is already idempotent and transaction-safe; duplication leads to race conditions. |
| Signal Routing | Direct manual updates to suspended workflow runs | `Chimeway.Signal.track/4` and `SignalRouterWorker` | `track/4` handles durable row persistence and Oban enqueueing inside an `Ecto.Multi`. |

## Common Pitfalls

### Pitfall 1: Double Progression via Signal Router and Inline Record Attempt
**What goes wrong:** Workflows progress twice or exhibit undefined behavior.
**Why it happens:** `Deliveries.record_attempt/2` already triggers `maybe_apply_progression/1`. If the `SignalRouterWorker` also blindly evaluates delivery outcomes, duplicate advancement can occur.
**How to avoid:** Ensure that standard `on_outcome` rules rely on the canonical inline `Progression.progress_run/2` execution, while the emitted `Signal` is strictly used to resume workflows that explicitly suspended themselves via a `wait_for_signal` rule with `pending_signals: ["delivery.bounced"]`.

### Pitfall 2: Missing Tenant Context for Signals
**What goes wrong:** `Chimeway.Signal.track/4` fails because `tenant_id` or `actor_id` is missing.
**Why it happens:** Webhook payloads often lack rich contextual metadata.
**How to avoid:** The `ProcessFeedbackWorker` looks up the `Delivery` row. It must preload or join the associated `Notification` and `WorkflowRun` to accurately resolve `tenant_id` and the `recipient_identity` (actor_id) needed for the `track/4` call.

## Code Examples

### Standard Signal Emission inside ProcessFeedbackWorker
```elixir
# Assuming `delivery` is preloaded with `Notification` or `WorkflowRun` state
with {:ok, %{delivery: updated_delivery, attempt: attempt}} <- Deliveries.record_attempt(delivery, attempt_params) do
  # Determine event name based on normalized outcome
  event_name = "delivery.#{outcome}"
  
  # Resolve context (Tenant ID, Actor ID) from associated domains
  # ...
  
  # Emit standard workflow signal
  Chimeway.Signal.track(tenant_id, actor_id, event_name, %{
    delivery_id: updated_delivery.id,
    attempt_id: attempt.id
  })
  
  :ok
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Synchronous branching on webhooks | Async Durable Workers + Inline Engine | Phase 30 / 31 | Branching occurs safely via Oban retries, avoiding API timeouts. |
| Coupling webhooks directly to next steps | `SignalRouterWorker` integration | Phase 31 | Host apps can write generic workflows that wait on `delivery.bounced` alongside custom `user.signed_in` signals. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ProcessFeedbackWorker` should emit `delivery.*` events to the v1.3 signal router | Summary | Duplicate logic or unused events if the router ignores them. |
| A2 | Tenant ID and Actor ID can be readily derived from the Delivery/Notification associations in the webhook worker | Common Pitfalls | If unresolvable, `Chimeway.Signal.track/4` will fail its non-empty validations. |

## Open Questions (RESOLVED)

1. **Resolution of `actor_id`:** 
   - What we know: `Chimeway.Signal.track/4` requires a non-empty `actor_id`.
   - What's unclear: If the `Delivery` is destined for an anonymous endpoint without a tracked `recipient_identity` on the `Notification`, what should the fallback `actor_id` be?
   - Resolution: Extract it from `Notification.recipient_identity`. If null, default to the string `"system"`. This is enforced by the migration backfill.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config file | `mix.exs` |
| Quick run command | `mix test` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FLOW-01 | Processing feedback triggers Signal emission | integration | `mix test test/chimeway/webhooks/process_feedback_worker_test.exs` | ❌ Wave 0 |
| FLOW-02 | Webhook ingestion drives journey progression | e2e/integration | `mix test test/chimeway/workflows_test.exs` | ✅ Wave 0 |

### Wave 0 Gaps
- [ ] `test/chimeway/webhooks/process_feedback_worker_test.exs` needs to assert that a `Chimeway.Signals.Signal` is successfully inserted after `Deliveries.record_attempt/2` succeeds.

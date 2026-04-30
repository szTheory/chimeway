# Phase 27: Journey Traces & Host Signal API - Research

## Overview

This document explores the architectural design, trade-offs, and developer experience (DX) considerations for Chimeway's Phase 27. The focus is on providing a stable Host Signal API for workflow progression, maintaining tenancy-aware and payload-safe journey traces, and enabling operators to seamlessly inspect workflow states entirely from persisted data.

---

## 1. Host Signal API for Workflow Progression

**Goal:** Host applications can submit validated workflow progression signals through a stable API boundary (e.g., read, seen, clicked, completed).

### Background & Problem Statement
Notification workflows are rarely fire-and-forget. A workflow might pause until a user clicks an email link, reads an in-app message, or completes a billing task. The host application needs a simple, idiomatic way to tell Chimeway, "This user just did X, update their workflows." If this boundary is messy, host apps will leak Chimeway internals (like workflow step IDs or internal state machines) into their domain logic.

### Prior Art Analysis

*   **Knock / Courier / Novu:** Provide RESTful endpoints for tracking events (e.g., `track(user_id, event_name)`).
    *   *What they did right:* The API is extremely simple. The host app just fires events; the engine figures out which workflows are waiting for that event.
    *   *Footguns:* Weak typing on event payloads leads to brittle condition evaluations. Event ordering issues (e.g., "read" arriving before "delivered") can cause state machines to get stuck or fail silently.
*   **Temporal / AWS Step Functions:** Use explicit signals or task tokens (`SendTaskSuccess`, `SignalWorkflowExecution`).
    *   *What they did right:* Deterministic and explicit. You signal a *specific* workflow execution.
    *   *Footguns:* DX is heavy. The host app has to persist the `task_token` or `workflow_id` and map it to user actions. For notifications, this is often too much boilerplate and couples the host domain tightly to the workflow engine.

### Idiomatic Elixir/Ecto Approaches

#### Approach A: Explicit Workflow Signaling (`Chimeway.Workflow.signal/3`)
The host app passes a specific workflow/delivery ID back to Chimeway.
*   **Pros:** Highly deterministic. Updates are scoped by Primary Key. Very fast database lookup.
*   **Cons:** Host app must store the Chimeway `workflow_id` or `delivery_id` alongside their domain entities, leaking infrastructure concerns.
*   **Example:** `Chimeway.signal_workflow(workflow_id, :clicked)`

#### Approach B: Global Event Bus / Topic Matching (`Chimeway.track/3`)
The host app tracks generic events for a user/tenant, and Chimeway's internal registry (or Oban jobs) pattern-matches to waiting workflows.
*   **Pros:** Incredible DX. Complete decoupling. Host app just does `Chimeway.track(tenant_id, user_id, "invoice.paid")`.
*   **Cons:** Complex internally. Requires an event router or fan-out mechanism to find all suspended workflows for that user waiting on that event. Can lead to race conditions if not handled transactionally.

### One-Shot Recommendation: The Topic-Mapped Event API

**Adopt Approach B (Topic-Mapped Event API) via a unified `Chimeway.Signal` module.**

Provide a unified `Chimeway.Signal.track(tenant_id, actor_id, event_name, payload \\ %{})` function.
*   **How it works:** Under the hood, this function synchronously writes an `InboxEvent` or `Signal` record. An Oban job or internal Broadway pipeline then transactionally routes this signal to any active workflows for that `(tenant_id, actor_id)` pair waiting on `event_name`.
*   **DX:** The host application doesn't need to know about workflows. They just report facts.
*   **Idiomatic Elixir:** Leverage Ecto `insert` for the signal (durability), and Oban triggers for the fan-out state machine progression. This isolates the host app's web requests from workflow processing latency.

---

## 2. Operator Inspection of Workflow Position

**Goal:** Operators can inspect the current workflow position, completed steps, pending next action, and stop/escalation reasons.

### Background & Problem Statement
When a user asks, "Why didn't I get the reminder?", a developer or support operator needs to see exactly where the workflow is. If state is implicit (e.g., buried in process dictionaries, Oban args, or unstructured JSON blobs), debugging is a nightmare.

### Prior Art Analysis

*   **Temporal:** The gold standard for visibility. Every step, timer, and signal is in an immutable event history.
    *   *What they did right:* Event sourcing allows perfect historical accuracy.
    *   *Footguns:* Storing full event histories for every notification is incredibly storage-heavy and can inflate database costs rapidly for high-volume notification libs.
*   **Sidekiq / Oban UI:** Good for job-level debugging, but terrible for *workflow* debugging. A workflow might span 5 Oban jobs. Seeing "Job 4 failed" doesn't explain the user journey.

### Idiomatic Elixir/Ecto Approaches

#### Approach A: Pure Event Sourcing (Commanded)
*   **Pros:** Perfect audit trail.
*   **Cons:** Not idiomatic for standard Phoenix/Ecto apps (requires Commanded or similar heavy dependencies). Massive overkill for a library designed to be embedded.

#### Approach B: Normalized State & Step Tables
`WorkflowExecution` has many `WorkflowSteps` or `WorkflowTraces`.
*   **Pros:** Idiomatic relational design. Easy to query "show me all workflows stuck on step X".
*   **Cons:** Write-heavy (multiple inserts per workflow progression).

### One-Shot Recommendation: The "Current State + Immutable Traces" Model

**Adopt Approach B.** Create a `WorkflowExecution` schema with explicit columnar state (`status`, `current_step_name`, `suspended_until`). For the *history*, write lightweight, append-only `WorkflowTrace` records.

*   **DX/UX:** Operators can query `Chimeway.Workflow.get_execution_state!(id)` and get a perfectly structured struct back containing `%Execution{status: :waiting, pending_action: "invoice.paid", traces: [...]}`.
*   **Idiomatic Elixir:** Ecto `has_many` makes this trivial to preload. Postgres handles the high-throughput inserts of traces effortlessly. UI building in Phoenix LiveView becomes a simple matter of rendering the preloaded `traces` list.

---

## 3. Payload-Safe and Tenancy-Aware Journey Traces

**Goal:** Journey trace surfaces remain payload-safe and tenancy-aware while spanning multiple deliveries and channels.

### Background & Problem Statement
Notifications often contain PII or sensitive data in their payloads (e.g., password reset tokens, health info). Traces and logs must not inadvertently leak this data. Furthermore, in B2B SaaS (which Chimeway targets), a tenant must never see another tenant's workflow traces.

### Prior Art Analysis

*   **Courier / DataDog:** Allow defining "scrubbers" or dropping specific keys before persistence.
    *   *What they did right:* Flexibility.
    *   *Footguns:* Opt-in scrubbing is a massive footgun. Developers *will* forget to scrub a new payload field, leaking PII to logs.
*   **Stripe:** Redacts sensitive fields by default in their API logs (e.g., card numbers are never logged, even if submitted).

### Idiomatic Elixir/Ecto Approaches

#### Approach A: Ecto Custom Types for Payload
Create an `Ecto.Type` (e.g., `Chimeway.SafePayload`) that redacts keys defined in application config before dumping to the database.
*   **Pros:** Enforced at the Ecto layer. Impossible to bypass unless using raw SQL.
*   **Cons:** Requires configuration. Doesn't protect against deeply nested arbitrary JSON unless heavily recursive.

#### Approach B: Opaque Trace Payloads (Drop by Default)
Never store the *delivery payload* in the trace. Instead, traces only record *structural progression* (e.g., `%{event: :email_sent, template: "welcome", provider_id: "sendgrid_123"}`).
*   **Pros:** 100% PII safe by design. Traces are tiny.
*   **Cons:** Harder to debug template rendering issues without the exact payload.

### One-Shot Recommendation: Structural Traces with Tenancy Signatures

**Adopt Approach B and mandate `tenant_id` at the API boundary.**

1.  **Tenancy:** Every Ecto schema (`WorkflowExecution`, `Trace`) MUST have a `tenant_id` string/UUID. The API boundary (`Chimeway.Workflow.list_traces(tenant_id, opts)`) must enforce `tenant_id` as the first argument, making cross-tenant queries impossible by design.
2.  **Payload Safety:** Traces only store structural progression metadata. By default, Chimeway *drops* the render payload from traces. If a host app wants to store payload context for debugging, they must explicitly pass data through a custom redaction protocol (opt-in).
*   **Architecture:** Principle of least surprise—PII doesn't magically end up in notification logs. Tenancy is enforced at the function signature level, preventing accidental data bleed in multi-tenant Elixir apps.

---

## 4. Deterministic Inspection from Persisted State

**Goal:** Workflow inspection surfaces answer "where is this recipient in the journey and why?" from persisted state alone.

### Background & Problem Statement
If a workflow is "stuck," operators need to know *why*. Is it waiting for a signal? Did it hit a rate limit? Did an external provider 500? The answer must be derivable purely from the database, without requiring active process state (like GenServer state) to be inspected.

### Prior Art Analysis

*   **AWS Step Functions:** You can look at the Visual Workflow and see exactly which box is green, red, or pulsing (waiting). The "why" is explicitly logged as the output of the previous step.
*   **Oban:** You can see an `error` array in the database containing the stack trace and retry time.
    *   *What they did right:* Pure database-driven state. The UI just reads Ecto models.

### Idiomatic Elixir/Ecto Approaches

#### Approach A: The "State Spine" Pattern
When a workflow yields (pauses), it updates the database with a `wait_condition` (e.g., `%{type: :signal, event: "user.clicked"}` or `%{type: :time, until: ~U[...]}`). When it stops, it writes a `stop_reason` (`:max_escalations_reached`, `:cancelled_by_host`).
*   **Pros:** Querying is trivial. `WHERE status = 'suspended' AND wait_condition->>'type' = 'signal'`. Highly observable.
*   **Cons:** Requires careful state machine design to ensure the DB is always updated *before* the Elixir process yields.

### One-Shot Recommendation: The Authoritative State Spine

**Adopt Approach A.** Design the `WorkflowExecution` schema to act as the authoritative spine.

*   Add `suspended_reason` (string/enum), `suspended_until` (datetime), and `pending_signals` (string array).
*   Add `terminal_reason` (string/enum).
*   Whenever a workflow execution halts (whether to wait for an hour, wait for an event, or abort due to an error), the final database transaction MUST record exactly why it yielded.
*   **DX/UX:** An operator UI (or simple IEx function `Chimeway.Workflow.explain(id)`) just reads these columns. It can instantly print: *"This workflow is paused. It has been waiting for the `document.signed` signal since 2023-10-25. It will escalate and timeout on 2023-10-30."*
*   **Architecture:** Relying solely on Postgres for inspection guarantees that horizontal scaling of the Chimeway engine doesn't break observability. Node restarts won't lose debug context.

---

## Conclusion: How the Architecture Integrates Cohesively

1.  **Host App** calls `Chimeway.Signal.track(tenant_id, user_id, "signed")`.
2.  **Chimeway** inserts a `Signal` and looks for any `WorkflowExecution` where `tenant_id = tenant_id` and `"signed" IN pending_signals` (The State Spine).
3.  **Engine** wakes up the workflow, processes the next step (e.g., sending a confirmation email).
4.  **Tracer** writes a PII-safe, structural `Trace` record (e.g., `step: :send_email`, `status: :delivered`) tied to the `tenant_id`.
5.  **Operator** uses `Chimeway.explain(tenant_id, execution_id)` and gets a perfect, DB-backed read-out of the journey without ever touching a live process or risking PII exposure.
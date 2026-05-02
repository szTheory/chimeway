# Phase 34: feedback-contract-e2e-proof - Research

**Researched:** 2026-05-02
**Domain:** Feedback contract proof (Elixir / Phoenix / Oban / Ecto sandbox / E2E test design)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Canonical outcome vocabulary**
- **D-01:** The signal event-name axis is locked to `chimeway.delivery.{succeeded,bounced,failed}`.
  Already produced by `lib/chimeway/webhooks/process_feedback_worker.ex:139` via
  `canonicalize_status("delivered") -> "succeeded"`. Already asserted by
  `test/chimeway/webhooks/process_feedback_worker_test.exs:77,117` against the real worker.
- **D-02:** Three vocabularies stay distinct by design. They live on separate axes and
  must NOT be collapsed in this phase:
  1. **Adapter-normalized status** — atoms `:delivered | :bounced | :failed` from
     `normalize_feedback/1`, persisted as string at `Ingress.normalized_status`
     (`lib/chimeway/webhooks/ingress.ex:28`).
  2. **Signal event-name suffix and worker outcome atom** —
     `succeeded | bounced | failed`, post-`canonicalize_status/1`.
  3. **Workflow-curated branchable outcome** —
     `:delivered | :suppressed | :temporary_failure | :retries_exhausted | :permanent_failure | :bounced`
     from `Chimeway.Workflows.ProgressionOutcome.from_delivery/2`
     (`lib/chimeway/workflows/progression_outcome.ex:12-26, 74-80`).
- **D-03:** Drift fix scope is the synthetic trace fixtures only —
  `test/chimeway/traces_test.exs:416,523`. Update `chimeway.delivery.delivered` →
  `chimeway.delivery.succeeded` (and `.bounced` / `.failed` where appropriate). No
  production code changes, no normalization shims, no vocabulary translation table.
- **D-04:** Document the three-axis vocabulary contract in 34-VERIFICATION.md as part
  of the FLOW-01/FLOW-02 evidence table.

**End-to-end proof shape**
- **D-05:** New E2E test lives in `examples/chimeway_demo_host/test/demo_host_web/controllers/`
  (new file or new `describe` in existing controller test).
- **D-06:** Test scenario:
  1. Insert a real `WorkflowDefinition` + `WorkflowRun` waiting on
     `chimeway.delivery.succeeded` (or `.bounced` for stop-path).
  2. Insert a real `Delivery` row in non-terminal state with `workflow_run_id`.
  3. POST to `/webhooks/chimeway/echo` with payload that resolves via
     `examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex:37`
     (`"delivery_id"` clause).
  4. Drain in order: `Oban.drain_queue(queue: :chimeway_delivery)` then
     `Oban.drain_queue(queue: :chimeway_signals)`.
- **D-07:** Test assertions: HTTP 2xx; Ingress row committed; DeliveryAttempt with
  canonical outcome atom; Signal with `event_name == "chimeway.delivery.succeeded"`;
  WorkflowRun.state flipped from `:waiting` to `:active` (or terminal); WorkflowTransition
  with `reason == "signal_received"` AND `delivery_id == delivery.id`; trace timeline
  carries both `:webhook_received` and a `:workflow_*` atom.
- **D-08:** Use real `Oban.drain_queue/1`, NOT `assert_enqueued + perform_job`. Reference:
  `test/chimeway/reliability/retry_exhaustion_test.exs:133`.
- **D-09:** Cover progress path (delivered → step advances) AND stop path
  (bounced → workflow stops) in same test file. One scenario each is enough.

**Audit-closure artifacts**
- **D-10:** `34-VERIFICATION.md` ships with FLOW-01/FLOW-02 requirements table citing
  Phase 31 emission code, Phase 32 trace projection code, and the new Phase 34 E2E
  test. Table format follows `33-VERIFICATION.md:115-118`.
- **D-11:** Each Phase 34 plan SUMMARY declares
  `requirements-completed: [FLOW-01, FLOW-02]` in YAML frontmatter, matching
  `33-04-SUMMARY.md:75`.
- **D-12:** Phase 34 does NOT amend Phase 31 verification or summaries.
- **D-13:** Phase 34 does NOT touch Phase 30 artifacts. 34-VERIFICATION includes a
  brief "Audit Notes" pointing at `33-VERIFICATION.md:115-118` for FEED-01/02 closure.

### Claude's Discretion

- New file (`webhooks_e2e_test.exs` / `feedback_pipeline_test.exs`) vs. additional
  `describe` block in existing `webhooks_controller_test.exs` — pick layout that
  keeps failure diagnostics most legible.
- Step-key strings (e.g. `"delivered_then_done"`), step rule shapes, and tenant_id
  values, so long as both progress and stop paths are exercised and standard
  tenancy posture is used.
- Whether `chimeway.delivery.failed` gets a third scenario — default skip unless
  progress + stop scenarios surface a non-obvious code path.
- Wording of audit-stale callout in 34-VERIFICATION (clear, dated, ≤6 lines).

### Deferred Ideas (OUT OF SCOPE)

- Inverting `canonicalize_status/1` to emit `delivered` instead of `succeeded`.
- Retroactive REQ-mapping edits in Phase 31 verification/summaries.
- Backfilling Phase 30 verification artifacts.
- Vocabulary translation table or normalization shim between the three axes.
- Multi-step / escalation E2E scenarios beyond progress + stop.
- A `chimeway.delivery.failed` E2E scenario as a third covering case.
- Telemetry events or structured logs for the new E2E flow.
- Operator UI surfacing the trace projection.
- Read/unread-driven workflow branching.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FLOW-01 | Normalized delivery outcomes are emitted as signals to the workflow engine. | Already implemented at `lib/chimeway/webhooks/process_feedback_worker.ex:158-168` via `Chimeway.Signal.track/4`. Phase 34 closes the AUDIT gap by mapping FLOW-01 to that emission code in 34-VERIFICATION + adding the new E2E test as the milestone-level proof. |
| FLOW-02 | Workflow journeys can define outcome-based progression rules driven by asynchronous feedback. | Already implemented in `lib/chimeway/workflows/progression.ex` (advance_run/stop_run) and `lib/chimeway/workflows.ex:393-431` (route_signal/1). Phase 34 closes the AUDIT gap by mapping FLOW-02 in 34-VERIFICATION + the new E2E test proves end-to-end webhook → progression on the real path. |

</phase_requirements>

## Summary

Phase 34 is an audit-closure phase, not an architectural one. The production contract
already lives at the canonical vocabulary (`chimeway.delivery.{succeeded,bounced,failed}`)
in `process_feedback_worker.ex:139` and is asserted by
`process_feedback_worker_test.exs:77,117`. The audit-flagged drift is fixture-only, in
two lines of `test/chimeway/traces_test.exs` (416, 523).

The risky and load-bearing piece of work is the new end-to-end test in
`examples/chimeway_demo_host/test/demo_host_web/controllers/`. The production seams it
exercises (Phase 33 atomic ingress, Phase 31 signal emission, Phase 32 trace projection,
Phase 25 workflow progression, Phase 27 signal routing) all already exist; the E2E test
proves they compose on the real Phoenix path with one host-mounted webhook callback.

The two synchronous drains — `Oban.drain_queue(queue: :chimeway_delivery)` followed by
`Oban.drain_queue(queue: :chimeway_signals)` — are the central design choice. The first
drain runs `ProcessFeedbackWorker`, which calls `Deliveries.record_attempt/2`. That call
synchronously triggers `Workflows.Progression.progress_run/2` (via
`maybe_apply_progression/1` at `deliveries.ex:1184-1207`) AND emits the canonical signal
via `Chimeway.Signal.track/4`. The second drain runs `SignalRouterWorker`, which calls
`Workflows.route_signal/1` and writes the `signal_received` `WorkflowTransition` row with
`delivery_id` populated (Phase 32 D-02 wiring at `workflows.ex:419`). Both drains together
land everything the SC-1 / SC-2 / SC-3 assertions need.

**Primary recommendation:** Add one new test file
`examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs`
with two `describe` blocks (progress path, stop path), update two synthetic fixture lines
in `test/chimeway/traces_test.exs:416,523`, and ship `34-VERIFICATION.md` with a
requirements table citing Phase 31 emission code + Phase 32 trace projection code + the
new Phase 34 E2E test as evidence for FLOW-01 and FLOW-02. Each plan SUMMARY declares
`requirements-completed: [FLOW-01, FLOW-02]` in frontmatter.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Webhook ingress + auth | API / Backend | — | `Chimeway.Webhooks.process/4` runs `verify_webhook` synchronously before the Multi-Oban handoff. |
| Async outcome processing | API / Backend | Database | `ProcessFeedbackWorker` reads ingress row, calls `record_attempt/2`, and tracks signal — all in one Oban perform call. |
| Workflow progression on delivery outcome | Database | API / Backend | `Deliveries.record_attempt/2` invokes `Progression.progress_run/2` synchronously inside the same transaction; advance/stop transitions write under `FOR UPDATE`. |
| Signal routing into waiting runs | API / Backend | Database | `SignalRouterWorker` drains `:chimeway_signals` queue and calls `Workflows.route_signal/1`, which writes the `signal_received` transition with `delivery_id` and flips `:waiting → :active`. |
| Operator trace projection | Database (read) | API / Backend | `Traces.explain_delivery/1` joins `DeliveryAttempt` (`:webhook_received`) and `WorkflowTransition` (`:workflow_*`) on `delivery_id` for the canonical timeline. |
| E2E proof harness | API / Backend (test) | — | `examples/chimeway_demo_host` Phoenix endpoint + sandboxed `Chimeway.Repo` + `Oban.Testing` `:manual` mode is the only existing harness that exercises the real route + the real `Webhooks.process/4` seam. Phase 34 extends, never rebuilds. |

## Standard Stack

### Core (no version changes — Phase 34 ships zero new dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir | ~> 1.15 (project default) | Language | Project-wide. [VERIFIED: `mix.exs`] |
| Phoenix | ~> 1.7 (resolved 1.8.5 per Phase 33 example app) | Real Endpoint + Router for E2E test | Already in `examples/chimeway_demo_host/mix.exs`. [VERIFIED: `examples/chimeway_demo_host/mix.exs:18`] |
| Plug | ~> 1.16 | HTTP plumbing for Endpoint pipeline | Already in example app deps. [VERIFIED: `examples/chimeway_demo_host/mix.exs:18`] |
| Oban | ~> 2.17 | Sandboxed `Oban.drain_queue/1` and `assert_enqueued` | Already wired through `use Oban.Testing` and `testing: :manual` config. [VERIFIED: `examples/chimeway_demo_host/config/test.exs:24-27`] |
| Ecto | 3.11.x | Repo + SQL Sandbox `:shared` mode | Already wired through `Ecto.Adapters.SQL.Sandbox.checkout` + `mode(_, {:shared, self()})`. [VERIFIED: `examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs:11-12`] |
| Jason | ~> 1.4 | JSON encode/decode in tests | Already used in existing E2E tests. [VERIFIED: `webhooks_controller_test.exs:22`] |

**Installation:** None. Phase 34 adds NO dependencies. All needed libraries are already
declared in the example app and root project.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| New E2E file `feedback_pipeline_e2e_test.exs` | New `describe` block inside existing `webhooks_controller_test.exs` | Locked under D-05's "Claude's Discretion." Recommendation below. |
| `Oban.drain_queue/1` | `assert_enqueued + perform_job` | EXPLICITLY REJECTED by D-08. Drain exercises the actual Oban handoff and the Phase 33 atomic-ingress seam end-to-end; `perform_job` bypasses scheduling and is unsafe for multi-queue cascades. |
| Two-drain pattern | Single drain | Two queues are involved (`:chimeway_delivery` runs `ProcessFeedbackWorker`; `:chimeway_signals` runs `SignalRouterWorker`). Draining only one leaves half the assertions unsatisfied. Required by D-06.4. |

**Recommendation on file layout (Claude's discretion per CONTEXT.md):**
Use a NEW file `feedback_pipeline_e2e_test.exs`. The existing
`webhooks_controller_test.exs` is already 286 lines with two distinct describe blocks
(Phase 33 host-mount E2E proof + BL-01 regression). A third describe spanning workflow
progression and trace projection would make failure diagnostics significantly less
legible — the existing file is about webhook ingress mechanics; the new file is about
the feedback contract spanning ingress → progression → trace. Failure modes are
different (test fixtures must seed Workflow rows, not just Ingress rows), and shared
setup is minimal (only the sandbox `:shared` mode + `Application.put_env` adapter
config from lines 11-13).

## Architecture Patterns

### System Architecture Diagram

```text
                            HTTP POST /webhooks/chimeway/echo
                                          │
                                          v
                          DemoHostWeb.Endpoint (Plug.Parsers + body_reader)
                                          │
                                          v
                          DemoHostWeb.WebhooksController.create/2
                                          │
                                          v
                          Chimeway.Webhooks.process(EchoAdapter, raw, headers, cfg)
                                          │
                          ┌───────────────┴───────────────┐
                          v                               v
                   verify_webhook              parse + resolve_delivery + normalize_feedback
                                          │
                                          v
                              Ecto.Multi (atomic):
                                Multi.insert(:ingress, ...)
                                Oban.insert(:job, ProcessFeedbackWorker.new(%{ingress_id: ...}))
                                          │
                                          v
                                    {:ok, ingress}  → 200 OK to provider
                                          │
                          ─────── async boundary ────────
                                          │
                            Oban.drain_queue(queue: :chimeway_delivery)   [DRAIN #1]
                                          │
                                          v
                          ProcessFeedbackWorker.perform/1
                                          │
                          ┌───────────────┴───────────────────┐
                          v                                   v
              Deliveries.record_attempt/2          Chimeway.Signal.track/4
                          │                                   │
                          v                                   v
              maybe_apply_progression                 Multi.insert(:signal,...)
                          │                            Oban.insert(:job, SignalRouterWorker)
                          v                                   │
              Workflows.Progression.progress_run/2            │
                          │                                   │
                          ├─→ advance_run (advance to to_step)│
                          │   • appends `progressed_on_delivery_outcome` transition
                          │   • plans next-step delivery
                          ├─→ stop_run (terminal stop)
                          │   • flips run.state = :stopped
                          │   • appends `workflow_stopped` transition
                          └─→ noop (rule no-match / not-branchable)
                                                              │
                                          ─────── second async boundary ────────
                                                              │
                            Oban.drain_queue(queue: :chimeway_signals)   [DRAIN #2]
                                          │
                                          v
                          SignalRouterWorker.perform/1
                                          │
                                          v
                          Workflows.route_signal(signal)
                                          │
                          (joins waiting runs by tenant_id + recipient_identity + event_name)
                                          │
                                          v
                          For each matched run (FOR UPDATE):
                            update_run(:waiting → :active, pending_signals: [])
                            append_transition(reason: "signal_received",
                                              delivery_id: payload["delivery_id"])
                                          │
                                          v
                          ─────── assertions ────────
                                          │
                          Repo.all(Ingress / DeliveryAttempt / Signal / WorkflowTransition)
                          Repo.get(WorkflowRun)
                          Traces.explain_delivery(delivery.id).timeline
```

### Recommended Project Structure

```
examples/chimeway_demo_host/test/demo_host_web/controllers/
├── webhooks_controller_test.exs                  # Phase 33 host-mount E2E (preserved, untouched)
└── feedback_pipeline_e2e_test.exs                # NEW Phase 34 E2E proof (progress + stop)

test/chimeway/
└── traces_test.exs                                # Two fixture-line drift fix at lines 416, 523

.planning/phases/34-feedback-contract-e2e-proof/
├── 34-CONTEXT.md                                 # exists
├── 34-RESEARCH.md                                # this file
├── 34-VALIDATION.md                              # generated post-research
├── 34-01-{slug}-PLAN.md                          # E2E test
├── 34-01-{slug}-SUMMARY.md                       # frontmatter requirements-completed: [FLOW-01, FLOW-02]
├── 34-02-{slug}-PLAN.md                          # fixture drift fix
├── 34-02-{slug}-SUMMARY.md                       # frontmatter requirements-completed: [FLOW-01, FLOW-02]
└── 34-VERIFICATION.md                            # FLOW-01/FLOW-02 requirements table + Audit Notes
```

### Pattern 1: Sandboxed Phoenix + Shared-Mode Repo for Cross-Process E2E

**What:** A sandboxed `Chimeway.Repo` connection is checked out by the test process and
flipped to `:shared` mode so the Plug.Test request, the controller process, and async
Oban drain calls all see the same uncommitted transaction.

**When to use:** Any E2E test that crosses process boundaries (HTTP request → controller →
Oban job perform). All Phase 34 scenarios are this shape.

**Example:**
```elixir
# Source: examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs:10-15
setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chimeway.Repo)
  Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, {:shared, self()})
  Application.put_env(:demo_host, :chimeway_adapter_config, [])
  :ok
end
```

**Phase 34 use:** Identical setup. No modifications.

### Pattern 2: Two-Stage `Oban.drain_queue/1` for Cross-Queue Cascade

**What:** Drain `:chimeway_delivery` first to land worker side-effects (attempt + signal
emission); then drain `:chimeway_signals` to land the router-driven transition.

**When to use:** Any test asserting both the worker-driven side-effects AND the
signal-routed `signal_received` transition. Phase 34 scenarios are this shape.

**Example:**
```elixir
# Drain order matters: ProcessFeedbackWorker emits the signal that
# SignalRouterWorker consumes. Reverse order would drain :chimeway_signals
# first when no signal exists yet — drain returns 0 jobs ran, then the worker
# drain enqueues the signal but never drains it, leaving the test in a half
# state.

# Step 1: run ProcessFeedbackWorker
%{success: 1, failure: 0} =
  Oban.drain_queue(queue: :chimeway_delivery, with_scheduled: true)

# Step 2: run SignalRouterWorker
%{success: 1, failure: 0} =
  Oban.drain_queue(queue: :chimeway_signals, with_scheduled: true)
```

**Reference posture:** `test/chimeway/reliability/retry_exhaustion_test.exs:133` — uses
`Oban.drain_queue(queue: :chimeway_delivery, with_scheduled: true, with_recursion: true)`.
Phase 34 does NOT need `with_recursion: true` because there are no scheduled retries on
the success path; `with_scheduled: true` is sufficient and recommended for forward-compat.

**Drain result shape note:** Per `retry_exhaustion_test.exs:135-143`, `drain_queue`
return shape can vary by Oban minor version. Assert observable state (rows in DB), not
drain count maps, for robustness:

```elixir
result = Oban.drain_queue(queue: :chimeway_delivery, with_scheduled: true)
total = Map.get(result, :success, 0) + Map.get(result, :failure, 0) + Map.get(result, :discard, 0)
assert total >= 1, "drain_queue must execute at least one job"
```

### Pattern 3: Real WorkflowDefinition + WorkflowRun + Delivery Insertion

**What:** Insert real domain rows directly via `Repo.insert!` with the relevant changeset
modules; do NOT route through `Trigger.trigger/3` or notifier callbacks for the test
fixture.

**When to use:** When the test needs deterministic control over `pending_signals`,
`current_step_id`, `delivery.workflow_run_id`, and the canonical `tenant_id` /
`actor_id` linkage.

**Example (canonical, derived from `test/chimeway/traces_test.exs:69-127` and
`test/chimeway/dispatch/signal_router_worker_test.exs:27-88`):**
```elixir
# Source: composite of traces_test.exs:69-127 + signal_router_worker_test.exs:27-88

defp insert_progress_path_fixture do
  alias Chimeway.{Deliveries, Repo}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Workflows.{WorkflowDefinition, WorkflowRun, WorkflowStep}

  tenant_id = "default"
  actor_id  = "user:phase34-#{System.unique_integer([:positive])}"

  event =
    Repo.insert!(%Event{
      notification_key: "test.phase34",
      notification_version: 1,
      idempotency_key: "phase34-#{System.unique_integer([:positive])}",
      payload: %{}
    })

  notification =
    Repo.insert!(%Notification{
      event_id: event.id,
      recipient_identity: actor_id,   # MUST equal delivery.actor_id (route_signal/1 join)
      recipient_type: "user",
      metadata: %{}
    })

  definition =
    Repo.insert!(
      WorkflowDefinition.changeset(%WorkflowDefinition{}, %{
        workflow_key: "test.phase34.delivered_then_done.#{System.unique_integer([:positive])}",
        workflow_version: 1,
        notification_key: "test.phase34"
      })
    )

  step1 =
    Repo.insert!(
      WorkflowStep.changeset(%WorkflowStep{}, %{
        workflow_definition_id: definition.id,
        step_key: "wait_for_delivery",
        step_order: 1,
        channel: "in_app",
        config: %{}
      })
    )

  step2 =
    Repo.insert!(
      WorkflowStep.changeset(%WorkflowStep{}, %{
        workflow_definition_id: definition.id,
        step_key: "done",
        step_order: 2,
        channel: "in_app",
        config: %{}
      })
    )

  now = DateTime.utc_now()

  run =
    Repo.insert!(
      WorkflowRun.changeset(%WorkflowRun{}, %{
        notification_id: notification.id,
        workflow_definition_id: definition.id,
        current_step_id: step1.id,
        state: :waiting,
        started_at: now,
        last_transition_at: now,
        status_reason: "waiting_for_signal",
        tenant_id: tenant_id,
        pending_signals: ["chimeway.delivery.succeeded"]
      })
    )

  # Plan a real delivery linked to the workflow run.
  # plan_delivery/3 requires tenant_id + actor_id; these MUST match the
  # signal's tenant + the notification's recipient_identity for route_signal/1
  # to match this run.
  {:ok, delivery} =
    Deliveries.plan_delivery(notification.id, "in_app",
      tenant_id: tenant_id,
      actor_id: actor_id,
      workflow_run_id: run.id,
      workflow_step_id: step1.id
    )

  # Move delivery off :pending so the worker's record_attempt/2 has a valid
  # transition target. (`@allowed_transitions` permits dispatched ← pending
  # and succeeded ← dispatched.)
  {:ok, delivery} = Deliveries.transition_status(delivery, :dispatched)

  %{
    tenant_id: tenant_id,
    actor_id: actor_id,
    delivery: delivery,
    run: run,
    step1: step1,
    step2: step2
  }
end
```

**Tenancy invariant:** `route_signal/1` at `lib/chimeway/workflows.ex:437-451` joins
`WorkflowRun.tenant_id == ^signal.tenant_id` AND `notification.recipient_identity ==
^signal.actor_id`. The signal is emitted from `process_feedback_worker.ex:167` with
`tenant_id = delivery.tenant_id` and `actor_id = delivery.actor_id`. So the test MUST set
`delivery.tenant_id == run.tenant_id` AND `delivery.actor_id == notification.recipient_identity`.
Use one shared `actor_id` variable across notification + delivery; use one shared
`tenant_id` variable across run + delivery.

### Pattern 4: EchoAdapter `delivery_id` Resolution Clause for Real-FK Test

**What:** The fixture EchoAdapter has a third resolution clause at
`examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex:37`:

```elixir
def resolve_delivery(%{"delivery_id" => did}) when is_binary(did),
  do: {:ok, %{delivery_id: did}}
```

This clause exists precisely so a webhook payload that names a real
`chimeway_deliveries.id` resolves to a Chimeway delivery row via FK lookup. Phase 33's
existing tests use `provider_message_id` because their fixtures don't have real delivery
rows; Phase 34's test SHOULD use `delivery_id` because we're inserting a real delivery
row to drive workflow progression.

**Example payload that the EchoAdapter resolves to delivery_id:**
```elixir
body = Jason.encode!(%{
  "delivery_id" => delivery.id,
  "status" => "ok"             # delivered → succeeded
})

# For stop path:
body = Jason.encode!(%{
  "delivery_id" => delivery.id,
  "status" => "bounce"         # → bounced
})
```

**Auth header:** `EchoAdapter.verify_webhook/3` matches a literal `[{"signature", "valid"}]`.
The test sends `put_req_header("signature", "valid")`. No HMAC computation needed for the
echo route — that is a fixture simplification. The `rawbody` route in
`webhooks_controller.ex:53` requires HMAC; Phase 34 does NOT need to use that route.

**Status string mapping (verified against `EchoAdapter.normalize_feedback/1`):**

| Body `"status"` | Adapter result | Ingress.normalized_status | Worker outcome | Signal event_name |
|-----------------|----------------|---------------------------|----------------|-------------------|
| `"ok"` | `{:ok, %{status: :delivered}}` | `"delivered"` | `:succeeded` (canonicalized) | `chimeway.delivery.succeeded` |
| `"bounce"` | `{:ok, %{status: :bounced}}` | `"bounced"` | `:bounced` | `chimeway.delivery.bounced` |
| `"fail"` | `{:ok, %{status: :failed}}` | `"failed"` | `:failed` | `chimeway.delivery.failed` |

### Pattern 5: Full Endpoint Pipeline Invocation

**What:** Construct a `Plug.Test.conn(:post, path, body)`, set headers, call
`DemoHostWeb.Endpoint.call(...)` with `Endpoint.init([])`. The connection traverses the
full plug pipeline (`Plug.Parsers` with `body_reader`, `Router`, `WebhooksController`).

**Example (from `webhooks_controller_test.exs:21-29`):**
```elixir
provider_msg_id = "msg-" <> Ecto.UUID.generate()
body = Jason.encode!(%{"delivery_id" => delivery.id, "status" => "ok"})

conn =
  conn(:post, "/webhooks/chimeway/echo", body)
  |> put_req_header("content-type", "application/json")
  |> put_req_header("signature", "valid")
  |> DemoHostWeb.Endpoint.call(DemoHostWeb.Endpoint.init([]))

assert conn.status == 200
```

### Anti-Patterns to Avoid

- **`String.to_atom("chimeway.delivery." <> outcome_string)`:** Forbidden by Phase 27 /
  Phase 32 D-16 atom-safety discipline. Worker tests + production both compare event
  names as **strings**: `assert hd(signals).event_name == "chimeway.delivery.succeeded"`.
  Phase 34 follows the same posture — never derive an event-name atom from a runtime
  string.
- **`use Chimeway.DataCase`** in the example app: the example host has its own sandbox
  pattern (manual `Sandbox.checkout` + `mode {:shared, self()}` in setup). DataCase is
  tightly bound to the root project's test support. Use the existing manual-setup
  pattern from `webhooks_controller_test.exs:10-15`.
- **`assert_enqueued + perform_job` instead of `drain_queue`:** Explicitly rejected by
  D-08. `perform_job` synthesizes a job struct, bypassing the actual `Oban.insert/1`
  side of the Phase 33 atomic-handoff Multi. Drain exercises the real path.
- **Adding a third progression rule kind:** Phase 34's progression test fixtures use
  ONLY `on_outcome` (advance) and `stop` (terminate). `wait_until` is unnecessary for
  the goal AND requires a scheduled-job seam that the example app's `dispatcher:
  Chimeway.Dispatch.Sync` setting suppresses (`maybe_schedule_due_progression_job/1`
  only schedules under Oban-backed dispatchers). Avoid wait_until entirely in
  Phase 34's E2E.
- **Inserting raw `WorkflowTransition` rows by hand:** Phase 34's test must let the
  production code paths write transitions (so the assertions prove the contract).
  Hand-inserting a `signal_received` row would defeat SC-2's "real webhook callback
  ... emits the workflow signal." Only the workflow run + delivery + workflow definition
  + workflow steps are inserted directly; transitions land via `record_attempt/2` +
  `route_signal/1` only.
- **Setting a fictitious `delivery.workflow_run_id`:** Real FK to `chimeway_workflow_runs`
  exists. Use the actual `run.id` from the inserted run.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Multi-process database visibility | Custom in-memory cache or shared ETS | `Ecto.Adapters.SQL.Sandbox.mode(_, {:shared, self()})` | Existing Phase 33 pattern; tested. |
| Job queue draining | Manual `Oban.Job.new` + `perform_job` | `Oban.drain_queue/1` | Drain calls the actual Oban runtime; perform_job bypasses it (D-08). |
| Workflow run insertion | Trigger pipeline (`Trigger.trigger/3`) | Direct `Repo.insert!` of WorkflowDefinition/Step/Run | Trigger is integration-shaped; needs notifier callback wiring. Direct insertion is what `traces_test.exs:69-127` and `signal_router_worker_test.exs:27-88` already use; reuse the pattern. |
| Delivery insertion + workflow link | Custom Delivery struct construction | `Deliveries.plan_delivery/3` with `workflow_run_id:` and `workflow_step_id:` opts | Already supports the linkage (`deliveries.ex:293-296, 319-320`). |
| Signal name comparison | `String.to_existing_atom + atom dispatch` | `assert signal.event_name == "chimeway.delivery.succeeded"` | Mirrors the production worker test pattern at `process_feedback_worker_test.exs:77,117`. Atom-safe by construction. |

**Key insight:** Every domain primitive Phase 34 needs already exists in production
code or in established test helpers. The phase's only NEW code is the test file itself
plus the audit-closure verification artifact.

## Common Pitfalls

### Pitfall 1: Wrong drain order

**What goes wrong:** Test asserts `[%Signal{}] = Repo.all(Signal)` but gets `[]`, OR
asserts `signal_received` transition exists but it doesn't.

**Why it happens:** `:chimeway_signals` is drained BEFORE `:chimeway_delivery`, so the
worker hasn't yet enqueued the signal-router job. A subsequent worker drain enqueues the
signal but the test has already moved on.

**How to avoid:** ALWAYS drain `:chimeway_delivery` first; then drain `:chimeway_signals`.
Order is encoded in CONTEXT.md D-06.4 — copy it verbatim into the test.

**Warning signs:** `length(signals) == 0` or `signal_received` transition missing in
intermediate test runs that pass on retry.

### Pitfall 2: Tenant + recipient_identity mismatch

**What goes wrong:** Worker emits the signal correctly, signal router runs, but
`route_signal/1` returns `{:ok, %{}}` (zero matched runs). The `pending_signals` array
contains the right event name, the run is `:waiting`, but the run is never resumed.

**Why it happens:** `route_signal/1` joins
`Notification.recipient_identity == ^signal.actor_id` AND
`WorkflowRun.tenant_id == ^signal.tenant_id` (lines 442-446). The signal carries
`tenant_id = delivery.tenant_id` and `actor_id = delivery.actor_id`. If the run's
`notification.recipient_identity` was set to a different value than `delivery.actor_id`
(or run.tenant_id ≠ delivery.tenant_id), no match.

**How to avoid:** Use ONE shared `actor_id` binding across `notification.recipient_identity`
and `delivery.actor_id`; use ONE shared `tenant_id` binding across `run.tenant_id` and
`delivery.tenant_id`. See Pattern 3's fixture helper.

**Warning signs:** First scenario passes (worker-side `progressed_on_delivery_outcome`
transition surfaces), but second-stage assertions on `signal_received` transition or
`run.state == :active` fail.

### Pitfall 3: Delivery status `:pending` blocks `record_attempt/2`

**What goes wrong:** `Deliveries.record_attempt/2` returns
`{:error, :invalid_status_transition}` on a freshly-planned delivery.

**Why it happens:** `@allowed_transitions` in `lib/chimeway/deliveries.ex` requires
`:dispatched ← :pending` before `:succeeded ← :dispatched`. A delivery freshly returned
from `plan_delivery/3` is `:pending`.

**How to avoid:** Call `Deliveries.transition_status(delivery, :dispatched)` after
planning, before triggering the webhook. See Pattern 3's fixture helper, last 2 lines.

**Warning signs:** Test fails with `record_attempt` returning `{:error, ...}` and the
ingress row stuck in `:queued` state (never advances to `:processed`).

### Pitfall 4: `:async` mode + `Application.put_env` race

**What goes wrong:** Tests interfere with each other when `async: true`. Adapter config
written by one test leaks into another.

**Why it happens:** `Application.put_env(:demo_host, :chimeway_adapter_config, [])` is
global state. The example app's controller reads it at request time
(`webhooks_controller.ex:34`).

**How to avoid:** Keep `use ExUnit.Case, async: false` (matches existing E2E test posture
at `webhooks_controller_test.exs:2`). Phase 34 does NOT relax this.

**Warning signs:** Flaky tests when run in parallel; one scenario's adapter config visible
to another scenario.

### Pitfall 5: Forgetting `with_scheduled: true` on drain

**What goes wrong:** Worker enqueues a follow-up job at a future timestamp; drain misses
it; assertions on rows that follow that job fail.

**Why it happens:** `Oban.drain_queue/1` defaults to executing only available
(non-scheduled) jobs. The Phase 33 atomic handoff inserts the worker job with no `:in`
delay, so the first drain works. But if any code path schedules a sub-second
retry/wakeup, default drain skips it.

**How to avoid:** Always pass `with_scheduled: true` to drain calls — matches the
posture at `retry_exhaustion_test.exs:133`. Phase 34's success path doesn't need it,
but the option is forward-compatible and harmless.

**Warning signs:** Test occasionally passes locally and fails in CI under different
timing.

### Pitfall 6: Fixture-drift fix breaks the PII boundary test

**What goes wrong:** Updating
`test/chimeway/traces_test.exs:523` (`describe "explain_delivery/1 — timeline detail
PII boundary"`) breaks an unrelated assertion.

**Why it happens:** That fixture seeds rows for the for-comprehension at lines 540-558
which asserts every new event atom appears in the timeline AND no entry's `:detail`
contains forbidden keys. Changing `chimeway.delivery.delivered` →
`chimeway.delivery.succeeded` is a string-only edit; it does NOT change which atoms
project (the projection in `traces.ex:570-575` dispatches on the `signal_received`
reason string, not the context's `event_name`). Safe. But the lookup helper at
`traces.ex:608-627` reads `transition.context["event_name"]` to enrich the
`:webhook_received` entry's `signal_event_name` field — verify this is still asserted
correctly post-edit if any test references it (Phase 32 Scenario A at
`traces_test.exs:347-397` uses `chimeway.delivery.bounced` which is already canonical;
no change needed).

**How to avoid:** Run `mix test test/chimeway/traces_test.exs` after the fixture edit
and confirm all 45+ tests still green. The string is only used as `context["event_name"]`
on inserted `signal_received` rows; the projection itself does not match on the value,
only on the reason string `"signal_received"`.

**Warning signs:** None expected — the edit is mechanical. But if a test fails, check
whether it asserts on `signal_event_name == "chimeway.delivery.delivered"` anywhere
(grep `chimeway.delivery.delivered` across `test/`). If yes, update those assertions
too.

### Pitfall 7: Atom safety in fixture changes

**What goes wrong:** Changing fixture strings prompts a tempting refactor of
`canonicalize_status/1`.

**Why it happens:** The drift "looks like" a bug.

**How to avoid:** Honor D-02 (locked). The three vocabularies are deliberately distinct.
Production code already lives at the canonical contract; only the fixtures drift.

**Warning signs:** Plan description includes phrases like "make canonicalize_status more
robust" or "add a vocabulary lookup table." Reject; refer to D-02/D-03.

## Code Examples

Canonical patterns from existing tests:

### Sandboxed shared-mode setup

```elixir
# Source: examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs:10-15
setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chimeway.Repo)
  Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, {:shared, self()})
  Application.put_env(:demo_host, :chimeway_adapter_config, [])
  :ok
end
```

### `use Oban.Testing` boilerplate

```elixir
# Source: examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs:1-8
defmodule DemoHostWeb.FeedbackPipelineE2ETest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn
  use Oban.Testing, repo: Chimeway.Repo

  alias Chimeway.{Deliveries, Repo, Traces}
  alias Chimeway.Webhooks.{Ingress, ProcessFeedbackWorker}
  alias Chimeway.Signals.Signal
  alias Chimeway.Workflows.{WorkflowDefinition, WorkflowRun, WorkflowStep, WorkflowTransition}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
end
```

### Endpoint invocation with EchoAdapter `delivery_id` payload

```elixir
# Adapted from: examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs:21-29
# Substitution: provider_msg_id → delivery.id (uses EchoAdapter.resolve_delivery clause at line 37)

%{tenant_id: _, actor_id: _, delivery: delivery, run: run} = insert_progress_path_fixture()

body = Jason.encode!(%{"delivery_id" => delivery.id, "status" => "ok"})

conn =
  conn(:post, "/webhooks/chimeway/echo", body)
  |> put_req_header("content-type", "application/json")
  |> put_req_header("signature", "valid")
  |> DemoHostWeb.Endpoint.call(DemoHostWeb.Endpoint.init([]))

assert conn.status == 200
```

### Two-stage drain + assertion shape

```elixir
# Drain order is mandatory per CONTEXT.md D-06.4

# DRAIN #1 — runs ProcessFeedbackWorker.
# Side effects (synchronous within the worker perform call):
#   - DeliveryAttempt row written
#   - Delivery.status flipped to :succeeded
#   - Workflows.Progression.progress_run/2 invoked via record_attempt/2
#     (writes `progressed_on_delivery_outcome` transition; advances run.current_step_id)
#   - Signal row written + SignalRouterWorker enqueued in same Multi
result1 = Oban.drain_queue(queue: :chimeway_delivery, with_scheduled: true)
total1 = Map.get(result1, :success, 0) + Map.get(result1, :failure, 0)
assert total1 >= 1, "expected ProcessFeedbackWorker to run; got #{inspect(result1)}"

# DRAIN #2 — runs SignalRouterWorker.
# Side effects:
#   - WorkflowRun.state flipped from :waiting → :active (or terminal for stop path)
#   - WorkflowTransition with reason "signal_received" + delivery_id populated
result2 = Oban.drain_queue(queue: :chimeway_signals, with_scheduled: true)
total2 = Map.get(result2, :success, 0) + Map.get(result2, :failure, 0)
assert total2 >= 1, "expected SignalRouterWorker to run; got #{inspect(result2)}"
```

### Boundary assertions (post-second-drain)

```elixir
# CONTEXT.md D-07: 7 assertions on the progress path.

# 1. HTTP 2xx — already asserted on conn.status above.

# 2. Ingress row committed with normalized_status populated.
assert [%Ingress{} = ingress] = Repo.all(Ingress)
assert ingress.normalized_status == "delivered"
assert ingress.delivery_id == delivery.id
assert ingress.ingress_state == :processed   # worker advanced lifecycle

# 3. DeliveryAttempt row written with the canonical outcome atom.
attempts = Repo.all(Chimeway.DeliveryAttempt)
assert length(attempts) == 1
assert hd(attempts).outcome == :succeeded
assert hd(attempts).adapter_module == to_string(DemoHost.Adapters.EchoAdapter)

# 4. Signal row exists with the canonical event_name (D-01).
signals = Repo.all(Signal)
assert length(signals) == 1
assert hd(signals).event_name == "chimeway.delivery.succeeded"
assert hd(signals).tenant_id == delivery.tenant_id
assert hd(signals).actor_id == delivery.actor_id

# 5. WorkflowRun.state flipped from :waiting → :active.
updated_run = Repo.get!(WorkflowRun, run.id)
assert updated_run.state == :active
assert updated_run.pending_signals == []

# 6. WorkflowTransition with reason "signal_received" AND delivery_id == delivery.id.
import Ecto.Query, only: [from: 2]

[signal_received_transition] =
  Repo.all(
    from(wt in WorkflowTransition,
      where: wt.workflow_run_id == ^run.id and wt.reason == "signal_received"
    )
  )

assert signal_received_transition.delivery_id == delivery.id

# 7. Trace timeline carries both :webhook_received AND a :workflow_* atom.
{:ok, %{timeline: timeline}} = Traces.explain_delivery(delivery.id)
event_atoms = Enum.map(timeline, & &1.event)

assert :webhook_received in event_atoms
# Progress path emits :workflow_progressed (rule-matched advance);
# stop path emits :workflow_stopped.
assert :workflow_progressed in event_atoms
```

### Stop-path scenario shape (single-step workflow + `kind: stop` rule)

```elixir
# For the stop path, the workflow definition has ONE step whose config["progress"]
# carries a `stop` rule for the bounced outcome. record_attempt/2 invokes
# Progression.progress_run/2 which evaluates the rule and writes a
# `workflow_stopped` transition + flips run.state = :stopped.
#
# Note: the run is INITIALLY :active (not :waiting on a signal) for the stop path
# so progression_run.evaluate_step/5 has rules to match against. The signal
# emission still happens (worker side), but route_signal finds no matching
# :waiting run — that's expected behavior for stop-path scenarios.
#
# For symmetry with progress path, the test can ALSO insert a SECOND :waiting run
# with pending_signals: ["chimeway.delivery.bounced"] — the bounced signal will
# resume both runs in parallel (Phase 27 fan-out). Recommended: keep the stop
# path simple — one run, :active state, on_outcome=stop rule. Then SC-2's
# "stops a workflow as configured" is proven by run.state == :stopped without
# needing the route_signal path.

step =
  Repo.insert!(
    WorkflowStep.changeset(%WorkflowStep{}, %{
      workflow_definition_id: definition.id,
      step_key: "send_email",
      step_order: 1,
      channel: "in_app",
      config: %{
        "progress" => [
          %{"kind" => "stop", "outcome" => "bounced"}
        ]
      }
    })
  )

run =
  Repo.insert!(
    WorkflowRun.changeset(%WorkflowRun{}, %{
      notification_id: notification.id,
      workflow_definition_id: definition.id,
      current_step_id: step.id,
      state: :active,                 # NOT :waiting — engine evaluates active step rules
      started_at: now,
      last_transition_at: now,
      status_reason: "phase34_stop",
      tenant_id: tenant_id,
      pending_signals: []
    })
  )
```

**Stop-path assertion deltas:**
```elixir
# Substitute these for the progress path's run/transition assertions:

updated_run = Repo.get!(WorkflowRun, run.id)
assert updated_run.state == :stopped

# Progression engine writes a workflow_stopped transition (not signal_received).
# delivery_id is populated by progression.ex:370.
[stopped_transition] =
  Repo.all(
    from(wt in WorkflowTransition,
      where: wt.workflow_run_id == ^run.id and wt.reason == "workflow_stopped"
    )
  )

assert stopped_transition.delivery_id == delivery.id

# Trace timeline carries :workflow_stopped.
{:ok, %{timeline: timeline}} = Traces.explain_delivery(delivery.id)
assert :workflow_stopped in Enum.map(timeline, & &1.event)
```

### Synthetic fixture drift fix (single-line surgical edit)

```elixir
# File: test/chimeway/traces_test.exs

# Line 416 (Scenario B fixture):
# BEFORE:
insert_workflow_transition!(run, delivery.id, "signal_received",
  %{"event_name" => "chimeway.delivery.delivered"})

# AFTER:
insert_workflow_transition!(run, delivery.id, "signal_received",
  %{"event_name" => "chimeway.delivery.succeeded"})


# Line 523 (PII boundary fixture):
# BEFORE:
insert_workflow_transition!(run, delivery.id, "signal_received",
  %{"event_name" => "chimeway.delivery.delivered"})

# AFTER:
insert_workflow_transition!(run, delivery.id, "signal_received",
  %{"event_name" => "chimeway.delivery.succeeded"})
```

Both edits are mechanical string substitutions. Verify after edit:
- `grep -n "chimeway.delivery.delivered" test/chimeway/traces_test.exs` returns no matches.
- `mix test test/chimeway/traces_test.exs` passes (45+ tests).

### Canonical 33-VERIFICATION-style requirements table format

```markdown
## Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|---------------|-------------|--------|----------|
| FLOW-01 | 31-02, 34-01, 34-02 | Normalized delivery outcomes are emitted as signals to the workflow engine. | SATISFIED | Phase 31 emission code in `lib/chimeway/webhooks/process_feedback_worker.ex:158-168` (`Chimeway.Signal.track/4` invocation; canonicalize_status/1 at line 139). Phase 34 fixture-drift fix in `test/chimeway/traces_test.exs:416,523` (lines now use `chimeway.delivery.succeeded`). Phase 34 E2E test asserts `signal.event_name == "chimeway.delivery.succeeded"` on the real webhook → worker → signal path. |
| FLOW-02 | 31-01, 32-01, 34-01, 34-02 | Workflow journeys can define outcome-based progression rules driven by asynchronous feedback. | SATISFIED | Phase 25 rule engine in `lib/chimeway/workflows/progression.ex` (advance_run lines 282-344, stop_run lines 348-379). Phase 27 signal routing in `lib/chimeway/workflows.ex:393-431` populates `WorkflowTransition.delivery_id` (Phase 32 D-02). Phase 32 trace projection in `lib/chimeway/traces.ex:570-575` dispatches `progressed_on_delivery_outcome/workflow_stopped` reasons to atoms. Phase 34 E2E test inserts real workflow + delivery rows, drains both Oban queues, asserts run.state flipped (`:waiting → :active` or `:stopped`) and timeline contains `:webhook_received` + `:workflow_*` events. |
```

### Canonical 33-04-SUMMARY:75 frontmatter line

```yaml
# In every Phase 34 plan SUMMARY frontmatter:

requirements-completed: [FLOW-01, FLOW-02]
```

This single line is the milestone-audit gate. Place it as a top-level YAML key (not
nested), at the same indentation as other top-level keys (`phase`, `plan`, `subsystem`,
etc.). Reference: `33-04-SUMMARY.md:75`.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Sync webhook validation + sync DB writes | Sync verify, async (Multi+Oban) durable handoff | Phase 33 | Phase 34 inherits this; the Multi handoff is what makes E2E proof possible. |
| Synthetic fixture-only timeline projection tests | Real-route + real Oban + real progression E2E | Phase 33 example app + Phase 34 | Catches real-path drift like the FLOW-01/02 audit gap. |
| Per-phase verification artifacts that omit REQ mapping | `requirements-completed:` frontmatter on every plan SUMMARY | Phase 29 onward | Milestone audit's REQ-mapping check passes deterministically. |
| Hand-rolled Oban job structs in tests | `Oban.drain_queue/1` with sandbox + shared mode | Phase 27 onward, Phase 33 reinforces | Drain exercises the actual Oban runtime + the atomic-handoff seam. |

**Deprecated/outdated:**
- `chimeway.delivery.delivered` as a signal event-name string. Replaced by
  `chimeway.delivery.succeeded` (production canonical since Phase 31). Phase 34's
  fixture-drift fix in `test/chimeway/traces_test.exs:416,523` is the last surface
  carrying the old string.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The example app's `dispatcher: Chimeway.Dispatch.Sync` (config/test.exs:12) does NOT interfere with Phase 31's signal emission seam in ProcessFeedbackWorker. | Pattern 2 / Pitfall 5 | If Sync dispatcher changes worker behavior, the two-drain pattern could leave assertions unsatisfied. **Mitigation:** Phase 33's existing E2E tests already exercise the same dispatcher path; Phase 34's new assertions on Signal + WorkflowTransition rows would fail loudly, not silently. [VERIFIED: examples/chimeway_demo_host/config/test.exs:12 sets `dispatcher: Chimeway.Dispatch.Sync`; Phase 31 emission is independent of dispatcher choice — it runs unconditionally inside the worker.] |
| A2 | `Deliveries.transition_status(delivery, :dispatched)` in test setup will not trigger any ancillary workflow progression that conflicts with the worker's later `record_attempt/2` call. | Pattern 3 fixture | If the transition_status function ALSO invokes progression hooks (it doesn't, per inspection), test fixtures might double-progress. [VERIFIED: only `record_attempt/2` invokes `maybe_apply_progression/1` per `lib/chimeway/deliveries.ex:1184-1207`.] |
| A3 | The Plug.Test path in the example app does not chunk request bodies, so the `:more` branch in CacheBodyReader is never exercised by Phase 34's tests. | Pattern 5 | If chunking ever activates, the existing `IO.iodata_to_binary` flatten in the controller still recovers the full body. **Mitigation:** Phase 33-06's BL-01 regression test already covers the chunked path. Phase 34 needs no special handling. |

**The remaining content (test framework + drain shape + EchoAdapter resolution + Signal
schema + production worker behavior + table format + frontmatter pattern) is all
[VERIFIED] against the cited source files.**

## Open Questions

1. **File layout: new file vs. new describe block?**
   - What we know: Both are valid per CONTEXT.md D-05 (Claude's discretion).
   - What's unclear: Whether the Phase 34 implementor will favor failure-diagnostic legibility over single-file convenience.
   - Recommendation: NEW file (`feedback_pipeline_e2e_test.exs`). Existing file's two
     describe blocks are about webhook ingress mechanics; Phase 34 spans
     ingress + worker + signal router + workflow + trace and benefits from a separate
     file. The shared setup is minimal (3 lines).

2. **Should the `chimeway.delivery.failed` scenario be added preemptively?**
   - What we know: D-09 / Deferred Ideas explicitly defaults to skip unless evidence emerges.
   - What's unclear: Whether the progress + stop scenarios surface a code path that the
     `failed` outcome would exercise differently.
   - Recommendation: SKIP unless one of the two scenarios fails. The `failed` outcome
     drives the same `canonicalize_status` + `Signal.track` + `route_signal` path as
     `bounced`; it's a no-information-gain scenario in the absence of bug evidence.

3. **Should `34-VERIFICATION.md` declare `requirements-completed: [FLOW-01, FLOW-02]` in its OWN frontmatter (in addition to the per-plan SUMMARY frontmatter)?**
   - What we know: Phase 33's `33-VERIFICATION.md` does NOT carry a `requirements-completed`
     key in frontmatter; the per-plan SUMMARY frontmatter is what the milestone audit
     scans (per `v1.4-MILESTONE-AUDIT.md:32-39`).
   - What's unclear: Whether a future audit pass might also scan VERIFICATION.md frontmatter.
   - Recommendation: FOLLOW the Phase 33 pattern verbatim — verification frontmatter
     declares `phase`, `verified`, `status`, `score` only. Per-plan SUMMARY frontmatter
     carries `requirements-completed`. If a future audit changes the expected
     location, the fix is a 1-line additive edit; not worth speculating on.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Test runtime | ✓ | 1.15+ (per project default) | — |
| PostgreSQL | Repo (sandbox mode) | ✓ (verified by Phase 33's passing test suite) | 14.x or 15.x | — |
| Phoenix | Real Endpoint pipeline | ✓ | 1.7 → 1.8.5 (resolved) | — |
| Oban | Sandboxed drain_queue | ✓ | 2.17 | — |
| Ecto.Adapters.SQL.Sandbox | `:shared` mode for cross-process visibility | ✓ | 3.11.x | — |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None.

Phase 34 introduces zero new external dependencies. All needed libraries are already
declared and validated by Phase 33's passing test suite (548 chimeway core + 7 example
app, all green per `33-VERIFICATION.md:105-107`).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + `use Oban.Testing, repo: Chimeway.Repo` (manual mode) |
| Config file | `examples/chimeway_demo_host/config/test.exs` (Oban testing: :manual, queues `chimeway_delivery: 10, chimeway_signals: 5`) |
| Quick run command | `cd examples/chimeway_demo_host && mix test test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` |
| Full suite command | `mix test && cd examples/chimeway_demo_host && mix test` (or `mix verify.example` for the example slice alone) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FLOW-01 | A real webhook callback emits a canonical `chimeway.delivery.{succeeded\|bounced\|failed}` signal that the workflow engine consumes. | E2E controller test | `cd examples/chimeway_demo_host && mix test test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs:test "progress path"` | Wave 0 |
| FLOW-02 | A workflow defined with on_outcome (advance) and stop (terminate) rules progresses or stops as a webhook callback drives the canonical contract. | E2E controller test | `cd examples/chimeway_demo_host && mix test test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs:test "stop path"` | Wave 0 |
| FLOW-01 + FLOW-02 (drift) | Synthetic trace fixtures use the canonical `chimeway.delivery.succeeded` event-name string. | Unit fixture update | `mix test test/chimeway/traces_test.exs` | Existing — modified |

### Sampling Rate

- **Per task commit:** `mix test test/chimeway/traces_test.exs` (after fixture-drift fix);
  `cd examples/chimeway_demo_host && mix test test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` (after E2E test).
- **Per wave merge:** `mix test && cd examples/chimeway_demo_host && mix test`.
- **Phase gate:** Full root suite + full example suite both green before
  `/gsd-verify-work`. `mix verify.example` covers the example slice in one alias.

### Wave 0 Gaps

- [ ] `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` — covers FLOW-01 + FLOW-02 (the new file).
- [ ] `test/chimeway/traces_test.exs` — modify lines 416 and 523 (existing file, surgical edit).

*(No new framework install required; both files use existing test infrastructure.)*

### Validation Boundaries (Nyquist Dimension 8 — required for plan-checker)

The Phase 34 surface contains **6 boundary checkpoints** that must hold for FLOW-01 and
FLOW-02 closure. Each boundary is exercised by a single test action and asserted by one
or more concrete predicates.

| # | Boundary | Test Type | Concrete Assertion(s) |
|---|----------|-----------|-----------------------|
| **B1** | **HTTP entry → ingress write** (Phase 33 atomic-handoff seam) | E2E controller test | `assert conn.status == 200` AND `assert [%Ingress{} = ingress] = Repo.all(Ingress)` AND `assert ingress.delivery_id == delivery.id` AND `assert ingress.normalized_status == "delivered"` (progress) or `"bounced"` (stop). |
| **B2** | **Worker drain → DeliveryAttempt + canonical outcome atom** (Phase 31 worker contract) | E2E (after `Oban.drain_queue(:chimeway_delivery)`) | `attempts = Repo.all(Chimeway.DeliveryAttempt)` AND `assert length(attempts) == 1` AND `assert hd(attempts).outcome == :succeeded` (progress) or `:bounced` (stop) AND `assert hd(attempts).adapter_module == to_string(DemoHost.Adapters.EchoAdapter)`. |
| **B3** | **Signal emit with canonical event_name string** (Phase 31 signal contract — D-01) | E2E (post-DRAIN #1) | `signals = Repo.all(Signal)` AND `assert length(signals) == 1` AND `assert hd(signals).event_name == "chimeway.delivery.succeeded"` (progress) or `"chimeway.delivery.bounced"` (stop) AND `assert hd(signals).tenant_id == delivery.tenant_id` AND `assert hd(signals).actor_id == delivery.actor_id`. |
| **B4** | **Workflow progression on delivery outcome** (Phase 25 engine — record_attempt/2 hook at deliveries.ex:1184-1207) | E2E (post-DRAIN #1, before DRAIN #2 for stop path; post-DRAIN #2 for progress path) | **Progress path:** `from(wt in WorkflowTransition, where: wt.workflow_run_id == ^run.id and wt.reason == "progressed_on_delivery_outcome")` returns 1 row; transition.delivery_id == delivery.id. **Stop path:** `from(wt in WorkflowTransition, where: wt.workflow_run_id == ^run.id and wt.reason == "workflow_stopped")` returns 1 row; transition.delivery_id == delivery.id; `Repo.get!(WorkflowRun, run.id).state == :stopped`. |
| **B5** | **Signal router drain → signal_received transition + run resume** (Phase 27 router + Phase 32 D-02 wiring) — progress path only | E2E (after `Oban.drain_queue(:chimeway_signals)` on progress path) | `Repo.get!(WorkflowRun, run.id).state == :active` AND `pending_signals == []` AND `from(wt in WorkflowTransition, where: wt.workflow_run_id == ^run.id and wt.reason == "signal_received")` returns 1 row AND that transition's `delivery_id == delivery.id`. |
| **B6** | **Trace projection unifies webhook + workflow on canonical vocabulary** (Phase 32 timeline) | E2E (post-DRAIN #2) | `{:ok, %{timeline: timeline}} = Traces.explain_delivery(delivery.id)` AND `:webhook_received in Enum.map(timeline, & &1.event)` AND for **progress path:** `:workflow_progressed in event_atoms`; for **stop path:** `:workflow_stopped in event_atoms`. |
| **B7** | **Synthetic fixture vocabulary drift fix** (audit-flagged drift closure — D-03) | Unit (existing file) | After edit: `grep -c "chimeway.delivery.delivered" test/chimeway/traces_test.exs` returns `0`; `mix test test/chimeway/traces_test.exs` passes (45+ tests, 0 failures). |

**Boundary B5 is progress-path-only.** The stop path's run is `:active` (not `:waiting`),
so `route_signal/1` finds no matching run and returns `{:ok, %{}}`. That is the correct
behavior; the stop path is closed by **B4**'s assertions. The two paths together
exercise both progression seams (worker-driven `progressed_on_delivery_outcome` /
`workflow_stopped` AND router-driven `signal_received`).

**Sampling completeness check:** B1+B2+B3+B6 cover FLOW-01 (signals emitted on canonical
contract from real webhook). B4+B5 cover FLOW-02 (workflow progression driven by async
feedback, both advance and stop rule kinds). B7 closes the audit-flagged vocabulary
drift. **Six runtime boundaries + one fixture boundary = 7 total checkpoints.** All
boundaries are codebase-verifiable; no human verification needed for Phase 34 closure.

## Project Constraints (from CLAUDE.md)

CLAUDE.md is not present at the repo root. Constraints are inferred from the project's
operating norms documented in `.planning/METHODOLOGY.md` and prior phase contexts:

- **Atom safety:** Never use `String.to_atom/1`. Use `String.to_existing_atom/1` only on
  bounded sets, only after canonicalization. Verified: `process_feedback_worker.ex:96,196`
  uses `String.to_existing_atom` after `canonicalize_status/1` against the `~w(succeeded
  bounced failed)` set.
- **Tenancy:** Every cross-table query must filter by `tenant_id`. Phase 34 fixtures
  must use one shared `tenant_id` across all inserted rows.
- **Atomic Multi handoffs:** "Persist domain fact + queue Oban work" boundaries use
  `Ecto.Multi` (Phase 12 / Phase 33). Phase 34 asserts the observable effect (rows in
  DB after drain) — not the implementation detail.
- **Compile-time literal atom dispatch:** Phase 34 follows the same posture as Phases 11,
  27, 32. Signal name strings are validated by string-match in tests.
- **Sandboxed Oban + shared-mode Repo:** Phase 34 reuses Phase 33's setup verbatim; do
  not modify.
- **`requirements-completed:` frontmatter on plan summaries:** Required for milestone-audit
  closure. Phase 34 every plan SUMMARY declares it (D-11).

## Sources

### Primary (HIGH confidence — read in this session)

- `lib/chimeway/webhooks/process_feedback_worker.ex` — canonicalize_status/1:139, signal emission:158-168, perform/1:43-67
- `lib/chimeway/webhooks/ingress.ex` — schema + normalized_status validation:28
- `lib/chimeway/webhooks.ex` — Multi+Oban atomic handoff:43-57
- `lib/chimeway/signal.ex` — track/4 atomic insert + enqueue:22-40
- `lib/chimeway/dispatch/signal_router_worker.ex` — perform/1:23-34
- `lib/chimeway/workflows.ex:393-431` — route_signal/1 + delivery_id wiring:419
- `lib/chimeway/workflows/progression.ex` — advance_run:282-344, stop_run:348-379
- `lib/chimeway/workflows/progression_outcome.ex` — curated outcome vocabulary:1-120
- `lib/chimeway/workflows/workflow_run.ex` — schema + state values + pending_signals
- `lib/chimeway/workflows/workflow_transition.ex` — schema + reason field + delivery_id FK
- `lib/chimeway/workflows/workflow_step.ex` — schema + config map for progression rules
- `lib/chimeway/workflows/workflow_definition.ex` — schema + workflow_key uniqueness
- `lib/chimeway/deliveries.ex:1184-1207` — maybe_apply_progression hook
- `lib/chimeway/deliveries.ex:265-338` — plan_delivery/3 with workflow_run_id opt
- `lib/chimeway/signals/signal.ex` — schema + tenant_id/actor_id validation
- `lib/chimeway/traces.ex:490-606` — timeline_rank/1, project_workflow_reason/1, build_workflow_detail/2
- `examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs` — full existing E2E test (286 lines)
- `examples/chimeway_demo_host/test/test_helper.exs` — sandbox + Application boot
- `examples/chimeway_demo_host/config/test.exs` — Oban + Repo + dispatcher config
- `examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex` — delivery_id resolution clause:37
- `examples/chimeway_demo_host/lib/demo_host_web/router.ex` — `/webhooks/chimeway/:adapter` route
- `examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex` — full controller flow
- `examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex` — Plug.Parsers + body_reader
- `examples/chimeway_demo_host/lib/demo_host/application.ex` — supervisor children
- `test/chimeway/webhooks/process_feedback_worker_test.exs:60-124` — canonical signal-name assertions:77,117
- `test/chimeway/dispatch/signal_router_worker_test.exs:1-120` — waiting-run insertion pattern
- `test/chimeway/traces_test.exs` — full file (drift target lines 416, 523; insert_workflow_run_for at 69-127)
- `test/chimeway/orchestration/workflow_progression_test.exs:1-150` — on_outcome / stop / wait_until rule shapes
- `test/chimeway/reliability/retry_exhaustion_test.exs:122-159` — drain_queue posture reference
- `test/support/data_case.ex` — root project sandbox pattern
- `config/test.exs` — root Oban queues + Repo config
- `.planning/phases/34-feedback-contract-e2e-proof/34-CONTEXT.md` — locked decisions
- `.planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md` — table format reference (lines 113-118)
- `.planning/phases/33-webhook-ingress-durability/33-04-SUMMARY.md` — frontmatter pattern (line 75)
- `.planning/phases/32-operator-traces-audit/32-VERIFICATION.md` — passed-status format reference
- `.planning/phases/32-operator-traces-audit/32-CONTEXT.md` — D-01/D-02 delivery_id wiring
- `.planning/phases/31-feedback-driven-progression/31-RESEARCH.md` — signal emission seam
- `.planning/phases/31-feedback-driven-progression/31-VERIFICATION.md` — current state (does NOT map FLOW-01/02)
- `.planning/phases/30-inbound-feedback-normalization/30-RESEARCH.md` — adapter contract
- `.planning/v1.4-MILESTONE-AUDIT.md` — gap claims for FLOW-01/02 + FEED-01/02
- `.planning/REQUIREMENTS.md` — FLOW-01, FLOW-02 definitions

### Secondary (MEDIUM confidence)

None — all claims in this research are verified against the in-tree codebase.

### Tertiary (LOW confidence)

None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every dependency is already declared and proven by Phase 33.
- Architecture (E2E test shape, drain order, fixture insertion): HIGH — every piece is
  derived from existing tests in the same repo (`webhooks_controller_test.exs`,
  `signal_router_worker_test.exs`, `traces_test.exs`,
  `orchestration/workflow_progression_test.exs`).
- Pitfalls: HIGH — derived from production code inspection (route_signal join clauses,
  record_attempt allowed transitions, drain_queue version variability per Phase
  retry_exhaustion test's resolved Open Question 2).
- Validation Architecture (boundaries B1-B7): HIGH — every assertion target is read
  directly from production source files; no speculation.
- Vocabulary contract (D-01/D-02/D-03): HIGH — three axes explicitly verified at:
  ingress.ex:28 (string axis), process_feedback_worker.ex:139,159 (signal axis),
  progression_outcome.ex:12-26 (workflow-curated axis).

**Research date:** 2026-05-02
**Valid until:** 2026-06-01 (30 days; production code is stable, only Phase 34's own
fixtures change. The next audit pass should re-verify if any of Phase 25/27/31/32/33
files are modified before Phase 34 ships).

---

## RESEARCH COMPLETE

**Phase:** 34 - feedback-contract-e2e-proof
**Confidence:** HIGH

### Key Findings

- The production contract already lives at the canonical vocabulary
  (`chimeway.delivery.{succeeded,bounced,failed}`); the audit-flagged drift is
  fixture-only at two lines (`test/chimeway/traces_test.exs:416,523`).
- The new E2E test extends the existing Phase 33 sandbox + `use Oban.Testing` + shared
  Repo harness; no new infrastructure is needed.
- The two-stage `Oban.drain_queue/1` order is the central design constraint: drain
  `:chimeway_delivery` first (lands attempt + worker-driven progression transition +
  signal emission), then drain `:chimeway_signals` (lands router-driven `signal_received`
  transition with `delivery_id` populated per Phase 32 D-02).
- The EchoAdapter already has the `delivery_id` resolution clause at line 37; Phase
  34 uses it (passing real `delivery.id` in the body) to drive a real FK lookup against
  `chimeway_deliveries`.
- The tenancy invariant is critical: `route_signal/1`'s join requires
  `notification.recipient_identity == delivery.actor_id` and
  `WorkflowRun.tenant_id == delivery.tenant_id`. Test fixtures must use one shared
  `actor_id` and one shared `tenant_id` across all inserted rows.
- Six runtime validation boundaries (B1-B6) plus one fixture boundary (B7) close
  FLOW-01 and FLOW-02 with codebase-verifiable assertions; no human verification needed.

### File Created

`.planning/phases/34-feedback-contract-e2e-proof/34-RESEARCH.md`

### Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Standard Stack | HIGH | Zero new deps; existing libraries proven by Phase 33's passing 555-test suite. |
| Architecture | HIGH | Every pattern is derived from existing tests in the same repo. |
| Pitfalls | HIGH | Derived from production code inspection (route_signal joins, allowed_transitions, drain_queue version-variability). |
| Validation | HIGH | All 7 boundaries map to concrete production code locations + concrete predicates. |

### Open Questions

1. **File layout:** new file vs. extending existing — recommended NEW file
   (`feedback_pipeline_e2e_test.exs`) for failure-diagnostic legibility.
2. **Third `failed` scenario:** default skip per D-09; revisit only if progress + stop
   surface a non-obvious code path.
3. **`requirements-completed` frontmatter location:** per-plan SUMMARY only (matching
   Phase 33); not on `34-VERIFICATION.md` itself.

### Ready for Planning

Research complete. The planner can now create PLAN.md files with concrete code excerpts
ready to paste into `<read_first>` and `<acceptance_criteria>` blocks. Recommended plan
shape:

- **34-01-feedback-pipeline-e2e-PLAN.md** — new E2E test file with progress + stop
  describes (~250 lines of test code)
- **34-02-fixture-drift-fix-PLAN.md** — two-line surgical edit to
  `test/chimeway/traces_test.exs:416,523`
- **34-VERIFICATION.md** — requirements table + Audit Notes (no separate plan)

Both plan SUMMARY files declare `requirements-completed: [FLOW-01, FLOW-02]` in
frontmatter (D-11). 34-VERIFICATION.md uses the `33-VERIFICATION.md:115-118` table format
with evidence cells citing Phase 31 emission code, Phase 32 trace projection code, and
the new Phase 34 E2E test (D-10).

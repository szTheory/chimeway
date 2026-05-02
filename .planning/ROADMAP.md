# Roadmap: Chimeway

## Milestones

- ✅ **v1.0** — [Archived roadmap](.planning/milestones/v1.0-ROADMAP.md) (shipped 2026-04-25)
- ✅ **v1.1** — [Archived roadmap](.planning/milestones/v1.1-ROADMAP.md) (shipped 2026-04-27)
- ✅ **v1.2** — [Archived roadmap](.planning/milestones/v1.2-ROADMAP.md) (shipped 2026-04-29)
- ✅ **v1.3** — [Archived roadmap](.planning/milestones/v1.3-ROADMAP.md) (shipped 2026-04-30)

## Active Milestone: v1.4 Channel Feedback Loops

### Phases

- [x] **Phase 29: Outbound Channel Contracts** - Define adapter behaviors and channel-specific render contracts for non-email channels. (completed 2026-05-01)
- [ ] **Phase 30: Inbound Feedback Normalization** - Implement a canonical webhook ingestion layer that translates vendor payloads to Chimeway delivery outcomes.
- [x] **Phase 31: Feedback-Driven Progression** - Connect normalized inbound feedback into the workflow signal spine to trigger next steps or escalations.
- [x] **Phase 32: Operator Traces & Audit** - Expand timeline traces to show provider callbacks and resulting workflow transitions. (completed 2026-05-01)
- [x] **Phase 33: Webhook Ingress Durability** - Close the webhook handoff and ingress safety gaps so provider callbacks only acknowledge success after durable queueing and safe delivery resolution. (completed 2026-05-02)
- [ ] **Phase 34: Feedback Contract E2E Proof** - Align outcome naming across feedback, workflow, and traces, then prove the real webhook-to-progression path end to end.

### Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 29. Outbound Channel Contracts | 7/7 | Complete    | 2026-05-01 |
| 30. Inbound Feedback Normalization | 1/1 | Audit gap | - |
| 31. Feedback-Driven Progression | 2/2 | Audit gap | 2026-05-01 |
| 32. Operator Traces & Audit | 2/2 | Complete    | 2026-05-01 |
| 33. Webhook Ingress Durability | 6/6 | Complete    | 2026-05-02 |
| 34. Feedback Contract E2E Proof | 0/3 | Planned | - |

## Phase Details

### Phase 29: Outbound Channel Contracts
**Goal**: Host apps can configure and render notifications for non-email channels (SMS, Push) using standard adapter boundaries.
**Depends on**: Phase 28
**Requirements**: CHAN-01, CHAN-02
**Success Criteria**:
  1. Operator can define a channel adapter for SMS or Push that implements Chimeway's behavior.
  2. Notification templates can define distinct render contracts for different channels (e.g. `text_body` for SMS vs `html_body` for email).
  3. The delivery engine correctly routes payloads to the specified non-email adapter.
**Plans**: 7 plans

Plans:
- [x] 29-01-channel-behaviour-PLAN.md — Create Chimeway.Rendering.Channel behaviour + __using__ macro
- [x] 29-02-migration-schema-PLAN.md — Migration for adapter_module column + DeliveryAttempt schema wiring
- [x] 29-03-channel-modules-PLAN.md — Create Sms/Push/Chat channel modules + refactor Email/InApp to declare @behaviour
- [x] 29-04-registry-resolver-PLAN.md — Three-layer channel_module/1 resolver + boot validation + telemetry allowlist
- [x] 29-05-adapter-resolution-PLAN.md — Per-channel adapter resolve_adapter/1 in Executor + adapter_module persistence
- [x] 29-06-traces-explain-PLAN.md — explain_delivery gains adapter_module in last_attempt + timeline entries
- [x] 29-07-test-suite-PLAN.md — Adapters.Test channel-tagging + full test coverage for all Phase 29 decisions

### Phase 30: Inbound Feedback Normalization
**Goal**: Asynchronous delivery feedback from providers is securely ingested and recorded as canonical delivery state.
**Depends on**: Phase 29
**Requirements**: FEED-01, FEED-02
**Success Criteria**:
  1. Host app can mount a webhook endpoint that receives provider callbacks.
  2. An ingested webhook successfully updates the corresponding canonical delivery record's state (e.g., from `sent` to `delivered` or `bounced`).
  3. Unknown or malformed webhooks are safely rejected or logged without crashing the ingestion layer.
**Plans**: TBD

### Phase 31: Feedback-Driven Progression
**Goal**: Workflow journeys automatically progress or branch based on the asynchronous outcomes of earlier steps.
**Depends on**: Phase 30
**Requirements**: FLOW-01, FLOW-02
**Success Criteria**:
  1. A journey configured to wait for delivery receipt progresses immediately when the `delivered` webhook is processed.
  2. A journey configured to escalate on failure triggers its next step (e.g., send SMS) when a `bounced` webhook is received.
  3. The webhook ingestion layer successfully emits standard workflow signals that the v1.3 signal router can consume.
**Plans**: 2 plans

Plans:
- [x] 31-01-PLAN.md — Denormalize Tenant and Actor ID onto Delivery
- [x] 31-02-PLAN.md — Emit Standard Workflow Signals from Webhooks

### Phase 32: Operator Traces & Audit
**Goal**: Operators can fully audit the asynchronous lifecycle of a notification journey including provider feedback.
**Depends on**: Phase 31
**Requirements**: TRAC-01, TRAC-02
**Success Criteria**:
  1. Operators querying trace data can see exactly when a webhook was received and what outcome it produced.
  2. Trace output clearly links the inbound webhook event to the workflow progression step that it triggered.
  3. Diagnostic tools can explain why a journey stopped or escalated based on asynchronous feedback.
**Plans**: 2 plans
**UI hint**: yes

Plans:
- [x] 32-01-PLAN.md — Populate WorkflowTransition.delivery_id from signal.payload in route_signal/1 (write-path delta + D-21 tests)
- [x] 32-02-PLAN.md — Extend Chimeway.Traces with webhook + workflow timeline projection (read-side helpers + D-19/D-20 tests)

### Phase 33: Webhook Ingress Durability
**Goal**: Provider callbacks acknowledge success only after durable async handoff, and webhook ingress failures stay safe and explainable.
**Depends on**: Phase 32
**Requirements**: FEED-01, FEED-02
**Gap Closure**: Closes v1.4 audit gaps for enqueue durability, host ingress proof, and unknown `delivery_id` handling.
**Success Criteria**:
  1. `Chimeway.Webhooks.process/4` only returns success when async processing is durably queued, and queue insertion failures surface explicitly.
  2. Unknown or stale `delivery_id` callbacks fail safely without crashing the feedback worker.
  3. The repo includes a runtime ingress seam or reference consumer proving a host-mounted HTTP path into `Chimeway.Webhooks.process/4`.
**Plans**: 6 plans

Plans:
- [x] 33-01-ingress-schema-PLAN.md — Ecto schema + migration + partial composite unique index for chimeway_webhook_ingress
- [x] 33-02-process-atomic-handoff-PLAN.md — Rewrite Webhooks.process/4 to atomic Multi+Oban handoff; add Deliveries.fetch_delivery/1
- [x] 33-03-worker-ingress-pivot-PLAN.md — Pivot ProcessFeedbackWorker to ingress-driven safe-noop with backwards-compat shim
- [x] 33-04-example-host-app-PLAN.md — Sibling Phoenix Mix project at examples/chimeway_demo_host/ proving host mount with body_reader + E2E test
- [x] 33-05-dedup-and-verification-PLAN.md — Dedup convergence integration test + 33-VERIFICATION.md phase-gate artifact
- [x] 33-06-cache-body-reader-chunked-fix-PLAN.md — Fix CacheBodyReader to accumulate all chunks (:more path); add chunked-body regression test (BL-01 gap closure)

### Phase 34: Feedback Contract E2E Proof
**Goal**: Feedback outcomes use one canonical contract from normalization through workflow progression and operator traces, with end-to-end proof on the real path.
**Depends on**: Phase 33
**Requirements**: FLOW-01, FLOW-02
**Gap Closure**: Closes v1.4 audit gaps for outcome vocabulary drift and missing webhook-to-workflow proof.
**Success Criteria**:
  1. Webhook normalization, signal emission, and trace projection agree on one canonical outcome/event vocabulary.
  2. An end-to-end test proves a real webhook callback updates delivery state, emits the workflow signal, and progresses or stops a workflow as configured.
  3. Verification and summary artifacts explicitly map `FLOW-01` and `FLOW-02` so the milestone audit can close without orphaned requirements.
**Plans**: 3 plans

Plans:
- [ ] 34-01-PLAN.md — Build feedback-pipeline E2E test in examples/chimeway_demo_host (progress + stop describes); two-stage Oban.drain_queue, all 7 D-07 assertions
- [ ] 34-02-PLAN.md — Fix synthetic trace fixture vocabulary drift at test/chimeway/traces_test.exs:416,523 (chimeway.delivery.delivered → chimeway.delivery.succeeded)
- [ ] 34-03-PLAN.md — Author 34-VERIFICATION.md with FLOW-01/FLOW-02 requirements table, three-axis vocabulary documentation, and Audit Notes pointing at FEED closure

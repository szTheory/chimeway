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
- [ ] **Phase 31: Feedback-Driven Progression** - Connect normalized inbound feedback into the workflow signal spine to trigger next steps or escalations.
- [ ] **Phase 32: Operator Traces & Audit** - Expand timeline traces to show provider callbacks and resulting workflow transitions.

### Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 29. Outbound Channel Contracts | 7/7 | Complete    | 2026-05-01 |
| 30. Inbound Feedback Normalization | 0/0 | Not started | - |
| 31. Feedback-Driven Progression | 0/2 | Not started | - |
| 32. Operator Traces & Audit | 0/0 | Not started | - |

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
- [ ] 31-01-PLAN.md — Denormalize Tenant and Actor ID onto Delivery
- [ ] 31-02-PLAN.md — Emit Standard Workflow Signals from Webhooks

### Phase 32: Operator Traces & Audit
**Goal**: Operators can fully audit the asynchronous lifecycle of a notification journey including provider feedback.
**Depends on**: Phase 31
**Requirements**: TRAC-01, TRAC-02
**Success Criteria**:
  1. Operators querying trace data can see exactly when a webhook was received and what outcome it produced.
  2. Trace output clearly links the inbound webhook event to the workflow progression step that it triggered.
  3. Diagnostic tools can explain why a journey stopped or escalated based on asynchronous feedback.
**Plans**: TBD
**UI hint**: yes
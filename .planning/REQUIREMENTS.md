# Milestone v1.3 Requirements

## Workflow Model

- [ ] **WRK-01**: Teams can declare a named workflow with a stable workflow key, version, and ordered notification steps for a notifier.
- [ ] **WRK-02**: Each workflow step can define explicit progression rules based on elapsed time or the prior delivery outcome.
- [ ] **WRK-03**: Workflow execution persists canonical journey state, current step, and transition reasoning on Chimeway-owned records.

## Escalations

- [ ] **ESC-01**: Teams can escalate from one step to the next when a configured wait expires or a prior delivery outcome requires follow-up.
- [ ] **ESC-02**: Teams can stop or cancel remaining workflow steps when a configured terminal condition is met.
- [ ] **ESC-03**: Workflow progression and escalation remain idempotent and concurrency-safe under retries, duplicate claims, or repeated host calls.

## API & Integration

- [ ] **API-01**: Host applications can submit explicit workflow progression signals through a stable public API without mutating durable history directly.
- [ ] **API-02**: Workflow declarations remain explicit, durable, and decoupled from notifier module names or replay-time callback re-entry.
- [ ] **INT-03**: Documentation and examples show how to model a common SaaS journey such as `in_app -> email escalation` with both sync and Oban-backed operation.

## Operator Explainability

- [ ] **OPS-03**: Operators can inspect the current workflow position, completed steps, pending next action, and the reason a workflow advanced, waited, escalated, or stopped.
- [ ] **OPS-04**: Journey traces preserve payload-safe explanation across multiple deliveries and channels under one workflow run.

## Future Requirements

- `READ-01`: Teams can branch workflows primarily on unread/read or seen state from host-app attention signals.
- `CHAN-01`: Chimeway provides first-class production adapters beyond the initial outbound seam for SMS, push, and chat.
- `CHAN-02`: Transport-specific delivery receipts and webhook callbacks flow back into lifecycle traces and workflow progression uniformly.
- `ADOPT-01`: Chimeway ships a richer reference app or operator UI surface for production adoption.

## Out of Scope

- Visual journey builders or hosted orchestration UIs — this milestone is API-first and library-centered.
- Marketing automation or campaign sequencing — Chimeway remains transactional/product notification infrastructure.
- Broad vendor/channel expansion in the same milestone — defer until the workflow model is stable and proven.
- Read/unread-driven branching as the milestone's primary progression model — defer until time/outcome journeys are established.

## Traceability

| Requirement | Phase | Status | Notes |
|---|---|---|---|
| WRK-01 | 24 | planned | Workflow identity and declaration contract |
| WRK-02 | 25 | planned | Time/outcome-based progression rules |
| WRK-03 | 24 | planned | Durable journey state and transition persistence |
| ESC-01 | 26 | planned | Escalation between workflow steps |
| ESC-02 | 26 | planned | Stop/cancel terminal semantics |
| ESC-03 | 25 | planned | Idempotent progression and race safety |
| API-01 | 27 | planned | Stable host signal API |
| API-02 | 24 | planned | Durable declaration model |
| INT-03 | 28 | planned | Docs and reference flows |
| OPS-03 | 27 | planned | Journey inspection surface |
| OPS-04 | 27 | planned | Payload-safe chain-level traces |

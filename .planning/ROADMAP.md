# Roadmap: Chimeway

## Milestones

- ✅ **v1.0** — [Archived roadmap](.planning/milestones/v1.0-ROADMAP.md) (shipped 2026-04-25)
- ✅ **v1.1** — [Archived roadmap](.planning/milestones/v1.1-ROADMAP.md) (shipped 2026-04-27)
- ✅ **v1.2** — [Archived roadmap](.planning/milestones/v1.2-ROADMAP.md) (shipped 2026-04-29)

## Active Milestone

### v1.3 Workflow Journeys

**Goal:** Turn Chimeway from single-notification orchestration into a durable, explainable workflow engine for multi-step notification journeys.
**Phases:** 24-28
**Requirements:** 11 mapped

| # | Phase | Goal | Requirements | Success Criteria |
|---|---|---|---|---|
| 24 | Workflow Contracts & State Spine | Persist stable workflow identity, declarations, run state, and transition history. | WRK-01, WRK-03, API-02 | 4 |
| 25 | Progression Engine & Wait Gates | Advance workflows safely based on elapsed time and prior delivery outcome. | WRK-02, ESC-03 | 4 |
| 26 | Escalations & Stop Conditions | Escalate to later steps and terminate workflows without over-notifying. | ESC-01, ESC-02 | 4 |
| 27 | Journey Traces & Host Signal API | Expose journey inspection and a stable host signal seam. | API-01, OPS-03, OPS-04 | 4 |
| 28 | Docs, Reference Flows & Closure | Demonstrate real SaaS workflow usage and close milestone verification. | INT-03 | 3 |

## Phase Details

### Phase 24: Workflow Contracts & State Spine

**Goal:** Persist stable workflow identity, declarations, run state, and transition history.
**Requirements:** WRK-01, WRK-03, API-02

Success criteria:
1. Workflow declarations persist a stable workflow key/version and ordered step definitions without durable dependence on module names.
2. Triggering a journey-enabled notifier creates durable workflow run state linked to canonical notification and delivery records.
3. Transition history records why a workflow entered its current state and which step is active.
4. Recovery/replay paths can read persisted workflow declarations without re-entering notifier callbacks for historical truth.

### Phase 25: Progression Engine & Wait Gates

**Goal:** Advance workflows safely based on elapsed time and prior delivery outcome.
**Requirements:** WRK-02, ESC-03

Success criteria:
1. Workflow steps can wait until a due time and then advance through a durable progression seam.
2. Progression rules can branch based on prior delivery outcome without mutating historical deliveries.
3. Repeated worker retries or duplicate claims do not emit duplicate next-step deliveries.
4. Progression behavior is verified under concurrency-focused tests for due-step races and retries.

### Phase 26: Escalations & Stop Conditions

**Goal:** Escalate to later steps and terminate workflows without over-notifying.
**Requirements:** ESC-01, ESC-02

Success criteria:
1. A workflow can escalate from an earlier step to a later step after a configured wait or qualifying outcome.
2. Terminal conditions stop or cancel remaining steps durably before further deliveries are emitted.
3. Escalation and stop reasons remain operator-visible and consistent across sync and Oban-backed execution.
4. End-to-end verification proves workflows do not continue after a terminal success or explicit stop condition.

### Phase 27: Journey Traces & Host Signal API

**Goal:** Expose journey inspection and a stable host signal seam.
**Requirements:** API-01, OPS-03, OPS-04

Success criteria:
1. Host applications can submit validated workflow progression signals through a stable API boundary.
2. Operators can inspect the current workflow position, completed steps, pending next action, and stop/escalation reasons.
3. Journey trace surfaces remain payload-safe and tenancy-aware while spanning multiple deliveries and channels.
4. Workflow inspection surfaces answer "where is this recipient in the journey and why?" from persisted state alone.

### Phase 28: Docs, Reference Flows & Closure

**Goal:** Demonstrate real SaaS workflow usage and close milestone verification.
**Requirements:** INT-03

Success criteria:
1. Documentation walks through at least one realistic SaaS journey such as `in_app -> email escalation`.
2. Reference guidance covers both sync-first and Oban-backed progression boundaries.
3. Milestone verification proves all workflow requirements are satisfied and traceability is updated truthfully.

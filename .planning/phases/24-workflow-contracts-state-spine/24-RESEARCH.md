# Phase 24: Workflow Contracts & State Spine - Research

**Researched:** 2026-04-29
**Domain:** Durable workflow declarations, workflow run state, and append-only transition history for journey-enabled notifications
**Confidence:** HIGH for repo-fit architecture; MEDIUM for exact naming and task slicing across schema/API surfaces

<user_constraints>
## Locked Scope

- Persist stable workflow declarations with `workflow_key` and `workflow_version`; do not store durable workflow identity as notifier module names.
- Create durable workflow run state anchored to canonical notification and delivery records.
- Persist transition history that explains why the run entered its current state and which step is active.
- Keep recovery and replay readable from persisted workflow declarations without re-entering notifier callbacks.

## Explicitly Deferred

- Wait gates, due-time progression, and outcome-branching logic belong to Phase 25.
- Escalations, stop conditions, and terminal workflow semantics belong to Phase 26.
- Host progression signals and journey inspection APIs belong to Phase 27.
- Reference docs and SaaS walkthroughs belong to Phase 28.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WRK-01 | Teams can declare a named workflow with a stable workflow key, version, and ordered notification steps for a notifier. | Add a notifier workflow declaration seam that normalizes and serializes ordered step definitions at trigger time into first-class workflow declaration storage. |
| WRK-03 | Workflow execution persists canonical journey state, current step, and transition reasoning on Chimeway-owned records. | Add workflow run and transition tables anchored to notification and delivery rows, with explicit state fields instead of inferring truth from queue state. |
| API-02 | Workflow declarations remain explicit, durable, and decoupled from notifier module names or replay-time callback re-entry. | Follow the existing rendering/orchestration posture: resolve once at trigger time, serialize durable facts, replay from stored data. |
</phase_requirements>

## Summary

Phase 24 should mirror the pattern Chimeway already established for rendering, orchestration, and digests: resolve declarations once at trigger time, persist durable normalized facts in first-class tables, and let later planning/recovery logic read those facts without callback re-entry.

The current repo has the right anchors but not the workflow layer yet. `Chimeway.Trigger` persists one `Notification` row per recipient and already snapshots render/orchestration declarations. `Chimeway.DeliveryPlanning` and `Chimeway.Deliveries` then operate on canonical delivery rows from persisted declarations. The missing layer is a workflow-specific declaration/run/history spine that sits between notification creation and later delivery progression.

The cleanest repo-fit design is:

1. Add a workflow declaration seam to `Chimeway.Notifier`, parallel to `rendering/2` and `orchestration/2`.
2. Persist normalized workflow declarations in explicit `workflow_definitions` and `workflow_steps` tables keyed by `workflow_key` and `workflow_version`.
3. Create one `workflow_run` per recipient notification when a workflow declaration exists.
4. Add append-only `workflow_transition` rows that record state changes, active step identity, reason, and related delivery linkage.
5. Add foreign-key linkage from step-generated delivery rows back to the owning workflow run and workflow step so later phases can progress from canonical persisted truth.

That keeps workflow truth explainable, queryable, and aligned with the existing event -> notification -> delivery lifecycle instead of introducing a queue-owned orchestration subsystem.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Normalize workflow declarations | `Chimeway.Notifier` | `Chimeway.Trigger` | The repo already resolves notifier contracts in `Notifier` and persists them in `Trigger`. |
| Persist durable workflow definition identity | Ecto schemas + migrations | Trigger-time insert/upsert service | Stable string identity/version belongs in first-class tables, like `DigestRule`. |
| Create workflow runs | Trigger-time transaction | `Notification` as anchor | One run per recipient notification matches the existing per-recipient notification spine. |
| Record current state and active step | Workflow run row | transition append log | Current truth needs a direct row field; history needs an append-only audit trail. |
| Link step deliveries to the run | `Delivery` row fields / FK | delivery planning seam | Later progression and trace phases need canonical delivery linkage, not inferred joins. |
| Explain why a workflow moved | transition rows | traces layer later | Explicit reason-bearing facts match the project’s explainability posture. |

## Recommended Data Model

### 1. Workflow definitions

Use a dedicated schema pair analogous to digest rules:

- `chimeway_workflow_definitions`
  - `id`
  - `workflow_key`
  - `workflow_version`
  - `notification_key`
  - `inserted_at` / `updated_at`
- `chimeway_workflow_steps`
  - `id`
  - `workflow_definition_id`
  - `step_key`
  - `step_order`
  - `channel`
  - `template of progression seed data` stored as explicit columns where Phase 24 already knows them, and a tightly scoped `config` map only for later-phase deferred semantics

Why: Phase 24 explicitly rejects hiding workflow shape in `Notification.orchestration` or `Delivery.planning_context`. `DigestRule` shows the correct repo pattern for stable identity plus versioned declarations.

### 2. Workflow runs

Add a `chimeway_workflow_runs` table anchored to the canonical notification row:

- `id`
- `notification_id`
- `workflow_definition_id`
- `current_step_id`
- `state`
- `started_at`
- `last_transition_at`
- `status_reason`
- `status_context`

One run per notification is the least-surprising model because a notification is already the per-recipient anchor. Deliveries remain the execution artifacts per channel/step.

### 3. Workflow transitions

Add append-only `chimeway_workflow_transitions` rows:

- `id`
- `workflow_run_id`
- `workflow_step_id` nullable
- `delivery_id` nullable
- `from_state`
- `to_state`
- `reason`
- `context`
- `inserted_at`

Phase 24 should at minimum record:

- run created
- initial step activated
- delivery linked to step/run

Later phases can append wait/branch/escalation/stop reasons without redesigning the table.

## Recommended Runtime Flow

1. `Chimeway.Trigger` resolves workflow declaration from the notifier alongside rendering/orchestration.
2. Trigger transaction upserts or fetches the durable workflow definition/version and ordered steps.
3. Notification rows are inserted as today.
4. For each workflow-enabled notification, create a workflow run row inside the same transaction.
5. Persist an initial transition row that records why the run entered its initial state and which step is active.
6. Delivery planning creates the canonical first-step delivery row and links it back to `workflow_run_id` and `workflow_step_id`.
7. Recovery/replay later reads the persisted workflow definition and run data instead of calling workflow callbacks again.

This keeps the repo’s existing posture intact: normalized declarations resolved once, persistent truth stored on Chimeway-owned rows, and later runtime work driven from those rows.

## Repo-Fit Patterns

### Pattern 1: Trigger-time declaration persistence

Use `Chimeway.Trigger.notifications_attrs/4` as the model for resolving workflow declarations once per recipient and writing sanitized durable facts during the event/notification transaction.

### Pattern 2: Stable identity + versioned declarations

Use `Chimeway.Digests.DigestRule` as the schema pattern for:

- string identity keys
- positive integer version
- uniqueness on `(key, version)`
- explicit columns over opaque blobs

### Pattern 3: Aggregate state row + append-only fact rows

Use `DigestBucket` plus `DigestMembership` as the best analog for:

- one current-state aggregate row (`workflow_run`)
- one auditable fact/history row set (`workflow_transitions`)

### Pattern 4: Persisted declarations for replay

Use the rendering/orchestration recovery posture from Phases 21-23:

- `Notification.render_channels`
- `Notification.orchestration`
- `Deliveries.recover_event/2` with `use_persisted_*` opts

Workflow declarations should be replayable from durable rows the same way.

## File-Level Impact

### Likely new files

- `lib/chimeway/workflows/workflow_definition.ex`
- `lib/chimeway/workflows/workflow_step.ex`
- `lib/chimeway/workflows/workflow_run.ex`
- `lib/chimeway/workflows/workflow_transition.ex`
- `lib/chimeway/workflows.ex`
- migration files for the four tables above
- tests under `test/chimeway/workflows/`

### Likely modified files

- `lib/chimeway/notifier.ex`
- `lib/chimeway/trigger.ex`
- `lib/chimeway/notifications/notification.ex`
- `lib/chimeway/delivery.ex`
- `lib/chimeway/delivery_planning.ex`
- `lib/chimeway/deliveries.ex`
- `test/chimeway/notifier_contract_test.exs`
- `test/chimeway/trigger_pipeline_test.exs`
- orchestration/recovery tests

## Testing Strategy

The phase should plan for three proof layers:

1. Contract tests
   - notifier workflow declarations normalize valid/invalid shapes
   - stable `workflow_key`/`workflow_version` validation
   - ordered step normalization

2. Trigger-time integration tests
   - triggering a workflow-enabled notifier persists definition/run/transition records
   - repeated triggers reuse durable declaration identity correctly
   - canonical notification rows remain the anchor

3. Replay/regression tests
   - replay/recovery can read persisted workflow declarations without workflow callback re-entry
   - initial state and active step remain reconstructable from persisted run + transition rows alone

## Risks And Guardrails

- Do not let workflow declarations collapse into notification metadata or delivery planning context. That would violate the locked scope immediately.
- Do not make `workflow_run` truth depend on Oban job state; Phase 24 is pre-progression and must stay durable-first.
- Do not overbuild wait/branch/escalation semantics now. The schema must permit later phases, but this phase should only seed the durable spine.
- Keep workflow linkage additive to the existing notification/delivery model. Replacing those anchors would create needless blast radius.

## Validation Architecture

Phase 24 validation should prove durable truth from database state alone:

- Trigger a workflow-enabled notifier.
- Assert persisted workflow definition identity and ordered steps.
- Assert persisted workflow run current state and active step.
- Assert at least one transition row explains run creation / activation.
- Assert delivery rows for the active step link back to the workflow run and step.
- Re-run planning/recovery paths without notifier callback re-entry and assert the same durable workflow declaration is used.

## Recommended Plan Split

The phase is best planned as 3-4 execution plans:

1. workflow declaration contract + schemas
2. trigger-time persistence + run creation
3. delivery/recovery linkage
4. tests and traceability closure if needed

That split matches the repo’s recent phase size and keeps migrations, runtime seams, and replay proof isolated enough for execution.

## Recommendation

Implement Phase 24 as a durable workflow subsystem that is tightly integrated with the existing notification spine:

- definition tables for stable identity and ordered steps
- run table for current workflow state
- transition table for append-only explainability
- notifier/trigger hooks that persist workflow facts once
- delivery linkage that lets future phases advance from canonical persisted truth

Anything thinner than that will leave workflow truth hidden in blobs; anything broader risks prematurely implementing Phase 25-27 behavior in the wrong place.

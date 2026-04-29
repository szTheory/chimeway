# Architecture Research

**Domain:** Durable notification workflow orchestration
**Researched:** 2026-04-29
**Confidence:** HIGH

## Standard Architecture

### System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                 Declaration / Host Integration             │
├─────────────────────────────────────────────────────────────┤
│  Notifier API   Workflow API   Host Signals   Preview/Docs │
└───────────────┬───────────────┬───────────────┬─────────────┘
                │               │               │
┌───────────────┴─────────────────────────────────────────────┐
│                Planning / Progression Engine               │
├─────────────────────────────────────────────────────────────┤
│ Workflow Resolver │ Step Evaluator │ Escalation Planner    │
│ Wait Gate Logic   │ Transition Log │ Progression Scheduler │
└───────────────┬─────────────────────────────────────────────┘
                │
┌───────────────┴─────────────────────────────────────────────┐
│                   Durable Delivery Substrate               │
├─────────────────────────────────────────────────────────────┤
│ Notifications │ Deliveries │ Attempts │ Traces │ Digests    │
└───────────────┬─────────────────────────────────────────────┘
                │
┌───────────────┴─────────────────────────────────────────────┐
│                     Persistence / Workers                  │
├─────────────────────────────────────────────────────────────┤
│ PostgreSQL │ Ecto.Multi │ Oban Workers │ Telemetry         │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Workflow declaration resolver | Normalizes workflow key/version and step definitions | Public API + changesets + persisted declaration snapshot |
| Journey state store | Owns workflow runs, current step, and transition facts | New Ecto schemas/tables anchored to notification/delivery identity |
| Progression engine | Decides when to wait, advance, escalate, stop, or noop | Deterministic transition evaluator called from planner/workers |
| Progression scheduler | Re-checks due waits and advances next steps durably | Oban-backed scheduled worker for due workflow transitions |
| Journey traces | Exposes payload-safe explanations across all workflow steps | Extension of existing trace APIs with workflow summaries |

## Recommended Project Structure

```text
lib/chimeway/
├── workflows/          # workflow state, transitions, and public API
│   ├── definition.ex   # durable workflow declarations
│   ├── run.ex          # workflow-run schema/state
│   ├── transition.ex   # transition persistence
│   └── progression.ex  # step advancement logic
├── dispatch/           # worker integration for due progression
├── traces/             # workflow-aware explanation/query surfaces
├── notifier.ex         # declaration seam updates
└── policy/             # reused suppression and stop-condition logic
```

### Structure Rationale

- **`workflows/`:** keeps journey concepts explicit instead of scattering them through planner, policy, and dispatch modules.
- **`dispatch/`:** reuses existing async seams for due-step progression and escalation timing.
- **`traces/`:** keeps explainability a first-class surface rather than an afterthought bolted onto workers.

## Architectural Patterns

### Pattern 1: Durable declaration snapshot

**What:** Persist workflow identity and normalized step declarations when the notification is planned.
**When to use:** Always for journey-enabled notifications.
**Trade-offs:** Slightly more storage, but replay and support become deterministic.

### Pattern 2: Transition log plus current-state pointer

**What:** Keep both current workflow state and an append-only transition history.
**When to use:** Whenever a workflow can wait, advance, escalate, or stop over time.
**Trade-offs:** More writes, but much better auditability and debugging.

### Pattern 3: Delivery-owned step materialization

**What:** When a workflow step emits a delivery, keep the emitted delivery linked back to the workflow run and step.
**When to use:** For every step that results in an actual notification delivery.
**Trade-offs:** Requires explicit linkage, but preserves the canonical delivery spine Chimeway already values.

## Data Flow

### Request Flow

```text
Trigger Notification
    ↓
Resolve workflow definition
    ↓
Persist workflow run + first-step state
    ↓
Plan delivery for current step
    ↓
Dispatch or wait
    ↓
Observe outcome / due time
    ↓
Evaluate next transition
    ↓
Plan next step or stop
```

### Key Data Flows

1. **Trigger-to-first-step:** notification planning creates the workflow run, records the first transition, and emits the initial delivery.
2. **Wait-to-advance:** a due worker or explicit progression call evaluates timing/outcome guards and advances idempotently.
3. **Escalation-to-stop:** subsequent steps emit additional deliveries until a terminal condition ends the workflow.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 0-10k active workflows | Monolith + PostgreSQL + Oban is sufficient |
| 10k-250k active workflows | Add tighter due-step indexes, batching, and worker concurrency tuning |
| 250k+ active workflows | Consider partitioning/archive strategies before introducing external orchestration systems |

### Scaling Priorities

1. **First bottleneck:** due-step scanning and transition contention; fix with indexes, targeted queries, and idempotent claims.
2. **Second bottleneck:** trace joins across workflow runs and deliveries; fix with summary tables or query-specific projections, not by weakening explainability.

## Anti-Patterns

### Anti-Pattern 1: Split workflow truth from delivery truth

**What people do:** store workflow state in one place and treat deliveries as loosely related side effects.
**Why it's wrong:** support surfaces and recovery paths drift immediately.
**Do this instead:** link workflow runs, steps, and emitted deliveries through canonical IDs.

### Anti-Pattern 2: Recompute transitions from runtime callbacks

**What people do:** infer workflow state by re-running notifier logic later.
**Why it's wrong:** replay changes when code changes, which breaks durable history.
**Do this instead:** persist normalized transition/declaration facts up front.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Oban | Scheduled progression workers | Primary wait/escalation engine for time-based workflows |
| Future provider callbacks | Optional workflow input events | Keep deferred until the later channel-feedback milestone |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `Notifier` ↔ `Workflows` | Public API + normalized declaration structs | Keep contract explicit and versioned |
| `Workflows` ↔ `Dispatch` | Canonical delivery ids + durable state transitions | Avoid runtime-only ephemeral handoffs |
| `Workflows` ↔ `Traces` | Query/projection layer | Operator surfaces must stay payload-safe and tenancy-aware |

## Sources

- https://laravel.com/docs/12.x/notifications
- https://symfony.com/doc/current/notifier.html
- https://github.com/excid3/noticed
- Local code context: `lib/chimeway/notifier.ex`, `lib/chimeway/inbox.ex`, `lib/chimeway/dispatch/oban_worker.ex`

---
*Architecture research for: durable notification workflow orchestration*
*Researched: 2026-04-29*

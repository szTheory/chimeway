# Architecture Research

**Domain:** Embedded notification infrastructure for Elixir applications  
**Researched:** 2026-04-23  
**Confidence:** HIGH

## Standard Architecture

### System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                    Host Application Layer                   │
├─────────────────────────────────────────────────────────────┤
│  Domain Events  Preferences  Auth/Tenancy  Admin Mounting  │
└───────────────┬───────────────┬─────────────┬───────────────┘
                │               │             │
┌───────────────┴─────────────────────────────────────────────┐
│                    Chimeway Core Layer                     │
├─────────────────────────────────────────────────────────────┤
│  Notifier Registry  Policy Engine  Planner  Trace Builder  │
│  Idempotency Guard  Adapter Behaviour Contracts            │
└───────────────┬───────────────────────┬────────────────────┘
                │                       │
┌───────────────┴──────────────┐  ┌─────┴────────────────────┐
│ Persistence Layer (Ecto)     │  │ Dispatch Layer           │
├──────────────────────────────┤  ├──────────────────────────┤
│ Events / Notifications       │  │ Sync executor            │
│ Deliveries / Attempts        │  │ Oban workers (optional)  │
│ Preferences / Routes         │  │ Retry/backoff policy     │
└───────────────┬──────────────┘  └──────────┬───────────────┘
                │                            │
┌───────────────┴────────────────────────────┴───────────────┐
│                      Adapter Layer                         │
├─────────────────────────────────────────────────────────────┤
│ In-app  Swoosh Email  Webhook  Slack  Push  SMS (optional)│
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Notifier definition | Declares key/version, recipient resolver, channel plans, renderers | Behaviour + optional DSL macros that expand to explicit callbacks |
| Planner/policy engine | Converts events into per-recipient channel delivery plans with suppression reasoning | Pure modules with deterministic decision structs |
| Persistence boundary | Stores durable lifecycle records and idempotency constraints | Ecto schemas + migrations + transactional `Ecto.Multi` |
| Dispatch executor | Executes deliveries and records attempts/results | Sync executor plus optional Oban workers |
| Adapter contracts | Isolates provider-specific code behind consistent deliver semantics | Behaviours + contract tests + fake adapter |
| Operator surface | Exposes traceability and diagnostics to humans | Optional Phoenix/LiveView routes and dashboards |

## Recommended Project Structure

```text
lib/
├── chimeway/                     # public API and core contracts
│   ├── notifier.ex
│   ├── planner.ex
│   ├── policy.ex
│   ├── idempotency.ex
│   ├── telemetry.ex
│   ├── adapters/                # adapter behaviours and shared structs
│   └── dispatch/                # sync + worker orchestration seams
├── chimeway_ecto/               # optional Ecto persistence package/scope
│   ├── schemas/
│   ├── queries/
│   └── migrations/
├── chimeway_oban/               # optional Oban integration package/scope
│   └── workers/
└── chimeway_phoenix/            # optional host integration and admin mount
    ├── live/
    ├── router/
    └── components/
```

### Structure Rationale

- **Core separated from integrations:** keeps baseline dependency footprint low and supports non-Phoenix usage.
- **Persistence and dispatch as explicit seams:** clarifies what is durable model vs execution engine.
- **Optional Phoenix/admin package path:** supports "batteries included" without forcing UI deps for API-only adopters.

## Architectural Patterns

### Pattern 1: Stable Key + Version Contract

**What:** Persist a stable string key and version for each notification type.  
**When to use:** Always, from first migration.  
**Trade-offs:** Adds upfront discipline; prevents rename/backfill breakage later.

**Example:**
```elixir
%Event{notification_key: "comment.created", version: 1}
```

### Pattern 2: Plan-Then-Dispatch Pipeline

**What:** Separate deterministic planning from side-effectful provider calls.  
**When to use:** Always for explainability and testing.  
**Trade-offs:** More structs/tables; significantly easier debugging and retries.

**Example:**
```elixir
event
|> Planner.plan()
|> Persistence.persist()
|> Dispatcher.execute(mode: :sync)
```

### Pattern 3: Policy Re-evaluation at Perform Time

**What:** Run policy before enqueue and again immediately before send.  
**When to use:** Any delayed/queued channel or fallback logic.  
**Trade-offs:** Extra reads/checks; prevents stale preference sends.

## Data Flow

### Request Flow

```text
[Domain action]
    ↓
[Chimeway.trigger]
    ↓
[Notifier + recipient resolution]
    ↓
[Policy evaluation]
    ↓
[Persist Event/Notification/Delivery rows]
    ↓
[Dispatch sync or enqueue]
    ↓
[Adapter attempt + response classification]
    ↓
[Delivery final state + trace update]
```

### State Management

```text
notify_events
    └─> notify_notifications (recipient-level canonical state)
           └─> notify_deliveries (channel-level lifecycle)
                  └─> notify_delivery_attempts (provider call history)
```

### Key Data Flows

1. **Trigger to traceability:** single trigger call yields auditable artifacts even when external send fails.
2. **Read-state fallback:** in-app read/seen transitions influence delayed outbound policy decisions.
3. **Retry and suppression:** failures and suppressions are explicit states, not hidden log-only outcomes.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 0-1k active users | Sync path acceptable for non-critical channels; keep schemas and idempotency in place. |
| 1k-100k active users | Use Oban queues, explicit channel queues, retry/backoff tuning, index optimization. |
| 100k+ active users | Partition high-volume tables, add archival/retention, separate adapter packages/services if needed. |

### Scaling Priorities

1. **First bottleneck:** write amplification in delivery/attempt tables - solve with indexing, batching, retention windows.
2. **Second bottleneck:** provider and queue pressure - solve with per-channel queue tuning and adaptive backoff/rate limits.

## Anti-Patterns

### Anti-Pattern 1: Adapter Calls Before Persistence

**What people do:** send via provider first, then try to persist outcomes.  
**Why it's wrong:** failures/timeouts lose authoritative lifecycle records.  
**Do this instead:** persist first, then dispatch, then write attempt outcomes.

### Anti-Pattern 2: Conflating In-App and External Delivery State

**What people do:** treat "email sent" as equivalent to "notification seen by user."  
**Why it's wrong:** weakens UX semantics and makes fallback logic incorrect.  
**Do this instead:** keep canonical in-app state separate from per-channel delivery outcomes.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Email providers via Swoosh | Adapter package wrapping `%Swoosh.Email{}` rendering/delivery | Reuse Local/Test/Sandbox patterns for deterministic tests. |
| Oban | Optional worker package with transactional enqueue | Required for robust async fanout and retries. |
| Push/SMS/Slack/webhooks | Behaviour-based optional adapters | Keep contract tests and fake providers to avoid regressions. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Host app -> Chimeway core | Public API + context structs | Host owns auth/tenancy/correlation IDs. |
| Core -> persistence | repository abstraction / Ecto adapter | Enables testing and future storage variants. |
| Core -> adapters | behaviour callbacks | Keeps channel implementations swappable. |

## Sources

- `prompts/elixir_notifykit_research_brief.md`
- `prompts/chimeway-host-app-integration-seam.md`
- `prompts/chimeway-admin-ui-and-operator-ia.md`
- `prompts/chimeway-engineering-dna-from-prior-libs.md`

---
*Architecture research for: Chimeway*
*Researched: 2026-04-23*

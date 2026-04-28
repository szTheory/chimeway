# Project Research: Architecture

**Project:** Chimeway  
**Milestone:** v1.2 Delivery Orchestration  
**Researched:** 2026-04-28  
**Confidence:** HIGH

## Focus

How should delivery windows, digests, rendering identity, and recovery fit into Chimeway's existing event -> notification -> delivery -> attempt lifecycle?

## Recommended Architecture

### 1. Extend planning, do not bypass it

- Immediate send, deferred send, and digest eligibility should all be outcomes of the existing planning stage.
- Chimeway should persist orchestration intent before side effects happen.

### 2. Model deferral as lifecycle state, not ad hoc queue timing

- Delivery windows need durable fields for rule identity, timezone context, and next eligible send time.
- Oban scheduling should execute the persisted decision, not become the source of truth for that decision.

### 3. Model digests as explicit aggregates

- Digest emission should reference a durable batch or accumulator record that links source notifications to one emitted digest delivery.
- Inclusion and exclusion rules need their own explainability facts, not only job logs.

### 4. Separate rendering identity from notifier module identity

- Durable content versioning should survive notifier refactors.
- The persisted record should identify template or rendering version separately from `notification_key`.

### 5. Recovery should re-drive persisted state, not recreate history

- Reconciliation jobs should inspect stored events and deliveries, determine which lifecycle work never completed, and continue safely from there.
- Reconciliation should preserve idempotency and maintain a readable audit trail.

## Suggested Build Order

1. Delivery-window persistence and planning semantics
2. Scheduled resume execution path
3. Digest accumulation model
4. Digest emission and explainability
5. Rendering identity and preview contracts
6. Recovery and aggregate analytics

## Sources

- Oban Job scheduling and retry state model: https://hexdocs.pm/oban/Oban.Job.html
- Phoenix.Swoosh rendering contract: https://hexdocs.pm/phoenix_swoosh/Phoenix.Swoosh.html
- Existing Chimeway lifecycle and duplicate-trigger caveat: `lib/chimeway/trigger.ex`

---
*Research completed: 2026-04-28*

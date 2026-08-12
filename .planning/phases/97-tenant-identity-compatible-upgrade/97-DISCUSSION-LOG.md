# Phase 97: Tenant Identity & Compatible Upgrade - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-08-11
**Phase:** 97-tenant-identity-compatible-upgrade
**Mode:** assumptions
**Areas analyzed:** Durable Tenant Identity, Explicit Tenant-Scoped Public Boundary, Non-Guessing Additive Upgrade

## Assumptions Presented

### Durable Tenant Identity

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Events and notifications each persist immutable `tenant_id`; event idempotency is enforced and recovered by `{tenant_id, idempotency_key}`. | Confident | `lib/chimeway/trigger.ex`; `lib/chimeway/events/event.ex`; `lib/chimeway/notifications/notification.ex`; migrations `001`, `002`, and `030` |

### Explicit Tenant-Scoped Public Boundary

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Inbox, trace, admin, and recovery operations require supplied tenant scope; old unscoped signatures work only through explicit single-tenant compatibility configured with that tenant identity. | Unclear | `lib/chimeway/inbox.ex`; `lib/chimeway/traces.ex`; `lib/chimeway/admin.ex`; `lib/chimeway/deliveries.ex`; Phase 70 and Phase 61 context |

### Non-Guessing Additive Upgrade

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Add tenant identity without silently assigning legacy ownership; report ambiguous rows for explicit host reconciliation and retain one static storage prefix. | Confident | `priv/chimeway_migrations/030_add_tenant_and_actor_to_chimeway_deliveries.exs`; `lib/chimeway/install/migrations.ex`; Phase 73 and Phase 74 context |

## Corrections Made

No corrections — all assumptions confirmed. The user explicitly confirmed compatibility as a configured concrete single-tenant identity.

## Methodology Applied

- **Cohesive Recommendation Default:** Tenant identity belongs directly on the event and notification lifecycle spine rather than being inferred through optional child rows.
- **High-Impact Escalation Gate:** The compatibility contract was treated as the sole high-blast-radius assumption and explicitly confirmed.
- **Research-First Decision Ownership:** Code and prior contexts established the safety boundary without offloading medium-stakes implementation choices.
- **One-Shot Recommendation Bias:** One fail-closed explicit-scope contract was recommended, with compatibility as a declared exception.
- **Durable Explainability Bias:** Ambiguous legacy ownership remains visible reconciliation evidence rather than a fabricated default tenant.
- **Least-Surprise DX Default:** Legacy calls survive only after a host declares their concrete tenant identity.
- **Low-Escalation Recommendation Default:** Existing recovery/admin seams and static storage routing remain intact.

# Chimeway

## What This Is

Chimeway is an open-source, embedded notification layer for Elixir and Phoenix applications. It provides durable notification records and delivery planning from one event to many recipients across channels, with explainable traces from trigger through policy and provider attempts. It is local-first by design: host applications keep their own data, policies, and operational controls.

## Core Value

Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, or was suppressed.

## Requirements

### Validated

- [x] Developers can trigger one domain event that fans out to many recipients with durable event and notification records. *(Validated in Phase 01: durable-core-spine)*
- [x] Chimeway enforces idempotency across event creation and notification planning to prevent duplicate records. *(Validated in Phase 01: durable-core-spine)*
- [x] Users get durable in-app notification records with explicit `seen`, `read`, and archival semantics. *(Validated in Phase 01: durable-core-spine)*
- [x] The project ships with strict OSS engineering discipline (`mix verify.*`, CI lane hygiene, docs contracts, release checks). *(Validated in Phase 05: oss-verification-and-release-hardening)*

### Active

- [ ] Applications have explicit policy evaluation before enqueue and before perform for late suppression (preferences, quiet hours, caps, consent).
- [ ] Developers can trigger one domain event that fans out to many recipients and channels with durable event, notification, delivery, and attempt records.
- [ ] Chimeway enforces idempotency across event creation and delivery planning to prevent duplicate sends.
- [ ] Operators can inspect an end-to-end trace and answer "why wasn't this sent?" from first-class data.
- [ ] v0.1 ships one vertical slice with durable spine plus at least one outbound adapter seam (initially log/test or Swoosh wrapper).
- [ ] Dispatch supports a sync-first path and a documented upgrade seam to optional Oban-backed background jobs.
- [ ] Chimeway remains composable and provider-agnostic through adapter behaviours.

### Out of Scope

- Hosted, multi-tenant notification SaaS or open-core billing model — Chimeway is embedded OSS infrastructure.
- Reimplementing channel/provider foundations such as Swoosh or Oban — Chimeway integrates with them.
- Marketing automation, campaigns, or customer-engagement journey tooling — Chimeway is transactional/product notification focused.
- Hard-coding one SMS/push vendor — adapter seams remain replaceable.
- Forcing final package topology in v0.1 while core API is still stabilizing — structure can evolve before 1.0.

## Context

This project is being initialized from a detailed idea brief and prior-art synthesis focused on an ecosystem gap in Elixir/Phoenix notifications. Existing channel primitives are strong, but teams repeatedly rebuild routing, fanout, preferences, idempotency, read/seen state, retries, digests, and operator diagnostics. Chimeway targets that gap with an idiomatic, explicit, inspectable model that avoids opaque framework magic.

Prior context includes:
- Product and brand positioning emphasizing local-first ownership and explainable delivery.
- Domain research mapping lessons from Noticed (Rails), Laravel Notifications, Symfony Notifier, and Elixir channel libraries.
- Engineering DNA from sibling OSS libraries: strict CI, verification entrypoints, contract tests, and release hygiene.
- Operator IA intent centered on timeline tracing, redaction, and support-friendly debugging.
- Host-app integration seam guidance for auth, tenancy, URL generation, and correlation IDs.

## Constraints

- **Tech Stack**: Elixir/Phoenix/Ecto-first with Oban and Swoosh integration seams — align with existing ecosystem strengths.
- **Architecture**: Stable notification keys (e.g., `comment.created`) must be persisted as durable identity — avoid module-name coupling in data.
- **Data Ownership**: Host app database is source of truth for events, inbox state, deliveries, and attempts — no hosted control plane.
- **Composability**: Channel/provider integrations must use replaceable adapter behaviours — avoid hard vendor lock-in.
- **Operability**: Redacted, queryable traces must exist for support and debugging — explainability is core value, not optional polish.
- **Quality Bar**: Named `mix verify.*` and `mix ci.*` workflows, compile warnings as errors, and documented release checks are mandatory.
- **Scope**: v0.1 should prove the durable spine and one vertical channel slice before broad channel matrix expansion.
- **Compatibility**: Version baseline should track active Phoenix/Elixir LTS norms in sibling repositories.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Persist stable notification keys as data identity | Survives module renames and preserves historical traceability | Implemented in Phase 01 notifier contract + persistence flow |
| Local-first embedded architecture | Host apps need ownership, auditability, and composability without SaaS dependency | — Pending |
| Keep core explicit and inspectable | Elixir users expect clear behaviours and low magic | Implemented in Phase 01 trigger and inbox APIs |
| Treat explainability as product surface | "Why wasn't this sent?" is the primary operator differentiator | — Pending |
| Integrate channel/job primitives instead of replacing them | Swoosh/Oban already solve core delivery substrates well | — Pending |
| Start with durable spine + one channel slice | Fastest path to validate end-to-end architecture and DX | Durable spine completed in Phase 01 |
| Enforce OSS release hygiene as executable contracts | Maintainers need deterministic, repeatable release confidence | Implemented in Phase 05 docs/test/release hardening |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check - still the right priority?
3. Audit Out of Scope - reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-24 after Phase 05 completion*

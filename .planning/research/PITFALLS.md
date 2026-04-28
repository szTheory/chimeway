# Project Research: Pitfalls

**Project:** Chimeway  
**Milestone:** v1.2 Delivery Orchestration  
**Researched:** 2026-04-28  
**Confidence:** HIGH

## Focus

What are the main risks when adding scheduling, digests, templating, and recovery to an existing durable notification library?

## Main Pitfalls

### 1. Letting queue state become the product truth

If scheduled time exists only in Oban jobs and not in Chimeway data, operators cannot explain why a delivery was delayed or when it should resume.

### 2. Implementing digests as best-effort jobs without durable grouping facts

If source notifications are not explicitly linked to digest batches, duplicate emission and poor explainability will follow.

### 3. Coupling content history to notifier modules

If rendered content identity depends on module names or current code shape, historical explanation and replay become fragile.

### 4. Adding preview APIs that bypass real rendering contracts

Preview helpers should exercise the same rendering path that production delivery uses; otherwise developers gain false confidence.

### 5. Recovering by recreating events instead of re-driving them

Rebuilding history to fix partial failures breaks idempotency and confuses operator traces.

### 6. Expanding provider breadth too early

More providers add matrix complexity. Until orchestration behavior is solid, that complexity will slow down the more important product leap.

## Prevention Strategy

- Persist orchestration facts before scheduling work
- Keep digest membership explicit and queryable
- Introduce durable template/version identity
- Reuse production rendering paths for previews and tests
- Reconcile from persisted lifecycle state, never by replaying opaque side effects

## Sources

- Laravel transaction and queued-notification caveat: https://laravel.com/docs/12.x/notifications
- Oban scheduling and uniqueness docs: https://hexdocs.pm/oban/Oban.Job.html
- Symfony channel-specific transport customization: https://symfony.com/doc/current/notifier.html

---
*Research completed: 2026-04-28*

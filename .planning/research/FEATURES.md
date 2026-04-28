# Project Research: Features

**Project:** Chimeway  
**Milestone:** v1.2 Delivery Orchestration  
**Researched:** 2026-04-28  
**Confidence:** HIGH

## Focus

How do mature notification systems handle orchestration behaviors that Chimeway should add next?

## Table Stakes

### Scheduled and queued delivery

- Mature systems treat delayed and queued notification delivery as first-class behavior, not an afterthought.
- Delivery timing must stay durable across transaction boundaries and worker retries.

### Channel-specific formatting

- Mature systems let one logical notification shape different output per channel.
- Email-like channels typically require richer rendering and preview support.

### Durable database-backed notification history

- Notifications that appear in product UI still need durable storage and read-state semantics.
- Aggregate reporting depends on explicit lifecycle records rather than transient transport logs.

## Differentiators Chimeway Should Lean Into

### Explainable deferral and batching

- Chimeway can differentiate by making "why this was delayed", "why this was digested", and "why this bypassed a digest" explicit product behavior.

### Local-first operator analytics

- Aggregate outcome queries over host-owned lifecycle data are more aligned with Chimeway's position than hosted dashboards.

### Recovery as a first-class feature

- Production trust improves materially if persisted-but-unfinished notification flows can be detected and re-driven safely.

## Anti-Features For This Milestone

- Broad provider expansion before orchestration semantics are complete
- Marketing-campaign tooling and journey builders
- UI-heavy hosted management surfaces

## Sources

- Laravel Notifications queueing, database notifications, markdown mail, and preview behavior: https://laravel.com/docs/12.x/notifications
- Symfony Notifier channel model and transport-specific message shaping: https://symfony.com/doc/current/notifier.html
- Noticed bulk delivery prior art: https://www.rubydoc.info/gems/noticed/2.0.4/Noticed/BulkDeliveryMethod

---
*Research completed: 2026-04-28*

# Project Research Summary

**Project:** Chimeway  
**Milestone:** v1.2 Delivery Orchestration  
**Researched:** 2026-04-28  
**Confidence:** HIGH

## Executive Summary

Chimeway's next major leap should be orchestration behavior, not more plumbing and not broad provider expansion. Current prior art converges on a few expectations for mature notification systems: durable queued and scheduled delivery, channel-specific rendering, previewable content, and lifecycle-safe recovery. Chimeway already has the durable and explainable core needed to support those behaviors.

The recommended direction is to extend the existing planner and lifecycle spine so immediate send, deferred send, and digest participation become persisted, explainable outcomes. Oban should remain the async scheduling backbone, Phoenix.Swoosh should inform email-like rendering seams, and new digest or recovery flows should preserve Chimeway's local-first and host-owned data model.

## Key Findings

### Stack additions

- Oban already provides the scheduled and retry lifecycle needed for deferred sends and digest emission.
- Phoenix.Swoosh provides a strong rendering seam for HTML and text email bodies without forcing Chimeway to invent a new mail DSL.

### Table-stakes product behaviors

- Delivery windows and queued resume paths
- Digest accumulation and emission
- Channel-aware rendering with preview or verification support
- Aggregate operator reporting over lifecycle outcomes
- Recovery for persisted-but-unfinished dispatch flows

### Watch outs

- Do not let queue state replace Chimeway's persisted product truth.
- Do not implement digests without explicit batch membership facts.
- Do not tie content history to notifier module names.
- Do not widen provider breadth before orchestration semantics and recovery are trustworthy.

## Milestone Implications

The milestone should prioritize:
1. Delivery-window planning and durable deferral state
2. Scheduled resume execution with explainable traces
3. Digest accumulation and digest dispatch
4. Template versioning and channel-aware rendering contracts
5. Recovery and outcome analytics

This ordering compounds the durable core already built in v1.0 and the production-trust baseline shipped in v1.1.

## Sources

- Oban Job docs: https://hexdocs.pm/oban/Oban.Job.html
- Phoenix.Swoosh docs: https://hexdocs.pm/phoenix_swoosh/Phoenix.Swoosh.html
- Laravel Notifications docs: https://laravel.com/docs/12.x/notifications
- Symfony Notifier docs: https://symfony.com/doc/current/notifier.html
- Noticed bulk delivery docs: https://www.rubydoc.info/gems/noticed/2.0.4/Noticed/BulkDeliveryMethod

---
*Research completed: 2026-04-28*

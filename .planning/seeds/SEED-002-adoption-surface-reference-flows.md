---
id: SEED-002
status: dormant
planted: 2026-04-29T15:34:12Z
planted_during: Milestone v1.3 initialization
trigger_when: Core workflow and channel semantics are stable enough that production adoption is blocked more by ergonomics, docs, and operator experience than by missing core features.
scope: medium
---

# SEED-002: Adoption Surface & Reference Flows

## Why This Matters

Even with strong core features, OSS adoption stalls if teams cannot quickly understand, integrate, and operate the library. After journeys and channel feedback loops exist, Chimeway should make the production path obvious with better docs, demos, and operator surfaces.

## When to Surface

**Trigger:** Core workflow and channel semantics are stable enough that adoption friction becomes the bottleneck.

This seed should be presented during `$gsd-new-milestone` when the milestone
scope matches any of these conditions:
- New milestone discussion emphasizes production adoption, onboarding, or integration polish
- The core library feels strong enough that a demo/reference app would materially increase trust
- Operator UX, docs, and reference flows are more urgent than new core orchestration semantics

## Scope Estimate

**medium** — likely spans docs, example apps, operator surfaces, and integration DX rather than foundational engine work.

## Breadcrumbs

Related code and decisions found in the current codebase:

- `.planning/PROJECT.md`
- `.planning/milestones/v1.1-ROADMAP.md`
- `.planning/milestones/v1.2-ROADMAP.md`
- `lib/chimeway.ex`
- `lib/chimeway/inbox.ex`

## Notes

This is the likely follow-on after workflows and channel feedback loops are proven. It should emphasize real SaaS usage patterns, onboarding speed, and production trust rather than adding yet another orchestration primitive.

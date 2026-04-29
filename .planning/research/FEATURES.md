# Feature Research

**Domain:** Embedded notification workflow orchestration for SaaS applications
**Researched:** 2026-04-29
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Multi-step notification sequences | SaaS teams routinely need `in_app -> email -> fallback` style flows | HIGH | This is the core missing capability after Chimeway's single-delivery orchestration milestone. |
| Time-based waits and delayed progression | Notification programs need reminder timing, not only immediate sends | MEDIUM | Reuses Chimeway's existing deferred scheduling posture. |
| Outcome-based escalation | Teams expect follow-up when prior delivery fails, exhausts, or stays pending too long | HIGH | Should start with delivery outcome/time gates before read-state branching. |
| Stop/cancel semantics | Workflows must halt when a success or terminal condition is met | MEDIUM | Critical to avoid duplicate or contradictory follow-up sends. |
| End-to-end journey explainability | Operators need to know why a recipient is on step N or why a journey stopped | HIGH | This is where Chimeway can differentiate strongly. |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Canonical workflow state tied to delivery history | Keeps each journey inspectable from event through final escalation | HIGH | Strong fit with Chimeway's local-first explainability DNA. |
| Durable transition reasons | Answers not just what happened, but why each step advanced, waited, escalated, or stopped | MEDIUM | A stronger operator surface than most notification libraries expose. |
| Notification-specific workflow API instead of generic automation builder | Keeps the public contract focused and explicit | MEDIUM | Avoids slipping into marketing automation or BPMN sprawl. |
| Channel expansion deferred until workflows are solid | Improves leverage of later SMS/push work | LOW | Prioritization choice, but strategically important. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Visual journey builder in-core | Feels product-complete and demo-friendly | Pulls the project toward hosted-product complexity before the underlying workflow model is proven | Keep the milestone API-first and let UI/reference tooling come later |
| Broad vendor/channel expansion in the same milestone | Makes the roadmap feel bigger | Dilutes the workflow milestone and blocks on adapter breadth instead of orchestration quality | Finish durable journey semantics first, then add channels as follow-on seeds |
| Read/unread as the primary first-step driver | Feels close to “real” product behavior | Couples the core model to host inbox semantics before time/outcome progression is proven | Defer read/unread-driven branching to a later milestone |

## Feature Dependencies

```text
Workflow definitions
    └──requires──> Durable workflow identity and state
                           └──requires──> Canonical transition persistence

Outcome/time progression
    └──requires──> Scheduled progression + concurrency-safe idempotency

Escalations
    └──requires──> Outcome/time progression
                           └──enhances──> Journey explainability

Channel expansion ──enhances──> Escalations
Read/unread branching ──enhances──> Escalations
Visual builder ──conflicts──> API-first milestone focus
```

### Dependency Notes

- **Workflow definitions require durable workflow identity and state:** without persisted keys/versions and current-step state, journeys cannot be replayed or explained.
- **Outcome/time progression requires scheduled progression plus idempotency:** the same wait gate may be evaluated more than once under retries or races.
- **Escalations require progression first:** channel fallbacks only make sense once the engine can decide when to move to the next step.
- **Visual builder conflicts with API-first scope:** it consumes product/design bandwidth before the core contract stabilizes.

## MVP Definition

### Launch With (v1.3)

- [ ] Workflow definitions with stable identity and ordered steps — essential to model real SaaS notification journeys
- [ ] Time-based waits and outcome-based branching — essential to progress beyond single-delivery orchestration
- [ ] Escalation and stop semantics — essential to avoid over-notifying or stalling
- [ ] Journey traces and operator explanations — essential to preserve Chimeway's core value

### Add After Validation (v1.4/v1.5)

- [ ] First-class SMS/push/chat channels — add after the workflow engine can use them well
- [ ] Delivery receipts and callback ingestion — add when workflows need provider feedback loops
- [ ] Reference operator UI / demo app — add when the journey model is stable enough to showcase

### Future Consideration (v2+)

- [ ] Read/unread-driven workflow branching — defer until host-signal semantics are clearer
- [ ] Visual journey authoring — defer until the textual/API model stabilizes
- [ ] Marketing-style campaign automation — outside the transactional product scope

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Durable workflow definitions | HIGH | HIGH | P1 |
| Time/outcome progression engine | HIGH | HIGH | P1 |
| Escalation + stop semantics | HIGH | HIGH | P1 |
| Journey traces | HIGH | MEDIUM | P1 |
| Host signal API | MEDIUM | MEDIUM | P2 |
| Read/unread branching | MEDIUM | HIGH | P3 |
| Channel expansion | MEDIUM | HIGH | P3 |

**Priority key:**
- P1: Must have for this milestone
- P2: Should have if it directly supports the P1 journey model
- P3: Nice to have later, but defer for milestone focus

## Competitor Feature Analysis

| Feature | Noticed | Laravel Notifications | Our Approach |
|---------|---------|-----------------------|--------------|
| Delays / waits | Delivery-method delays and conditions | Queue delays and per-channel timing | Persist wait gates and reasons durably on Chimeway-owned workflow state |
| Multi-channel follow-up | Comparable patterns exist, but workflow state is light | Channel fanout is strong, workflow semantics are app-owned | Make follow-up progression a first-class library concern |
| Explainability | Limited compared with Chimeway's operator focus | Mostly app-defined / transport-focused | Treat journey reasoning as product behavior, not custom app glue |

## Sources

- https://github.com/excid3/noticed
- https://laravel.com/docs/12.x/notifications
- https://symfony.com/doc/current/notifier.html
- Local deferred requirements: `.planning/milestones/v1.2-REQUIREMENTS.md`

---
*Feature research for: embedded notification workflow orchestration*
*Researched: 2026-04-29*

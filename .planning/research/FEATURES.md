# Feature Research

**Domain:** Embedded notification framework for Elixir/Phoenix  
**Researched:** 2026-04-23  
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Stable notification definitions (`notification_key`) | Teams need rename-safe, long-lived data identity | MEDIUM | Foundation for migrations, traceability, and docs. |
| Event -> recipient fanout | One trigger commonly targets many recipients | MEDIUM | Must support deterministic recipient resolution and dedupe. |
| Durable in-app notification rows | Embedded systems need app-owned inbox state | LOW | Include explicit `seen/read/archive` semantics. |
| Per-channel delivery records + attempts | Operators need audit/debug across channels | MEDIUM | Required to answer "why wasn't this sent?" |
| Idempotency for trigger and delivery | Retries and double-submit happen in production | HIGH | Requires key strategy and unique constraints. |
| Preference and suppression checks | Users expect notification controls | MEDIUM | Include pre-enqueue and pre-perform checks for late suppression. |
| Retry/backoff and failure classification | Provider/network failures are normal | MEDIUM | Works best with Oban path but should have clear sync semantics. |
| Adapter seams for channels/providers | Ecosystem toolchains vary by app | MEDIUM | Keep Swoosh/Oban integration optional, not replaced. |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Explainable trace UI ("Why wasn't this sent?") | Operator-grade support debugging is a major gap in ecosystem | HIGH | Signature product surface; should be planned early even if UI is phased. |
| Delayed fallback (e.g., email if unread) | Reduces noise while preserving important delivery | MEDIUM | Requires read-state checks at delivery time. |
| Built-in simulator / dry-run | Faster incident triage and safer policy tuning | MEDIUM | Can ship after core persistence and policy engine are stable. |
| Redacted timeline exports for support | Safer collaboration with customer-facing teams | MEDIUM | Depends on structured payload redaction model. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Marketing campaign/journey builder | "Omnichannel" pressure from SaaS expectations | Blows scope and shifts away from transactional notification reliability | Keep explicit non-goal; focus on product/transactional paths. |
| Provider-specific logic in core | Faster initial coding for one team | Locks architecture and makes OSS adoption harder | Enforce behaviour-based adapters and contract tests. |
| Implicit magic DSL that hides state | Rails-like ergonomics appeal | Hard to debug and conflicts with Elixir explicitness | Keep macros thin; expose plain structs and behaviours. |
| Full admin suite in first cut | Attractive demo factor | Delays durable spine and increases dependency surface | Build data/trace model first, then mount optional admin package/scope. |

## Feature Dependencies

```text
Explainable trace UI
    └──requires──> Durable delivery + attempt records
                       └──requires──> Event + notification persistence
                                          └──requires──> Stable key identity

Delayed fallback (email if unread)
    └──requires──> Read/seen state model
    └──requires──> Policy checks at perform time

Push/SMS/Slack adapters
    └──requires──> Generic adapter behaviour + contract tests
```

### Dependency Notes

- **Trace UI requires durable attempt records:** UI cannot explain decisions if storage model only captures final status.
- **Fallback requires read-state semantics:** suppress-on-read logic depends on explicit inbox state transitions.
- **Additional channels require adapter contracts first:** avoids channel-specific drift and inconsistent retries/errors.

## MVP Definition

### Launch With (v1)

Minimum viable product - what is needed to validate the concept.

- [ ] Stable notification key/version model with trigger API.
- [ ] Durable event + in-app notification persistence.
- [ ] Channel delivery planning + attempt tracking for one vertical outbound seam.
- [ ] Idempotency keys and dedupe protections.
- [ ] Policy checks and suppression reasons stored in trace data.
- [ ] CI/verify discipline and baseline docs for adoption.

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] Oban-first async dispatch and richer retry controls - when production users need scheduled fanout.
- [ ] Optional mountable admin/trace UI - when trace data model is proven in real incidents.
- [ ] Additional adapters (Slack/webhook/push/SMS) - after contract tests and baseline channel semantics stabilize.

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] Digest batching and advanced frequency caps - defer until preference/policy usage is validated.
- [ ] Rich end-user preference UI - defer until host-app integration patterns settle.
- [ ] Cross-project operator analytics dashboards - defer until sufficient telemetry adoption.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Durable event/notification/delivery spine | HIGH | HIGH | P1 |
| Idempotency and dedupe | HIGH | HIGH | P1 |
| In-app inbox semantics (`seen/read`) | HIGH | MEDIUM | P1 |
| One outbound adapter seam | HIGH | MEDIUM | P1 |
| Oban async path | HIGH | MEDIUM | P2 |
| Explainable admin timeline UI | HIGH | HIGH | P2 |
| Expanded channel matrix (push/SMS/chat) | MEDIUM | HIGH | P3 |
| Digests and escalation policies | MEDIUM | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | Competitor A | Competitor B | Our Approach |
|---------|--------------|--------------|--------------|
| Notifier abstraction | Rails Noticed: event/notifier DSL | Laravel: notification classes with `via` | Elixir behaviour + optional thin DSL with stable persisted keys. |
| Multi-channel fanout | Noticed/Laravel provide per-channel queueing | Novu provides hosted orchestration | Embedded local-first fanout with durable rows and replaceable adapters. |
| Explainability | Varies; usually partial logs | Novu has execution logs in hosted model | First-class "why wasn't this sent?" trace in host app data model. |

## Sources

- `prompts/CHIMEWAY-GSD-IDEA.md`
- `prompts/elixir_notifykit_research_brief.md`
- `prompts/chimeway-admin-ui-and-operator-ia.md`
- `prompts/chimeway-engineering-dna-from-prior-libs.md`

---
*Feature research for: Chimeway*
*Researched: 2026-04-23*

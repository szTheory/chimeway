# Feature Landscape

**Domain:** Embedded notification workflow orchestration (Channel & Feedback Expansion)
**Researched:** 2026-04-30

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Broad Channel Interfaces | Email alone isn't enough; SaaS needs SMS, Push, Chat | Low | Define the data shapes (e.g., phone number, device token) and adapter behaviors. |
| Webhook Ingestion Seam | Providers send async state (bounces, deliveries); must update the canonical row | Medium | Needs a secure, mountable Plug or generic module for the host router. |
| Feedback-to-Signal Mapping | A "bounced" receipt should be able to trigger a workflow escalation | High | Reuses the v1.3 signal API, but requires automatic bridging from the delivery row to the workflow run. |

## Differentiators

Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Normalized Provider Outcomes | Abstracting Twilio's "undelivered" and SendGrid's "bounce" into a unified `:failed` state | Medium | Reduces cognitive load for operators writing workflow rules. |
| Traced Provider Payload | Securely capturing the provider's raw error reason in the trace explanation | Medium | Essential for operator debuggability ("Why did this SMS fail?"). |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Native Vendor SDKs inside Chimeway | Violates composability and increases dependency weight. | Provide pure Elixir behaviours (e.g., `Chimeway.Adapter.SMS`) and let host apps install `twilio_elixir` or `pigeon`. |
| Unified Inbox / Chat UI | This is product-specific and host-owned. | Keep focus on orchestration and state machine progression. |

## Feature Dependencies

\`\`\`text
Channel Interfaces -> Webhook Ingestion -> Feedback-to-Signal Mapping -> Workflow Progression
\`\`\`

## MVP Recommendation

Prioritize:
1. SMS and Push adapter interfaces.
2. Normalized webhook ingestion for basic terminal states (delivered, bounced).
3. Bridging normalized states to the workflow signal spine to trigger escalations.

Defer: Read/unread sync tracking (adds too much latency and state complexity for an orchestration milestone).

## Sources
- Competitor analysis (Laravel Notifications, Noticed)
- Chimeway SEED-001 (HIGH confidence)

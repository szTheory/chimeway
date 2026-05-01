# Research Summary: Chimeway Milestone v1.4 - Channel Feedback Loops

**Domain:** Embedded notification workflow orchestration (Channel & Feedback Expansion)
**Researched:** 2026-04-30
**Overall confidence:** HIGH

## Executive Summary

Chimeway established a durable workflow engine in v1.3. The next major leverage point is enabling those multi-step journeys to interact with a broader set of channels (SMS, Push, Chat) and to react to asynchronous provider feedback (receipts, bounces, callbacks). Until now, Chimeway operated primarily in a "fire-and-forget" model post-dispatch (except for synchronous failure or Oban retry convergence). Provider callbacks represent true terminal state.

Research shows the Elixir ecosystem has fragmented but capable libraries for these channels (e.g., `pigeon` for push, `twilio_elixir` for SMS, `slack_elixir` for chat). Rather than hardcoding these libraries, Chimeway must maintain its adapter-seam philosophy, allowing host apps to plug in their preferred clients while Chimeway standardizes the inbound webhook normalization and state convergence. 

By ingesting webhooks as signals into the v1.3 Workflow Engine, Chimeway can drive outcome-based progression (e.g., escalate to SMS if the Email bounces, or mark the journey completed if a Push is opened/delivered).

## Key Findings

**Stack:** Continue using Elixir/Ecto/Oban with replaceable Adapter Behaviors; add an inbound normalized webhook parsing layer.
**Architecture:** Expose an ingest/webhook seam that normalizes vendor payloads into canonical Chimeway outcomes, then emits these as workflow signals.
**Critical pitfall:** Hard-coupling the library to specific vendor SDKs (like Twilio or Slack) instead of standardizing the adapter contract. 

## Implications for Roadmap

Based on research, suggested phase structure:

1. **[Phase] Outbound Channel Contracts** - Define adapter behaviors and channel-specific render contracts for SMS, Push, and Chat.
   - Addresses: Need for non-email messaging without vendor lock-in.
   - Avoids: Hard-coupling to `twilio_elixir` or `pigeon`.

2. **[Phase] Inbound Feedback Normalization** - Implement a canonical webhook ingestion layer that translates vendor payloads to Chimeway delivery outcomes.
   - Addresses: Closing the loop on asynchronous delivery state (receipts, bounces, clicks).
   - Avoids: Exposing raw vendor payloads in the core workflow spine.

3. **[Phase] Feedback-Driven Progression** - Connect the normalized inbound feedback into the workflow signal spine to trigger next steps or escalations.
   - Addresses: Outcome-based escalation based on true delivery state rather than just dispatch success.
   - Avoids: Split-brain state where the delivery row says "delivered" but the workflow engine is unaware.

4. **[Phase] Operator Traces & Audit** - Expand timeline traces to show provider callbacks and the resulting workflow transitions.
   - Addresses: Explainability for asynchronous provider feedback.

**Phase ordering rationale:**
- Outbound channel contracts must exist first so that deliveries have a channel context.
- Inbound feedback normalization builds the bridge from the outside world back to the delivery row.
- Feedback-driven progression links the updated delivery row back to the workflow engine.
- Operator traces seal the explainability loop.

**Research flags for phases:**
- Feedback Normalization: Needs deeper research during planning on how to securely ingest webhooks across different host app router setups (Plug vs Phoenix).
- Feedback-Driven Progression: Carefully map delivery status convergence with the v1.3 Signal router.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Relying on host apps for SDKs aligns perfectly with existing Swoosh architecture. |
| Features | HIGH | Outcomes mapped perfectly to SEED-001 requirements. |
| Architecture | HIGH | Reuses v1.3 Signal architecture heavily. |
| Pitfalls | HIGH | Known pain points from webhook ingestion are standard web dev concerns. |

## Gaps to Address

- Whether Read/unread-driven branching is entirely out of scope for v1.4, or if basic read-receipt webhooks should trigger a state change. Current recommendation is to stick to delivery terminal states (bounced, delivered, failed) first.

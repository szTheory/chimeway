---
id: SEED-003
status: implemented
planted: 2026-04-29T15:34:12Z
planted_during: Milestone v1.3 initialization
trigger_when: Ecosystem composition becomes the next adoption wedge after core journeys, channel feedback, and adoption surfaces are stable.
scope: large
shipped_by: v1.8-v1.10
implemented:
  - v1.8 Mailglass adapter, inbound feedback bridge, blueprint, demo proof, docs, and verify gate
  - v1.9 Accrue dunning blueprint, demo proof, docs, and verify gate
  - v1.10 Threadline telemetry bridge, Sigra auth flows, demo proofs, docs, and verify gates
---

# Ecosystem Integrations (High-Value Wins)

**Domain:** Interoperability with sztheory ecosystem libraries
**Status:** Implemented by v1.10

Chimeway's architecture is deeply decoupled, making it a perfect orchestration engine that can compose with other specialized libraries in the ecosystem. Rather than building everything in-house, Chimeway should provide first-class adapters, blueprints, and telemetry bridges for the following high-value integrations:

## Outcome

This seed is implemented across v1.8-v1.10:

- v1.8 shipped the Mailglass adapter, inbound feedback bridge, blueprint, demo proof, integration guide, doc-contracts, and `mix verify.mailglass`.
- v1.9 shipped the Accrue dunning workflow blueprint, demo proof, integration guide, doc-contracts, and `mix verify.accrue`.
- v1.10 shipped the Threadline telemetry bridge and Sigra auth notification flows with blueprints, demo proofs, integration guides, doc-contracts, and `mix verify.threadline` / `mix verify.sigra`.

Remaining ecosystem ideas should be captured as new focused seeds rather than reopening this broad matrix seed.

## 1. Mailglass (Transactional Email)
*What it is:* A transactional email framework for Phoenix composable on Swoosh, complete with a LiveView dev/admin preview.
*The Win:* Chimeway orchestrates the "when" and "why" (workflows, escalations, deduplication, digests), while Mailglass handles the "what" and "how" (templating, MJML rendering, Swoosh delivery). 
*Integration point:* A first-class `Chimeway.Adapter.Mailglass` that leverages Mailglass's rendering and cleanly maps Mailglass inbound webhook normalization (via `mailglass_inbound`) into Chimeway's Signal engine for feedback loops.

## 2. Accrue (Billing State)
*What it is:* Billing state and subscription management modeled clearly for Elixir.
*The Win:* Dunning (failed payment recovery) is one of the highest-ROI workflows for any SaaS. Chimeway's v1.3 Workflow Journeys and v1.4 Channel Feedback are perfectly suited for this. 
*Integration point:* A "Chimeway + Accrue Dunning Blueprint". Accrue emits `invoice.payment_failed` -> Chimeway workflow starts -> Sends Email 1 -> Waits 48h -> Sends Email 2 (escalation) -> Accrue emits `invoice.paid` -> Workflow terminates via Outcome Signal. (Bidirectional win: Accrue's admin UI/portal can display the active Chimeway Dunning workflow state for a customer).

## 3. Threadline (Audit Platform)
*What it is:* Audit platform for Elixir teams using Phoenix, Ecto, and PostgreSQL.
*The Win:* Unified observability. Operators shouldn't have to check a notification log separately from their main system audit log. 
*Integration point:* Chimeway currently emits detailed traces for every notification decision (suppressed, deferred, dispatched). We can provide a `Chimeway.Telemetry.ThreadlineReporter` (or similar bridge) that automatically sinks Chimeway's deterministic outcomes into Threadline's immutable audit ledger.

## 4. Sigra (Authentication)
*What it is:* Auth for Phoenix (sessions, TOTP, passkeys, etc).
*The Win:* Out-of-the-box secure notification flows. Auth notifications are highly sensitive and require strict reliability.
*Integration point:* Reference blueprints/flows for Sigra events (e.g., "Magic Link Dispatcher", "MFA Token SMS"). Demonstrates Chimeway's security by proving it can safely deliver sensitive tokens without logging them in the trace database.

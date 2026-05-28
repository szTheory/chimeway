# Chimeway

## What This Is

Chimeway is an open-source, embedded notification layer for Elixir and Phoenix applications. It provides durable notification records, delivery orchestration, and explainable traces from trigger through policy, scheduling, batching, and provider attempts. It is local-first by design: host applications keep their own data, policies, and operational controls.

## Core Value

Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.

## Current State

Chimeway shipped **v1.4 Channel Feedback Loops** on 2026-05-08 (re-audited and formally closed 2026-05-28). **v1.5 Phase 35 (Installer Task) complete 2026-05-28** — `mix chimeway.gen.migrations` ships 31 canonical migration templates with slug idempotency, golden-diff and idempotency CI contracts (`mix ci.install_golden`). The library supports generic outbound channel contracts (SMS, Push, Chat), durable webhook ingress with atomic `Multi+Oban` handoff, feedback-driven workflow progression via canonical `chimeway.delivery.*` signals, and operator traces that link inbound webhooks to journey steps. End-to-end proof lives in `examples/chimeway_demo_host` with 562 tests passing.

## Product Arc

- `v1.3 Workflow Journeys` — durable, explainable multi-step workflows and escalations (shipped 2026-04-30).
- `v1.4 Channel Feedback Loops` — outbound channels plus inbound receipts/webhooks feeding workflow progression (shipped 2026-05-08).
- `v1.5 Adoption Surface` — reference flows, integration polish, and operator UX (planned).

## Current Milestone: v1.5 Adoption Surface

**Goal:** Make Chimeway adoptable off the lot — installer truth, golden-path docs, reference recipes, and optional operator trace UI — without expanding core engine scope.

**Target features:**
- `mix chimeway.gen.migrations` (or install task) with idempotent golden-diff verification
- Golden-path integration doc: fresh host → trigger → trace query → optional webhook feedback
- Two or more reference recipes (password-reset support trace; feedback escalation workflow)
- Demo host trace-inspection path documented beyond webhook-only E2E
- Optional `chimeway_admin` MVP: redacted trace lookup by user/correlation with host auth behaviour
- Doc-contract gates and `mix verify.example` in release checklist
- Persona/JTBD-driven DX alignment (SEED-004: Feature Developer, Support Operator, Product Manager)

**Included seeds:** SEED-002 (Adoption Surface & Reference Flows), SEED-004 (Personas & DX Roadmap)

**Explicitly deferred:** read/unread auto-branching, full SEED-003 ecosystem matrix, vendor adapters in core, bell inbox UI, marketing campaign tooling

## Out of Scope

- Hosted, multi-tenant notification SaaS or open-core billing model — Chimeway is embedded OSS infrastructure.
- Reimplementing channel/provider foundations such as Swoosh or Oban — Chimeway integrates with them.
- Marketing automation, campaigns, or customer-engagement journey tooling — Chimeway is transactional/product notification focused.
- Hard-coding one SMS/push vendor — adapter seams remain replaceable.
- Broad channel-matrix expansion before orchestration behavior is mature — timing, batching, and recovery are the higher-leverage gaps for current adopters.

## Context

This project is being initialized from a detailed idea brief and prior-art synthesis focused on an ecosystem gap in Elixir/Phoenix notifications. Existing channel primitives are strong, but teams repeatedly rebuild routing, fanout, preferences, idempotency, read/seen state, retries, digests, and operator diagnostics. Chimeway targets that gap with an idiomatic, explicit, inspectable model that avoids opaque framework magic.

Prior context includes:
- Product and brand positioning emphasizing local-first ownership and explainable delivery.
- Domain research mapping lessons from Noticed (Rails), Laravel Notifications, Symfony Notifier, and Elixir channel libraries.
- Engineering DNA from sibling OSS libraries: strict CI, verification entrypoints, contract tests, and release hygiene.
- Operator IA intent centered on timeline tracing, redaction, and support-friendly debugging.
- Host-app integration seam guidance for auth, tenancy, URL generation, and correlation IDs.
- The shipped v1.0 milestone established the durable spine, policy checkpoints, telemetry correlation, safe adapter resolution, and transactional Oban dispatch as the baseline to build from.
- The shipped v1.1 milestone established production-trust behavior across preferences, reliability, observability, and integration documentation.
- v1.4 shipped multi-channel outbound contracts and inbound feedback loops with E2E proof on a reference Phoenix host.
- Next value jump is adoption surface: reference flows, integration docs, and operator UX — not more channel matrix expansion.
- Adopter assessment (2026-05-28): ~82% done for embedded-notification scope — engine strong; installer doc references non-existent Mix task; no shipped operator LiveView; demo host proves webhooks only.

## Constraints

- **Tech Stack**: Elixir/Phoenix/Ecto-first with Oban and Swoosh integration seams — align with existing ecosystem strengths.
- **Architecture**: Stable notification keys (for example, `comment.created`) must be persisted as durable identity — avoid module-name coupling in data.
- **Data Ownership**: Host app database is source of truth for events, inbox state, deliveries, attempts, deferrals, and digest batches — no hosted control plane.
- **Composability**: Channel/provider integrations must use replaceable adapter behaviours — avoid hard vendor lock-in.
- **Operability**: Redacted, queryable traces must exist for support and debugging — explainability is core value, not optional polish.
- **Quality Bar**: Named `mix verify.*` and `mix ci.*` workflows, compile warnings as errors, and documented release checks are mandatory.
- **Scope**: v1.3 should prioritize workflow journeys and escalation semantics over broad channel expansion.
- **Scope**: The next milestone should stay centered on time/outcome progression before read/unread-driven branching or UI productization.
- **Compatibility**: Version baseline should track active Phoenix/Elixir LTS norms in sibling repositories.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Persist stable notification keys as data identity | Survives module renames and preserves historical traceability | Implemented in Phase 01 notifier contract + persistence flow |
| Local-first embedded architecture | Host apps need ownership, auditability, and composability without SaaS dependency | Implemented (Phases 01-03) |
| Keep core explicit and inspectable | Elixir users expect clear behaviours and low magic | Implemented in Phase 01 trigger and inbox APIs |
| Treat explainability as product surface | "Why wasn't this sent?" is the primary operator differentiator | Implemented via durable traces and Phase 08 outcome surfacing |
| Integrate channel/job primitives instead of replacing them | Swoosh/Oban already solve core delivery substrates well | Implemented in Phase 02 (Swoosh/Adapter) and Phase 03/12 (Oban) |
| Start with durable spine + one channel slice | Fastest path to validate end-to-end architecture and DX | Durable spine completed in Phase 01 |
| Enforce OSS release hygiene as executable contracts | Maintainers need deterministic, repeatable release confidence | Implemented in Phase 05 docs/test/release hardening |
| Transactional Oban Dispatch | Prevent orphaned pending deliveries on transaction failure | Implemented in Phase 12 |
| String-safe adapter lookup | Prevent atom table exhaustion from runtime channel strings | Implemented in Phase 11 |
| Persisted policy controls | Keep suppression explicit, explainable, and durable across planning and perform gates | Implemented in Phase 13 |
| Durable attempt history and convergence | Make retries and final outcomes inspectable under concurrency and failure | Implemented in Phase 14 |
| Tenancy-aware trace queries | Preserve host ownership boundaries in observability surfaces | Implemented in Phase 15 |
| Integration docs as product surface | Lower host-app adoption risk with explicit setup and adapter guidance | Implemented in Phase 16 |
| Prioritize orchestration before channel breadth in v1.2 | Scheduling, batching, rendering, and recovery create larger product value than adding more providers now | Shipped in v1.2 |
| Keep canonical lifecycle identity through orchestration features | Deferred, digested, recovered, and emitted flows should stay explainable on durable rows | Implemented across phases 17-23 |
| Persist orchestration and rendering declarations as durable data | Replay, recovery, and preview should not depend on notifier module re-entry | Implemented across phases 21-23 |
| Prioritize workflow journeys before channel breadth in v1.3 | Multi-step SaaS notification behavior is the next major adoption gap after single-notification orchestration | Shipped in v1.3 |
| Atomic webhook ingress via Multi+Oban | Prevent orphaned async feedback processing on partial failure | Shipped in v1.4 (Phase 33) |
| Canonical `chimeway.delivery.*` vocabulary | Align normalization, signals, and trace projection for auditability | Shipped in v1.4 (Phase 34) |
| Generic outbound channel behaviour | SMS/Push/Chat without vendor lock-in; per-channel render contracts | Shipped in v1.4 (Phase 29) |
| v1.5 before channel matrix or ecosystem plugins | Engine credible at v1.4 close; adoption friction (installer, golden path, operator UI) is the bottleneck | Assessment 2026-05-28 (thread `2026-05-28-v1.5-milestone-assessment`) |
| Defer read/unread-driven workflow branching to post-v1.5 | `pending_signals` not populated on `wait_until`; journey guide ahead of engine; READ milestone is narrower glue | Assessment 2026-05-28 |

## Archived Milestone Context

<details>
<summary>v1.4 Channel Feedback Loops planning context</summary>

### Milestone Scope

Extend Chimeway from email-only outbound delivery to multi-channel contracts with inbound provider feedback that drives workflow progression and operator auditability.

### Delivered Features

- `Chimeway.Rendering.Channel` behaviour and SMS/Push/Chat channel modules with registry resolution.
- Webhook ingestion (`Chimeway.Webhooks.process/4`), ingress durability, and `ProcessFeedbackWorker`.
- Feedback-driven progression via `Chimeway.Signal.track/4` and sync workflow progression.
- Operator traces with `:webhook_received` and workflow transition projection.
- `examples/chimeway_demo_host` E2E proof on real Oban queues.

### Validated Requirements Snapshot

- CHAN-01/02: Generic outbound adapters and per-channel render contracts.
- FEED-01/02: Webhook ingestion and canonical delivery outcomes.
- FLOW-01/02: Signals and outcome-based workflow progression from feedback.
- TRAC-01/02: Operator traces link webhooks to journey steps.

</details>

<details>
<summary>v1.2 Delivery Orchestration planning context</summary>

### Milestone Scope

Turn Chimeway from a durable notification engine into a product-grade notification layer that can decide not just whether to send, but when, how, and in what grouped form.

### Delivered Features

- Delivery windows and recipient-timezone-aware quiet-hours deferral.
- Scheduled resume and digest accumulation/emission over canonical delivery rows.
- Durable render identity, validated render contracts, and local preview tooling.
- Recovery/reconciliation flows plus grouped outcome analytics.

### Validated Requirements Snapshot

- Delivery planning can persist immediate, deferred, and digest-held behavior with explainable reasons.
- Deferred rows resume safely without duplicating canonical lifecycle history.
- Digest generation and explainability are verified end to end for Oban-backed scheduling.
- Rendering identity, preview, recovery, and outcome analytics all operate from durable persisted state.

</details>

<details>
<summary>v1.1 Production Trust planning context</summary>

### Milestone Scope

Make Chimeway trustworthy enough for real production use by tightening policy behavior, delivery reliability, observability, and integration seams.

### Delivered Features

- Explicit policy and preference controls that suppress before enqueue and before perform.
- Durable reliability and final-state tracking across retries, duplicates, and failures.
- End-to-end observability and support surfaces with safe redaction.
- Documented, contract-tested integration seams for host apps and adapters.

### Validated Requirements Snapshot

- Durable event, notification, delivery, and attempt records exist across trigger fanout flows.
- Idempotency is enforced across event creation and delivery planning.
- Operators can inspect lifecycle traces and answer "why wasn't this sent?" safely.
- Sync-first dispatch and Oban upgrade seams are both supported.
- Policy, preference, reliability, observability, and integration goals were validated in phases 13-16.

</details>

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
*Last updated: 2026-05-28 — Phase 35 (Installer Task) complete; v1.5 in progress*

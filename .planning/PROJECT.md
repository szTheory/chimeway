# Chimeway

## What This Is

Chimeway is an open-source, embedded notification layer for Elixir and Phoenix applications. It provides durable notification records, delivery orchestration, and explainable traces from trigger through policy, scheduling, batching, and provider attempts. It is local-first by design: host applications keep their own data, policies, and operational controls.

## Core Value

Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.

## Current Milestone: v1.9 Adopter Complete

**Goal:** Close the last adopter-facing gaps — Accrue dunning blueprint (SEED-003 slice) and end-user inbox UI (SEED-004 INBX) — so Chimeway is adoptable off the lot for all three personas.

**Target features:**
- Accrue `invoice.payment_failed` → Chimeway dunning workflow → `invoice.paid` termination via Signal engine (ECOS-06)
- Accrue dunning reference recipe with demo host proof and operator traces (ECOS-07, DEMO-07)
- Headless inbox API polish: unread count, pagination, stable DTO maps (INBX-01)
- Optional `chimeway_inbox` package: mountable router, recipient auth behaviour, unstyled bell-dropdown LiveView (INBX-02)
- Golden-path guides, doc-contract tests, and `mix verify.accrue` / `mix verify.inbox` release gates

**Included seeds:** SEED-003 (Accrue slice only), SEED-004 (INBX slice only)

## Current State

**v1.8 Ecosystem Integration Blueprints shipped (2026-05-30):** Phases 54–57, 57.1 — `Chimeway.Adapters.Mailglass` outbound adapter with contract tests (ECOS-01/02), inbound webhook feedback bridge with `provider_message_id` correlation (ECOS-03/04), ECOS-05 reference blueprint with DEMO-06 demo host proof, golden-path integration guide (DOCS-06), doc-contract truth lock (DOCS-07), and `mix verify.mailglass` release gate (GATE-04). **159 doc-contract + journey/mailglass gates** green at audit.

Prior: **v1.7 READ + Adoption Polish** shipped 2026-05-29 (Phases 48–53). Read/unread workflow glue, journey CI (`mix verify.journeys`), adoption docs, and demo host proof remain the adoption foundation.

## Product Arc

- `v1.3 Workflow Journeys` — durable, explainable multi-step workflows and escalations (shipped 2026-04-30).
- `v1.4 Channel Feedback Loops` — outbound channels plus inbound receipts/webhooks feeding workflow progression (shipped 2026-05-08).
- `v1.5 Adoption Surface` — installer, golden-path docs, reference recipes, demo trace path, operator admin MVP, release gates (shipped 2026-05-29).
- `v1.6 Consumer Journey Proof` — TeamPulse demo, deterministic seeds, journey CI, one-command spin-up (shipped 2026-05-29).
- `v1.7 READ + Adoption Polish` — read/unread workflow glue, natural escalation demo, adoption-evidence tail (shipped 2026-05-29).
- `v1.8 Ecosystem Integration Blueprints` — Mailglass-first adapter, inbound feedback bridge, reference recipe, demo proof, integration docs, and verify gate (shipped 2026-05-30).

## Next Milestone Goals

**v1.10 (planned):** SEED-003 remainder — Threadline telemetry bridge, Sigra auth notification flows. Optional polish: INT-02/03, ADPT-01 greenfield CI, real-time PubSub bell.

**Explicitly deferred from v1.9:** Threadline bridge, Sigra auth blueprints, real-time PubSub bell updates, INT-02/03 polish, ADPT-01, broad channel matrix, Playwright admin smoke (INV-004), full TeamPulse SaaS shell.

### Shipped v1.8 Features (Validated)

- `Chimeway.Adapters.Mailglass` optional dep with runtime config, outbound `deliver/2`, tenancy stamp, error classification, redacted success meta (ECOS-01)
- Shared `Chimeway.Adapter.ContractTest` coverage for Mailglass including simulate_error and executor email routing (ECOS-02)
- `provider_message_id` on attempt rows + adapter-native webhook parse seam (ECOS-03 spine)
- Mailglass webhook verify/resolve/normalize/dedup callbacks mapping Anymail events to `:delivered/:bounced/:failed` (ECOS-03/04)
- ECOS-05 reference blueprint with doc-contract truth lock — Chimeway orchestrates when/why, Mailglass handles templating
- DEMO-06: TeamPulse invite email through Mailglass with `/admin/chimeway` operator trace proof
- DOCS-06 golden-path integration guide (dependency → config → trigger → delivery → inbound feedback)
- DOCS-07 doc-contract locks guide truth including webhook call-shape guards (Phase 57.1)
- GATE-04: `mix verify.mailglass` CI job + MAINTAINING pre-ship sextet

### Shipped v1.7 Features (Validated)

- `cancel_signals` DSL on `wait_until` progress rules with declaration-time validation (READ-01)
- `enter_waiting/6` auto-populates `pending_signals` from progress rules — no host glue
- Inbox `mark_read`/`mark_seen` emit durable `chimeway.notification.read`/`.seen` signals via `Signal.track/4` (READ-02)
- Signal-routed early resume from `:waiting` with explainable `signal_received` transition (READ-03)
- TeamPulse payment escalation demo uses READ-driven progression — no `PendingWebhookAdapter` choreography (DEMO-03)
- Mention-escalation reference recipe documents read-cancel plus time-based `wait_until` fallback (DEMO-04)
- JOUR-06 read-cancel proof on Sync and Oban due-worker paths plus time-fallback
- JOUR-07/08 admin persona traces for Sam suppression and Morgan escalation
- Demo host README and `mix demo.up` moduledoc aligned to shipped READ behavior (DOCS-04/05)
- GATE-03: `mix verify.journeys` covers JOUR-01..08 (10 tests); MAINTAINING.md pre-ship quintet updated

### Shipped v1.6 Features (Validated)

- TeamPulse demo domain with three persona JTBD notifiers (`teampulse.invite_sent`, `teampulse.password_reset`, `teampulse.payment_reminder`)
- Deterministic, idempotent `DemoHost.Seeds` + `mix demo.seed` (adopter-copyable public API)
- `mix demo.up` (root) and `mix demo.admin` (demo host) one-command spin-up with admin URL banner
- Journey E2E suite: invite delivery, suppression explainability, webhook workflow progression
- Host-mount `chimeway_admin` integration test through demo host router
- GATE-02: `mix verify.journeys` CI job + pre-ship quintet in MAINTAINING.md (v1.6 foundation, JOUR-01..05)
- GATE-03: expanded journey suite JOUR-06..08 — READ read-cancel + admin persona traces (v1.7, 10 tests)

### Shipped v1.5 Features (Validated)
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
- Adopter assessment (2026-05-28): ~82% done for embedded-notification scope — **resolved by v1.5** (installer task, golden path, operator UI, demo trace path, release gates).
- Adopter assessment (2026-05-29): ~88–92% done post-v1.6 — adoption evidence (TeamPulse demo, seeds, `mix demo.up`, `mix verify.journeys`, host-mount admin E2E) resolved the pre-adopter confidence gap.
- v1.8 Ecosystem Integration Blueprints shipped 2026-05-30 — Mailglass adapter, inbound feedback bridge, blueprint recipe, demo proof, integration docs, verify gate.
- Adopter assessment post-v1.8: ~94–96% for embedded-notification scope — ecosystem Mailglass composition proven; next value jump is SEED-003 remainder + INBX (v1.9).

## Constraints

- **Tech Stack**: Elixir/Phoenix/Ecto-first with Oban and Swoosh integration seams — align with existing ecosystem strengths.
- **Architecture**: Stable notification keys (for example, `comment.created`) must be persisted as durable identity — avoid module-name coupling in data.
- **Data Ownership**: Host app database is source of truth for events, inbox state, deliveries, attempts, deferrals, and digest batches — no hosted control plane.
- **Composability**: Channel/provider integrations must use replaceable adapter behaviours — avoid hard vendor lock-in.
- **Operability**: Redacted, queryable traces must exist for support and debugging — explainability is core value, not optional polish.
- **Quality Bar**: Named `mix verify.*` and `mix ci.*` workflows, compile warnings as errors, and documented release checks are mandatory.
- **Scope**: Orchestration and explainability remain higher leverage than broad channel expansion.
- **Scope**: v1.9 closes Accrue dunning + INBX inbox UI; Threadline/Sigra and optional polish remain v1.10+.
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
| v1.5 before channel matrix or ecosystem plugins | Engine credible at v1.4 close; adoption friction is the bottleneck | Shipped 2026-05-29 (Phases 35-41) |
| Defer read/unread-driven workflow branching to v1.7 READ | `pending_signals` not populated on `wait_until`; inbox read does not emit signals | Shipped v1.7 (Phases 48–49) |
| `cancel_signals` validated at declaration time | Runtime validation would hide notifier authoring errors | Shipped v1.7 Phase 48 (D-06) |
| `pending_signals` column is sole durable source | Avoid mirroring into status_context for replay consistency | Shipped v1.7 Phase 48 |
| Inbox signals on first transition only | Idempotent read/seen should not duplicate signal rows | Shipped v1.7 Phase 49 |
| Lifecycle :ok independent of Signal.track | Separate transactions per D-07 — inbox state must not fail on signal errors | Shipped v1.7 Phase 49 |
| signal_received context is event_name only | No payload/notification_id in operator trace projection (READ-03) | Shipped v1.7 Phase 49 |
| READ-driven demo replaces staged webhook seeds | Staged choreography masked engine gap | Shipped v1.7 Phase 50 |
| JOUR-06 covers Sync + Oban due-worker paths | Single-path proof insufficient for async escalation | Shipped v1.7 Phase 51 |
| GATE-01 scoped doc-contract gates separate from default ci | Fast core feedback + explicit pre-ship quartet | Shipped Phase 41 |
| verify.example additive subprocess chain | Demo host E2E first, chimeway_admin second | Shipped Phase 41 |
| v1.6 journey CI separate from default ci | Fast core feedback; journey proof is explicit pre-ship gate | Shipped v1.6 |
| DemoHost.Seeds as adopter-copyable API | Seeds use Chimeway.trigger/3, not test fixture inserts | Shipped v1.6 |
| Defer Playwright for admin smoke | Host-mount ConnTest + LiveViewTest sufficient for JOUR-04 | Shipped v1.6 |
| Mailglass-only v1.8 scope | Accrue/Threadline/Sigra deferred — prove one ecosystem composition deeply first | Shipped v1.8 |
| Runtime config only in Mailglass adapter | No compile-time secrets; config read at call time via Application.get_env/3 | Shipped v1.8 Phase 54 |
| Dual lifecycle Chimeway attempts + Mailglass ledger | Intentional — Chimeway owns orchestration explainability | Shipped v1.8 Phase 54 |
| Mailglass test config unconditional in config/test.exs | Config loads before dep compile | Shipped v1.8 Phase 54 |
| Journey suite keeps Logger adapter; Mailglass isolated | `@moduletag :mailglass` selective CI — no journey regression | Shipped v1.8 Phase 56 |
| Guide vs blueprint doc separation | Introduction guide owns end-to-end path; blueprint is focused recipe | Shipped v1.8 Phase 57 |
| Webhook doc-contract explicit string list for multi-token patterns | ~w sigil splits multi-word forbidden patterns incorrectly | Shipped v1.8 Phase 57.1 |

## Archived Milestone Context

<details>
<summary>v1.8 Ecosystem Integration Blueprints planning context</summary>

### Milestone Scope

Prove Chimeway composes with szTheory ecosystem via first-class Mailglass adapter, inbound feedback bridge, reference blueprint, demo proof, and release gates.

### Delivered Features

- `Chimeway.Adapters.Mailglass` outbound delivery with contract tests (ECOS-01/02).
- Inbound webhook pipeline with `provider_message_id` correlation and Signal-driven progression (ECOS-03/04).
- ECOS-05 blueprint recipe + DEMO-06 demo host Mailglass proof.
- DOCS-06/07 integration guide with doc-contract truth lock; Phase 57.1 closed webhook example gap.
- GATE-04: `mix verify.mailglass` + MAINTAINING pre-ship sextet.

### Validated Requirements Snapshot

- ECOS-01..05, DEMO-06, DOCS-06/07, GATE-04 — all satisfied (9 requirements).

</details>

<details>
<summary>v1.7 READ + Adoption Polish planning context</summary>

### Milestone Scope

Connect inbox read/unread state to workflow progression and close adoption-evidence gaps in demo, docs, and journeys.

### Delivered Features

- `wait_until` auto-populates `pending_signals` from `cancel_signals` progress rules (READ-01).
- Inbox `mark_read`/`mark_seen` emit durable signals routing workflow progression (READ-02/03).
- TeamPulse payment escalation uses READ-driven progression; mention-escalation recipe published (DEMO-03/04).
- Journey CI: JOUR-06 read-cancel (Sync + Oban), JOUR-07/08 admin persona traces.
- Doc truth + GATE-03 expanded journey suite (10 tests).

### Validated Requirements Snapshot

- READ-01..03, DEMO-03/04, JOUR-06..08, DOCS-04/05, GATE-03 — all satisfied (11 requirements).

</details>

<details>
<summary>v1.6 Consumer Journey Proof planning context</summary>

### Milestone Scope

Realistic TeamPulse demo domain with deterministic seeds, one-command admin spin-up, and shift-left journey proof in CI.

### Delivered Features

- TeamPulse notifiers (invite, password reset, payment escalation) with stable notification keys.
- `DemoHost.Seeds` idempotent API + `mix demo.seed` / `mix demo.up` / `mix demo.admin`.
- Journey E2E suite (JOUR-01..05) + host-mount admin integration test.
- `mix verify.journeys` CI job + MAINTAINING.md pre-ship quintet.

### Validated Requirements Snapshot

- DEMO-02, SEED-01, CMD-01, JOUR-01..05, GATE-02 — all satisfied.

</details>

<details>
<summary>v1.5 Adoption Surface planning context</summary>

### Milestone Scope

Make Chimeway adoptable off the lot: installer truth, golden-path docs, reference recipes, demo trace path, optional operator trace MVP, and release doc-contract gates.

### Delivered Features

- `mix chimeway.gen.migrations` with golden-diff and idempotency CI contracts.
- Golden-path guide: dependency → migrations → trigger → trace → optional webhook feedback.
- Journey guide doc-truth rewrite with doc-contract tests.
- Password-reset support trace and feedback escalation reference recipes.
- Demo host IEx trace path without provider webhooks.
- `chimeway_admin` MVP: redacted trace lookup with host auth behaviour.
- GATE-01: `mix ci.verify_gates`, `verify.example` CI job, MAINTAINING.md pre-ship quartet.

### Validated Requirements Snapshot

- INST-01/02, DOCS-01/02/03, RECP-01/02, DEMO-01, OPER-01/02, GATE-01 — all satisfied.

</details>

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
*Last updated: 2026-05-30 — milestone v1.9 Adopter Complete started*

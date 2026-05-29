# Phase 55: Inbound Feedback Bridge - Context

**Gathered:** 2026-05-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Mailglass inbound webhook events feed Chimeway's existing feedback pipeline and resume or terminate workflows with explainable traces. This phase implements the four optional `Chimeway.Adapter` webhook callbacks on `Chimeway.Adapters.Mailglass`, persists outbound `provider_message_id` on attempt rows for correlation, and proves ECOS-03/04 via Chimeway-level contract and integration tests.

**Requirements:** ECOS-03, ECOS-04

**Success criteria (from ROADMAP):**
1. A signed Mailglass inbound webhook payload verifies, resolves delivery identity, and records a canonical delivery outcome (delivered, bounced, or failed)
2. Normalized feedback from Mailglass triggers workflow progression via the existing Signal engine without host glue
3. Operator traces show webhook-received and outcome-linked transitions for Mailglass feedback events

**Out of scope (Phases 56–57):** Demo host Mailglass webhook route wiring, reference recipe, golden-path integration guide, doc-contract tests, and `mix verify.mailglass` CI gate.
</domain>

<decisions>
## Implementation Decisions

### Integration seam (Chimeway webhook pipeline, not Mailglass Plug)
- **D-01:** Implement `verify_webhook/3`, `resolve_delivery/1`, `normalize_feedback/1`, and `resolve_provider_event_id/1` on `Chimeway.Adapters.Mailglass` inside the existing `Code.ensure_loaded?(Mailglass)` compile guard.
- **D-02:** Host applications call `Chimeway.Webhooks.process/4` with raw provider bytes and headers — same host-mount contract as `DemoHostWeb.WebhooksController`. Do NOT use `Mailglass.Webhook.Plug` as the Chimeway feedback ingress path; Mailglass Plug owns a separate durable ledger (`mailglass_webhook_events`) that does not feed Chimeway's ingress spine.
- **D-03:** `verify_webhook/3` delegates signature verification to the configured `Mailglass.Webhook.Provider` implementation for a config-driven provider atom (`:postmark`, `:sendgrid`, `:mailgun`, etc.) read at call time from adapter config or `Application.get_env/3`.
- **D-04:** Use Mailglass core `Mailglass.Webhook.*` APIs only — do NOT add `mailglass_inbound` as a dependency. That sibling package is for receiving inbound email, not delivery-status provider webhooks.

### Delivery correlation (provider_message_id spine)
- **D-05:** Lift `provider_message_id` from Mailglass adapter success meta into `chimeway_delivery_attempts.provider_message_id` in `Dispatch.Executor.run_delivery/1` when present in adapter `{:ok, meta}`. This closes Phase 54 D-19 deferral and enables `Deliveries.get_delivery_by_provider_message_id/1` lookup in `ProcessFeedbackWorker`.
- **D-06:** Webhook `resolve_delivery/1` resolves identity via `provider_message_id` extracted from Mailglass-normalized event metadata (e.g., `message_id`, `sg_message_id`, provider-specific keys in `%Mailglass.Events.Event{}.metadata`). Prefer `provider_message_id` correlation over direct `delivery_id` — matches existing EchoAdapter demo pattern and avoids FK fragility on ingress rows.
- **D-07:** Implement `resolve_provider_event_id/1` using Mailglass event metadata's stable provider event id for dedup via the existing partial unique index on `(adapter_module, provider_event_id)`.

### Outcome normalization (Mailglass Event → Chimeway canonical)
- **D-08:** Map Mailglass `%Mailglass.Events.Event{}` delivery lifecycle types to Chimeway's three canonical webhook outcomes:
  - `:delivered`, `:sent` (when representing successful delivery confirmation) → `:delivered`
  - `:bounced`, suppression-related reject reasons → `:bounced`
  - `:failed`, `:rejected` → `:failed`
- **D-09:** Engagement and non-delivery events (`:opened`, `:clicked`, `:complained`, `:autoresponded`, etc.) MUST NOT create ingress rows — `normalize_feedback/1` returns `:error` for these so `Chimeway.Webhooks.process/4` responds non-2xx and the provider retries or the event is dropped at the boundary.
- **D-10:** `ProcessFeedbackWorker.canonicalize_status/1` continues mapping `"delivered"` → attempt outcome `:succeeded` and signal `chimeway.delivery.succeeded` — no changes to worker vocabulary in this phase.

### Pipeline threading (raw body access + batch payloads)
- **D-11:** Extend `Chimeway.Webhooks.process/4` to inject `:raw_body` and `:headers` into the config keyword threaded through the adapter callback chain, so Mailglass adapter can call `Provider.normalize/2` without re-implementing provider parsers. Backward compatible — existing adapters ignore extra config keys.
- **D-12:** For SendGrid-style batched webhook payloads, process the **first delivery-relevant event** from `Provider.normalize/2` result per HTTP POST in v1.8. Full multi-event fan-out (one ingress row per normalized event) is deferred — document as known limitation.

### Workflow progression (reuse existing spine)
- **D-13:** No new Signal engine or workflow progression modules — ECOS-04 is satisfied by the existing path: `ProcessFeedbackWorker` → `Deliveries.record_attempt/2` → `Signal.track/4` (`chimeway.delivery.{outcome}`) → signal router → workflow progression with `progressed_on_delivery_outcome` trace entries. Prove with Chimeway-level integration test mirroring `feedback_pipeline_e2e_test.exs` patterns using Mailglass adapter fixtures.
- **D-14:** Operator traces (`Traces` timeline) already project `:webhook_received` from feedback attempts — ECOS-03 trace visibility requires Mailglass adapter webhook tests to assert timeline entries include `provider_message_id` and `adapter_module`.

### Testing and quality gates
- **D-15:** Add webhook callback contract tests alongside existing `Chimeway.Adapter.ContractTest` deliver tests — cover verify success/failure, resolve via `provider_message_id`, normalize delivered/bounced/failed, and provider event id dedup.
- **D-16:** Integration tests use Mailglass test stack (`Mailglass.Adapters.Fake`, `Mailglass.TestRepo`, provider fixture payloads) — mirror Phase 54 outbound test harness patterns.
- **D-17:** Phase 55 does NOT wire demo host routes or TeamPulse notifiers — that is Phase 56 (DEMO-06).

### Claude's Discretion
- Exact config key for webhook provider selection (`:webhook_provider`, nested under `:channel_adapter_configs["email"]`, etc.)
- Specific Mailglass Event type → Chimeway outcome mapping table refinements per provider
- Whether `:sent` maps to `:delivered` or is ignored (depends on provider semantics in Mailglass normalize output)
- Error tuple mapping from `%Mailglass.SignatureError{}` to `{:error, :unauthorized}` in verify_webhook
- Implementation of first-event selection logic for batched payloads (filter vs take-first)
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` — Phase 55 goal, success criteria, dependency on Phase 54
- `.planning/REQUIREMENTS.md` — ECOS-03, ECOS-04 acceptance criteria
- `.planning/seeds/SEED-003-ecosystem-integrations.md` — Chimeway orchestration vs Mailglass templating split; feedback loop vision
- `.planning/phases/54-mailglass-adapter-core/54-CONTEXT.md` — Outbound adapter decisions (D-01..D-19), deferred webhook scope

### Chimeway adapter and webhook pipeline
- `lib/chimeway/adapter.ex` — Optional webhook callbacks (`verify_webhook`, `resolve_delivery`, `normalize_feedback`, `resolve_provider_event_id`)
- `lib/chimeway/webhooks.ex` — Synchronous ingest boundary (`process/4`)
- `lib/chimeway/webhooks/ingress.ex` — Durable ingress schema and normalized status vocabulary
- `lib/chimeway/webhooks/process_feedback_worker.ex` — Async feedback → attempt + signal + workflow progression
- `lib/chimeway/dispatch/executor.ex` — Outbound attempt recording (extend for `provider_message_id`)
- `lib/chimeway/deliveries.ex` — `get_delivery_by_provider_message_id/1` lookup
- `lib/chimeway/traces.ex` — `:webhook_received` timeline projection (TRAC-01/02)
- `test/chimeway/webhooks_test.exs` — Ingress + dedup contract tests
- `test/chimeway/webhooks/process_feedback_worker_test.exs` — Worker safe-noop and correlation tests

### Mailglass adapter (Phase 54 outbound baseline)
- `lib/chimeway/adapters/mailglass.ex` — Outbound `deliver/2`; webhook callbacks added here
- `test/chimeway/adapters/mailglass_adapter_test.exs` — Existing contract test harness
- `test/support/chimeway/mailglass_fixtures.ex` — Mailglass test fixtures (extend for webhook payloads)

### Reference host patterns (read for wiring contract, do not modify in Phase 55)
- `examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex` — Host-mount contract
- `examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex` — Reference webhook callback implementations
- `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` — E2E feedback → workflow → trace proof pattern

### External (Mailglass — deps/mailglass)
- `Mailglass.Webhook.Provider` — verify!/3 + normalize/2 behaviour
- `Mailglass.Webhook.Plug` — **NOT** the Chimeway ingress path (read to understand what to avoid duplicating)
- `Mailglass.Events.Event` — Anymail event type taxonomy for outcome mapping
- `deps/mailglass/guides/webhooks.md` — Provider setup and signature verification notes
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Complete Phase 33–34 webhook durable spine: `Chimeway.Webhooks.process/4` → `Ingress` → `ProcessFeedbackWorker` → `Signal.track/4`
- `Chimeway.Adapter` optional webhook callbacks with test patterns in `EchoAdapter` and `webhooks_test.exs`
- `Deliveries.get_delivery_by_provider_message_id/1` indexed lookup on `chimeway_delivery_attempts.provider_message_id`
- `Traces` timeline already projects `:webhook_received` and `:workflow_progressed` for feedback-driven journeys
- Phase 54 Mailglass outbound adapter with success meta including `provider_message_id` and `mailglass_delivery_id`
- Phase 54 Mailglass test harness (`Mailglass.Adapters.Fake`, migration shims in `test/support/mailglass/`)

### Established Patterns
- Adapters under `Chimeway.Adapters.*` with `Code.ensure_loaded?(Mailglass)` compile guard
- Runtime config via `Application.get_env/3` and `ChannelAdapterConfig.resolve/2` — no compile-time secrets
- Webhook verify-before-parse: raw body passed to `verify_webhook/3` before `Jason.decode/1`
- Canonical feedback outcomes: `:delivered | :bounced | :failed` on ingress; worker maps `"delivered"` → `:succeeded` attempt outcome
- Idempotent provider retry dedup via partial unique index on `(adapter_module, provider_event_id)`
- Safe-noop worker semantics for stale correlation keys (`:delivery_not_found`, `:provider_message_id_not_found`)

### Integration Points
| Seam | Role in Phase 55 |
|------|------------------|
| `Chimeway.Adapters.Mailglass` webhook callbacks | Bridge Mailglass provider crypto + normalization to Chimeway ingress |
| `Dispatch.Executor.run_delivery/1` | Persist `provider_message_id` from outbound success meta |
| `Chimeway.Webhooks.process/4` | Host entry point; extend config threading for raw body |
| `ProcessFeedbackWorker` | Existing async path to attempts, signals, workflow progression |
| `Mailglass.Webhook.Provider` | Delegate verify + normalize; do not reimplement HMAC/ECDSA |
| `%Mailglass.Events.Event{}` | Source taxonomy for outcome mapping |
</code_context>

<specifics>
## Specific Ideas

- SEED-003 vision: Chimeway orchestrates when/why; Mailglass handles templating and provider webhook dialects. Phase 55 closes the feedback loop without host glue code.
- Phase 54 intentionally deferred webhook callbacks (D-18) and `provider_message_id` persistence (D-19) — both are core Phase 55 deliverables.
- v1.8 Mailglass-only wedge — no Accrue/Threadline/Sigra inbound bridges in this phase.
- `mailglass_inbound` (sibling Hex package) is for receiving inbound **email**, not delivery-status webhooks — out of scope and not a dependency.

</specifics>

<deferred>
## Deferred Ideas

- Multi-event webhook fan-out (one ingress row per event in SendGrid batches) — future enhancement beyond v1.8 wedge
- Demo host Mailglass webhook route and TeamPulse notifier end-to-end proof — Phase 56 (DEMO-06)
- Reference recipe documenting orchestration vs templating split — Phase 56 (ECOS-05)
- Golden-path integration guide and doc-contract tests — Phase 57 (DOCS-06/07)
- `mix verify.mailglass` CI gate — Phase 57 (GATE-04)
- Mounting `Mailglass.Webhook.Plug` as alternative Chimeway feedback path — rejected; duplicates durable tracking without feeding Chimeway spine
- Engagement event handling (`:opened`, `:clicked`) as Chimeway signals — new capability, not in ECOS-03/04

### Reviewed Todos (not folded)
None — no pending todos matched Phase 55.

</deferred>

---

*Phase: 55-inbound-feedback-bridge*
*Context gathered: 2026-05-29 (assumptions mode)*

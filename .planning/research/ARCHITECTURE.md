# Architecture Patterns

**Domain:** Embedded notification workflow orchestration (Channel & Feedback Expansion)
**Researched:** 2026-04-30

## Recommended Architecture

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `Chimeway.Adapter.*` | Defines the contract for new channels (SMS, Push, Chat) | Host App implementations |
| `Chimeway.Webhooks.Ingest` | Normalizes incoming HTTP payloads into standard canonical facts | Host App Web Router, `Chimeway.Delivery` |
| `Chimeway.Webhooks.Normalizer` | Behaviour for vendor-specific translation (e.g., Twilio -> canonical) | `Chimeway.Webhooks.Ingest` |
| `Chimeway.FeedbackBridge` | Listens to delivery state changes and emits workflow signals | `Chimeway.Signal`, `Chimeway.Delivery` |

### Data Flow

1. **Dispatch:** Workflow Run -> active step -> `Chimeway.Delivery` created for SMS -> Dispatcher -> `Chimeway.Adapter.SMS` -> Vendor (e.g., Twilio).
2. **Feedback:** Vendor sends Webhook -> Host App Router -> `Chimeway.Webhooks.Ingest` -> normalized to `Delivery` update.
3. **Bridge:** `Delivery` updated to `:failed` -> `Chimeway.FeedbackBridge` translates this to a workflow signal (e.g., `step_failed`).
4. **Progression:** `Chimeway.Signal` engine processes the signal -> evaluates workflow rules -> triggers escalation step.

## Patterns to Follow

### Pattern 1: Plug-based Ingestion Seam
**What:** Provide a generic handler or Plug that host apps can easily integrate into their Phoenix pipelines.
**When:** Receiving provider webhooks.
**Example:**
\`\`\`elixir
# In host app router.ex
post "/webhooks/twilio", Chimeway.Webhooks.Plug, 
  normalizer: MyApp.TwilioNormalizer,
  secret: Application.compile_env(:my_app, :twilio_secret)
\`\`\`

### Pattern 2: Normalized Outcomes
**What:** Define a strict atom-based taxonomy for outcomes (e.g., `:delivered`, `:bounced`, `:complaint`).
**Why:** So the workflow engine doesn't need to know vendor-specific string codes to evaluate escalations, making the rules engine provider-agnostic.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Direct Workflow Mutation
**What:** Updating the workflow run directly from the webhook ingest controller.
**Why bad:** Bypasses the transactional guarantees and locking of the Signal spine introduced in v1.3.
**Instead:** The webhook should strictly update the canonical `Delivery` row and emit a `Signal`, letting the worker evaluate progression safely.

## Sources
- Chimeway Architecture (Phases 24-27 Signal API) (HIGH confidence)

# Phase 33: webhook-ingress-durability - Context

**Gathered:** 2026-05-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the webhook-ingress durability gap in the existing feedback pipeline so a provider
callback is only acknowledged after Chimeway has durably captured the inbound fact and
durably handed it off to async processing. Keep the current core seam
`Chimeway.Webhooks.process/4`, make stale or unknown callback correlation safe and
explainable, and prove a real host-mounted HTTP ingress path without coupling Chimeway
core to Phoenix or Plug runtime helpers.

Out of scope for this phase: cross-phase outcome vocabulary cleanup (`delivered` vs
`succeeded`), end-to-end workflow progression proof on the real path, and broader channel
or provider expansion. Those remain Phase 34 work.

</domain>

<decisions>
## Implementation Decisions

### Durable ingress handoff
- **D-01:** Phase 33 extends Chimeway's durable lifecycle spine with a dedicated inbound
  webhook ingress record for trusted callbacks. The durable path becomes:
  `provider callback -> verified ingress row -> queued feedback worker -> delivery attempt -> signal/workflow/traces`.
- **D-02:** `Chimeway.Webhooks.process/4` is the acknowledgment boundary. It MUST return
  success only after one `Ecto.Multi` transaction commits both:
  1. insertion of the ingress row, and
  2. insertion of the `ProcessFeedbackWorker` Oban job.
  Any queue insertion or validation failure returns an explicit error tuple.
- **D-03:** The host HTTP layer owns HTTP mapping, but the canonical contract is:
  `{:ok, ingress}` or `{:ok, job}` -> host may return `2xx`;
  `{:error, :unauthorized}` -> host returns `401`;
  all other library-level failures -> host returns a non-`2xx` status so the provider can retry.
- **D-04:** The ingress row stores only provider-safe, payload-safe, explainability-first
  fields needed for audit and replay. Do NOT persist arbitrary full raw payloads or secret
  headers by default. Persist normalized status, adapter identity, correlation keys,
  provider event/message ids when available, durable ingress outcome, and timestamps.
- **D-05:** If the adapter exposes a stable provider event identifier, the ingress row
  should persist it and use it as the primary duplicate-collapse seam together with adapter
  identity. Duplicate provider retries should converge on the same ingress fact rather than
  creating unbounded inbound noise.

### Safe stale / unknown callback handling
- **D-06:** Unknown or stale `delivery_id` and `provider_message_id` callbacks are treated
  as understood-but-ignored async events, not worker failures. `ProcessFeedbackWorker`
  must stop using raising lookup paths like `get_delivery!/1` for this boundary.
- **D-07:** Missing delivery correlation returns `:ok` from the worker to avoid Oban retry
  storms, but MUST update the ingress row with an explicit ignored reason such as
  `delivery_not_found`, `provider_message_id_not_found`, or equivalent durable status.
- **D-08:** The ignored/stale audit lives on the new ingress surface, not on
  `DeliveryAttempt`. A delivery attempt means Chimeway resolved a canonical delivery row
  and recorded an actual delivery lifecycle fact; unresolved inbound callbacks are a
  different durable concept and should not overload attempt semantics.
- **D-09:** Unauthorized signature failures and malformed/unparseable requests do NOT get a
  durable ingress row in core. They remain host-edge concerns surfaced through safe error
  tuples and optional telemetry/logging. Only requests that pass adapter verification and
  basic parsing enter Chimeway's durable inbound lifecycle.

### Host ingress proof and developer ergonomics
- **D-10:** Chimeway core stays framework-agnostic. Do NOT add a Chimeway-owned Plug,
  Phoenix controller helper, or pseudo-request-map adapter in core for Phase 33.
- **D-11:** The runtime proof requirement is satisfied with an executable example or
  fixture Phoenix host app that mounts a real route, preserves the raw request body via
  `Plug.Parsers` `:body_reader`, calls `Chimeway.Webhooks.process/4`, and proves the
  success/error mapping end to end.
- **D-12:** The example app becomes the canonical reference for docs. Guides should point
  to that fixture instead of repeating large copy-paste controller snippets in multiple
  places, to reduce drift and keep one blessed mount pattern.
- **D-13:** The example ingress path should emphasize the ecosystem footgun explicitly:
  signature verification must operate on the exact raw request body bytes before JSON
  parsing or body mutation. This is a first-class DX concern, not incidental setup.

### Scope and sequencing
- **D-14:** Phase 33 is deliberately narrow: ingress durability, safe stale handling, and
  host-mounted proof only. Outcome vocabulary unification and the real webhook ->
  workflow -> trace end-to-end contract stay reserved for Phase 34.

### the agent's Discretion
- Exact ingress schema naming (`webhook_ingress`, `feedback_ingress`, etc.) so long as it
  clearly represents trusted inbound provider callback facts rather than generic host HTTP
  traffic.
- Exact enum/string vocabulary for ingress processing states (`queued`, `processed`,
  `ignored`, `failed`) so long as the write/read path stays explicit and queryable.
- Whether `process/4` returns the ingress row, the Oban job, or a compact result struct,
  so long as success only means the transaction committed and the host can map it cleanly
  to `2xx`.

</decisions>

<specifics>
## Specific Ideas

- Treat the new ingress row as the inbound sibling of `Chimeway.Signal.track/4`:
  a durable fact plus an atomically queued worker, not an optimistic enqueue helper.
- Keep the worker thin once it has an ingress row id; all correlation, status updates, and
  explainability should converge through durable rows rather than queue archaeology.
- Use the fixture app as the user-friendly story: "copy this exact route/body-reader
  pattern" rather than making adopters reverse-engineer webhook raw-body handling.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone scope
- `.planning/ROADMAP.md` — Phase 33 goal, success criteria, and Phase 34 boundary.
- `.planning/REQUIREMENTS.md` — `FEED-01` and `FEED-02` remain the active requirements.
- `.planning/PROJECT.md` — local-first ownership, durable identity, and explainability as
  the product value.
- `.planning/STATE.md` — current milestone posture and explicit Phase 33 focus.
- `.planning/v1.4-MILESTONE-AUDIT.md` — concrete audit gaps this phase closes.

### Prior phase carry-forward
- `.planning/phases/29-outbound-channel-contracts/29-CONTEXT.md` — channel adapter seam
  and adapter identity posture.
- `.planning/phases/30-inbound-feedback-normalization/30-RESEARCH.md` — original pure
  function webhook boundary recommendation.
- `.planning/phases/31-feedback-driven-progression/31-RESEARCH.md` — signal emission seam
  and async feedback pipeline posture.
- `.planning/phases/32-operator-traces-audit/32-CONTEXT.md` — current webhook/trace
  linkage constraints and audit posture.

### Existing source files
- `lib/chimeway/webhooks.ex` — current synchronous webhook boundary.
- `lib/chimeway/webhooks/process_feedback_worker.ex` — current async handoff and stale-id
  behavior.
- `lib/chimeway/signal.ex` — established `Ecto.Multi` + Oban atomic handoff pattern.
- `lib/chimeway/dispatch/workflow_progression_worker.ex` — current noop-on-missing-row
  queue-boundary precedent.
- `test/chimeway/webhooks_test.exs` — current process/4 behavior contract.
- `test/chimeway/webhooks/process_feedback_worker_test.exs` — current stale-id and signal
  behavior tests.

### Project methodology
- `.planning/METHODOLOGY.md` — recommendation-first, least-surprise, and durable
  explainability lenses that shaped these decisions.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Signal.track/4`: already demonstrates the preferred transaction seam for
  "persist domain fact + atomically enqueue Oban job".
- `Chimeway.Dispatch.WorkflowProgressionWorker.normalize_progress_result/1`: already shows
  that a missing durable row can be a queue-boundary noop rather than a retry-worthy error.
- Existing webhook tests: provide a focused place to harden the seam without inventing a
  new subsystem from scratch.

### Established Patterns
- Chimeway prefers durable rows over hidden queue state for explainability.
- Host apps own web/framework concerns; core owns notification lifecycle and storage.
- Async work is expected to be safe, explicit, and transactionally handed off through Oban.
- Sensitive payload material should not leak into operator or telemetry surfaces.

### Integration Points
- `Chimeway.Webhooks.process/4`: becomes the ingress transaction seam.
- `ProcessFeedbackWorker`: should pivot from raw callback args to a durable ingress-driven
  processing model.
- Example/fixture Phoenix host app: becomes the executable proof of the host-mounted
  ingress path and raw-body handling.

</code_context>

<deferred>
## Deferred Ideas

- Cross-phase outcome vocabulary unification (`delivered` vs `succeeded`) — Phase 34.
- Real webhook -> workflow progression -> trace E2E proof on the production path —
  Phase 34.
- Broader framework helper surfaces (dedicated Plug, Phoenix package split, etc.) unless
  future adoption evidence shows the pure-function + fixture-app seam is insufficient.

</deferred>

---

*Phase: 33-webhook-ingress-durability*
*Context gathered: 2026-05-01*

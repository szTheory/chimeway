# Phase 21: Template Versioning & Rendering Contracts - Context

**Gathered:** 2026-04-28 (assumptions mode + focused subagent research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Make notification content versioned, channel-aware, and previewable without coupling durable
history to notifier module changes. This phase covers durable rendering identity, explicit
channel-specific rendering contracts, and local developer preview/verification surfaces. Hosted
template management, visual workflow editing, and broader operator analytics remain out of scope.

</domain>

<decisions>
## Implementation Decisions

### Durable rendering identity
- **D-01:** Chimeway should persist a stable, per-channel rendering identity on the canonical
  `chimeway_deliveries` row using `render_key` plus `render_version`, separate from
  `notification_key` plus notifier version and never derived from notifier module names.
- **D-02:** `render_key` should be string-based and channel-scoped, for example
  `comment.created.email` or `comment.created.in_app`, so channel copy/layout can evolve without
  forcing unrelated channel version bumps.
- **D-03:** Chimeway should not introduce a full template registry or hosted-style template
  publication lifecycle in Phase 21. That would overbuild the milestone and pull the library
  toward a SaaS-shaped product model too early.

### Rendering contract shape
- **D-04:** Chimeway should keep trigger-time durable input capture, but `Notifier.build/2` should
  become a compatibility seam rather than the long-term rendering contract.
- **D-05:** The durable input contract should shift to explicit structured assigns plus
  notifier-declared rendering identity, while channel-specific renderer behaviours produce validated
  output payloads before delivery.
- **D-06:** Channel renderers should stay explicit and typed by channel responsibility rather than
  collapsing all channels into one generic metadata map. At minimum, `:in_app` and `:email` should
  have distinct validated output contracts in this phase.
- **D-07:** Phoenix-oriented rendering tools such as HEEx, `Phoenix.Template`, and
  `Phoenix.Swoosh` are good host-app implementation details, especially for email, but they should
  sit behind Chimeway renderer behaviours instead of becoming the core public API of the library.
- **D-08:** Outbound adapters must remain dumb transport seams. They should continue to receive
  pre-rendered delivery content and must not call back into notifiers or renderer modules at
  delivery time.

### Persistence and lifecycle boundaries
- **D-09:** Structured render inputs should persist once on the durable notification record, while
  channel-specific rendered outputs should materialize onto the delivery row before dispatch so the
  canonical delivery remains the explainable per-channel execution artifact.
- **D-10:** `Notification.metadata` may remain as a compatibility projection for existing in-app
  behavior during migration, but Phase 21 should treat it as a derived storage shape, not the
  primary rendering contract.
- **D-11:** `Delivery.planning_context` must not become the rendering contract. It remains reserved
  for orchestration reasoning, not content identity or rendered payload storage.
- **D-12:** Rendering must not recompute from mutable host data inside adapters or queue workers.
  The render artifact used for preview, tests, and dispatch should be the same validated production
  path output.

### Preview and verification surface
- **D-13:** The canonical developer surface for TMPL-03 should be a pure library preview/render API
  that returns stable preview structs and reuses the same render pipeline that dispatch uses.
- **D-14:** A Mix task should exist only as a convenience wrapper over that library API. It should
  not define different semantics or construct a fake rendering path of its own.
- **D-15:** Phoenix LiveDashboard or browser-based preview UI should not be the primary Phase 21
  surface. If added later, it should live in an optional Phoenix integration package and call the
  same core preview API.
- **D-16:** Snapshot and file-based verification are useful secondary techniques for CI and review,
  but they should complement the canonical preview/test API rather than replace it.

### Testing and DX posture
- **D-17:** Phase 21 should add shared contract tests for renderer behaviours and notifier content
  declarations, plus integration tests that prove preview output matches the rendered delivery
  payload used for dispatch.
- **D-18:** Validation must happen on explicit runtime payload shapes, not only through
  compile-time Phoenix component attribute warnings. Chimeway should use changesets or equivalent
  explicit validators for channel render outputs.
- **D-19:** Preview and render surfaces must remain inspectable and developer-friendly without
  leaking sensitive payload fields. Render artifacts should favor stable semantic fields over
  opaque or transport-specific blobs.

### the agent's Discretion
- Exact field/module names for render identity and renderer behaviours.
- Whether structured render inputs live in new dedicated notification columns or a validated map on
  the notification row, as long as the durable contract remains explicit and testable.
- Whether email renderer output is normalized into dedicated delivery columns, a validated
  `render_data` map, or a hybrid, as long as the adapter contract stays explicit and explainable.
- Exact Mix task flags and preview output formats, provided they are thin wrappers over the same
  production render pipeline.

</decisions>

<specifics>
## Specific Ideas

- Copy Phoenix/Swoosh’s strength at explicit template rendering and local preview, but do not let
  Phoenix become a hard dependency for the core library rendering contract.
- Copy Laravel’s channel-specific notification posture and browser-preview convenience for mail, but
  avoid its tendency to make class identity and channel fallbacks blur the durable contract.
- Copy Symfony Notifier’s explicit per-channel message mindset, but keep Chimeway more durable and
  history-aware than a transport-oriented abstraction.
- Learn from Noticed’s delivery-method ergonomics, while explicitly avoiding its persisted
  class-name coupling footgun.
- Learn from Knock and Novu’s previewability and channel-specific template thinking, but do not
  import their hosted workflow/template-store shape into this local-first embedded library.
- Keep GitHub-style “why did I get this?” clarity in mind: operators and developers should be able
  to see which content version and channel render shape produced a delivery without reverse-
  engineering current code.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone and phase scope
- `.planning/ROADMAP.md` — Phase 21 goal, dependency, and success criteria.
- `.planning/REQUIREMENTS.md` — `TMPL-01`, `TMPL-02`, and `TMPL-03` requirements.
- `.planning/PROJECT.md` — local-first ownership, stable identity, explainability, and milestone DX
  posture.
- `.planning/STATE.md` — carried-forward orchestration and digest decisions leading into Phase 21.

### Prior architectural direction
- `.planning/research/ARCHITECTURE.md` — project-level recommendation to separate rendering
  identity from notifier identity.
- `.planning/research/STACK.md` — rendering should stay composable and Phoenix.Swoosh-compatible
  without inventing a bespoke provider DSL.
- `.planning/research/PITFALLS.md` — warnings against content/module coupling and preview paths
  that bypass real rendering contracts.
- `.planning/METHODOLOGY.md` — current project-level guidance to research first, converge on one
  coherent recommendation set, and escalate only high-impact decisions.

### Prior phase carry-forward decisions
- `.planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md` — preview-friendly embedded
  DX posture, explicit durable identity, and least-surprise design direction.
- `.planning/phases/20-digest-emission-explainability/20-CONTEXT.md` — explainability must remain
  durable and payload-safe; richer rendering and preview contracts were explicitly deferred here.

### Existing lifecycle and adapter seams
- `lib/chimeway/notifier.ex` — current notifier behaviour, including `build/2`, channel
  declarations, and orchestration seam.
- `lib/chimeway/trigger.ex` — trigger-time notification persistence currently writes notifier
  metadata once per recipient.
- `lib/chimeway/delivery.ex` — canonical per-channel delivery row and current metadata/planning
  fields.
- `lib/chimeway/delivery_planning.ex` — planning choke point where rendered delivery materialization
  can be integrated before dispatch.
- `lib/chimeway/adapter.ex` — adapter contract requiring pre-rendered delivery content.
- `lib/chimeway/dispatch/executor.ex` — existing transport execution path that should stay renderer-
  agnostic.
- `lib/chimeway/traces.ex` — explainability surface that Phase 21 should enrich without leaking raw
  payloads.

### Existing tests and compatibility boundaries
- `test/chimeway/notifier_contract_test.exs` — current notifier contract coverage that Phase 21
  will extend.
- `test/chimeway/inbox_integration_test.exs` — current in-app metadata behavior that migration
  needs to preserve or deliberately replace.
- `test/chimeway/integration/delivery_lifecycle_test.exs` — end-to-end delivery lifecycle behavior
  that rendered output changes must not break.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Trigger.notifications_attrs/4`: already provides the durable, once-per-notification
  persistence hook where structured render inputs can be captured.
- `Chimeway.DeliveryPlanning`: already centralizes per-channel planning and is the right place to
  materialize validated channel render outputs onto delivery rows before dispatch.
- `Chimeway.Adapter` plus dispatch modules: already enforce the “adapters consume, they do not
  render” boundary that Phase 21 should preserve.
- `Chimeway.Traces`: already provides the operator-facing explanation seam where render identity can
  later surface safely.

### Established Patterns
- Durable business truth belongs in Chimeway rows, not in queue state, not in module names, and
  not in best-effort preview-only helpers.
- The canonical execution unit is the per-channel delivery row, so channel-specific content identity
  belongs there.
- Explainability and DX prefer explicit, queryable facts over opaque metadata or hidden fallback
  behavior.
- Optional ecosystem integrations are good; hard framework coupling in the core library is not.

### Integration Points
- Phase 21 will connect notifier declarations, notification persistence, delivery planning, adapter
  execution, and preview/test surfaces into one render pipeline.
- Email-like rendering should remain compatible with Phoenix/Swoosh host-app patterns without
  forcing those dependencies into the core contract.
- Preview helpers, contract tests, and dispatched deliveries should all share one normalized render
  artifact so TMPL-02 and TMPL-03 reinforce each other.

</code_context>

<deferred>
## Deferred Ideas

- Hosted-style template registry tables, publish/promote lifecycle, and UI-managed template editing.
- A first-party LiveDashboard or browser preview UI in the core library.
- Broad cross-channel editor UX or workflow-builder surfaces similar to Knock or Novu.
- Provider breadth expansion beyond the current outbound seam; orchestration and rendering contracts
  remain the higher-leverage work.

</deferred>

---

*Phase: 21-template-versioning-rendering-contracts*
*Context gathered: 2026-04-28*

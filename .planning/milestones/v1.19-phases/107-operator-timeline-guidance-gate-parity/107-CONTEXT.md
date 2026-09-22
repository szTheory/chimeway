# Phase 107: Operator Timeline, Guidance & Gate Parity - Context

**Gathered:** 2026-09-12
**Status:** Ready for planning
**Mode:** Autonomous smart discuss — recommended defaults approved

<domain>
## Phase Boundary

Expose the already-durable notification seen/read facts in safe delivery explanations and the optional admin timeline, document the complete arrival-to-seen-to-read ownership model, and make the existing inbox verification lane and both aggregate CI gates continuously prove the full adopter journey. This phase closes INT-02, DOCS-03, and GATE-03 without adding new lifecycle storage, protocols, providers, engagement inference, package promotion, or visual redesign.

</domain>

<decisions>
## Implementation Decisions

### Safe Timeline Projection
- Add conditional `:notification_seen` and `:notification_read` entries to every `Chimeway.Traces.explain_delivery/2` timeline, deriving timestamps directly from the parent notification's persisted `seen_at` and `read_at` fields so sibling delivery explanations agree.
- Give both events closed empty detail maps and pass them through the existing `Chimeway.SafeEvidence` event/detail allowlists. Never project recipient identity, signal payload, caller metadata, tenant, notification content, or publisher data.
- Preserve genuinely chronological presentation: sort first by authoritative timestamp and use the closed event rank only as a deterministic tie-breaker. When timestamps are equal, seen sorts before read.
- Keep read and seen independent: do not synthesize seen from read, signals, PubSub hints, delivery state, protected activation, or provider feedback.

### Admin Timeline Presentation
- Reuse `ChimewayAdmin.Components.TimelineEvent`; add explicit accessible labels “Notification seen” and “Notification read” plus stable per-event structural hooks.
- Preserve the existing timestamp element, detail list, status badge, suppression-reason handling, and both core and admin redaction layers.
- Prove presentation through focused component/redaction contracts and the mounted demo-host Trace Detail path after real seen/read transitions.
- Do not redesign the inbox or broaden admin/browser coverage beyond the timeline facts required by this phase.

### Adopter Guidance and Ownership
- Update `guides/introduction/inbox-integration.md` as the single canonical host guide. Show the working `:inbox_change_publisher`, `:pubsub_server`, high-entropy `:topic_secret`, and an auth module implementing both `current_recipient/2` and `current_tenant/2`.
- State ownership explicitly: Chimeway owns durable notification state and best-effort post-commit publishing; `chimeway_inbox` owns opaque topics, closed reload messages, subscription, and authoritative reload; the host owns authentication, tenant membership, recipient mapping, PubSub supervision, secret custody, and production authorization.
- Replace stale raw-email and deferred-seen examples with stable opaque `cw_*` recipient references and current semantics: arrival is durable creation, panel reveal marks only visible rows first-seen, read is explicit, archive is independent, and reconnect/reload does not imply engagement.
- Include a concise semantics table separating durable inbox arrival/seen/read/archive from provider handoff, visible presentation, CrossWake protected activation, and engagement; none implies another unless the host records that separate fact.

### Verification and Gate Parity
- Strengthen the existing `mix verify.inbox` composition instead of adding a CI lane. It must require focused core lifecycle/timeline/privacy/Phoenix-optional evidence, the full inbox package suite, focused admin timeline evidence, the canonical guide contract, and the demo `:inbox` journey covering arrival → mounted seen → explicit read with once-only workflow progression.
- Keep `pr-gate` and `ci-gate` dependent on the single `verify_inbox` job; extend release-gate contracts to lock the alias contents and both aggregate edges.
- Keep nightly-only admin/browser work outside `ci-gate`; do not change the established fast/release topology.
- Update `MAINTAINING.md` and doc/release contracts so pre-ship instructions name all required evidence classes and assert that both aggregate gates consume the same lane.

### the agent's Discretion
- Exact helper names, focused test-file placement, CSS hook naming, and guide prose are at the agent's discretion when consistent with existing conventions and the decisions above.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/chimeway/traces.ex` already loads each delivery's notification and constructs durable timeline entries.
- `lib/chimeway/notifications/notification.ex` owns authoritative `seen_at` and `read_at` timestamps; `lib/chimeway/inbox.ex` writes them idempotently under tenant/recipient scope.
- `lib/chimeway/safe_evidence.ex` owns the closed event vocabulary and safe-detail projection.
- `chimeway_admin/lib/chimeway_admin/components/timeline_event.ex` and `trace_detail_live.ex` already render explanation timelines.
- Existing core, inbox-package, demo-host, documentation, and release-gate tests cover each integration seam needed for composition.

### Established Patterns
- Explanations are rebuilt from durable rows and expose closed, allowlisted evidence only.
- PubSub messages are routing-only reload hints; a fresh durable query remains authoritative.
- Optional packages preserve host ownership of authentication, tenancy, PubSub supervision, URL/configuration, and secret custody.
- Named local `verify.*` aliases and CI jobs are locked together through executable release/doc contracts.

### Integration Points
- Timeline projection: `Chimeway.Traces.explain_delivery/2`, timeline builders, ordering helpers, and `Chimeway.SafeEvidence`.
- Admin rendering: `ChimewayAdmin.Components.TimelineEvent`, Trace Detail LiveView, and admin redaction.
- Host guidance: `guides/introduction/inbox-integration.md`, its doc contract, and the demo-host configuration/auth examples.
- Gate parity: root `mix.exs` aliases, `.github/workflows/ci.yml`, `MAINTAINING.md`, and `test/chimeway/release_gate_contract_test.exs`.

</code_context>

<specifics>
## Specific Ideas

- Use the exact visible labels “Notification seen” and “Notification read.”
- Model the guide's lifecycle comparison as a compact semantics table and link to the existing mobile operations authority for provider-handoff and protected-activation boundaries.
- Keep `mix verify.inbox` as the single local and CI owner of the complete inbox proof surface.

</specifics>

<deferred>
## Deferred Ideas

- Android/FCM, retention/pruning, analytics/engagement inference, generic offline sync, package promotion, additional provider integrations, broad inbox redesign, and CI topology refactors remain outside Phase 107.
- Repository-wide release hygiene and the 1.2.0 release train will run as a separate bounded stabilization batch after the milestone closes.

</deferred>

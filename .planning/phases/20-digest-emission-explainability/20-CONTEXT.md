# Phase 20: Digest Emission & Explainability - Context

**Gathered:** 2026-04-28 (assumptions mode + research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Generate, dispatch, and explain digest deliveries from the durable digest buckets introduced in
Phase 19. This phase covers selecting and resolving bucket memberships at flush time, emitting one
canonical digest delivery through the normal dispatch lifecycle, and making inclusion, exclusion,
and immediate-send outcomes operator-explainable. Template versioning, richer rendering contracts,
and broader recovery/analytics surfaces remain later-phase work.

</domain>

<decisions>
## Implementation Decisions

### Digest Emission Lifecycle
- **D-01:** Phase 20 should emit each digest flush as its own canonical `chimeway_deliveries` row,
  then hand that row to the existing sync/Oban dispatch lifecycle instead of introducing a
  digest-only execution pipeline.
- **D-02:** Bucket flush work should stay limited to durable bucket claim, member resolution,
  digest-delivery creation, and canonical enqueue/dispatch handoff; provider calls, attempt
  history, retries, and final delivery convergence belong on the emitted digest delivery row.
- **D-03:** Oban remains an optional execution seam, not the source of truth. All facts required to
  reproduce or explain a digest send must persist in Chimeway tables before queue handoff.

### Membership Resolution Facts
- **D-04:** `digest_memberships` must gain durable per-member resolution facts rather than relying on
  indirect derivation. Each membership should persist a terminal resolution such as included,
  skipped, or emitted_immediately plus a machine-readable `resolution_reason`, `resolved_at`, and
  `digest_delivery_id` when included in an emitted digest.
- **D-05:** Membership resolution facts must snapshot the exact rule/window identity used at flush
  time so later rule edits, policy changes, or bucket mutations cannot rewrite history.
- **D-06:** Digest emission must be idempotent at the database layer by combining bucket/member
  claiming, membership resolution writes, digest-delivery creation, and enqueue/dispatch handoff in
  one transaction. Queue uniqueness may reduce duplicate work, but it cannot be the correctness
  boundary.

### Explainability Surface
- **D-07:** Operator explainability should stay under `Chimeway.Traces` as the primary entrypoint.
  Phase 20 may add digest-specific trace functions and structs, but it should not introduce a
  separate top-level operator API.
- **D-08:** Source delivery explanations must answer "why did this source notification join digest D,
  skip digest D, or send immediately instead?" Emitted digest explanations must answer "which source
  deliveries were included, under which rule/window, and what was excluded or deferred?"
- **D-09:** Explainability data must be durable and sanitized. Do not solve digest explanation by
  dumping raw event payloads, rendered content, or provider responses into `planning_context` or
  metadata blobs.

### Source Delivery Convergence
- **D-10:** Source `:digest_held` rows must converge in place after flush; they must not remain
  indefinitely `status == :pending`.
- **D-11:** Included source rows should land on an explicit digest terminal outcome on the existing
  canonical row, with lightweight linkage back to the emitted digest delivery rather than pretending
  the source row itself was sent.
- **D-12:** Skipped-at-flush or immediate-send outcomes must also converge durably on the canonical
  source row with explicit reasons so later traces, reconciliation, and Phase 22 analytics can
  distinguish "digested", "sent immediately", "skipped by policy", and "still waiting for a future
  flush" without secondary inference.

### Developer Experience and Least Surprise
- **D-13:** The design should optimize for one obvious operator story and one obvious developer story:
  delivery rows remain the lifecycle spine, digest memberships explain membership decisions, and
  `Chimeway.Traces` remains the place to ask "why did this happen?"
- **D-14:** Preview/inspection helpers for digest behavior should feel more like Discourse/GitHub
  reasoning surfaces than a hosted workflow debugger: concrete reasons, clear included/excluded
  lists, and stable durable identifiers.
- **D-15:** Planning and implementation should avoid Ecto N+1 flush paths. Bucket/member resolution
  must preload or join the source notification/event facts needed for policy rechecks and operator
  explanations rather than `Repo.get!` looping per membership.

### the agent's Discretion
- Exact schema/module names for emitted digest delivery linkage and membership resolution enums.
- Whether digest-specific operator queries live as new `Traces.*` functions or adjacent structs
  under the same namespace, as long as `Chimeway.Traces` remains the primary entrypoint.
- Whether the explicit source-row terminal outcome is represented as a new delivery status such as
  `:digested` or an equivalent durable terminal shape, provided dispatcher guards, traces, and
  future analytics all treat it coherently.

</decisions>

<specifics>
## Specific Ideas

- Model operator-facing reasons after GitHub's explicit "why am I seeing this?" posture: store and
  expose durable, human-meaningful reasons rather than making operators reverse-engineer state.
- Model digest preview/inspection helpers after Discourse's activity-summary previewability and
  sent-email visibility, not after a SaaS workflow debugger.
- Learn from Knock's strengths without copying its hosted-workflow complexity: explicit batch/window
  identity and skip reasons are valuable; retention-bound logs, first-activity caveats, and queue-
  shaped truth are not.
- Avoid the Noticed/Laravel/Symfony footguns where class names, queue timing, or background-worker
  presence become accidental durable identity or hidden correctness dependencies.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone and phase scope
- `.planning/ROADMAP.md` — Phase 20 goal, dependency, and success criteria.
- `.planning/REQUIREMENTS.md` — `DIGEST-02` and `DIGEST-03` requirements.
- `.planning/PROJECT.md` — local-first ownership, stable identity, explainability, and DX posture.
- `.planning/STATE.md` — carried-forward orchestration and digest decisions from Phases 17-19.

### Prior phase carry-forward decisions
- `.planning/phases/18-scheduled-resume-deferred-dispatch/18-CONTEXT.md` — canonical row mutation
  and trace continuity posture for orchestration transitions.
- `.planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md` — durable digest rule/bucket/
  membership model and explicit deferral of emission/explainability to Phase 20.
- `.planning/phases/19-digest-data-model-accumulation/19-RESEARCH.md` — prior art and architecture
  direction feeding the digest model.

### Existing orchestration and digest model
- `lib/chimeway/delivery.ex` — current delivery status/orchestration enums.
- `lib/chimeway/deliveries.ex` — canonical delivery transitions, suppression/convergence helpers,
  and terminal-state rules.
- `lib/chimeway/delivery_planning.ex` — digest-held planning choke point and accumulation handoff.
- `lib/chimeway/digests.ex` — digest rule lookup contract.
- `lib/chimeway/digests/accumulation.ex` — bucket identity, membership inserts, and current
  transaction shape.
- `lib/chimeway/digests/digest_bucket.ex` — durable bucket schema and grouping/window fields.
- `lib/chimeway/digests/digest_membership.ex` — current membership schema that Phase 20 must extend.

### Dispatch and trace continuity
- `lib/chimeway/dispatch/sync.ex` — ready-only sync execution path.
- `lib/chimeway/dispatch/oban.ex` — canonical enqueue flow and transactionally consistent job
  handoff.
- `lib/chimeway/dispatch/oban_worker.ex` — `delivery_id`-only execution, retry semantics, and
  terminal short-circuiting.
- `lib/chimeway/traces.ex` — public operator trace entrypoint.
- `lib/chimeway/traces/explanation.ex` — current explanation contract and fields.

### Existing tests that lock behavior
- `test/chimeway/orchestration/dispatch_gating_test.exs` — digest-held rows must not dispatch before
  a later phase promotes them.
- `test/chimeway/orchestration/traces_deferral_test.exs` — digest-held trace surfaces stay separate
  from suppression and preserve sanitized planning facts.
- `test/chimeway/orchestration/delivery_planning_test.exs` — planning keeps one canonical
  notification/channel row under digest-held orchestration.
- `test/chimeway/digests/accumulation_test.exs` — bucket/membership identity, idempotency, and
  durable window semantics.
- `test/chimeway/traces_test.exs` — current public trace/explanation contract to extend, not bypass.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Deliveries`: already owns canonical lifecycle transitions, suppression/convergence
  helpers, and terminal-state semantics that emitted digest deliveries should reuse.
- `Chimeway.Dispatch.Oban` and `Chimeway.Dispatch.ObanWorker`: already provide the thin-job,
  `delivery_id`-only execution model that keeps queue state non-authoritative.
- `Chimeway.DeliveryPlanning`: already centralizes digest-held planning and is the natural hook for
  future flush scheduling/handoff boundaries.
- `Chimeway.Traces`: already exposes the operator-facing "why did this happen?" surface and
  sanitizes durable planning facts.

### Established Patterns
- Chimeway prefers explicit schemas and durable facts over hidden workflow state or JSON-only blobs.
- Canonical rows are mutated or linked in place rather than replaced.
- Queue/job records are execution artifacts, not business truth.
- Explainability is designed as product behavior, not support-only metadata.
- Stable durable identity is data-based (`notification_key`, versions, persisted row IDs), not code-
  identifier-based.

### Integration Points
- Phase 20 will connect digest bucket/membership data to a new emitted digest delivery row and the
  existing dispatch pipeline.
- Membership resolution facts must bridge the current accumulation model to future traces and Phase
  22 analytics without requiring retrospective inference.
- Any new digest terminal outcome on source rows must be wired through `Delivery`, `Deliveries`,
  dispatch guards, and `Traces` together.

</code_context>

<deferred>
## Deferred Ideas

- Full workflow-debugger or hosted-style visual orchestration UX.
- Rich template preview/rendering contracts beyond digest explainability needs; those belong to Phase
  21.
- Broader aggregate outcome dashboards and reconciliation tooling; those belong to Phase 22.
- Multi-stage or nested digest workflows and advanced SaaS-style batching policies.

</deferred>

---

*Phase: 20-digest-emission-explainability*
*Context gathered: 2026-04-28*

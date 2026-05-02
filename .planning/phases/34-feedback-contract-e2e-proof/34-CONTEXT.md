# Phase 34: feedback-contract-e2e-proof - Context

**Gathered:** 2026-05-02 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the v1.4 milestone audit by proving the feedback contract end-to-end on the real
path: lock the canonical signal event-name vocabulary, ship one host-mounted E2E test
that exercises webhook → ingress → worker → signal → workflow progression → operator
trace, and produce verification/summary artifacts that explicitly map FLOW-01 and
FLOW-02 so the milestone audit can close without orphaned requirements.

In scope:
- Vocabulary lock for the **signal event-name axis** only (`chimeway.delivery.{succeeded,bounced,failed}`).
- Drift fix for synthetic trace fixtures that emit `chimeway.delivery.delivered`.
- One new E2E test inside `examples/chimeway_demo_host/test/` that runs the real route
  through `Chimeway.Webhooks.process/4` and inline-drains both Oban queues to land both
  the worker-driven progression transition and the router-driven `signal_received`
  transition.
- `34-VERIFICATION.md` with a requirements table mapping FLOW-01/FLOW-02 to evidence
  spanning Phase 31 emission code, Phase 32 trace projection code, and the new Phase 34
  E2E test. Each Phase 34 plan SUMMARY declares `requirements-completed: [FLOW-01, FLOW-02]`
  in frontmatter (matching Phase 33's pattern).
- A short audit-stale callout in 34-VERIFICATION explaining that FEED-01/FEED-02 were
  already closed by `33-VERIFICATION.md:115-118` after the 2026-05-01 audit was written.

Out of scope:
- Collapsing the **adapter-normalized status axis** (`:delivered|:bounced|:failed`) or the
  **workflow-curated outcome axis** (`ProgressionOutcome`'s `:delivered|:suppressed|...`).
  Those are deliberately distinct vocabularies; only the signal-name axis is being locked.
- Retroactive edits to Phase 31's `31-VERIFICATION.md` or `31-01/02-SUMMARY.md` frontmatter.
  Phase 34's verification closes FLOW-01/02 forward.
- Retroactive edits to Phase 30's missing artifacts. FEED-01/02 closure already lives in
  Phase 33's verification; pointing at it from Phase 34 is sufficient.
- Inverting `canonicalize_status/1` to emit `chimeway.delivery.delivered` instead of
  `.succeeded`. Production code, the `Delivery.status` atom (`:succeeded`), and existing
  worker tests already agree on `succeeded` — flipping them is a much larger change with
  no product-value justification.
- Any new outcome atoms, new signal event-name shapes, new timeline ranks, new
  `WorkflowTransition.context` keys, or new error tuples.
- Bundled vendor adapters, broader provider expansion, read/unread branching, or operator UI.

</domain>

<decisions>
## Implementation Decisions

### Canonical outcome vocabulary
- **D-01:** The signal event-name axis is locked to `chimeway.delivery.{succeeded,bounced,failed}`.
  This is what `lib/chimeway/webhooks/process_feedback_worker.ex:139` already produces via
  `canonicalize_status("delivered") -> "succeeded"` and what
  `test/chimeway/webhooks/process_feedback_worker_test.exs:77,117` already asserts on the
  real worker.
- **D-02:** Three vocabularies stay distinct by design. They live on separate axes and
  must NOT be collapsed in this phase:
  1. **Adapter-normalized status** — atoms `:delivered | :bounced | :failed` returned by
     `normalize_feedback/1`. The string form is persisted to `Ingress.normalized_status`
     (`lib/chimeway/webhooks/ingress.ex:28`).
  2. **Signal event-name suffix and worker outcome atom** —
     `succeeded | bounced | failed`, post-`canonicalize_status/1`. Locked.
  3. **Workflow-curated branchable outcome** —
     `:delivered | :suppressed | :temporary_failure | :retries_exhausted | :permanent_failure | :bounced`,
     produced by `Chimeway.Workflows.ProgressionOutcome.from_delivery/2`
     (`lib/chimeway/workflows/progression_outcome.ex:12-26, 74-80`). This is the
     rule-authoring vocabulary; collapsing it into the signal-name axis would break the
     Phase 25 curated workflow contract.
- **D-03:** Drift fix scope is the synthetic trace fixtures only —
  `test/chimeway/traces_test.exs:416,523` use `chimeway.delivery.delivered` for hand-built
  `signal_received` companion rows. Update those fixtures to `chimeway.delivery.succeeded`
  (and use `.bounced` / `.failed` where appropriate). Do not change production code, do
  not add new normalization shims, and do not introduce a vocabulary translation table.
- **D-04:** Document the three-axis vocabulary contract in 34-VERIFICATION.md as part of
  the FLOW-01/FLOW-02 evidence table so the next milestone audit can reference one
  authoritative explanation rather than rediscovering the distinction.

### End-to-end proof shape
- **D-05:** The E2E test lives in `examples/chimeway_demo_host/test/demo_host_web/controllers/`
  (a new test file or an additional `describe` in the existing webhooks controller test).
  This is the only existing harness that boots a real Phoenix endpoint, real plug
  pipeline, real `Chimeway.Webhooks.process/4`, and a sandboxed `Chimeway.Repo` shared
  across the request and Oban workers.
- **D-06:** The test scenario:
  1. Insert a real `Chimeway.Workflows.WorkflowDefinition` + `WorkflowRun` with one step
     in state `:waiting` keyed on `chimeway.delivery.succeeded` (or `.bounced` for the
     stop-path variant).
  2. Insert a real `Chimeway.Deliveries.Delivery` row in a non-terminal state with
     `workflow_run_id` populated.
  3. POST to the real `/webhooks/chimeway/echo` route with a body that resolves via
     `examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex:37` (the existing
     `"delivery_id"` clause exposed precisely so a real `chimeway_deliveries` FK can
     drive the test).
  4. Inline-drain Oban queues in this order:
     - `Oban.drain_queue(queue: :chimeway_delivery)` — runs `ProcessFeedbackWorker`,
       which calls `Deliveries.record_attempt/2` and synchronously progresses the
       workflow run (via `lib/chimeway/deliveries.ex:1184-1207`), and emits the signal
       via `Chimeway.Signal.track/4`.
     - `Oban.drain_queue(queue: :chimeway_signals)` — runs `SignalRouterWorker`, which
       writes the `signal_received` `WorkflowTransition` row through
       `Chimeway.Workflows.route_signal/1`.
- **D-07:** Test assertions must cover, at minimum:
  1. HTTP 2xx returned by the endpoint.
  2. `Chimeway.Webhooks.Ingress` row committed with `normalized_status` populated.
  3. `Chimeway.Deliveries.DeliveryAttempt` row written with the canonical outcome atom
     (`:succeeded` or `:bounced`).
  4. `Chimeway.Signals.Signal` row exists with
     `event_name == "chimeway.delivery.succeeded"` (or `.bounced`).
  5. `WorkflowRun.state` flipped from `:waiting` to `:active` (or terminal state for
     stop-path).
  6. At least one `WorkflowTransition` with `reason == "signal_received"` AND
     `delivery_id == delivery.id` (Phase 32 D-02 wiring).
  7. `Chimeway.Traces.explain_delivery(delivery.id).timeline` carries both
     `:webhook_received` (rank 13) and at least one `:workflow_*` projection atom
     (`:workflow_progressed` for the progress path, `:workflow_stopped` for the stop path).
- **D-08:** Use real `Oban.drain_queue/1` for the Oban handoff, not `assert_enqueued`
  followed by manual `perform_job`. Draining exercises the actual Multi-attached job and
  the Phase 33 atomic-handoff seam end-to-end. Reference posture:
  `test/chimeway/reliability/retry_exhaustion_test.exs:133`.
- **D-09:** Cover at least the progress path (delivered → step advances) and the stop
  path (bounced → workflow stops) in the same test file. One scenario each is enough to
  prove SC-2; richer matrices (waiting, escalation, multi-step) are deferred unless
  evidence emerges that single-link scenarios miss a real defect.

### Audit-closure artifacts
- **D-10:** `34-VERIFICATION.md` ships with a requirements table mapping FLOW-01 and
  FLOW-02 to evidence cells citing:
  - Phase 31 emission code (`process_feedback_worker.ex` signal track + canonicalize),
  - Phase 32 trace projection code (`traces.ex` workflow_transition_entries + timeline),
  - the new Phase 34 E2E test as the closing milestone-level proof.
  Table format follows `33-VERIFICATION.md:115-118`.
- **D-11:** Each Phase 34 plan SUMMARY declares `requirements-completed: [FLOW-01, FLOW-02]`
  in YAML frontmatter, matching the canonical pattern at `33-04-SUMMARY.md:75`.
- **D-12:** Phase 34 does NOT amend Phase 31's verification or summaries. Methodology
  lenses (Cohesive Recommendation Default, Low-Escalation Recommendation Default,
  Least-Surprise DX Default) favor a single forward-looking artifact when the audit's
  rule is "REQ-mapping must exist in some verification artifact" (per
  `v1.4-MILESTONE-AUDIT.md:32-39`). If the next audit pass disagrees and requires
  retroactive mapping, the fallback is a 30-line additive edit; that fallback is
  reversible and stays out of scope until proven necessary.
- **D-13:** Phase 34 does NOT touch Phase 30 artifacts. FEED-01/02 are already closed by
  `33-VERIFICATION.md:115-118` (which post-dates the 2026-05-01 audit). 34-VERIFICATION
  includes a brief "Audit Notes" section pointing at this so the next milestone-audit
  pass clears all four orphaned IDs (FEED + FLOW) in one sweep.

### Claude's Discretion
- Whether the new E2E test goes in a brand-new file
  (`webhooks_e2e_test.exs` / `feedback_pipeline_test.exs`) or as a new `describe` block
  in the existing `webhooks_controller_test.exs`. Both are correct; pick the layout that
  keeps failure diagnostics most legible.
- Exact step-key strings for the test workflow definition (e.g. `"delivered_then_done"`),
  step rule shape, and tenant_id value, so long as they exercise both the progress and
  stop paths and use the project's standard tenancy posture.
- Whether the failure-mode signal name (`chimeway.delivery.failed`) gets a third scenario
  in the same test file. Default: skip unless writing the progress + stop scenarios
  surfaces a non-obvious code path that needs the third covering case.
- Exact wording of the audit-stale callout in 34-VERIFICATION's "Audit Notes" section
  (clear and dated, ≤6 lines).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone scope
- `.planning/ROADMAP.md` — Phase 34 goal, success criteria, FLOW-01/FLOW-02 traceability.
- `.planning/REQUIREMENTS.md` — FLOW-01 and FLOW-02 (the only requirements this phase
  must close).
- `.planning/PROJECT.md` — local-first ownership, durable identity, explainability as
  product value.
- `.planning/STATE.md` — current milestone posture; Phase 33 just completed.
- `.planning/v1.4-MILESTONE-AUDIT.md` — the audit gaps this phase closes; note the FEED
  claims are stale post-`33-VERIFICATION.md`.
- `.planning/METHODOLOGY.md` — Cohesive Recommendation, One-Shot Recommendation,
  Research-First Decision Ownership, Durable Explainability, Least-Surprise DX,
  Low-Escalation Recommendation, High-Impact Escalation Gate.

### Prior phase carry-forward (read for locked design constraints)
- `.planning/phases/29-outbound-channel-contracts/29-CONTEXT.md` — adapter identity,
  per-attempt `adapter_module` field, atom-safety posture.
- `.planning/phases/30-inbound-feedback-normalization/30-RESEARCH.md` — original pure
  function webhook boundary; `normalize_feedback/1` outcome contract.
- `.planning/phases/31-feedback-driven-progression/31-RESEARCH.md` — signal emission seam
  and `route_signal` posture.
- `.planning/phases/31-feedback-driven-progression/31-VERIFICATION.md` — current
  verification artifact (does NOT map FLOW-01/02; Phase 34 closes that gap forward).
- `.planning/phases/32-operator-traces-audit/32-CONTEXT.md` — five timeline atoms,
  reason→atom dispatch, `:webhook_received` source = `DeliveryAttempt`,
  `WorkflowTransition.delivery_id` populated by `route_signal/1`.
- `.planning/phases/32-operator-traces-audit/32-VERIFICATION.md` — TRAC-01/TRAC-02 table
  format reference.
- `.planning/phases/33-webhook-ingress-durability/33-CONTEXT.md` — atomic ingress seam,
  ingress row schema, host-mounted proof posture (`examples/chimeway_demo_host`),
  Phase 34 boundary statements (D-14 explicitly defers vocabulary cleanup + E2E proof
  to Phase 34).
- `.planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md` — FEED-01/FEED-02
  closure evidence and the canonical requirements-table format Phase 34 reuses.
- `.planning/phases/33-webhook-ingress-durability/33-04-SUMMARY.md` — canonical
  `requirements-completed:` frontmatter pattern (line 75).

### Existing source files (the surface this phase touches)
- `lib/chimeway/webhooks/process_feedback_worker.ex` — `canonicalize_status/1` (line 139),
  signal emission via `Chimeway.Signal.track/4` (lines 158-168), already-canonical event
  names. **Read-only reference** — Phase 34 does not change worker logic.
- `lib/chimeway/webhooks/ingress.ex` — `normalized_status` allowed values (line 28).
  Read-only reference.
- `lib/chimeway/webhooks.ex` — `process/4` atomic ingress seam from Phase 33. Read-only.
- `lib/chimeway/signal.ex` — `track/4` atomic write+enqueue. Read-only.
- `lib/chimeway/dispatch/signal_router_worker.ex` — drains `:chimeway_signals`, calls
  `route_signal/1`. Read-only.
- `lib/chimeway/workflows.ex` — `route_signal/1` at lines 393-431, populates
  `WorkflowTransition.delivery_id` at line 419 (Phase 32 D-02). Read-only.
- `lib/chimeway/workflows/progression.ex` — `advance_run`/`stop_run` write `delivery_id`
  on transitions (lines 309, 370). Read-only.
- `lib/chimeway/workflows/progression_outcome.ex` — curated workflow-facing vocabulary
  (lines 12-26, 74-80). Read-only; documents why D-02's three-axis distinction matters.
- `lib/chimeway/deliveries.ex` — `record_attempt/2` synchronous workflow-progression
  hook (lines 1184-1207). Read-only.
- `lib/chimeway/traces.ex` — `explain_delivery/1`, `build_timeline/5`, timeline projection
  (lines 506-575). Read-only; existing projection is the assertion target.

### Test files (the surfaces Phase 34 modifies or extends)
- `test/chimeway/traces_test.exs` — fixtures at lines 416, 523 use
  `chimeway.delivery.delivered`. Update to canonical `.succeeded` (and `.bounced` where
  appropriate). **Modification target.**
- `test/chimeway/webhooks/process_feedback_worker_test.exs` — already asserts canonical
  signal names at lines 77, 117. Read-only reference (proves the production contract).
- `examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs`
  — existing E2E harness with `use Oban.Testing, repo: Chimeway.Repo` and shared sandbox
  mode. **Extension target** — Phase 34's new E2E scenario(s) live here or in a sibling
  file in the same directory.
- `test/chimeway/reliability/retry_exhaustion_test.exs:133` — reference posture for
  inline `Oban.drain_queue/1` usage.

### Demo host (canonical real-host harness — Phase 33's deliverable)
- `examples/chimeway_demo_host/lib/demo_host_web/router.ex` — real `/webhooks/chimeway/echo`
  route.
- `examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex` —
  calls `Chimeway.Webhooks.process/4`.
- `examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` — Phase 33-06
  raw-body preservation for HMAC.
- `examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex:37` — existing
  `"delivery_id"` resolution clause (the seam Phase 34's E2E uses to bind a webhook
  payload to a real `chimeway_deliveries` row).
- `examples/chimeway_demo_host/config/test.exs` — Oban + Repo test config (already wired
  for `use Oban.Testing`).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Chimeway.Signal.track/4`** — atomic insert + Oban enqueue. Already used by the
  worker. Phase 34 only verifies its observable effects in the new E2E test.
- **`Chimeway.Webhooks.process/4`** — Phase 33 atomic ingress seam. Phase 34 calls it
  through the real Phoenix route, no direct invocation.
- **`Chimeway.Deliveries.record_attempt/2`** (lines 1184-1207) — synchronously triggers
  `Workflows.Progression.progress_run/2` when delivery has `workflow_run_id`. Means a
  single drain of `:chimeway_delivery` lands the `progressed_on_delivery_outcome`
  transition in the same call stack as the worker.
- **`Chimeway.Workflows.route_signal/1`** (lines 393-431) — writes the `signal_received`
  `WorkflowTransition` with `delivery_id` populated (Phase 32 D-02). One drain of
  `:chimeway_signals` lands this row.
- **`Chimeway.Traces.explain_delivery/1`** with `build_timeline/5` (lines 506-575) —
  joint projection of `DeliveryAttempt` (`:webhook_received`) and `WorkflowTransition`
  rows linked on `delivery_id` (`:workflow_*`). Direct assertion target for SC-1's
  trace coverage.
- **demo_host webhooks controller test** — already has the sandboxed-Repo +
  `use Oban.Testing` plumbing; new scenarios extend the existing setup, not rebuild it.
- **`EchoAdapter` `"delivery_id"` clause** (`echo_adapter.ex:37`) — exists precisely so
  a webhook payload can name an existing `chimeway_deliveries.id` and drive a real FK
  resolution in tests. No new adapter code needed.

### Established Patterns
- **Three-axis outcome vocabulary** — adapter-normalized status, internal signal
  event-name, and workflow-curated branchable outcome are deliberately separate. The
  drift this phase fixes is fixture-only; the production contract is already correct
  and consistent.
- **Atomic Multi handoffs** (Phase 12 / Phase 33) — every "persist domain fact + queue
  Oban work" boundary uses `Ecto.Multi`. Phase 34's E2E test asserts the observable
  effect, not the implementation detail.
- **Compile-time literal atom dispatch** (Phases 11, 27, 32) — never derive event-name
  atoms from strings. Phase 34 follows the same posture: signal name strings are
  validated by string-match in tests, never via `String.to_atom`.
- **Tenant-scoped reads** (Phase 27) — every cross-table query filters by `tenant_id`.
  The new E2E test must set `tenant_id` consistently across `WorkflowRun`, `Delivery`,
  and any inserted `Signal` payload entries.
- **Sandboxed Oban + shared-mode Repo** (Phase 33-04 SUMMARY) — the demo host's test
  setup hands the sandboxed connection to a `:shared` mode allowing the controller
  request and async Oban workers to see the same data. Reuse, do not modify.
- **`requirements-completed:` frontmatter on plan summaries** (Phase 33-04 / Phase 32 /
  Phase 29) — milestone-audit-friendly closure shape. Phase 34 plans follow this.

### Integration Points
- `examples/chimeway_demo_host/test/demo_host_web/controllers/` — primary surface for
  the new E2E test file.
- `test/chimeway/traces_test.exs:416,523` — fixture drift correction site.
- `.planning/phases/34-feedback-contract-e2e-proof/` — Phase 34 plan directories,
  SUMMARY frontmatter, and 34-VERIFICATION.md authoring.

</code_context>

<specifics>
## Specific Ideas

- The audit's "Outcome vocabulary drifts across phases" claim points at three lines
  total: two synthetic fixtures in `traces_test.exs` (`chimeway.delivery.delivered`),
  and one mismatch the milestone summary calls out between
  `process_feedback_worker_test.exs` (canonical) and `traces_test.exs` (drifted).
  The drift is documentation-shaped, not architecture-shaped — production code
  already lives at the canonical contract.
- The two-row pattern from Phase 32 (`:webhook_received` from `DeliveryAttempt` +
  `:workflow_*` from `WorkflowTransition`) is the natural assertion shape for SC-1's
  "trace projection agrees on canonical vocabulary" requirement. The E2E test asserts
  both rows exist and both project to the canonical event atoms — proving the contract
  end-to-end without inspecting internal state.
- 34-VERIFICATION's audit-stale callout serves a real purpose beyond documentation
  hygiene: it tells the next audit pass that FEED-01/02 closure already exists in
  Phase 33's verification, so the audit doesn't need a Phase 30 backfill round.
  Keep it short, dated, and pointed at `33-VERIFICATION.md:115-118`.

</specifics>

<deferred>
## Deferred Ideas

- **Inverting `canonicalize_status/1`** to make the canonical name `delivered` instead
  of `succeeded`. Out of scope; production code, `Delivery.status` atom, and existing
  worker tests already agree on `succeeded`.
- **Retroactive REQ-mapping edits in Phase 31's verification/summaries.** Out of scope
  unless the next audit pass requires REQ-mapping to live in the originally claiming
  phase rather than any verification artifact.
- **Backfilling Phase 30 verification artifacts** (`30-VERIFICATION.md`,
  `requirements-completed` frontmatter on `30-01-SUMMARY.md`). Out of scope; FEED-01/02
  are already closed by Phase 33 and pointing at that closure is sufficient for the
  next milestone-audit pass.
- **A vocabulary translation table or normalization shim** between adapter-status,
  signal-name, and curated-workflow-outcome axes. Out of scope; the three axes are
  intentionally distinct and the drift is fixture-only.
- **Multi-step / escalation E2E scenarios** beyond progress + stop. Out of scope for
  Phase 34 unless single-link coverage misses a real defect.
- **A `chimeway.delivery.failed` E2E scenario** as a third covering case. Out of scope
  by default; revisit if the progress + stop scenarios surface a non-obvious code path.
- **Telemetry events or structured logs** for the new E2E flow. Existing per-attempt /
  per-signal / per-transition telemetry from Phases 29-32 already covers these data
  sources.
- **Operator UI surfacing the trace projection.** Explicit milestone-deferred per
  `STATE.md` deferred items.
- **Read/unread-driven workflow branching.** Explicit milestone-deferred per `STATE.md`.

</deferred>

---

*Phase: 34-feedback-contract-e2e-proof*
*Context gathered: 2026-05-02 (assumptions mode)*

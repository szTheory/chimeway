# Phase 49: Inbox Read → Signal - Context

**Gathered:** 2026-05-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Close READ-02 and READ-03: `Chimeway.mark_read/3` and `mark_seen/3` emit durable signals routed through `SignalRouterWorker`, so `:waiting` workflow runs whose `pending_signals` include the canonical inbox events resume to `:active` with an explainable `signal_received` transition (event name only, no raw payload).

**In scope:** Signal emission wiring in inbox lifecycle APIs, tenant resolution for signal tracking, idempotent emission on first state transition, progression/orchestration tests proving mark_read → signal → resume path, journey guide doc-truth update removing READ-02 deferral.

**Out of scope:** Demo seed refactor / `stage_escalation_webhook/1` removal (Phase 50), JOUR-06 journey proof (Phase 51), mention-escalation recipe rewrite (DEMO-04, Phase 50), changes to `route_signal/1` matching or post-match behavior (Phase 48 D-07).

</domain>

<decisions>
## Implementation Decisions

### Implementation seam
- **D-01:** Wire signal emission inside `Chimeway.Inbox` after successful lifecycle timestamp update, calling `Chimeway.Signal.track/4`. Keep `Chimeway.mark_read/3` and `mark_seen/3` as thin facades — no duplicate logic in `lib/chimeway.ex`.

### Tenant resolution
- **D-02:** Resolve `tenant_id` for signal tracking via join: notification → `workflow_run` (preferred), fallback to first `delivery` row for that notification. Notifications do not store `tenant_id` directly; both `WorkflowRun` and `Delivery` inherit it from `trigger/3` opts.

### Canonical event names
- **D-03:** `mark_read/3` emits `chimeway.notification.read`; `mark_seen/3` emits `chimeway.notification.seen`. Exact strings per Phase 48 D-05 — no namespace variation.

### Read vs seen semantics
- **D-04:** Emit distinct signals only — `mark_read` does not auto-emit `chimeway.notification.seen` and vice versa. Preserves INBX-02/INBX-03 independence (read_at and seen_at are separate lifecycle facts).

### Signal payload
- **D-05:** Signal payload includes `%{"notification_id" => notification_id}` for downstream correlation. Operator traces continue to show event name only in `signal_received` transition context (READ-03 — no raw payload in trace).

### Idempotent emission
- **D-06:** Emit signals only on first transition (nil → timestamp). Re-marking an already-read or already-seen notification is a no-op for signal emission — no duplicate signal rows.

### Transaction coupling
- **D-07:** Inbox timestamp update completes first; `Signal.track/4` runs in its own `Ecto.Multi` transaction (signal insert + Oban enqueue). Do not wrap inbox update and signal track in one atomic Multi.

### READ-03 / route_signal behavior
- **D-08:** No changes to `route_signal/1`, `SignalRouterWorker`, or progression post-match behavior. READ-03 is satisfied by existing `signal_received` transition with `%{"event_name" => event_name}` context. Phase 49 proves end-to-end: `mark_read` → signal → resume → trace.

### Doc-truth
- **D-09:** Update `guides/flows/multi-step-journeys.md` — remove READ-02 deferral, document inbox emission wiring for `mark_read`/`mark_seen`. Extend `test/chimeway/doc_contract_test.exs` to lock the new doc truth (mirrors Phase 48-03 pattern).

### Claude's Discretion
- Exact query for tenant resolution fallback when neither workflow_run nor delivery exists (emit signal with `"default"` vs skip emission).
- Whether to add `notification_id` to `delivery_id` join path in trace explain surfaces (optional polish; not required for READ-03).
- Test fixture shape for inbox → signal → progression integration proof.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/ROADMAP.md` — Phase 49 goal, success criteria, dependency on Phase 48
- `.planning/REQUIREMENTS.md` — READ-02, READ-03 acceptance criteria
- `.planning/PROJECT.md` — v1.7 READ milestone scope
- `.planning/METHODOLOGY.md` — research-first, least-surprise DX lenses

### Prior phase context
- `.planning/phases/48-wait-until-pending-signals/48-CONTEXT.md` — canonical event names (D-05), route_signal unchanged (D-07), pending_signals population

### Engine implementation
- `lib/chimeway/inbox.ex` — primary change seam (`mark_read/3`, `mark_seen/3`)
- `lib/chimeway/signal.ex` — `track/4` durable signal + Oban enqueue
- `lib/chimeway/workflows.ex` — `route_signal/1`, `find_runs_waiting_for_signal/3` (no behavioral change)
- `lib/chimeway/dispatch/signal_router_worker.ex` — async routing entrypoint
- `lib/chimeway/webhooks/process_feedback_worker.ex` — `emit_signal/2` reference pattern for delivery feedback

### Docs & contracts
- `guides/flows/multi-step-journeys.md` — canonical inbox events, READ-02 deferral to remove
- `test/chimeway/doc_contract_test.exs` — doc-truth contract tests

### Test patterns
- `test/chimeway/inbox_state_transition_test.exs` — read/seen independence (INBX-02/03)
- `test/chimeway/orchestration/workflow_progression_test.exs` — injected signal resume proof (extend with mark_read emission)
- `test/chimeway/signal_test.exs` — `Signal.track/4` + Oban enqueue assertions
- `test/chimeway/workflows_test.exs` — `route_signal/1` transition trace assertions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Signal.track/4` — durable signal insert + `SignalRouterWorker` enqueue in one `Ecto.Multi`.
- `Chimeway.Inbox.update_lifecycle_timestamp/4` — scoped `Repo.update_all` by notification id + recipient identity; returns `{1, _}` on success.
- `WorkflowRun.pending_signals` + `route_signal/1` — full match + atomic `:waiting` → `:active` transition already proven in Phase 48.
- Canonical event names `chimeway.notification.read` / `.seen` — documented in journey guide and notifier contract tests.

### Established Patterns
- Delivery feedback emits signals via `ProcessFeedbackWorker.emit_signal/2` after primary work completes — separate transaction from feedback row write.
- Signal routing matches on `tenant_id` + `actor_id` (recipient_identity) + `event_name in pending_signals` + `state == :waiting`.
- Inbox lifecycle APIs are explicit — seen, read, and archived are independent timestamps; no implicit cross-transitions.
- Operator traces redact signal payloads — transition context carries event name only.

### Integration Points
- `Inbox.mark_read/3` / `mark_seen/3` → lifecycle update → `Signal.track(tenant_id, recipient_identity, event_name, payload)`.
- `SignalRouterWorker` → `route_signal/1` → resume waiting runs with matching `pending_signals`.
- Journey guide §7 + Deferred section — READ-02 callout to remove after emission ships.
- Phase 50 demo refactor will consume READ-02 — `stage_escalation_webhook/1` manual glue becomes unnecessary.

</code_context>

<specifics>
## Specific Ideas

No user corrections — all assumptions confirmed as-is.

</specifics>

<deferred>
## Deferred Ideas

- **Demo seed choreography removal** — Replace `stage_escalation_webhook/1` with READ-driven TeamPulse escalation (Phase 50, DEMO-03).
- **JOUR-06 journey proof** — End-to-end mark_read cancels escalation before `wait_until` due_at (Phase 51).
- **Mention-escalation recipe** — Document read-cancel + `wait_until` fallback as canonical PM JTBD path (DEMO-04, Phase 50).

None — analysis stayed within phase scope.

</deferred>

---

*Phase: 49-Inbox Read → Signal*
*Context gathered: 2026-05-29 (assumptions mode)*

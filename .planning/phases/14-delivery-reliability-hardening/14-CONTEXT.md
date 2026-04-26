# Phase 14: delivery-reliability-hardening - Context

**Gathered:** 2026-04-26 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Make delivery retries and duplicate protection safe under real-world concurrency and failure for REL-01, REL-02, REL-03. Three concrete outcomes: (1) explicit, tested duplicate-protection contract across events, notifications, and deliveries when triggers/planning are retried; (2) Oban-driven retry on transient adapter failures with durable per-attempt history including error class and attempt number; (3) every delivery converges to a single, queryable terminal state with one source of truth shared by sync, Oban, and trace surfaces.

Out of scope: new channels, new dispatch modes, new business logic, host-app retry orchestration UI, schema changes outside `deliveries` and `delivery_attempts`.
</domain>

<decisions>
## Implementation Decisions

### Duplicate protection contract (REL-01)

- **D-01:** Treat existing dedup infrastructure as locked. The unique constraints on `chimeway_events.idempotency_key`, `chimeway_notifications.(event_id, recipient_identity)`, and `chimeway_deliveries.(notification_id, channel)` (with `Deliveries.plan_delivery/3` using `on_conflict: :nothing, conflict_target: [:notification_id, :channel]`) are the dedup mechanism. Phase 14 must not redesign this schema or these conflict targets.
- **D-02:** Add explicit duplicate-trigger contract tests covering: (a) `Trigger.fire/...` returning `{:duplicate, event}` on a re-fire; (b) `plan_notifications/2` re-entering cleanly when called twice for the same event (returning the existing pending deliveries without creating duplicate rows); (c) sync and Oban dispatch paths short-circuiting against already-terminal deliveries via the canonical terminal-state helper (see D-09); (d) preservation of the Phase 12 atomicity guarantee — partial enqueue failures still roll back planning rows.
- **D-03:** Keep `Trigger.dispatch_after_trigger/4` inert on `{:duplicate, event}` for Phase 14. Do NOT add a "resume dispatch on duplicate" path. Document this contract explicitly in module docs and trace explanations: a duplicate trigger does not re-drive dispatch for stranded pending deliveries. If host apps need to recover from a crash between event-insert and enqueue, that is a separate phase concern.

### Oban-driven retry for transient failures (REL-02 — central change)

- **D-04:** Make `Chimeway.Dispatch.ObanWorker.perform/1` actually trigger Oban's retry machinery on transient adapter failures. When `Executor.run_delivery/1` records an attempt classified as `:temporary`, the worker must return `{:error, reason}` (or `{:snooze, n}` if a custom curve is needed — see Claude's discretion) so Oban schedules the retry under its `max_attempts: 5` budget. When the classification is `:permanent` or `:bounced`, the worker continues to return `:ok` so Oban does NOT retry. Successful sends remain `:ok`.
- **D-05:** Preserve the `:temporary | :permanent | :bounced` distinction end-to-end. `Executor.classify/1` (lib/chimeway/dispatch/executor.ex:30-33) currently collapses `:temporary → :failed` and discards the class. Phase 14 must preserve the classification both in the worker return value (for retry) and in the persisted attempt row (see D-07).
- **D-06:** Each Oban-driven retry continues to write exactly one `DeliveryAttempt` row through the existing `Executor.run_delivery/1` seam — preserving retry history is a side effect of the existing one-attempt-per-call contract; no change required to the executor write path. The shared sync/Oban executor seam established in Phase 11 stays intact.

### Attempt history schema additions (REL-02)

- **D-07:** Add two columns to `chimeway_delivery_attempts`:
  - `attempt_number :integer` — the 1-indexed ordinal of this attempt for its delivery, computed at insert time (in the same multi as the attempt insert).
  - `error_class :string` — one of `"temporary" | "permanent" | "bounced"` for `:failed | :rejected | :bounced` outcomes; null for `:succeeded`.
  Migration is additive (nullable columns + backfill of existing rows where derivable). `DeliveryAttempt` schema and changeset get the new fields. `Executor.classify/1` plumbs `error_class` into `Deliveries.record_attempt/...`. `Traces.last_attempt_summary` (and any explainability surface) exposes both fields.
- **D-08:** Do NOT encode `error_class` or `attempt_number` inside `provider_response` JSON. Operators and traces must be able to query these fields directly.

### Terminal-state durability (REL-03)

- **D-09:** Promote `Chimeway.Deliveries.terminal_states/0` (deliveries.ex:21) as the single source of truth. Replace the duplicated `@terminal_states` lists in `lib/chimeway/dispatch/sync.ex:25` and `lib/chimeway/dispatch/oban_worker.ex:38` with calls to the helper. Do NOT delete the helper — it is the right anchor and the v1.0 audit's orphan finding is resolved by promotion, not removal.
- **D-10:** Close the "`:failed` is not terminal" gap. Today `@allowed_transitions` permits `failed → dispatched`, which means a delivery whose adapter returned `:temporary` lands in `:failed` and stays there forever once Oban exhausts retries — operators have no durable "this is final" marker. Add an explicit terminal write triggered when Oban exhausts retries: prefer reusing `:cancelled` with a new `suppression_reason` (e.g. `"retries_exhausted"`) and adding `failed → cancelled` to `@allowed_transitions`. The new transition must be guarded so it can only fire from the Oban exhaustion hook, not from arbitrary callers.
- **D-11:** Wire the exhausted-retries write through the canonical Oban callback (per the planner's research — `c:Oban.Worker.exhausted/1` or equivalent; see Needs External Research below). The write executes within the same transactional discipline established in Phase 12: a single multi for state transition + (optional) final attempt log if not already written.
- **D-12:** Every delivery must converge to a state in `Deliveries.terminal_states/0` after Phase 14. Add regression tests covering each terminal path: `:succeeded` (success), `:cancelled` with reason `"retries_exhausted"` (Oban gave up), `:cancelled` with permanent/bounced reason (adapter said don't retry), `:suppressed` (policy), and `:cancelled` (manual). The tests must assert `Deliveries.terminal_states/0` membership, not hardcoded lists.

### Test rewrites and regressions

- **D-13:** Rewrite `test/chimeway/dispatch/oban_worker_test.exs:109-149` so it asserts real Oban-driven retry. The current test (which calls `perform_job/2` manually after swapping the adapter) must become a true Oban retry assertion using `Oban.Testing.assert_enqueued/1` semantics or the equivalent for the project's Oban testing setup.
- **D-14:** Add concurrency regression tests for REL-01 alongside the existing `test/chimeway/idempotency_constraint_test.exs`: concurrent re-fires of the same trigger; concurrent `plan_notifications/2` calls for the same event; concurrent dispatch re-entry against an already-terminal delivery. None must produce duplicate rows or extra attempts.
- **D-15:** Phase 14 must not regress Phase 10 correlation enrichment, Phase 11 string-channel safety, or Phase 12 transactional dispatch atomicity — all three lifecycle and trace assertions must continue to pass.

### Claude's Discretion

- Whether `perform/1` returns `{:error, reason}` (let Oban use its built-in `c:Worker.backoff/1` exponential schedule) vs `{:snooze, computed_seconds}` (custom curve reading `job.attempt`). Pick whichever the researcher confirms aligns with Oban's documented contract; default to `{:error, reason}` unless backoff tuning is justified.
- Exact name of the new `error_class` enum representation (string column with whitelist vs Postgres enum vs Ecto.Enum) — pick the project-idiomatic shape; persisted values must remain `"temporary" | "permanent" | "bounced"`.
- Whether to add a new status atom (e.g. `:exhausted`) instead of reusing `:cancelled` with `suppression_reason: "retries_exhausted"`. Reuse `:cancelled` unless the researcher surfaces a strong reason — it minimizes enum churn and keeps `Deliveries.terminal_states/0` stable. If a new status is added, all three modules (`deliveries.ex`, `sync.ex`, `oban_worker.ex`) and trace surfaces must be updated coherently.
- Migration backfill strategy for `attempt_number` on existing rows — `row_number() over (partition by delivery_id order by inserted_at)` is the obvious fill; pick the cheapest correct form. `error_class` may be left null on historical rows if it cannot be derived from existing data.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract and requirements
- `.planning/ROADMAP.md` — Phase 14 goal and success criteria (lines 37-46).
- `.planning/REQUIREMENTS.md` — REL-01, REL-02, REL-03 (lines 21-23) and traceability table.
- `.planning/PROJECT.md` — Local-first, explainability, and adapter-seam constraints.

### Audit evidence driving this phase
- `.planning/v1.0-MILESTONE-AUDIT.md` — `Chimeway.Deliveries.terminal_states/0` orphan finding (lines 13-19, 99, 120). Phase 14 closes this finding by promotion.

### Prior locked context that Phase 14 must preserve
- `.planning/phases/12-oban-transactional-dispatch-consistency/12-CONTEXT.md` — Locks the multi-wrapped enqueue, tuple step names, and `on_conflict: :nothing` planning idempotency. Phase 14 must not regress these.
- `.planning/phases/11-channel-adapter-safety-and-explainability-hardening/11-CONTEXT.md` — Locks string-safe channel handling and the shared `Executor.run_delivery/1` seam used by sync and Oban paths.
- `.planning/phases/10-telemetry-correlation-enrichment/` — Correlation identifier plumbing (`notification_key`, `event_id`, `correlation_id`) through dispatch/telemetry; new retry telemetry must keep this intact.

### Current implementation surfaces
- `lib/chimeway/adapter.ex` (lines 26-31) — Adapter return contract `{:ok, meta} | {:error, :temporary | :permanent | :bounced, detail}`. The pivot point for retry classification.
- `lib/chimeway/deliveries.ex` (lines 15, 21, 23-27, 107-118, 163-213) — `@terminal_states`, `@allowed_transitions`, `transition_status/2`, `record_attempt/2`. The state machine extended in D-09/D-10.
- `lib/chimeway/delivery.ex` — Delivery schema (status enum, suppression_reason, metadata).
- `lib/chimeway/delivery_attempt.ex` (lines 15-19) — Outcome enum and attempt fields; extended in D-07.
- `lib/chimeway/delivery_planning.ex` (lines 85-94) — `plan_notifications/2` per-channel `plan_delivery` calls; re-entry contract verified in D-02.
- `lib/chimeway/dispatch/executor.ex` (lines 13-33) — `classify/1` collapses `:temporary → :failed` today; D-05 preserves the class.
- `lib/chimeway/dispatch/oban_worker.ex` (lines 29-32, 38, 41-86) — `max_attempts: 5` config and `perform/1` return-value contract; D-04/D-09/D-11 land here.
- `lib/chimeway/dispatch/sync.ex` (line 25) — Duplicate `@terminal_states` list; replaced by D-09.
- `lib/chimeway/traces.ex` (lines 148-153) — `last_attempt_summary`; surfaces new fields per D-07.
- `lib/chimeway/trigger.ex` (lines 172-185, 275-305) — `{:duplicate, event}` short-circuit; contract pinned by D-03.

### Migrations affected
- `priv/repo/migrations/20260424023200_create_chimeway_events.exs` — existing event idempotency uniqueness (no change required).
- `priv/repo/migrations/20260424023201_create_chimeway_notifications.exs` — existing per-recipient uniqueness (no change required).
- `priv/repo/migrations/20260424082834_create_chimeway_delivery_attempts.exs` — base attempts table; new migration in D-07 adds `attempt_number` and `error_class` (additive).

### Tests
- `test/chimeway/idempotency_constraint_test.exs` — Existing concurrent dedup proof; extended by D-14.
- `test/chimeway/trigger_pipeline_test.exs` (lines 191-218) — Verifies duplicate trigger bypasses dispatch invocation; pin via D-02/D-03.
- `test/chimeway/dispatch/oban_worker_test.exs` (lines 109-149) — Currently proves Oban retries are inert; rewritten by D-13.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Deliveries.terminal_states/0` — orphan helper that becomes Phase 14's source of truth (D-09).
- `Chimeway.Adapter` `:temporary | :permanent | :bounced` classification (`adapter.ex:26-31`) — already exists; needs to flow through executor and persist on attempts.
- `Chimeway.Dispatch.Executor.run_delivery/1` — shared sync/Oban seam established in Phase 11; new behavior threads through here without forking paths.
- `Ecto.Multi`-backed transactional dispatch from Phase 12 — extend, don't fork.
- `Chimeway.Deliveries.transition_status/2` and `@allowed_transitions` — state machine extension point for D-10.
- `chimeway_delivery_attempts` table with one-row-per-attempt contract — preserved as-is for retry history.

### Established Patterns
- One `DeliveryAttempt` row per adapter call (immutable history).
- Channel identifiers stay as strings; no atom creation from runtime values.
- Sync and Oban dispatch converge through `Executor.run_delivery/1`; new retry semantics must hold for both, even though only Oban exercises Oban-managed retry.
- Planning + enqueue are atomic via `Ecto.Multi` (Phase 12); terminal-state writes follow the same transactional discipline.
- `on_conflict: :nothing` for idempotent inserts where re-entry is expected.
- Telemetry spans carry `notification_key`, `event_id`, `correlation_id` (Phase 10) — new retry/exhaustion spans must keep this metadata.

### The Defects (concrete files, lines)
- `lib/chimeway/dispatch/executor.ex:30-33` — `classify/1` discards the `:temporary` distinction by mapping to `:failed`, breaking retry classification.
- `lib/chimeway/dispatch/oban_worker.ex:62-86` — `perform/1` returns `:ok` even on `:temporary` failures, so `max_attempts: 5` never fires.
- `lib/chimeway/deliveries.ex:23-27` — `failed → dispatched` transition allowed, no terminal failure state for "Oban gave up."
- `lib/chimeway/dispatch/sync.ex:25` and `lib/chimeway/dispatch/oban_worker.ex:38` — duplicated terminal-state lists shadow `Deliveries.terminal_states/0`.
- `lib/chimeway/delivery_attempt.ex:15-19` — schema lacks `attempt_number` and `error_class`, so `Traces.last_attempt_summary` (`traces.ex:148-153`) can't explain "why failed and is it retryable?"

### Integration Points
- Adapter classification → executor → attempt row → trace explanation: one chain that must preserve the `:temporary | :permanent | :bounced` distinction without losing it at any hop.
- Worker `perform/1` return value → Oban backoff scheduler → next worker call → next attempt row: the retry feedback loop being completed in Phase 14.
- `terminal_states/0` → sync dispatch guard, Oban dispatch guard, trace explanation: single source of truth replaces three lists.
</code_context>

<specifics>
## Specific Ideas

- The Phase 12 multi-based dispatch and Phase 11 string-safe executor are the spine — Phase 14 extends them, never forks them.
- Reuse `:cancelled` with `suppression_reason: "retries_exhausted"` instead of inventing a new status atom unless the researcher finds a strong reason otherwise. Stable enums help operator tooling.
- `attempt_number` should be computed at insert time inside the same multi as the attempt insert, not at read time, so traces and telemetry can sort and report deterministically.
- The "`{:duplicate, event}` does not re-drive dispatch" contract must be made explicit in module docs and trace output — silent inertness is the bug Phase 14 prevents from drifting.
</specifics>

<deferred>
## Deferred Ideas

- Self-healing dispatch on `{:duplicate, event}` (resume pending deliveries after crash between event-insert and enqueue) — D-03 explicitly defers this; belongs in a future operability/recovery phase, not Phase 14.
- Host-app surfaces for manual retry orchestration / re-enqueueing terminal-failed deliveries — out of scope; Phase 14 only covers Oban-managed retry. INT-* phase territory.
- Hierarchical retry policies per-channel or per-category (different backoff curves for SMS vs email) — out of scope; Phase 14 uses one Oban backoff schedule.
- Replacing the `:failed` non-terminal status with a richer state model (e.g., `:retrying`, `:exhausted`, `:bounced` as first-class statuses) — D-10 chooses the minimal change (reuse `:cancelled` + suppression_reason). A richer state machine can come in a later observability/operability phase if needed.
- Metrics dashboards for retry counts, exhaustion rates, error_class distribution — Phase 15 (Observability & Supportability).
</deferred>

---

*Phase: 14-delivery-reliability-hardening*
*Context gathered: 2026-04-26*

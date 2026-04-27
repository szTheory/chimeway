# Phase 12: oban-transactional-dispatch-consistency - Context

**Gathered:** 2026-04-24 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Guarantee that the optional Oban dispatch path plans delivery rows and enqueues Oban jobs inside a single atomic database transaction, so no orphaned pending rows can be left behind if enqueue fails. Also fix the atom-creation safety defect in multi step naming. This phase does not add new dispatch modes, channels, or business logic.
</domain>

<decisions>
## Implementation Decisions

### Atom safety in multi step names
- **D-01:** Replace `String.to_atom("enqueue_delivery_#{delivery.id}")` in `enqueue_deliveries/2` with tuple-keyed step names. Use `{:enqueue_delivery, idx}` where `idx` is the enumeration index. Ecto.Multi accepts any Elixir term as a step name — no atom creation from runtime strings is required.

### Transactional atomicity: planning + enqueue in one operation
- **D-02:** Restructure `Chimeway.Dispatch.Oban.dispatch/2` so both delivery planning inserts and Oban job enqueue happen inside a single `Ecto.Multi`-backed transaction. Use two `Ecto.Multi.run/3` steps in sequence: the first runs `DeliveryPlanning.plan_notifications/2` (its `Repo.insert` calls run inside the transaction connection), the second iterates pending deliveries and calls `Oban.insert/2` for each. Because both steps share the same checked-out connection, a failure in either step rolls back both planning rows and any partially-enqueued jobs.
- **D-03:** When a caller provides a `:multi` option, merge it as the base of the combined multi (prepend caller steps, then planning step, then enqueue step), preserving the existing caller-composable contract.

### Caller-visible error surface
- **D-04:** Map multi failure step names to the existing error shape convention: `:plan_notifications` step failure returns `{:error, {:planning_failed, reason}}`; enqueue step failure returns `{:error, reason}`. Callers must not receive raw Ecto.Multi step failure tuples.

### Non-multi (direct) dispatch path
- **D-05:** The existing non-multi code path (no `:multi` opt) also has the planning-before-enqueue atomicity gap. Fold it into the same multi-based implementation using `Ecto.Multi.new()` as the base — eliminating the two-branch implementation and closing the non-multi atomicity gap at the same time.

### Scope boundary
- **D-06:** Do not refactor `DeliveryPlanning.plan_notifications/2` to return a multi — using `Ecto.Multi.run/3` in the dispatcher wraps the existing function without changing its contract. This keeps Phase 12 scoped to the Oban dispatcher layer only.

### Regression coverage
- **D-07:** Update `oban_transactional_test.exs` to include a rollback-path test that asserts planning rows are also absent after transaction rollback (not just Oban jobs). The existing test using `create_pending_delivery()` pre-creates rows and bypasses the gap — add a complementary test that triggers planning from scratch and asserts complete rollback.
- **D-08:** Add a failure-path test that triggers an enqueue step failure after successful planning and asserts no `pending` delivery rows remain (i.e., planning rows were rolled back too).

### AI Discretion
- Whether to use `Oban.insert/2` inside `Ecto.Multi.run` callbacks or retain `Oban.insert/3` for each job — both are valid; prefer whichever keeps the multi pipeline readable.
- Exact error-step name atoms (`:plan_notifications`, `:enqueue_jobs`) are implementation choices as long as the public error shape matches D-04.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract and requirements
- `.planning/ROADMAP.md` — Phase 12 goal, scope, and success criteria.
- `.planning/REQUIREMENTS.md` — Requirement mapping for `INTG-03` and `DLVR-04`.
- `.planning/PROJECT.md` — Core constraints around local-first operation and explainability.

### Audit evidence driving this phase
- `.planning/v1.0-MILESTONE-AUDIT.md` — "Oban planning path → transactional persistence guarantees" gap (high severity, INTG-03, DLVR-04).
- `.planning/phases/07-delayed-fallback-runtime-wiring/07-REVIEW.md` — Prior review noting atom-table growth and planning/enqueue consistency risks.

### Prior locked context
- `.planning/phases/06-delivery-planning-and-policy-checkpoint-repair/06-CONTEXT.md` — Established planning fanout contract and sync/Oban dispatch parity shape.
- `.planning/phases/11-channel-adapter-safety-and-explainability-hardening/11-CONTEXT.md` — D-05 deferred Oban enqueue atom naming to this phase.

### Current implementation surfaces
- `lib/chimeway/dispatch/oban.ex` — The target file: `dispatch/2`, `enqueue_deliveries/2` (multi path has atom creation + planning-before-transaction gap), non-multi path shares the gap.
- `lib/chimeway/delivery_planning.ex` — `plan_notifications/2` — called by dispatcher; its `Repo.insert` calls will run inside the multi transaction when wrapped in `Ecto.Multi.run`.
- `lib/chimeway/deliveries.ex` — `plan_delivery/3` — uses `Repo.insert(on_conflict: :nothing)` for idempotent row creation.
- `test/chimeway/dispatch/oban_transactional_test.exs` — Existing transactional tests; extend for planning-level rollback coverage.
</canonical_refs>

<code_context>
## Existing Code Insights

### The Defect (oban.ex lines 65-76)
The multi path calls `plan_notifications` before building the multi, then runs `Repo.transaction(multi_with_jobs)`. Planning rows are already persisted when the transaction starts — a transaction failure cannot roll them back.

### The Atom Risk (oban.ex line 68)
`String.to_atom("enqueue_delivery_#{delivery.id}")` — delivery IDs are database-generated values. Each unique ID creates a new atom. In high-volume dispatch this exhausts the atom table over time.

### Reusable Assets
- `Ecto.Multi.run/3`: accepts any Elixir term as step name; wraps arbitrary Repo-calling code inside the transaction boundary.
- `DeliveryPlanning.plan_notifications/2`: safe to call inside `Ecto.Multi.run` — its internal `Repo.insert` calls will use the checked-out connection.
- `Oban.insert/2`: can be called inside a transaction (uses checked-out connection); `Oban.insert/3` form adds a job as a named multi step.
- `oban_transactional_test.exs`: already uses `Oban.Testing` and `DataCase`; extend rather than replace.

### Established Patterns
- Dispatcher returns `{:ok, deliveries}` on success, `{:error, {:planning_failed, reason}}` on planning failure, `{:error, reason}` on enqueue failure.
- Sync and Oban dispatch both route delivery execution through `Chimeway.Dispatch.Executor.run_delivery/1`.
- `on_conflict: :nothing` in `plan_delivery` makes planning idempotent — safe to retry without creating duplicate rows.
</code_context>

<specifics>
## Specific Ideas

- Merge non-multi and multi paths into one implementation using `base_multi = Keyword.get(opts, :multi, Ecto.Multi.new())`. This eliminates duplicated logic and closes the atomicity gap for both paths simultaneously.
- `{:enqueue_delivery, idx}` tuple step names are safe, readable, and unique within a single dispatch call even if the same delivery.id appears in different runs.
- The rollback-path test should use a forced-failure `Ecto.Multi.run` step appended AFTER the enqueue step so planning rows are inserted and then rolled back, proving the atomicity guarantee.
</specifics>

<deferred>
## Deferred Ideas

- Refactoring `DeliveryPlanning.plan_notifications/2` to return an `Ecto.Multi` natively — unnecessary given `Ecto.Multi.run` wrapping in the dispatcher.
- Caller-visible async outcome metadata beyond the existing `{:ok, deliveries}` / `{:error, reason}` shape — belongs in Phase 8 (trigger dispatch outcome surfacing) scope.
</deferred>

---

*Phase: 12-oban-transactional-dispatch-consistency*
*Context gathered: 2026-04-24*

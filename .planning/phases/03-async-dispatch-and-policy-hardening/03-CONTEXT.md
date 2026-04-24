# Phase 3: Async Dispatch and Policy Hardening - Context

**Gathered:** 2026-04-23
**Status:** Ready for planning
**Source:** AI self-discuss (headless mode)

## Phase Boundary

Deliver an optional Oban-backed dispatch path and a dual-checkpoint policy engine (planning time + perform time). Phase 3 does not add new channel adapters or change the in-app inbox API — it hardens the execution path that Phase 2 established. The dispatcher seam and policy evaluation are the two deliverables; everything else (telemetry, operator UI) defers to Phase 4.

## Implementation Decisions

### Dispatcher Config Resolution

- **D-01:** Resolve the dispatcher at call time via `Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)` — not as a compile-time module attribute. — Rationale: test configs can override the dispatcher without recompilation; ExUnit's per-test `Application.put_env` works cleanly.

### Policy Function Interface

- **D-02:** Use a single `Chimeway.Policy.evaluate/2` entry point with a keyword opts list rather than two named functions (`evaluate_at_plan/2` and `evaluate_at_perform/2`). The `check_read_state:` option (boolean, default `false`) activates the in-app read check. — Rationale: one decision surface is easier to document and audit; the opts list is extensible without a new public function.
- **D-03:** `evaluate/2` returns `{:ok, :proceed}` or `{:suppress, reason_atom}` where `reason_atom` is a plain atom (`:channel_disabled`, `:already_read`). No nested maps in the return tuple. — Rationale: keeps pattern matching simple at the two call sites; structured context for tracing/logging can be derived from the delivery struct already in scope.

### Oban Optional Dependency Guard

- **D-04:** Wrap `Chimeway.Dispatch.Oban` and `Chimeway.Dispatch.ObanWorker` module bodies with `if Code.ensure_loaded?(Oban)` at the top of each file — the entire `defmodule` block is inside the conditional. The files themselves always exist (no absent files at compile time), but the modules are only defined when Oban is loaded. — Rationale: this is the idiomatic Elixir pattern for optional library integrations; avoids `@compile_if` macros or Mix compile-time flags.

### Terminal State Definition (Idempotency Guard)

- **D-05:** The Oban worker considers a delivery terminal (skip and return `:ok`) when its status is one of `[:succeeded, :suppressed, :cancelled]`. The `failed` status is NOT terminal — it remains retryable. — Rationale: suppressed deliveries are intentional final states that must not be re-attempted; failed deliveries may succeed on retry.

### `suppression_reason` Persistence Shape

- **D-06:** Persist `suppression_reason` as a plain string atom name in the DB column (e.g., `"channel_disabled"`, `"already_read"`). Do not encode structured maps or JSON in the column. — Rationale: the column is a filter/display field for operator queries and support debugging; a plain string is directly queryable via `WHERE suppression_reason = 'already_read'` without JSON extraction.

### Policy Extensibility

- **D-07:** `Chimeway.Policy` is NOT a behaviour or plugin system in Phase 3. It is a plain module with focused logic. An optional `policy_module` config key is reserved and documented in `@moduledoc` as the extension point for custom host-app policy (quiet hours, rate limits), but no dispatch to it occurs in Phase 3. — Rationale: YAGNI — build the hook when a use case requires it; document the seam so Phase 4/5 can wire it without rework.

### `delay_fallback` and the Notification Association

- **D-08:** The `delay_fallback: true` flag on a delivery row triggers the read-state check at perform time. To perform this check, `ObanWorker.perform/1` must load the associated `notify_notifications` row for the same `(recipient_id, notification_key)`. This lookup is scoped by `notification_id` on the delivery row (added in Phase 2 schema). If no notification row exists, treat read state as nil (not read) and proceed with delivery. — Rationale: avoids a broad query; notification association is already first-class from Phase 1.

### AI Discretion

- Exact Oban queue name and `max_attempts` value — plans specify `:chimeway_delivery` / 5; keeping as-is.
- Whether `Chimeway.Policy` and `Chimeway.Preferences` are co-located in one context module or remain separate — keep separate as planned; they have different schemas and public surfaces.
- Migration timestamp conventions — follow Phase 1/2 patterns in the existing `priv/repo/migrations/` directory.

## Existing Code Insights

### Reusable Assets

- `Chimeway.Preferences.channel_enabled?/3` (to be built in 03-02): called from both planning-time and perform-time policy evaluation — keep signature stable from first use.
- `notify_notifications` `read_at` timestamp (Phase 1): the only field needed for `delay_fallback` check — no schema changes to `notify_notifications` required this phase.
- Phase 2 `Ecto.Multi` delivery-creation pipeline: the transactional enqueue hook attaches to the existing `Multi` at the delivery-dispatch step.

### Established Patterns

- Behaviour-first contracts (Phase 1 `D-03`): `Chimeway.Dispatch` follows the same pattern as the Phase 1 notifier contract — explicit callback, thin optional wrapper.
- Explicit over magic (Phase 1 `D-04`): both Sync and Oban dispatchers must have documented `@moduledoc` with config examples.
- No module names as data: delivery args in Oban jobs contain only `delivery_id` (UUID) — never a module name or serialized struct.

## Specific Ideas

- Test the `delay_fallback` path using `Oban.Testing` (sandbox mode) — set `read_at` on the notification row before calling `perform/1` directly in tests.
- For the transactional enqueue test (rollback prevents job), use `Ecto.Multi` with a forced error step after the enqueue to confirm the job does not appear in `Oban.all_enqueued/1`.
- `Chimeway.Policy.evaluate/2` should log a structured debug message (via `Logger.debug`) on suppress decisions — gives operator visibility before Phase 4 adds telemetry.

## Deferred Ideas

- Custom `policy_module` dispatch hook — documented in `Chimeway.Policy` `@moduledoc` but not implemented until a concrete use case (quiet hours, caps) lands in a later phase.
- Telemetry spans for dispatch and policy events — Phase 4 scope.
- Digest/batching semantics for `delay_fallback` across multiple notifications — out of scope for v1.

---

*Phase: 03-async-dispatch-and-policy-hardening*
*Context gathered: 2026-04-23*

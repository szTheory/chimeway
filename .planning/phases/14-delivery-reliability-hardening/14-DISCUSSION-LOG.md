# Phase 14: delivery-reliability-hardening - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-04-26
**Phase:** 14-delivery-reliability-hardening
**Mode:** assumptions
**Areas analyzed:** Duplicate protection (REL-01), Oban retry mechanics (REL-02), Attempt history schema (REL-02), Terminal-state durability (REL-03)

## Assumptions Presented

### A1 — Duplicate protection (REL-01)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Existing unique constraints + `on_conflict: :nothing` already satisfy REL-01; Phase 14 only locks the contract with explicit tests and decides whether `{:duplicate, event}` should re-drive dispatch. | Confident | `events/event.ex:34`, `notifications/notification.ex:36-38`, `deliveries.ex:66`, `trigger.ex:172-185, 275-305`, `test/chimeway/idempotency_constraint_test.exs:49-74`, `test/chimeway/trigger_pipeline_test.exs:191-218`. |

Open question raised: should `Trigger.dispatch_after_trigger/4` fire on `{:duplicate, event}` to recover from crashes between event-insert and enqueue?

### A2 — Oban retry mechanics (REL-02, central change)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `max_attempts: 5` is dead config — `perform/1` returns `:ok` even on `:temporary` adapter failures. Phase 14 makes the worker return `{:error, _}` (or `{:snooze, n}`) on `:temporary` so Oban actually retries, while keeping `:ok` for `:permanent | :bounced`. | Confident | `oban_worker.ex:29-32, 62-86`, `executor.ex:13-33`, `adapter.ex:26-31`, `oban_worker_test.exs:109-149` (smoking-gun test). |

### A3 — Attempt history schema (REL-02)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add `attempt_number :integer` and `error_class :string` columns to `chimeway_delivery_attempts`; plumb `error_class` through `Executor.classify/1`; surface both in `Traces.last_attempt_summary`. Avoid encoding either inside `provider_response` JSON. | Likely | `delivery_attempt.ex:15-19`, `priv/repo/migrations/20260424082834_create_chimeway_delivery_attempts.exs`, `executor.ex:30-33`, `traces.ex:148-153`. |

Alternative considered: encode in `provider_response` JSON — rejected because it loses queryability and ties retry-history fidelity to per-adapter response shape.

### A4 — Terminal-state durability (REL-03)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Promote `Chimeway.Deliveries.terminal_states/0` (orphan) as the single source of truth and add a terminal-failure transition for "Oban exhausted retries." Prefer reusing `:cancelled` with `suppression_reason: "retries_exhausted"` over a new status atom; allow `failed → cancelled` only from the Oban exhaustion hook. | Likely | `deliveries.ex:15, 21, 23-27`, `dispatch/sync.ex:25`, `dispatch/oban_worker.ex:38`, `.planning/v1.0-MILESTONE-AUDIT.md:13-19, 99, 120`, `oban_worker_test.exs:113-125`. |

Alternative considered: leave the enum unchanged and mark terminality via `metadata["final"] = true` — rejected because it creates two ways to mean "terminal" and reintroduces the duplication the orphan helper is meant to prevent.

## Corrections Made

No corrections — user accepted all four assumptions ("Yes, proceed").

## Auto-Resolved

Not applicable — interactive confirmation, no auto mode.

## External Research

Two topics explicitly handed to research/planner downstream (also captured in CONTEXT.md):

- **Oban `perform/1` return-value contract.** Confirm canonical mapping of `:ok | {:error, _} | {:snooze, n} | {:cancel, _} | {:discard, _}` to retry / backoff / exhaust behavior. Confirm: (a) does `{:error, _}` on the last allowed attempt mark the job `discarded` or `retryable`? (b) is there a `c:Oban.Worker.exhausted/1` callback (or equivalent) to hook for the terminal-failure write? (c) what is `c:Oban.Worker.backoff/1`'s default schedule and is it acceptable for production delivery retries?
- **Oban `unique: [period: 60]` semantics.** The worker uses `unique: [fields: [:args], keys: [:delivery_id], period: 60]` (`oban_worker.ex:32`). Confirm whether this prevents duplicate enqueues across the 60-second window only, and what happens at the 61st second if a host app re-enqueues for an already-`:succeeded` delivery (the terminal-state guard at `oban_worker.ex:44` covers it, but worth validating against documented semantics).

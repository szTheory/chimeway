---
phase: 3
phase_name: Async Dispatch and Policy Hardening
verified_at: 2026-04-24
status: passed
score: 4/4
---

# Phase 3 Verification

## Goal

Add optional Oban-backed async execution and enforce policy correctness across delayed paths.

## Artifact Table

| Artifact | Exists | Substantive | Wired | Status |
|----------|--------|-------------|-------|--------|
| `lib/chimeway/dispatch.ex` | YES | YES — behaviour with `@callback dispatch/2` + typespec | YES — implemented by Sync and Oban via `@behaviour Chimeway.Dispatch` | VERIFIED |
| `lib/chimeway/dispatch/sync.ex` | YES | YES — 96 lines, full pipeline with planning-time + perform-time policy checks | YES — default dispatcher, implements `@behaviour Chimeway.Dispatch`, calls `Policy.evaluate/2` at both checkpoints | VERIFIED |
| `lib/chimeway/dispatch/oban.ex` | YES | YES — 84 lines, two enqueue paths (direct + transactional multi) | YES — `@behaviour Chimeway.Dispatch`, guarded by `Code.ensure_loaded?(Oban)`, enqueues `ObanWorker` jobs | VERIFIED |
| `lib/chimeway/dispatch/oban_worker.ex` | YES | YES — 93 lines, terminal-state guard, perform-time policy check, full dispatch pipeline | YES — guarded by `Code.ensure_loaded?(Oban)`, calls `Policy.evaluate/2`, calls `Deliveries.get_delivery!` and `Deliveries.record_attempt` | VERIFIED |
| `lib/chimeway/policy.ex` | YES | YES — 102 lines, `evaluate/2` with two private check functions | YES — called in Sync at planning time (line 30) and perform time (line 56); called in ObanWorker at perform time (line 57) | VERIFIED |
| `lib/chimeway/preferences.ex` | YES | YES — 49 lines, `upsert_preference/1`, `get_preference/3`, `channel_enabled?/3` with opt-in default | YES — called by `Policy.check_preferences/1` via `Preferences.channel_enabled?/3` | VERIFIED |
| `lib/chimeway/preferences/notification_preference.ex` | YES | YES — Ecto schema with changeset, unique constraint | YES — used by `Chimeway.Preferences` context | VERIFIED |
| `lib/chimeway/deliveries.ex` (suppress_delivery/2) | YES | YES — persists `status: :suppressed`, `suppression_reason: Atom.to_string(reason)` | YES — called by both Sync and ObanWorker on `{:suppress, reason}` policy decisions | VERIFIED |
| `priv/repo/migrations/20260424091726_create_chimeway_notification_preferences.exs` | YES | YES — correct schema and unique index on `(recipient_id, notification_key, channel)` | YES — serves `Chimeway.Preferences.NotificationPreference` | VERIFIED |
| `priv/repo/migrations/20260424082833_create_chimeway_deliveries.exs` | YES | YES — `suppression_reason :string` and `delay_fallback :boolean` already present | YES — no alter migration needed; columns were in Phase 2 migration | VERIFIED |
| `priv/repo/migrations/20260424093000_create_oban_jobs_tables.exs` | YES | YES | YES — required for Oban in test env | VERIFIED |
| `guides/flows/oban-integration.md` | YES | YES — 98 lines, covers deps, queue config, dispatcher config, migrations, transactional enqueue, retry tuning, testing | YES — serves as documented integration seam per DLVR-04 / INTG-03 | VERIFIED |
| `test/chimeway/dispatch/oban_test.exs` | YES | YES — 121 lines, 6 tests under `Oban.Testing`, `@moduletag :oban` | YES — exercises `Chimeway.Dispatch.Oban` and `ObanWorker` | VERIFIED |
| `test/chimeway/dispatch/oban_worker_test.exs` | YES | YES — 127 lines, 7 tests: success, idempotency, all 3 terminal states, error, retry | YES — exercises `ObanWorker.perform/1` via `perform_job/2` | VERIFIED |
| `test/chimeway/policy/delayed_fallback_test.exs` | YES | YES — 104 lines, 5 tests covering all four delayed fallback scenarios | YES — exercises ObanWorker and Sync dispatch paths for POLC-03 compliance | VERIFIED |
| `test/chimeway/dispatch/oban_transactional_test.exs` | YES | YES — 74 lines, 4 tests: commit, rollback, duplicate dispatch idempotency, sync bypass | YES — exercises `Chimeway.Dispatch.Oban.dispatch/2` with and without `multi:` option | VERIFIED |
| `test/support/chimeway/dispatch_helpers.ex` | YES | YES — `create_pending_delivery/1` (supports `delay_fallback` option) and `mark_notification_read/1` | YES — imported by oban_worker_test, delayed_fallback_test, oban_transactional_test | VERIFIED |

## Truth Verification

### Truth 1: Oban is an optional dependency in mix.exs
**Status:** VERIFIED
**Evidence:** `mix.exs` line 34: `{:oban, "~> 2.17", optional: true}` — matches the plan requirement exactly.

### Truth 2: Both Oban modules are conditionally compiled with Code.ensure_loaded? guard
**Status:** VERIFIED
**Evidence:**
- `lib/chimeway/dispatch/oban.ex` line 1: `if Code.ensure_loaded?(Oban) do`
- `lib/chimeway/dispatch/oban_worker.ex` line 1: `if Code.ensure_loaded?(Oban) do`
Both files always exist on disk; the `defmodule` is conditionally defined.

### Truth 3: Chimeway.Dispatch.Oban satisfies @behaviour Chimeway.Dispatch; dispatch/2 enqueues one ObanWorker job per delivery
**Status:** VERIFIED
**Evidence:** `oban.ex` line 29: `@behaviour Chimeway.Dispatch`. `dispatch/2` calls `Deliveries.plan_delivery/2` per notification, then enqueues via `enqueue_one/1` which calls `Oban.insert(ObanWorker.new(%{delivery_id: delivery.id}))` — one job per delivery.

### Truth 4: ObanWorker.perform/1 loads delivery, short-circuits on terminal states, calls adapter, records attempt
**Status:** VERIFIED
**Evidence:**
- Line 40: `delivery = Deliveries.get_delivery!(delivery_id)` — loads from DB by delivery_id
- Lines 42–44: `if delivery.status in @terminal_states do :ok` — short-circuits with no adapter call
- Lines 56–67: `dispatch_delivery/1` calls `Policy.evaluate/2` then `do_dispatch/1`
- Lines 70–90: `do_dispatch/1` calls `transition_status`, `adapter.deliver`, `Deliveries.record_attempt`

### Truth 5: Job args contain only delivery_id (UUID string) — no payload, no module names
**Status:** VERIFIED
**Evidence:** All enqueue calls use `ObanWorker.new(%{delivery_id: delivery.id})`. The `perform/1` pattern match is `%Oban.Job{args: %{"delivery_id" => delivery_id}}`. No payload, metadata, or module names in args anywhere.

### Truth 6: Oban job insertion participates in the same Ecto.Multi when multi: option is passed
**Status:** VERIFIED
**Evidence:** `oban.ex` lines 60–71: `enqueue_deliveries/2` with non-nil multi accumulates jobs via `Oban.insert(acc, job_name, ObanWorker.new(...))` then commits via `Chimeway.Repo.transaction(multi_with_jobs)`. Confirmed by rollback test in `oban_transactional_test.exs`.

### Truth 7: Oban guide exists at guides/flows/oban-integration.md
**Status:** VERIFIED
**Evidence:** File exists (98 lines). Covers: adding Oban as dependency, queue config, dispatcher config, migrations, transactional enqueue pattern, retry tuning, and test sandbox setup.

### Truth 8: chimeway_notification_preferences table with correct schema and unique index
**Status:** VERIFIED
**Evidence:** Migration `20260424091726_create_chimeway_notification_preferences.exs` creates the table with all required columns and `create unique_index(..., [:recipient_id, :notification_key, :channel], name: :chimeway_notification_preferences_recipient_key_channel_index)`.

### Truth 9: Preferences.channel_enabled?/3 returns true when no preference row exists
**Status:** VERIFIED
**Evidence:** `preferences.ex` lines 43–48: `case get_preference(...) do nil -> true; pref -> pref.enabled end`. Opt-in default is explicit and correct.

### Truth 10: Policy.evaluate/2 is the single decision surface at both planning and perform time
**Status:** VERIFIED
**Evidence:**
- Planning-time (Sync): `dispatch/sync.ex:30` — `Chimeway.Policy.evaluate(delivery, [])` called after `plan_delivery`, before `dispatch_delivery/1`
- Perform-time (Sync): `dispatch/sync.ex:56` — `Chimeway.Policy.evaluate(delivery, check_read_state: delivery.delay_fallback)` inside `dispatch_delivery/1`
- Perform-time (ObanWorker): `dispatch/oban_worker.ex:57` — `Policy.evaluate(delivery, check_read_state: delivery.delay_fallback)` inside `dispatch_delivery/1`
All three call sites confirmed via code read and grep.

### Truth 11: evaluate/2 returns {:ok, :proceed} or {:suppress, plain_atom}
**Status:** VERIFIED
**Evidence:** `policy.ex` uses `with` returning `{:ok, :proceed}`, or `{:suppress, :channel_disabled}` / `{:suppress, :already_read}`. Plain atoms only, no nested maps.

### Truth 12: Delayed fallback suppresses when read_at is not nil
**Status:** VERIFIED
**Evidence:** `policy.ex` lines 83–100: `maybe_check_read_state/2` — when `read_at` is not nil, returns `{:suppress, :already_read}`. Both dispatchers set `check_read_state: delivery.delay_fallback`. End-to-end confirmed in `delayed_fallback_test.exs`.

### Truth 13: suppression_reason persisted as plain string atom name
**Status:** VERIFIED
**Evidence:** `deliveries.ex:84` — `change(status: :suppressed, suppression_reason: Atom.to_string(reason))`. Tests assert `"already_read"` and `"channel_disabled"` as plain strings on the delivery row.

### Truth 14: ObanWorker idempotency — repeated perform creates exactly one attempt row
**Status:** VERIFIED
**Evidence:** `oban_worker_test.exs` lines 44–54 — two `perform_job` calls on same delivery; asserts `length(attempts) == 1`. Second call short-circuits on terminal `:succeeded` state.

### Truth 15: Transactional rollback prevents job from being enqueued
**Status:** VERIFIED
**Evidence:** `oban_transactional_test.exs` lines 37–47 — `failing_multi` with forced error; `refute_enqueued` confirms no job visible after rollback.

## Wiring Verification

| Key Link | Status | Evidence |
|----------|--------|----------|
| `Chimeway.Dispatch.Oban` → `@behaviour Chimeway.Dispatch` | WIRED | `@behaviour Chimeway.Dispatch` at `oban.ex:29`; `@impl Chimeway.Dispatch` on `dispatch/2` |
| `Chimeway.Dispatch.Sync` → `@behaviour Chimeway.Dispatch` | WIRED | `@behaviour Chimeway.Dispatch` at `sync.ex:18`; `@impl Chimeway.Dispatch` on `dispatch/2` |
| `Chimeway.Trigger` → configurable dispatcher | WIRED | `trigger.ex:234` — `Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)` then `dispatcher.dispatch(notifications, opts)` |
| Policy evaluated at planning time (Sync) | WIRED | `sync.ex:30` — `Chimeway.Policy.evaluate(delivery, [])` before `dispatch_delivery/1` |
| Policy evaluated at perform time (Sync) | WIRED | `sync.ex:56` — `Chimeway.Policy.evaluate(delivery, check_read_state: delivery.delay_fallback)` inside `dispatch_delivery/1` |
| Policy evaluated at perform time (ObanWorker) | WIRED | `oban_worker.ex:57` — `Policy.evaluate(delivery, check_read_state: delivery.delay_fallback)` inside `dispatch_delivery/1` |
| `Policy` → `Preferences.channel_enabled?/3` | WIRED | `policy.ex:70` — `Preferences.channel_enabled?(notification.recipient_identity, event.notification_key, delivery.channel)` |
| `Policy` → `Repo.get(Notification)` for read_at | WIRED | `policy.ex:86` — fresh DB read in `maybe_check_read_state/2`; suppresses on `%{read_at: _read_at}` |
| `Deliveries.suppress_delivery/2` → `Atom.to_string` | WIRED | `deliveries.ex:84` — reason is always a known Policy atom, never user input |
| `Dispatch.Oban` → `ObanWorker` (direct) | WIRED | `oban.ex:78` — `Oban.insert(ObanWorker.new(%{delivery_id: delivery.id}))` in `enqueue_one/1` |
| `Dispatch.Oban` → `ObanWorker` (transactional multi) | WIRED | `oban.ex:64` — `Oban.insert(acc, job_name, ObanWorker.new(%{delivery_id: delivery.id}))` in `enqueue_deliveries/2` |
| ObanWorker terminal-state guard before policy check | WIRED | `oban_worker.ex:42–44` — `if delivery.status in @terminal_states do :ok` before `dispatch_delivery/1` |
| ObanWorker → `Deliveries.get_delivery!/1` | WIRED | `oban_worker.ex:40` |
| ObanWorker → `Deliveries.record_attempt/2` | WIRED | `oban_worker.ex:83–88` |

## Requirements Coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| DLVR-04 | SATISFIED | `Chimeway.Dispatch` behaviour is the documented seam. `Dispatch.Sync` is the default v1 implementation; `Dispatch.Oban` is the optional job-backed implementation, conditionally compiled behind `Code.ensure_loaded?(Oban)`. Oban is `optional: true` in `mix.exs`. ObanWorker idempotency is verified by terminal-state guard + unique job constraint + test proving two performs → one attempt row. |
| POLC-01 | SATISFIED | `chimeway_notification_preferences` table with unique index on `(recipient_id, notification_key, channel)`. `Chimeway.Preferences.channel_enabled?/3` returns `true` when no row exists (opt-in default). `upsert_preference/1` supports `enabled: false` to disable a channel. |
| POLC-02 | SATISFIED | `Policy.evaluate/2` is called at planning time (Sync `dispatch/2:30`) and at perform time in both Sync (`dispatch_delivery/1:56`) and ObanWorker (`dispatch_delivery/1:57`). Both perform-time calls re-read preferences from DB. A post-enqueue preference disable is caught at perform time and confirmed by test in `delayed_fallback_test.exs`. |
| POLC-03 | SATISFIED | `Policy.maybe_check_read_state/2` issues a fresh `Repo.get` of the notification and suppresses with `{:suppress, :already_read}` when `read_at` is not nil. Triggered when `check_read_state: true`, derived from `delivery.delay_fallback`. `delayed_fallback_test.exs` confirms: delivery status `:suppressed`, `suppression_reason == "already_read"`, zero attempt rows, adapter not called, for both Oban and sync paths. |
| INTG-03 | SATISFIED | `guides/flows/oban-integration.md` documents the optional integration seam. The `multi:` option in `Dispatch.Oban.dispatch/2` enables atomic job+delivery-row creation. `oban_transactional_test.exs` verifies rollback removes the job. Oban is `optional: true` in `mix.exs`, ensuring library consumers are not forced to pull it in. |

## Anti-patterns Found

None found. Specific checks performed:

- Grep for `TODO`, `FIXME`, `placeholder`, `stub`, `not implemented` across `lib/` returned zero matches.
- Job args contain only `delivery_id` — no payload, metadata maps, or module names.
- `Policy.ex` Logger.debug calls log only `delivery_id`, `reason` atom, and `channel` — `recipient_identity` value is not logged.
- `suppression_reason` is always derived from `Atom.to_string/1` of hardcoded atoms from Policy — never user-controlled input.
- All Oban test files use `async: false` and restore `Application.put_env` values in `on_exit` blocks.
- `Chimeway.Adapters.Test.clear()` is called in setup blocks of all Oban test files.
- The `policy_module` config key in `policy.ex` moduledoc is correctly labeled as an unimplemented extension point for future phases — this is intentional, not a stub.

## Summary

Phase 3 fully achieves its goal. All four success criteria are satisfied by real, substantive code — no stubs, no placeholders. The critical verifications:

**Dispatch seam (SC1):** `Chimeway.Dispatch` behaviour is cleanly implemented by both `Sync` and `Oban`. The Oban path is conditionally compiled and the dependency is correctly marked `optional: true`. The trigger pipeline delegates to a configurable dispatcher via `Application.get_env`.

**Dual policy checkpoints (SC2):** `Policy.evaluate/2` is confirmed called at three distinct points in code: planning-time in Sync (`sync.ex:30`), perform-time in Sync (`sync.ex:56`), and perform-time in ObanWorker (`oban_worker.ex:57`). Both perform-time calls re-read preferences from the DB — no snapshot — so a post-enqueue preference change is correctly suppressed.

**Delayed fallback suppression (SC3):** Fully implemented. `Policy.maybe_check_read_state/2` issues a fresh DB read of `notification.read_at`. `delayed_fallback_test.exs` covers all four key scenarios (unread, read, post-enqueue preference disable, sync path parity) and asserts zero attempt rows for suppressed deliveries.

**Async idempotency (SC4):** ObanWorker terminal-state guard (`@terminal_states [:succeeded, :suppressed, :cancelled]`) blocks any adapter call on repeated performs. Worker unique constraint (`keys: [:delivery_id], period: 60`) adds an Oban-layer guard. Tests confirm two `perform_job` calls produce one attempt row; retry from `:failed` produces two attempt rows and final `:succeeded`.

## Gaps

One documentation inaccuracy found (no functional gap):

**Guide overstates automatic multi injection:** `guides/flows/oban-integration.md` section 5 states "The trigger pipeline passes `multi:` automatically when `Chimeway.Dispatch.Oban` is configured." The actual `Trigger.dispatch_after_trigger/2` code passes through whatever `opts` the caller provides — it does not inject `multi:` automatically. The transactional path works correctly when callers pass `multi:` explicitly; the guide's claim is inaccurate. This is a documentation gap only and does not affect any requirement. A low-priority doc fix should correct section 5 to state that callers must pass `multi:` explicitly to `Chimeway.Trigger.trigger/3` opts, which are forwarded to `dispatcher.dispatch/2`.

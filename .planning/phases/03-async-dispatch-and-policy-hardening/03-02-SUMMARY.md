---
phase: 03-async-dispatch-and-policy-hardening
plan: "03-02"
subsystem: policy
tags: [preferences, policy, suppression, dispatch, oban]
dependency_graph:
  - lib/chimeway/preferences.ex -> lib/chimeway/policy.ex
  - lib/chimeway/policy.ex -> lib/chimeway/dispatch/sync.ex
  - lib/chimeway/policy.ex -> lib/chimeway/dispatch/oban_worker.ex
key_files:
  - priv/repo/migrations/20260424091726_create_chimeway_notification_preferences.exs
  - lib/chimeway/preferences/notification_preference.ex
  - lib/chimeway/preferences.ex
  - lib/chimeway/policy.ex
  - lib/chimeway/deliveries.ex
  - lib/chimeway/dispatch/sync.ex
  - lib/chimeway/dispatch/oban_worker.ex
  - test/chimeway/preferences_test.exs
  - test/chimeway/policy_test.exs
key_decisions:
  - Keep `Policy.evaluate/2` as the single decision entry point for planning-time and perform-time checks.
  - Persist suppression reasons as atom-name strings ("channel_disabled", "already_read") for direct DB filtering.
  - Re-read preferences at perform time in both sync and Oban paths to prevent post-enqueue policy bypass.
tech_stack: [elixir, ecto, oban]
requirements-completed: [POLC-01, POLC-02, POLC-03]
duration: ~30 min
completed_at: "2026-04-24T09:23:13Z"
---

Added recipient preference persistence and a dual-checkpoint policy engine so deliveries can be suppressed consistently at both planning time and perform time.

## Tasks

### 03-02-01: Preference storage and context ✅

- Added `chimeway_notification_preferences` migration with unique `(recipient_id, notification_key, channel)` index.
- Added `NotificationPreference` schema and `Chimeway.Preferences` context (`upsert_preference/1`, `get_preference/3`, `channel_enabled?/3`).
- Added `test/chimeway/preferences_test.exs` covering default opt-in behavior and idempotent upsert semantics.

### 03-02-02: Policy engine and planning-time suppression ✅

- Added `Chimeway.Policy.evaluate/2` with suppression outcomes `{:suppress, :channel_disabled}` and `{:suppress, :already_read}`.
- Added `Deliveries.suppress_delivery/2` to persist `status: :suppressed` and string suppression reason.
- Wired planning-time policy evaluation in `Dispatch.Sync.dispatch/2` before dispatch execution.

### 03-02-03: Perform-time policy enforcement ✅

- Wired perform-time policy checks in both `Dispatch.Sync` and `Dispatch.ObanWorker` using `check_read_state: delivery.delay_fallback`.
- Added/updated policy tests for read-state fallback and preference toggles near dispatch time.
- Verified suppression paths skip adapter calls and persist expected reason values.

## Verification

- `mix ecto.migrate`
- `mix ecto.rollback --step 1 && mix ecto.migrate`
- `mix compile --warnings-as-errors`
- `mix test test/chimeway/preferences_test.exs --seed 0`
- `mix test test/chimeway/policy_test.exs --seed 0`
- `mix test --seed 0`

## Task Commits

1. **Task 03-02-01** - `7d6911d` (`feat(03-02): add notification preference persistence`)
2. **Task 03-02-02** - `2a5441d` (`feat(03-02): add policy evaluation and suppression flow`)
3. **Task 03-02-03** - `be7b982` (`feat(03-02): enforce perform-time checks in async worker`)

## Deviations

None - plan executed as written.

## Issues Encountered

None.

## Self-Check: PASSED

- Preference storage, policy evaluation, and suppression persistence are implemented.
- Sync and Oban dispatch paths both enforce perform-time policy checks.
- Verification commands and full test suite pass.
---
phase: 03-async-dispatch-and-policy-hardening
plan: "03-02"
subsystem: policy-engine
tags: [preferences, policy, suppression, dual-checkpoint]
key_files:
  - priv/repo/migrations/20260424091726_create_chimeway_notification_preferences.exs
  - lib/chimeway/preferences/notification_preference.ex
  - lib/chimeway/preferences.ex
  - lib/chimeway/policy.ex
  - lib/chimeway/deliveries.ex
  - lib/chimeway/dispatch/sync.ex
  - lib/chimeway/dispatch/oban_worker.ex
  - test/chimeway/preferences_test.exs
  - test/chimeway/policy_test.exs
key_decisions:
  - "Policy.evaluate/2 is the single suppression surface called at both planning time (Sync.dispatch) and perform time (dispatch_delivery in Sync and ObanWorker)"
  - "Missing preference rows default to enabled (opt-in default) — no preference row = channel active"
  - "suppression_reason is always derived from known atoms via Atom.to_string/1 — never from user input"
  - "Logger.debug in Policy logs only delivery_id, reason atom, channel — no recipient_identity or payload"
duration: ~12 min
completed_at: "2026-04-24T05:21:00Z"
---

# 03-02 Summary: Preference Storage and Dual-Checkpoint Policy Engine

Introduced the chimeway_notification_preferences table, Chimeway.Preferences context, and Chimeway.Policy.evaluate/2 — then wired evaluate/2 at planning time (in Dispatch.Sync.dispatch/2 before adapter call) and at perform time (in both Dispatch.Sync.dispatch_delivery/1 and ObanWorker.dispatch_delivery/1). Suppressed deliveries are persisted with status :suppressed and suppression_reason as a plain atom string.

## Task Completions

### 03-02-01: Migration, Schema, Preferences Context, Tests
- Migration `20260424091726_create_chimeway_notification_preferences` creates table with unique index on `(recipient_id, notification_key, channel)`. Round-trip (rollback + re-apply) verified clean.
- `Chimeway.Preferences.NotificationPreference` Ecto schema implemented.
- `Chimeway.Preferences` context with `upsert_preference/1`, `get_preference/3`, `channel_enabled?/3` (defaults to `true` on missing row).
- 5 tests in `preferences_test.exs` — all pass.

### 03-02-02: Policy Module + Planning-Time Check in Dispatch.Sync
- `Chimeway.Policy.evaluate/2` implemented with `check_preferences/1` and `maybe_check_read_state/2`.
- `Chimeway.Deliveries.suppress_delivery/2` added — persists `:suppressed` status and `Atom.to_string(reason)`.
- Planning-time check wired in `Dispatch.Sync.dispatch/2`: after `plan_delivery`, calls `Policy.evaluate(delivery, [])` before proceeding to `dispatch_delivery`.

### 03-02-03: Perform-Time Policy + ObanWorker Wiring + Policy Tests
- `Dispatch.Sync.dispatch_delivery/1` refactored to call `Policy.evaluate(delivery, check_read_state: delivery.delay_fallback)` before adapter dispatch.
- `ObanWorker.dispatch_delivery/1` same pattern applied.
- 7 tests in `policy_test.exs` covering all suppression scenarios — all pass.

## Verification Results

- `mix ecto.migrate` — ✅ table created
- `mix ecto.rollback --step 2 && mix ecto.migrate` — ✅ round-trip clean
- `rg "suppression_reason|delay_fallback" chimeway_deliveries migration` — ✅ already present from Phase 2
- `rg "def channel_enabled?"` — ✅
- `rg "def evaluate"` — ✅
- `rg "Policy.evaluate" sync.ex oban_worker.ex` — ✅ both paths wired
- `mix compile --warnings-as-errors` — ✅ no warnings
- `mix test test/chimeway/preferences_test.exs` — ✅ 5 tests pass
- `mix test test/chimeway/policy_test.exs` — ✅ 7 tests pass
- `mix test` — ✅ 83 tests, 0 failures

## Security Gate (ASVS L1)

- TM-03-02-PII-IN-POLICY-LOG: ✅ PASS — Logger.debug logs only `delivery_id`, `reason`, `channel`; no `recipient_identity` or payload
- TM-03-02-SUPPRESSION-BYPASS: ✅ PASS — `Policy.evaluate/2` called at perform time in both Dispatch.Sync and ObanWorker
- TM-03-02-SUPPRESSION-REASON-INJECTION: ✅ PASS — `suppress_delivery/2` guarded with `when is_atom(reason)`; reason always from known internal atoms

## Deviations

None. Implementation followed the plan exactly.

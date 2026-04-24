---
plan: 03-02
phase: 3
title: Implement Preference Model and Policy Engine with Dual Evaluation Checkpoints
status: not_started
requirements: [POLC-01, POLC-02, POLC-03]
depends_on: [03-01]
---

# Plan 03-02: Implement Preference Model and Policy Engine with Dual Evaluation Checkpoints

## Goal
Introduce a `NotificationPreference` schema that lets applications configure per-channel suppression per recipient/key, and a `Chimeway.Policy` module that enforces preferences at both planning time and perform time — including checking in-app read state for delayed fallback suppression.

## Context
After 03-01, the dispatch path flows through a `Chimeway.Dispatch` behaviour and delivery rows exist in `notify_deliveries`. The trigger pipeline builds `Ecto.Multi` transactions that create delivery rows. `notify_notifications` has `read_at`, `seen_at`, and `archived_at` timestamps from Phase 1. There is no preference storage, no policy module, and suppression reasons are not persisted. This plan adds the preference table, the policy engine, and hooks at two points: (1) during delivery planning in the trigger pipeline, and (2) inside `Chimeway.Dispatch.ObanWorker.perform/1` (and `Chimeway.Dispatch.Sync.dispatch/2`) before the adapter is called.

## Tasks

### Task 1: Add NotificationPreference Schema and Migration
**What**: Create the `chimeway_notification_preferences` table with columns: `id` (UUID PK), `recipient_id` (string, not null), `notification_key` (string, not null), `channel` (string, not null), `enabled` (boolean, not null, default true), `inserted_at`, `updated_at`. Add a unique index on `(recipient_id, notification_key, channel)`. Create the `Chimeway.Preferences.NotificationPreference` Ecto schema mapping to this table. Create `Chimeway.Preferences` as the public context module with: `upsert_preference/1`, `get_preference/3` (recipient_id, notification_key, channel), and `channel_enabled?/3` (returns boolean, defaulting to `true` when no row exists).

**Where**:
- `lib/chimeway/preferences/notification_preference.ex` — Ecto schema with `schema "chimeway_notification_preferences"`, changeset with required fields, `@type t :: %__MODULE__{}`
- `lib/chimeway/preferences.ex` — public context: `upsert_preference/1`, `get_preference/3`, `channel_enabled?/3`
- `priv/repo/migrations/<timestamp>_create_chimeway_notification_preferences.exs` — migration with table, unique index, and timestamps

**Acceptance criteria**:
- [ ] Migration runs with `mix ecto.migrate` and rolls back cleanly
- [ ] Unique index on `(recipient_id, notification_key, channel)` is present
- [ ] `Chimeway.Preferences.channel_enabled?/3` returns `true` when no preference row exists (opt-in default)
- [ ] `upsert_preference/1` with `enabled: false` followed by `channel_enabled?/3` returns `false`
- [ ] Unit tests cover upsert, lookup, and missing-row default behavior

**Done when**: Preference rows can be created and queried, and missing-row lookups default to enabled.

---

### Task 2: Implement Chimeway.Policy and Planning-Time Evaluation
**What**: Create `Chimeway.Policy` with a single public function `evaluate/2` that accepts a `%Chimeway.Delivery{}` (or a delivery plan struct produced during fanout) and a keyword opts list, and returns `{:ok, :proceed} | {:suppress, reason_atom}` where `reason_atom` is a plain atom (e.g. `:channel_disabled`, `:already_read`). No nested maps in the return tuple. The planning-time check must call `Chimeway.Preferences.channel_enabled?(recipient_id, notification_key, channel)`. When `evaluate/2` returns `{:suppress, reason_atom}`, the delivery row should be created with `status: :suppressed` and `suppression_reason` persisted as the string atom name (e.g. `"channel_disabled"`) on the `notify_deliveries` schema as a nullable string column. Wire this check into the trigger pipeline's `Ecto.Multi` so that suppressed deliveries are written but not dispatched.

**Where**:
- `lib/chimeway/policy.ex` — `evaluate/2` with planning-time preference check; extensible via optional `policy_module` config for future quiet-hours / rate-limit checks
- `lib/chimeway/deliveries/delivery.ex` (Phase 2 schema) — add `suppression_reason` field (`:string`, nullable)
- `priv/repo/migrations/<timestamp>_add_suppression_reason_to_chimeway_deliveries.exs` — alter table migration
- `lib/chimeway/trigger.ex` — add `Policy.evaluate(delivery_plan, context)` step before `Dispatcher.dispatch/2` in the `Ecto.Multi` pipeline; on suppress, set status and skip dispatch

**Acceptance criteria**:
- [ ] `Chimeway.Policy.evaluate/2` returns `{:suppress, :channel_disabled}` when preference is disabled
- [ ] `Chimeway.Policy.evaluate/2` returns `{:ok, :proceed}` when no preference row exists or preference is enabled
- [ ] Suppressed deliveries are persisted with `status: :suppressed` and a non-null `suppression_reason`
- [ ] A test confirms: trigger with disabled preference -> delivery row created as suppressed -> no adapter call made
- [ ] `suppression_reason` migration runs and rolls back cleanly

**Done when**: Planning-time policy evaluation is wired into the trigger pipeline and suppressed deliveries are durably recorded with reasons.

---

### Task 3: Perform-Time Policy Re-evaluation and Delayed Fallback Suppression
**What**: Add a second policy evaluation point inside both `Chimeway.Dispatch.ObanWorker.perform/1` and `Chimeway.Dispatch.Sync.dispatch/2`, executed after the delivery is loaded but before the adapter call. This perform-time check must: (1) re-run `Chimeway.Preferences.channel_enabled?/3` with current preference state, and (2) for deliveries where `delay_fallback: true`, check whether the associated in-app notification has `read_at` set. If either check returns suppress, update the delivery to `status: :suppressed` with `suppression_reason` and return `:ok` from the worker without calling the adapter. Add a `delay_fallback` boolean field to delivery rows to carry the fallback intent from planning time.

**Where**:
- `lib/chimeway/policy.ex` — extend `evaluate/2` to accept `check_read_state: true` option (boolean, default `false`); when `true`, load `notify_notifications` record and check `read_at`; returns `{:suppress, :already_read}` if read
- `lib/chimeway/dispatch/oban_worker.ex` — add `Policy.evaluate(delivery, check_read_state: delivery.delay_fallback)` call before adapter dispatch
- `lib/chimeway/dispatch/sync.ex` — same perform-time check before adapter dispatch using `Policy.evaluate(delivery, check_read_state: delivery.delay_fallback)`
- `lib/chimeway/deliveries/delivery.ex` — add `delay_fallback` boolean field (default `false`)
- `priv/repo/migrations/<timestamp>_add_delay_fallback_to_chimeway_deliveries.exs` — alter table migration

**Acceptance criteria**:
- [ ] Perform-time evaluation re-reads preferences from DB at execution time, not from enqueue-time snapshot
- [ ] If a delivery has `delay_fallback: true` and the associated notification has `read_at` set, the worker suppresses with reason `:already_read` and does not call the adapter
- [ ] If a delivery has `delay_fallback: true` and `read_at` is nil, the adapter is called normally
- [ ] If a preference is disabled between enqueue and perform, the delivery is suppressed at perform time
- [ ] `suppression_reason` is populated for all perform-time suppression cases
- [ ] `mix test` passes

**Done when**: Both sync and Oban dispatch paths re-evaluate policy at perform time, and delayed fallback suppression based on in-app read state is verified by tests.

## Verification
**This plan is complete when**:
- [ ] `chimeway_notification_preferences` table exists with correct schema, index, and migration
- [ ] `Chimeway.Policy.evaluate/2` is the single decision surface called at both planning time and perform time
- [ ] Suppression reasons are persisted on delivery rows for both planning-time and perform-time suppressions
- [ ] A test covers the full path: trigger -> preference disabled -> delivery row suppressed, adapter never called
- [ ] A test covers: Oban job enqueued -> preference disabled between enqueue and perform -> job performs and suppresses
- [ ] A test covers: Oban job enqueued -> in-app notification read before perform -> job performs and suppresses (POLC-03)
- [ ] All tasks done conditions are met
- [ ] `mix test` passes for this plan's scope

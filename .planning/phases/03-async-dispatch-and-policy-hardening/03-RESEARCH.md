# Research: Phase 3 — Async Dispatch and Policy Hardening

**Phase**: 3 — Async Dispatch and Policy Hardening
**Requirements**: DLVR-04, POLC-01, POLC-02, POLC-03, INTG-03
**Researched**: 2026-04-24
**Status**: RESEARCH COMPLETE

---

## Summary

Phase 3 adds an optional Oban-backed async dispatch path behind the `Chimeway.Dispatch` behaviour seam that Phase 2 established, and introduces a dual-checkpoint policy engine that enforces recipient preferences at both planning time and perform time. The central technical challenge is keeping Oban strictly optional — the project must compile, test, and operate correctly when Oban is absent — while ensuring the Oban path is transactionally consistent (job insert inside the same `Ecto.Multi` as delivery row creation) and idempotent on retry. Policy correctness requires re-reading preferences from the DB at perform time, not relying on enqueue-time snapshots, and checking in-app `read_at` state for the delayed fallback suppression path.

---

## Existing Codebase Analysis

### Dispatch Architecture (current)

The dispatch seam is **fully wired** as of Phase 2. Key findings:

**`lib/chimeway/dispatch.ex`** — behaviour contract with a single `@callback dispatch(notifications :: [Notification.t()], opts :: keyword()) :: {:ok, [Delivery.t()]} | {:error, term()}`. Note the current callback signature takes a list of notifications, not a single delivery. This is relevant for Phase 3: the Oban dispatcher will need to enqueue one job per delivery, not one job per notification. The seam already documents `Chimeway.Dispatch.Oban` as the Phase 3 alternative.

**`lib/chimeway/dispatch/sync.ex`** — production-ready synchronous dispatcher. Pipeline per delivery: (1) terminal state guard for `[:succeeded, :suppressed, :cancelled]`, (2) transition to `:dispatched`, (3) resolve adapter from `Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)`, (4) call `adapter.deliver/2`, (5) classify outcome, (6) call `Deliveries.record_attempt/2` atomically. All six steps are implemented.

**`lib/chimeway/trigger.ex`** — trigger pipeline calls `dispatch_after_trigger/2` which reads `Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)` at call time, reloads notifications from DB via `Repo.all(from n in Notification, where: n.event_id == ^event.id)`, then calls `dispatcher.dispatch(notifications, opts)`. The config seam is live. Dispatch happens outside the notification `Ecto.Multi` transaction — correct per Phase 2 design.

**`config/config.exs`** — `config :chimeway, dispatcher: Chimeway.Dispatch.Sync` is the documented default.

**`lib/chimeway/dispatch/` directory** — contains `sync.ex` only. `oban.ex` and `oban_worker.ex` do not yet exist.

### Delivery Model (current)

**`lib/chimeway/delivery.ex`** — schema for `chimeway_deliveries`. Status enum: `[:pending, :dispatched, :succeeded, :failed, :suppressed, :cancelled]`. Already has `suppression_reason` (nullable string) and `delay_fallback` (boolean, default false) fields. Unique constraint on `(notification_id, channel)` named `:chimeway_deliveries_notification_channel_index`. No migration gaps — these columns are already present in the schema declaration. The PHASE.md states these as "Key DB Changes This Phase" (alter table migrations), but the schema definition already includes them. This needs reconciliation: either they were added in Phase 2 already (check migrations), or they exist only in the schema and the migrations have not been created yet.

**`lib/chimeway/delivery_attempt.ex`** — immutable append-only schema. `outcome` enum: `[:succeeded, :failed, :bounced, :rejected]`. No `updated_at` (correct). FK to `chimeway_deliveries`.

**`lib/chimeway/deliveries.ex`** — context module. `plan_delivery/2` is idempotent via `on_conflict: :nothing`. `transition_status/2` enforces the allowed transition table: `pending → [:dispatched, :suppressed, :cancelled]`, `dispatched → [:succeeded, :failed, :suppressed]`, `failed → [:dispatched]`. `record_attempt/2` atomically inserts attempt + transitions delivery status in one `Ecto.Multi`. Terminal states constant defined: `@terminal_states [:succeeded, :suppressed, :cancelled]`.

**`lib/chimeway/notifications/notification.ex`** — `read_at` field is `utc_datetime_usec`, nullable. The `recipient_identity` string is the stable identity key. No changes needed to this schema for Phase 3.

### Dependencies

**`mix.exs`** current deps:
- `{:ecto_sql, "~> 3.11"}` — present
- `{:postgrex, ">= 0.0.0"}` — present
- `{:nimble_options, "~> 1.1"}` — present
- `{:jason, "~> 1.4"}` — present

**Oban is NOT yet in `mix.exs`.** Phase 3 must add it as an optional dependency:
```elixir
{:oban, "~> 2.17", optional: true}
```

The optional flag means Oban will not be pulled in by downstream consumers of Chimeway unless they explicitly add it. When Oban is absent from the host app, the `Chimeway.Dispatch.Oban` and `Chimeway.Dispatch.ObanWorker` module bodies must not be defined.

---

## Technical Findings

### Finding 1: Oban Integration Seam

**Confidence**: HIGH

The dispatch seam is already implemented and correctly positioned. `Chimeway.Trigger.dispatch_after_trigger/2` reads the dispatcher from application config at call time and invokes `dispatcher.dispatch(notifications, opts)`. The `Chimeway.Dispatch` behaviour is defined with the correct callback. The sync implementation is complete and tested.

The only gap is that the current `dispatch/2` callback signature accepts `[Notification.t()]`, not individual delivery structs. The Oban dispatcher will need to: (1) plan delivery rows for each notification+channel pair, and (2) enqueue one Oban job per delivery. This is consistent with the existing sync pattern in `Dispatch.Sync` which iterates notifications, calls `Deliveries.plan_delivery/2` for each, and dispatches each delivery inline.

**Recommendation**: The `Chimeway.Dispatch.Oban` implementation should mirror the sync dispatcher's iteration pattern — iterate notifications, call `plan_delivery/2` for each, then call `Oban.insert(ObanWorker.new(%{delivery_id: delivery.id}))` instead of calling the adapter inline. This preserves the behaviour contract shape with no changes required to `Chimeway.Dispatch` or `Chimeway.Trigger`.

### Finding 2: Optional Oban Activation

**Confidence**: HIGH

The established Elixir pattern for optional library integration is `Code.ensure_loaded?(Oban)` at the top of the file wrapping the entire `defmodule` block. This is documented in `03-CONTEXT.md` as decision D-04 and is the correct approach.

```elixir
if Code.ensure_loaded?(Oban) do
  defmodule Chimeway.Dispatch.Oban do
    @behaviour Chimeway.Dispatch
    # ...
  end
end
```

The files `lib/chimeway/dispatch/oban.ex` and `lib/chimeway/dispatch/oban_worker.ex` always exist on disk (no absent files at compile time). The `defmodule` block is conditionally compiled. This avoids Mix compile-time flags and keeps the codebase structure consistent whether Oban is present or not.

Test suite implications: Oban tests must be tagged separately (`@moduletag :oban`) and conditionally excluded in the test helper when Oban is absent. `Oban.Testing` provides `use Oban.Testing, repo: Chimeway.Repo` for test helpers and `assert_enqueued/1`, `perform_job/2` assertion helpers.

**Oban version**: Use `~> 2.17` to get `Oban.Testing.perform_job/2`, unique job constraints, and `Oban.insert/2` with `Ecto.Multi` support.

### Finding 3: Transactional Enqueue

**Confidence**: HIGH

Oban's `Oban.insert/3` accepts a `repo` and an `Oban.Job` changeset, and can be embedded inside an `Ecto.Multi` as a named step:

```elixir
Ecto.Multi.new()
|> Ecto.Multi.insert(:delivery, delivery_changeset)
|> Oban.insert(:job, ObanWorker.new(%{delivery_id: delivery.id}))
|> Repo.transaction()
```

When the `Ecto.Multi` transaction rolls back (e.g., a subsequent step fails), the Oban job row is also rolled back — it never becomes visible to the Oban queue. This is the key transactional guarantee that prevents orphaned jobs for deliveries that never committed.

The `03-01` plan Task 3 specifies accepting an optional `multi: %Ecto.Multi{}` option in `Chimeway.Dispatch.Oban.dispatch/2`. However, the current trigger pipeline calls dispatch _after_ the notification transaction commits (outside the multi). For full transactional enqueue, the dispatch call must either: (a) move inside the existing `Ecto.Multi`, or (b) create a new mini-transaction just for delivery planning + job enqueue. Option (b) is cleaner because the notification transaction should remain focused on event/notification insertion. A two-step approach is acceptable: notification multi commits → delivery planning + job enqueue in a second multi.

**Oban unique job configuration** (idempotency):
```elixir
use Oban.Worker,
  queue: :chimeway_delivery,
  max_attempts: 5,
  unique: [fields: [:args], keys: [:delivery_id], period: 60]
```
This prevents duplicate jobs for the same `delivery_id` within a 60-second window. For stronger idempotency, use the terminal state check in `perform/1` as the authoritative guard — the DB state of the delivery is always the source of truth.

### Finding 4: Preference Schema

**Confidence**: HIGH

The `chimeway_notification_preferences` table does not yet exist (no migration found in `priv/repo/migrations/`). The schema and context module are not yet created.

**Recommended schema:**

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID PK | `primary_key: true` |
| `recipient_id` | string | `not null` |
| `notification_key` | string | `not null` |
| `channel` | string | `not null` |
| `enabled` | boolean | `not null, default: true` |
| `inserted_at` | utc_datetime_usec | `not null` |
| `updated_at` | utc_datetime_usec | `not null` |

Unique index on `(recipient_id, notification_key, channel)` — named `:chimeway_notification_preferences_recipient_key_channel_index`.

**Preference resolution semantics**: The plan calls for exact-match lookup only in Phase 3 (`get_preference(recipient_id, notification_key, channel)`). A hierarchical resolution (global → topic → key-specific) is not required for this phase and should not be over-engineered. The `channel_enabled?/3` function returns `true` when no row exists — opt-in default behavior is the correct choice for a notification system where new channels should be enabled by default.

**`Chimeway.Preferences` context**:
- `upsert_preference/1` — idempotent via `on_conflict: {:replace, [:enabled, :updated_at]}`
- `get_preference/3` — returns `%NotificationPreference{}` or `nil`
- `channel_enabled?/3` — boolean, defaults `true` on nil result

### Finding 5: Policy Engine Architecture

**Confidence**: HIGH

Context decision D-02 from `03-CONTEXT.md` specifies a single `Chimeway.Policy.evaluate/2` entry point with keyword opts rather than two separate named functions. Decision D-03 specifies return values of `{:ok, :proceed}` or `{:suppress, reason_atom}` where `reason_atom` is a plain atom.

**Dual evaluation checkpoints:**

1. **Planning time** (in trigger pipeline, before or during delivery row creation):
   - Check `Chimeway.Preferences.channel_enabled?(recipient_id, notification_key, channel)`
   - If disabled: create delivery row with `status: :suppressed`, `suppression_reason: "channel_disabled"`, skip dispatch
   - If enabled: create delivery row with `status: :pending`, proceed to dispatch

2. **Perform time** (in both `Dispatch.Sync.dispatch/2` and `ObanWorker.perform/1`, after delivery is loaded, before adapter call):
   - Re-check `Chimeway.Preferences.channel_enabled?/3` with fresh DB read
   - If `delivery.delay_fallback == true`: check `Notification.read_at` for the associated notification
   - If either check suppresses: transition delivery to `:suppressed`, write `suppression_reason`, return `:ok` without calling adapter

**`evaluate/2` signature:**
```elixir
@spec evaluate(Chimeway.Delivery.t(), keyword()) :: {:ok, :proceed} | {:suppress, atom()}
def evaluate(%Delivery{} = delivery, opts \\ [])
```

The `check_read_state:` boolean option (default `false`) activates the in-app read check. The planning-time call omits this option; the perform-time call passes `check_read_state: delivery.delay_fallback`.

**D-07 extensibility**: The `policy_module` config hook is documented in `@moduledoc` but not dispatched to in Phase 3. This is the correct YAGNI boundary.

### Finding 6: Delayed Fallback Suppression

**Confidence**: HIGH

The `delay_fallback` boolean is already present on the `Chimeway.Delivery` schema (`field :delay_fallback, :boolean, default: false`). The `suppression_reason` string field is also already present on the schema.

The notification `read_at` timestamp is on `Chimeway.Notifications.Notification` as `utc_datetime_usec` (nullable). The association path from a delivery to its notification:

```
chimeway_deliveries.notification_id
  → chimeway_notifications.id
    → chimeway_notifications.read_at
```

The `Delivery` schema already has `belongs_to :notification, Notification` association. Loading the notification for the read-state check is a single `Repo.get/2` or preload. Context decision D-08 from `03-CONTEXT.md` confirms: load by `notification_id` on the delivery row. If no notification row exists, treat `read_at` as nil (not read) and proceed.

**Suppression flow in `perform/1`:**
```elixir
1. Load delivery by delivery_id
2. If terminal state: return :ok (idempotency guard)
3. evaluate(delivery, check_read_state: delivery.delay_fallback)
4. If {:suppress, reason}: transition to :suppressed, persist reason, return :ok
5. Transition to :dispatched
6. Call adapter
7. record_attempt(...)
```

The suppression must happen before the `:dispatched` transition — a suppressed delivery should never pass through `:dispatched`.

**`suppression_reason` persistence**: Context decision D-06 specifies persisting as a plain string atom name (`"channel_disabled"`, `"already_read"`), not a JSON map. The existing `suppression_reason` column is `:string` nullable — correct.

### Finding 7: Idempotency in Async Context

**Confidence**: HIGH

Three layers of idempotency must be maintained in the Oban path:

1. **Delivery planning idempotency**: `Deliveries.plan_delivery/2` already uses `on_conflict: :nothing` with reload. Duplicate planning calls produce one delivery row.

2. **Job-level idempotency**: Oban unique job constraints (`unique: [fields: [:args], keys: [:delivery_id]]`) prevent duplicate job insertion for the same delivery within the uniqueness window. This is a soft guard.

3. **Perform-time terminal state guard**: The authoritative idempotency guard is in `perform/1`. On every execution, load the delivery, check if status is in `[:succeeded, :suppressed, :cancelled]`, and return `:ok` immediately if terminal. This handles the case where Oban retries a job after a partial success (e.g., attempt was recorded but Oban job acknowledgment failed).

The `failed` delivery status is **not terminal** and must be retried. Oban's `max_attempts: 5` with default exponential backoff is the retry mechanism. Each Oban retry creates a new `DeliveryAttempt` row via `record_attempt/2`. The attempt table is append-only — multiple attempts per delivery are expected and correct.

**Retry safety for `record_attempt/2`**: The current implementation is an `Ecto.Multi` that inserts an attempt row and calls `transition_status/2`. If a retry arrives when the delivery is already in `:failed`, the `failed → :dispatched` transition is allowed (re-entering dispatched for retry). This is already in the allowed transitions table.

**Error classification for retry policy**: Attempt outcomes map to delivery status:
- `{:ok, meta}` → attempt `:succeeded` → delivery `:succeeded` (terminal, no retry)
- `{:error, :temporary, detail}` → attempt `:failed` → delivery `:failed` (retryable)
- `{:error, :permanent, detail}` → attempt `:rejected` → delivery `:failed` (retryable by default, but could be made terminal with outcome-specific logic in Phase 4)
- `{:error, :bounced, detail}` → attempt `:bounced` → delivery `:failed` (retryable)

Note: `:permanent` and `:bounced` adapter errors result in `delivery.status = :failed` (retryable), not `:cancelled`. Phase 3 does not add outcome-specific terminal logic — all non-succeeded, non-suppressed deliveries are retried up to `max_attempts`. This is the correct conservative default.

---

## Recommended Approach

### 03-01: Oban Worker Path

**Summary**: The existing dispatch seam is correct and requires no changes to `Chimeway.Dispatch` behaviour or `Chimeway.Trigger`. Only additive work is needed.

1. **Add Oban to `mix.exs` as optional**: `{:oban, "~> 2.17", optional: true}`. Add `{:oban, "~> 2.17"}` to the `:test` environment deps of the integration test app if testing Oban paths.

2. **Create `lib/chimeway/dispatch/oban.ex`** inside `if Code.ensure_loaded?(Oban) do`. Implements `@behaviour Chimeway.Dispatch`. The `dispatch/2` function iterates notifications (matching the Sync pattern), calls `Deliveries.plan_delivery/2` for each, then calls `Oban.insert(ObanWorker.new(%{delivery_id: delivery.id}))` per delivery. Returns `{:ok, deliveries}`.

3. **Create `lib/chimeway/dispatch/oban_worker.ex`** inside `if Code.ensure_loaded?(Oban) do`. Uses `use Oban.Worker, queue: :chimeway_delivery, max_attempts: 5`. The `perform/1` callback: load delivery, terminal state guard, call adapter (no policy check yet — that is 03-02), `record_attempt/2`.

4. **Transactional enqueue**: When the `dispatch/2` receives a `multi: multi` option, add job insertion as a named step via `Oban.insert(multi, :enqueue_job_<delivery_id>, ...)`. When no multi is provided, use direct `Oban.insert/2`. The trigger pipeline currently passes no multi to dispatch — update `Trigger.dispatch_after_trigger/2` to pass the option for Oban dispatcher awareness.

5. **Tests**: Use `Oban.Testing` with `use Oban.Testing, repo: Chimeway.Repo`. Tag with `@moduletag :oban`. Test: switch config to `Chimeway.Dispatch.Oban` → trigger → `assert_enqueued(worker: ObanWorker, args: %{delivery_id: ...})`. Test transactional rollback: construct a multi that fails after job insert → confirm job not visible.

6. **Documentation**: `guides/flows/oban-integration.md` with: deps, config, transactional enqueue example, queue naming, retry tuning.

### 03-02: Preference Model and Policy Engine

1. **Migration for `chimeway_notification_preferences`**: UUID PK, `recipient_id`, `notification_key`, `channel` (all not null strings), `enabled` boolean not null default true, `inserted_at`/`updated_at` utc_datetime_usec. Named unique index. Follow Phase 1/2 migration conventions: `primary_key: false`, explicit UUID add.

2. **Schema `Chimeway.Preferences.NotificationPreference`**: Standard `use Ecto.Schema` with `@primary_key {:id, :binary_id, autogenerate: true}`. Changeset validates required fields.

3. **Context `Chimeway.Preferences`**: `upsert_preference/1` with `on_conflict: {:replace, [:enabled, :updated_at]}, conflict_target: [:recipient_id, :notification_key, :channel]`. `channel_enabled?/3` returns `true` on nil.

4. **`Chimeway.Policy.evaluate/2`**: Planning-time call checks `channel_enabled?/3`. Perform-time call also passes `check_read_state: delivery.delay_fallback`. When `check_read_state: true`, load `Repo.get(Notification, delivery.notification_id)` and check `notification.read_at != nil`. Log suppress decisions with `Logger.debug` (structured, no PII) per D-07 recommendation.

5. **Wire planning-time check into `Dispatch.Sync`**: After `plan_delivery/2` returns the delivery, call `Policy.evaluate(delivery, [])`. On `{:suppress, reason}`: `Deliveries.transition_status(delivery, :suppressed)` and set `suppression_reason`. Skip adapter call.

6. **Wire perform-time check into `Dispatch.Sync`** (in addition to ObanWorker): The sync path also needs the perform-time re-evaluation for consistency — a preference change between plan and dispatch should suppress the delivery even in sync mode.

7. **Column existence — no action needed**: The `suppression_reason` and `delay_fallback` columns are confirmed present in the Phase 2 create migration. Do NOT write alter-table migrations for them in Phase 3. Only the `chimeway_notification_preferences` table migration is new this phase.

### 03-03: Delayed Fallback Tests and Async Failure-Mode Verification

1. **Delayed fallback test**: Insert a notification, plan a delivery with `delay_fallback: true`, set `read_at` on the notification row, then call `ObanWorker.perform/1` directly (using `perform_job(ObanWorker, %{delivery_id: delivery.id})` via `Oban.Testing`). Assert: delivery transitions to `:suppressed`, `suppression_reason: "already_read"`, no adapter call made (use Test adapter + assert no deliveries stored).

2. **Delayed fallback not-read test**: Same setup, `read_at` nil. Assert: adapter is called, delivery transitions to `:succeeded`.

3. **Preference change between enqueue and perform test**: Plan delivery, disable preference after enqueue, perform worker. Assert: delivery suppressed with `"channel_disabled"`.

4. **Terminal state idempotency test**: Manually set delivery to `:succeeded`, call `perform/1`. Assert: returns `:ok`, no new attempt row created.

5. **Transactional rollback test**: Construct `Ecto.Multi` that enqueues job then fails. Assert: `Oban.all_enqueued(worker: ObanWorker)` returns empty list.

6. **Retry after failure test**: Perform worker → adapter returns `{:error, :temporary, %{}}` → delivery is `:failed` → perform again → delivery transitions through `:dispatched` → `:succeeded`. Assert two attempt rows.

7. **Test tags**: `@moduletag :oban` for all Oban-path tests; `@moduletag :policy` for policy/preference tests; `@moduletag :integration` for end-to-end lifecycle tests.

---

## Key Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| `suppression_reason` / `delay_fallback` columns missing from DB (schema has them, migrations may not) | RESOLVED | — | Both columns confirmed present in `20260424082833_create_chimeway_deliveries.exs`. No action needed. |
| Oban `Code.ensure_loaded?` guard compiles but produces cryptic runtime error if Oban accidentally absent when `Chimeway.Dispatch.Oban` is configured | MEDIUM | MEDIUM | Add a runtime config validation that raises a clear error at application start if `:dispatcher` is set to `Chimeway.Dispatch.Oban` but Oban module is not available |
| Perform-time policy check races with concurrent preference update | LOW | LOW | Acceptable for v1; preference reads are a single Repo.get; last-write-wins on the delivery suppression is acceptable behavior |
| `Oban.insert/2` signature differences across Oban 2.x minor versions | LOW | MEDIUM | Pin to `~> 2.17`; test against that version only; document in guide |
| `delay_fallback` check loads the wrong notification (wrong notification_id association) | LOW | HIGH | Test with explicit `delivery.notification_id` assertion in the fallback test; never load notification by recipient_identity alone |
| Attempt rows accumulate without bound on max_attempts exhaustion | LOW | LOW | Phase 4 concern; `max_attempts: 5` caps at 5 attempts per delivery; document in guide |
| Planning-time policy check inside `Ecto.Multi` holds DB transaction while querying preferences | LOW | LOW | Preference query is a single indexed row lookup; acceptable latency; no HTTP calls in policy evaluation |

---

## Open Questions

1. ~~**`suppression_reason` and `delay_fallback` migration gap**~~ **RESOLVED**: `priv/repo/migrations/20260424082833_create_chimeway_deliveries.exs` confirms both `suppression_reason` (nullable string) and `delay_fallback` (boolean, not null, default false) were included in the Phase 2 create migration. No alter-table migrations are needed in Phase 3. The PHASE.md "Key DB Changes" list for these columns is obsolete — they are already live in the DB schema.

2. **`Dispatch.Sync` perform-time policy evaluation**: The `03-02` plan specifies adding the perform-time policy check to both `Dispatch.Sync` and `ObanWorker`. The current `Dispatch.Sync` has no policy integration at all. Should the planning-time policy check be added to `Dispatch.Sync` before or during 03-02, or does the Sync path only need the perform-time check (since planning and perform are synchronous)? For sync dispatch, a single check at perform time is sufficient — the planning-to-perform window is zero. The plan should clarify whether duplicate (planning + perform) evaluation is required in sync mode or only in async mode.

3. **Queue name in application config vs. compile-time**: The queue name `:chimeway_delivery` is currently hardcoded in the plan. Should it be configurable via `Application.get_env(:chimeway, :oban_queue, :chimeway_delivery)` to allow host apps to customize the queue? This is an ergonomics question for INTG-03 compliance — document the default and allow override without making it a required config key.

4. **Recipient identity to `recipient_id` mapping for preferences**: `Chimeway.Preferences` uses `recipient_id` as the preference lookup key. The delivery row has `notification_id` → notification row has `recipient_identity`. Are `recipient_id` in preferences and `recipient_identity` in notifications the same string? The naming should be standardized. Verify the intended key shape before writing the preference migration.

5. **`notification_key` source for preference lookup**: When evaluating preferences at perform time, the worker has a `delivery_id`. To call `channel_enabled?(recipient_id, notification_key, channel)`, it needs `notification_key`. This requires loading: `delivery → notification (via notification_id) → event (via event_id) → notification_key`. This is a two-join load. Should the `notification_key` be denormalized onto the delivery row or notification row to avoid the join at perform time?

---

*Research date: 2026-04-24*
*Status: RESEARCH COMPLETE*
*Confidence: HIGH overall — dispatch seam and delivery model are well-established in Phase 2; Oban integration patterns are standard Elixir ecosystem; key open questions are clarification/verification items, not architectural unknowns*

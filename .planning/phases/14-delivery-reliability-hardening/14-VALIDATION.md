---
phase: 14
slug: delivery-reliability-hardening
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-26
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `14-RESEARCH.md` § Validation Architecture (lines 710–787).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19.5 stdlib) + `Oban.Testing` 2.21.1 + `Ecto.Adapters.SQL.Sandbox` 3.13.5 |
| **Config file** | `test/test_helper.exs` (existing); `mix.exs` aliases include `ci.test: ["test"]` |
| **Quick run command** | `mix test test/chimeway/dispatch/oban_worker_test.exs test/chimeway/reliability/` |
| **Full suite command** | `mix ci` (`format --check-formatted`, `compile --warnings-as-errors`, `credo --strict`, `test`) |
| **Estimated runtime** | ~30 seconds (full `mix test`); ~5 seconds (per-task affected files) |

---

## Sampling Rate

- **After every task commit:** Run `mix test {affected_file_paths}` for files in the task's `<acceptance_criteria>`
- **After every plan wave:** Run `mix ci`
- **Before `/gsd-verify-work`:** `mix ci` green AND every test in the Per-Task Verification Map green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

> Plan/Wave/Task IDs assigned by the planner. This map captures the requirement-to-test bindings the planner MUST honor.

| Requirement | Behavior | Test Type | Automated Command | File Status |
|-------------|----------|-----------|-------------------|-------------|
| REL-01 | `Trigger.trigger` returns `{:duplicate, event}` on serial re-fire | unit | `mix test test/chimeway/idempotency_constraint_test.exs:29` | ✅ exists |
| REL-01 | Concurrent re-fires produce one canonical row | concurrency | `mix test test/chimeway/idempotency_constraint_test.exs:49` | ✅ exists |
| REL-01 | `plan_notifications/2` is idempotent on re-entry for same event | unit | `mix test test/chimeway/reliability/duplicate_protection_test.exs` | ❌ Wave 0 |
| REL-01 | Sync dispatch short-circuits on terminal delivery | unit | `mix test test/chimeway/dispatch/sync_test.exs` | ✅ extend |
| REL-01 | Oban dispatch short-circuits on terminal delivery | unit | `mix test test/chimeway/dispatch/oban_worker_test.exs` | ✅ exists |
| REL-01 | Phase 12 transactional rollback still rolls back planning rows | regression | `mix test test/chimeway/dispatch/oban_transactional_test.exs` | ✅ exists |
| REL-01 | Concurrent `plan_notifications/2` produces no duplicates | concurrency | `mix test test/chimeway/reliability/duplicate_protection_test.exs` | ❌ Wave 0 |
| REL-01 | Concurrent dispatch re-entry against terminal delivery records no extra attempts | concurrency | `mix test test/chimeway/reliability/duplicate_protection_test.exs` | ❌ Wave 0 |
| REL-02 | Transient failure causes Oban to schedule retry (return `{:error, _}`) | unit | `mix test test/chimeway/dispatch/oban_worker_test.exs` (D-13 rewrite) | ❌ Wave 0 (rewrite) |
| REL-02 | Permanent failure does NOT trigger retry (return `:ok`, status converges) | unit | `mix test test/chimeway/dispatch/oban_worker_test.exs` | ❌ Wave 0 |
| REL-02 | Bounced failure does NOT trigger retry (return `:ok`, status converges) | unit | `mix test test/chimeway/dispatch/oban_worker_test.exs` | ❌ Wave 0 |
| REL-02 | `attempt_number` is 1-indexed and contiguous per delivery | unit | `mix test test/chimeway/reliability/attempt_history_test.exs` | ❌ Wave 0 |
| REL-02 | `error_class` persists `"temporary"\|"permanent"\|"bounced"`; nil on success | unit | `mix test test/chimeway/reliability/attempt_history_test.exs` | ❌ Wave 0 |
| REL-02 | Concurrent `record_attempt` calls do not duplicate `attempt_number` | concurrency | `mix test test/chimeway/reliability/attempt_history_test.exs` | ❌ Wave 0 |
| REL-02 | Telemetry [:attempts, :record, :stop] meta carries attempt_number + error_class | unit | `mix test test/chimeway/reliability/attempt_history_test.exs` | ❌ Wave 0 |
| REL-02 | `Traces.last_attempt_summary` exposes `attempt_number` and `error_class` | unit | `mix test test/chimeway/traces_test.exs` | ✅ extend |
| REL-02 | Final attempt (`job.attempt == max_attempts`) writes `:cancelled` retries_exhausted | unit | `mix test test/chimeway/dispatch/oban_worker_test.exs` | ❌ Wave 0 |
| REL-02 | drain_queue end-to-end: 5 retries then terminal | integration | `mix test test/chimeway/reliability/retry_exhaustion_test.exs` | ❌ Wave 0 |
| REL-03 | Promoted `terminal_states/0` is single source of truth (sync uses it) | unit | `mix test test/chimeway/dispatch/sync_test.exs` | ✅ extend |
| REL-03 | Promoted `terminal_states/0` is single source of truth (Oban uses it) | unit | `mix test test/chimeway/dispatch/oban_worker_test.exs` | ✅ extend |
| REL-03 | `failed -> cancelled` transition allowed via `exhaust_delivery/1` only | unit | `mix test test/chimeway/deliveries_test.exs` | ❌ Wave 0 |
| REL-03 | `transition_status(failed_delivery, :cancelled)` general path is rejected | unit | `mix test test/chimeway/deliveries_test.exs` | ❌ Wave 0 |
| REL-03 | Every terminal path lands in `Deliveries.terminal_states/0` (succeeded) | unit | `mix test test/chimeway/reliability/terminal_convergence_test.exs` | ❌ Wave 0 |
| REL-03 | Every terminal path lands in `terminal_states/0` (retries_exhausted) | unit | `mix test test/chimeway/reliability/terminal_convergence_test.exs` | ❌ Wave 0 |
| REL-03 | Every terminal path lands in `terminal_states/0` (permanent_failure) | unit | `mix test test/chimeway/reliability/terminal_convergence_test.exs` | ❌ Wave 0 |
| REL-03 | Every terminal path lands in `terminal_states/0` (bounced) | unit | `mix test test/chimeway/reliability/terminal_convergence_test.exs` | ❌ Wave 0 |
| REL-03 | Every terminal path lands in `terminal_states/0` (suppressed) | unit | `mix test test/chimeway/reliability/terminal_convergence_test.exs` | ❌ Wave 0 |
| REL-03 | Every terminal path lands in `terminal_states/0` (cancelled manual) | unit | `mix test test/chimeway/reliability/terminal_convergence_test.exs` | ❌ Wave 0 |
| REL-03 | Sync path converges permanent/bounced to `:cancelled` (parity with Oban) | unit | `mix test test/chimeway/dispatch/sync_test.exs` | ❌ Wave 0 |

*Status: ✅ exists · ✅ extend (file exists, add new test cases) · ❌ Wave 0 (file must be created before implementation tasks)*

---

## Wave 0 Requirements

Wave 0 = Plan 14-01 (the four scaffolded test files with `:skip` moduletags). Plan 14-01 satisfies the Wave 0 gate.

New test files scaffolded by Plan 14-01:

- [x] `test/chimeway/reliability/duplicate_protection_test.exs` — REL-01 D-02/D-14: concurrent re-fire, concurrent plan re-entry, concurrent terminal re-entry
- [x] `test/chimeway/reliability/attempt_history_test.exs` — REL-02: `attempt_number` ordinality, `error_class` taxonomy, concurrent `attempt_number` race, telemetry stop assertion (W3 addition)
- [x] `test/chimeway/reliability/retry_exhaustion_test.exs` — REL-02 end-to-end via `Oban.drain_queue/2` + always-failing adapter
- [x] `test/chimeway/reliability/terminal_convergence_test.exs` — REL-03 D-12: every terminal path asserts membership in `Deliveries.terminal_states/0`

Existing files extended by later plans (Plan 14-04, 14-05, 14-07, 14-08):

- [x] `test/chimeway/dispatch/oban_worker_test.exs` — D-13 rewrite using `Oban.Testing.perform_job/3` with `attempt:` (executed in Plan 14-05 Task 2 per B4)
- [x] `test/chimeway/dispatch/sync_test.exs` — REL-03 sync-path permanent/bounced convergence (executed in Plan 14-04 Task 3 per B4)
- [x] `test/chimeway/deliveries_test.exs` — `exhaust_delivery/1` happy path + invalid-transition path (Plan 14-07)
- [x] `test/chimeway/traces_test.exs` — `last_attempt_summary` exposes new fields (Plan 14-08)

Framework install: not required (ExUnit is stdlib; `Oban.Testing` already available via mix.lock).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| (none) | — | All Phase 14 behaviors are automatable via ExUnit + `Oban.Testing` + `Ecto.Adapters.SQL.Sandbox` | — |

*All phase behaviors have automated verification.*

---

## Failure Mode Hypotheses (drive Wave 0 test design)

| Failure Mode | Hypothesis | Validation Observable |
|--------------|------------|----------------------|
| Concurrent re-fire collision | Two simultaneous triggers with same `idempotency_key` both succeed because the dedup check ran outside the transaction | Postgres unique constraint name in error tuple; `Repo.aggregate(Event, :count) == 1` |
| Partial enqueue rollback | Dispatch fails after planning rows are inserted; planning rows survive | `Repo.aggregate(Delivery, :count, where: notification_id == ^id) == 0` after forced enqueue failure |
| Terminal-state divergence between sync and Oban | Sync `:permanent` outcome leaves delivery `:failed`; Oban path correctly converges to `:cancelled` | `Deliveries.get_delivery!(id).status in Deliveries.terminal_states()` for BOTH paths |
| `:snooze` budget runaway (anti-pattern) | Worker returns `{:snooze, n}` and `attempt` keeps climbing past `max_attempts: 5` | `assert job.attempt <= max_attempts` after `drain_queue` |
| Final-attempt write missed | `job.attempt == job.max_attempts` guard misfires (off-by-one) and exhaustion path never runs | After `drain_queue` with always-failing adapter: `delivery.status == :cancelled and suppression_reason == "retries_exhausted"` |
| `attempt_number` duplicate under concurrency | Two concurrent `record_attempt` calls both compute `count(*) + 1` and tie | Concurrent test asserts `Repo.aggregate(DeliveryAttempt, :count, distinct: :attempt_number) == count(:id)` (mitigated preemptively by `SELECT ... FOR UPDATE` lock in Plan 14-04 W8 fix) |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all `❌` references in the Per-Task Verification Map
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** 2026-04-26 (planner-verified during plan-phase)

---
phase: 02-first-outbound-delivery-slice
plan: "02-02"
subsystem: adapter-seam
tags: [adapter, dispatch, sync, test-adapter, logger-adapter, outcome-classification]
depends_on: ["02-01"]
key_files:
  - lib/chimeway/adapter.ex
  - lib/chimeway/adapters/test.ex
  - lib/chimeway/adapters/logger.ex
  - lib/chimeway/dispatch/sync.ex
  - test/chimeway/adapters/test_adapter_test.exs
  - test/chimeway/adapters/logger_adapter_test.exs
  - test/chimeway/dispatch/sync_test.exs
key_decisions:
  - "Outcome classification lives in Chimeway.Dispatch.Sync, not in adapters — adapters return raw {:ok, meta} | {:error, class, detail}"
  - "Adapter resolved via Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger) at dispatch time — swappable in tests via put_env"
  - "Test adapter uses process dictionary for per-test isolation (mirrors Swoosh.Adapters.Test pattern)"
  - "Logger adapter emits only tagged identity fields — never delivery.metadata or provider_response blobs"
  - "Dispatch transitions delivery to :dispatched BEFORE calling adapter — crash-safe persistence ordering"
tech_stack: [elixir, ecto, exunit, capture_log]
duration: ~15min
completed_at: "2026-04-24T04:44:00Z"
---

Implemented Chimeway.Adapter behaviour, Test and Logger adapters, and wired the full Chimeway.Dispatch.Sync pipeline from dispatched-state transition through adapter call, outcome classification, and atomic attempt + status persistence.

## Tasks Completed

### Task 02-02-01: Chimeway.Adapter behaviour
**Status: COMPLETE (already implemented)**

`lib/chimeway/adapter.ex` defines the `@callback deliver/2` with full `{:ok, map()} | {:error, atom(), map()}` return typespec. `@moduledoc` documents:
- `:temporary | :permanent | :bounced` reason classes
- Redaction requirement (password, token, secret, api_key, auth)
- No notifier callbacks allowed — content must arrive pre-populated
- Config via `Application.get_env/3` at call time only

### Task 02-02-02: Chimeway.Adapters.Test and Logger
**Status: COMPLETE (already implemented)**

**`Chimeway.Adapters.Test`:**
- `@behaviour Chimeway.Adapter` satisfied with `@impl`
- `deliver/2` stores in process dictionary, returns `{:ok, %{adapter: "test", delivered_at: ...}}`
- `delivered_messages/0`, `assert_delivered/1` (raises `ExUnit.AssertionError` with readable message including delivery ID), `clear/0`

**`Chimeway.Adapters.Logger`:**
- `@behaviour Chimeway.Adapter` satisfied with `@impl`
- Logs `[chimeway_delivery] channel=... notification_id=...` only — no metadata blob
- Always returns `{:ok, %{adapter: "logger", logged: true}}`

**Tests (19 tests, 0 failures):**
- `test_adapter_test.exs`: return shape, process dict storage, `assert_delivered` pass/fail/message, `clear/0`, process isolation
- `logger_adapter_test.exs`: return shape, `[chimeway_delivery]` in log, channel name in log, no metadata blob

### Task 02-02-03: Chimeway.Dispatch.Sync wiring
**Status: COMPLETE (already implemented)**

Full pipeline in `dispatch_delivery/1`:
1. Terminal guard: `[:succeeded, :suppressed, :cancelled]` → `{:ok, delivery}` no-op
2. `Deliveries.transition_status(delivery, :dispatched)` — persisted before adapter call
3. Adapter resolved via `Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)`
4. `adapter.deliver(dispatched, adapter_config)` called
5. Outcome classified: `{:ok, meta}` → `:succeeded`; `{:error, :temporary, _}` → `:failed`; `{:error, :permanent, _}` → `:rejected`; `{:error, :bounced, _}` → `:bounced`
6. `Deliveries.record_attempt/2` atomically inserts attempt row + final status transition

**Tests (sync_test.exs, as part of 54-test suite):**
- `{:ok, meta}` → delivery `:succeeded`, attempt `:succeeded`, delivery stored in test adapter
- `{:error, :temporary, _}` → delivery `:failed`, attempt `:failed`
- `{:error, :permanent, _}` → delivery `:failed`, attempt `:rejected`
- `{:error, :bounced, _}` → delivery `:failed`, attempt `:bounced`
- Terminal guard: second dispatch on `:succeeded` delivery returns `{:ok, delivery}`, no new attempt row

## Verification Results

- `mix compile --warnings-as-errors` — PASS
- `mix test test/chimeway/adapters/test_adapter_test.exs` — 10 tests, 0 failures
- `mix test test/chimeway/adapters/logger_adapter_test.exs` — 4 tests (plus logger adapter runs), 0 failures
- `mix test test/chimeway/dispatch/sync_test.exs` — 5 tests, 0 failures
- `mix test --seed 0` — 54 tests, 0 failures

## Security Gate (ASVS L1, block on high)

| Check | Result |
|-------|--------|
| TM-02-02-PII-IN-LOG: logger.ex has no `delivery.metadata` reference | PASS |
| TM-02-02-SENSITIVE-ATTEMPT-RESPONSE: adapter.ex documents redaction | PASS |
| TM-02-02-DISPATCH-BEFORE-PERSIST: `transition_status(:dispatched)` before adapter call | PASS |
| TM-02-02-COMPILE-TIME-CONFIG: no `@config/@api_key/@base_url` in adapters | PASS |
| TM-02-02-TEST-ADAPTER-SHARED-STATE: process dict only, no ETS/Agent | PASS |

## Deviations

None. All code was already implemented and passing when this plan was executed. Verification confirmed complete conformance with plan acceptance criteria.

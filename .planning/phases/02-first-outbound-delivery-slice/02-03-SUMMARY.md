---
phase: 02-first-outbound-delivery-slice
plan: "02-03"
subsystem: adapter-contract-tests
tags: [contract-test, integration-test, adapter, redaction, idempotency, lifecycle]
depends_on: ["02-01", "02-02"]
key_files:
  - test/support/chimeway/adapter/contract_test.ex
  - test/chimeway/adapters/test_adapter_test.exs
  - test/chimeway/adapters/logger_adapter_test.exs
  - test/chimeway/integration/delivery_lifecycle_test.exs
  - mix.exs
  - test/test_helper.exs
  - lib/chimeway/adapter.ex
key_decisions:
  - "Added elixirc_paths: elixirc_paths(Mix.env()) to mix.exs so test/support/ compiles automatically; removed Code.require_file from test_helper.exs"
  - "Used Code.ensure_loaded!/1 before :erlang.function_exported/3 to guard against lazy module loading in async: false test contexts"
  - "Integration test Scenario B uses Test adapter (via Application.put_env) for in_app channel since Dispatch.Sync currently only dispatches :in_app; assert_delivered/1 confirms capture"
  - "Notifier modules for integration test defined at file top level with unique notification_keys to prevent cross-scenario idempotency collisions"
  - "@before_compile enforcement in ContractTest raises CompileError if adapter_module/0 or sample_delivery/0 are not defined"
tech_stack: [elixir, exunit, ecto, macro, defmacro]
duration: ~25min
completed_at: "2026-04-24T08:55:03Z"
---

Locked adapter replaceability guarantee with Chimeway.Adapter.ContractTest shared module, applied it to both adapters, and confirmed the complete trigger-to-attempt lifecycle chain for in-app and outbound channels with idempotency verification.

## Tasks Completed

### Task 02-03-01: Chimeway.Adapter.ContractTest shared module
**Status: COMPLETE**

Created `test/support/chimeway/adapter/contract_test.ex` defining `Chimeway.Adapter.ContractTest` via `defmacro __using__`:

- **Contract test 1 (behaviour):** `Code.ensure_loaded!/1` + `:erlang.function_exported(mod, :deliver, 2)` — guards against lazy module loading in async: false contexts
- **Contract test 2 (success shape):** calls `adapter_module().deliver(sample_delivery(), [])`, asserts `{:ok, meta}` where meta is a map, then calls `__contract_check_no_sensitive_keys!(meta)`
- **Contract test 3 (redaction gate):** asserts `assert_raise ExUnit.AssertionError, fn -> __contract_check_no_sensitive_keys!(%{token: "abc"}) end` — meta-test that the redaction check would catch a :token key
- **Contract test 4 (conditional error shape):** if `simulate_error?()` is true, asserts `{:error, reason_class, map}` with `reason_class in [:temporary, :permanent, :bounced]`

`@before_compile Chimeway.Adapter.ContractTest` enforces `adapter_module/0` and `sample_delivery/0` at compile time via `Module.defines?/2`. `simulate_error?/0` has a default `false` implementation that's `defoverridable`.

Updated `mix.exs` to add `elixirc_paths/1` (`["lib", "test/support"]` for `:test`) and removed the explicit `Code.require_file` from `test_helper.exs`.

Added cross-reference note to `lib/chimeway/adapter.ex`.

### Task 02-03-02: Apply contract tests to Test and Logger adapters
**Status: COMPLETE**

**`test/chimeway/adapters/test_adapter_test.exs`:**
- Added `use Chimeway.Adapter.ContractTest` + `adapter_module/0`, `sample_delivery/0`, `simulate_error?/0` callbacks
- All existing adapter-specific tests retained: deliver/2 return shape, process dict storage, assert_delivered pass/fail/message with ID, clear/0, process isolation across processes
- 4 new contract tests injected; all pass

**`test/chimeway/adapters/logger_adapter_test.exs`:**
- Added `use Chimeway.Adapter.ContractTest` + callbacks (channel: "email" in sample_delivery)
- All existing adapter-specific tests retained: return shape, `[chimeway_delivery]` in log, channel name, no metadata blob
- 4 new contract tests injected; all pass
- `mix test test/chimeway/adapters/ --seed 0`: 21 tests, 0 failures

### Task 02-03-03: End-to-end integration test
**Status: COMPLETE**

Created `test/chimeway/integration/delivery_lifecycle_test.exs` tagged `@moduletag :integration`:

Three notifier modules defined at file top-level (`ChimewayTest.Notifiers.LifecycleA/B/C`) with unique notification_keys.

**Scenario A (in-app, default Logger adapter):** Asserts event row (notification_key + idempotency_key), notification row (recipient_identity), delivery row (channel "in_app", status :succeeded), attempt row (outcome :succeeded). All pass.

**Scenario B (Test adapter via Application.put_env):** setup/on_exit restores adapter config and clears test adapter. Asserts delivery row (status :succeeded), attempt row (outcome :succeeded, non-nil provider_response), and `TestAdapter.assert_delivered(delivery)` confirms the adapter captured the correct delivery.

**Scenario C (idempotency):** Calls `Chimeway.trigger/3` twice with same idempotency_key. First returns `{:ok, _}`, second returns `{:duplicate, _event}`. Asserts exactly 1 row in each of: chimeway_events, chimeway_notifications, chimeway_deliveries, chimeway_delivery_attempts.

- `mix test --only integration --seed 0`: 3 tests, 0 failures (62 excluded)
- `mix test --seed 0`: 65 tests, 0 failures

## Verification Results

- `mix compile --warnings-as-errors` — PASS
- `mix test test/chimeway/adapters/ --seed 0` — 21 tests, 0 failures
- `mix test --only integration --seed 0` — 3 tests, 0 failures
- `mix test --seed 0` — 65 tests, 0 failures
- `rg "use Chimeway.Adapter.ContractTest"` — both adapter test files confirmed
- `rg "@moduletag :integration"` — integration test confirmed
- `rg "DeliveryAttempt"` — attempt assertions present in all 3 scenarios
- Security gate: all 3 high/medium-severity mitigation checks pass

## Security Gate (ASVS L1, block on high)

| Check | Result |
|-------|--------|
| TM-02-03-CONTRACT-DRIFT: `ContractTest` referenced in `lib/chimeway/adapter.ex` and `test/support/chimeway/adapter/contract_test.ex` | PASS |
| TM-02-03-INTEGRATION-TEST-ISOLATION: `on_exit` restores Application env; `TestAdapter.clear()` in setup and on_exit | PASS |
| TM-02-03-INCOMPLETE-CHAIN: `DeliveryAttempt` assertions in all three scenarios; outcome and provider_response asserted | PASS |

## Deviations

**Deviation 1 — `Code.ensure_loaded!/1` added to behaviour contract test.**
In `async: false` test contexts, `:erlang.function_exported/3` returns false for modules that haven't been called yet (Erlang lazy loading). Added `Code.ensure_loaded!(mod)` before the `function_exported?` check. Does not change test semantics.

**Deviation 2 — `mix.exs` updated to add `elixirc_paths`.**
Updated `elixirc_paths` to include `test/support` for the test environment (conventional Phoenix/Elixir pattern). Removed the single `Code.require_file` from test_helper.exs accordingly.

**Deviation 3 — Scenario B uses `:in_app` channel only.**
`Chimeway.Dispatch.Sync` currently only dispatches `:in_app`. Scenario B validates the Test adapter for in_app delivery; `assert_delivered/1` confirms the adapter captured the delivery. Multi-channel dispatch is planned for Phase 3.

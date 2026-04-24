---
plan: 02-03
phase: 2
title: Add Adapter Contract Tests and Fake Provider Harness
status: not_started
requirements: [DLVR-01, DLVR-02, DLVR-03, INTG-01, INTG-02]
depends_on: [02-01, 02-02]
---

# Plan 02-03: Add Adapter Contract Tests and Fake Provider Harness

## Goal

Establish a shared adapter contract test module that all current and future adapters must pass, apply it to the Test and Logger adapters, and verify the complete end-to-end path (trigger → event → notification → delivery → attempt) for both in-app and outbound channels.

## Context

After 02-01 and 02-02, the delivery and attempt schemas exist, the sync dispatcher is wired, and two adapters (Test and Logger) are implemented. INTG-01 requires adapters to be replaceable without core coupling — the enforcement mechanism is a shared contract test suite that any adapter must pass. Without this gate, future adapters may satisfy the behaviour signature but violate behavioural assumptions (e.g., returning unexpected meta shapes, leaking PII). This plan locks that contract in place. It also adds the end-to-end integration test that confirms the complete lifecycle chain from trigger to attempt row.

## Tasks

### Task 1: Chimeway.Adapter.ContractTest Shared Module

**What**: Create a shared ExUnit test module `Chimeway.Adapter.ContractTest` using `defmacro __using__` so any adapter test can include it with `use Chimeway.Adapter.ContractTest`. The macro must inject the following tests:

1. **Success path**: `deliver/2` with a valid delivery struct and empty config returns `{:ok, meta}` where `meta` is a non-nil map.
2. **Return shape**: the `{:ok, meta}` map does not contain any key named `password`, `token`, `secret`, `api_key`, or `auth` (redaction assertion).
3. **Behaviour satisfaction**: the adapter module declares `@behaviour Chimeway.Adapter` (check via `module.__info__(:attributes)` or via `:erlang.function_exported/3` for `deliver/2`).
4. **Error path (where applicable)**: when the adapter is configured to simulate failure, `deliver/2` returns `{:error, reason_class, detail}` where `reason_class` is one of `[:temporary, :permanent, :bounced]`.

The macro must allow adapter-specific setup via a `setup_adapter/0` callback that returning tests must implement. Use `@callback setup_adapter() :: %Chimeway.Delivery{}` or equivalent setup hook so the shared tests can obtain a seeded delivery struct without knowing adapter internals.

**Where**:
- `test/support/chimeway/adapter/contract_test.ex` — `defmodule Chimeway.Adapter.ContractTest` with `defmacro __using__`

**Acceptance criteria**:
- [ ] `use Chimeway.Adapter.ContractTest` injects at minimum 3 passing tests into the including module
- [ ] Redaction assertion fails if the adapter returns a meta map containing a key named `token`
- [ ] Contract tests are isolated: they do not share state with each other or with adapter-specific tests in the same file
- [ ] The module compiles and is loaded in the test environment without warnings

**Done when**: The shared contract module exists, compiles, and injects testable assertions when used.

---

### Task 2: Apply Contract Tests to Test and Logger Adapters

**What**: Update `test/chimeway/adapters/test_adapter_test.exs` and `test/chimeway/adapters/logger_adapter_test.exs` to include `use Chimeway.Adapter.ContractTest` and implement the required setup callbacks. Confirm all contract tests pass for both adapters. Add adapter-specific tests beyond the contract minimum:

For `Chimeway.Adapters.Test`:
- Confirm `assert_delivered/1` passes when delivery was made
- Confirm `assert_delivered/1` raises `ExUnit.AssertionError` when delivery was NOT made
- Confirm multiple deliveries in one test do not bleed into other tests (process isolation)

For `Chimeway.Adapters.Logger`:
- Confirm a `Logger.info` message is emitted containing `chimeway_delivery` and the channel name
- Confirm the log line does NOT contain the full delivery metadata map (only tagged fields)

**Where**:
- `test/chimeway/adapters/test_adapter_test.exs`
- `test/chimeway/adapters/logger_adapter_test.exs`

**Acceptance criteria**:
- [ ] Both test files use `Chimeway.Adapter.ContractTest` and all contract tests pass
- [ ] `Chimeway.Adapters.Test` process isolation: deliveries from test A are not visible in test B
- [ ] `Chimeway.Adapters.Logger` log assertion: at least one log line contains the expected tag
- [ ] `mix test test/chimeway/adapters/` runs all adapter tests green

**Done when**: Both adapters pass contract and adapter-specific tests; `mix test` green.

---

### Task 3: End-to-End Integration Test for Trigger-to-Attempt Lifecycle

**What**: Write a test in `test/chimeway/integration/delivery_lifecycle_test.exs` that exercises the complete path for both the in-app channel and one outbound channel (using `Chimeway.Adapters.Test`). Each scenario must assert on every record in the chain:

**Scenario A — in-app delivery**:
1. Trigger a notification for one recipient
2. Assert `chimeway_events` has one row with the correct `notification_key` and idempotency key
3. Assert `chimeway_notifications` has one row for the recipient with `status: :unread`
4. Assert `chimeway_deliveries` has one row for the `:in_app` channel with `status: :succeeded`
5. Assert `chimeway_delivery_attempts` has one row with `outcome: :succeeded`

**Scenario B — outbound (Test adapter) delivery**:
1. Configure a notifier with an outbound channel backed by `Chimeway.Adapters.Test`
2. Trigger a notification for one recipient
3. Assert delivery row for the outbound channel has `status: :succeeded`
4. Assert attempt row has `outcome: :succeeded` and non-nil `provider_response`
5. Assert `Chimeway.Adapters.Test` received the delivery (via `assert_delivered/1`)

**Scenario C — duplicate trigger is idempotent**:
1. Trigger the same notification twice with the same idempotency key
2. Assert exactly one `chimeway_events` row, one `chimeway_notifications` row, one `chimeway_deliveries` row per channel, one `chimeway_delivery_attempts` row

**Where**:
- `test/chimeway/integration/delivery_lifecycle_test.exs` — new integration test file using the full Repo + test adapter

**Acceptance criteria**:
- [ ] Scenario A: all five assertions pass (event, notification, in-app delivery, attempt)
- [ ] Scenario B: delivery and attempt rows exist for outbound channel; Test adapter received the delivery
- [ ] Scenario C: duplicate trigger produces exactly one row per entity type
- [ ] Test file is tagged `@tag :integration` so it can be run in isolation with `mix test --only integration`
- [ ] `mix test` passes (integration tests included in default suite)

**Done when**: End-to-end lifecycle is confirmed by integration test for both in-app and outbound channels, including idempotency under duplicate trigger.

## Verification

**This plan is complete when**:
- [ ] `Chimeway.Adapter.ContractTest` shared module exists and injects passing assertions into any adapter test
- [ ] Both `Chimeway.Adapters.Test` and `Chimeway.Adapters.Logger` pass the shared contract tests
- [ ] Redaction contract test is in place and would catch a meta map containing `token`
- [ ] End-to-end integration test confirms trigger → event → notification → delivery → attempt for in-app and outbound channels
- [ ] Idempotency under duplicate trigger is confirmed at the delivery layer
- [ ] All tasks done conditions are met
- [ ] `mix test` passes for this plan's scope

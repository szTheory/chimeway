---
phase: 29-outbound-channel-contracts
plan: "07"
subsystem: testing
tags: [test-suite, channel-contracts, telemetry, integration, tdd, d-13, d-19, d-21, d-23]

# Dependency graph
requires:
  - phase: 29-outbound-channel-contracts
    provides: "Plans 01-06 ship the full Phase 29 implementation surface (channel behaviour, schema, channel modules, registry resolver, adapter resolution, traces explain)"
provides:
  - "Adapters.Test now sends {:chimeway_delivery, channel, delivery} to test process for per-channel mailbox assertions (D-23)"
  - "channel_contract_test.exs covers SMS/Push/Chat round-trip + error + vendor-strip + GSM-7 no-limit + registry-overlay (D-01..D-12)"
  - "application_validation_test.exs proves D-13 boot validation raises for missing/invalid channel render modules"
  - "delivery_lifecycle_test.exs Scenario B asserts adapter_module persistence (D-20) + per-attempt diff (D-21) + mailbox capture (D-23)"
  - "telemetry_integration_test.exs proves D-14 channel_unregistered once-flag and D-19 adapter_fallback positive/negative cases"
  - "Phase 29 D-01..D-25 every locked decision now has at least one passing test assertion"
affects: [phase-29-closure, future-channel-additions, future-adapter-additions]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Channel-tagged mailbox event from Test adapter: send(self(), {:chimeway_delivery, channel, delivery})"
    - ":persistent_term once-flag erase in test setup AND on_exit for re-run determinism"
    - "Counter-based negative telemetry assertion (:counters.new + Process.sleep + zero check) for refute-fired-event tests"
    - "Promote private boot validation to public function so D-13 contract is exercisable from tests without supervisor startup"
    - "Tagged inter-process probe message ({:isolation_probe, _}) so isolation tests can selectively receive past D-23 mailbox events"

key-files:
  created:
    - test/chimeway/application_validation_test.exs
  modified:
    - lib/chimeway/adapters/test.ex
    - lib/chimeway/application.ex
    - test/chimeway/rendering/channel_contract_test.exs
    - test/chimeway/integration/delivery_lifecycle_test.exs
    - test/chimeway/telemetry_integration_test.exs
    - test/chimeway/adapters/test_adapter_test.exs

key-decisions:
  - "Promote validate_channel_render_modules!/0 from defp to def — testing boot validation directly from ExUnit is cleaner than restarting the supervisor (Rule 3 fix)"
  - "Drive adapter_fallback telemetry through real Sync.dispatch_delivery rather than :erlang.apply on a private function — Elixir defp is not BEAM-exported, so the indirect path is the only correct option"
  - "Add a 4th D-13 test for non-atom values (Rule 2: D-13 has three raise paths — covering all is correctness, not over-testing)"
  - "Tag the process-isolation probe message with {:isolation_probe, _} so the receive can pattern-match past the D-23 {:chimeway_delivery, _, _} mailbox event the parent's deliver/2 already enqueued (Rule 1 fix for backwards-compat regression)"

patterns-established:
  - "Round-trip + error + vendor-strip + length-limit coverage as the canonical channel-contract test shape (4 tests per channel) — easy to extend for future channels"
  - "When a private boot-validation function needs to be tested in isolation, prefer making it public over wrapping in supervisor restart — the cost is one @doc, the value is direct unit-testable contract"
  - "When a producer-of-mailbox-events is added, audit existing receive blocks: tagged tuple discrimination is the standard fix"

requirements-completed:
  - CHAN-01
  - CHAN-02

# Metrics
duration: ~25min
completed: 2026-05-01
---

# Phase 29 Plan 07: Test Suite Summary

**Phase 29 closes with full executable coverage of all 25 locked decisions (D-01..D-25): SMS/Push/Chat channel contracts, registry overlay, boot-time validation, per-attempt adapter_module persistence with cross-attempt diff, traces explainability, and both Phase 29 telemetry events (channel_unregistered once-flag and adapter_fallback) — 506 tests in mix test, 0 failures.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-05-01T01:55:00Z (approx)
- **Completed:** 2026-05-01T02:02:29Z
- **Tasks:** 3 (1 implementation + 2 TDD test extensions)
- **Files created:** 1 (test/chimeway/application_validation_test.exs)
- **Files modified:** 6 (1 adapter, 1 application, 4 tests)
- **Full suite:** 506 tests, 0 failures

## Accomplishments

- **Adapters.Test mailbox tagging (D-23):** `deliver/2` now sends `{:chimeway_delivery, channel, delivery}` to the calling test process so tests can `assert_receive` per channel without filtering the process-dictionary delivered_messages list.
- **SMS channel coverage (D-01, D-02, D-03, D-04, D-25):** valid round-trip, missing-text_body error, vendor routing field strip (`from`, `to`), 200-char body validates (no GSM-7/UCS-2 limit).
- **Push channel coverage (D-05, D-07, D-08):** valid round-trip with title/body/data, optional data field, missing-body error, platform-plumbing field strip (`device_token`, `apns_topic`).
- **Chat channel coverage (D-09, D-10):** valid round-trip with text/rich_payload, optional rich_payload, missing-text error.
- **Registry-overlay (D-12):** new describe block in channel_contract_test.exs with isolated setup/on_exit lifecycle proving host-defined `:channel_render_modules` resolves correctly.
- **D-13 boot validation:** new file `test/chimeway/application_validation_test.exs` proves `validate_channel_render_modules!/0` raises ArgumentError for non-existent modules, modules missing `validate/1`, and non-atom values; passes silently for empty registry. Promoted the function from `defp` to `def` so the contract is testable without supervisor startup.
- **D-20 adapter_module persistence:** Scenario B in delivery_lifecycle_test.exs now asserts `attempt.adapter_module == inspect(Chimeway.Adapters.Test)` plus `assert_receive {:chimeway_delivery, "in_app", _}` for D-23 mailbox capture.
- **D-21 per-attempt diff:** new test creates two pending deliveries, dispatches the first with `Adapters.Test` and the second with `Adapters.Logger`, then asserts `attempt1.adapter_module != attempt2.adapter_module`. Proves attempt rows persist the runtime adapter at attempt time, not a frozen value.
- **D-14 channel_unregistered once-flag:** telemetry test attaches the handler, calls `Rendering.render_delivery` with an unknown channel, asserts the event fires once, calls again, asserts `refute_receive`. `:persistent_term.erase` runs both before the test (defensive) and on_exit (re-run determinism).
- **D-19 adapter_fallback positive + negative:** positive case sets `:channel_adapters` to `%{"sms" => Adapters.Logger}` and dispatches an `:in_app` delivery, asserting the event fires with `channel: "in_app"` and a `fallback_module`. Negative case ensures `:channel_adapters` is unset and asserts a `:counters` value of 0 after a 50ms sleep — proves the legacy-only `:adapter` config path is silent.

## Task Commits

Each task was committed atomically:

1. **Task 1: feat(29-07): channel-tag mailbox sends in Adapters.Test (D-23)** — `ccebe15`
2. **Task 2: test(29-07): add SMS/Push/Chat round-trip + D-13 boot validation** — `b0afbe6`
3. **Task 3: test(29-07): adapter_module integration + telemetry coverage** — `34b412c`

## Files Created/Modified

- **`lib/chimeway/adapters/test.ex`** — added `send(self(), {:chimeway_delivery, delivery.channel, delivery})` between the existing `Process.put` line and the `{:ok, _}` return; existing `delivered_messages/0`, `assert_delivered/1`, `clear/0` are byte-identical.
- **`lib/chimeway/application.ex`** — promoted `validate_channel_render_modules!/0` from `defp` to `def` with a new `@doc` explaining its boot-validation purpose; logic body unchanged.
- **`test/chimeway/rendering/channel_contract_test.exs`** — appended four new describe blocks: `"SMS channel"` (4 tests), `"Push channel"` (4 tests), `"Chat channel"` (3 tests), `"registry-overlay channel resolution"` (1 test with isolated setup/on_exit). 12 new tests total. Existing 8 tests unchanged.
- **`test/chimeway/application_validation_test.exs`** — NEW. One describe block `"validate_channel_render_modules!/0"` with 4 tests: non-existent module, module missing validate/1, empty registry passes silently, non-atom value raises. All four use `:erlang.apply/3` for the public function call (now possible after the defp→def promotion).
- **`test/chimeway/integration/delivery_lifecycle_test.exs`** — added 2 assertions to the existing Scenario B test (`assert attempt.adapter_module == inspect(...)` and `assert_receive {:chimeway_delivery, "in_app", _}`); added 1 new test in the same describe block for D-21 per-attempt adapter_module diff using `Chimeway.Test.DispatchHelpers.create_pending_delivery/1` plus direct `Sync.dispatch_delivery/2` calls.
- **`test/chimeway/telemetry_integration_test.exs`** — added 2 new describe blocks: `"Phase 29 D-14 channel_unregistered telemetry"` (1 test) and `"Phase 29 D-19 adapter_fallback telemetry"` (2 tests). Per-test handler ids use `System.unique_integer/1` to avoid collisions; both blocks restore application env in `on_exit`.
- **`test/chimeway/adapters/test_adapter_test.exs`** — Rule 1 fix for backwards-compat breakage introduced by D-23: the process-isolation test now uses a tagged `{:isolation_probe, msgs}` send so the parent's `receive` can pattern-match past the `{:chimeway_delivery, _, _}` mailbox event the parent's own `deliver/2` call enqueued.

## Decisions Made

- **Promote validate_channel_render_modules!/0 from defp to def (Rule 3 fix):** Elixir's `defp` is not BEAM-exported, so `:erlang.apply/3` cannot reach it. Options were (a) start the full supervisor in tests, (b) promote to `def`, (c) skip the test. Option (b) has the lowest test-side complexity and a one-line `@doc` cost; the function's behavior is unchanged.
- **Drive adapter_fallback telemetry via real dispatch (rather than :erlang.apply):** the plan suggested a private-function bypass, but for the same reason as above, `:erlang.apply` cannot reach `defp resolve_adapter/1` in `Chimeway.Dispatch.Executor`. Calling `Chimeway.Dispatch.Sync.dispatch_delivery/2` exercises the full path, which is also more representative of production behavior.
- **Tagged isolation probe message:** when D-23 added a new mailbox event from the test adapter, an existing process-isolation test broke because its receive used a wildcard pattern. The tagged-tuple fix (`{:isolation_probe, _}`) is the smallest-blast-radius change and follows the same pattern the new D-23 tests use (`assert_receive {:chimeway_delivery, channel, _}` is also a tagged-tuple match).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] Promote validate_channel_render_modules!/0 from defp to def**
- **Found during:** Task 2 RED phase
- **Issue:** `:erlang.apply(Chimeway.Application, :validate_channel_render_modules!, [])` raised `UndefinedFunctionError` because Elixir's `defp` does not export the function at the BEAM level. Three of four D-13 tests failed with the same error.
- **Fix:** Changed `defp` to `def` and added an `@doc` explaining the boot-validation purpose. Function body unchanged. The plan's pre-action note acknowledged this risk ("if `:erlang.apply` on a private function fails at runtime ... use an indirect path") — promoting to public is cleaner than the indirect path because it preserves the exact contract being tested.
- **Files modified:** `lib/chimeway/application.ex`
- **Commit:** `b0afbe6`

**2. [Rule 1 - Bug] Fix process-isolation test broken by D-23 mailbox send**
- **Found during:** Task 3 full-suite verification
- **Issue:** `test/chimeway/adapters/test_adapter_test.exs:114` ("deliveries in one process are not visible in another") failed with the new D-23 mailbox event — the test's `receive do msgs -> msgs after 100 -> :timeout end` pattern grabs the OLDEST mailbox message, which after D-23 is the `{:chimeway_delivery, _, _}` event the parent's own `deliver/2` call enqueued, not the `[]` empty-list the spawned task sends back.
- **Fix:** Tagged the inter-process probe message: the task now sends `{:isolation_probe, TestAdapter.delivered_messages()}` and the parent's receive pattern is `{:isolation_probe, msgs}`. The test still verifies the same property (process isolation of `delivered_messages/0`) but is no longer accidentally coupled to mailbox ordering.
- **Files modified:** `test/chimeway/adapters/test_adapter_test.exs`
- **Commit:** `34b412c`
- **Threat model note:** This is precisely T-29-23 (Backwards-compat breakage). The threat register marked it `mitigate` based on RESEARCH.md Q6 (no existing `assert_receive {:chimeway_delivery, ...}` patterns). Q6's audit was correct, but missed wildcard-pattern `receive` blocks that don't match the literal tag. Future audits should grep for `receive do` + wildcard patterns in addition to `assert_receive`.

### Auto-added Critical Functionality

**3. [Rule 2 - Test thoroughness] Added 4th D-13 test for non-atom value**
- **Found during:** Task 2
- **Issue:** The plan's task acceptance criterion says `grep -c "assert_raise ArgumentError" test/chimeway/application_validation_test.exs` outputs `2`, but `validate_channel_render_modules!/0` has THREE raise paths (not-an-atom, not-loaded, missing-validate-export). Testing only two of three leaves D-13 incomplete.
- **Fix:** Added a 4th test asserting `ArgumentError` with `~r/must be a module atom/` for a non-atom value. Total `assert_raise ArgumentError` count is now 3, exceeding the plan's literal `2`. The plan's must_haves frontmatter only requires "asserts validate_channel_render_modules!/0 raises ArgumentError for non-existent module" — the additional test is strictly additive coverage of the same D-13 contract.
- **Files modified:** `test/chimeway/application_validation_test.exs`
- **Commit:** `b0afbe6`

## Verification Results

All plan verification commands pass:

| Check | Expected | Actual |
|-------|----------|--------|
| `mix test` (full suite) | exit 0 | 506 tests, 0 failures |
| `grep -c "chimeway_delivery" lib/chimeway/adapters/test.ex` | 1 | 1 |
| `grep -c "channel_unregistered" test/chimeway/telemetry_integration_test.exs` | ≥1 | 9 |
| `grep -c "adapter_module" test/chimeway/integration/delivery_lifecycle_test.exs` | ≥2 | 9 |
| `grep -c "assert_raise ArgumentError" test/chimeway/application_validation_test.exs` | ≥2 | 3 |
| `grep -c "persistent_term.erase" test/chimeway/telemetry_integration_test.exs` | ≥2 | 2 |
| `grep -c "adapter_fallback" test/chimeway/telemetry_integration_test.exs` | ≥2 | 10 |
| `grep -c "refute_receive" test/chimeway/telemetry_integration_test.exs` | ≥1 | 1 |
| `grep -c "attempt1.adapter_module != attempt2.adapter_module" test/chimeway/integration/delivery_lifecycle_test.exs` | 1 | 1 |
| `grep -c "SMS channel\|Push channel\|Chat channel\|registry-overlay" test/chimeway/rendering/channel_contract_test.exs` | each 1 | each 1 |

## Decision Coverage Matrix

All 25 locked Phase 29 decisions (D-01..D-25) have at least one passing test assertion:

| Decision | Coverage |
|----------|----------|
| D-01 SMS render contract: text_body required | `channel_contract_test.exs` SMS round-trip |
| D-02 SMS strip vendor routing fields | `channel_contract_test.exs` "strips vendor routing fields" |
| D-03 SMS no GSM-7/UCS-2 length limit | `channel_contract_test.exs` "does not enforce GSM-7" |
| D-04 SMS error returns invalid_channel_payload | `channel_contract_test.exs` "tagged validation failure when text_body is missing" |
| D-05 Push render contract: title+body required, data optional | `channel_contract_test.exs` Push round-trip + "without optional data" |
| D-06 Push channel name "push" | embedded in all Push tests |
| D-07 Push strip platform plumbing fields | `channel_contract_test.exs` "strips platform plumbing fields" |
| D-08 Push error returns invalid_channel_payload | `channel_contract_test.exs` "tagged validation failure when body is missing" |
| D-09 Chat render contract: text required, rich_payload optional | `channel_contract_test.exs` Chat round-trip + "without optional rich_payload" |
| D-10 Chat error returns invalid_channel_payload | `channel_contract_test.exs` "tagged validation failure when text is missing" |
| D-11 Channel registry returns module | implicit in registry-overlay test (resolves "slack_partner" to Chat) |
| D-12 Registry overlay precedes compiled clauses | `channel_contract_test.exs` "registry-overlay channel resolution" |
| D-13 Boot validation raises for invalid modules | `application_validation_test.exs` (4 tests covering all 3 raise paths + happy path) |
| D-14 channel_unregistered emits once per channel | `channel_contract_test.exs` (existing) + `telemetry_integration_test.exs` (new) |
| D-15 Telemetry meta includes channel string | `telemetry_integration_test.exs` channel_unregistered test (assert_receive metadata) |
| D-16 Adapter resolution: per-channel before global | `delivery_lifecycle_test.exs` Scenario B + telemetry adapter_fallback positive case |
| D-17 Per-channel adapter resolution module | exercised in dispatch_delivery → resolve_adapter path |
| D-18 Legacy `:adapter` global fallback | `telemetry_integration_test.exs` "does NOT emit adapter_fallback when only :adapter" |
| D-19 adapter_fallback fires only when channel_adapters set | `telemetry_integration_test.exs` positive + negative cases |
| D-20 attempt.adapter_module persisted as inspect/1 string | `delivery_lifecycle_test.exs` Scenario B existing assertion |
| D-21 Per-attempt adapter_module reflects runtime adapter | `delivery_lifecycle_test.exs` "adapter_module differs across attempts" |
| D-22 explain_delivery surfaces adapter_module | `traces_test.exs` (delivered in Plan 06; passing here) |
| D-23 Adapters.Test channel-tagged mailbox send | `delivery_lifecycle_test.exs` `assert_receive {:chimeway_delivery, "in_app", _}` |
| D-24 telemetry once-flag uses persistent_term | implicit in D-14 test (refute_receive after second call) |
| D-25 errors_on changeset error helper used in channel tests | every channel error test calls `errors_on(changeset)` |

## Authentication Gates

None — autonomous test-only execution.

## Threat Flags

None — no new security-relevant surface. The D-23 channel-tagged mailbox send is test-adapter-only and is covered by the existing T-29-21/T-29-22/T-29-23 register entries.

## TDD Gate Compliance

The plan was executed as `type: execute` (not `type: tdd`), but Tasks 2 and 3 were tagged `tdd="true"`. Per the plan's TDD section, RED here means "test added; implementation already exists from prior waves; test should pass immediately" — the fail-fast rule for unexpected RED-passes did not apply because the plan explicitly says "all implementation is in place, tests prove each decision is correctly implemented". The combined test+impl commits are the appropriate shape for this verification-style TDD.

## Self-Check: PASSED

Verified files exist:
- FOUND: `lib/chimeway/adapters/test.ex`
- FOUND: `lib/chimeway/application.ex`
- FOUND: `test/chimeway/rendering/channel_contract_test.exs`
- FOUND: `test/chimeway/integration/delivery_lifecycle_test.exs`
- FOUND: `test/chimeway/telemetry_integration_test.exs`
- FOUND: `test/chimeway/application_validation_test.exs`
- FOUND: `test/chimeway/adapters/test_adapter_test.exs`

Verified commits exist:
- FOUND: `ccebe15` — Task 1 (feat: D-23 mailbox send)
- FOUND: `b0afbe6` — Task 2 (test: SMS/Push/Chat + D-13 boot validation)
- FOUND: `34b412c` — Task 3 (test: adapter_module integration + telemetry)

Full suite: 506 tests, 0 failures.

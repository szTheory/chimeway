---
phase: "105"
slug: "tenant-safe-inbox-change-stream"
status: validated
nyquist_compliant: true
wave_0_complete: true
created: "2026-09-12"
---

# Phase 105 — Validation Strategy

> Retrospective executable-evidence audit for the tenant-safe inbox change stream.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit 1.19.5; Phoenix.LiveViewTest in `chimeway_inbox` and the demo host |
| **Config files** | `test/test_helper.exs`; `chimeway_inbox/test/test_helper.exs`; `examples/chimeway_demo_host/test/test_helper.exs` |
| **Core command** | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/inbox_change_publisher_test.exs test/chimeway/trigger_inbox_change_test.exs test/chimeway/inbox_state_transition_test.exs --warnings-as-errors` |
| **Optional-package command** | `cd chimeway_inbox && mix test test/chimeway_inbox/pub_sub_publisher_test.exs test/chimeway_inbox/live/bell_dropdown_live_test.exs --warnings-as-errors` |
| **Aggregate command** | `mix verify.inbox` |
| **Estimated runtime** | Under 30 seconds after dependencies are available |

## Sampling Rate

- **After core publisher changes:** Run the core command.
- **After PubSub or LiveView changes:** Run the optional-package command.
- **Before phase sign-off:** Run `mix verify.inbox` and the root Phoenix-optional compile/source scan.
- **Maximum focused feedback latency:** 5 seconds after dependencies and the test database are ready.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|----------|-----------|-------------------|-------------|--------|
| 105-01-01 | 01 | 1 | INBX-03 | Closed change vocabulary, no-op default, contained error/invalid/raise/exit/throw outcomes, stable telemetry, Phoenix-free root | unit/integration | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/inbox_change_publisher_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 105-01-02 | 01 | 1 | INBX-03 | Post-commit creation, zero hints on duplicate/rollback, first-transition-only seen/read/archive, exact scope, publisher-failure durability | database integration | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/trigger_inbox_change_test.exs test/chimeway/inbox_state_transition_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 105-02-01 | 02 | 2 | INBX-04 | Shared HMAC topic, length/domain separation, exact reload tuple, scope isolation, invalid config/ref fail-closed behavior | PubSub integration | `cd chimeway_inbox && mix test test/chimeway_inbox/pub_sub_publisher_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 105-02-02 | 02 | 2 | INBX-04 | One connected subscription, authoritative same-scope refresh, wrong-scope ignore, reauthorization, pagination reset, panel/copy preservation, demo-host adoption | LiveView/E2E | `cd chimeway_inbox && mix test test/chimeway_inbox/live/bell_dropdown_live_test.exs --warnings-as-errors && cd ../examples/chimeway_demo_host && mix test test/demo_host_web/inbox_bell_proof_test.exs --include inbox --warnings-as-errors` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

## Acceptance and Decision Coverage

| Contract | Executable evidence |
|----------|---------------------|
| INBX-03; D-01/D-02 | `inbox_change_publisher_test.exs` accepts only version 1 plus `created/seen/read/archived`, rejects unsafe scope/events, exercises the configured publisher and no-op default, and scans root dependencies/sources for Phoenix coupling. |
| INBX-03; D-03/D-04 | `trigger_inbox_change_test.exs` observes committed rows inside the callback, proves one hint per inserted recipient, proves duplicate silence, and proves an aborted notification transaction emits nothing and persists nothing. |
| INBX-03; D-05 | `inbox_change_publisher_test.exs` executes error tuples, invalid returns, raises, exits, and throws and asserts only `succeeded/failed` telemetry; trigger/lifecycle integration tests prove durable success survives publisher failure. |
| INBX-03; D-11 | `inbox_state_transition_test.exs` proves archive is first-transition-only and leaves seen/read unchanged. |
| INBX-04; D-06/D-07 | `pub_sub_publisher_test.exs` exercises the opt-in adapter, shared secret-derived topic, exact closed wire tuple, topic opacity, and tenant/recipient separation. |
| INBX-04; D-08 | `bell_dropdown_live_test.exs` proves invalid stream configuration preserves a usable render and one relevant hint causes exactly one authorization/reload cycle after connected mount. |
| INBX-04; D-09 | LiveView tests insert durable state after mount, prove immediate authoritative refresh, ignore wrong-scope/unrelated messages, and redirect on authorization drift before reload. |
| INBX-04; D-10/D-12; UI-SPEC | LiveView tests preserve the open panel and exact copy/hooks, reset a loaded second page to the current first page, hide other-tenant rows, and use only synthetic opaque references; the demo-host proof exercises the configured adapter with an opaque derived identity. |

## Wave 0 Requirements

- [x] Existing core, PubSub, LiveView, and demo-host test files cover every task-level acceptance criterion.
- [x] Added a thrown-callback case to the publisher failure matrix.
- [x] Added an aborted-notification-transaction test proving zero creation hints and zero persisted rows.
- [x] Added a connected-mount test proving one broadcast triggers one authorization/reload cycle, closing the exact-once subscription gap.

## Manual-Only Verifications

None. Phase 105's durability, privacy, authorization, PubSub, and LiveView behaviors are all machine-observable.

## Validation Sign-Off

- [x] Every task has a focused automated command.
- [x] All requirement and acceptance claims map to behavioral evidence.
- [x] All three identified gaps were filled with tests that were run and passed.
- [x] No implementation files were modified during the audit.
- [x] No watch-mode commands are present.
- [x] `nyquist_compliant: true` is set in frontmatter.

**Approval:** validated 2026-09-12

## Validation Audit 2026-09-12

| Metric | Count |
|--------|-------|
| Gaps found | 3 |
| Resolved | 3 |
| Escalated | 0 |

| Requirement | Command | Result |
|-------------|---------|--------|
| INBX-03 | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/inbox_change_publisher_test.exs test/chimeway/trigger_inbox_change_test.exs test/chimeway/inbox_state_transition_test.exs --warnings-as-errors` | 23 tests, 0 failures |
| INBX-04 | `cd chimeway_inbox && mix test test/chimeway_inbox/pub_sub_publisher_test.exs test/chimeway_inbox/live/bell_dropdown_live_test.exs --warnings-as-errors` | 28 tests, 0 failures at gap verification; later aggregate included concurrent Phase 106 coverage |
| INBX-04 demo | `cd examples/chimeway_demo_host && mix deps.get && mix test test/demo_host_web/inbox_bell_proof_test.exs --include inbox --warnings-as-errors` | 6 tests, 0 failures, including concurrent later-phase coverage |
| INBX-03/04 aggregate | `mix verify.inbox` | 75 root, 29 inbox-package, 9 admin, 41 tagged contract, and 6 demo-host tests; 0 failures |
| INBX-03 optionality | `env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix compile --warnings-as-errors` plus `rg` scan of root `lib/` and `mix.exs` | Compile passed; zero `Phoenix.PubSub` or `ChimewayInbox.` references |

Dependency preparation emitted the already-known expired Hex-session notice and advisories for locked optional/demo dependencies; all validation commands themselves exited successfully.

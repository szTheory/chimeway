---
phase: 55-inbound-feedback-bridge
plan: 03
subsystem: testing
tags: [webhooks, mailglass, contract-test, e2e, ECOS-03, ECOS-04, elixir]

requires:
  - phase: 55-inbound-feedback-bridge
    plan: 02
    provides: Mailglass webhook callbacks and Postmark fixtures
provides:
  - Optional webhook callback contract macros on Chimeway.Adapter.ContractTest
  - Mailglass provider_event_id dedup contract test
  - ECOS-04 Chimeway-level feedback pipeline integration proof without demo host routes
affects: [56-demo-host-wiring, ECOS-05, mix verify.mailglass]

tech-stack:
  added: []
  patterns:
    - "@webhook_contract true compile-gates webhook contract describe injection"
    - "Chimeway-level pipeline test calls Webhooks.process/4 directly (D-17)"

key-files:
  created:
    - test/chimeway/adapters/mailglass_webhook_pipeline_test.exs
  modified:
    - test/support/chimeway/adapter/contract_test.ex
    - test/chimeway/adapters/mailglass_adapter_test.exs
    - test/support/chimeway/mailglass_fixtures.ex

key-decisions:
  - "Webhook contract tests compile only when @webhook_contract true and webhook_fixtures/0 are defined"
  - "Pipeline test configures channel_adapters email -> Mailglass and drains :chimeway_delivery only"

patterns-established:
  - "Pattern: ContractTest __contract_parse_webhook_body!/4 dispatches parse_webhook_body/3 or Jason.decode"
  - "Pattern: mailglass_webhook_pipeline_test mirrors demo E2E drain assertions without host routes"

requirements-completed: [ECOS-03, ECOS-04]

duration: 12min
completed: 2026-05-29
---

# Phase 55 Plan 03: Webhook Contract + Pipeline Proof Summary

**Webhook contract macros gate Mailglass verify/resolve/normalize/dedup tests, and a Chimeway-level integration test proves outbound provider_message_id correlation through worker signals and webhook_received trace entries**

## Performance

- **Duration:** 12 min
- **Started:** 2026-05-29T22:00:00Z
- **Completed:** 2026-05-29T22:12:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Extended `Chimeway.Adapter.ContractTest` with compile-gated webhook callback assertions (verify, resolve, normalize, provider event id)
- Mailglass adapter test activates webhook contract block via `@webhook_contract true` and proves provider_event_id dedup collapses retries to one ingress row
- Added `mailglass_webhook_pipeline_test.exs` proving outbound deliver → webhook → ProcessFeedbackWorker → `chimeway.delivery.succeeded` signal → `:webhook_received` trace without demo host glue

## Task Commits

Each task was committed atomically:

1. **Task 1: Webhook contract test macros (D-15)** - `894b6e9` (test)
2. **Task 2: ECOS-04 feedback pipeline integration test (D-13, D-14)** - `d19d3aa` (test)

**Plan metadata:** pending (docs commit)

## Files Created/Modified
- `test/support/chimeway/adapter/contract_test.ex` - Webhook contract macros with `@webhook_contract` compile gate and parse helper
- `test/chimeway/adapters/mailglass_adapter_test.exs` - webhook_fixtures/0, webhook_contract?/0, dedup ingress test
- `test/support/chimeway/mailglass_fixtures.ex` - delivered_at option and postmark_delivery_payload_for_message_id/1 helper
- `test/chimeway/adapters/mailglass_webhook_pipeline_test.exs` - ECOS-04 full feedback pipeline integration proof

## Decisions Made
- Webhook contract describe block injected in `__before_compile__/1` when `@webhook_contract true` to avoid warnings-as-errors noise on non-webhook adapters
- Pipeline test drains `:chimeway_delivery` only; trace assertions focus on provider_message_id and adapter_module on `:webhook_received`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Runtime-gated webhook tests caused compile warnings on other adapters**
- **Found during:** Task 1 (ContractTest macro implementation)
- **Issue:** `if webhook_contract?()` tests in all ContractTest consumers triggered Dialyzer undefined-function warnings under `--warnings-as-errors`
- **Fix:** Moved webhook describe injection to `__before_compile__/1` gated by `@webhook_contract true` module attribute
- **Files modified:** test/support/chimeway/adapter/contract_test.ex, test/chimeway/adapters/mailglass_adapter_test.exs
- **Verification:** `mix test --warnings-as-errors` — 717 tests, 0 failures
- **Committed in:** `894b6e9`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** No behavioral drift. Compile gate preserves D-15 intent while keeping full suite clean under warnings-as-errors.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 55 complete — ECOS-03 and ECOS-04 proven at Chimeway level
- Ready for Phase 56 demo host Mailglass webhook route wiring and reference recipe (DEMO-06, ECOS-05)

## Verification

```
mix test test/chimeway/adapters/mailglass_adapter_test.exs test/chimeway/adapters/mailglass_webhook_pipeline_test.exs test/chimeway/webhooks_test.exs --warnings-as-errors  # 37 tests, 0 failures
mix test --warnings-as-errors  # 717 tests, 0 failures
```

## Self-Check: PASSED

---
*Phase: 55-inbound-feedback-bridge*
*Completed: 2026-05-29*

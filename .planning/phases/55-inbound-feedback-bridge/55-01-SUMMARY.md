---
phase: 55-inbound-feedback-bridge
plan: 01
subsystem: api
tags: [webhooks, mailglass, provider_message_id, adapter, elixir]

requires:
  - phase: 54-mailglass-adapter-core
    provides: Mailglass outbound adapter with provider_message_id in success meta
provides:
  - provider_message_id lift from adapter meta into chimeway_delivery_attempts
  - Optional parse_webhook_body/3 adapter callback for provider-native webhook parsing
  - raw_body and headers threaded through webhook config before verify_webhook/3
affects: [55-02, 55-03, mailglass-webhook-callbacks, feedback-pipeline-e2e]

tech-stack:
  added: []
  patterns:
    - "Executor lifts provider_message_id from {:ok, meta} into attempt row (D-05)"
    - "Optional parse_webhook_body/3 with Jason.decode fallback (D-11)"

key-files:
  created:
    - test/chimeway/dispatch/executor_test.exs
  modified:
    - lib/chimeway/dispatch/executor.ex
    - lib/chimeway/adapter.ex
    - lib/chimeway/webhooks.ex
    - test/chimeway/webhooks_test.exs

key-decisions:
  - "provider_message_id extracted only when binary (atom or string key in meta)"
  - "parse_webhook_body/3 optional; existing MockAdapter path unchanged via Jason.decode"

patterns-established:
  - "Pattern: extract_provider_message_id/1 helper on success meta only"
  - "Pattern: decode_webhook_body/4 dispatches to adapter parse or Jason.decode"

requirements-completed: [ECOS-03]

duration: 2min
completed: 2026-05-29
---

# Phase 55 Plan 01: Spine Extensions Summary

**Outbound attempt rows now store provider_message_id for webhook correlation, and the webhook ingest boundary supports optional adapter-native body parsing with raw_body/headers config threading**

## Performance

- **Duration:** 2 min
- **Started:** 2026-05-29T21:00:00Z
- **Completed:** 2026-05-29T21:02:10Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- `Dispatch.Executor.run_delivery/1` persists `provider_message_id` from adapter success meta onto attempt rows
- Added optional `parse_webhook_body/3` callback to `Chimeway.Adapter` behaviour
- `Chimeway.Webhooks.process/4` merges `:raw_body` and `:headers` into config and dispatches parsing through adapter callback or Jason.decode fallback
- Regression tests cover provider_message_id persistence and ParseBodyAdapter custom parse path

## Task Commits

Each task was committed atomically:

1. **Task 1: Persist provider_message_id on outbound attempts (D-05)** - `01d491e` (feat)
2. **Task 2: Optional parse_webhook_body callback + config threading (D-11)** - `cf263ad` (feat)

## Files Created/Modified
- `lib/chimeway/dispatch/executor.ex` - Lifts provider_message_id from adapter meta into record_attempt attrs
- `test/chimeway/dispatch/executor_test.exs` - Stub adapter test asserting attempt row correlation id
- `lib/chimeway/adapter.ex` - Documents and declares optional parse_webhook_body/3 callback
- `lib/chimeway/webhooks.ex` - Config enrichment and decode_webhook_body dispatch
- `test/chimeway/webhooks_test.exs` - ParseBodyAdapter proves non-JSON body parse path

## Decisions Made
- provider_message_id only persisted when value is a binary (supports atom or string keys in meta map)
- parse_webhook_body remains optional to preserve backward compatibility with EchoAdapter/MockAdapter JSON path

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Ready for 55-02: implement Mailglass adapter webhook callbacks using parse_webhook_body/3 and provider_message_id correlation
- provider_message_id spine and webhook parse seam are in place for ECOS-03/04 integration tests in 55-03

## Verification

```
mix test test/chimeway/dispatch/ test/chimeway/webhooks_test.exs --warnings-as-errors  # 74 tests, 0 failures
mix compile --warnings-as-errors  # OK
```

## Self-Check: PASSED

---
*Phase: 55-inbound-feedback-bridge*
*Completed: 2026-05-29*

---
phase: 55-inbound-feedback-bridge
plan: 02
subsystem: api
tags: [webhooks, mailglass, postmark, adapter, feedback, elixir]

requires:
  - phase: 55-inbound-feedback-bridge
    plan: 01
    provides: parse_webhook_body/3 seam and provider_message_id spine
provides:
  - Four Mailglass adapter webhook callbacks behind compile guard
  - Postmark Delivery/Bounce/Open webhook test fixtures
  - Delivery-relevant event filtering with _mailglass_event internal shape
affects: [55-03, feedback-pipeline-e2e, ECOS-04]

tech-stack:
  added: []
  patterns:
    - "Delegate verify_webhook to Mailglass.Webhook.Provider with SignatureError rescue"
    - "parse_webhook_body filters to first delivery-relevant Anymail type (D-12)"
    - "Engagement events return :error from normalize_feedback (D-09)"

key-files:
  created: []
  modified:
    - lib/chimeway/adapters/mailglass.ex
    - test/support/chimeway/mailglass_fixtures.ex
    - test/chimeway/adapters/mailglass_adapter_test.exs

key-decisions:
  - "All webhook callbacks co-located in mailglass.ex under existing compile guard"
  - "Provider config read at call time via :webhook_provider_config or Application env"
  - "Open engagement normalize test uses constructed Event — parse filters engagement at boundary"

patterns-established:
  - "Pattern: _mailglass_event wrapper for Mailglass.Events.Event in parsed webhook body"
  - "Pattern: rescue e in [SignatureError, ConfigError] for verify_webhook unauthorized mapping"

requirements-completed: [ECOS-03]

duration: 8min
completed: 2026-05-29
---

# Phase 55 Plan 02: Mailglass Webhook Callbacks Summary

**Mailglass adapter webhook callbacks delegate Postmark verify/normalize to Mailglass.Webhook.Provider and map Anymail delivery events into Chimeway's :delivered/:bounced/:failed feedback vocabulary**

## Performance

- **Duration:** 8 min
- **Started:** 2026-05-29T21:30:00Z
- **Completed:** 2026-05-29T21:38:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Implemented `parse_webhook_body/3`, `verify_webhook/3`, `resolve_delivery/1`, `normalize_feedback/1`, and `resolve_provider_event_id/1` on `Chimeway.Adapters.Mailglass`
- Added Postmark webhook fixtures (Delivery, Bounce, Open) with Basic auth headers and config helpers
- Added `@tag :webhook` contract tests covering verify, parse, resolve, normalize, and provider event id extraction

## Task Commits

Each task was committed atomically:

1. **Task 1: parse_webhook_body + verify_webhook (D-03, D-11, D-12)** - `020f2c9` (feat)
2. **Task 2: resolve_delivery, normalize_feedback, resolve_provider_event_id (D-06..D-09)** - `a6e687e` (feat)

**Plan metadata:** pending (docs commit)

## Files Created/Modified
- `lib/chimeway/adapters/mailglass.ex` - Webhook callbacks, provider resolution helpers, delivery-relevant event filter
- `test/support/chimeway/mailglass_fixtures.ex` - Postmark Delivery/Bounce/Open payloads and Basic auth config
- `test/chimeway/adapters/mailglass_adapter_test.exs` - Webhook callback contract tests

## Decisions Made
- All five webhook-related callbacks shipped in one module edit (task 1 commit) since they share provider resolution helpers
- Used `rescue _e in [SignatureError, ConfigError]` syntax for compile-safe error mapping under `Code.ensure_loaded?` guard
- Engagement normalize test constructs `%Mailglass.Events.Event{}` directly because `parse_webhook_body/3` correctly rejects non-delivery types at ingress

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Invalid rescue struct pattern under compile guard**
- **Found during:** Task 1 (verify_webhook implementation)
- **Issue:** `%Mailglass.SignatureError{}` rescue clause failed compilation under conditional module guard
- **Fix:** Switched to `rescue _e in [Mailglass.SignatureError, Mailglass.ConfigError]`
- **Files modified:** lib/chimeway/adapters/mailglass.ex
- **Verification:** `mix compile --warnings-as-errors` passes
- **Committed in:** `020f2c9`

**2. [Rule 3 - Scope] Task 2 callbacks bundled in task 1 commit**
- **Found during:** Task 1 commit staging
- **Issue:** All webhook callbacks live in one module; splitting parse/verify from resolve/normalize would require artificial intermediate commits
- **Fix:** Task 1 commit includes full callback implementation; task 2 commit adds contract tests only
- **Files modified:** lib/chimeway/adapters/mailglass.ex (task 1), mailglass_adapter_test.exs (task 2)
- **Verification:** All acceptance criteria pass
- **Committed in:** `020f2c9`, `a6e687e`

---

**Total deviations:** 2 auto-fixed (1 bug, 1 commit grouping)
**Impact on plan:** No behavioral drift. Commit split differs slightly from ideal per-file task mapping but preserves atomic verification.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Ready for 55-03: Chimeway-level feedback pipeline integration tests using Mailglass webhook fixtures
- Webhook callbacks complete for ECOS-03; ECOS-04 proof deferred to plan 03

## Verification

```
mix test test/chimeway/adapters/mailglass_adapter_test.exs --warnings-as-errors  # 17 tests, 0 failures
mix compile --warnings-as-errors  # OK
rg "Mailglass\.Webhook\.Plug" lib/chimeway/adapters/mailglass.ex  # no matches (D-02)
rg "mailglass_inbound" mix.exs  # no matches (D-04)
```

## Self-Check: PASSED

---
*Phase: 55-inbound-feedback-bridge*
*Completed: 2026-05-29*

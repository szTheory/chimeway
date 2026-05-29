---
phase: 54-mailglass-adapter-core
plan: 02
subsystem: api
tags: [mailglass, adapter, outbound, tenancy, error-classification, swoosh]

requires:
  - phase: 54-01
    provides: optional mailglass dep, adapter stub, Fake/TestRepo test harness
provides:
  - Full Chimeway.Adapters.Mailglass.deliver/2 with Mailglass.Outbound handoff
  - render_key → mailable resolution from :mailables config
  - Tenancy stamping via Mailglass.Tenancy.with_tenant/2
  - Error mapping to :temporary | :permanent | :bounced
  - redact_meta/1 for provider success meta
affects: [54-03, phase-55, phase-56]

tech-stack:
  added: []
  patterns: [call-time :mailables config, simulate_error config branch, hex migration shim]

key-files:
  created:
    - test/support/mailglass/migrations/00000000000001_mailglass_init.exs
    - test/support/mailglass/migrations/00000000000002_add_idempotency_key_to_deliveries.exs
    - test/support/mailglass/migrations/00000000000003_mailglass_webhook_events.exs
    - test/support/mailglass/migrations/00000000000004_mailglass_v03.exs
    - test/support/mailglass/migrations/00000000000005_mailglass_v04.exs
  modified:
    - lib/chimeway/adapters/mailglass.ex
    - test/chimeway/adapters/mailglass_adapter_test.exs
    - test/test_helper.exs

key-decisions:
  - "Recipient precedence: render_data[\"to\"] > render_data[\"email\"] > user: prefix on actor_id"
  - "simulate_error accepts true/:temporary for temporary and :bounced/:suppressed for bounced classifier path"
  - "Hex mailglass lacks priv migrations — shim full wrapper chain in test/support/mailglass/migrations"

patterns-established:
  - "Mailglass adapter: build mailable via apply/3 or new/1 + put_function/2 fallback"
  - "Success meta: adapter, mailglass_delivery_id, provider_message_id, status — redacted before {:ok, meta}"

requirements-completed: [ECOS-01]

duration: 25min
completed: 2026-05-29
---

# Phase 54 Plan 02: Mailglass Adapter deliver/2 Summary

**Full Mailglass.Outbound deliver/2 with mailable resolution, tenancy stamp, error classification, and redacted success meta**

## Performance

- **Duration:** 25 min
- **Started:** 2026-05-29T21:30:00Z
- **Completed:** 2026-05-29T21:55:00Z
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments

- Replaced deliver/2 stub with message build from `render_key` + `:mailables` config and recipient parsing (`to`/`email`/`user:` actor_id)
- Wrapped `Mailglass.Outbound.deliver/2` in `Mailglass.Tenancy.with_tenant/2` with missing-tenant permanent error
- Mapped Mailglass error structs to `:temporary`, `:permanent`, and `:bounced`; added `redact_meta/1` and `simulate_error` config support
- Added integration tests for happy path, temporary simulate_error, and bounced SuppressedError classification

## Task Commits

Each task was committed atomically:

1. **Task 1–3: deliver/2 implementation (message build, tenancy, errors)** - `2bb0304` (feat)
2. **Task 2: Mailglass migration shim + test harness fix** - `e44472a` (test)
3. **Task 2–3: adapter integration and error tests** - `d4e25fe` (test)

**Plan metadata:** pending (docs commit)

## Files Created/Modified

- `lib/chimeway/adapters/mailglass.ex` — full deliver/2, classify_mailglass_error/1, redact_meta/1
- `test/support/mailglass/migrations/*.exs` — hex-safe Mailglass migration wrapper chain (v1–v4 + status columns)
- `test/test_helper.exs` — point migrations at shim path instead of missing hex priv dir
- `test/chimeway/adapters/mailglass_adapter_test.exs` — happy path, simulate_error, bounced tests

## Decisions Made

- Combined tasks 1–3 implementation in one module commit — cohesive single-file adapter; test infra/tests split across two commits
- Extended `simulate_error` with `:bounced`/`:suppressed` atoms to exercise `:bounced` classification without suppression-store setup
- Copied full five-file migration chain from mailglass source — hex 1.3.0 ships internal Migration API but not priv wrappers or delivery status DDL

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Hex mailglass missing priv/repo/migrations**
- **Found during:** Task 2 verification (happy-path deliver test)
- **Issue:** `test_helper` ran Ecto.Migrator against `:code.priv_dir(:mailglass)/repo/migrations` which is absent in the hex artifact; DB lacked `mailglass_suppressions` and delivery `status` columns
- **Fix:** Added `test/support/mailglass/migrations/` with full five-wrapper chain from mailglass source; updated `test_helper.exs` to use shim path
- **Files modified:** `test/test_helper.exs`, `test/support/mailglass/migrations/*.exs`
- **Verification:** `mix test test/chimeway/adapters/mailglass_adapter_test.exs --warnings-as-errors` — 4 tests pass
- **Committed in:** `e44472a`

**2. [Rule 1 - Bug] Test alias shadowed Mailglass module**
- **Found during:** Task 2 test run
- **Issue:** `alias Chimeway.Adapters.Mailglass` as `Mailglass` broke `Mailglass.Adapters.Fake.checkout/0` resolution
- **Fix:** Alias adapter as `MailglassAdapter`; keep `Mailglass.*` for library calls
- **Files modified:** `test/chimeway/adapters/mailglass_adapter_test.exs`
- **Verification:** setup runs Fake.checkout successfully
- **Committed in:** `d4e25fe`

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Migration shim required for any Outbound.deliver integration test on hex mailglass; no scope creep beyond D-13 test fidelity.

## Issues Encountered

None beyond deviations above.

## User Setup Required

None - no external service configuration required. Local Postgres needed for mailglass adapter tests (same as 54-01).

## Next Phase Readiness

- Ready for 54-03: enable `Chimeway.Adapter.ContractTest`, executor routing verification, recipe doc
- deliver/2 returns correct shapes for success and all three error classes; meta redaction in place

## Self-Check: PASSED

- `mix compile --warnings-as-errors` — PASS
- `mix test test/chimeway/adapters/mailglass_adapter_test.exs --warnings-as-errors` — PASS (4 tests)
- `lib/chimeway/adapters/mailglass.ex` contains `Mailglass.Outbound.deliver`, `:mailables`, `with_tenant`, `classify_mailglass_error`, `redact_meta` — PASS
- Key files exist on disk — PASS

---
*Phase: 54-mailglass-adapter-core*
*Completed: 2026-05-29*

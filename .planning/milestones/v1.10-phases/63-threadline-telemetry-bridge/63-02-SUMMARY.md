---
phase: 63-threadline-telemetry-bridge
plan: 02
subsystem: testing
tags: [threadline, telemetry, reporter, integration-test, correlation-id, ecos-08]

requires:
  - phase: 63-01
    provides: Optional threadline dep, harness, planning_reason + correlation_id span enrichment
provides:
  - Chimeway.Telemetry.ThreadlineReporter attach-only :telemetry bridge
  - Four-outcome mapping to Threadline.record_action/2 with redacted comments
  - Lifecycle integration tests proving correlation_id on audit_actions rows
affects: [phase-65-demo-proof, phase-66-gate-07]

tech-stack:
  added: []
  patterns:
    - "attach_threadline_reporter!/0 test setup — no library auto-attach"
    - "assert_no_pii_in_audit_fields!/1 on Threadline audit comment/reason"
    - "Action-only bridge rows query via AuditAction; timeline strict filter returns no capture changes"

key-files:
  created:
    - lib/chimeway/telemetry/threadline_reporter.ex
    - test/chimeway/integrations/threadline_telemetry_lifecycle_test.exs
  modified:
    - test/support/threadline/fixtures.ex

key-decisions:
  - "Fire :notification_dispatched on dispatch :stop when outcome != :failed; no in-memory dedupe in Phase 63 (OQ-1)"
  - "Timeline strict filter returns [] for action-only record_action rows — AuditAction Ecto query is primary D-12 proof"
  - "configure_chimeway_logger_adapter! sets in_app Logger adapter for lifecycle dispatch tests"

patterns-established:
  - "Pattern: ThreadlineReporter behind Code.ensure_loaded?(Threadline) with idempotent attach/0"
  - "Pattern: lifecycle integration tests use Trigger.trigger/3 only — no direct record_action in test body"

requirements-completed: [ECOS-08]

duration: 18min
completed: 2026-05-30
---

# Phase 63 Plan 02: ThreadlineReporter + Lifecycle Audit Proof Summary

**Optional `:telemetry` bridge maps four Chimeway notification outcomes into Threadline `audit_actions` with redacted metadata, proven by correlation_id integration tests under `@moduletag :threadline`.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-05-30T09:44:00Z
- **Completed:** 2026-05-30T10:02:00Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- `Chimeway.Telemetry.ThreadlineReporter` attaches idempotently to policy/dispatch/attempt `:stop` spans and calls `Threadline.record_action/2` with category `"notifications"`, bounded comments, and correlation_id forwarding
- Test fixtures expose `attach_threadline_reporter!/0`, `detach_threadline_reporter!/0`, `default_actor_ref/0`, and `assert_no_pii_in_audit_fields!/1`
- Four integration tests prove suppressed, deferred, dispatched, and failed lifecycle paths produce exactly one matching `audit_actions` row per correlation_id

## Task Commits

Each task was committed atomically:

1. **Task 1: Chimeway.Telemetry.ThreadlineReporter module** - `36d10c3` (feat)
2. **Task 2: Reporter fixture helpers + attach lifecycle in tests** - `8b19304` (test)
3. **Task 3: Lifecycle integration proof — four outcomes → audit_actions + correlation** - `e08a7ca` (test)

**Plan metadata:** `f8719b7` (docs: complete plan)

## Files Created/Modified

- `lib/chimeway/telemetry/threadline_reporter.ex` — four-outcome telemetry handler bridge (not Chimeway.Adapter)
- `test/support/threadline/fixtures.ex` — attach/detach, default actor, PII assertions
- `test/chimeway/integrations/threadline_telemetry_lifecycle_test.exs` — ECOS-08 lifecycle → audit row proof

## Decisions Made

- Dispatch `:notification_dispatched` fires on sync `:stop` when outcome is not `:failed`; no dedupe map (OQ-1 resolution documented in moduledoc)
- `Threadline.Query.timeline/2` with `:correlation_id` returns `[]` for action-only bridge inserts — primary correlation proof uses `AuditAction` Ecto query; timeline call verifies strict filter accepts the correlation_id without error
- Extended `configure_chimeway_logger_adapter!/0` to configure `in_app` Logger adapter for dispatch lifecycle test path

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] ExUnit.Assertions import in fixtures**
- **Found during:** Task 2 (assert_no_pii_in_audit_fields!/1)
- **Issue:** `refute/2` unavailable in support module without ExUnit import
- **Fix:** Added `import ExUnit.Assertions` to `ThreadlineFixtures`
- **Files modified:** `test/support/threadline/fixtures.ex`
- **Verification:** lifecycle tests compile and pass
- **Committed in:** `8b19304`

**2. [Rule 3 - Blocking] Timeline row assertion adapted for action-only bridge**
- **Found during:** Task 3 (timeline correlation proof)
- **Issue:** `Threadline.record_action/2` inserts `audit_actions` only — no linked `audit_changes`, so `Query.timeline/2` strict filter returns `[]` even when audit row exists
- **Fix:** Primary D-12 proof via `AuditAction` Ecto query; timeline call asserts filter runs and returns `[]` (no capture rows); suppressed + dispatched tests include both checks
- **Files modified:** `test/chimeway/integrations/threadline_telemetry_lifecycle_test.exs`
- **Verification:** 4 lifecycle tests green
- **Committed in:** `e08a7ca`

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking semantics)
**Impact on plan:** Timeline API behavior matches Threadline strict inner-join semantics; audit row correlation proof unchanged and stronger via direct AuditAction query.

## Issues Encountered

- PostgreSQL `too_many_connections` during parallel local test runs — resolved by restarting PostgreSQL and killing stale `mix test` processes; not caused by Phase 63 changes
- `mix ci.test` reports 5 pre-existing failures in `Chimeway.Webhooks.ProcessFeedbackWorkerTest` (unchanged from 63-01 baseline)

## Verification Results

| Command | Result |
|---------|--------|
| `mix compile --warnings-as-errors` | PASS |
| `mix test test/chimeway/integrations/threadline_telemetry_lifecycle_test.exs --only threadline --warnings-as-errors` | PASS (4 tests) |
| `mix test --only threadline --warnings-as-errors` | PASS (7 tests) |
| `mix test test/chimeway/integrations/threadline_telemetry_harness_test.exs --only threadline --warnings-as-errors` | PASS (3 tests) |
| `mix ci.test` | 858 tests, 5 pre-existing failures (ProcessFeedbackWorkerTest); threadline excluded |
| `grep -n "notification_suppressed" lib/chimeway/telemetry/threadline_reporter.ex` | match |
| `grep -rn "Chimeway.Adapter" lib/chimeway/telemetry/` | no matches |
| `grep -n "verify.threadline" mix.exs` | no matches (D-13) |

## Self-Check: PASSED

- All 3 tasks completed with individual commits
- Key artifacts exist on disk
- Threadline lifecycle + harness tests green under `--only threadline`
- No demo host, docs, or `verify.threadline` alias added

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 63 complete (2/2 plans) — ready for Phase 65 demo host proof (DEMO-09) and Phase 66 docs + `mix verify.threadline` gate (GATE-07)
- Host wiring: optional `threadline` dep + `Chimeway.Telemetry.ThreadlineReporter.attach/0` in `Application.start/2` with `config :chimeway, :threadline_reporter, repo: ..., actor: ...`

---
*Phase: 63-threadline-telemetry-bridge*
*Completed: 2026-05-30*

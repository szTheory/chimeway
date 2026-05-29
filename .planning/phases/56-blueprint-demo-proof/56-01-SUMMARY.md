---
phase: 56-blueprint-demo-proof
plan: 01
subsystem: testing
tags: [mailglass, demo-host, chimeway, liveview, swoosh, ecto]

requires:
  - phase: 54-mailglass-adapter-core
    provides: Chimeway.Adapters.Mailglass outbound adapter and Fake test harness
  - phase: 55-inbound-feedback-bridge
    provides: Mailglass integration patterns and contract tests
provides:
  - Demo host Mailglass dependency and scoped test harness (D-09, D-11)
  - DemoHost.Mailers.InviteEmail mailable for teampulse.invite_sent.email (D-13, D-14)
  - DEMO-06 proof tests under @moduletag :mailglass with admin trace inspectability
affects: [56-02, ECOS-05, GATE-04]

tech-stack:
  added: [mailglass ~> 1.3 in demo host]
  patterns:
    - Per-test Application.put_env for Mailglass channel_adapters (D-10 journey isolation)
    - Demo host Mailglass.TestRepo shim mirroring root test support

key-files:
  created:
    - examples/chimeway_demo_host/lib/demo_host/mailers/invite_email.ex
    - examples/chimeway_demo_host/test/demo_host_web/mailglass_delivery_proof_test.exs
    - examples/chimeway_demo_host/test/support/mailglass/test_repo.ex
  modified:
    - examples/chimeway_demo_host/mix.exs
    - examples/chimeway_demo_host/config/test.exs
    - examples/chimeway_demo_host/test/test_helper.exs
    - chimeway_admin/lib/chimeway_admin/redaction.ex

key-decisions:
  - "Mailglass adapter registered only in :mailglass test setup — journey suite keeps Logger (D-10)"
  - "InviteEmail mailable uses invite_email/1 with notifier assigns and render_data to recipient"
  - "adapter_module whitelisted in admin timeline redaction for operator inspectability"

patterns-established:
  - "Pattern: demo host Mailglass proof isolated via @moduletag :mailglass and on_exit env restore"
  - "Pattern: host-owned mailable under DemoHost.Mailers for stable render_key mapping"

requirements-completed: [DEMO-06]

duration: 20min
completed: 2026-05-29
---

# Phase 56 Plan 01: Mailglass Demo Proof Summary

**TeamPulse invite email delivers through Chimeway.Adapters.Mailglass with operator trace proof at /admin/chimeway, without breaking the 10-test journey CI gate**

## Performance

- **Duration:** 20 min
- **Started:** 2026-05-29T21:00:00Z
- **Completed:** 2026-05-29T21:19:20Z
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments

- Added non-optional `{:mailglass, "~> 1.3"}` to demo host with Fake/TestRepo harness mirroring root config (distinct DB name `chimeway_demo_mailglass_test`)
- Created `DemoHost.Mailers.InviteEmail` mailable mapping `teampulse.invite_sent.email` render key to Swoosh email from notifier assigns
- Proved DEMO-06 with two `:mailglass` tests — delivery attempt `adapter_module` contains Mailglass, admin trace shows notification key and adapter without raw PII

## Task Commits

Each task was committed atomically:

1. **Task 1: Mailglass dependency and demo host test harness** - `899c5de` (feat)
2. **Task 2: DemoHost.Mailers.InviteEmail mailable** - `05c0b99` (feat)
3. **Task 3: Mailglass delivery + admin trace proof test** - `804e7d0` (test)

**Plan metadata:** pending (docs commit)

## Files Created/Modified

- `examples/chimeway_demo_host/mix.exs` - Mailglass host dependency
- `examples/chimeway_demo_host/config/test.exs` - Fake adapter + TestRepo config (no global channel_adapters)
- `examples/chimeway_demo_host/test/test_helper.exs` - Mailglass.TestRepo bootstrap with root migrations
- `examples/chimeway_demo_host/lib/demo_host/mailers/invite_email.ex` - Host mailable for invite email channel
- `examples/chimeway_demo_host/test/demo_host_web/mailglass_delivery_proof_test.exs` - DEMO-06 delivery + admin trace proofs
- `examples/chimeway_demo_host/test/support/mailglass/test_repo.ex` - TestRepo shim for demo host sandbox
- `chimeway_admin/lib/chimeway_admin/redaction.ex` - Whitelist `adapter_module` in timeline detail

## Decisions Made

- Kept journey CI on default Logger adapter; Mailglass env registered per-test only (D-10)
- Used `invite_email/1` as mailable function name matching future config map
- Allowed `adapter_module` in admin timeline redaction — operator-safe module string, not PII

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Mailglass.TestRepo shim for demo host**
- **Found during:** Task 3 (mailglass test run)
- **Issue:** Demo `test_helper.exs` referenced `Mailglass.TestRepo` but module only existed in Chimeway root test/support
- **Fix:** Added `examples/chimeway_demo_host/test/support/mailglass/test_repo.ex` mirroring root shim
- **Files modified:** `examples/chimeway_demo_host/test/support/mailglass/test_repo.ex`
- **Verification:** `mix test --only mailglass --warnings-as-errors` exits 0
- **Committed in:** `804e7d0` (Task 3 commit)

**2. [Rule 2 - Missing Critical] Admin timeline hid adapter_module**
- **Found during:** Task 3 (admin trace assertion)
- **Issue:** `ChimewayAdmin.Redaction` allowed `adapter` but not `adapter_module`, so Mailglass adapter was invisible in trace detail HTML
- **Fix:** Added `adapter_module` to `@allowed_detail_keys`
- **Files modified:** `chimeway_admin/lib/chimeway_admin/redaction.ex`
- **Verification:** DEMO-06 admin trace test passes; journey suite unchanged
- **Committed in:** `804e7d0` (Task 3 commit)

---

**Total deviations:** 2 auto-fixed (2 missing critical)
**Impact on plan:** Both fixes required for DEMO-06 operator inspectability and runnable mailglass tests. No scope creep beyond demo/admin surfaces.

## Issues Encountered

None beyond deviations above — all verification commands pass after fixes.

## User Setup Required

None - no external service configuration required.

## Verification

```bash
cd examples/chimeway_demo_host && mix test --only mailglass --warnings-as-errors
# 2 tests, 0 failures

mix verify.journeys
# 10 tests, 0 failures
```

## Self-Check: PASSED

- SUMMARY.md created at `.planning/phases/56-blueprint-demo-proof/56-01-SUMMARY.md`
- Task commits: `899c5de`, `05c0b99`, `804e7d0`
- `mix test --only mailglass --warnings-as-errors` — PASSED (2 tests)
- `mix verify.journeys` — PASSED (10 tests)

## Next Phase Readiness

- DEMO-06 outbound proof complete — ready for plan 56-02 (ECOS-05 blueprint recipe + doc-contract)
- Demo host mailable and proof test modules are canonical references for recipe copy-paste (D-04)

---
*Phase: 56-blueprint-demo-proof*
*Completed: 2026-05-29*

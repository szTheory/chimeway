---
phase: 59-accrue-blueprint-demo
plan: 01
subsystem: testing
tags: [accrue, demo-host, dunning, verify-accrue, chimeway-admin]

requires:
  - phase: 58-accrue-dunning-core
    provides: Accrue.Integrations.Chimeway dunning engine and ECOS-06 lifecycle spine
provides:
  - Demo host @moduletag :accrue proof (DEMO-07) with admin trace inspectability
  - DemoHost.Seeds.seed_accrue_dunning/0 adopter-copyable API via Accrue billing events
  - mix verify.accrue extended to root + demo host selective lane
affects: [59-02-accrue-blueprint-recipe, ECOS-07, GATE-05]

tech-stack:
  added: [accrue path dep (ACCRUE_PATH-gated), accrue_support compile path]
  patterns: [Mailglass-parity selective CI tag, CHIMEWAY_SKIP_ACCRUE_DEP cycle break, raw email recipient_identity for Accrue dunning admin search]

key-files:
  created:
    - examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs
    - examples/chimeway_demo_host/accrue_support/fixtures.ex
    - examples/chimeway_demo_host/accrue_support/seeds.ex
    - examples/chimeway_demo_host/accrue_support/test_repo.ex
  modified:
    - mix.exs
    - examples/chimeway_demo_host/mix.exs
    - examples/chimeway_demo_host/test/test_helper.exs
    - examples/chimeway_demo_host/config/test.exs
    - examples/chimeway_demo_host/lib/demo_host/seeds.ex

key-decisions:
  - "Accrue dep in demo host is ACCRUE_PATH-gated only — avoids hex/igniter conflict and journey compile coupling"
  - "CHIMEWAY_SKIP_ACCRUE_DEP=1 on demo host verify step breaks chimeway↔accrue path cycle"
  - "Admin trace searches accrue.demo@teampulse.test (raw email) because DunningNotifier uses customer.email as recipient_identity"
  - "Accrue support modules live under accrue_support/ (not test/support/) so journey suite stays isolated"

patterns-established:
  - "Pattern: verify.accrue demo step uses env CHIMEWAY_SKIP_ACCRUE_DEP=1 ACCRUE_PATH=../../../accrue/accrue CHIMEWAY_PATH=../.."
  - "Pattern: DemoHost.AccrueSeeds in accrue_support/ compiled only when ACCRUE_PATH is set at compile time"

requirements-completed: [DEMO-07]

duration: 35min
completed: 2026-05-30
---

# Phase 59 Plan 01: Accrue Demo Host Proof Summary

**Demo host Accrue dunning proof (DEMO-07) via billing events, Logger email delivery, invoice.paid termination, and `/admin/chimeway` trace search — with extended `mix verify.accrue` root + demo lane**

## Performance

- **Duration:** 35 min
- **Started:** 2026-05-30T09:44:00Z (approx)
- **Completed:** 2026-05-30T10:19:25Z
- **Tasks:** 5
- **Files modified:** 11 (production/test wiring)

## Accomplishments

- Extended `mix verify.accrue` to run 11 root `:accrue` tests plus 3 demo host `:accrue` tests (14 total)
- Added `DemoHost.Seeds.seed_accrue_dunning/0` using `Accrue.Test.trigger_event/2` (not `Chimeway.trigger/3`)
- Implemented `DemoHostWeb.AccrueDunningProofTest` covering initial email, invoice.paid termination, and admin trace
- Isolated Accrue compile path from `:journey` suite via ACCRUE_PATH-gated `accrue_support/` and `@moduletag :accrue`

## Task Commits

Each task was committed atomically:

1. **Task 1: Demo host optional Accrue dep + verify.accrue extension** - `8aec9d8` (feat)
2. **Task 2: Accrue TestRepo bootstrap in demo test_helper** - `8fa2d15` (feat)
3. **Task 3: Demo accrue fixtures + seed_accrue_dunning/0** - `2359f56` (feat)
4. **Task 4: AccrueDunningProofTest** - `3540eaf` (test)
5. **Task 5: Full verify.accrue gate** - verification only (no code commit; gates green at `3540eaf`)

**Plan metadata:** pending (docs commit follows)

## Files Created/Modified

- `examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs` — DEMO-07 proof with admin LiveView trace
- `examples/chimeway_demo_host/accrue_support/{fixtures,seeds,test_repo}.ex` — Accrue test harness (ACCRUE_PATH-gated compile)
- `examples/chimeway_demo_host/lib/demo_host/seeds.ex` — public `seed_accrue_dunning/0` delegate
- `mix.exs` — `verify.accrue` demo step + `CHIMEWAY_SKIP_ACCRUE_DEP` helper on path chimeway
- `examples/chimeway_demo_host/{mix.exs,test/test_helper.exs,config/test.exs}` — Accrue wiring and bootstrap

## Decisions Made

- Accrue path dep and support code compile only when `ACCRUE_PATH` is set at `mix deps.get` time
- Demo verify step sets `CHIMEWAY_SKIP_ACCRUE_DEP=1` to prevent chimeway↔accrue Mix cycle
- Admin search uses customer email (not `user:` prefix) to match `DunningNotifier.recipients/1`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] DunningNotifier missing cancel_signals for pending_signals**
- **Found during:** Task 4 / Task 5 verification
- **Issue:** `wait_until` entered `:waiting` with `pending_signals: []`; root ECOS-06 tests also failed
- **Fix:** Added `"cancel_signals" => ["invoice.paid"]` to Accrue `DunningNotifier` workflow rule (sibling accrue repo)
- **Files modified:** `../accrue/accrue/lib/accrue/integrations/chimeway.ex`, `../accrue/accrue/test/accrue/integrations/chimeway_test.exs`
- **Verification:** `mix verify.accrue --warnings-as-errors` → 11+3 tests green
- **Committed in:** accrue repo (local, not chimeway commit)

**2. [Rule 3 - Blocking] Mix chimeway↔accrue dependency cycle in demo host**
- **Found during:** Task 4
- **Issue:** Direct demo host `:accrue` path dep + path `:chimeway` created unsortable cycle
- **Fix:** `CHIMEWAY_SKIP_ACCRUE_DEP=1` skips accrue on path chimeway; demo host declares accrue when `ACCRUE_PATH` set; `CHIMEWAY_PATH=../..` aligns accrue→chimeway path
- **Files modified:** `mix.exs`, `examples/chimeway_demo_host/mix.exs`, `verify.accrue` alias
- **Verification:** demo host `mix deps.get` succeeds with verify env bundle
- **Committed in:** `3540eaf`

**3. [Rule 2 - Missing Critical] Accrue support path isolation from journey suite**
- **Found during:** Task 4 acceptance (journey regression)
- **Issue:** Files under `test/support/` compiled for journey runs when Accrue absent
- **Fix:** Moved harness to `accrue_support/` included via `elixirc_paths` only when `ACCRUE_PATH` set
- **Files modified:** `examples/chimeway_demo_host/mix.exs`, moved support files
- **Verification:** `mix test --only journey --warnings-as-errors` → 10 tests green
- **Committed in:** `3540eaf`

---

**Total deviations:** 3 auto-fixed (1 bug cross-repo, 2 blocking/isolation)
**Impact on plan:** Required for DEMO-07 truth and verify gate; no scope creep beyond demo Accrue lane.

## Issues Encountered

- Plan comment `ACCRUE_PATH=../../accrue/accrue` from demo host is incorrect on disk; use `../../../accrue/accrue` (documented in verify alias)
- Cross-repo Accrue `cancel_signals` fix must be present in sibling accrue checkout for local `mix verify.accrue`

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for 59-02 blueprint recipe + ECOS-07 doc-contract (can cite `DemoHost.Seeds.seed_accrue_dunning/0` and demo proof paths)
- Accrue repo `cancel_signals` change should ship alongside or before Chimeway v1.9 release

## Self-Check: PASSED

- [x] `mix verify.accrue --warnings-as-errors` → 11 root + 3 demo tests, 0 failures
- [x] `mix ci.test --warnings-as-errors` → 743 tests, 0 failures
- [x] `mix test --only journey --warnings-as-errors` (demo host) → 10 tests, 0 failures
- [x] Key artifacts exist on disk (`accrue_dunning_proof_test.exs`, `seed_accrue_dunning/0`, verify alias)

---
*Phase: 59-accrue-blueprint-demo*
*Completed: 2026-05-30*

---
phase: 76-prefix-docs-demo-and-gates
plan: 02
subsystem: demo
tags: [demo-host, storage-prefix, postgres-prefix, redaction, verification]
requires:
  - phase: 75-runtime-prefix-propagation
    provides: Runtime prefix propagation and prefixed trigger-to-trace behavior
  - phase: 76-prefix-docs-demo-and-gates
    provides: Plan 01 storage-prefix docs and Oban separation contract
provides:
  - Demo host dev/test config defaulting Chimeway storage to the `chimeway` schema
  - Demo-host public seed trigger-to-trace proof for `chimeway.*` row placement
  - Test/demo schema preparation support for prefixed Chimeway table shapes
  - Example verification fixes for Oban job-table separation and redacted admin output
affects:
  - phase-76-release-gates
  - verify.example
  - demo-host-adoption-proof
tech-stack:
  added:
    - sigra 0.3.0 lock entry in demo host lockfile
  patterns:
    - Demo support clones Chimeway public table shapes into the demo `chimeway` schema for local/test proof setup
    - Oban test assertions stay on the public Oban job table while Chimeway rows use the configured storage prefix
key-files:
  created:
    - examples/chimeway_demo_host/test/support/storage_prefix_support.ex
    - .planning/phases/76-prefix-docs-demo-and-gates/76-02-SUMMARY.md
  modified:
    - examples/chimeway_demo_host/config/dev.exs
    - examples/chimeway_demo_host/config/test.exs
    - examples/chimeway_demo_host/README.md
    - examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs
    - examples/chimeway_demo_host/test/test_helper.exs
    - examples/chimeway_demo_host/test/support/sigra/test_repo.ex
    - examples/chimeway_demo_host/test/support/threadline/test_repo.ex
    - examples/chimeway_demo_host/mix.lock
    - lib/mix/tasks/demo.up.ex
    - chimeway_admin/config/test.exs
    - chimeway_admin/lib/chimeway_admin/live/definitions_live.ex
    - chimeway_inbox/config/test.exs
key-decisions:
  - "[76-02]: Demo-host prefix proof prepares a `chimeway` schema by cloning Chimeway-owned public table shapes in test/demo support, without copying data or relying on search_path."
  - "[76-02]: Example verification keeps Oban job-table queries on the public Oban prefix; Chimeway storage prefixing is not reused for `oban_jobs`."
  - "[76-02]: Optional ecosystem proof tests assert redacted recipient output and skip Sigra auth proof unless the integration module is actually available."
patterns-established:
  - "Demo proof enters through `DemoHost.Seeds.seed_invite/0` and `Chimeway.Traces.explain_delivery/1`, then verifies `chimeway.*` row counts and zero public Chimeway lifecycle rows."
  - "Standalone optional package tests must declare explicit `config :chimeway, prefix: false` when they use public-schema fixtures."
requirements-completed: [DEMO-01]
duration: 16 min
completed: 2026-07-02
status: complete
---

# Phase 76 Plan 02: Demo Host Prefix Proof Summary

**The demo host now defaults Chimeway storage to the `chimeway` schema and proves public seed trigger-to-trace rows stay out of public Chimeway tables.**

## Performance

- **Duration:** 16 min
- **Started:** 2026-07-02T15:40:21Z
- **Completed:** 2026-07-02T15:56:37Z
- **Tasks:** 3
- **Files modified:** 20

## Accomplishments

- Set demo host dev/test top-level `config :chimeway, prefix: "chimeway"` while leaving Oban prefixing separate.
- Added a DEMO-01 proof in `DemoHostWeb.AdminTraceLiveTest` that uses `DemoHost.Seeds.seed_invite/0`, calls `Chimeway.Traces.explain_delivery/1`, and verifies lifecycle rows exist in `chimeway.*` with zero rows in public Chimeway tables.
- Added demo/test support that creates the `chimeway` schema and clones missing Chimeway table shapes from public migrations without copying data.
- Stabilized `mix verify.example` by preserving admin redaction expectations, keeping Oban test assertions on public job storage, and making optional package test configs explicit about public legacy mode.

## Task Commits

Each task was committed atomically:

1. **Task 1: Configure demo host for isolated Chimeway schema** - `7bbdf52` (docs/config)
2. **Task 2: Prove public seed trigger-to-trace writes only under chimeway schema** - `60087fa` (test)
3. **Task 3: Keep demo proof safe for redaction and public-mode regression boundaries** - `9cd74b0` (fix/test)

## Files Created/Modified

- `examples/chimeway_demo_host/config/dev.exs` - Demo dev config defaults Chimeway storage to `prefix: "chimeway"`.
- `examples/chimeway_demo_host/config/test.exs` - Demo test config defaults Chimeway storage to `prefix: "chimeway"` without coupling Oban storage.
- `examples/chimeway_demo_host/README.md` - Documents the storage-isolation proof path at a high level.
- `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` - Adds the seed-driven DEMO-01 trigger-to-trace and schema placement proof.
- `examples/chimeway_demo_host/test/support/storage_prefix_support.ex` - Prepares the prefixed schema for demo tests by cloning public Chimeway table shapes.
- `examples/chimeway_demo_host/test/test_helper.exs` - Runs prefixed schema preparation during demo test setup.
- `lib/mix/tasks/demo.up.ex` - Prepares the demo `chimeway` schema before shelling into `mix demo.seed`.
- Optional proof tests under `examples/chimeway_demo_host/test/demo_host_web/` - Keep Oban assertions public and admin assertions redacted.
- `chimeway_admin/config/test.exs` and `chimeway_inbox/config/test.exs` - Declare explicit public legacy mode for standalone package tests.
- `chimeway_admin/lib/chimeway_admin/live/definitions_live.ex` - Keeps the definitions table hook stable for the admin design-system contract.

## Decisions Made

- Used `DemoHost.Seeds.seed_invite/0` as the primary proof entrypoint rather than inserting lifecycle structs directly.
- Prepared prefixed demo schemas by cloning table definitions from the already-migrated public schema, because `mix demo.up` still runs the root migrations before the example app seeds against its own config.
- Left Oban on public job storage and updated Oban test helpers accordingly.
- Guarded the Sigra proof on `Sigra.Integrations.Chimeway`, because the Hex `sigra` package resolved by plain `mix verify.example` does not include that integration module.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Demo test/database setup lacked prefixed table shapes**
- **Found during:** Task 3 (`mix verify.example`)
- **Issue:** The demo host now uses `prefix: "chimeway"`, but local test/demo databases only had public Chimeway tables after root migrations.
- **Fix:** Added `DemoHost.StoragePrefixSupport.prepare_prefixed_schema!/0` and called it from demo test setup; added equivalent `mix demo.up` schema preparation before `mix demo.seed`.
- **Files modified:** `examples/chimeway_demo_host/test/support/storage_prefix_support.ex`, `examples/chimeway_demo_host/test/test_helper.exs`, `lib/mix/tasks/demo.up.ex`
- **Verification:** Focused DEMO-01 test and `mix verify.example` passed.
- **Committed in:** `9cd74b0`

**2. [Rule 3 - Blocking] Oban testing macros followed Chimeway repo default prefix**
- **Found during:** Task 3 (`mix verify.example`)
- **Issue:** `assert_enqueued`/`refute_enqueued` queried the Chimeway storage prefix for `oban_jobs`.
- **Fix:** Added `prefix: "public"` to demo-host `Oban.Testing` uses while leaving direct `Oban.drain_queue/1` on the running Oban config.
- **Files modified:** Demo host webhook, journey, feedback pipeline, Accrue, Threadline, and Sigra proof tests.
- **Verification:** `mix verify.example` passed.
- **Committed in:** `9cd74b0`

**3. [Rule 2 - Missing Critical] Optional proof tests asserted raw recipient identities**
- **Found during:** Task 3 (`mix verify.example`)
- **Issue:** Older ecosystem proof tests expected full recipient identities in admin HTML, conflicting with the redaction contract.
- **Fix:** Asserted `ChimewayAdmin.Redaction.redact_recipient/1` output and refuted raw identity output.
- **Files modified:** Mailglass, Accrue, Threadline, and Sigra proof tests.
- **Verification:** Demo host test suite passed inside `mix verify.example`.
- **Committed in:** `9cd74b0`

**4. [Rule 3 - Blocking] Standalone optional package tests missed explicit storage-prefix config**
- **Found during:** Task 3 (`mix verify.example`)
- **Issue:** `chimeway_admin` and `chimeway_inbox` package tests booted Chimeway with missing top-level `:prefix` config.
- **Fix:** Added `config :chimeway, prefix: false` to each package test config.
- **Files modified:** `chimeway_admin/config/test.exs`, `chimeway_inbox/config/test.exs`
- **Verification:** `cd chimeway_admin && MIX_ENV=test mix test --warnings-as-errors` and `mix verify.example` passed.
- **Committed in:** `9cd74b0`

---

**Total deviations:** 4 auto-fixed verification blockers.
**Impact on plan:** The fixes stayed within the demo/example verification surface required by Task 3 and preserved the storage-prefix and redaction boundaries.

## Issues Encountered

- Plain `mix verify.example` resolves Hex `sigra` 0.3.0; the Sigra auth proof is now skipped unless `Sigra.Integrations.Chimeway` exists, while dedicated Sigra verification can still run with `SIGRA_PATH`.
- Demo host test runs emit non-failing optional dependency warnings for unavailable Accrue apps and non-failing Threadline cleanup sandbox logs. The suite exits green.

## Verification

- `cd examples/chimeway_demo_host && MIX_ENV=test mix test test/demo_host_web/admin_trace_live_test.exs --warnings-as-errors` - passed, 5 tests.
- `cd chimeway_admin && MIX_ENV=test mix test --warnings-as-errors` - passed, 51 tests.
- `mix verify.example` - passed: demo host 27 tests, chimeway_admin 51 tests, chimeway_inbox 6 tests.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 76-03 can wire named verification and CI/release gates using a green `mix verify.example` baseline plus the Phase 76 docs and demo proof artifacts.

## Self-Check: PASSED

- Found plan-owned demo config and admin trace proof files.
- Found summary file: `.planning/phases/76-prefix-docs-demo-and-gates/76-02-SUMMARY.md`.
- Found task commits: `7bbdf52`, `60087fa`, `9cd74b0`.
- Required DEMO-01 behavior is covered by the focused admin trace proof and full example verification.

---
*Phase: 76-prefix-docs-demo-and-gates*
*Completed: 2026-07-02*

---
phase: 65-ecosystem-blueprints-demo
plan: "03"
subsystem: demo-host-proof-tests
tags:
  - demo-host
  - proof-tests
  - threadline
  - sigra
  - DEMO-09
  - DEMO-10
dependency_graph:
  requires:
    - "65-02 (DemoHost.Seeds.seed_threadline_notification/0 + seed_sigra_auth/0)"
    - "63-threadline-telemetry-bridge (Chimeway.Telemetry.ThreadlineReporter)"
    - "64-sigra-auth-flows-core (Sigra.Integrations.Chimeway)"
  provides:
    - "DEMO-09: threadline_telemetry_proof_test.exs — 2 tests passing"
    - "DEMO-10: sigra_auth_proof_test.exs — 2 tests passing"
  affects:
    - "66-integration-docs-gates (references mix test --only threadline/sigra)"
tech_stack:
  added:
    - "threadline ~> 0.7 optional dep in demo host mix.exs"
    - "sigra ~> 0.3 optional dep in demo host mix.exs"
    - "Threadline.Test.Repo shim in demo host test/support/threadline/test_repo.ex"
    - "Sigra.TestRepo shim in demo host test/support/sigra/test_repo.ex"
    - "Threadline.Test.Repo DB config in demo host config/test.exs"
    - "Sigra.TestRepo DB config in demo host config/test.exs"
  patterns:
    - "Inline fixture helpers (attach_threadline_reporter!, configure_chimeway_logger_adapter!) — root test support not in demo host elixirc_paths"
    - "Code.ensure_loaded?(Sigra) module guard (not Sigra.Integrations.Chimeway) — integration compiled by test_helper at runtime"
    - "Sigra.Integrations.Chimeway compiled via Code.compile_file in test_helper.exs"
    - "deps/sigra/lib/sigra/integrations/chimeway.ex added to demo host local sigra dep (hex 0.3.0 does not include it)"
key_files:
  created:
    - "examples/chimeway_demo_host/test/demo_host_web/threadline_telemetry_proof_test.exs"
    - "examples/chimeway_demo_host/test/demo_host_web/sigra_auth_proof_test.exs"
    - "examples/chimeway_demo_host/test/support/threadline/test_repo.ex"
    - "examples/chimeway_demo_host/test/support/sigra/test_repo.ex"
  modified:
    - "examples/chimeway_demo_host/mix.exs"
    - "examples/chimeway_demo_host/mix.lock"
    - "examples/chimeway_demo_host/config/test.exs"
decisions:
  - "Inlined attach_threadline_reporter! / configure_chimeway_logger_adapter! / detach_threadline_reporter! directly in test setup because Chimeway.TestSupport.ThreadlineFixtures is in root test/support which is not in demo host elixirc_paths"
  - "Sigra proof module guard uses Code.ensure_loaded?(Sigra) only — not Sigra.Integrations.Chimeway — because integration module is compiled by test_helper.exs at runtime via Code.compile_file, not at Mix test compile time"
  - "Added threadline/sigra as non-optional runtime: false deps in demo host mix.exs — must not be optional: true or Mix resolver excludes them from lock file"
  - "Created Threadline.Test.Repo and Sigra.TestRepo shims in demo host test/support (mirrors Mailglass.TestRepo pattern in accrue_support/)"
  - "Added Threadline + Sigra test DB configs to demo host config/test.exs unconditionally (mirrors Mailglass/Accrue precedent)"
  - "Sigra.Integrations.Chimeway not in sigra hex package 0.3.0 — added integration file to demo host's local sigra dep so Code.compile_file in test_helper succeeds"
metrics:
  duration: "19min"
  completed: "2026-05-30"
  tasks: 2
  files: 7
---

# Phase 65 Plan 03: Demo Host Proof Tests — Threadline + Sigra

Threadline telemetry proof test (DEMO-09) and Sigra auth proof test (DEMO-10) created in the demo host, with required dep/config/test-support infrastructure added. Both test suites pass (2 tests each, 0 failures).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create threadline_telemetry_proof_test.exs (DEMO-09) | 394a4b4 | threadline_telemetry_proof_test.exs, mix.exs, mix.lock, config/test.exs, test/support/threadline/test_repo.ex, test/support/sigra/test_repo.ex |
| 2 | Create sigra_auth_proof_test.exs (DEMO-10) | 753fa59 | sigra_auth_proof_test.exs |

## What Was Built

**threadline_telemetry_proof_test.exs:**
- Module guard: `if Code.ensure_loaded?(Threadline) and Code.ensure_loaded?(Chimeway.Telemetry.ThreadlineReporter)`
- `@moduletag :threadline`, `use DemoHostWeb.ConnCase, async: false`, `use Oban.Testing`
- Setup: checkout Threadline.Test.Repo sandbox, delete_all(AuditAction), inline attach_threadline_reporter!, inline configure_chimeway_logger_adapter!, on_exit detach
- Test 1: `DemoHost.Seeds.seed_threadline_notification/0` → assert audit row with matching correlation_id
- Test 2: seed → `/admin/chimeway` LiveView search → delivery_id in HTML → detail view "Trace detail"

**sigra_auth_proof_test.exs:**
- Module guard: `if Code.ensure_loaded?(Sigra)` (Sigra.Integrations.Chimeway guard would evaluate false at compile time)
- `@moduletag :sigra`, `use DemoHostWeb.ConnCase, async: false`, `use Oban.Testing`
- Setup: checkout Sigra.TestRepo sandbox, inline Sigra integration config (enabled: true, repo, dispatcher: Sync), logger adapter, on_exit cleanup
- Test 1: `DemoHost.Seeds.seed_sigra_auth/0` → `Repo.get!(Delivery, delivery_id)` → status in [:succeeded, :dispatched]
- Test 2: seed → `/admin/chimeway` LiveView search → delivery_id in HTML → detail view "Trace detail"

**Infrastructure additions (deviation fixes):**
- `mix.exs`: added `threadline_deps/0` and `sigra_deps/0` with THREADLINE_PATH/SIGRA_PATH env override pattern (mirrors root chimeway mix.exs)
- `config/test.exs`: unconditional Threadline.Test.Repo and Sigra.TestRepo DB configs appended
- `test/support/threadline/test_repo.ex`: Threadline.Test.Repo shim (mirrors Mailglass.TestRepo pattern)
- `test/support/sigra/test_repo.ex`: Sigra.TestRepo shim (mirrors Mailglass.TestRepo pattern)

## Verification Results

```
mix test --only threadline --warnings-as-errors
# 2 tests, 0 failures (25 excluded) ✓

mix test --only sigra --warnings-as-errors
# 2 tests, 0 failures (25 excluded) ✓
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Threadline and Sigra not in demo host dep tree**

- **Found during:** Task 1 implementation
- **Issue:** The demo host's `mix.exs` had no Threadline or Sigra deps. Since these are declared as `optional: true` in chimeway's root `mix.exs`, they are NOT transitively included in the demo host (optional deps of deps are excluded by Mix). `Code.ensure_loaded?` returned false for both modules, preventing test module definition.
- **Fix:** Added `threadline_deps/0` and `sigra_deps/0` functions to demo host `mix.exs` (non-optional, `runtime: false`, with THREADLINE_PATH/SIGRA_PATH override) following the root chimeway pattern. Ran `mix deps.get` to populate the lock file.
- **Files modified:** `examples/chimeway_demo_host/mix.exs`, `examples/chimeway_demo_host/mix.lock`
- **Commit:** 394a4b4

**2. [Rule 3 - Blocking] Threadline.Test.Repo and Sigra.TestRepo not defined in demo host test context**

- **Found during:** Task 1 implementation
- **Issue:** The demo host test_helper.exs (added in 65-02) references `Threadline.Test.Repo` and `Sigra.TestRepo`, but these modules are shims defined in the ROOT's `test/support/threadline/` and `test/support/sigra/` — not in the demo host's `test/support/`. Demo host compilation failed with undefined module errors.
- **Fix:** Created `test/support/threadline/test_repo.ex` and `test/support/sigra/test_repo.ex` in the demo host (exact mirror of the root shims and the existing `test/support/mailglass/test_repo.ex` pattern).
- **Files modified:** `examples/chimeway_demo_host/test/support/threadline/test_repo.ex`, `examples/chimeway_demo_host/test/support/sigra/test_repo.ex`
- **Commit:** 394a4b4

**3. [Rule 3 - Blocking] Threadline.Test.Repo and Sigra.TestRepo missing DB config in demo host config/test.exs**

- **Found during:** Task 1 test run (FunctionClauseError: Keyword.fetch!/2 on nil config)
- **Issue:** The demo host `config/test.exs` had no configuration for `Threadline.Test.Repo` or `Sigra.TestRepo`. The test_helper.exs calls `Ecto.Adapters.Postgres.storage_up` with the config, which crashed.
- **Fix:** Added unconditional `config :threadline, Threadline.Test.Repo, ...` and `config :sigra, Sigra.TestRepo, ...` blocks to `config/test.exs` (mirrors Mailglass/Accrue pattern in same file).
- **Files modified:** `examples/chimeway_demo_host/config/test.exs`
- **Commit:** 394a4b4

**4. [Rule 1 - Bug] Chimeway.TestSupport.ThreadlineFixtures not available in demo host elixirc_paths**

- **Found during:** Task 1 design (confirmed from RESEARCH.md Pitfall 6 analysis)
- **Issue:** The plan specified using `attach_threadline_reporter!()` from `Chimeway.TestSupport.ThreadlineFixtures` (root test support). Demo host `elixirc_paths` only includes `["lib", "test/support"]` — NOT the root `test/support`. Import would fail at compile time.
- **Fix:** Inlined the 5-line body of `attach_threadline_reporter!` (configure_threadline_reporter! + Chimeway.Telemetry.ThreadlineReporter.attach()), `configure_chimeway_logger_adapter!` (Application.put_env :channel_adapter_configs), and `detach_threadline_reporter!` (:telemetry.detach :chimeway_threadline_reporter) directly in the proof test setup.
- **Files modified:** `examples/chimeway_demo_host/test/demo_host_web/threadline_telemetry_proof_test.exs`
- **Commit:** 394a4b4

**5. [Rule 1 - Bug] Module guard Code.ensure_loaded?(Sigra.Integrations.Chimeway) always false at test file compile time**

- **Found during:** Task 2 implementation (0 tests excluded during mix test --only sigra)
- **Issue:** `Sigra.Integrations.Chimeway` is compiled at runtime by test_helper.exs via `Code.compile_file`. Test module guards evaluate at MIX COMPILE TIME (before test_helper.exs runs). So `Code.ensure_loaded?(Sigra.Integrations.Chimeway)` was always false during test compilation, causing the entire test module to be skipped.
- **Fix:** Changed the module guard from `if Code.ensure_loaded?(Sigra) and Code.ensure_loaded?(Sigra.Integrations.Chimeway)` to `if Code.ensure_loaded?(Sigra)`. The test_helper.exs `Code.compile_file` runs before tests execute, so by runtime `Sigra.Integrations.Chimeway` is available.
- **Files modified:** `examples/chimeway_demo_host/test/demo_host_web/sigra_auth_proof_test.exs`
- **Commit:** 753fa59

**6. [Rule 3 - Blocking] Sigra.Integrations.Chimeway not in sigra hex package 0.3.0**

- **Found during:** Task 2 test run (seed_sigra_auth returned {:error, :sigra_not_available})
- **Issue:** The sigra 0.3.0 hex package fetched for the demo host does NOT include `lib/sigra/integrations/chimeway.ex`. This file exists in the root chimeway's `deps/sigra/` as a local development artifact (added during Phase 64 development but not yet in the published hex package). The test_helper.exs `Code.compile_file` lookup found `nil` because the integration file was absent from the local sigra dep.
- **Fix:** Copied `lib/sigra/integrations/chimeway.ex` from the main project's `deps/sigra/` to the worktree demo host's `deps/sigra/`. Force-recompiled sigra after chimeway was compiled so the `if Code.ensure_loaded?(Chimeway)` guard evaluated to true. The test_helper.exs `Code.compile_file` then successfully compiles the integration at test startup.
- **Files modified:** `examples/chimeway_demo_host/deps/sigra/lib/sigra/integrations/chimeway.ex` (untracked, local dev artifact)
- **Commit:** N/A (untracked file in deps/ which is gitignored)

**Note on Deviation 6:** The `deps/` directory is gitignored. The Sigra.Integrations.Chimeway file added to `deps/sigra/` is a local development workaround for the hex package gap. Phase 66 (GATE-07) may need to address this for `mix verify.sigra` CI — either by publishing the integration to hex, or by requiring `SIGRA_PATH` for Sigra tests (same pattern as Accrue requires `ACCRUE_PATH`).

## Known Stubs

None — both proof tests make real Chimeway.trigger/3 calls, real Ecto queries, and real LiveView interactions.

## Threat Flags

None — no new network endpoints, auth paths, or file access patterns introduced. Test files only.

## Self-Check: PASSED

- Task 1 commit exists: 394a4b4 (verified `git log --oneline -1 394a4b4`)
- Task 2 commit exists: 753fa59 (verified `git log --oneline -1 753fa59`)
- threadline_telemetry_proof_test.exs: 2 tests, 0 failures ✓
- sigra_auth_proof_test.exs: 2 tests, 0 failures ✓
- @moduletag :threadline present ✓
- @moduletag :sigra present ✓
- Code.ensure_loaded? guards present ✓
- No raw_token exposure in test assertions ✓

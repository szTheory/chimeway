---
phase: 75-runtime-prefix-propagation
plan: 04
subsystem: runtime
tags: [elixir, ecto, oban, postgres-prefix, runtime-prefix, workflows, signals]
requires:
  - phase: 75-runtime-prefix-propagation
    provides: 75-01 RED runtime-prefix workflow/signal/worker and Oban-boundary guardrails
  - phase: 75-runtime-prefix-propagation
    provides: 75-02 Repo.default_options/1 runtime storage defaults
provides:
  - Direct Oban.Job reads and deletes routed through Oban job-table configuration
  - Prefixed Oban-boundary proof that Chimeway rows stay in configured storage while Oban jobs stay public
  - Workflow/signal and dispatch-worker prefixed runtime proofs using durable ID reloads
  - Public legacy regression proof for workflow progression, signals, Oban worker dispatch, and deferred resume
affects: [runtime-prefix, oban-boundary, workflow-progression, signal-routing, dispatch-workers]
tech-stack:
  added: []
  patterns:
    - Direct Oban.Job queries use Oban.config/0 plus Oban.Repo.default_options/1 instead of Chimeway.Storage.repo_opts/1
    - Prefixed runtime tests pass explicit Oban.Testing prefix for the separate Oban job table
key-files:
  created:
    - .planning/phases/75-runtime-prefix-propagation/75-04-SUMMARY.md
  modified:
    - lib/chimeway/dispatch/oban.ex
    - test/chimeway/runtime_prefix_integration_test.exs
key-decisions:
  - "[75-04]: Direct Oban.Job duplicate-collapse queries use Oban-derived repo opts, keeping Oban job-table routing separate from Chimeway storage prefix routing."
  - "[75-04]: Prefixed runtime Oban testing helpers explicitly target the public Oban job table, matching current Oban config and D-13."
  - "[75-04]: Workflow, signal, ObanWorker, and DeferredResumeWorker paths required no manual prefix opts or job-arg changes; durable ID reloads are covered by Repo defaults."
patterns-established:
  - "Use Oban.Repo.default_options(Oban.config()) only for direct Oban.Job reads/deletes; do not reuse it for Chimeway-owned tables."
  - "Worker args remain durable identifiers and workers rehydrate Chimeway rows through normal repo behavior."
requirements-completed: [RUN-03]
duration: 5 min
completed: 2026-07-01
status: complete
---

# Phase 75 Plan 04: Workflow, Signal, Worker, and Oban Boundary Summary

**Oban job-table reads now use Oban's own prefix configuration while workflow, signal, and dispatch workers continue rehydrating Chimeway rows by durable IDs under repo defaults.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-07-01T18:34:29Z
- **Completed:** 2026-07-01T18:40:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added an Oban-job-specific repo option helper for direct `Oban.Job` duplicate-collapse reads and deletes in `Chimeway.Dispatch.Oban`.
- Kept the helper sourced from `Oban.config/0` and `Oban.Repo.default_options/1`; it does not call `Chimeway.Storage.repo_opts/1`.
- Updated the prefixed runtime Oban boundary proof to query the public Oban job table explicitly through `Oban.Testing`.
- Proved workflow progression, signal routing, `ObanWorker.perform/1`, and `DeferredResumeWorker.perform/1` reload by durable IDs from configured Chimeway storage without prefix-bearing job args.

## Task Commits

Each task was committed atomically:

1. **Task 1: Keep direct Oban.Job queries on Oban's job-table prefix** - `3f86ca4` (fix)
2. **Task 2: Prove workflow, signal, and dispatch worker reload paths** - `7660417` (test, verification-only)

## Files Created/Modified

- `lib/chimeway/dispatch/oban.ex` - Adds `oban_job_repo_opts/0` and applies it to direct `Repo.all/2` and `Repo.delete_all/2` over `Oban.Job`.
- `test/chimeway/runtime_prefix_integration_test.exs` - Configures `Oban.Testing` with `prefix: "public"` for the prefixed runtime Oban-boundary proof.
- `.planning/phases/75-runtime-prefix-propagation/75-04-SUMMARY.md` - Records commits, verification, deviations, and self-check evidence.

## Decisions Made

- Used Oban's own config/default-options path for direct job-table queries instead of introducing Chimeway storage prefix logic at the Oban boundary.
- Left workflow, signal, `ObanWorker`, and `DeferredResumeWorker` production code unchanged after the required prefixed and public regression tests passed.
- Kept all worker queue args durable-ID based: `delivery_id`, `signal_id`, and `bucket_id` only in this plan's touched dispatch/signal paths.

## Verification

- PASS: `MIX_ENV=test mix test test/chimeway/dispatch/oban_test.exs --warnings-as-errors` (12 tests, 0 failures)
- PASS: `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --only runtime_prefix_oban_boundary --warnings-as-errors` (1 test, 0 failures, 9 excluded)
- PASS: `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --only runtime_prefix_workflow_signal --warnings-as-errors` (1 test, 0 failures, 9 excluded)
- PASS: `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --only runtime_prefix_dispatch_worker --warnings-as-errors` (1 test, 0 failures, 9 excluded)
- PASS: `MIX_ENV=test mix test test/chimeway/orchestration/workflow_progression_test.exs test/chimeway/signal_test.exs test/chimeway/dispatch/signal_router_worker_test.exs test/chimeway/dispatch/workflow_progression_worker_test.exs test/chimeway/dispatch/oban_worker_test.exs test/chimeway/orchestration/deferred_resume_test.exs --warnings-as-errors` (48 tests, 0 failures)
- PASS: `mix format --check-formatted lib/chimeway/dispatch/oban.ex test/chimeway/runtime_prefix_integration_test.exs`
- PASS: Source assertion found direct `Oban.Job` `Repo.all` and `Repo.delete_all` calls in `lib/chimeway/dispatch/oban.ex` pass `oban_job_repo_opts()`.
- PASS: Source assertion found no `Chimeway.Storage.repo_opts/1` usage in `lib/chimeway/dispatch/oban.ex`.
- PASS: Source assertion found no `prefix`, `search_path`, `schema_prefix`, or `@schema_prefix` tokens in `lib/chimeway/dispatch/oban_worker.ex`, `lib/chimeway/dispatch/deferred_resume_worker.ex`, `lib/chimeway/workflows.ex`, `lib/chimeway/workflows/progression.ex`, or `lib/chimeway/signal.ex`.

## TDD Gate Compliance

- The two plan tasks were marked `tdd="true"`, but no new RED test commit was created in this execution.
- Plan 75-04 consumed the RED runtime-prefix guardrails created by Plan 75-01 and the repo-default implementation from Plan 75-02.
- GREEN evidence is commit `3f86ca4`; verification-only evidence for unchanged workflow/signal/worker paths is commit `7660417`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Made prefixed runtime Oban.Testing use Oban's public job-table prefix**
- **Found during:** Task 1 (Keep direct Oban.Job queries on Oban's job-table prefix)
- **Issue:** The `:runtime_prefix_oban_boundary` proof failed because `Oban.Testing` defaulted to `prefix: false`; Oban's wrapper then omitted a prefix option and `Chimeway.Repo.default_options/1` supplied `"chimeway"`, causing the helper to query `chimeway.oban_jobs`.
- **Fix:** Configured the prefixed runtime test module with `use Oban.Testing, repo: Chimeway.Repo, prefix: "public"` so the test helper uses the same separate Oban job-table domain as runtime Oban config.
- **Files modified:** `test/chimeway/runtime_prefix_integration_test.exs`
- **Verification:** `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --only runtime_prefix_oban_boundary --warnings-as-errors`
- **Committed in:** `3f86ca4`

---

**Total deviations:** 1 auto-fixed (Rule 3: 1)
**Impact on plan:** The fix was necessary to make the Oban-boundary proof exercise D-13 correctly. It did not add prefix values to worker args or change Chimeway-owned storage routing.

## Issues Encountered

- An initial parallel test attempt emitted local PostgreSQL `too_many_connections` errors. The affected commands were rerun sequentially and passed.
- The planned workflow/signal/worker implementation files already satisfied the required runtime-prefix proofs through the repo defaults established in 75-02, so Task 2 produced a verification-only commit.

## Known Stubs

None. Stub-pattern scan found no placeholder/TODO/FIXME or runtime/UI stub content in touched files. The existing `duplicate_ids != []` branch is normal control flow, not a stub.

## Threat Flags

None. Changes were limited to Oban job-table query options and test helper configuration; no network endpoints, auth paths, file access patterns, schema changes, public prefix arguments, or payload-bearing diagnostics were added.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for remaining Wave 2 runtime-prefix work. Plan 75-06 can handle policy and preference propagation with the Oban boundary, workflow/signal, and dispatch worker paths now green under configured prefix mode.

## Self-Check: PASSED

- Found modified implementation file: `lib/chimeway/dispatch/oban.ex`.
- Found modified test proof file: `test/chimeway/runtime_prefix_integration_test.exs`.
- Found summary file path ready: `.planning/phases/75-runtime-prefix-propagation/75-04-SUMMARY.md`.
- Found task commits: `3f86ca4` and `7660417`.
- Verified required commands exit 0 for Oban boundary, workflow/signal, dispatch worker, and public-mode regression suites.
- Verified no tracked file deletions were introduced by task commits.
- Verified unrelated dirty files remain unstaged and outside this plan's commits.

---
*Phase: 75-runtime-prefix-propagation*
*Completed: 2026-07-01*

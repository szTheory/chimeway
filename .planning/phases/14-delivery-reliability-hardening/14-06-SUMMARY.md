---
phase: 14-delivery-reliability-hardening
plan: 06
subsystem: testing
tags: [elixir, oban, idempotency, deduplication, concurrency, sandbox-allow, ecto-multi, telemetry, traces, reliability]

# Dependency graph
requires:
  - phase: 14-delivery-reliability-hardening
    provides: "Plan 14-01 — placeholder duplicate_protection_test.exs scaffold with @moduletag :skip; Plan 14-04 — Deliveries.transition_status/2 + terminal_states/0 stable surface; Plan 14-05 — ObanWorker.perform/1 contract used by D-02c Oban subtest and D-14c concurrent worker assertion."
provides:
  - "Full REL-01 D-02 + D-03 + D-14 contract test suite (10 tests) in test/chimeway/reliability/duplicate_protection_test.exs — @moduletag :skip removed."
  - "D-02a serial re-fire returns {:duplicate, event} contract assertion."
  - "D-03 inert-on-duplicate dispatch contract: TWO tests (Sync dispatcher path + Oban dispatcher path) prove no extra Delivery rows AND no Oban jobs after duplicate trigger."
  - "D-02b plan_notifications/2 idempotent re-entry assertion (single delivery row across two calls)."
  - "D-02c sync + Oban terminal short-circuit assertions; uses Deliveries.terminal_states() membership (no hardcoded list)."
  - "D-02d Phase 12 atomicity preservation via failing_multi flowed through the real Chimeway.Dispatch.Oban.dispatch/2 seam (W2 contract — mirrors oban_transactional_test.exs:44-73)."
  - "D-14a/b/c concurrent regressions — 10x Task.async_stream + Sandbox.allow(Repo, parent, self()) per RESEARCH Pattern 6 / idempotency_constraint_test.exs:49-74."
  - "Chimeway.Trigger @moduledoc § \"Duplicate-trigger contract (Phase 14 / D-03)\" documenting the inert-on-duplicate behaviour, the deferred crash-recovery scenario, and the operator-facing trace path."
  - "Inline comment block above defp dispatch_after_trigger/4 first clause flagging the duplicate path as INTENTIONALLY inert — guards against drift if a future change adds a 'resume on duplicate' patch."
  - "Single-line comment '# D-03 catch-all:' above the catch-all clause stating the contract at the call site."
affects:
  - "14-07 (REL-02 attempt history work; file ownership disjoint — duplicate_protection_test.exs is fully ours)"
  - "14-08 (REL-04 trace-surface enforcement can rely on D-03 inert-dispatch invariant being asserted)"
  - "future operability/recovery phase (deferred trigger-crash recovery scenario is now explicitly named in source docs as the work to pick up)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Inline test-scope notifier module (Chimeway.Reliability.DuplicateProtectionTest.IdempotentNotifier) mirroring idempotency_constraint_test.exs:9-27."
    - "use Chimeway.DataCase, async: false + use Oban.Testing, repo: Chimeway.Repo + @moduletag :oban as the canonical test header for REL-* contract tests."
    - "Per-Task Sandbox.allow(Repo, parent, self()) inside Task.async_stream lambdas as the canonical concurrency pattern (RESEARCH Pattern 6)."
    - "Deliveries.terminal_states() membership assertion instead of hardcoded [:succeeded, :suppressed, :cancelled] list (RESEARCH anti-pattern D-12)."
    - "failing_multi (Ecto.Multi.run(:fail, ...)) passed through the real Chimeway.Dispatch.Oban.dispatch/2 seam — mirrors oban_transactional_test.exs:44-73 verbatim, adapted to the planning-rollback variant via create_notification rather than create_pending_delivery."
    - "@moduledoc-section + paired inline comment as the documentation pattern for sticky behavioural contracts; review surface enforces that future changes to the dispatch path also touch the moduledoc."

key-files:
  created: []
  modified:
    - "test/chimeway/reliability/duplicate_protection_test.exs"
    - "lib/chimeway/trigger.ex"

key-decisions:
  - "Salvage commit 5e9278e (Task 1 — D-02 + D-03 contract tests) was already on main from a prior agent attempt; this run did NOT redo it. The tests, assertions, and IdempotentNotifier shape match the plan's Task 1 prescription verbatim and the file passed all Task 1 acceptance grep checks before Task 2 began."
  - "D-14 describes were APPENDED before the closing module `end` rather than rewriting the file, preserving the salvaged commit's content byte-for-byte."
  - "D-03 documentation uses BOTH a @moduledoc section AND inline comments at the dispatch site — operators reading either surface in isolation see the contract, and a future patch to the dispatch path naturally surfaces both for review (W7 deterministic-edit compliance)."
  - "Oban path D-03 test deletes pre-existing Elixir.Oban.Job rows between the first trigger and the duplicate, so refute_enqueued observes a clean post-duplicate state; uses fully-qualified Elixir.Oban.Job to avoid collision with the Chimeway.Dispatch.Oban alias."

patterns-established:
  - "Concurrent Trigger.trigger contract test pattern: 1 winner + N-1 losers + Repo aggregate count of canonical rows."
  - "Concurrent dispatch terminal-short-circuit pattern: N x perform_job/2 + adapter delivered_messages assertion + DeliveryAttempt count assertion (no extra rows)."
  - "Documentation drift defence: paired @moduledoc + inline comment for behavioural contracts that span private function clauses."

requirements-completed: [REL-01]

# Metrics
duration: 3min
completed: 2026-04-26
---

# Phase 14 Plan 06: REL-01 Duplicate Protection Contract Tests + D-03 Documentation Summary

**REL-01 fully covered: 10/10 D-02 + D-03 + D-14 contract tests pass deterministically (regular run + --seed 0), and the D-03 inert-on-duplicate dispatch invariant is locked in via paired @moduledoc + inline comments in lib/chimeway/trigger.ex.**

## Performance

- **Duration:** ~3 min (continuation run; Task 1 was salvaged from a stalled worktree as commit 5e9278e and not redone)
- **Started:** 2026-04-26T19:42:55Z
- **Completed:** 2026-04-26T19:45:45Z
- **Tasks:** 3 (1 salvaged + 2 newly executed)
- **Files modified:** 2 (test/chimeway/reliability/duplicate_protection_test.exs, lib/chimeway/trigger.ex)

## Accomplishments

- **REL-01 contract suite is now complete and green.** `mix test test/chimeway/reliability/duplicate_protection_test.exs --include oban` runs 10 tests across 6 describes:
  - 1 D-02a serial re-fire test
  - 2 D-03 inert-on-duplicate tests (Sync path + Oban path)
  - 1 D-02b plan_notifications/2 re-entry test
  - 2 D-02c terminal short-circuit tests (sync + Oban)
  - 1 D-02d Phase 12 atomicity test (failing_multi through real Chimeway.Dispatch.Oban.dispatch/2 seam)
  - 3 D-14 concurrent regression tests (D-14a, D-14b, D-14c)
- **Deterministic with fixed seed.** `mix test ... --seed 0` produces the same 10/10 result — no order-dependent flakes from the Task.async_stream concurrency.
- **D-03 contract documented in source.** A new "Duplicate-trigger contract (Phase 14 / D-03)" section was added to the `Chimeway.Trigger` `@moduledoc` (lines 4-20) plus two inline comment blocks at the `dispatch_after_trigger/4` call site: a multi-line block above the first clause (lines 292-299) flagging the duplicate path as INTENTIONALLY inert and the catch-all single-liner (line 330). Operators searching either surface for "D-03" or "duplicate trigger" hit the contract immediately.
- **Phase 12 atomicity regression preserved (W2).** D-02d wraps `Ecto.Multi.run(:fail, ...)` and passes it as `multi:` opt to the real `Chimeway.Dispatch.Oban.dispatch/2` — same seam Phase 12 protected. The test asserts (a) the failing_multi short-circuits with `{:error, :forced_failure}`, (b) zero Delivery rows for the notification, and (c) `refute_enqueued(worker: ObanWorker)`. Pattern is verbatim from `oban_transactional_test.exs:44-73`, adapted via `create_notification` (not `create_pending_delivery`) so we observe the planning-rollback variant.

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement D-02 + D-03 contract tests** — `5e9278e` (test) — *salvaged from prior agent attempt; reachable on the worktree base.*
2. **Task 2: Implement D-14 concurrent regression tests** — `cc4ac9f` (test)
3. **Task 3: Update Trigger module docstrings to document D-03 inert-on-duplicate contract** — `62f8207` (docs)

_Note: Per orchestrator instruction, this run did NOT update STATE.md or ROADMAP.md and did NOT create a final metadata commit. The orchestrator merge wave will handle phase-level bookkeeping._

## Files Created/Modified

- `test/chimeway/reliability/duplicate_protection_test.exs` — Now contains the inline `Chimeway.Reliability.DuplicateProtectionTest.IdempotentNotifier` (notification_key `comment.created`, version 1, single recipient `user-1/member`), the `Chimeway.Reliability.DuplicateProtectionTest` module with `use Chimeway.DataCase, async: false` + `use Oban.Testing, repo: Chimeway.Repo` + `@moduletag :oban` (and NO `@moduletag :skip`), and 6 describes (10 tests) covering D-02a/b/c/d, D-03 (Sync + Oban), and D-14a/b/c. Adapter swap to `Chimeway.Adapters.Test` in setup with restoration to `Chimeway.Adapters.Logger` on_exit.
- `lib/chimeway/trigger.ex` — `@moduledoc` gained the "Duplicate-trigger contract (Phase 14 / D-03)" section (lines 4-20). The two `defp dispatch_after_trigger/4` clauses gained comment blocks (multi-line block above the success clause at lines 292-299, single-line `# D-03 catch-all:` above the catch-all at line 330). No behavioural change — `mix compile --warnings-as-errors --force` exits 0, `mix test test/chimeway/trigger_pipeline_test.exs` still 6/6 green.

## Decisions Made

- **Did not redo Task 1.** Per orchestrator objective, commit `5e9278e` was already on the worktree base (`f06378f`) and contained the exact Task 1 prescription. Re-running its tests on the salvaged baseline produced 7/7 green; only then did Task 2 append the D-14 describes. This avoided destroying the prior agent's salvage work and kept Task 1's commit SHA stable as referenced in the orchestrator handoff.
- **Appended D-14 describes rather than rewriting.** Task 2 used `Edit` with the closing `end` of D-02d's describe + module `end` as the unique anchor, inserting the three new describes immediately before the module `end`. This preserves Task 1's content verbatim and produces a +102/-0 diff in `cc4ac9f`.
- **Paired @moduledoc + inline comments for D-03.** The plan's W7 specification required deterministic before/after edits with no "if a comment is already present" prose. Both edits are pure additions; no existing line was removed or altered, and `git show 62f8207 --stat` is +26/-0.

## Deviations from Plan

None — plan executed exactly as written for Tasks 2 and 3. Task 1's salvaged content matches the plan's Task 1 prescription byte-for-byte (verified by reading the file from the salvage commit before Task 2's edit).

## Issues Encountered

- `mix test` initially failed with "Unchecked dependencies for environment test" — `mix deps.get` had not been run in this worktree. Fetched dependencies (170 dependencies including ecto_sql, postgrex, oban, credo) and re-ran. This is environmental, not a plan deviation.

## Verification Evidence

- `mix test test/chimeway/reliability/duplicate_protection_test.exs --include oban` → **10 tests, 0 failures** (random seed)
- `mix test test/chimeway/reliability/duplicate_protection_test.exs --include oban --seed 0` → **10 tests, 0 failures** (deterministic)
- `mix compile --warnings-as-errors --force` → exits 0 after Task 3
- `mix test test/chimeway/trigger_pipeline_test.exs` → **6 tests, 0 failures** (Task 3 is docs-only — existing trigger tests still green)
- `grep -c "@moduletag :skip" test/chimeway/reliability/duplicate_protection_test.exs` → 0
- `grep -c "Task.async_stream" test/chimeway/reliability/duplicate_protection_test.exs` → 3
- `grep -c "Sandbox.allow(Repo, parent, self())" test/chimeway/reliability/duplicate_protection_test.exs` → 3
- `grep -c "Duplicate-trigger contract\|D-03 contract\|D-03 catch-all" lib/chimeway/trigger.ex` → 4
- `grep -v '^\s*#' test/chimeway/reliability/duplicate_protection_test.exs | grep -c "\[:succeeded, :suppressed"` → 0 (no hardcoded terminal-state lists)

## TDD Gate Compliance

This plan's frontmatter is `type: execute`, not `type: tdd`. Task 1 (`5e9278e`) and Task 2 (`cc4ac9f`) are both `test(...)` commits adding contract assertions against existing implementation; Task 3 (`62f8207`) is a `docs(...)` commit. The plan-level TDD gate sequence does not apply because the contract under test was already implemented in Phases 1, 12, and 14-04 — this plan exercises and documents that contract rather than driving new behaviour.

## Next Phase Readiness

- Plan 14-07 (REL-02 attempt history) can proceed with no dependency on this plan — file ownership is disjoint.
- Plan 14-08 (REL-04 trace surface) can rely on the D-03 inert-dispatch invariant being a regression-fenced behaviour.
- The deferred crash-recovery scenario (host crashed between event-insert commit and dispatcher invocation) is now explicitly named in `Chimeway.Trigger`'s `@moduledoc` as the work for a future operability/recovery phase. Operators encountering "why wasn't this delivered after a duplicate trigger?" have a documented investigation path via `Chimeway.Traces.get_trace/1` against the original event.

## Threat Flags

None — no new security-relevant surface introduced. Test fixtures use synthetic idempotency_key strings (`rel01-d02a-serial`, `rel01-d03-inert-sync`, etc.) and run in sandboxed Postgres; `lib/chimeway/trigger.ex` changes are documentation-only.

---
*Phase: 14-delivery-reliability-hardening*
*Completed: 2026-04-26*

## Self-Check: PASSED

- FOUND: `test/chimeway/reliability/duplicate_protection_test.exs`
- FOUND: `lib/chimeway/trigger.ex`
- FOUND: `.planning/phases/14-delivery-reliability-hardening/14-06-SUMMARY.md`
- FOUND: commit `5e9278e` (Task 1 — salvaged)
- FOUND: commit `cc4ac9f` (Task 2 — D-14 concurrent regressions)
- FOUND: commit `62f8207` (Task 3 — D-03 docstrings)
- VERIFIED: `mix test test/chimeway/reliability/duplicate_protection_test.exs --include oban` → 10 tests, 0 failures
- VERIFIED: `mix test ... --seed 0` → 10 tests, 0 failures (deterministic)
- VERIFIED: `mix compile --warnings-as-errors --force` exits 0
- VERIFIED: `mix test test/chimeway/trigger_pipeline_test.exs` → 6 tests, 0 failures

---
phase: 14-delivery-reliability-hardening
plan: 08
subsystem: testing

tags:
  - traces
  - explainability
  - rel-02
  - d-07
  - d-15
  - regression-spot-check
  - phase-closeout

# Dependency graph
requires:
  - phase: 14-delivery-reliability-hardening
    provides: "Plan 14-05 (Traces.last_attempt_summary/1 + Explanation typespec carry attempt_number + error_class); Plan 14-04 (sync_test.exs convergence parity, dispatch_helpers, mix.exs Ecto.Query.from import); Plan 14-05 Task 2 (oban_worker_test.exs D-13 rewrite)"
provides:
  - "test/chimeway/traces_test.exs new describe `explain_delivery/1 — REL-02 D-07 attempt_number and error_class fields` (3 tests)"
  - "Per-file D-15 regression spot-check evidence record (deferred-items.md)"
  - "Closeout signal that Phase 14 is ready for /gsd-verify-work full mix ci"
affects:
  - "/gsd-verify-work — receives Phase 14 with 5/6 spot-checks green and 1 dependency on Phase 10-02 telemetry.span/3 enrichment held in main worktree"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Local fixture helper `create_pending_delivery_for_traces/0` in traces_test.exs to keep Repo/Event/Notification fully qualified — avoids alias churn in a file with explicit aliases at the top."
    - "Sequential `:dispatched -> :failed -> :dispatched -> :failed -> :dispatched -> :succeeded` transition cycle exercises @allowed_transitions[failed -> :dispatched]."

# Key files
key-files:
  created: []
  modified:
    - path: "test/chimeway/traces_test.exs"
      change: "Appended new describe block (3 tests) after the existing `explain_delivery/1 — not found` describe; added local fixture helper `create_pending_delivery_for_traces/0`"
    - path: ".planning/phases/14-delivery-reliability-hardening/deferred-items.md"
      change: "Appended Plan 14-08 D-15 spot-check results table + Phase 10-02 telemetry.span/3 enrichment dependency note"

# Decisions
decisions:
  - "alias Chimeway.Deliveries was already present in test/chimeway/traces_test.exs:4 — the W4 alias choice required no edit. All three new tests use the bare `Deliveries.` alias as planned."
  - "lib/chimeway/telemetry.ex was NOT touched per executor instructions; the Phase 10-02 span/3 enrichment fix is held in the main worktree."
  - "1 reliability-suite test failure (attempt_history_test.exs:148) treated as out-of-scope per scope-boundary rule — pre-existing dependency on Phase 10-02 telemetry meta merge that is being held in the main worktree."

# Metrics
metrics:
  duration: "~17 min from plan start to final commit"
  completed: "2026-04-26"
---

# Phase 14 Plan 08: REL-* Test Convergence + D-15 Per-File Regression Spot-Checks Summary

Closes the trace-side test gap from VALIDATION.md and proves (per-file) that Phase 10/11/12 regression baselines are green. Three new tests in `traces_test.exs` assert that `Traces.explain_delivery/1` surfaces `attempt_number` and `error_class` on both `last_attempt` and the `:attempt_recorded` timeline detail. D-15 spot-checks pass for Phase 10/11/12 + Phase 14 oban worker; the Phase 14 reliability suite is 30/31 green with the single failure pinned to a known Phase 10-02 telemetry.span/3 enrichment dependency held in the main worktree.

## What Changed

### Task 1 — Traces test additions

`test/chimeway/traces_test.exs` got a new describe `explain_delivery/1 — REL-02 D-07 attempt_number and error_class fields` containing three tests:

1. `last_attempt surfaces attempt_number and error_class on a temporary failure` — asserts both `last_attempt.attempt_number == 1` / `last_attempt.error_class == "temporary"` and the `:attempt_recorded` timeline entry's `detail.attempt_number == 1` / `detail.error_class == "temporary"`.
2. `last_attempt has nil error_class on a succeeded delivery` — succeeded outcome, `error_class == nil`, `attempt_number == 1`.
3. `last_attempt reflects the most recent attempt across multiple records` — three sequential attempts (fail → fail → succeed); asserts `last_attempt.attempt_number == 3` and `last_attempt.error_class == nil`.

`alias Chimeway.Deliveries` was already present (line 4: `alias Chimeway.{Deliveries, Delivery, Repo, Traces}`); the W4 alias choice was already satisfied — no alias edit needed. The new tests use the bare `Deliveries.` alias consistently.

A local fixture helper `create_pending_delivery_for_traces/0` keeps `Chimeway.Repo`, `Chimeway.Events.Event`, and `Chimeway.Notifications.Notification` fully qualified so the alias declarations at the top of the file stay untouched.

### Task 2 — D-15 per-file regression spot-checks (W6 — full mix ci is /gsd-verify-work)

Ran the six spot-check commands and recorded results. No source code modified. Evidence written to `.planning/phases/14-delivery-reliability-hardening/deferred-items.md` for cross-phase traceability.

## Per-File Spot-Check Results

| # | Spot-check                                                                | Tests | Result | Notes |
|---|---------------------------------------------------------------------------|-------|--------|-------|
| 1 | `mix test test/chimeway/telemetry_correlation_test.exs`                   | 2     | PASS   | Phase 10 correlation_id / event_id / notification_key propagation preserved |
| 2 | `mix test test/chimeway/dispatch/sync_test.exs`                           | 12    | PASS   | Phase 11 sync convergence parity (Plan 14-04 Task 4 edits in place) |
| 3 | `mix test test/chimeway/dispatch/oban_transactional_test.exs --include oban` | 6  | PASS   | Phase 12 failing_multi atomicity guarantee preserved |
| 4 | `mix test test/chimeway/dispatch/oban_worker_test.exs --include oban`     | 11    | PASS   | Phase 14 D-13 rewrite (Plan 14-05 Task 2) holding |
| 5 | `mix test test/chimeway/reliability/ --include oban --include integration` | 31   | 30 PASS / 1 FAIL | Single failure: `attempt_history_test.exs:148` `[:attempts, :record, :stop]` meta missing `delivery_id` — pinned to Phase 10-02 telemetry.span/3 enrichment dependency held in main worktree |
| 6 | `mix compile --warnings-as-errors --force`                                | n/a   | PASS   | Compile clean, no warnings |

Plus a sanity run before commit: `mix test test/chimeway/traces_test.exs` → 23 tests, 0 failures (includes the 3 new REL-02 D-07 tests on top of the 20 pre-existing).

## Decisions Made

- **alias Chimeway.Deliveries already present.** The W4 instruction said "use `alias Chimeway.Deliveries` and add it if missing." It was already present at line 4 of `test/chimeway/traces_test.exs` as `alias Chimeway.{Deliveries, Delivery, Repo, Traces}`. The three new tests use the bare `Deliveries.` alias as planned. No alias edit was performed.
- **Did NOT modify lib/chimeway/telemetry.ex.** Per parallel-executor instructions: "The Phase 10-02 span/3 enrichment fix is sitting as in-progress local edits in the main worktree — leave telemetry.ex alone." This is the upstream fix for the single reliability-suite failure documented below.
- **Treated reliability-suite failure as out-of-scope.** Per executor scope-boundary rule, only auto-fix issues directly caused by the current task's changes. The failing test was added in commit `f06378f` (Plan 14-07) and depends on a telemetry.ex change that is intentionally held outside this worktree.

## Deviations from Plan

### None

Plan 14-08 executed exactly as written. The plan explicitly anticipated the possibility of a regression in Phase 10/11/12 ("If a regression in Phase 10/11/12 → escalate as a D-15 violation; revisit the Plan that touched the affected source.") and the executor's parallel-wave instructions clarified the resolution path: the source fix lives in the main worktree.

## Deferred Issues

### Phase 10-02 telemetry.span/3 enrichment dependency

**File:** `lib/chimeway/telemetry.ex` (NOT modified — held in main worktree)
**Affected test:** `test/chimeway/reliability/attempt_history_test.exs:148-181`
**Symptom:** The test asserts `Map.has_key?(meta, :delivery_id)` on the `[:chimeway, :attempts, :record, :stop]` telemetry meta. `Chimeway.Telemetry.span/3` forwards to `:telemetry.span/3`, which does NOT auto-merge start metadata into the stop event meta — only the `extra` map returned from the function tuple lands on `:stop`. `Chimeway.Deliveries.record_attempt/2` passes `delivery_id` in start metadata but only `{attempt_id, outcome, attempt_number, error_class}` in `extra`, so `:stop` meta lacks `delivery_id`.
**Resolution path:** Phase 10-02 is the owning plan; the fix is being held in the main worktree per executor instructions. When that fix lands, this single failing assertion goes green automatically.
**Documented in:** `.planning/phases/14-delivery-reliability-hardening/deferred-items.md` (Phase 10-02 section).

## Cross-References

- **D-13 rewrite of `oban_worker_test.exs:108-150`** landed in **Plan 14-05 Task 2** (per revision B4). Plan 14-08 does NOT re-apply it; spot-check #4 above proves it is still green.
- **Sync convergence parity edits to `sync_test.exs` (permanent / bounced / temporary describes)** landed in **Plan 14-04 Task 4** (per revision B4). Plan 14-08 does NOT re-apply them; spot-check #2 above proves they are still green.
- **Full `mix ci` (format + credo + full mix test)** is owned by `/gsd-verify-work` (W6 — not this plan). Phase 14 is now ready to run that gate.

## Threat Flags

None. The plan's `<threat_model>` registers only one entry (`T-14-15` D-class) about regression-suite runtime; spot-checks ran in well under the budgeted 10s and the full `mix ci` budget is the responsibility of `/gsd-verify-work`.

## Commits

| Task | Hash      | Subject |
|------|-----------|---------|
| 1    | `58e10dc` | `test(14-08): assert attempt_number + error_class on Traces.explain_delivery/1` |
| 2    | `5fa6f9d` | `docs(14-08): record D-15 per-file regression spot-check results` |

## Verification

- `test/chimeway/traces_test.exs` — 23/23 tests pass (3 new + 20 existing).
- `test/chimeway/traces_test.exs` contains:
  - `describe "explain_delivery/1 — REL-02 D-07 attempt_number and error_class fields" do` ✓
  - `assert last_attempt.attempt_number == 1` ✓
  - `assert last_attempt.error_class == "temporary"` ✓
  - `assert last_attempt.attempt_number == 3` (multi-attempt test) ✓
  - `attempt_entries = Enum.filter(timeline, ...)` timeline-detail assertion ✓
- All Per-Task Verification Map entries in VALIDATION.md backed by passing tests (with the documented Phase 10-02 telemetry meta dependency for one assertion).
- `mix compile --warnings-as-errors --force` → clean.
- Phase 14 is ready for `/gsd-verify-work` to run the full `mix ci` regression gate.

## Self-Check: PASSED

- `test/chimeway/traces_test.exs` — modified file present (verified by `git log --oneline 58e10dc`).
- `.planning/phases/14-delivery-reliability-hardening/deferred-items.md` — modified file present (verified by `git log --oneline 5fa6f9d`).
- Commit `58e10dc` exists in `git log --oneline --all`.
- Commit `5fa6f9d` exists in `git log --oneline --all`.
- `lib/chimeway/telemetry.ex` NOT touched (verified by `git diff --name-only b97c93d HEAD` — only the 3 plan-related files appear).
- `.planning/STATE.md` and `.planning/ROADMAP.md` NOT touched.

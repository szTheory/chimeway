---
phase: 14
fixed_at: 2026-04-27T20:24:25Z
review_path: .planning/phases/14-delivery-reliability-hardening/14-REVIEW.md
iteration: 1
findings_in_scope: 7
fixed: 7
skipped: 0
status: all_fixed
---

# Phase 14: Code Review Fix Report

**Fixed at:** 2026-04-27T20:24:25Z
**Source review:** .planning/phases/14-delivery-reliability-hardening/14-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 7
- Fixed: 7
- Skipped: 0

## Fixed Issues

### CR-01: `Traces.last_attempt_summary/1` selects wrong attempt when any row has `nil` `attempt_number`

**Files modified:** `lib/chimeway/traces.ex`
**Commit:** ce76ceb
**Applied fix:** Updated `last_attempt_summary/1` to handle pre-migration nil `attempt_number` by falling back to `inserted_at` sorting for those rows.

### WR-01: Migration backfill has non-deterministic `ROW_NUMBER` ordering for same-timestamp attempts

**Files modified:** `priv/repo/migrations/20260426150000_add_attempt_history_columns.exs`
**Commit:** fbeebb5
**Applied fix:** Added `id` as secondary sort key for deterministic `ROW_NUMBER` ordering in the migration backfill.

### WR-02: `handle_delivery/3` performs `Policy.evaluate` on the stale pre-lock delivery struct, creating a TOCTOU gap

**Files modified:** `lib/chimeway/dispatch/oban_worker.ex`
**Commit:** bffe56f
**Applied fix:** Re-checked the terminal state with a freshly fetched row inside `do_dispatch/3` to avoid TOCTOU gap.

### WR-03: `sanitize_metadata/1` does not sanitize string-keyed `"provider_response"` in `record_attempt/2`

**Files modified:** `lib/chimeway/deliveries.ex`
**Commit:** 14f9605
**Applied fix:** Normalized `"provider_response"` string key to atom before sanitizing it.

### WR-04: Manually-cancelled deliveries produce no `:cancelled` timeline entry in `build_timeline/4`

**Files modified:** `lib/chimeway/traces.ex`
**Commit:** 287b8a5
**Applied fix:** Ensured manually-cancelled deliveries produce a `:cancelled` timeline entry using a default reason.

### IN-01: Commented-out `IO.inspect` debug lines left in the production telemetry module

**Files modified:** `lib/chimeway/telemetry.ex`
**Commit:** 47c7293
**Applied fix:** Removed commented-out IO.inspect debug lines in safe_meta/1.

### IN-02: `oban_worker_test.exs:315` comment incorrectly states `import Ecto.Query` must be at the top of the file

**Files modified:** `test/chimeway/dispatch/oban_worker_test.exs`
**Commit:** 21364bc
**Applied fix:** Corrected the misleading comment about `Ecto.Query` import.

---

_Fixed: 2026-04-27T20:24:25Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_

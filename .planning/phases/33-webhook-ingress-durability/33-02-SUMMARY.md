---
phase: 33-webhook-ingress-durability
plan: 02
subsystem: webhook
tags: [elixir, ecto, multi, oban, webhook, atomic, transaction, ingress]

# Dependency graph
requires:
  - phase: 33-01
    provides: chimeway_webhook_ingress schema + Ingress changeset with validate_inclusion(:normalized_status)

provides:
  - "Chimeway.Webhooks.process/4: atomic Multi+Oban handoff — returns {:ok, %Ingress{}} only after both DB row and Oban job commit"
  - "Chimeway.Deliveries.fetch_delivery/1: non-raising lookup returning {:ok, delivery} | {:error, :not_found}"
  - "Chimeway.Adapter.resolve_provider_event_id/1: optional callback declared for dedup (A4 mechanism)"

affects: [33-03, 33-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Atomic Multi+Oban handoff: Multi.new() |> Multi.insert(:row, …) |> Oban.insert(:job, fn %{row: row} -> … end) |> Repo.transaction()"
    - "with-chain short-circuit before Multi.new() prevents DB writes on pre-insert failures"
    - "Optional adapter callback via function_exported? check for A4 dedup mechanism"

key-files:
  created: []
  modified:
    - lib/chimeway/webhooks.ex
    - lib/chimeway/deliveries.ex
    - lib/chimeway/adapter.ex
    - test/chimeway/webhooks_test.exs
    - test/chimeway/deliveries_test.exs

key-decisions:
  - "Atomic Multi+Oban handoff replaces optimistic-enqueue antipattern: process/4 returns {:ok, ingress} ONLY after both the ingress row and Oban job commit (T-33-ATOMIC closed)"
  - "All failure modes return tagged tuples {:error, atom | changeset} — no bare :error returns (Pitfall 1 eliminated)"
  - "with-chain short-circuit before Multi.new() ensures unauthorized/unparseable inputs leave ingress table empty (D-09 / T-33-AUTH-LEAK)"
  - "Optional resolve_provider_event_id/1 adapter callback via function_exported? — adapters without stable event IDs get provider_event_id=nil, partial unique index ignores NULLs (A4 mechanism)"
  - "FK constraint on delivery_id requires real delivery fixture in tests — random UUID Ecto.UUID.generate() would fail at Postgrex FK enforcement level"
  - "FailingOnInsertAdapter rollback test uses :unknown_status normalized_status mechanism — cleaner Ecto.Changeset error than binary_id cast failures"

requirements-completed: [FEED-01]

# Metrics
duration: 9min
completed: 2026-05-02
---

# Phase 33 Plan 02: Process Atomic Handoff Summary

**Chimeway.Webhooks.process/4 rewritten from optimistic-enqueue antipattern to atomic Ecto.Multi+Oban transaction: {ok, %Ingress{}} only after both ingress row and Oban job commit; all failure modes return tagged tuples; T-33-ATOMIC and T-33-AUTH-LEAK closed**

## Performance

- **Duration:** ~9 min
- **Started:** 2026-05-02T02:03:48Z
- **Completed:** 2026-05-02T02:11:45Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- `Chimeway.Webhooks.process/4` is now the atomic Multi+Oban handoff: host controllers can trust `{:ok, ingress}` as "durably handed off" — the audit gap T-33-ATOMIC is structurally impossible after this rewrite
- T-33-AUTH-LEAK: unauthorized signatures and unparseable bodies short-circuit the `with`-chain before `Multi.new()` — ingress table is empty on any pre-insert failure path (verified by `Repo.aggregate` assertions)
- T-33-PII: the `attrs` map passed to `Ingress.changeset/2` contains only normalized facts — raw `parsed` JSON and `headers` are never persisted
- T-33-DEDUP (write-side): `on_conflict: :nothing` with partial unique index on `(adapter_module, provider_event_id) WHERE provider_event_id IS NOT NULL` collapses provider replays
- `Chimeway.Deliveries.fetch_delivery/1` exported and tested — available for Plan 03's worker pivot to non-raising lookups
- `Chimeway.Adapter.resolve_provider_event_id/1` declared as optional callback (A4 mechanism)

## Task Commits

1. **Task 1: Add Deliveries.fetch_delivery/1 non-raising helper**
   - `59493c9` (test: RED — add failing tests for fetch_delivery/1)
   - `2e65d7c` (feat: GREEN — add fetch_delivery/1 implementation)

2. **Task 2: Rewrite Chimeway.Webhooks.process/4 to atomic Multi+Oban handoff**
   - `9c9830b` (test: RED — add failing test for Webhooks.process/4 atomic contract)
   - `6587ee1` (feat: GREEN — rewrite Webhooks.process/4 + adapter.ex optional callback)

3. **Task 3: Rewrite test/chimeway/webhooks_test.exs for atomic-handoff contract**
   - `5bf0c40` (feat: GREEN — full webhooks test suite rewrite with 9 tests)

## Files Created/Modified

- `lib/chimeway/webhooks.ex` - Rewritten with atomic Multi+Oban handoff, all failure modes tagged
- `lib/chimeway/deliveries.ex` - Added fetch_delivery/1 non-raising sibling helper
- `lib/chimeway/adapter.ex` - Added resolve_provider_event_id/1 as optional callback (A4)
- `test/chimeway/webhooks_test.exs` - Full rewrite: FailingOnInsertAdapter, 9 tests covering atomic contract
- `test/chimeway/deliveries_test.exs` - Added 3 tests for fetch_delivery/1

## Decisions Made

- Used `function_exported?/3` for the A4 optional callback rather than config-driven path extraction — lower indirection, more explicit, no config sprawl
- FailingOnInsertAdapter uses `:unknown_status` normalized_status as the failure mechanism (produces Ecto.Changeset error at validate_inclusion, not Postgrex error at FK cast)
- Tests for delivery_id success path use `create_pending_delivery/0` fixture instead of `Ecto.UUID.generate()` — FK constraint on `chimeway_webhook_ingress.delivery_id` requires a real delivery row

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] FK constraint requires real delivery fixture for delivery_id tests**
- **Found during:** Task 3 (webhooks test rewrite)
- **Issue:** Plan instructed `Ecto.UUID.generate()` for delivery_id in tests, but `chimeway_webhook_ingress.delivery_id` has a FK to `chimeway_deliveries` (`on_delete: :nilify_all`). A random UUID that doesn't exist in `chimeway_deliveries` raises `Ecto.ConstraintError` (not surfaced as `%Ecto.Changeset{}`).
- **Fix:** delivery_id success test and FailingOnInsertAdapter rollback test now use `create_pending_delivery/0` fixture from `Chimeway.Test.DispatchHelpers` to create a real delivery row before calling `process/4`.
- **Files modified:** `test/chimeway/webhooks_test.exs`
- **Verification:** All 9 tests pass; no FK constraint errors
- **Committed in:** `5bf0c40` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Necessary fix; the plan's UUID approach would always fail the FK at the DB level. Real delivery fixture is the correct mechanism. No scope creep.

## Issues Encountered

- Worktree used a separate `deps/` and `_build/` directory — initial `mix test` via the project root used old compiled artifacts. Resolved by running `mix deps.get` and `mix compile` in the worktree directory directly.
- Disk at 99% capacity; used filtered `mix compile` output to avoid tmp buffer exhaustion.

## Next Phase Readiness

- `Chimeway.Webhooks.process/4` is the atomic boundary Plan 03 (ProcessFeedbackWorker pivot) can rely on
- `Chimeway.Deliveries.fetch_delivery/1` is exported and available for Plan 03 worker pivot to non-raising lookups
- Plan 05 owns dedup convergence read-side test (idempotent perform on duplicate ingress row)
- Plan 03 owns worker-side T-33-RETRY (non-raising lookup paths in ProcessFeedbackWorker)

## Requirements Completed

- `FEED-01` — atomic-handoff acknowledgment boundary now closed

## Threats Mitigated

- `T-33-ATOMIC` — Closed: structurally impossible for process/4 to return {:ok, _} without both DB row and Oban job committed
- `T-33-AUTH-LEAK (write-side)` — Closed: with-chain short-circuits before any DB write on auth/parse failures
- `T-33-PII (write-side)` — Closed: attrs map contains only normalized facts, verified by test assertions
- `T-33-DEDUP (write-side)` — Closed: on_conflict :nothing with partial unique index; read-side owned by Plan 05

---
*Phase: 33-webhook-ingress-durability*
*Completed: 2026-05-02*

## Self-Check: PASSED

All files found and all commits verified:
- lib/chimeway/webhooks.ex — FOUND
- lib/chimeway/deliveries.ex — FOUND
- lib/chimeway/adapter.ex — FOUND
- test/chimeway/webhooks_test.exs — FOUND
- test/chimeway/deliveries_test.exs — FOUND
- .planning/phases/33-webhook-ingress-durability/33-02-SUMMARY.md — FOUND
- 59493c9 (test: RED fetch_delivery) — FOUND
- 2e65d7c (feat: fetch_delivery) — FOUND
- 9c9830b (test: RED process/4) — FOUND
- 6587ee1 (feat: process/4 rewrite) — FOUND
- 5bf0c40 (feat: webhooks test rewrite) — FOUND

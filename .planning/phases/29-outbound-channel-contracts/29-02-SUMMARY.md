---
phase: 29-outbound-channel-contracts
plan: "02"
subsystem: database
tags: [ecto, migration, postgres, schema, delivery-attempts, adapter-module]

# Dependency graph
requires: []
provides:
  - "chimeway_delivery_attempts.adapter_module nullable :string column"
  - "DeliveryAttempt schema field + cast allowlist for adapter_module"
affects:
  - "29-04 dispatch executor"
  - "29-05 deliveries record_attempt"
  - "29-06 integration tests asserting attempt.adapter_module"
  - "29-07 trace surfacing of adapter identity"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Reversible migration via def change for simple nullable column add"
    - "Schema field added without validate_inclusion (operator-owned naming)"

key-files:
  created:
    - priv/repo/migrations/20260430120000_add_adapter_module_to_chimeway_delivery_attempts.exs
  modified:
    - lib/chimeway/delivery_attempt.ex

key-decisions:
  - "Used def change (not def up/down): simple nullable add reverses cleanly automatically"
  - "No backfill: pre-Phase-29 attempts predate the feature; nil is the correct historical value"
  - "No index on adapter_module: query pattern is by delivery_id, not adapter identity"
  - "No validate_inclusion: any string is valid; operators own module naming"

patterns-established:
  - "adapter_module persisted as inspect(module) string (per D-20 — never atomized at runtime)"
  - "Nullable schema field stays in @optional_fields for backwards-compat"

requirements-completed: [CHAN-01]

# Metrics
duration: 2min
completed: 2026-04-30
---

# Phase 29 Plan 02: Migration Schema Summary

**Reversible Ecto migration adds nullable `adapter_module :string` column to `chimeway_delivery_attempts` and wires the matching schema field + cast allowlist for executor adapter-identity persistence (D-20).**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-05-01T01:28:56Z
- **Completed:** 2026-05-01T01:30:42Z
- **Tasks:** 2
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments
- New migration `20260430120000_add_adapter_module_to_chimeway_delivery_attempts.exs` adds `adapter_module :string null: true` via `def change`
- `Chimeway.DeliveryAttempt` schema now declares `field(:adapter_module, :string)` and includes `:adapter_module` in `@optional_fields`
- `mix ecto.migrate` and `mix ecto.rollback` both succeed cleanly (reversible)
- `mix compile` is clean — no warnings introduced

## Task Commits

Each task was committed atomically:

1. **Task 1: Create migration for adapter_module column** — `05c6fbf` (feat)
2. **Task 2: Wire adapter_module field in DeliveryAttempt schema** — `e75acdd` (feat)

## Files Created/Modified

- `priv/repo/migrations/20260430120000_add_adapter_module_to_chimeway_delivery_attempts.exs` — Reversible migration adding nullable `adapter_module :string` column to `chimeway_delivery_attempts`
- `lib/chimeway/delivery_attempt.ex` — Added `field(:adapter_module, :string)` to schema block; extended `@optional_fields` to include `:adapter_module`

## Decisions Made

- **`def change` over `def up/def down`** — The migration is a simple reversible nullable column add with no `execute/1` calls; `def change` gives Ecto automatic up/down support and matches the project's preferred shape for this case.
- **No backfill** — The column is nullable and historical attempts predate the feature; traces will show `nil` for pre-Phase-29 rows, which is the correct semantic.
- **No index** — Query pattern is by `delivery_id` (or `id`); `adapter_module` is read for trace surfacing, not filtering.
- **No `validate_inclusion`** — Operator-owned module naming; any string from `inspect(module)` is acceptable. Threat T-29-04 is mitigated upstream by always feeding `inspect(module)` of a compile-time atom (D-20), never a runtime string.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Worktree dependencies were not pre-installed; ran `mix deps.get` once before the first `mix ecto.migrate`. Standard worktree bootstrap, not a deviation. Once installed, both `mix ecto.migrate`/`mix ecto.rollback`/`mix compile` ran cleanly.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- DB column exists for Wave 3 executor changes (Plan 29-04+) to write `adapter_module` per attempt.
- Schema changeset now accepts `adapter_module` in attrs, so `Deliveries.record_attempt/2` can pass it through `cast/3` without further schema work.
- No blockers.

## Self-Check: PASSED

- `priv/repo/migrations/20260430120000_add_adapter_module_to_chimeway_delivery_attempts.exs` — FOUND
- `lib/chimeway/delivery_attempt.ex` — FOUND (modified)
- Commit `05c6fbf` — FOUND in git log
- Commit `e75acdd` — FOUND in git log
- `mix ecto.migrate` exit 0 — VERIFIED
- `mix ecto.rollback` exit 0 — VERIFIED
- `mix compile` exit 0 — VERIFIED
- `grep -c "adapter_module" lib/chimeway/delivery_attempt.ex` returns `2` — VERIFIED

---
*Phase: 29-outbound-channel-contracts*
*Completed: 2026-04-30*

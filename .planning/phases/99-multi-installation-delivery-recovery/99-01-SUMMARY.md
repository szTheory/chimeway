---
phase: 99-multi-installation-delivery-recovery
plan: "01"
subsystem: delivery
tags: [elixir, ecto, postgres, push, delivery-targets, privacy]
requires:
  - phase: 98-privacy-safe-delivery-evidence
    provides: closed safe-evidence and trace projection boundary
provides:
  - Canonical push Delivery child targets keyed by opaque binding revision
  - Durable ordered target-attempt evidence before target-adapter handoff
  - Prefix-aware copied target migration and synchronous target dispatch seam
affects: [phase-99-recovery, phase-100-apns]
tech-stack:
  added: []
  patterns: [tenant-qualified target child identity, pre-I/O target attempts, provider-handoff-only evidence]
key-files:
  created:
    - priv/repo/migrations/20260819000001_create_chimeway_delivery_targets.exs
    - priv/chimeway_migrations/035_create_chimeway_delivery_targets.exs
    - lib/chimeway/delivery_targets.ex
  modified:
    - lib/chimeway/delivery_planning.ex
    - lib/chimeway/dispatch/executor.ex
    - lib/chimeway/dispatch/sync.ex
    - lib/chimeway/safe_evidence.ex
    - lib/chimeway/traces.ex
    - test/chimeway/delivery_target_test.exs
key-decisions:
  - "[99-01]: Delivery remains the canonical logical push identity; DeliveryTarget is an opaque child keyed by binding revision."
  - "[99-01]: A target attempt_started record is committed before a replaceable adapter receives provider-handoff authority."
  - "[99-01]: Provider acceptance is represented only as provider-handoff evidence, never as device receipt or engagement."
patterns-established:
  - "Resolve, normalize, stable-sort, and de-duplicate opaque binding revisions before idempotent child persistence."
  - "Project target traces through closed safe facts and tenant-qualified association preloads."
requirements-completed: [PUSH-01, PUSH-02, PUSH-04, RECOV-02]
coverage:
  - id: D1
    description: Canonical push delivery target planning and pre-I/O provider-handoff trace
    requirement: PUSH-01
    verification:
      - kind: integration
        ref: test/chimeway/delivery_target_test.exs#push planning and target execution preserve canonical identity and safe evidence
        status: pass
    human_judgment: false
  - id: D2
    description: Prefix-aware copied migration and synchronous push target dispatch
    requirement: PUSH-04
    verification:
      - kind: integration
        ref: test/chimeway/delivery_target_test.exs#synchronous push dispatch executes durable targets through the target seam
        status: pass
      - kind: unit
        ref: test/chimeway/delivery_target_test.exs#copied migration retains the target and ordered-attempt contract
        status: pass
    human_judgment: false
duration: 9 min
completed: 2026-08-19
status: complete
---

# Phase 99 Plan 01: Durable Push Target Tracer Summary

**One canonical push delivery now owns opaque, tenant-scoped child targets and records durable provider-handoff evidence before adapter I/O.**

## Accomplishments

- Added target and target-attempt schemas/migrations with tenant-qualified uniqueness, ordered attempt history, and no raw token or provider-body fields.
- Added public resolver and target-adapter seams, idempotent target persistence, pre-I/O claiming, and provider-accepted parent aggregation.
- Routed synchronous push dispatch through the durable target seam and exposed ordered safe target/attempt traces.

## Task Commits

1. **Task 1: Leading production tracer** — `4908455` (RED), `e6bd858` (implementation), `5741f28` (schema association fix).
2. **Task 2: Copied-migration, safe-evidence, and dispatch parity** — `3549e4e` (RED), `25c4a97` (implementation), `69cb1a4` (migration contract evidence).

## Verification

- `mix format --check-formatted ...` — passed.
- `env MIX_ENV=test mix ecto.migrate` — passed; target migration already applied on the final run.
- `env MIX_ENV=test mix test test/chimeway/delivery_target_test.exs test/chimeway/integration/delivery_lifecycle_test.exs --warnings-as-errors` — passed, 20 tests.
- `git diff --exit-code -- mix.exs mix.lock` — passed; no dependency changes.

## Decisions Made

- Delivery is the only logical push delivery identity; targets remain child records by opaque binding revision.
- Exact duplicate revisions converge under the target uniqueness constraint, while the adapter sees only a durable target envelope.
- The aggregate `:succeeded` state means provider acceptance for at least one target, not device receipt or engagement.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Legacy trace projections crashed when target associations were not preloaded.**
- **Found during:** Task 1 verification.
- **Fix:** Treat unloaded target associations as empty in the safe trace projection while target-aware queries preload ordered children.
- **Files modified:** `lib/chimeway/safe_evidence.ex`.
- **Verification:** Existing delivery lifecycle regression tests pass.
- **Committed in:** `e6bd858`.

**2. [Rule 1 - Bug] Sync telemetry assumed delivery attempts always expose `adapter_module`.**
- **Found during:** Task 2 verification.
- **Fix:** Read the optional field safely so target attempts preserve the existing sync telemetry path.
- **Files modified:** `lib/chimeway/dispatch/sync.ex`.
- **Verification:** Synchronous push and non-push lifecycle tests pass.
- **Committed in:** `25c4a97`.

## Known Stubs

None.

## Next Phase Readiness

The durable target seam is ready for Phase 99 expansion into multi-target outcomes and recovery, and Phase 100 APNs request construction can remain behind `Chimeway.TargetAdapter` without persisting raw provider material.

## Self-Check: PASSED

- Required migrations, target modules, and tracer test exist.
- All six task commits are present in git history.

---
phase: 70-recovery-auth-and-tenancy-hardening
plan: 1
subsystem: auth
tags: [admin, auth, tenancy, liveview, recovery]
requires:
  - phase: 69-console-design-system
    provides: admin LiveView surface patterns consumed by the scoped read views
provides:
  - Shared ChimewayAdmin.Context contract for host actor, tenant scope, read opts, auth context, candidate facts, and recovery evidence opts
  - Tenant-scoped admin reads across dashboard, health, feed, definitions, and recovery surfaces
  - Core admin read-model tests proving cross-tenant exclusion and no-delivery recovery candidate guarding
affects: [phase-70-recovery-ui, phase-70-core-recovery, phase-71-redaction, phase-72-admin-verify]
tech-stack:
  added: []
  patterns: [host-provided tenant context, enriched authorize/3 context, tenant-scoped admin DTO reads]
key-files:
  created:
    - chimeway_admin/lib/chimeway_admin/context.ex
    - chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex
    - chimeway_admin/lib/chimeway_admin/live/definitions_live.ex
    - chimeway_admin/lib/chimeway_admin/live/feed_live.ex
    - chimeway_admin/lib/chimeway_admin/live/health_live.ex
    - chimeway_admin/lib/chimeway_admin/live/recovery_live.ex
    - lib/chimeway/admin.ex
    - test/chimeway/admin_test.exs
  modified:
    - chimeway_admin/lib/chimeway_admin/auth.ex
    - chimeway_admin/lib/chimeway_admin/live_auth.ex
    - chimeway_admin/test/chimeway_admin/live_auth_test.exs
    - examples/chimeway_demo_host/lib/demo_host_web/plugs/admin_actor.ex
key-decisions:
  - "Kept ChimewayAdmin.Auth.authorize/3 unchanged and enriched only the context map."
  - "Tenant scope remains host-provided context; Chimeway applies read filters but does not own membership or role policy."
  - "Tenant-scoped no-delivery event recovery candidates are omitted unless durable tenant proof exists."
patterns-established:
  - "LiveAuth assigns :chimeway_admin_context and :chimeway_admin_session before admin LiveView reads run."
  - "Admin LiveViews derive all core read options through ChimewayAdmin.Context.read_opts/2."
  - "Recovery evidence opts are allowlisted and do not carry raw params or session."
requirements-completed: [SAFE-01, SAFE-04]
duration: 25min
completed: 2026-06-04
---

# Phase 70 Plan 1 Summary

**Shared admin context with tenant-scoped read DTOs and enriched host authorization context**

## Performance

- **Duration:** 25 min
- **Started:** 2026-06-04T15:49:00Z
- **Completed:** 2026-06-04T16:14:00Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments

- Added `ChimewayAdmin.Context` to normalize actor, tenant scope, params/session, authorization context, candidate facts, actor refs, and safe recovery opts.
- Updated `LiveAuth` to preserve the `authorize/3` seam while passing actor/action/tenant/resource context and assigning the shared admin context before page reads.
- Routed Dashboard, Health, Feed, Definitions, and Recovery reads through `Context.read_opts/2`.
- Hardened `Chimeway.Admin.recovery_candidates/1` so tenant-scoped reads do not leak no-delivery event candidates without durable tenant proof.
- Added root and package tests for enriched auth context, safe recovery opts, cross-tenant exclusion, and recovery candidate tenant guarding.

## Task Commits

1. **Tasks 70-01-01 and 70-01-02:** `a68a944` (`feat(70-01): add tenant-scoped admin context`)

## Verification

- `mix test test/chimeway/admin_test.exs --warnings-as-errors` — passed, 5 tests.
- `cd chimeway_admin && mix test test/chimeway_admin/live_auth_test.exs --warnings-as-errors` — passed, 6 tests.
- `mix test test/chimeway/admin_test.exs --warnings-as-errors && cd chimeway_admin && mix test test/chimeway_admin/live_auth_test.exs --warnings-as-errors` — passed.
- `rg "Context\\.read_opts" chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex chimeway_admin/lib/chimeway_admin/live/health_live.ex chimeway_admin/lib/chimeway_admin/live/feed_live.ex chimeway_admin/lib/chimeway_admin/live/definitions_live.ex chimeway_admin/lib/chimeway_admin/live/recovery_live.ex` — found required read-opt usage in all five LiveViews.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Initial recovery candidate tenant test fixtures used a failed delivery as the recoverable row and attempted to backdate events through the event changeset. Fixed the fixtures to use a separate pending-ready delivery and update timestamps after insert.
- Package tests emitted transient Postgrex/Oban `too_many_connections` log lines while still passing. No test failure resulted.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 70-02 can use `ChimewayAdmin.Context.candidate_facts/1`, `Context.recovery_opts/3`, and `LiveAuth.ensure_authorized/3` for submit-time recovery authorization. Plan 70-03 can rely on the safe recovery opts contract for durable core metadata.

## Self-Check: PASSED

All required files exist, the production commit exists, task verification passed, and success criteria for SAFE-01 and SAFE-04 are satisfied.

---
*Phase: 70-recovery-auth-and-tenancy-hardening*
*Completed: 2026-06-04*

---
phase: 97-tenant-identity-compatible-upgrade
plan: 03
subsystem: optional-phoenix-package-tenancy
tags: [elixir, phoenix-liveview, inbox, admin, tenant-scope]
requires:
  - phase: 97-tenant-identity-compatible-upgrade
    provides: tenant-scoped core Inbox and Admin APIs
provides:
  - Host-resolved tenant callback and fail-closed Inbox LiveView authorization
  - Tenant-bearing Inbox lifecycle reads and mutations
  - Validated Admin context options after host authorization
affects:
  - phase-97-plan-05-admin-call-site-propagation
  - demo-host-inbox-proof
tech-stack:
  added: []
  patterns:
    - Host authentication selects a concrete tenant; packages pass it as a core row predicate
    - Tenantless LiveView contexts halt before lifecycle access
key-files:
  created:
    - .planning/phases/97-tenant-identity-compatible-upgrade/97-03-SUMMARY.md
  modified:
    - chimeway_inbox/lib/chimeway_inbox/auth.ex
    - chimeway_inbox/lib/chimeway_inbox/live_auth.ex
    - chimeway_inbox/lib/chimeway_inbox/live/bell_dropdown_live.ex
    - chimeway_admin/lib/chimeway_admin/context.ex
    - chimeway_admin/lib/chimeway_admin/live_auth.ex
    - examples/chimeway_demo_host/lib/demo_host/inbox_auth.ex
key-decisions:
  - "[97-03]: Inbox events revalidate and retain the exact recipient/tenant pair assigned at mount."
  - "[97-03]: Admin host authorization runs before tenant validation; successful authorization without a concrete tenant still halts."
  - "[97-03]: Tenant identity remains an explicit core API option, never an Ecto or Oban prefix."
requirements-completed: [TENANT-02]
coverage:
  - id: D1
    description: "Inbox LiveView mounts and mutates only with host-resolved tenant scope."
    requirement: TENANT-02
    verification:
      - kind: integration
        ref: "mix verify.inbox"
        status: pass
    human_judgment: false
  - id: D2
    description: "Admin contexts fail closed without a concrete tenant after host authorization."
    requirement: TENANT-02
    verification:
      - kind: unit
        ref: "chimeway_admin/test/chimeway_admin/live_auth_test.exs"
        status: pass
    human_judgment: false
metrics:
  duration: 22 min
  completed: 2026-08-12
status: complete
---

# Phase 97 Plan 03: Optional Phoenix Package Tenant Scope Summary

**Inbox and Admin Phoenix package seams now require a host-selected concrete tenant and preserve it for every lifecycle access.**

## Accomplishments

- Added `ChimewayInbox.Auth.current_tenant/2`, normalized nonblank host values, and halted mount/event flows when recipient or tenant context is absent, invalid, or changes after mount.
- Passed the assigned tenant to every bell dropdown list, count, pagination, mark-one, mark-all, and refresh call; cross-tenant notification UUIDs retain the absent-row UI outcome.
- Added `ChimewayAdmin.Context.build/3` and made tenantless `read_opts/2` and `recovery_opts/3` return a stable `{:error, :invalid_tenant}` rather than unscoped options.
- Preserved host Admin authorization as the authority boundary, then halted authorized-but-tenantless sessions before assigning package lifecycle state.
- Updated the demo host and its prefix-test support so the repository Inbox verification continues to prove the full host-mounted path.

## Task Commits

1. **Task 1 RED: Inbox tenant context contract** — `9812c10` (`test`)
2. **Task 1 GREEN: Tenant-scoped Inbox lifecycle calls** — `a26bbe5` (`feat`)
3. **Task 2 RED: Admin tenant gate contract** — `ce37a79` (`test`)
4. **Task 2 GREEN: Tenant-bearing Admin context** — `b4e85d9` (`feat`)
5. **Deviation fix: Demo Inbox proof compatibility** — `2aeeb90` (`fix`)

## Verification

- PASS: focused Inbox LiveView suite — 7 tests, 0 failures.
- PASS: `mix cmd --cd chimeway_inbox mix test --warnings-as-errors` — 8 tests, 0 failures.
- PASS: focused Admin LiveAuth suite — 9 tests, 0 failures.
- PASS: `mix verify.inbox` — Inbox package and DemoHost INBX-tag proof pass.

## TDD Gate Compliance

- RED commits `9812c10` and `ce37a79` preceded their corresponding Inbox and Admin implementations.
- GREEN commits `a26bbe5` and `b4e85d9` passed the focused behavioral suites.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated host and prefixed-demo proof for the new Inbox tenant contract**
- **Found during:** Plan-level `mix verify.inbox`.
- **Issue:** The demo host did not implement the new required callback, its direct `mark_seen` proof was tenantless, and the long-lived prefixed test schema did not clone additive columns from public tables.
- **Fix:** Implemented `DemoHost.InboxAuth.current_tenant/2`, scoped the proof mutation, and added additive public-column synchronization to the test-only prefix helper.
- **Files modified:** `examples/chimeway_demo_host/lib/demo_host/inbox_auth.ex`, `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs`, `examples/chimeway_demo_host/test/support/storage_prefix_support.ex`.
- **Verification:** `mix verify.inbox` passes.
- **Committed in:** `2aeeb90`.

**Total deviations:** 1 auto-fixed (Rule 3). **Impact:** Keeps the existing host-mounted verification path compatible with the new explicit row-scope contract; no runtime storage routing or tenant ACL was introduced.

## Known Stubs

None.

## Next Phase Readiness

Plan 97-05 can propagate the validated Admin context through remaining LiveView call sites. The package boundary now guarantees that any context reaching those callers carries a concrete host-authorized tenant.

## Self-Check: PASSED

- Found all Inbox, Admin, and demo host implementation files named above.
- Found task commits `9812c10`, `a26bbe5`, `ce37a79`, `b4e85d9`, and `2aeeb90` in git history.
- No plan-owned placeholder/TODO/FIXME runtime stubs found.

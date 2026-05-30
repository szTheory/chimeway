---
phase: 62-inbox-demo-docs-gate
plan: 01
subsystem: testing
tags: [chimeway_inbox, phoenix_live_view, demo_host, inbox, exunit]

requires:
  - phase: 61-inbox-headless-package
    provides: chimeway_inbox package with Auth, Router macro, BellDropdownLive
provides:
  - Demo host /inbox mount with DemoHost.InboxAuth recipient resolution
  - Adopter-copyable DemoHost.Seeds.seed_inbox/0 standalone API
  - Selective @moduletag :inbox proof test for list/mark_read/badge and mark_seen API
affects: [62-02-inbox-guide, 62-03-verify-inbox-gate]

tech-stack:
  added: [chimeway_inbox path dep in demo host]
  patterns: [admin-mount clone for inbox, demo_user_email session key for end-user auth, selective proof module tag]

key-files:
  created:
    - examples/chimeway_demo_host/lib/demo_host/inbox_auth.ex
    - examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs
  modified:
    - examples/chimeway_demo_host/mix.exs
    - examples/chimeway_demo_host/config/config.exs
    - examples/chimeway_demo_host/lib/demo_host_web/router.ex
    - examples/chimeway_demo_host/lib/demo_host/seeds.ex

key-decisions:
  - "InboxAuth resolves demo_user_email session key to recipient_identity — never demo:operator admin actor"
  - "seed_inbox/0 standalone API outside run/0 bundle with two idempotent invite triggers"
  - "Proof isolated via @moduletag :inbox mirroring mailglass/accrue selective CI pattern"

patterns-established:
  - "Pattern: Demo host inbox mount clones chimeway_admin dep + auth_module + router scope"
  - "Pattern: mark_seen proof via Chimeway.mark_seen/3 API — badge unchanged (read_at drives count)"

requirements-completed: [DEMO-08]

duration: 18min
completed: 2026-05-30
---

# Phase 62 Plan 01: Demo Host Inbox Mount Summary

**Demo host `/inbox` bell with `demo_user_email` InboxAuth, adopter-copyable `seed_inbox/0`, and selective `:inbox` proof for mark_read badge + mark_seen API**

## Performance

- **Duration:** 18 min
- **Started:** 2026-05-30T12:45:00Z
- **Completed:** 2026-05-30T13:03:00Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments

- Mounted `chimeway_inbox` at `/inbox` with `DemoHost.InboxAuth` resolving end-user recipient from `"demo_user_email"` session key
- Added `DemoHost.Seeds.seed_inbox/0` seeding two unread in_app notifications with stable idempotency keys
- Created `InboxBellProofTest` with `@moduletag :inbox` proving LiveView mark_read badge decrement and API mark_seen persistence

## Task Commits

Each task was committed atomically:

1. **Task 1: Add chimeway_inbox dep, config, InboxAuth, and router mount** - `c719344` (feat)
2. **Task 2: Add DemoHost.Seeds.seed_inbox/0** - `f1e0d91` (feat)
3. **Task 3: Create inbox_bell_proof_test.exs with @moduletag :inbox** - `9163cc0` (test)

**Plan metadata:** pending (docs commit)

## Files Created/Modified

- `examples/chimeway_demo_host/lib/demo_host/inbox_auth.ex` - ChimewayInbox.Auth behaviour for end-user session
- `examples/chimeway_demo_host/lib/demo_host_web/router.ex` - `/inbox` scope with `chimeway_inbox_routes/0`
- `examples/chimeway_demo_host/lib/demo_host/seeds.ex` - `seed_inbox/0` standalone DEMO-08 seed API
- `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs` - selective `:inbox` proof module
- `examples/chimeway_demo_host/mix.exs` - chimeway_inbox path dependency
- `examples/chimeway_demo_host/config/config.exs` - auth_module config

## Decisions Made

- Used `"demo_user_email"` session key distinct from AdminActor `"demo:operator"` (T-62-01 mitigation)
- Reused `DemoHost.Notifiers.InviteSent` for in_app channel + metadata subject rather than new notifier
- mark_seen proof via public API only — no badge assertion per D-07 (read_at drives unread count)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for 62-02 (inbox integration guide + doc-contract) — can cite `/inbox` route, `seed_inbox/0`, and `:inbox` proof test
- Ready for 62-03 parallel gate work — `mix test --only inbox` demo lane is green

## Verification

```bash
cd examples/chimeway_demo_host && mix test --only inbox --warnings-as-errors
# 2 tests, 0 failures

cd examples/chimeway_demo_host && mix test --only journey --warnings-as-errors
# 10 tests, 0 failures (journey isolation confirmed)
```

## Self-Check: PASSED

- [x] `examples/chimeway_demo_host/lib/demo_host/inbox_auth.ex` exists
- [x] `DemoHost.Seeds.seed_inbox/0` exists with Standalone API moduledoc
- [x] `inbox_bell_proof_test.exs` has `@moduletag :inbox`
- [x] `mix test --only inbox --warnings-as-errors` green (2 tests)
- [x] `mix test --only journey --warnings-as-errors` green (10 tests)
- [x] Task commits present: c719344, f1e0d91, 9163cc0

---
*Phase: 62-inbox-demo-docs-gate*
*Completed: 2026-05-30*

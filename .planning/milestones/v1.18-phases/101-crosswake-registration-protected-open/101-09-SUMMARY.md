---
phase: 101-crosswake-registration-protected-open
plan: "09"
subsystem: protected-notification-open
tags: [swift, ios, elixir, chimeway, route-gate, privacy, tdd]
requires:
  - phase: 101-crosswake-registration-protected-open
    provides: bounded opaque protected-open queue and host allow-only activation seam
  - phase: 101-crosswake-registration-protected-open
    provides: authenticated permission-loss transcript and exact-revision registry CAS
provides:
  - Terminal native handling for every stale or denied protected-notification outcome
  - Reconnect routing that cannot use ordinary unavailable-route or URL fallback
  - Executable final acceptance evidence across resolver, host registry, RouteGate, Mix, and Swift suites
affects: [102-crosswake-digital-twin, 103-crosswake-physical-iphone-proof]
tech-stack:
  added: []
  patterns:
    - Protected notification denials are terminal and expose only one sanitized native presentation
    - Queue reconnects pass the complete closed outcome to the activation coordinator
key-files:
  created:
    - .planning/phases/101-crosswake-registration-protected-open/101-09-SUMMARY.md
  modified:
    - ../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/ActivationCoordinator.swift
    - ../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationOpenDelegate.swift
    - ../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationOpenQueue.swift
    - ../crosswake/packages/crosswake-shell-core-ios/Tests/CrosswakeShellCoreTests/ProtectedNotificationActivationTests.swift
key-decisions:
  - "[101-09]: Every stale or denied protected-open outcome resolves to a stable no-action terminal native presentation."
  - "[101-09]: NotificationOpenQueue sends closed reconnect outcomes to the coordinator, keeping the denial path distinct from ordinary fallback navigation."
requirements-completed: [OPEN-01, OPEN-02, OPEN-03, OPEN-04]
coverage:
  - id: D1
    description: "All ten stale-authority and denied protected-open classes are terminal without activation or fallback."
    requirement: OPEN-04
    verification:
      - kind: unit
        ref: "packages/crosswake-shell-core-ios/Tests/CrosswakeShellCoreTests/ProtectedNotificationActivationTests.swift#test_every_protected_denial_is_terminal_and_never_activates_or_falls_back"
        status: pass
    human_judgment: false
  - id: D2
    description: "Current policy, one-time consumption, registry CAS, and RouteGate ordering remain fail-closed."
    requirement: OPEN-01
    verification:
      - kind: integration
        ref: "mix test resolver, Phoenix registry, and compatibility suites --seed 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "The full deterministic CrossWake Mix and Swift regression suites pass."
    requirement: OPEN-03
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix verify && swift test"
        status: pass
    human_judgment: false
metrics:
  duration: 6 min
  completed: 2026-08-24
  tasks_completed: 1
  files_modified: 4
status: complete
---

# Phase 101 Plan 09: Protected-Open Acceptance Matrix Summary

**Protected notification reconnects now carry every closed denial to a terminal, sanitized native presentation with no URL or unavailable-route fallback.**

## Accomplishments

- Added an explicit native taxonomy for the ten stale-authority denial classes and a table-driven XCTest matrix that proves each remains terminal with no actions.
- Routed queue reconnect outcomes through a protected handler so denied items cannot bypass the no-fallback boundary; only an explicit host allow invokes activation.
- Re-ran resolver, authenticated registry CAS transcript, RouteGate compatibility, repository Mix, and full Swift evidence.

## Verification

- `cd packages/crosswake_chimeway && mix test test/crosswake/companions/chimeway/resolver_test.exs` — passed (13 tests).
- `cd examples/phoenix_host && mix test test/crosswake_example/chimeway/notification_registration_adapter_test.exs test/crosswake_example/chimeway/registry_notification_open_test.exs --seed 0` — passed (12 tests).
- `mix test test/crosswake/compatibility/compatibility_test.exs` — passed (15 tests).
- `MIX_ENV=test mix verify` — passed (repository and companion verification suites).
- `cd packages/crosswake-shell-core-ios && swift test` — passed (full shell suite).

## Task Commits

1. **Task 1 RED: terminal protected-denial matrix** — `b6e0a0a5` (test)
2. **Task 1 GREEN: terminal protected notification outcomes** — `49cd2909` (feat)

## Decisions Made

- Kept denial details host-owned and used one generic native terminal presentation, preventing authority classifications or fallback targets from entering the shell UI.
- Used `MIX_ENV=test mix verify` for the repository alias because the root alias invokes `mix test`, which rejects the default `:dev` environment.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Routed denied reconnect outcomes through the native terminal handler**
- **Found during:** Task 1 GREEN implementation
- **Issue:** The queue forwarded only allowed results to the coordinator, leaving the explicit terminal denial handler outside the production reconnect path.
- **Fix:** Forward the complete closed outcome and remove only allowed or denied items; retryable transport failures remain queued.
- **Files modified:** `packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationOpenQueue.swift`
- **Verification:** Full `swift test` passed.
- **Commit:** `49cd2909`

**Total deviations:** 1 auto-fixed (Rule 2). **Impact:** Necessary no-fallback wiring only; no Phase 102/103 work was added.

## Known Stubs

None.

## Next Phase Readiness

Phase 101 has automated acceptance evidence for protected open. Phase 102 may build the separately scoped digital-twin and named CI gates without changing this closed activation contract.

## Self-Check: PASSED

- Confirmed all four changed CrossWake source/test files exist.
- Confirmed TDD commits `b6e0a0a5` and `49cd2909` exist in CrossWake history.
- Confirmed focused, full Mix, and full Swift verification passed.

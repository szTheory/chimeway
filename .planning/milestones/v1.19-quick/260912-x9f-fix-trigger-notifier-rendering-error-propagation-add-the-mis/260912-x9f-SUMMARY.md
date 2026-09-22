---
phase: 260912-x9f
plan: 01
subsystem: trigger-inbox
tags: [elixir, ecto, transactions, phoenix-liveview, pubsub]
requires:
  - phase: 105-tenant-safe-inbox-change-stream
    provides: Closed post-commit inbox publisher and authorized bell reload path
provides:
  - Stable public Trigger error propagation for returned rendering failures
  - Rollback and no-publication regression coverage for failed notification builds
  - Mounted public Trigger-to-bell arrival proof bound to the inserted notification ID
affects: [trigger, inbox-change-publisher, demo-host-inbox]
actuals:
  tokens: 986
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns:
    - Halt Enum.reduce_while with the existing tagged error so Ecto.Multi owns rollback
    - Prove LiveView reloads by mounting before the public mutation and binding rendered output to the committed row
key-files:
  created:
    - .planning/quick/260912-x9f-fix-trigger-notifier-rendering-error-propagation-add-the-mis/260912-x9f-SUMMARY.md
  modified:
    - lib/chimeway/trigger.ex
    - test/chimeway/trigger_inbox_change_test.exs
    - examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs
key-decisions:
  - "[260912-x9f]: Halt the reducer with the already-tagged rendering error; do not rescue notifier exceptions or move publication into the transaction."
  - "[260912-x9f]: Bind the mounted arrival proof to the exact inserted opaque notification row while explicitly keeping raw caller content out of the inbox projection."
patterns-established:
  - "Returned notifier contract errors remain values across reducer, transaction, and public API boundaries."
  - "Mounted real-time proofs identify the committed row rather than manually publishing or inserting fixtures."
requirements-completed: [INBX-03, INBX-04]
coverage:
  - id: D1
    description: Returned rendering errors produce the stable notifications_insert_failed result, roll back all rows, and publish no inbox hint.
    requirement: INBX-03
    verification:
      - kind: integration
        ref: test/chimeway/trigger_inbox_change_test.exs#a-rendering-failure-returns-a-stable-error-and-rolls-back-without-publishing
        status: pass
    human_judgment: false
  - id: D2
    description: A bell mounted before public Chimeway.trigger/3 refreshes from zero to one unread and renders the exact committed notification row.
    requirement: INBX-04
    verification:
      - kind: automated_ui
        ref: examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs#public-trigger-refreshes-a-previously-mounted-bell
        status: pass
      - kind: integration
        ref: mix verify.inbox
        status: pass
    human_judgment: false
  - id: D3
    description: The mounted arrival path preserves the closed publisher payload and does not project raw caller-supplied team text.
    requirement: INBX-04
    verification:
      - kind: integration
        ref: examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs#public-trigger-refreshes-a-previously-mounted-bell
        status: pass
    human_judgment: false
duration: 5 min
completed: 2026-09-13
status: complete
---

# Quick 260912-x9f: Trigger Rendering Error and Mounted Bell Proof Summary

**Tagged rendering failures now roll back cleanly as stable public errors, while a mounted authorized bell proves the real post-commit Trigger refresh path without exposing caller content.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-09-13T05:16:00Z
- **Completed:** 2026-09-13T05:21:06Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added an intentional RED regression demonstrating that a notifier rendering error previously crashed `Enum.reduce_while/3` instead of returning the documented public tuple.
- Corrected the reducer with a two-line halt branch, preserving the original tagged error for Ecto rollback and one-time public normalization.
- Proved a bell mounted before `Chimeway.trigger/3` receives the configured closed reload signal, refreshes to one unread, and renders the exact inserted opaque notification row.
- Preserved the privacy boundary by verifying that the synthetic caller-supplied team name does not enter the durable inbox projection.

## Task Commits

1. **Task 1 RED: reproduce rendering error propagation failure** - `df228ce6` (test)
2. **Task 1 GREEN: propagate notifier rendering errors** - `0cb29735` (fix)
3. **Task 2: prove mounted Trigger arrival refresh** - `8e0f708f` (test)

## Files Created/Modified

- `lib/chimeway/trigger.ex` - Halts notification attribute reduction with the existing tagged error.
- `test/chimeway/trigger_inbox_change_test.exs` - Covers exact public error shape, event/notification rollback, and absent publication.
- `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs` - Covers the public Trigger-to-mounted-bell refresh path and privacy-negative projection.

## Decisions Made

- Kept `ChangePublisher.publish/3` exclusively in the successful post-transaction path; the correction changes no duplicate, lifecycle, or publisher-failure behavior.
- Used the committed notification ID as the arrival identity in the rendered bell instead of weakening `SafeEvidence.notification_metadata/1` to persist raw notifier content.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Security] Replaced raw invitation-text projection with exact opaque-row evidence**

- **Found during:** Task 2 (mounted public Trigger-to-bell refresh)
- **Issue:** The plan asked the bell to render the unique caller-supplied team text, but Trigger intentionally applies the closed `SafeEvidence.notification_metadata/1` vocabulary before persistence. Widening it would violate the locked privacy boundary and Phase 107 content-exclusion contracts.
- **Fix:** Queried the single notification committed by the returned event, asserted that exact opaque notification ID in the refreshed bell, and explicitly refuted the raw team text.
- **Files modified:** `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs`
- **Verification:** Focused demo suite and `mix verify.inbox` both pass.
- **Committed in:** `8e0f708f`

**2. [Rule 1 - Contract mismatch] Matched the established zero-unread presentation**

- **Found during:** Task 2 focused verification
- **Issue:** At zero unread the existing bell contract uses `aria-label="Notifications"` and a hidden badge containing `0`, not `Notifications, 0 unread`; changing presentation was explicitly out of scope.
- **Fix:** Asserted the established accessible label plus hidden zero badge, then verified the post-trigger `Notifications, 1 unread` transition.
- **Files modified:** `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs`
- **Verification:** Focused demo suite and `mix verify.inbox` both pass.
- **Committed in:** `8e0f708f`

---

**Total deviations:** 2 auto-fixed (1 security preservation, 1 contract mismatch)
**Impact on plan:** The real-time arrival and exact row identity are fully proven with stronger privacy evidence; no production surface or dependency boundary was broadened.

## Issues Encountered

- The demo suite logs pre-existing optional-application warnings and Threadline sandbox cleanup errors, but exits successfully with all seven focused tests green.
- `mix verify.inbox` reports dependency advisories from its isolated package environments; they do not fail this behavior gate and are outside this item's owned files.

## Verification

- RED: focused root suite — 5 tests, 1 intentional failure at `Enumerable.List.reduce/3` with `{:error, {:rendering_resolution_failed, :forced_rendering_failure}}`.
- GREEN: focused root suite — 5 tests, 0 failures.
- Focused demo-host inbox suite — 7 tests, 0 failures.
- Aggregate `mix verify.inbox` — all five lanes passed: root 76, inbox package 29, admin 9, gate parity 41, demo inbox 7.
- `mix format --check-formatted` passed for all three owned files.

## Known Stubs

None.

## Threat Surface

No new network endpoint, authentication path, file access, schema, dependency, publisher payload, or topic format was introduced.

## User Setup Required

None.

## Self-Check: PASSED

- All three owned source/test files exist.
- Commits `df228ce6`, `0cb29735`, and `8e0f708f` exist in history.
- The required summary exists with `status: complete` and remains uncommitted for the batch orchestrator.

---
*Quick: 260912-x9f*
*Completed: 2026-09-13*

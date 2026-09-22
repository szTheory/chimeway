---
phase: 105-tenant-safe-inbox-change-stream
plan: "02"
subsystem: inbox-live
tags: [inbox, phoenix-pubsub, liveview, hmac, tenant-isolation]
provides:
  - Secret-derived tenant-and-recipient PubSub topics
  - Closed reload messages with connected-mount subscription
  - Reauthorized authoritative LiveView refresh
  - Demo-host adoption using opaque recipient identities
affects: [106, 107, inbox-realtime, demo-host]
key-files:
  created:
    - chimeway_inbox/lib/chimeway_inbox/change_stream.ex
    - chimeway_inbox/lib/chimeway_inbox/pub_sub_publisher.ex
    - chimeway_inbox/test/chimeway_inbox/pub_sub_publisher_test.exs
  modified:
    - chimeway_inbox/lib/chimeway_inbox/live/bell_dropdown_live.ex
    - chimeway_inbox/test/chimeway_inbox/live/bell_dropdown_live_test.exs
    - examples/chimeway_demo_host/lib/demo_host/seeds.ex
    - examples/chimeway_demo_host/config/config.exs
    - examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs
key-decisions:
  - "Topics use HMAC-SHA256 over domain-separated, length-delimited scope and expose no scope input."
  - "The bell subscribes only in connected mount and reauthorizes every exact reload message before reading durable state."
  - "Reloads reset pagination to page one while preserving panel state and existing markup/copy."
requirements-completed: [INBX-04]
duration: 13min
completed: 2026-09-12
status: complete
---

# Phase 105 Plan 02 Summary

**Authorized connected inboxes now refresh from durable state through privacy-safe Phoenix PubSub hints.**

## Accomplishments

- Added one HMAC topic derivation boundary shared by publishing and subscription.
- Broadcast only `{:chimeway_inbox, :reload, 1}` and fail closed for unsafe scope, weak secrets, or invalid PubSub configuration.
- Subscribed after LiveView authorization, reauthorized on every reload, ignored unrelated messages, and preserved panel/UI state.
- Proved same-scope refresh, tenant/recipient isolation, auth-drift redirect, and authoritative pagination reset.
- Updated the reference host to persist stable opaque recipient keys and exercise the opt-in publisher configuration.

## Task Commits

1. RED PubSub contract — `36b31d79`
2. Opaque PubSub stream — `642c7e24`
3. RED LiveView refresh contract — `7eb48401`
4. Authorized LiveView refresh — `593299ed`
5. Demo-host adoption correction — `5e4a0252`

## Evidence

- PubSub and LiveView focused suite: 20 tests, 0 failures.
- Demo-host inbox proof: 2 tests, 0 failures.
- Aggregate `mix verify.inbox`: 21 package tests plus 2 demo-host tests, 0 failures.
- `mix compile --warnings-as-errors`: passed for the optional package.

## Deviations from Plan

- The aggregate gate exposed that the older demo seed still persisted an email-shaped recipient identity. The demo now derives a stable one-way `cw_` identity and configures the new publisher, bringing the executable reference host into the planned privacy boundary.

## Self-Check: PASSED

- All implementation and test artifacts exist and all five task/deviation commits are present.
- Changed files contain no conversational account identifiers.

---
*Phase: 105-tenant-safe-inbox-change-stream*
*Completed: 2026-09-12*

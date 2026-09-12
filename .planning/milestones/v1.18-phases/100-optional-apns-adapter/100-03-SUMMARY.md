---
phase: 100-optional-apns-adapter
plan: 03
subsystem: apns-adapter
tags: [elixir, apns, pigeon, privacy, optional-dependency]
requires:
  - phase: 100-optional-apns-adapter
    provides: persisted safe APNs request intent and copied migration parity
provides:
  - Closed APNs request-intent and payload boundary
  - Tenant-explicit transient binding lookup and optional Pigeon transport seam
  - Exact provider-response extraction with fail-closed invalidation facts
affects: [100-04, 100-05, apns-delivery]
tech-stack:
  added: []
  patterns:
    - Dynamic optional dependency resolution through Module.concat, Code.ensure_loaded?, struct, and apply
    - Closed host callback structs and redacted fake transport request capture
key-files:
  created:
    - lib/chimeway/apns/payload.ex
    - lib/chimeway/apns/binding_lookup.ex
    - lib/chimeway/apns/transport.ex
    - test/support/apns_fake_transport.ex
    - test/chimeway/apns/request_test.exs
    - test/chimeway/adapters/apns_test.exs
  modified:
    - lib/chimeway/apns/request_intent.ex
    - lib/chimeway/adapters/apns.ex
    - test/chimeway/apns/tracer_test.exs
decisions:
  - "[100-03]: APNs payloads are encoded from a fixed APS alert plus opaque open-reference allowlist; generic push data is never emitted."
  - "[100-03]: Binding lookup callbacks exchange exact opaque structs, with all malformed or mismatched transient material normalized to :binding_not_found."
  - "[100-03]: Pigeon remains a host-selected optional transport; absent Pigeon is a stable pre-handoff outcome."
metrics:
  duration: 18 min
  completed: 2026-08-20
status: complete
---

# Phase 100 Plan 03: APNs Request Boundary Summary

**APNs delivery now has a closed, Pigeon-optional request boundary that preserves tenant-scoped transient custody and explicit ambiguity semantics.**

## Accomplishments

- Added byte-bounded JSON payload encoding for only `aps.alert` and `chimeway_open_ref`; generic rendering data never crosses to APNs.
- Preserved microsecond expiry equality and added versioned length-delimited collapse identity for explicitly replaceable occurrences.
- Formalized exact host lookup/invalidation structs, normalized lookup failures, and redacted all fake-transport token capture.
- Added a dynamic Pigeon path that compiles with Pigeon absent, maps Pigeon timeout/exception paths to possible handoff, and fails closed on incomplete invalidation response facts.
- Updated the prior tracer fixture to the new public callback contracts.

## Verification

- PASS: `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns/request_test.exs --warnings-as-errors` (4 tests).
- PASS: `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/adapters/apns_test.exs test/chimeway/apns/request_test.exs --warnings-as-errors` (7 tests).
- PASS: focused suite including the existing tracer (10 tests).
- PASS: `MIX_ENV=prod mix compile --warnings-as-errors` with no root Pigeon dependency.

## Task Commits

1. Task 1 RED — `10d6e03` test request/payload boundaries.
2. Task 1 GREEN — `c5f4e1b` close request intent and payload construction.
3. Task 2 RED — `f814a7d` test lookup and transport contracts.
4. Task 2 GREEN — `ed27a46` implement exact lookup and optional transport seams.
5. Directly related compatibility fix — `ab0241a` update the pre-existing tracer fixture.
6. Directly related Pigeon contract fix — `96f7cd9` correct the dispatcher-first Pigeon 2.0.1 sync call and response classification.

## Decisions Made

- Stable `apns_id` is carried only as provider correlation; collapse identity remains absent unless the host opts into replaceability.
- Only a complete `410 + ExpiredToken|Unregistered + non-negative timestamp` response can become a closed invalidation fact; all incomplete inputs fail closed.
- The APNs adapter never records raw token, dispatcher, payload body, or caught exception details in its result.

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 1 - Bug] Updated the Phase 100 tracer fixture for the new public callback contract.
- **Found during:** Final focused regression check.
- **Issue:** The accepted tracer still implemented the predecessor `resolve/4` and `deliver/2` callbacks, causing its APNs handoff assertion to become ambiguous.
- **Fix:** Replaced it with exact `BindingLookup` and `Transport` test contracts and asserted the closed payload through the new request struct.
- **Files modified:** `test/chimeway/apns/tracer_test.exs`.
- **Commit:** `ab0241a`.

## Known Stubs

None. The stub scan found only intentional collapse-id default assertions and no placeholder or unwired runtime behavior.

## Self-Check: PASSED

- Found all five task commits in git history.
- Confirmed the request, payload, lookup, transport, adapter, fake transport, and focused test files exist.
- Confirmed no tracked file deletions in the task commits.

---
phase: 100-optional-apns-adapter
plan: 01
subsystem: delivery-targets
tags: [elixir, ecto, apns, target-adapter]
requires:
  - phase: 99-multi-installation-delivery-recovery
    provides: durable target claim and attempt lifecycle
provides:
  - Safe, nullable APNs request intent persisted on a delivery target
  - Runtime-only host lookup and transport handoff for APNs
affects:
  - phase-100-apns-adapter-expansion
tech-stack:
  added: []
  patterns:
    - Persist provider-neutral intent and resolve tokens only at the handoff boundary
    - Validate final JSON payload size before transport invocation
key-files:
  created:
    - lib/chimeway/apns/request_intent.ex
    - lib/chimeway/adapters/apns.ex
    - priv/repo/migrations/20260820000001_add_apns_request_intent.exs
    - test/chimeway/apns/tracer_test.exs
  modified:
    - lib/chimeway/target_resolver.ex
    - lib/chimeway/delivery_target.ex
    - lib/chimeway/delivery_targets.ex
decisions:
  - "[100-01]: APNs request intent is a nullable, immutable delivery-target variant; tokens and dispatcher references resolve only at the host-owned runtime boundary."
metrics:
  duration: 8 min
  completed: 2026-08-20
status: complete
---

# Phase 100 Plan 01: Safe APNs Target Handoff Summary

**A validated APNs routing intent now persists on each target while tokens and dispatcher references remain transient host-owned material.**

## Completed Work

- Added a data-first `Chimeway.APNS.RequestIntent` with durable storage conversion, expiry checks, UUID validation, and scoped optional collapse derivation.
- Kept `BindingRevision.new/2` provider-neutral while adding an explicit safe-intent construction path and intent normalization guard.
- Added nullable `apns_request_intent` target storage with an additive reversible migration; duplicate target conflicts retain the first stored intent.
- Added a Pigeon-free APNs target adapter that validates expiry and exact lookup scope before dynamically invoking host-configured lookup and transport modules.
- Added tracer coverage for safe intent persistence projection, accepted scoped handoff, and expiry’s no-I/O boundary.

## Verification

- `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix ecto.migrate` — passed.
- `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns/tracer_test.exs --warnings-as-errors` — passed (3 tests).
- `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix ecto.rollback --step 1` — passed; subsequent test-database migration setup remained healthy.
- `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/delivery_target_test.exs --warnings-as-errors` — passed (13 tests).

## Decisions Made

- APNs metadata is an optional delivery-target variant rather than an APNs-specific identity or table.
- The adapter returns only allowlisted provider acceptance facts and never emits token, dispatcher credential, or encoded payload data.

## Deviations from Plan

None - the target-planning path already passed normalized `BindingRevision` values unchanged, so no `DeliveryPlanning` code change was required to carry the new safe intent.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed the APNs intent, adapter, migration, and tracer files exist.
- Confirmed task commits `5e99e4d` and `a5039f4` exist in git history.

---
phase: 65-ecosystem-blueprints-demo
plan: "02"
subsystem: demo-host-test-infrastructure
tags:
  - demo-host
  - test-helper
  - seeds
  - threadline
  - sigra
  - DEMO-09
  - DEMO-10
dependency_graph:
  requires:
    - "63-threadline-telemetry-bridge (Chimeway.Telemetry.ThreadlineReporter)"
    - "64-sigra-auth-flows-core (Sigra.Integrations.Chimeway)"
  provides:
    - "demo host Threadline.Test.Repo + Sigra.TestRepo sandbox bootstrap"
    - "DemoHost.Seeds.seed_threadline_notification/0"
    - "DemoHost.Seeds.seed_sigra_auth/0"
  affects:
    - "65-03 proof tests (consume both seed helpers)"
tech_stack:
  added: []
  patterns:
    - "Code.ensure_loaded? conditional TestRepo bootstrap (Accrue/Mailglass precedent)"
    - "delivery_ids_for_event/1 private DB query helper"
    - "@compile {:no_warn_undefined, [...]} extended with nested Sigra modules"
key_files:
  created: []
  modified:
    - "examples/chimeway_demo_host/test/test_helper.exs"
    - "examples/chimeway_demo_host/lib/demo_host/seeds.ex"
decisions:
  - "Used Chimeway.trigger/3 directly with Sigra.Integrations.Chimeway.MagicLinkNotifier rather than dispatch_magic_link_after_request to avoid requiring user fixture setup in seed function"
  - "Pre-populate PendingDelivery ETS before trigger call so MagicLinkNotifier.rendering/2 can pop URL at render time without exposing it (T-65-03)"
  - "Query delivery IDs from Chimeway.Repo after trigger (not from trigger result which always returns delivery_ids: []) — mirrors DemoHost.AccrueSeeds pattern"
  - "seed_threadline_notification returns recipient_identity via Map.put_new after trigger; alex_identity() = user:alex@teampulse.test"
  - "seed_sigra_auth returns @alex_email directly as recipient_identity (MagicLinkNotifier sets recipient_identity = email without user: prefix)"
  - "Sigra integration set to enabled: false globally in test_helper; proof tests enable per test in setup (T-65-04)"
metrics:
  duration: "15min"
  completed: "2026-05-30"
  tasks: 2
  files: 2
---

# Phase 65 Plan 02: Demo Host Test Infrastructure — Threadline + Sigra Bootstrap Summary

Threadline and Sigra TestRepo bootstrap added to the demo host test_helper.exs, and two new seed helpers (`seed_threadline_notification/0` + `seed_sigra_auth/0`) added to `DemoHost.Seeds` for the Plan 03 proof tests.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add Threadline + Sigra TestRepo bootstrap to demo host test_helper.exs | 466a75c | examples/chimeway_demo_host/test/test_helper.exs |
| 2 | Add seed_threadline_notification/0 and seed_sigra_auth/0 to DemoHost.Seeds | 59a1d85 | examples/chimeway_demo_host/lib/demo_host/seeds.ex |

## What Was Built

**test_helper.exs bootstrap blocks:**

Two new conditional blocks appended after the Accrue block:
- `if Code.ensure_loaded?(Threadline)` — mirrors Mailglass/Accrue pattern exactly: `ensure_all_started(:threadline)`, migrations path wildcard, `storage_up`, pool swap, migration run, config restore, `Threadline.Test.Repo.start_link()`, `Sandbox.mode(:manual)`
- `if Code.ensure_loaded?(Sigra)` — mirrors root test/test_helper.exs Sigra block: Sigra.Integrations.Chimeway compile fallback, `Application.load(:sigra)`, conditional migrations (path or nil), `storage_up`, pool swap, migration run, config restore, `Sigra.TestRepo.start_link()`, `Sandbox.mode(:manual)`, sets `enabled: false` for chimeway integration globally

**DemoHost.Seeds additions:**

- `@compile {:no_warn_undefined, [...]}` extended with `Sigra.Integrations.Chimeway`, `Sigra.Integrations.Chimeway.MagicLinkNotifier`, `Sigra.Integrations.Chimeway.PendingDelivery`
- `seed_threadline_notification/0` — calls `Chimeway.trigger/3` via `DemoHost.Notifiers.InviteSent` with unique correlation_id; queries delivery_ids from Chimeway.Repo; returns `{:ok, %{recipient_identity: "user:alex@teampulse.test", trace: %{delivery_ids: [...], correlation_id: ...}}}`
- `seed_sigra_auth/0` — pre-populates `Sigra.Integrations.Chimeway.PendingDelivery` ETS, then calls `Chimeway.trigger/3` via `MagicLinkNotifier` directly; queries delivery_ids from Chimeway.Repo; returns `{:ok, %{recipient_identity: "alex@teampulse.test", trace: %{delivery_ids: [...], correlation_id: ...}}}` — no raw_token or url exposed
- `delivery_ids_for_event/1` private helper — queries Delivery rows joined via Notification to event_id

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] dispatch_magic_link_after_request signature requires user_schema, user_token_schema, url_fun opts**

- **Found during:** Task 2 implementation
- **Issue:** The plan action showed `dispatch_magic_link_after_request(@alex_email, %{...})` as a 2-arg call. The actual function signature is 3-arg `(repo, email, opts)` and requires `url_fun`, `user_schema`, `user_token_schema`, and a pre-existing user row in Sigra.TestRepo. Calling it in a seed without these would raise `KeyError: url_fun` or `Ecto.NoResultsError`.
- **Fix:** Used `Chimeway.trigger/3` with `Sigra.Integrations.Chimeway.MagicLinkNotifier` directly (same underlying call that `dispatch_magic_link` makes), pre-populating `PendingDelivery` ETS with a demo URL that gets discarded at render time. This matches the security requirement (T-65-03) while avoiding the user fixture dependency.
- **Files modified:** `examples/chimeway_demo_host/lib/demo_host/seeds.ex`
- **Commit:** 59a1d85

**2. [Rule 1 - Bug] Chimeway trigger result delivery_ids is always [] — admin trace would fail**

- **Found during:** Task 2 implementation (inspecting DemoHost.AccrueSeeds pattern)
- **Issue:** `Chimeway.trigger/3` returns `trace: %{delivery_ids: []}` in its result (hardcoded in trigger.ex normalize_trigger_result). The plan's pseudocode assumed `normalize_trigger_result` in seeds.ex would propagate delivery_ids, but the trigger result only has an empty list. Using `Map.put_new(result, :recipient_identity, ...)` from trigger result would give `delivery_ids: []`, causing `hd([])` to fail in proof tests.
- **Fix:** Added `delivery_ids_for_event/1` private helper that queries `Delivery` joined via `Notification` to get actual delivery IDs from Chimeway.Repo after trigger. This mirrors the `DemoHost.AccrueSeeds.seed_accrue_dunning/0` pattern which explicitly queries delivery IDs.
- **Files modified:** `examples/chimeway_demo_host/lib/demo_host/seeds.ex`
- **Commit:** 59a1d85

## Verification Results

```
grep -c "Code.ensure_loaded?(Threadline)\|Code.ensure_loaded?(Sigra)" test/test_helper.exs
# => 2 ✓

grep -c "seed_threadline_notification\|seed_sigra_auth" lib/demo_host/seeds.ex
# => 4 (2 def, 2 @spec) ✓

No raw_token exposed in return values ✓
@compile {:no_warn_undefined, [...]} covers Sigra.Integrations.Chimeway ✓
```

## Known Stubs

None — both seed helpers make real Chimeway.trigger/3 calls and query real Delivery rows from the database.

## Self-Check: PASSED

- Task 1 commit exists: 466a75c (verified in git log)
- Task 2 commit exists: 59a1d85 (verified in git log)
- test_helper.exs has 2 bootstrap blocks: verified
- seeds.ex has both seed helpers: verified
- No raw_token exposure in return values: verified

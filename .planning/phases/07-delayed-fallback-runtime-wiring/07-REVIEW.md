---
status: issues_found
files_reviewed:
  - lib/chimeway/notifier.ex
  - lib/chimeway/deliveries.ex
  - lib/chimeway/delivery_planning.ex
  - lib/chimeway/dispatch/sync.ex
  - lib/chimeway/dispatch/oban.ex
  - lib/chimeway/dispatch/oban_worker.ex
  - lib/chimeway/traces.ex
  - test/chimeway/integration/delivery_lifecycle_test.exs
  - test/chimeway/dispatch/sync_test.exs
  - test/chimeway/dispatch/oban_test.exs
  - test/chimeway/dispatch/oban_worker_test.exs
  - test/chimeway/policy/delayed_fallback_test.exs
  - test/support/chimeway/dispatch_helpers.ex
findings:
  critical: 1
  warning: 2
  info: 1
  total: 4
updated: 2026-04-24
---

# Phase 07 Code Review (Standard)

## Findings

### Critical

1. **Dynamic atom creation in Oban enqueue step can exhaust the BEAM atom table (DoS risk).**
   - **Where:** `lib/chimeway/dispatch/oban.ex`
   - **Evidence:** `job_name = String.to_atom("enqueue_delivery_#{delivery.id}")`
   - **Impact:** `delivery.id` is unbounded UUID data. Creating atoms dynamically for every delivery causes permanent atom growth; atoms are not garbage-collected and can crash the VM under sustained load.
   - **Actionable fix:** Use a non-atom `Ecto.Multi` operation key (e.g. `{:enqueue_delivery, delivery.id}` or `"enqueue_delivery:#{delivery.id}"`) instead of `String.to_atom/1`.

### Warning

2. **`multi:` path is not transactional with delivery planning; failures can leave orphaned pending deliveries.**
   - **Where:** `lib/chimeway/dispatch/oban.ex`
   - **Evidence:** `DeliveryPlanning.plan_notifications/2` runs before `Repo.transaction/1`; only job insert operations are included in `multi_with_jobs`.
   - **Impact:** If `Repo.transaction/1` fails, delivery rows created during planning persist as `:pending` without an enqueued worker job. This creates stuck deliveries and breaks the module's documented transactional expectation.
   - **Actionable fix:** Move delivery planning inserts into the same `Ecto.Multi` transaction as enqueue operations, or add a robust recovery path for orphaned pending deliveries and update docs to match actual guarantees.

3. **`Traces.explain_delivery/1` can raise for valid custom channels due to `String.to_existing_atom/1`.**
   - **Where:** `lib/chimeway/traces.ex`, `lib/chimeway/delivery_planning.ex`
   - **Evidence:** `explain_delivery/1` converts `delivery.channel` using `String.to_existing_atom/1`, while planner accepts arbitrary non-empty string channels.
   - **Impact:** Custom channels not preloaded as atoms (for example `"sms"` or `"push"`) can trigger `ArgumentError`, causing operator trace queries to fail.
   - **Actionable fix:** Keep channel as string in explanation payloads, or map through an explicit whitelist with fallback instead of direct atom conversion.

### Info

4. **Coverage gap for trace behavior with custom string channels.**
   - **Where:** Scoped tests in `test/chimeway/...`
   - **Impact:** Current tests focus on `in_app`/`email` paths and do not exercise the custom-channel trace path, so regressions there are likely to go undetected.
   - **Actionable fix:** Add an integration test that creates a delivery using a custom string channel and asserts `Chimeway.Traces.explain_delivery/1` returns successfully.

## Assessment

Delayed fallback runtime wiring and sync/Oban policy parity are generally well-implemented and well-tested. However, the atom-exhaustion risk and transactional inconsistency should be addressed before considering this phase fully production-safe.

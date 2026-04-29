# Deferred Items

## 2026-04-29

- PostgreSQL 15.17 full-suite verification (`MIX_ENV=test DATABASE_URL=postgres://$USER@localhost:55432/chimeway_test mix ci.test`) exposed an unrelated failure in `test/chimeway/integration/delivery_lifecycle_test.exs:815`.
  The failing path is `Chimeway.Integration.DeliveryLifecycleTest resume_deferred_delivery promotes the existing row to orchestration_state == :ready`, which currently raises a `CaseClauseError` in `lib/chimeway/dispatch/oban_worker.ex:141` after `Policy.evaluate/2` returns `{:defer, ...}`.
  This blocker is outside the digest files changed by Plan 23-03 and was not auto-fixed in this plan.

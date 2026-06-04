---
phase: 70-recovery-auth-and-tenancy-hardening
reviewed: 2026-06-04T16:37:21Z
depth: standard
files_reviewed: 21
files_reviewed_list:
  - chimeway_admin/assets/css/chimeway_admin.css
  - chimeway_admin/lib/chimeway_admin/auth.ex
  - chimeway_admin/lib/chimeway_admin/context.ex
  - chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex
  - chimeway_admin/lib/chimeway_admin/live/definitions_live.ex
  - chimeway_admin/lib/chimeway_admin/live/feed_live.ex
  - chimeway_admin/lib/chimeway_admin/live/health_live.ex
  - chimeway_admin/lib/chimeway_admin/live/recovery_live.ex
  - chimeway_admin/lib/chimeway_admin/live_auth.ex
  - chimeway_admin/priv/static/chimeway_admin.css
  - chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs
  - chimeway_admin/test/chimeway_admin/live_auth_test.exs
  - examples/chimeway_demo_host/lib/demo_host_web/plugs/admin_actor.ex
  - lib/chimeway.ex
  - lib/chimeway/admin.ex
  - lib/chimeway/deliveries.ex
  - lib/chimeway/traces.ex
  - test/chimeway/admin_test.exs
  - test/chimeway/deliveries_test.exs
  - test/chimeway/orchestration/recovery_test.exs
  - test/chimeway/traces_test.exs
findings:
  critical: 2
  blocker: 2
  warning: 1
  info: 0
  total: 3
status: issues_found
---

# Phase 70: Code Review Report

**Reviewed:** 2026-06-04T16:37:21Z
**Depth:** standard
**Files Reviewed:** 21
**Status:** issues_found

## Summary

Reviewed the Phase 70 auth, tenant context, admin read models, recovery LiveView, recovery APIs, trace metadata rendering, CSS, and scoped tests. The implementation has two blocker-tier issues around sensitive auth logging and tenant-scoped recovery enforcement, plus one UI correctness warning.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Unexpected Auth Return Is Logged With Potential Secrets

**File:** `chimeway_admin/lib/chimeway_admin/live_auth.ex:79`
**Issue:** `LiveAuth.authorize/3` logs `inspect(other)` when the configured host auth module returns anything other than `:ok` or `{:error, :unauthorized}`. Phase 70 also passes raw `params` and `session` through the auth context, and the tests intentionally include raw session fields. If an auth implementation accidentally returns a denial tuple containing context, session, tokens, or payload-derived data, this code writes those values to application logs. That violates the project requirement to avoid leaking sensitive fields in operator-adjacent surfaces and turns auth misbehavior into persistent secret disclosure.
**Fix:**
```elixir
other ->
  require Logger

  Logger.warning(
    "ChimewayAdmin.Auth.authorize/3 returned an unexpected value; treating as unauthorized",
    action: action,
    auth_module: inspect(auth_module)
  )

  {:error, :unauthorized}
```

Add a regression test with an auth module returning `{:error, %{session: %{"token" => "secret"}}}` and assert the captured log does not contain the secret.

### CR-02: Recovery APIs Ignore Tenant Scope During Side Effects

**File:** `lib/chimeway/deliveries.ex:85`
**Issue:** `begin_recovery/2`, `recover_delivery/2`, and `recover_event/2` accept only an id and recovery metadata; they do not enforce a `:tenant_id` option. The admin UI lists candidates with `Context.read_opts/2`, but the final side effect calls `Chimeway.recover_delivery(id, recovery_opts)` or `Chimeway.recover_event(id, recovery_opts)` without any tenant guard. Any caller that has an id, including a future admin path or host wrapper that forwards `tenant_id` expecting it to scope recovery, can recover a delivery/event from another tenant because the core update/select queries match only by id and eligibility. This breaks the host ownership boundary for a Phase explicitly hardening recovery auth and tenancy.
**Fix:**
```elixir
tenant_id = Keyword.get(opts, :tenant_id)

recovery_query =
  from(d in Delivery,
    where:
      d.id == ^delivery_id and
        (is_nil(^tenant_id) or d.tenant_id == ^tenant_id) and
        d.status == :pending and d.orchestration_state == :ready and
        d.updated_at <= ^cutoff and fragment("?->>? IS NULL", d.metadata, ^"recovered_at"),
    update: [...]
  )
```

Thread `tenant_id` from `ChimewayAdmin.Context.recovery_opts/3`, apply equivalent tenant checks in `recover_event/2` through durable tenant proof, and add cross-tenant tests proving a tenant-scoped recovery returns `{:noop, _}` and does not stamp another tenant's row.

## Warnings

### WR-01: Empty Definition Channels Render As Blank Text

**File:** `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex:88`
**Issue:** `Enum.join(definition.channels, ", ") || "no deliveries"` never uses the fallback for an empty channel list because `Enum.join([])` returns `""`, and empty strings are truthy in Elixir. Definitions without deliveries render as `vN · ` instead of the intended `vN · no deliveries`.
**Fix:** Reuse the definitions view helper behavior or inline an explicit empty check:
```elixir
defp channel_summary([]), do: "no deliveries"
defp channel_summary(channels), do: Enum.join(channels, ", ")
```

Then render `{channel_summary(definition.channels)}` and add a LiveView/component assertion for a definition with no channels.

---

_Reviewed: 2026-06-04T16:37:21Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_

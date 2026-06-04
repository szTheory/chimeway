# Admin Console Integration

This guide is the canonical adoption path for mounting the optional `chimeway_admin` operator console in a Phoenix host. Follow it when you want a shippable operator surface for answering why notifications were sent, failed, suppressed, deferred, or recovered.

The demo-host README remains supporting proof copy. This guide is the adopter setup source of truth for routing, assets, auth, tenant context, redaction, recovery permissions, and verification.

## Responsibility split

**Chimeway provides explainability data and redacted admin DTOs:** durable events, notifications, deliveries, attempts, suppression reasons, recovery candidates, lifecycle health, and DB-inferred notification key/version history.

**`chimeway_admin` provides the mounted operator console:** Command Center, Trace Lookup, Trace Detail, Feed Debug, Definitions, Health, and Recovery pages under the host route prefix.

**The host owns production policy:** authentication, authorization, tenant membership, role checks, URL generation, session shape, and deployment-specific correlation IDs remain host responsibilities.

## 1. Dependencies

Add Chimeway and `chimeway_admin` to your host `mix.exs`:

```elixir
def deps do
  [
    {:chimeway, "~> 1.0"},
    {:chimeway_admin, "~> 1.0"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

For Chimeway repository, supervisor, and migration setup, see [Installation](installation.md).

## 2. Runtime config

Configure the admin auth module in your host config:

```elixir
config :chimeway_admin, auth_module: MyApp.AdminAuth
```

Replace `MyApp.AdminAuth` with a host module that implements `ChimewayAdmin.Auth`. Production must not use permissive demo auth; it must fail closed until the host supplies a real auth module.

## 3. Router mount

Mount the admin routes in an authenticated browser scope:

```elixir
# lib/my_app_web/router.ex
scope "/admin/chimeway" do
  pipe_through [:browser]

  import ChimewayAdmin.Router
  chimeway_admin_routes()
end
```

The `scope "/admin/chimeway"` prefix produces these routes:

| Page | Route |
|------|-------|
| Command Center | `/admin/chimeway` |
| Trace Lookup | `/admin/chimeway/traces` |
| Trace Detail | `/admin/chimeway/deliveries/:delivery_id` |
| Feed Debug | `/admin/chimeway/feed` |
| Definitions | `/admin/chimeway/definitions` |
| Health | `/admin/chimeway/health` |
| Recovery | `/admin/chimeway/recovery` |

If your host mounts the console under another prefix, set and pass a matching `path_prefix` through the admin context so generated links and operator copy stay aligned with the mount.

Runnable reference: `examples/chimeway_demo_host/lib/demo_host_web/router.ex` mounts the console under `/admin/chimeway` with `chimeway_admin_routes()`.

## 4. Packaged static assets

Serve the packaged stylesheet from your Phoenix endpoint:

```elixir
# lib/my_app_web/endpoint.ex
plug Plug.Static,
  at: "/chimeway_admin",
  from: {:chimeway_admin, "priv/static"},
  gzip: false,
  only: ~w(chimeway_admin.css)
```

Then include the stylesheet in the root layout used by the admin routes:

```heex
<link rel="stylesheet" href={ChimewayAdmin.Assets.css_path()} />
```

`ChimewayAdmin.Assets.css_path()` resolves to `/chimeway_admin/chimeway_admin.css`. If the page renders unstyled, check the `Plug.Static` mount, the layout used by the browser pipeline, and the deployed asset path.

## 5. Auth behaviour

Implement `ChimewayAdmin.Auth` in the host:

```elixir
defmodule MyApp.AdminAuth do
  @behaviour ChimewayAdmin.Auth

  @impl true
  def authorize(actor, action, context) do
    if MyApp.AdminPolicy.allowed?(actor, action, context) do
      :ok
    else
      {:error, :unauthorized}
    end
  end
end
```

`authorize/3` receives the current actor, an action atom, and normalized context. It must return `:ok` or `{:error, :unauthorized}`. Unexpected return values fail closed through `ChimewayAdmin.LiveAuth`.

The current actor comes from `current_actor` on the socket assigns or session. Keep this actor host-native: a struct, map, id, or role tuple is fine as long as your `authorize/3` implementation can evaluate it.

Production setup must fail closed. The permissive demo auth in `DemoHost.AdminAuth` is for dev/test only and denies all requests in production until replaced with a host `ChimewayAdmin.Auth` implementation.

## 6. Tenant and context expectations

Chimeway normalizes host-supplied context but does not validate tenant membership or roles. The configured `ChimewayAdmin.Auth.authorize/3` module remains responsible for checking tenant membership, role policy, and per-resource access.

The admin context recognizes:

| Key | Purpose |
|-----|---------|
| `current_actor` | Host operator identity used for authorization and recovery audit metadata. |
| `chimeway_admin_tenant_id` | Optional tenant scope for reads and recovery candidate filtering. |
| `path_prefix` | Optional route prefix when the host mounts the console somewhere other than `/admin/chimeway`. |

The context passed to `authorize/3` can include route params such as `delivery_id` and action-specific facts for recovery. Use those values to enforce per-tenant and per-resource decisions in the host policy layer.

## 7. Recovery permissions

Recovery is action-bearing and must be explicitly authorized. Treat these actions as separate host-owned permissions:

| Action | Meaning |
|--------|---------|
| `:list_recovery_candidates` | Operator can inspect eligible failed or stalled work. |
| `:recover_delivery` | Operator can retry or recover one eligible delivery. |
| `:recover_event` | Operator can retry or recover one eligible event. |

Do not grant blanket recovery powers just because an actor can view traces. Recovery candidates are derived from durable lifecycle state, and the host should log the actor, reason, tenant, and confirmation marker appropriate for its own audit trail.

## 8. Redaction guarantees

Operator surfaces are intentionally redacted. Admin DTOs and rendered HTML must not expose raw payloads, render data, provider bodies, tokens, secrets, auth codes, or full recipient PII.

Trace pages may show safe identifiers such as notification keys, versions, delivery ids, status labels, reason codes, tenant ids, masked recipients, and correlation ids. They must not show provider raw bodies or unredacted request/response payloads.

Keep Feed Debug honest: it is operator lifecycle inspection by recipient, not the end-user inbox product surface. End-user inbox UI belongs to `chimeway_inbox`.

Keep Definitions honest: it is DB-inferred durable notification key/version history from persisted Chimeway events and deliveries, not source-code discovery.

## 9. Production fail-closed checklist

Before shipping the admin console:

1. Configure `config :chimeway_admin, auth_module: MyApp.AdminAuth`.
2. Ensure unauthenticated or unauthorized operators receive `{:error, :unauthorized}` from `authorize/3`.
3. Set `current_actor` in the browser session or LiveView assigns before the admin LiveViews mount.
4. Pass `chimeway_admin_tenant_id` when your deployment needs tenant-scoped reads.
5. Serve `/chimeway_admin/chimeway_admin.css` through `Plug.Static`.
6. Confirm `ChimewayAdmin.Assets.css_path()` is linked by the admin root layout.
7. Authorize `:list_recovery_candidates`, `:recover_delivery`, and `:recover_event` separately.
8. Verify redaction by searching rendered admin pages for raw payloads, render data, provider bodies, tokens, secrets, auth codes, and full recipient PII.

The console does not ship broad management screens, message-template mutation, provider setup screens, unbounded recovery operations, or audience analytics.

## 10. Verification

After wiring dependencies, config, router mount, assets, auth, tenant context, and recovery permissions, run:

```bash
mix verify.admin
```

The admin gate runs root admin/read-model tests, the `chimeway_admin` package tests, demo-host mounted admin coverage, and the Playwright Chromium smoke against `/admin/chimeway`.

For release-doc contract parity, keep running:

```bash
mix ci.verify_gates
```

That gate exercises the root doc contracts and release-gate contracts that keep this guide, HexDocs extras, CI, and the pre-ship checklist in sync.

## Related guides

- [Installation](installation.md) - Chimeway repository, supervisor, and migration setup
- [Getting Started](getting-started.md) - notification lifecycle overview
- [Golden Path](golden-path.md) - first Chimeway notification path
- [Inbox Integration](inbox-integration.md) - end-user bell UI, separate from operator admin
- [Tracing a Notification](../recipes/tracing-a-notification.md) - operator support workflow

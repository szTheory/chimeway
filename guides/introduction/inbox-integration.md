# Inbox Integration

This guide is the canonical adoption path for composing Chimeway with the optional `chimeway_inbox` package. Follow it when you want one credible vertical slice: add Chimeway and the inbox package, configure tenant and recipient authorization, mount the bell dropdown LiveView, and verify durable arrival → visible seen → explicit read → operator timeline.

There is no separate inbox blueprint recipe in v1.9 — this guide owns the end-to-end path from dependency to verification.

## Responsibility split

**Chimeway owns durable state and contained publication:** the durable notification lifecycle, suppression and preference gates, idempotency, scheduling, operator traces, and best-effort inbox-change publication only after the owning transaction commits. A publication failure never rolls back durable state.

**`chimeway_inbox` owns the reload protocol:** HMAC-derived opaque topics, closed reload messages, subscription after authorization, and authoritative reload from Chimeway's durable rows. PubSub messages contain no recipient, tenant, caller, or notification content and are not lifecycle facts.

**The host owns authority and custody:** authentication, tenant membership, stable opaque recipient mapping, PubSub supervision, high-entropy secret custody, production authorization, and CSS for `data-cw-inbox-*` hooks. The host must resolve the currently authorized tenant and currently authorized recipient independently on mount and again before reload; never accept either identity from URL params, PubSub payloads, or browser state.

**Product boundary:** `chimeway_inbox` is a mountable LiveView package — not a `Chimeway.Adapter` seam. Operator admin (`chimeway_admin`) and end-user bell UI (`chimeway_inbox`) are separate surfaces with distinct auth behaviours.

## 1. Dependencies

`chimeway_inbox` is an in-repo preview/path package: it lives in the Chimeway monorepo and is **not published on Hex yet**. Add Chimeway and `chimeway_inbox` to your host `mix.exs`, keeping `chimeway_inbox` as a path dependency for repository/demo usage:

```elixir
def deps do
  [
    {:chimeway, "~> 1.0"},
    {:chimeway_inbox, path: "../chimeway_inbox"}
  ]
end
```

Keep the `{:chimeway_inbox, path: "../chimeway_inbox"}` path dependency for repository/demo usage until an explicit package-promotion milestone defines package metadata, SemVer policy, publish automation, and a clean install smoke. Both packages live in the Chimeway monorepo today — no sibling checkout is required (unlike Accrue integration).

Then fetch dependencies:

```bash
mix deps.get
```

## 2. Database / migrations

Chimeway stores the durable lifecycle spine (`event` → `notification` → `delivery` → `attempt`) in your database. Generate and run Chimeway migrations:

```bash
mix chimeway.gen.migrations
mix ecto.migrate
```

For Chimeway install depth — repo config, supervisor setup, and migration idempotency — see [Installation](installation.md).

The `chimeway_inbox` package has no separate schema — it reads notification rows through Chimeway's headless API. No Accrue-style sibling migrations are required.

## 3. Runtime config

Configure the core publisher and the inbox package using the same tracked shape as the demo host:

```elixir
config :chimeway,
  inbox_change_publisher: ChimewayInbox.PubSubPublisher

config :chimeway_inbox,
  auth_module: MyApp.InboxAuth,
  pubsub_server: MyApp.PubSub,
  topic_secret: System.fetch_env!("CHIMEWAY_INBOX_TOPIC_SECRET")
```

Supervise `MyApp.PubSub` in the host application and replace `MyApp.InboxAuth` with a module that implements `ChimewayInbox.Auth`. `CHIMEWAY_INBOX_TOPIC_SECRET` must be a host-custodied high-entropy secret, distinct from public identifiers and rotated deliberately; do not derive it from tenant or recipient data. The package invokes `auth_module` on mount and before every authoritative reload.

For the full Chimeway runtime setup (installer repo, `Chimeway.Repo`, supervisor), see [Installation §3–§4](installation.md#3-configuration).

## 4. Auth behaviour

Implement both callbacks. Map host session authority to a stable opaque recipient reference such as `cw_recipient_01HZX7F9N8Q4T2M6V3K1` and independently resolve the tenant whose membership the host has just authorized:

```elixir
defmodule MyApp.InboxAuth do
  @behaviour ChimewayInbox.Auth

  @impl true
  def current_recipient(session, _context) do
    with user_id when is_binary(user_id) and user_id != "" <- session["current_user_id"],
         {:ok, recipient_ref} <- MyApp.Accounts.opaque_inbox_recipient(user_id) do
      {:ok, recipient_ref}
    else
      _ -> {:error, :unauthorized}
    end
  end

  @impl true
  def current_tenant(session, _context) do
    with user_id when is_binary(user_id) and user_id != "" <- session["current_user_id"],
         tenant_id when is_binary(tenant_id) and tenant_id != "" <- session["active_tenant_id"],
         true <- MyApp.Accounts.member?(user_id, tenant_id) do
      {:ok, tenant_id}
    else
      _ -> {:error, :unauthorized}
    end
  end
end
```

Both callbacks receive the Phoenix session map and a context keyword list. Return `{:ok, value}` only from current host authorization; otherwise return `{:error, :unauthorized}`. `current_tenant/2` owns tenant membership enforcement, while `current_recipient/2` owns the stable opaque recipient mapping within that authorized tenant. The same human may have different recipient references in different tenants.

**Do not** reuse operator admin identity (`"demo:operator"`) for end-user inbox — that is `ChimewayAdmin.Auth` territory. End-user bell UI resolves stable opaque references such as `"cw_recipient_01HZX7F9N8Q4T2M6V3K1"`; raw email addresses and other mutable profile fields are not recipient identities.

Runnable reference: `DemoHost.InboxAuth` implements both callbacks, maps its demo session through `DemoHost.Seeds.recipient_identity/1`, and fails closed in production. Production hosts must replace that demo-only module with real authentication, tenant membership, and recipient authorization.

## 5. Router mount

Mount inbox routes in a browser scope, matching the package router moduledoc:

```elixir
# lib/my_app_web/router.ex
scope "/inbox" do
  pipe_through [:browser]

  import ChimewayInbox.Router
  chimeway_inbox_routes()
end
```

The macro registers a LiveView session with `ChimewayInbox.LiveAuth` on_mount and serves `ChimewayInbox.Live.BellDropdownLive` at `/inbox` (scope path + `/`).

Runnable reference: `examples/chimeway_demo_host/lib/demo_host_web/router.ex` mounts under `/inbox` with `chimeway_inbox_routes/0`.

## 6. Bell UI surface

The package ships `BellDropdownLive` — an unstyled bell dropdown with semantic `data-cw-inbox-*` hooks for host CSS:

| Hook | Purpose |
|------|---------|
| `data-cw-inbox-bell` | Bell trigger button |
| `data-cw-inbox-badge` | Unread count badge (hidden when zero) |
| `data-cw-inbox-items` | Notification list container (`ul#chimeway-inbox-items`) |

Contractual LiveView events:

| Event | Effect |
|-------|--------|
| `toggle_panel` | Open/close dropdown; update `aria-expanded`; on reveal, mark only currently visible authorized rows first-seen |
| `mark_read` | `Chimeway.mark_read/3` on item; refresh count and row |
| `mark_all_read` | Batch mark visible unread items |
| `load_more` | Next page via paginated `Chimeway.list_for_recipient/2`; newly visible authorized rows become seen |

### Lifecycle semantics

These facts are independent. One does not imply another unless the host separately records the other authoritative fact:

| Fact | Authoritative meaning | Does not imply |
|------|-----------------------|----------------|
| Durable arrival | Chimeway committed the notification row for the authorized tenant and opaque recipient. | Provider handoff, visible presentation, seen, read, protected activation, or engagement. |
| Inbox seen | The mounted bell first revealed that currently authorized row on a visible page and durably set `seen_at`. | Read, provider handoff, visible device presentation, protected activation, or engagement. |
| Inbox read | An explicit authorized inbox action durably set `read_at`. It is independent of `seen_at`. | Provider handoff, device presentation, protected activation, or engagement. |
| Inbox archive | An explicit authorized archive action durably set `archived_at`, independently of seen and read. | Read, deletion, provider handoff, protected activation, or engagement. |
| Provider handoff | A provider accepted a delivery request. | Device receipt, visible presentation, inbox state, protected activation, or engagement. |
| Visible presentation | A separate observation recorded that an alert was visibly presented. | Inbox seen/read, protected activation, or engagement. |
| Protected activation | CrossWake authorized and consumed a route-scoped open intent. | Inbox seen/read, provider handoff, or engagement. |
| Engagement | A separate host-defined product fact. Chimeway does not infer it. | Any inbox, delivery, presentation, or activation fact. |

PubSub messages and reconnect events are lossy reload hints only. On receipt or reconnect, `chimeway_inbox` re-runs both host authorization callbacks and performs an authoritative reload from durable rows scoped to the currently authorized tenant and currently authorized recipient. A message, reconnect, or reload does not itself mark anything seen/read, prove presentation, activate a protected route, or establish engagement. See [Mobile Adoption and Operations](mobile-adoption-operations.md#outcome-vocabulary) for the canonical provider-handoff, visible-presentation, and protected-activation boundaries.

Wrap the root element with `.chimeway-inbox` and style via host CSS using the hooks above. The package does not ship Tailwind or shadcn — hosts own visual design.

## 7. Headless API

When building custom inbox UI or calling lifecycle methods outside the bell dropdown, use public Chimeway delegates only — do not call internal inbox implementation modules directly:

```elixir
# Unread badge count
Chimeway.unread_count("cw_recipient_01HZX7F9N8Q4T2M6V3K1", tenant_id: tenant_id)

# Paginated list (cursor/limit opts per API docs)
Chimeway.list_for_recipient("cw_recipient_01HZX7F9N8Q4T2M6V3K1",
  tenant_id: tenant_id,
  limit: 20
)

# Mark read (emits chimeway.notification.read signal on first transition)
Chimeway.mark_read(notification_id, "cw_recipient_01HZX7F9N8Q4T2M6V3K1",
  tenant_id: tenant_id
)

# Mark seen from a custom UI only after the row is visibly presented
Chimeway.mark_seen(notification_id, "cw_recipient_01HZX7F9N8Q4T2M6V3K1",
  tenant_id: tenant_id
)
```

These delegates wrap the durable inbox lifecycle spine. Resolve `tenant_id` and the opaque recipient reference from current host authorization for every request; never take them from untrusted request parameters. First read/seen transitions emit signals that workflow steps can listen for via `cancel_signals`.

## 8. Verification

After wiring dependencies, config, auth, and router mount, run the named proof command:

```bash
mix verify.inbox --warnings-as-errors
```

This exercises focused core lifecycle/timeline/privacy/Phoenix-optional evidence, the full `chimeway_inbox` package, focused admin timeline/redaction evidence, the tagged guide/release contracts, and the DEMO-08 demo-host `:inbox` journey. No sibling repo checkout is required.

Seed the demo host inbox scenario:

```elixir
DemoHost.Seeds.seed_inbox/0
```

Then visit `/inbox` in the demo host (session must include `"demo_user_email"`) to inspect the bell badge, open the dropdown, and mark notifications read.

The selective proof module `DemoHostWeb.InboxBellProofTest` is tagged `@moduletag :inbox` — it proves durable arrival → mounted visible seen → once-only workflow progression → explicit read → authorized Trace Detail labels. Journey suite tests keep default Logger adapter isolation (D-06).

Search `/admin/chimeway` by recipient identity to inspect delivery attempts for seeded notifications alongside operator traces.

## Related guides

- [Golden Path](golden-path.md) — Chimeway-only first integration
- [Getting Started](getting-started.md) — inbox lifecycle overview
- [Mention escalation](../recipes/mention-escalation.md) — workflow recipe with `mark_read` / `cancel_signals`
- [Mailglass Integration Guide](mailglass-integration.md) — optional email delivery for the same notifiers
- [Accrue Dunning Integration Guide](accrue-dunning-integration.md) — billing workflow vertical slice
- [Installation](installation.md) — Chimeway install and migration depth

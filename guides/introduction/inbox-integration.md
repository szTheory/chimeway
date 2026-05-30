# Inbox Integration

This guide is the canonical adoption path for composing Chimeway with the optional [`chimeway_inbox`](../../chimeway_inbox) package. Follow it when you want one credible vertical slice: add Chimeway and the inbox package, configure recipient auth, mount the bell dropdown LiveView, and verify list → mark_read → badge updates.

There is no separate inbox blueprint recipe in v1.9 — this guide owns the end-to-end path from dependency to verification.

## Responsibility split (SEED-003)

**Chimeway orchestrates the when and why:** durable notification lifecycle, suppression and preference gates, idempotency, scheduling, and operator traces you can search at `/admin/chimeway` via `chimeway_admin`.

**The host owns end-user identity and styling:** session → recipient identity resolution through `ChimewayInbox.Auth`, CSS for `data-cw-inbox-*` hooks, and optional headless inbox calls via public `Chimeway.*` delegates.

**Product boundary:** `chimeway_inbox` is a mountable LiveView package — not a `Chimeway.Adapter` seam. Operator admin (`chimeway_admin`) and end-user bell UI (`chimeway_inbox`) are separate surfaces with distinct auth behaviours.

## 1. Dependencies

Add Chimeway and `chimeway_inbox` to your host `mix.exs`:

```elixir
def deps do
  [
    {:chimeway, "~> 1.0"},
    {:chimeway_inbox, path: "../chimeway_inbox"}
  ]
end
```

When `chimeway_inbox` is published to hex, replace the path dependency with `{:chimeway_inbox, "~> 1.0"}`. Both packages live in the Chimeway monorepo today — no sibling checkout is required (unlike Accrue integration).

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

Register your host auth module for recipient resolution:

```elixir
config :chimeway_inbox, auth_module: MyApp.InboxAuth
```

Replace `MyApp.InboxAuth` with a module that implements `ChimewayInbox.Auth`. The package invokes `auth_module` on every LiveView mount to resolve the current recipient identity.

For the full Chimeway runtime setup (installer repo, `Chimeway.Repo`, supervisor), see [Installation §3–§4](installation.md#3-configuration).

## 4. Auth behaviour

Implement `ChimewayInbox.Auth` to map host session (or connection assigns) to a Chimeway recipient identity string:

```elixir
defmodule MyApp.InboxAuth do
  @behaviour ChimewayInbox.Auth

  @impl true
  def current_recipient(session, _context) do
    with email when is_binary(email) and email != "" <- session["current_user_email"] do
      {:ok, "user:#{email}"}
    else
      _ -> {:error, :unauthorized}
    end
  end
end
```

The `@callback current_recipient/2` receives the Phoenix session map and a context keyword list. Return `{:ok, recipient_identity}` on success or `{:error, :unauthorized}` when the user is not signed in.

**Do not** reuse operator admin identity (`"demo:operator"`) for end-user inbox — that is `ChimewayAdmin.Auth` territory. End-user bell UI resolves per-user identities such as `"user:alex@teampulse.test"`.

Runnable reference: `DemoHost.InboxAuth` in the demo host reads `"demo_user_email"` from the session and maps via `DemoHost.Seeds.recipient_identity/1`.

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
| `toggle_panel` | Open/close dropdown; update `aria-expanded` |
| `mark_read` | `Chimeway.mark_read/3` on item; refresh count and row |
| `mark_all_read` | Batch mark visible unread items |
| `load_more` | Next page via paginated `Chimeway.list_for_recipient/2` |

**Deferred in v1.9:** `mark_seen` is not wired in `BellDropdownLive` — hosts call `Chimeway.mark_seen/3` via the headless API when seen-state matters for workflow signals (see [Mention escalation](../recipes/mention-escalation.md) for `cancel_signals` on `chimeway.notification.read`).

Wrap the root element with `.chimeway-inbox` and style via host CSS using the hooks above. The package does not ship Tailwind or shadcn — hosts own visual design.

## 7. Headless API

When building custom inbox UI or calling lifecycle methods outside the bell dropdown, use public Chimeway delegates only — do not call internal inbox implementation modules directly:

```elixir
# Unread badge count
Chimeway.unread_count("user:alex@teampulse.test")

# Paginated list (cursor/limit opts per API docs)
Chimeway.list_for_recipient("user:alex@teampulse.test", limit: 20)

# Mark read (emits chimeway.notification.read signal on first transition)
Chimeway.mark_read(notification_id, "user:alex@teampulse.test")

# Mark seen (headless — not exposed in bell UI v1.9)
Chimeway.mark_seen(notification_id, "user:alex@teampulse.test")
```

These delegates wrap the durable inbox lifecycle spine — read/seen transitions emit signals that workflow steps can listen for via `cancel_signals`.

## 8. Verification

After wiring dependencies, config, auth, and router mount, run the named proof command:

```bash
mix verify.inbox --warnings-as-errors
```

This exercises the `chimeway_inbox` package test suite and the DEMO-08 demo host proof lane (`--only inbox`). No sibling repo checkout is required.

Seed the demo host inbox scenario:

```elixir
DemoHost.Seeds.seed_inbox/0
```

Then visit `/inbox` in the demo host (session must include `"demo_user_email"`) to inspect the bell badge, open the dropdown, and mark notifications read.

The selective proof module `DemoHostWeb.InboxBellProofTest` is tagged `@moduletag :inbox` — it asserts list → `phx-click="mark_read"` → badge count update and `Chimeway.mark_seen/3` via the headless API. Journey suite tests keep default Logger adapter isolation (D-06).

Search `/admin/chimeway` by recipient identity to inspect delivery attempts for seeded notifications alongside operator traces.

## Related guides

- [Golden Path](golden-path.md) — Chimeway-only first integration
- [Getting Started](getting-started.md) — inbox lifecycle overview
- [Mention escalation](../recipes/mention-escalation.md) — workflow recipe with `mark_read` / `cancel_signals`
- [Mailglass Integration Guide](mailglass-integration.md) — optional email delivery for the same notifiers
- [Accrue Dunning Integration Guide](accrue-dunning-integration.md) — billing workflow vertical slice
- [Installation](installation.md) — Chimeway install and migration depth

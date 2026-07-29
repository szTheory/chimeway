# Phase 70: Recovery, Auth, and Tenancy Hardening - Pattern Map

**Mapped:** 2026-06-04
**Files analyzed:** 16 new/modified files
**Analogs found:** 16 / 16

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `chimeway_admin/lib/chimeway_admin/context.ex` | utility | transform | `chimeway_admin/lib/chimeway_admin/live_auth.ex` | role-match |
| `chimeway_admin/lib/chimeway_admin/auth.ex` | service | request-response | `chimeway_admin/lib/chimeway_admin/auth.ex` | exact |
| `chimeway_admin/lib/chimeway_admin/live_auth.ex` | middleware | request-response | `chimeway_admin/lib/chimeway_admin/live_auth.ex` | exact |
| `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex` | component | request-response | `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex` | exact |
| `chimeway_admin/lib/chimeway_admin/live/health_live.ex` | component | request-response | `chimeway_admin/lib/chimeway_admin/live/health_live.ex` | exact |
| `chimeway_admin/lib/chimeway_admin/live/feed_live.ex` | component | request-response | `chimeway_admin/lib/chimeway_admin/live/feed_live.ex` | exact |
| `chimeway_admin/lib/chimeway_admin/live/definitions_live.ex` | component | request-response | `chimeway_admin/lib/chimeway_admin/live/definitions_live.ex` | exact |
| `chimeway_admin/lib/chimeway_admin/live/recovery_live.ex` | component | request-response | `chimeway_admin/lib/chimeway_admin/live/recovery_live.ex` | exact |
| `lib/chimeway.ex` | service | request-response | `lib/chimeway.ex` | exact |
| `lib/chimeway/admin.ex` | service | CRUD | `lib/chimeway/admin.ex` | exact |
| `lib/chimeway/deliveries.ex` | service | CRUD | `lib/chimeway/deliveries.ex` | exact |
| `examples/chimeway_demo_host/lib/demo_host/admin_auth.ex` | service | request-response | `examples/chimeway_demo_host/lib/demo_host/admin_auth.ex` | exact |
| `examples/chimeway_demo_host/lib/demo_host_web/plugs/admin_actor.ex` | middleware | request-response | `examples/chimeway_demo_host/lib/demo_host_web/plugs/admin_actor.ex` | exact |
| `test/chimeway/admin_test.exs` | test | CRUD | `test/chimeway/admin_test.exs` | exact |
| `test/chimeway/deliveries_test.exs` | test | CRUD | `test/chimeway/deliveries_test.exs` | exact |
| `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs` | test | request-response | `chimeway_admin/test/chimeway_admin/live/design_system_live_test.exs` | role-match |

## Pattern Assignments

### `chimeway_admin/lib/chimeway_admin/context.ex` (utility, transform)

**Analog:** `chimeway_admin/lib/chimeway_admin/live_auth.ex`

**Imports pattern** (lines 11-14):
```elixir
import Phoenix.Component
import Phoenix.LiveView

alias ChimewayAdmin.Auth
```

**Session/actor extraction pattern** (lines 56-65):
```elixir
defp authorize(action, session, socket, extra_context) do
  auth_module = Auth.auth_module()
  actor = socket.assigns[:current_actor] || session["current_actor"]

  context =
    %{
      live_view: socket.view,
      session: session
    }
    |> Map.merge(extra_context)
```

Copy this shape for a new helper that normalizes `%{actor: ..., tenant_id: ..., params: ..., session: ...}`. Keep params/session as context for host authorization, but expose separate safe helpers for core opts and recovery evidence so raw params/session are not persisted.

**Core read opts pattern** (from `lib/chimeway/admin.ex`, lines 293-320):
```elixir
defp maybe_filter_tenant(query, nil), do: query
defp maybe_filter_tenant(query, ""), do: query
defp maybe_filter_tenant(query, tenant_id), do: where(query, [d], d.tenant_id == ^tenant_id)

defp repo_opts(opts) do
  Keyword.drop(opts, [:limit, :tenant_id, :recipient_id, :now, :older_than])
end
```

The new context helper should produce keyword opts containing `:tenant_id` only when non-empty, preserving existing `Chimeway.Admin` filtering semantics.

---

### `chimeway_admin/lib/chimeway_admin/auth.ex` (service, request-response)

**Analog:** `chimeway_admin/lib/chimeway_admin/auth.ex`

**Behaviour callback pattern** (lines 1-30):
```elixir
defmodule ChimewayAdmin.Auth do
  @moduledoc """
  Host-implemented authorization for operator trace surfaces.
  ...
  Host implementations may inspect context (including delivery_id when
  provided) to enforce tenancy or per-resource access.
  """

  @callback authorize(actor :: term(), action :: atom(), context :: map()) ::
              :ok | {:error, :unauthorized}

  @spec auth_module() :: module()
  def auth_module, do: Application.fetch_env!(:chimeway_admin, :auth_module)
end
```

Update docs only if needed. Do not change the callback arity; Phase 70 keeps `authorize/3` as the host-owned seam and enriches the `context` map.

---

### `chimeway_admin/lib/chimeway_admin/live_auth.ex` (middleware, request-response)

**Analog:** `chimeway_admin/lib/chimeway_admin/live_auth.ex`

**Mount authorization pattern** (lines 27-34):
```elixir
def on_mount(action, params, session, socket) when action in @actions do
  case authorize(action, session, socket, %{params: params}) do
    :ok ->
      {:cont, assign(socket, :chimeway_admin_session, session)}

    {:error, _} ->
      {:halt, redirect(socket, to: unauthorized_redirect())}
  end
end
```

**Event-time authorization pattern** (lines 42-53):
```elixir
def ensure_authorized(socket, action, extra_context \\ %{}) when action in @actions do
  session = Map.get(socket.assigns, :chimeway_admin_session, %{})

  case authorize(action, session, socket, extra_context) do
    :ok ->
      {:ok, socket}

    {:error, _} ->
      {:error, redirect(socket, to: unauthorized_redirect())}
  end
end
```

**Error handling pattern** (lines 67-82):
```elixir
case auth_module.authorize(actor, action, context) do
  :ok ->
    :ok

  {:error, :unauthorized} ->
    {:error, :unauthorized}

  other ->
    require Logger

    Logger.warning(
      "ChimewayAdmin.Auth.authorize/3 returned unexpected #{inspect(other)}; treating as unauthorized"
    )

    {:error, :unauthorized}
end
```

Use this fail-closed handling unchanged. Enrich the merged context with actor/action/tenant/resource/candidate facts through the new context helper.

---

### Admin LiveViews: `dashboard_live.ex`, `health_live.ex`, `feed_live.ex`, `definitions_live.ex` (component, request-response)

**Analogs:** same files plus `lib/chimeway/admin.ex`

**Dashboard mount pattern** (from `dashboard_live.ex`, lines 9-12):
```elixir
@impl true
def mount(_params, _session, socket) do
  {:ok, assign(socket, :snapshot, Chimeway.admin_command_center(limit: 8))}
end
```

**Health mount pattern** (from `health_live.ex`, lines 9-16):
```elixir
@impl true
def mount(_params, _session, socket) do
  {:ok,
   assign(socket,
     outcomes: Chimeway.admin_outcome_totals(),
     problems: Chimeway.admin_recent_problem_deliveries(limit: 25),
     recovery_candidates: Chimeway.admin_recovery_candidates(limit: 25)
   )}
end
```

**Feed event/search pattern** (from `feed_live.ex`, lines 14-23):
```elixir
@impl true
def handle_event("search", %{"recipient_id" => recipient_id}, socket) do
  recipient_id = String.trim(recipient_id || "")

  rows =
    if recipient_id == "",
      do: [],
      else: Chimeway.admin_feed(recipient_id: recipient_id, limit: 50)

  {:noreply, assign(socket, query: recipient_id, rows: rows, searched: true)}
end
```

**Definitions mount pattern** (from `definitions_live.ex`, lines 7-10):
```elixir
@impl true
def mount(_params, _session, socket) do
  {:ok, assign(socket, definitions: Chimeway.admin_definitions(limit: 100))}
end
```

Replace direct option literals with `ChimewayAdmin.Context.read_opts(context, limit: n)` style calls, preserving existing assigns and render output.

**Core tenant filtering pattern** (from `lib/chimeway/admin.ex`, lines 35-61 and 245-252):
```elixir
def recent_problem_deliveries(opts \\ []) do
  limit = Keyword.get(opts, :limit, @default_limit)

  Delivery
  |> join(:inner, [d], n in assoc(d, :notification))
  |> join(:inner, [_d, n], e in assoc(n, :event))
  |> where([d], d.status in ^@problem_statuses)
  |> maybe_filter_tenant(Keyword.get(opts, :tenant_id))
  |> order_by([d], desc: d.updated_at)
  |> limit(^limit)
  |> select([d, n, e], %{tenant_id: d.tenant_id, correlation_id: e.correlation_id})
  |> Repo.all(repo_opts(opts))
  |> Enum.map(&delivery_dto/1)
end

def outcome_totals(opts \\ []) do
  Delivery
  |> maybe_filter_tenant(Keyword.get(opts, :tenant_id))
  |> group_by([d], [d.status])
  |> select([d], {d.status, count(d.id)})
  |> Repo.all(repo_opts(opts))
  |> Map.new(fn {status, count} -> {to_string(status), count} end)
end
```

---

### `chimeway_admin/lib/chimeway_admin/live/recovery_live.ex` (component, request-response)

**Analog:** `chimeway_admin/lib/chimeway_admin/live/recovery_live.ex`

**Imports pattern** (lines 5-7):
```elixir
use ChimewayAdmin.Live, :live_view

alias ChimewayAdmin.LiveAuth
```

**One-candidate selection pattern** (lines 20-24):
```elixir
@impl true
def handle_event("choose", %{"id" => id, "type" => type}, socket) do
  selected = Enum.find(socket.assigns.candidates, &(&1.id == id and &1.type == type))
  {:noreply, assign(socket, selected: selected, flash_result: nil)}
end
```

**Submit authorization and noop handling pattern** (lines 26-54):
```elixir
def handle_event("recover", %{"candidate_id" => id, "type" => type, "reason" => reason}, socket) do
  action = if type == "event", do: :recover_event, else: :recover_delivery

  with {:ok, socket} <-
         LiveAuth.ensure_authorized(socket, action, %{resource_id: id, recovery_type: type}),
       {:ok, result} <- do_recover(type, id, reason) do
    {:noreply,
     assign(socket,
       candidates: Chimeway.admin_recovery_candidates(limit: 50),
       selected: nil,
       flash_result: success_message(type, result)
     )}
  else
    {:noop, _result} ->
      {:noreply,
       assign(socket,
         candidates: Chimeway.admin_recovery_candidates(limit: 50),
         selected: nil,
         flash_result: "Recovery skipped: the row is no longer eligible."
       )}

    {:error, socket_or_reason} ->
      if match?(%Phoenix.LiveView.Socket{}, socket_or_reason) do
        {:noreply, socket_or_reason}
      else
        {:noreply,
         assign(socket, flash_result: "Recovery failed: #{inspect(socket_or_reason)}")}
      end
  end
end
```

Keep this event-time authorization and normal noop branch. Extend the context with tenant scope and selected safe candidate facts, add explicit confirmation handling before recovery, and refresh candidates with tenant-scoped opts in every branch.

**Core API call pattern** (lines 136-142):
```elixir
defp do_recover("event", id, reason) do
  Chimeway.recover_event(id, source: "chimeway_admin", reason: reason)
end

defp do_recover("delivery", id, reason) do
  Chimeway.recover_delivery(id, source: "chimeway_admin", reason: reason)
end
```

Add safe evidence only through this existing API path: source, reason, actor reference, recovered_at/now when supplied, and confirmation marker.

---

### `lib/chimeway.ex` (service, request-response)

**Analog:** `lib/chimeway.ex`

**Public delegation pattern** (lines 26-38):
```elixir
@doc """
Recovers a persisted event whose notifications exist but dispatch never planned deliveries.
"""
def recover_event(event_id, opts \\ []) do
  Deliveries.recover_event(event_id, opts)
end

@doc """
Recovers a persisted delivery by re-driving the canonical row through the configured dispatcher.
"""
def recover_delivery(delivery_id, opts \\ []) do
  Deliveries.recover_delivery(delivery_id, opts)
end
```

**Admin read delegation pattern** (lines 40-80):
```elixir
def admin_command_center(opts \\ []) do
  Admin.command_center(opts)
end

def admin_recovery_candidates(opts \\ []) do
  Admin.recovery_candidates(opts)
end

def admin_outcome_totals(opts \\ []) do
  Admin.outcome_totals(opts)
end
```

Preserve these public surfaces. If new safe evidence opts are added, pass them through to `Deliveries` without creating admin-only APIs.

---

### `lib/chimeway/admin.ex` (service, CRUD)

**Analog:** `lib/chimeway/admin.ex`

**DTO/read model pattern** (lines 1-12):
```elixir
defmodule Chimeway.Admin do
  @moduledoc """
  Admin-safe read models for operator UI surfaces.

  This module returns small DTO maps instead of raw Ecto schemas so UI packages do
  not accidentally render payloads, render snapshots, provider responses, or other
  sensitive fields.
  """

  import Ecto.Query

  alias Chimeway.{Delivery, Events.Event, Notifications.Notification, Repo}
```

**Recovery candidate tenant pattern** (lines 166-239):
```elixir
def recovery_candidates(opts \\ []) do
  limit = Keyword.get(opts, :limit, @default_limit)
  now = Keyword.get(opts, :now, DateTime.utc_now())

  delivery_rows =
    Delivery
    |> join(:inner, [d], n in assoc(d, :notification))
    |> join(:inner, [_d, n], e in assoc(n, :event))
    |> where([d], d.status == :pending and d.orchestration_state == :ready)
    |> where([d], fragment("?->>? IS NULL", d.metadata, ^"recovered_at"))
    |> maybe_older_than(now, Keyword.get(opts, :older_than, 60))
    |> maybe_filter_tenant(Keyword.get(opts, :tenant_id))
    |> order_by([d], asc: d.updated_at, asc: d.inserted_at)
    |> limit(^limit)
    |> select([d, n, e], %{type: "delivery", id: d.id, tenant_id: d.tenant_id})
    |> Repo.all(repo_opts(opts))

  event_rows =
    Event
    |> join(:inner, [e], n in assoc(e, :notifications))
    |> join(:left, [_e, n], d in assoc(n, :deliveries))
    |> maybe_older_event_than(now, Keyword.get(opts, :older_than, 60))
    |> maybe_filter_event_tenant(Keyword.get(opts, :tenant_id))
    |> having([_e, _n, d], count(d.id) == 0)
    |> Repo.all(repo_opts(opts))

  (delivery_rows ++ event_rows)
  |> Enum.sort_by(& &1.updated_at, DateTime)
  |> Enum.take(limit)
  |> Enum.map(&recovery_dto/1)
end
```

If Phase 70 adds guards, keep them query-side and DTO-side. Do not expose raw schemas to admin LiveViews.

---

### `lib/chimeway/deliveries.ex` (service, CRUD)

**Analog:** `lib/chimeway/deliveries.ex`

**Atomic recovery claim pattern** (lines 85-136):
```elixir
def begin_recovery(delivery_id, opts) when is_binary(delivery_id) and is_list(opts) do
  now =
    opts
    |> Keyword.get(:now, DateTime.utc_now())
    |> normalize_datetime!()

  cutoff = recoverable_cutoff!(now, Keyword.get(opts, :older_than, 60))
  source = normalize_recovery_value!("recovery source", Keyword.get(opts, :source, "operator"))
  reason = normalize_recovery_value!("recovery reason", Keyword.get(opts, :reason, "stuck"))
  recovered_at = iso8601_utc_usec(now)

  recovery_query =
    from(d in Delivery,
      where:
        d.id == ^delivery_id and d.status == :pending and d.orchestration_state == :ready and
          d.updated_at <= ^cutoff and fragment("?->>? IS NULL", d.metadata, ^"recovered_at"),
      update: [set: [metadata: fragment("jsonb_set(...)", d.metadata), updated_at: ^now]]
    )

  {updated_count, _rows} = Repo.update_all(recovery_query, [])
  updated_delivery = get_delivery!(delivery_id)

  if updated_count == 1, do: {:ok, updated_delivery}, else: {:noop, updated_delivery}
end
```

**Recovery API noop pattern** (lines 168-184 and 246-252):
```elixir
case begin_recovery(delivery_id, Keyword.put(opts, :now, now)) do
  {:ok, _claimed_delivery} ->
    case dispatcher.dispatch_delivery(delivery_id, pre_planned: true, post_commit: true) do
      {:ok, dispatched_delivery} ->
        {:ok, recovery_delivery_result(dispatched_delivery, source, reason, now, :dispatched)}

      {:skip, skipped_delivery} ->
        {:noop, recovery_delivery_result(skipped_delivery, source, reason, now, :skipped)}

      {:error, reason_term} ->
        compensate_failed_recovery_claim(delivery_id, now, older_than)
        {:error, reason_term}
    end

  {:noop, existing_delivery} ->
    {:noop, recovery_delivery_result(existing_delivery, source, reason, now, :noop)}
end

{:noop,
 %{
   event: event,
   deliveries: [],
   recovery: recovery_metadata(source, reason, now)
 }}
```

**Safe value and metadata pattern** (lines 840-869, 904-940):
```elixir
defp normalize_recovery_value!(_label, value)
     when is_binary(value) and byte_size(value) > 0,
     do: value

defp normalize_recovery_value!(label, value)
     when is_atom(value),
     do: normalize_recovery_value!(label, Atom.to_string(value))

defp normalize_recovery_value!(label, value),
  do: raise(ArgumentError, "expected non-empty #{label}, got: #{inspect(value)}")

defp recovery_metadata(source, reason, recovered_at) do
  %{
    source: source,
    reason: reason,
    recovered_at: recovered_at
  }
end
```

Extend the JSONB metadata writer with allowlisted keys only. Keep `{:noop, ...}` outcomes normal and preserve compensation if dispatch fails after claim.

---

### Demo host auth/session files (service/middleware, request-response)

**Analogs:** `examples/chimeway_demo_host/lib/demo_host/admin_auth.ex`, `examples/chimeway_demo_host/lib/demo_host_web/plugs/admin_actor.ex`

**Permissive dev/test auth pattern** (from `admin_auth.ex`, lines 1-28):
```elixir
defmodule DemoHost.AdminAuth do
  @moduledoc """
  Permissive dev/test auth for `chimeway_admin` in the demo host.

  Production always returns `{:error, :unauthorized}` — replace with a host
  `ChimewayAdmin.Auth` implementation before shipping to production.
  """
  @behaviour ChimewayAdmin.Auth

  @impl true
  def authorize(_actor, _action, _context) do
    if authorized?(), do: :ok, else: {:error, :unauthorized}
  end
end
```

**Session actor pattern** (from `admin_actor.ex`, lines 1-10):
```elixir
defmodule DemoHostWeb.Plugs.AdminActor do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    put_session(conn, "current_actor", "demo:operator")
  end
end
```

If the demo host gets a tenant example, add a session key in this plug and keep production authorization fail-closed.

---

### Core tests: `test/chimeway/admin_test.exs`, `test/chimeway/deliveries_test.exs` (test, CRUD)

**Analogs:** same files plus `test/support/data_case.ex`

**DataCase pattern** (from `test/support/data_case.ex`, lines 1-23):
```elixir
defmodule Chimeway.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Chimeway.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Chimeway.DataCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Chimeway.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
```

**Tenant-safe admin test pattern** (from `admin_test.exs`, lines 1-51):
```elixir
defmodule Chimeway.AdminTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.{Admin, Deliveries, Repo}

  test "recovery candidates are tenant filtered and safe" do
    old = ~U[2026-01-15 12:00:00.000000Z]
    now = ~U[2026-01-15 12:05:00.000000Z]

    delivery_a =
      insert_delivery(notification_a, tenant_id: "tenant-a", inserted_at: old, updated_at: old)

    _delivery_b =
      insert_delivery(notification_b, tenant_id: "tenant-b", inserted_at: old, updated_at: old)

    candidates = Admin.recovery_candidates(tenant_id: "tenant-a", now: now, older_than: 60)

    assert [%{id: id, type: "delivery"}] = candidates
    assert id == delivery_a.id
    refute inspect(candidates) =~ "tenant-b@example.test"
  end
end
```

**Recovery metadata/noop test pattern** (from `deliveries_test.exs`, lines 685-745):
```elixir
test "begin_recovery/2 stamps recovery metadata on the canonical row" do
  assert {:ok, recovered_delivery} =
           Deliveries.begin_recovery(delivery,
             now: recovered_at,
             older_than: 60,
             source: "operator_console",
             reason: "dispatch_stuck"
           )

  assert recovered_delivery.metadata["recovery_source"] == "operator_console"
  assert recovered_delivery.metadata["recovery_reason"] == "dispatch_stuck"
  assert recovered_delivery.metadata["recovered_at"] == "2026-04-28T18:00:00.000000Z"
end

test "begin_recovery/2 returns {:noop, delivery} after recovery metadata already exists" do
  assert {:noop, noop_delivery} =
           Deliveries.begin_recovery(delivery.id,
             now: ~U[2026-04-28 18:01:00Z],
             older_than: 60,
             source: "operator_console",
             reason: "dispatch_stuck"
           )

  assert recovered_delivery.metadata == noop_delivery.metadata
end
```

Add assertions for new safe evidence keys and absence of raw payload/session/params/provider fields.

---

### `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs` (test, request-response)

**Analog:** `chimeway_admin/test/chimeway_admin/live/design_system_live_test.exs` and `chimeway_admin/test/chimeway_admin/live_auth_test.exs`

**LiveViewCase pattern** (from `chimeway_admin/test/support/live_view_case.ex`, lines 1-26):
```elixir
defmodule ChimewayAdmin.LiveViewCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest

      @endpoint ChimewayAdmin.TestSupport.Endpoint
    end
  end

  setup _tags do
    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Chimeway.Repo, shared: false)
    previous = Application.get_env(:chimeway_admin, :auth_module)
    Application.put_env(:chimeway_admin, :auth_module, ChimewayAdmin.TestSupport.AllowAuth)
    ...
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
```

**Isolated mount pattern** (from `design_system_live_test.exs`, lines 97-105):
```elixir
defp mount_page(conn, live_view, action, params \\ %{}) do
  {:ok, _view, html} =
    live_isolated(conn, live_view,
      session: %{"current_actor" => "ops:1"},
      on_mount: [{ChimewayAdmin.LiveAuth, action}],
      params: params
    )

  html
end
```

**Authorization context capture pattern** (from `live_auth_test.exs`, lines 49-85):
```elixir
defmodule ParamCaptureAuth do
  @behaviour ChimewayAdmin.Auth

  @impl true
  def authorize(_actor, action, context) do
    :chimeway_admin
    |> Application.fetch_env!(:capture_pid)
    |> send({:authorized, action, context})

    :ok
  end
end

Application.put_env(:chimeway_admin, :auth_module, ParamCaptureAuth)

assert {:cont, _} =
         LiveAuth.on_mount(
           :view_trace,
           %{"delivery_id" => "del-1"},
           %{"current_actor" => "ops:1"},
           socket
         )

assert_receive {:authorized, :view_trace, %{params: %{"delivery_id" => "del-1"}}}
```

Use this capture module to assert recovery submit context includes actor/action/resource/tenant/recovery type/safe candidate facts.

## Shared Patterns

### Authentication

**Source:** `chimeway_admin/lib/chimeway_admin/live_auth.ex`
**Apply to:** All admin LiveViews and recovery submit handlers

```elixir
def on_mount(action, params, session, socket) when action in @actions do
  case authorize(action, session, socket, %{params: params}) do
    :ok -> {:cont, assign(socket, :chimeway_admin_session, session)}
    {:error, _} -> {:halt, redirect(socket, to: unauthorized_redirect())}
  end
end

def ensure_authorized(socket, action, extra_context \\ %{}) when action in @actions do
  session = Map.get(socket.assigns, :chimeway_admin_session, %{})
  case authorize(action, session, socket, extra_context) do
    :ok -> {:ok, socket}
    {:error, _} -> {:error, redirect(socket, to: unauthorized_redirect())}
  end
end
```

### Tenant-Scoped Admin Reads

**Source:** `lib/chimeway/admin.ex`
**Apply to:** Dashboard, health, feed, definitions, recovery reads

```elixir
|> maybe_filter_tenant(Keyword.get(opts, :tenant_id))
|> Repo.all(repo_opts(opts))

defp maybe_filter_tenant(query, nil), do: query
defp maybe_filter_tenant(query, ""), do: query
defp maybe_filter_tenant(query, tenant_id), do: where(query, [d], d.tenant_id == ^tenant_id)
```

### Durable Recovery Evidence

**Source:** `lib/chimeway/deliveries.ex`
**Apply to:** Recovery metadata extension in `begin_recovery/2`, `recover_delivery/2`, `recover_event/2`

```elixir
source = normalize_recovery_value!("recovery source", Keyword.get(opts, :source, "operator"))
reason = normalize_recovery_value!("recovery reason", Keyword.get(opts, :reason, "stuck"))
recovered_at = iso8601_utc_usec(now)

{updated_count, _rows} = Repo.update_all(recovery_query, [])
updated_delivery = get_delivery!(delivery_id)

if updated_count == 1 do
  {:ok, updated_delivery}
else
  {:noop, updated_delivery}
end
```

### Test Harness

**Source:** `chimeway_admin/test/support/live_view_case.ex`, `test/support/data_case.ex`
**Apply to:** New LiveView and core tests

```elixir
use ChimewayAdmin.LiveViewCase, async: false
import Phoenix.LiveViewTest

live_isolated(conn, live_view,
  session: %{"current_actor" => "ops:1"},
  on_mount: [{ChimewayAdmin.LiveAuth, action}],
  params: params
)
```

## No Analog Found

No files lacked an analog. `chimeway_admin/lib/chimeway_admin/context.ex` is new, but it has strong source patterns in `LiveAuth` for session/actor context and `Chimeway.Admin` for read-option normalization.

## Metadata

**Analog search scope:** `chimeway_admin/lib`, `chimeway_admin/test`, `lib/chimeway`, `test/chimeway`, `examples/chimeway_demo_host/lib`
**Files scanned:** 100+ candidate files via `rg --files` and targeted `rg`
**Pattern extraction date:** 2026-06-04

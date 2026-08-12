# Phase 97: Tenant Identity & Compatible Upgrade - Pattern Map

**Mapped:** 2026-08-11  
**Files analyzed:** 25 planned new/modified files and fixture trees  
**Analogs found:** 24 / 25

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/chimeway/tenant_scope.ex` | utility | request-response | `chimeway_admin/lib/chimeway_admin/context.ex` | partial (normalization, not core scope) |
| `lib/chimeway/reconciliation.ex` | service | CRUD | `lib/chimeway/admin.ex` | role-match |
| `lib/chimeway/trigger.ex` | service | transaction/CRUD | same file | exact |
| `lib/chimeway/events/event.ex` | model | CRUD | same file | exact |
| `lib/chimeway/notifications/notification.ex` | model | CRUD | same file | exact |
| `lib/chimeway/inbox.ex` | service | request-response/mutation | same file | exact |
| `lib/chimeway/traces.ex` | service | request-response | same file | exact |
| `lib/chimeway/admin.ex` | service | request-response | same file | exact |
| `lib/chimeway/deliveries.ex` | service | request-response/mutation | same file | exact |
| `chimeway_inbox/lib/chimeway_inbox/live_auth.ex` | middleware | event-driven | same file | exact |
| inbox LiveViews/callers | component | event-driven | `chimeway_inbox/lib/chimeway_inbox/live_auth.ex` | role-match |
| `chimeway_admin/lib/chimeway_admin/context.ex` | utility | request-response | same file | exact |
| `chimeway_admin/lib/chimeway_admin/live_auth.ex` | middleware | event-driven | same file | exact |
| admin LiveViews/callers | component | event-driven | `chimeway_admin/lib/chimeway_admin/context.ex` | role-match |
| `priv/chimeway_migrations/032_add_tenant_identity_to_events_and_notifications.exs` | migration | schema transform | `priv/chimeway_migrations/030_add_tenant_and_actor_to_chimeway_deliveries.exs` | exact prefix-template mechanics |
| generated public/prefixed migration fixture trees | fixture/config | file-I/O | `priv/chimeway_migrations/030_add_tenant_and_actor_to_chimeway_deliveries.exs` | exact generated artifact model |
| `lib/chimeway/install/migrations.ex` | service | file-I/O | same file | exact (likely no logic change) |
| `test/chimeway/tenant_identity_test.exs` | test | CRUD/transaction | `test/chimeway/trigger_pipeline_test.exs` | exact |
| `test/chimeway/tenant_scope_contract_test.exs` | test | request-response | `test/chimeway/inbox_query_test.exs`, `test/chimeway/traces_test.exs` | role-match |
| `test/chimeway/admin_test.exs` | test | request-response | same file | exact |
| `test/chimeway/orchestration/recovery_test.exs` | test | request-response/mutation | same file | exact |
| `test/chimeway/install/migrations_test.exs` | test | file-I/O | same file | exact |
| `test/chimeway/migration_contract_test.exs` and prefix/runtime proof tests | test | schema transform | existing migration/prefix contract suite | exact |
| `chimeway_inbox/test/.../bell_dropdown_live_test.exs` | test | event-driven | existing bell LiveView test | exact |
| `chimeway_admin/test/.../{live_auth,recovery_live,trace_search_live}_test.exs` | test | event-driven | corresponding existing test | exact |

## Pattern Assignments

### `lib/chimeway/tenant_scope.ex` (utility, request-response)

**Analog:** `chimeway_admin/lib/chimeway_admin/context.ex`

**Normalization pattern** (lines 101-124):

```elixir
defp tenant_id(params, session) do
  session_value(session, "chimeway_admin_tenant_id") ||
    session_value(session, "tenant_id") ||
    session_value(params, "tenant_id")
end

defp normalize_value(value) when is_binary(value) do
  value
  |> String.trim()
  |> case do
    "" -> nil
    value -> value
  end
end
```

Copy the nonblank-binary normalization shape, but make the new core resolver return an error for absent scope instead of the admin context's permissive `nil`. Old arities alone may consult a configured concrete compatibility tenant.

### `lib/chimeway/trigger.ex`, `lib/chimeway/events/event.ex`, `lib/chimeway/notifications/notification.ex` (service/models, transaction CRUD)

**Analog:** `lib/chimeway/trigger.ex`

**Required-input transaction pattern** (lines 48-110):

```elixir
with {:ok, idempotency_key} <- Keyword.fetch(opts, :idempotency_key),
     {:ok, tenant_id} <- fetch_tenant_id(opts),
     :ok <- validate_idempotency_key(idempotency_key),
     :ok <- validate_tenant_id(tenant_id),
     {:ok, recipients} <- notifier.recipients(params) do
  do_trigger(notifier, params, opts, idempotency_key, correlation_id, recipients, tenant_id)
end

Multi.new()
|> Multi.insert(:event, event_changeset(...))
|> Multi.run(:notifications, fn repo, %{event: event} ->
  insert_notifications(repo, notifier, params, event, normalized_recipients, tenant_id)
end)
|> Repo.transaction()
```

**Bulk-child row pattern** (lines 170-215):

```elixir
row = %{
  id: UUID.generate() |> UUID.dump!(),
  event_id: UUID.dump!(event.id),
  recipient_identity: recipient_identity(recipient),
  ...,
  inserted_at: timestamp,
  updated_at: timestamp
}
...
repo.insert_all("chimeway_notifications", rows)
```

Add `tenant_id` to the event changeset attributes and every `insert_all` notification row; do not source it from workflow/delivery children.

**Conflict recovery pattern** (lines 247-280):

```elixir
if idempotency_conflict?(changeset) do
  case Repo.get_by(Event, idempotency_key: idempotency_key) do
    nil -> {:error, :duplicate_event_not_found}
    existing_event -> {:duplicate, existing_event}
  end
end
```

Replace both constraint recognition and `Repo.get_by/2` with the same composite `{tenant_id, idempotency_key}` identity.

**Schema pattern:** `lib/chimeway/events/event.ex` lines 14-35 uses field lists, `cast`, `validate_required`, and named `unique_constraint`; `lib/chimeway/notifications/notification.ex` lines 14-44 uses the same pattern. Put `tenant_id` in each schema and required field list. Do not permit it in an update-oriented changeset.

### `lib/chimeway/inbox.ex` (service, request-response/mutation)

**Analog:** same file.

**Atomic no-disclosure mutation pattern** (lines 128-166):

```elixir
case Repo.update_all(query, set: [{field, timestamp}, {:updated_at, timestamp}]) do
  {1, _} -> :ok
  {0, _} -> {:error, :not_found}
end
```

Thread a resolved tenant through `base_recipient_query/1`, list/count queries, each `update_all`, and the signal path. Retain `{:error, :not_found}` for a wrong tenant. Replace the child-row `resolve_tenant_id/1` lookup at lines 173-198 with `notification.tenant_id` obtained under the same scoped predicate.

### `lib/chimeway/traces.ex` (service, request-response)

**Analog:** same file.

**Not-found trace pattern** (lines 46-56):

```elixir
case Repo.get(Event, event_id, repo_opts) do
  nil -> {:error, :not_found}
  event ->
    loaded = Repo.preload(event, [notifications: [deliveries: :attempts]], repo_opts)
    {:ok, loaded}
end
```

Change root lookup from `Repo.get/3` to an Ecto query constrained by event `tenant_id`, and keep tenant conditions in recipient, correlation, delivery explanation, aggregate, preload, and nested trace queries. A wrong tenant must follow this same `:not_found` branch.

### `lib/chimeway/admin.ex` and `chimeway_admin/lib/chimeway_admin/context.ex` (service/utility, request-response)

**Analog:** `lib/chimeway/admin.ex` lines 36-80 and 293-305.

```elixir
|> maybe_filter_tenant(Keyword.get(opts, :tenant_id))

defp maybe_filter_tenant(query, nil), do: query
defp maybe_filter_tenant(query, ""), do: query
defp maybe_filter_tenant(query, tenant_id), do: where(query, [d], d.tenant_id == ^tenant_id)
```

This is the anti-pattern to replace: resolve tenant before constructing the query, then use an unconditional `where`. `ChimewayAdmin.Context.read_opts/2` lines 45-52 and `recovery_opts/3` lines 90-98 show how the optional package forwards host context; retain that host-auth seam but reject missing tenant before core operations.

### `lib/chimeway/deliveries.ex` (service, request-response/mutation)

**Analog:** same file.

**Scoped atomic claim pattern** (lines 103-129): compose the recovery `update_all` predicate with tenant, and preserve `{0, _} -> {:noop, nil}`. Every reload must then retain scope; the current `get_delivery!/1` at line 447 and `Repo.get!(Event, event_id)` at line 210 are unscoped follow-up reads to replace.

**Validation pattern** (lines 278-339):

```elixir
with {:ok, tenant_id} <- normalize_tenant_id(Keyword.get(opts, :tenant_id)),
     {:ok, actor_id} <- normalize_actor_id(Keyword.get(opts, :actor_id)) do
  ...
end

defp normalize_tenant_id(value) when is_binary(value) and byte_size(value) > 0,
  do: {:ok, value}
defp normalize_tenant_id(value), do: {:error, {:invalid_tenant_id, value}}
```

Use the new shared resolver rather than the current `scoped_tenant_id/1` + `maybe_scope_delivery_tenant(query, nil)` permissive fallback at lines 341-362.

### Optional inbox/admin packages (middleware/components, event-driven)

**Analogs:** `chimeway_inbox/lib/chimeway_inbox/live_auth.ex` lines 12-27 and `chimeway_admin/lib/chimeway_admin/live_auth.ex` lines 25-43.

```elixir
case resolve_recipient(session, socket) do
  {:ok, recipient_identity} -> {:cont, assign(socket, ...)}
  {:error, _} -> {:halt, redirect(socket, to: unauthorized_redirect())}
end
```

```elixir
case authorize(action, admin_context, %{}) do
  :ok -> {:cont, socket |> assign(:chimeway_admin_context, admin_context)}
  {:error, _} -> {:halt, redirect(socket, to: unauthorized_redirect())}
end
```

Continue to make host authentication/authorization authoritative. Extend the resolved host context to provide tenant scope to every core call and fail closed if unavailable; do not turn tenant identity into a Chimeway ACL.

### `priv/chimeway_migrations/032_add_tenant_identity_to_events_and_notifications.exs` (migration, schema transform)

**Analog:** `priv/chimeway_migrations/030_add_tenant_and_actor_to_chimeway_deliveries.exs`.

**Copied migration/prefix-helper pattern** (lines 1-17, 55-91):

```elixir
@chimeway_prefix __CHIMEWAY_PREFIX__

def up do
  alter chimeway_table(:chimeway_deliveries) do
    add(:tenant_id, :string)
  end
  flush()
end

defp chimeway_prefix_opts(opts \\ []) do
  if @chimeway_prefix, do: Keyword.put_new(opts, :prefix, @chimeway_prefix), else: opts
end
```

Copy its `up/down`, sentinel, `chimeway_table`, index and quoted-relation helpers. Unlike migration 030 lines 31-48, do **not** backfill from child state, use `"default"`, or make legacy values non-null. Add nullable fields, remove the old global unique idempotency index, then create the named composite index. Reconciliation operates only on NULL legacy rows.

### `lib/chimeway/reconciliation.ex` (service, CRUD)

**Analog:** `lib/chimeway/admin.ex` lines 167-266.

The closest query-service precedent builds Ecto joins, maps stable operator-safe DTOs, and returns lists rather than serializing database structs. Follow it for NULL-tenant report rows and explicit-id + supplied-tenant `update_all` assignment. The report module has no direct existing analog: add explicit JSON-safe maps with `schema_version`, `counts`, NULL tenant values, and an assignment instruction—never inferred ownership.

### Installer and verification artifacts (file-I/O/schema-transform tests)

**Analog:** `lib/chimeway/install/migrations.ex` lines 35-70.

```elixir
list_templates()
|> Enum.with_index()
|> Enum.each(fn {{_order, slug, template_path}, index} ->
  case find_existing_by_slug(slug) do
    nil ->
      content = template_path |> File.read!() |> render_template(host_prefix, generation_prefix)
      File.write!(dest, content)
    existing -> io.info("unchanged #{existing}")
  end
end)
```

Do not introduce a second generator or dynamic storage routing. Adding template `032` automatically participates in stable ordering and idempotent copied outputs; update both golden fixture modes and existing `test/chimeway/install/migrations_test.exs`, `migration_contract_test.exs`, `generated_prefixed_runtime_proof_test.exs`, and `runtime_prefix_integration_test.exs` accordingly.

## Shared Patterns

### Tenant scope and non-disclosure

**Sources:** `lib/chimeway/deliveries.ex` lines 103-129; `lib/chimeway/traces.ex` lines 46-56; `lib/chimeway/inbox.ex` lines 128-166.  
**Apply to:** Inbox, traces, admin, deliveries/recovery, and optional package delegates.

Resolve exactly one nonblank tenant before any query. Add it directly to root/nested read and mutation predicates. Map zero-row/wrong-tenant results to the surface's existing empty, `:not_found`, or `:noop` contract.

### Host ownership of authorization

**Sources:** `chimeway_inbox/lib/chimeway_inbox/live_auth.ex` lines 47-69; `chimeway_admin/lib/chimeway_admin/live_auth.ex` lines 62-95.  
**Apply to:** Phoenix packages only.

Keep package auth modules responsible for identity/membership decisions; core receives already-authorized explicit tenant scope and never derives it from a recipient or UUID.

### Static storage prefix

**Sources:** `priv/chimeway_migrations/030_add_tenant_and_actor_to_chimeway_deliveries.exs` lines 57-91; `lib/chimeway/install/migrations.ex` lines 104-125.  
**Apply to:** migration template, generator goldens, public and `"chimeway"` runtime proofs.

`tenant_id` is a durable column and Ecto predicate only. Preserve the `__CHIMEWAY_PREFIX__` template sentinel and its static `"chimeway"`/`false` rendering; it must never become a request option or dynamic prefix.

### Tests

**Sources:** `test/chimeway/trigger_pipeline_test.exs` lines 316-352 (duplicate behavior), `test/chimeway/inbox_state_transition_test.exs` lines 18-53 (state/no-row result), `test/chimeway/traces_test.exs` lines 174-184 (trace outcome).  
**Apply to:** the two new focused core tests plus edited core/package/migration suites.

Use real Repo rows, assert wrong-tenant indistinguishability, and run existing named verification entrypoints (`mix verify.install_golden`, `mix verify.runtime_prefix`, `mix verify.inbox`, `mix verify.admin`) instead of conversational acceptance.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/chimeway/reconciliation.ex` report contract | service | CRUD/transform | No existing maintenance module exposes a versioned JSON ambiguity report or host-supplied ownership assignment. Use Admin query DTO conventions and the RESEARCH.md report shape. |

## Metadata

**Analog search scope:** `lib/chimeway`, `priv/chimeway_migrations`, `test/chimeway`, `chimeway_inbox`, `chimeway_admin`  
**Files scanned:** 40+ source, migration, package, and verification files  
**Pattern extraction date:** 2026-08-11

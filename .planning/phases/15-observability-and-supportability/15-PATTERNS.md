# Phase 15: Observability & Supportability - Pattern Map

**Mapped:** 2024-05-24
**Files analyzed:** 4
**Analogs found:** 4 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/chimeway/telemetry.ex` | utility | event-driven | `lib/chimeway/telemetry.ex` | exact |
| `lib/chimeway/traces.ex` | service | query | `lib/chimeway/traces.ex` | exact |
| `test/chimeway/telemetry_correlation_test.exs` | test | event-driven | `test/chimeway/telemetry_correlation_test.exs` | exact |
| `test/chimeway/traces_test.exs` | test | query | `test/chimeway/traces_test.exs` | exact |

## Pattern Assignments

### `lib/chimeway/telemetry.ex` (utility, event-driven)

**Analog:** `lib/chimeway/telemetry.ex`

**Imports pattern** (lines 48-49):
```elixir
  require Logger
```

**PII Redaction pattern** (lines 51-55, 88-95):
```elixir
  @allowed_meta_keys ~w(
    notification_key event_id recipient_id channel
    delivery_id attempt_id outcome suppression_reason correlation_id
    attempt_number error_class
  )a

  def safe_meta(meta) when is_map(meta) do
    result =
      meta
      |> normalize_keys()
      |> Map.take(@allowed_meta_keys)

    result
  end
```

**Core span wrapping pattern** (lines 65-71):
```elixir
  def span(event_suffix, meta, func)
      when is_list(event_suffix) and is_map(meta) and is_function(func, 0) do
    :telemetry.span([:chimeway | event_suffix], meta, fn ->
      {result, extra} = func.()
      {result, Map.merge(meta, extra)}
    end)
  end
```

---

### `lib/chimeway/traces.ex` (service, query)

**Analog:** `lib/chimeway/traces.ex`

**Imports pattern** (lines 30-33):
```elixir
  import Ecto.Query

  alias Chimeway.{Delivery, Events.Event, Notifications.Notification, Repo}
  alias Chimeway.Traces.Explanation
```

**Trace assembly pattern** (lines 42-49):
```elixir
  def get_trace(event_id) do
    case Repo.get(Event, event_id) do
      nil ->
        {:error, :not_found}

      event ->
        loaded = Repo.preload(event, notifications: [deliveries: :attempts])
        {:ok, loaded}
    end
  end
```

**Correlation lookup pattern** (lines 89-94):
```elixir
  def find_traces_by_correlation_id(correlation_id) do
    events =
      Repo.all(from(e in Event, where: e.correlation_id == ^correlation_id))

    Repo.preload(events, notifications: [deliveries: :attempts])
  end
```

---

### `test/chimeway/telemetry_correlation_test.exs` (test, event-driven)

**Analog:** `test/chimeway/telemetry_correlation_test.exs`

**Testing telemetry events pattern** (lines 46-60):
```elixir
  test "[:deliveries, :plan] telemetry span is enriched with correlation identifiers" do
    test_pid = self()
    handler_id = :telemetry_enrichment_test

    :telemetry.attach(
      handler_id,
      [:chimeway, :deliveries, :plan, :stop],
      fn _name, _measurements, meta, _config ->
        send(test_pid, {:telemetry_event, meta})
      end,
      nil
    )

    on_exit(fn ->
      :telemetry.detach(handler_id)
    end)
```

---

### `test/chimeway/traces_test.exs` (test, query)

**Analog:** `test/chimeway/traces_test.exs`

**Testing traces extraction pattern** (lines 142-154):
```elixir
    test "OPS-01: get_trace and correlation lookup recover the same event identity" do
      event = insert_event(%{correlation_id: "req-ops-01-link"})
      _notification = insert_notification(event, "user:ops-01")

      assert {:ok, loaded} = Traces.get_trace(event.id)

      events = Traces.find_traces_by_correlation_id("req-ops-01-link")
      assert Enum.any?(events, &(&1.id == loaded.id))
    end
```

## Shared Patterns

### Correlation ID
**Source:** `lib/chimeway/traces.ex`
**Apply to:** Operator trace retrieval logic and host-app context queries.
```elixir
  def find_traces_by_correlation_id(correlation_id) do
    events = Repo.all(from(e in Event, where: e.correlation_id == ^correlation_id))
    Repo.preload(events, notifications: [deliveries: :attempts])
  end
```

### Telemetry PII Redaction
**Source:** `lib/chimeway/telemetry.ex`
**Apply to:** All metadata emission points across the library.
```elixir
  Chimeway.Telemetry.safe_meta(%{notification_key: "abc", PII: "hidden"})
```

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| None | N/A | N/A | Existing robust implementation matches phase objectives exactly. |

## Metadata

**Analog search scope:** `lib/chimeway/**/*.ex` and `test/chimeway/**/*.exs`
**Files scanned:** 31
**Pattern extraction date:** 2024-05-24

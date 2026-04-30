# Phase 29: Outbound Channel Contracts - Pattern Map

**Mapped:** 2026-04-30
**Files analyzed:** 14 new/modified files
**Analogs found:** 14 / 14

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/chimeway/rendering/channel.ex` | behaviour | request-response | `lib/chimeway/notifier.ex` (lines 12-16 + 37-58) | role-match |
| `lib/chimeway/rendering/channels/sms.ex` | validator | transform | `lib/chimeway/rendering/channels/email.ex` | exact |
| `lib/chimeway/rendering/channels/push.ex` | validator | transform | `lib/chimeway/rendering/channels/email.ex` | exact |
| `lib/chimeway/rendering/channels/chat.ex` | validator | transform | `lib/chimeway/rendering/channels/email.ex` | exact |
| `lib/chimeway/rendering/channels/email.ex` | validator | transform | itself (refactor: add `use Chimeway.Rendering.Channel`) | exact |
| `lib/chimeway/rendering/channels/in_app.ex` | validator | transform | itself (refactor: add `use Chimeway.Rendering.Channel`) | exact |
| `lib/chimeway/rendering.ex` | module | request-response | itself (`channel_module/1` lines 230-232; `alias` line 6) | exact |
| `lib/chimeway/dispatch/executor.ex` | service | request-response | `lib/chimeway/dispatch/channel_adapter_config.ex` (lines 17-22) | role-match |
| `lib/chimeway/application.ex` | config | request-response | itself + `lib/chimeway/notifier.ex` (`validate_module!/1` lines 37-58) | role-match |
| `lib/chimeway/delivery_attempt.ex` | model | CRUD | itself (schema + `@optional_fields`) | exact |
| `lib/chimeway/traces.ex` | service | request-response | itself (lines 275-282 + 392-403) | exact |
| `lib/chimeway/adapters/test.ex` | utility | request-response | itself (lines 24-29) | exact |
| `lib/chimeway/telemetry.ex` | utility | event-driven | itself (lines 80-84) | exact |
| `priv/repo/migrations/YYYYMMDD_add_adapter_module_to_chimeway_delivery_attempts.exs` | migration | CRUD | `priv/repo/migrations/20260426150000_add_attempt_history_columns.exs` | exact |

---

## Pattern Assignments

### `lib/chimeway/rendering/channel.ex` (NEW behaviour)

**Analog:** `lib/chimeway/notifier.ex`

**`__using__/1` macro pattern** (notifier.ex lines 12-16):
```elixir
defmacro __using__(_opts) do
  quote do
    @behaviour Chimeway.Notifier
  end
end
```

**`validate_module!/1` pattern for boot-time checks** (notifier.ex lines 37-58 — same
`Code.ensure_loaded?` + `function_exported?` pattern used in `Application.start/2`):
```elixir
def validate_module!(module) when is_atom(module) do
  cond do
    not Code.ensure_loaded?(module) ->
      {:error, :notifier_not_loaded}

    not function_exported?(module, :notification_key, 0) ->
      {:error, :missing_notification_key_callback}

    true ->
      :ok
  end
end
```

**New `channel.ex` module to produce** (copy macro, declare callback, add `@optional_callbacks` if needed — full verified shape from RESEARCH.md Q3):
```elixir
defmodule Chimeway.Rendering.Channel do
  @moduledoc """
  Behaviour contract for channel-specific render validation.

  ## Usage

      defmodule MyApp.Channels.Slack do
        use Chimeway.Rendering.Channel

        @impl Chimeway.Rendering.Channel
        def validate(attrs) when is_map(attrs) do
          # ... Ecto.Changeset validation ...
        end
      end
  """

  @callback validate(attrs :: map()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Chimeway.Rendering.Channel
    end
  end
end
```

---

### `lib/chimeway/rendering/channels/sms.ex` (NEW — D-25: copy email.ex skeleton verbatim)

**Analog:** `lib/chimeway/rendering/channels/email.ex` (full file, 42 lines)

**Full email.ex to copy verbatim and adapt** (email.ex lines 1-42):
```elixir
defmodule Chimeway.Rendering.Channels.Email do
  @moduledoc """
  Validates the durable email render contract.
  """

  import Ecto.Changeset

  @types %{
    subject: :string,
    html_body: :string,
    text_body: :string
  }

  @required_fields [:subject, :html_body, :text_body]

  @spec validate(map()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
  def validate(attrs) when is_map(attrs) do
    {%{}, @types}
    |> cast(attrs, Map.keys(@types))
    |> validate_required(@required_fields)
    |> apply_action(:insert)
    |> case do
      {:ok, validated} -> {:ok, stringify_keys(validated)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def validate(other) do
    types = %{payload: :map}

    {%{}, types}
    |> cast(%{payload: other}, [:payload])
    |> add_error(:payload, "must be a map")
    |> apply_action(:insert)
  end

  defp stringify_keys(map) do
    Enum.into(map, %{}, fn {key, value} ->
      {Atom.to_string(key), value}
    end)
  end
end
```

**SMS substitutions** (D-01, D-03, D-25):
- Module name: `Chimeway.Rendering.Channels.Sms`
- Add `use Chimeway.Rendering.Channel` after the module's `@moduledoc`
- Add `@impl Chimeway.Rendering.Channel` before the `def validate(attrs)` clause
- `@types %{text_body: :string}`
- `@required_fields [:text_body]`
- `@moduledoc` must note the 160-char GSM-7 / 70-char UCS-2 segment reality (D-03); do NOT add a validator for it

---

### `lib/chimeway/rendering/channels/push.ex` (NEW)

**Analog:** `lib/chimeway/rendering/channels/email.ex` (same full skeleton above)

**Push substitutions** (D-05):
- Module name: `Chimeway.Rendering.Channels.Push`
- Add `use Chimeway.Rendering.Channel` + `@impl Chimeway.Rendering.Channel`
- `@types %{title: :string, body: :string, data: :map}`
- `@required_fields [:title, :body]`
- `data` is `:map` only — no sub-shape validation (D-08)
- `@moduledoc` must note that APNs/FCM platform plumbing (`apns_topic`, `priority`, `device_token`) belongs in the adapter, not here (D-07)

---

### `lib/chimeway/rendering/channels/chat.ex` (NEW)

**Analog:** `lib/chimeway/rendering/channels/email.ex` (same full skeleton above)

**Chat substitutions** (D-09):
- Module name: `Chimeway.Rendering.Channels.Chat`
- Add `use Chimeway.Rendering.Channel` + `@impl Chimeway.Rendering.Channel`
- `@types %{text: :string, rich_payload: :map}`
- `@required_fields [:text]`
- `rich_payload` is `:map` only — opaque for Slack `blocks`, Discord `embeds`, etc. (D-09)

---

### `lib/chimeway/rendering/channels/email.ex` (MODIFIED — refactor only)

**Analog:** itself

**Changes required:**
1. Add `use Chimeway.Rendering.Channel` after the opening `@moduledoc` block
2. Add `@impl Chimeway.Rendering.Channel` before the `def validate(attrs) when is_map(attrs)` clause

No functional changes. Current file (lines 1-42) is the template; after refactor it looks like:
```elixir
defmodule Chimeway.Rendering.Channels.Email do
  @moduledoc """
  Validates the durable email render contract.
  """

  use Chimeway.Rendering.Channel   # ADD THIS

  import Ecto.Changeset

  @types %{...}
  @required_fields [...]

  @impl Chimeway.Rendering.Channel  # ADD THIS
  @spec validate(map()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
  def validate(attrs) when is_map(attrs) do
    # ... unchanged ...
  end
  # ... rest unchanged ...
end
```

---

### `lib/chimeway/rendering/channels/in_app.ex` (MODIFIED — refactor only)

**Analog:** itself (in_app.ex lines 1-71)

Same two-line refactor as email.ex:
- Add `use Chimeway.Rendering.Channel` after `@moduledoc`
- Add `@impl Chimeway.Rendering.Channel` before `def validate(attrs) when is_map(attrs)` (line 17)

InApp has nested validation via `validate_primary_action/1` — leave that unchanged.

---

### `lib/chimeway/rendering.ex` (MODIFIED — `channel_module/1` + alias)

**Analog:** itself

**Current alias** (rendering.ex line 6):
```elixir
alias Chimeway.Rendering.Channels.{Email, InApp}
```

**New alias** (extend to cover the three new modules):
```elixir
alias Chimeway.Rendering.Channels.{Email, InApp, Sms, Push, Chat}
```

**Current `channel_module/1` clauses** (rendering.ex lines 230-232):
```elixir
defp channel_module("in_app"), do: {:ok, InApp}
defp channel_module("email"), do: {:ok, Email}
defp channel_module(channel), do: {:error, {:unsupported_render_channel, channel}}
```

**New three-layer `channel_module/1`** (D-12; full verified shape from RESEARCH.md Q8):
```elixir
defp channel_module("email"), do: {:ok, Email}
defp channel_module("in_app"), do: {:ok, InApp}
defp channel_module("sms"), do: {:ok, Sms}
defp channel_module("push"), do: {:ok, Push}
defp channel_module("chat"), do: {:ok, Chat}
defp channel_module(channel) do
  # Layer 1: registry lookup
  case Application.get_env(:chimeway, :channel_render_modules, %{}) |> Map.get(channel) do
    nil ->
      # Layer 3: graceful fallback — delivery_planning.ex:437-446 catches
      # {:unsupported_render_channel, _} and substitutes render_data: %{}
      :telemetry.execute(
        [:chimeway, :rendering, :channel_unregistered],
        %{count: 1},
        %{channel: channel}
      )
      Logger.warning(
        "[chimeway] unregistered render channel #{inspect(channel)} hit graceful fallback — " <>
          "render_data will be empty. Configure :channel_render_modules or add a compiled clause."
      )
      {:error, {:unsupported_render_channel, channel}}

    module ->
      {:ok, module}
  end
end
```

Note: `require Logger` must be added at the top of `rendering.ex` if not already present.

---

### `lib/chimeway/dispatch/executor.ex` (MODIFIED — `resolve_adapter/1` + `adapter_module` persist)

**Analog:** `lib/chimeway/dispatch/channel_adapter_config.ex` (lines 17-22 — `preferred_config/1`)

**`preferred_config/1` pattern to mirror** (channel_adapter_config.ex lines 17-22):
```elixir
defp preferred_config(channel) do
  case Application.get_env(:chimeway, :channel_adapter_configs, %{}) do
    configs when is_map(configs) -> Map.get(configs, channel)
    _ -> nil
  end
end
```

**Current `run_delivery/1`** (executor.ex lines 29-44):
```elixir
def run_delivery(%Delivery{} = delivery) do
  with {:ok, dispatched} <- Deliveries.transition_status(delivery, :dispatched) do
    adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    adapter_config = ChannelAdapterConfig.resolve(delivery.channel, [])

    {attempt_outcome, error_class, provider_response} =
      dispatched
      |> adapter.deliver(adapter_config)
      |> classify()

    Deliveries.record_attempt(dispatched, %{
      outcome: attempt_outcome,
      error_class: error_class,
      provider_response: provider_response
    })
  end
end
```

**New `run_delivery/1` + `resolve_adapter/1`** (D-17, D-19, D-20 — full verified shape from RESEARCH.md Q2):
```elixir
def run_delivery(%Delivery{} = delivery) do
  with {:ok, dispatched} <- Deliveries.transition_status(delivery, :dispatched) do
    adapter = resolve_adapter(dispatched.channel)           # D-17: was hardcoded get_env
    adapter_config = ChannelAdapterConfig.resolve(delivery.channel, [])

    {attempt_outcome, error_class, provider_response} =
      dispatched
      |> adapter.deliver(adapter_config)
      |> classify()

    Deliveries.record_attempt(dispatched, %{
      outcome: attempt_outcome,
      error_class: error_class,
      provider_response: provider_response,
      adapter_module: inspect(adapter)                      # D-20: persist as string, never atom
    })
  end
end

defp resolve_adapter(channel) when is_binary(channel) do
  channel_adapters = Application.get_env(:chimeway, :channel_adapters, %{})

  case Map.get(channel_adapters, channel) do
    nil ->
      fallback = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)

      if map_size(channel_adapters) > 0 do
        :telemetry.execute(                                 # D-19: only when :channel_adapters set AND miss
          [:chimeway, :dispatch, :adapter_fallback],
          %{count: 1},
          %{channel: channel, fallback_module: inspect(fallback)}
        )
      end

      fallback

    adapter_module ->
      adapter_module
  end
end
```

Key: use `inspect(adapter)` not `to_string(adapter)` — `inspect(MyModule)` → `"MyModule"` (no `Elixir.` prefix); `to_string(MyModule)` → `"Elixir.MyModule"`. D-20 specifies `inspect/1`.

---

### `lib/chimeway/application.ex` (MODIFIED — registry validation at boot)

**Analog:** itself + `lib/chimeway/notifier.ex` (`validate_module!/1` pattern for `Code.ensure_loaded?` + `function_exported?`)

**Current `start/2`** (application.ex lines 8-19):
```elixir
@impl true
def start(_type, _args) do
  children =
    [
      Chimeway.Repo
    ] ++ oban_child()

  opts = [strategy: :one_for_one, name: Chimeway.Supervisor]
  Supervisor.start_link(children, opts)
end
```

**New `start/2` + `validate_channel_render_modules!/0`** (D-13 — full verified shape from RESEARCH.md Q4):
```elixir
@impl true
def start(_type, _args) do
  validate_channel_render_modules!()              # D-13: boot fails loud on typo'd module names

  children =
    [
      Chimeway.Repo
    ] ++ oban_child()

  opts = [strategy: :one_for_one, name: Chimeway.Supervisor]
  Supervisor.start_link(children, opts)
end

defp validate_channel_render_modules! do
  registry = Application.get_env(:chimeway, :channel_render_modules, %{})

  Enum.each(registry, fn {channel, module} ->
    cond do
      not is_atom(module) ->
        raise ArgumentError,
              "[chimeway] :channel_render_modules[#{inspect(channel)}] must be a module atom, " <>
                "got: #{inspect(module)}"

      not Code.ensure_loaded?(module) ->
        raise ArgumentError,
              "[chimeway] :channel_render_modules[#{inspect(channel)}] module #{inspect(module)} " <>
                "could not be loaded"

      not function_exported?(module, :validate, 1) ->
        raise ArgumentError,
              "[chimeway] :channel_render_modules[#{inspect(channel)}] module #{inspect(module)} " <>
                "does not export validate/1"

      true ->
        :ok
    end
  end)
end
```

The `oban_child/0` private function (lines 21-30) uses the same `Code.ensure_loaded?(Oban)` pattern — the new helper follows that convention.

---

### `lib/chimeway/delivery_attempt.ex` (MODIFIED — `adapter_module` field)

**Analog:** itself

**Current schema block** (delivery_attempt.ex lines 39-47):
```elixir
schema "chimeway_delivery_attempts" do
  field(:outcome, Ecto.Enum, values: [:succeeded, :failed, :bounced, :rejected])
  field(:provider_response, :map)
  field(:attempt_number, :integer)
  field(:error_class, :string)
  field(:inserted_at, :utc_datetime_usec)

  belongs_to(:delivery, Chimeway.Delivery)
end
```

**Current `@optional_fields`** (delivery_attempt.ex line 53):
```elixir
@optional_fields ~w(error_class provider_response)a
```

**Two changes required** (D-20):
1. Add `field(:adapter_module, :string)` to schema block after `field(:error_class, :string)`
2. Extend `@optional_fields`:
```elixir
@optional_fields ~w(error_class provider_response adapter_module)a
```

No change to `@required_fields`. No `validate_inclusion` for `adapter_module` — any string is valid; operators own module naming. The `cast/3` call already uses `@required_fields ++ @optional_fields` — adding to `@optional_fields` is sufficient.

---

### `lib/chimeway/traces.ex` (MODIFIED — `adapter_module` in explain output)

**Analog:** itself

**Current `build_last_attempt_map/1`** (traces.ex lines 275-282):
```elixir
defp build_last_attempt_map(attempt) do
  %{
    outcome: attempt.outcome,
    inserted_at: attempt.inserted_at,
    attempt_number: attempt.attempt_number,
    error_class: attempt.error_class
  }
end
```

**New `build_last_attempt_map/1`** (D-22):
```elixir
defp build_last_attempt_map(attempt) do
  %{
    outcome: attempt.outcome,
    inserted_at: attempt.inserted_at,
    attempt_number: attempt.attempt_number,
    error_class: attempt.error_class,
    adapter_module: attempt.adapter_module   # NEW — nil for pre-Phase-29 rows
  }
end
```

**Current `attempt_entries` map** (traces.ex lines 392-403):
```elixir
attempt_entries =
  Enum.map(attempts, fn attempt ->
    %{
      at: attempt.inserted_at,
      event: :attempt_recorded,
      detail: %{
        outcome: attempt.outcome,
        attempt_number: attempt.attempt_number,
        error_class: attempt.error_class
      }
    }
  end)
```

**New `attempt_entries` map** (D-22 — add `adapter_module` to detail):
```elixir
attempt_entries =
  Enum.map(attempts, fn attempt ->
    %{
      at: attempt.inserted_at,
      event: :attempt_recorded,
      detail: %{
        outcome: attempt.outcome,
        attempt_number: attempt.attempt_number,
        error_class: attempt.error_class,
        adapter_module: attempt.adapter_module   # NEW — nil for pre-Phase-29 rows
      }
    }
  end)
```

**`Chimeway.Traces.Explanation` struct** (`lib/chimeway/traces/explanation.ex`) — two changes (D-22):

1. `@moduledoc` field list: add `- adapter_module` to the `last_attempt` field description (line 32)
2. `@type t` — extend `last_attempt` type (lines 57-63):
```elixir
last_attempt:
  %{
    outcome: atom(),
    inserted_at: DateTime.t(),
    attempt_number: pos_integer() | nil,
    error_class: String.t() | nil,
    adapter_module: String.t() | nil     # NEW
  }
  | nil,
```

---

### `lib/chimeway/adapters/test.ex` (MODIFIED — channel-tagged mailbox send)

**Analog:** itself

**Current `deliver/2`** (test.ex lines 24-29):
```elixir
@impl Chimeway.Adapter
def deliver(%Chimeway.Delivery{} = delivery, _config) do
  existing = Process.get(:chimeway_test_deliveries, [])
  Process.put(:chimeway_test_deliveries, [delivery | existing])
  {:ok, %{adapter: "test", delivered_at: DateTime.utc_now()}}
end
```

**New `deliver/2`** (D-23 — add `send(self(), ...)` for channel-tagged assertions):
```elixir
@impl Chimeway.Adapter
def deliver(%Chimeway.Delivery{} = delivery, _config) do
  existing = Process.get(:chimeway_test_deliveries, [])
  Process.put(:chimeway_test_deliveries, [delivery | existing])
  send(self(), {:chimeway_delivery, delivery.channel, delivery})   # D-23
  {:ok, %{adapter: "test", delivered_at: DateTime.utc_now()}}
end
```

`delivered_messages/0`, `assert_delivered/1`, and `clear/0` are UNCHANGED. Existing tests using `delivered_messages()` / `assert_delivered()` remain unmodified. New tests use `assert_receive {:chimeway_delivery, "sms", %Delivery{}}`.

---

### `lib/chimeway/telemetry.ex` (MODIFIED — `@allowed_meta_keys` gain `:adapter_module`)

**Analog:** itself

**Current `@allowed_meta_keys`** (telemetry.ex lines 80-84):
```elixir
@allowed_meta_keys ~w(
  notification_key event_id recipient_id channel
  delivery_id attempt_id outcome suppression_reason correlation_id
  attempt_number error_class
)a
```

**New `@allowed_meta_keys`** (D-22 — add `adapter_module`):
```elixir
@allowed_meta_keys ~w(
  notification_key event_id recipient_id channel
  delivery_id attempt_id outcome suppression_reason correlation_id
  attempt_number error_class adapter_module
)a
```

This is the only change to `telemetry.ex`. The `safe_meta/1` function (lines 125-132) uses `Map.take(@allowed_meta_keys)` — no change needed there, it inherits the new key automatically.

---

### `priv/repo/migrations/YYYYMMDD_add_adapter_module_to_chimeway_delivery_attempts.exs` (NEW)

**Analog:** `priv/repo/migrations/20260426150000_add_attempt_history_columns.exs`

**Full analog migration** (add_attempt_history_columns.exs lines 1-46):
```elixir
defmodule Chimeway.Repo.Migrations.AddAttemptHistoryColumns do
  use Ecto.Migration

  def up do
    alter table(:chimeway_delivery_attempts) do
      add :attempt_number, :integer, null: true
      add :error_class, :string, null: true
    end

    execute(
      """
      UPDATE chimeway_delivery_attempts AS a
      SET attempt_number = sub.rn
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY delivery_id ORDER BY inserted_at, id) AS rn
        FROM chimeway_delivery_attempts
      ) AS sub
      WHERE a.id = sub.id;
      """,
      "UPDATE chimeway_delivery_attempts SET attempt_number = NULL;"
    )

    create index(:chimeway_delivery_attempts, [:error_class])
  end

  def down do
    drop index(:chimeway_delivery_attempts, [:error_class])
    alter table(:chimeway_delivery_attempts) do
      remove :error_class
      remove :attempt_number
    end
  end
end
```

**New migration** (D-20 — simpler: nullable add, no backfill, no index):
```elixir
defmodule Chimeway.Repo.Migrations.AddAdapterModuleToChimewayDeliveryAttempts do
  use Ecto.Migration

  def change do
    alter table(:chimeway_delivery_attempts) do
      add :adapter_module, :string, null: true
    end
  end
end
```

Use `def change` (not `def up / def down`) because there is no `execute/1` call — simple reversible `add` is sufficient. `null: true` is explicit (project convention: nullable columns are explicitly tagged). No index — query pattern is by `delivery_id`, not by `adapter_module`. No backfill — existing rows predate the feature; `explain_delivery/1` shows `nil` for `adapter_module` on pre-Phase-29 rows.

---

## Test Pattern Assignments

### `test/chimeway/rendering/channel_contract_test.exs` (EXTENDED)

**Analog:** itself (full file, 81 lines)

**Existing email round-trip test to copy verbatim and adapt** (channel_contract_test.exs lines 31-53):
```elixir
test "renders validated email payloads with subject, html_body, and text_body" do
  assert {:ok,
          %{
            channel: "email",
            render_data: %{
              "html_body" => "<p>Ada left a new comment</p>",
              "subject" => "New comment",
              "text_body" => "Ada left a new comment"
            },
            render_key: "comment.created.email",
            render_version: 4
          }} =
           Rendering.render_delivery(
             :email,
             "comment.created.email",
             4,
             %{
               "html_body" => "<p>Ada left a new comment</p>",
               "subject" => "New comment",
               "text_body" => "Ada left a new comment"
             }
           )
end
```

**Existing error test to copy verbatim and adapt** (channel_contract_test.exs lines 55-71):
```elixir
test "returns tagged runtime validation failures for malformed channel payloads" do
  assert {:error,
          {:rendering_failed, "email", {:invalid_channel_payload, "email", changeset}}} =
           Rendering.render_delivery(:email, "comment.created.email", 4, %{"subject" => "Missing bodies"})

  assert %Ecto.Changeset{} = changeset
  assert %{html_body: ["can't be blank"], text_body: ["can't be blank"]} = errors_on(changeset)
end
```

**New SMS round-trip substitution:**
- channel atom: `:sms`; render_key: `"otp.sent.sms"`; render_version: `1`
- `render_data`: `%{"text_body" => "Your code is 123456"}`
- Error case: omit `text_body` → `%{text_body: ["can't be blank"]}`

**New Push round-trip substitution:**
- channel atom: `:push`; render_key: `"alert.push"`; render_version: `1`
- `render_data`: `%{"body" => "New message", "title" => "Alert", "data" => %{"deep_link" => "/inbox"}}`
- Error case: omit `title` → `%{title: ["can't be blank"]}`

**New Chat round-trip substitution:**
- channel atom: `:chat`; render_key: `"comment.chat"`; render_version: `1`
- `render_data`: `%{"text" => "Hello", "rich_payload" => %{"blocks" => []}}`
- Error case: omit `text` → `%{text: ["can't be blank"]}`

**New registry-overlay case** (D-12 — use Application env isolation pattern from delivery_lifecycle_test.exs lines 378-390):
```elixir
test "host-defined channel resolves via registry overlay" do
  defmodule TestSlackChannel do
    use Chimeway.Rendering.Channel
    @impl Chimeway.Rendering.Channel
    def validate(attrs) when is_map(attrs), do: {:ok, attrs}
    def validate(_), do: {:error, :invalid}
  end

  original = Application.get_env(:chimeway, :channel_render_modules)
  Application.put_env(:chimeway, :channel_render_modules, %{"slack" => TestSlackChannel})

  on_exit(fn ->
    case original do
      nil -> Application.delete_env(:chimeway, :channel_render_modules)
      val -> Application.put_env(:chimeway, :channel_render_modules, val)
    end
  end)

  assert {:ok, %{channel: "slack"}} =
           Rendering.render_delivery(:slack, "slack.message", 1, %{"text" => "hi"})
end
```

### `test/chimeway/integration/delivery_lifecycle_test.exs` (EXTENDED)

**Analog:** itself (lines 378-440 — Scenario B: Test adapter pattern)

**`Application.put_env` isolation pattern to reuse** (delivery_lifecycle_test.exs lines 378-390):
```elixir
setup do
  original = Application.get_env(:chimeway, :adapter)
  Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
  TestAdapter.clear()

  on_exit(fn ->
    case original do
      nil -> Application.delete_env(:chimeway, :adapter)
      mod -> Application.put_env(:chimeway, :adapter, mod)
    end
    TestAdapter.clear()
  end)

  :ok
end
```

**New assertions to add** for `adapter_module` on attempt rows (D-20):
```elixir
# After triggering delivery and loading attempt:
assert attempt.adapter_module == "Chimeway.Adapters.Test"
```

For channel-tagged mailbox assertion (D-23):
```elixir
assert_receive {:chimeway_delivery, "email", %Chimeway.Delivery{}}
```

### `test/chimeway/traces_test.exs` (EXTENDED)

**Analog:** itself (existing `explain_delivery` tests)

**New assertions** (D-22):
```elixir
{:ok, explanation} = Chimeway.Traces.explain_delivery(delivery.id)
assert explanation.last_attempt.adapter_module == "Chimeway.Adapters.Test"
```

For pre-Phase-29 rows (nil path):
```elixir
assert is_nil(explanation.last_attempt.adapter_module)
```

### `test/chimeway/telemetry_integration_test.exs` (EXTENDED)

**Analog:** itself (existing telemetry attach/assert pattern)

**New assertions** (D-14, D-19):
```elixir
# channel_unregistered fires for unknown channel:
:telemetry.attach("test-unregistered", [:chimeway, :rendering, :channel_unregistered], handler, nil)
# trigger render for unknown channel
assert_receive {:telemetry_event, [:chimeway, :rendering, :channel_unregistered], %{count: 1}, %{channel: "unknown_xyz"}}

# adapter_fallback fires when :channel_adapters is set and lookup misses:
:telemetry.attach("test-fallback", [:chimeway, :dispatch, :adapter_fallback], handler, nil)
Application.put_env(:chimeway, :channel_adapters, %{"sms" => SomeAdapter})
# trigger email delivery (not in :channel_adapters)
assert_receive {:telemetry_event, [:chimeway, :dispatch, :adapter_fallback], %{count: 1}, %{channel: "email", fallback_module: _}}
```

---

## Shared Patterns

### Behaviour + `use` macro
**Source:** `lib/chimeway/notifier.ex` lines 12-16
**Apply to:** `lib/chimeway/rendering/channel.ex` (new behaviour definition)
```elixir
defmacro __using__(_opts) do
  quote do
    @behaviour Chimeway.Notifier   # → substitute Chimeway.Rendering.Channel
  end
end
```

### Module validation with `Code.ensure_loaded?` + `function_exported?`
**Source:** `lib/chimeway/notifier.ex` lines 37-58; `lib/chimeway/application.ex` lines 21-30 (`oban_child/0`)
**Apply to:** `lib/chimeway/application.ex` new `validate_channel_render_modules!/0` helper

### String-safe resolver (`Map.get` on config-keyed map, no `String.to_atom`)
**Source:** `lib/chimeway/dispatch/channel_adapter_config.ex` lines 17-22
**Apply to:** `lib/chimeway/dispatch/executor.ex` new `resolve_adapter/1` function and `lib/chimeway/rendering.ex` new `channel_module/1` registry-overlay clause

### Application env isolation in tests
**Source:** `test/chimeway/integration/delivery_lifecycle_test.exs` lines 378-390
**Apply to:** all test cases that set `:channel_render_modules` or `:channel_adapters`
```elixir
setup do
  original = Application.get_env(:chimeway, :the_key)
  Application.put_env(:chimeway, :the_key, test_value)
  on_exit(fn ->
    case original do
      nil -> Application.delete_env(:chimeway, :the_key)
      val -> Application.put_env(:chimeway, :the_key, val)
    end
  end)
  :ok
end
```

### Ecto.Changeset render-contract skeleton
**Source:** `lib/chimeway/rendering/channels/email.ex` lines 1-42
**Apply to:** `sms.ex`, `push.ex`, `chat.ex` — copy verbatim, substitute module name + `@types` + `@required_fields`

---

## No Analog Found

All 14 files have clear analogs in the codebase. No file requires external pattern references.

---

## Metadata

**Analog search scope:** `lib/chimeway/`, `test/chimeway/`, `priv/repo/migrations/`
**Files scanned:** 14 source files read directly; RESEARCH.md cross-referenced for verified line-number citations
**Pattern extraction date:** 2026-04-30

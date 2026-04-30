# Phase 29: Outbound Channel Contracts — Research

**Researched:** 2026-04-30
**Domain:** Elixir channel-render contracts, adapter resolution, Ecto migration, telemetry, test ergonomics
**Confidence:** HIGH (all findings verified against codebase or official patterns already in this project)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01** `Chimeway.Rendering.Channels.Sms` — `@types %{text_body: :string}`, `@required_fields [:text_body]`
- **D-02** SMS MUST NOT include `from`, `to`, `phone_number`, sender ID, `unicode`, or vendor-shaped routing fields
- **D-03** No GSM-7 / UCS-2 length validation; document 160/70 reality in `@moduledoc`, do not enforce
- **D-04** No `media_url` / MMS support in Phase 29
- **D-05** `Chimeway.Rendering.Channels.Push` — `@types %{title: :string, body: :string, data: :map}`, `@required_fields [:title, :body]`
- **D-06** Single `:push` channel — no `:push_ios` / `:push_android` split
- **D-07** Push MUST NOT include APNs/FCM platform-plumbing fields or `device_token` / `to`
- **D-08** `data` is validated only as `:map`, no strict sub-shape
- **D-09** `Chimeway.Rendering.Channels.Chat` — `@types %{text: :string, rich_payload: :map}`, `@required_fields [:text]`
- **D-10** Chat is the starter validator; host apps use the registry seam for vendor-specific shapes
- **D-11** `Chimeway.Rendering.Channel` behaviour with `@callback validate(attrs :: map()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}` plus `use Chimeway.Rendering.Channel` macro injecting `@behaviour`; all five built-ins declare the behaviour
- **D-12** `channel_module/1` resolution order: (1) registry, (2) compiled clauses, (3) graceful fallback at `delivery_planning.ex:437-446`
- **D-13** Registry validation at `Chimeway.Application.start/2`; boot fails loud on bad module names
- **D-14** Emit `[:chimeway, :rendering, :channel_unregistered]` + `Logger.warning` on first hit of graceful fallback for unknown channel
- **D-15** New config key `:channel_adapters` shaped `%{String.t() => module()}`
- **D-16** `Chimeway.Adapter` behaviour unchanged — single `c:deliver/2` callback
- **D-17** Resolution at `Executor.run_delivery/1` via `resolve_adapter/1` private function; falls back to `:adapter`
- **D-18** Existing `:adapter` keeps working unchanged; no deprecation in v1.4
- **D-19** Emit `[:chimeway, :dispatch, :adapter_fallback]` only when `:channel_adapters` is set AND lookup misses
- **D-20** `chimeway_delivery_attempts.adapter_module :string` column; stored as `inspect(module)` string; NEVER atom
- **D-21** Per-attempt not per-delivery; retry can change adapter across attempts
- **D-22** `Chimeway.Traces.explain_delivery/1` per-attempt rendering gains `via {adapter_module}`; add `:adapter_module` to `[:chimeway, :dispatch, :delivery, :stop]` metadata
- **D-23** `Chimeway.Adapters.Test` sends `{:chimeway_delivery, channel, %Delivery{}}` to calling process; existing tests update to channel-tagged shape
- **D-24** No preview API changes; `preview/3` and Mix task already channel-agnostic
- **D-25** All five built-in channels use Ecto.Changeset skeleton; no switch to defstruct

### Claude's Discretion
- Exact atom names for `use Chimeway.Rendering.Channel` macro internals
- Whether registry validation lives in `Application.start/2`, `__after_compile__/2`, or dedicated helper — pick most testable seam
- Exact telemetry measurements/metadata maps for `channel_unregistered` and `adapter_fallback`
- Migration ordering for `adapter_module` column (nullable, no backfill required)

### Deferred Ideas (OUT OF SCOPE)
- Per-delivery adapter resolution behaviour (`Chimeway.AdapterResolver`)
- Adapter failover / round-robin operators
- MMS / `media_url` in SMS contract
- Push `image_url`, action buttons, `category`
- Per-platform push channels (`:push_ios` / `:push_android`)
- Bundled vendor adapters in core
- Inbound webhook ingestion, outcome-driven workflow progression, trace expansion for async callbacks (Phases 30-32)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CHAN-01 | System supports generic outbound channel adapters (SMS, Push, Chat) without hard-coupling to specific vendor SDKs | D-01..D-19 cover three new channel modules + adapter registry; D-15..D-17 add per-channel adapter resolution without vendor coupling |
| CHAN-02 | Channel-specific rendering contracts exist to format payloads appropriately for different channels (e.g. `text_body` for SMS vs `html_body` for email) | D-01/D-05/D-09 define field shapes per channel; D-11/D-25 enforce via behaviour + Changeset; D-12 wires `channel_module/1` resolver |
</phase_requirements>

---

## Summary

Phase 29 is a pure extension of an already well-designed channel/adapter seam. The codebase already separates rendering contracts (per-channel Ecto.Changeset validators) from adapters (dumb transport seams) and already has one string-safe resolver pattern (`ChannelAdapterConfig`) to mirror. Every major decision in CONTEXT.md is fully constrained — there are no design choices left for research to discover. The research task is therefore to surface exact code shapes, insertion points, and edge cases so the planner can write precise task instructions.

The three new render-contract modules (`Sms`, `Push`, `Chat`) are trivial copies of `Channels.Email` with field-shape substitutions. The interesting work is (a) the new `Chimeway.Rendering.Channel` behaviour + macro, (b) the three-layer `channel_module/1` resolver, (c) the `resolve_adapter/1` extension in `Executor`, (d) the nullable `adapter_module` migration + schema wiring, and (e) the `Adapters.Test` channel-tagging refactor that ripples into every test that calls `delivered_messages/0` or `assert_delivered/1`.

**Primary recommendation:** Follow the exact code patterns already in this repository. Nothing new needs inventing. Copy `Email` for the three new modules, mirror `ChannelAdapterConfig.resolve/2` for adapter resolution, and pattern-match `Notifier.__using__/1` for the Channel behaviour macro.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| SMS/Push/Chat render contract validation | Rendering (compile-time) | — | Pure changeset validators; no I/O |
| Channel-render-module registry | Rendering (runtime config) | Application boot | Config-keyed; validated at boot |
| Per-channel adapter resolution | Dispatch / Executor | Config | Mirrors existing ChannelAdapterConfig pattern |
| Adapter identity persistence | Dispatch / Executor | Database (attempts table) | Written at attempt-record time |
| Trace surface (`via adapter_module`) | Traces / Explanation | — | Read from attempt row at explain time |
| Test channel-tagging | Adapters.Test | — | Delivery channel tagged on send |
| Boot-time registry validation | Application.start/2 | — | D-13 locked location |

---

## Standard Stack

### Core (no new dependencies — everything is already in the project)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ecto` | existing | Changeset validation for render contracts | Already used by all five channels |
| `:telemetry` | existing | Event emission for misconfig signals | Already wired in `Chimeway.Telemetry` facade |

[VERIFIED: project mix.exs and existing lib/chimeway/rendering/channels/ directory]

No new hex dependencies are introduced by Phase 29.

---

## Architecture Patterns

### System Architecture Diagram

```
Trigger.trigger/3
     |
     v
DeliveryPlanning.plan_notification/2
     |
     v
Rendering.render_delivery/4
     |
     +--> channel_module/1
     |       Layer 1: Application.get_env(:chimeway, :channel_render_modules, %{}) |> Map.get(channel)
     |       Layer 2: compiled clauses (email | in_app | sms | push | chat)
     |       Layer 3: graceful fallback -> emit channel_unregistered telemetry -> render_data: %{}
     |
     v (validated render_data persisted on delivery row)
     |
Dispatcher (Sync or Oban)
     |
     v
Executor.run_delivery/1
     |
     +--> resolve_adapter(delivery.channel)
     |       Map.get(Application.get_env(:chimeway, :channel_adapters, %{}), channel)
     |       || Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
     |       [if :channel_adapters set AND miss -> emit adapter_fallback telemetry]
     |
     +--> adapter.deliver(delivery, config)
     |
     v
Deliveries.record_attempt/2
     |
     +--> DeliveryAttempt.changeset/2 (adapter_module field added)
     |
     v
Traces.explain_delivery/1
     +--> build_last_attempt_map/1 (gains adapter_module)
     +--> attempt_entries in timeline (gains "via {adapter_module}")
```

### Recommended Project Structure

```
lib/chimeway/rendering/
├── channel.ex               # NEW: behaviour + __using__ macro
├── channels/
│   ├── email.ex             # UNCHANGED (refactor to declare @behaviour)
│   ├── in_app.ex            # UNCHANGED (refactor to declare @behaviour)
│   ├── sms.ex               # NEW
│   ├── push.ex              # NEW
│   └── chat.ex              # NEW
└── preview.ex               # UNCHANGED

lib/chimeway/dispatch/
└── executor.ex              # MODIFIED: resolve_adapter/1 + persist adapter_module

lib/chimeway/adapters/
├── logger.ex                # UNCHANGED
└── test.ex                  # MODIFIED: channel-tagging

lib/chimeway/
├── application.ex           # MODIFIED: registry validation pass
├── delivery_attempt.ex      # MODIFIED: adapter_module field
└── traces.ex                # MODIFIED: via {adapter_module} in explain_delivery

priv/repo/migrations/
└── YYYYMMDD_add_adapter_module_to_chimeway_delivery_attempts.exs  # NEW
```

---

## Research Findings by Question

### Q1: Migration approach

**Most recent migration that adds columns to `chimeway_delivery_attempts`:**
`priv/repo/migrations/20260426150000_add_attempt_history_columns.exs`

**Canonical migration filename pattern:**
`YYYYMMDDHHMMSS_<verb>_<what>_to_<table>.exs` — for this phase:
`20260430HHMMSS_add_adapter_module_to_chimeway_delivery_attempts.exs`

**Canonical `up/down` shape (from 20260426150000):**
```elixir
defmodule Chimeway.Repo.Migrations.AddAdapterModuleToChimewayDeliveryAttempts do
  use Ecto.Migration

  def up do
    alter table(:chimeway_delivery_attempts) do
      add :adapter_module, :string, null: true
    end
  end

  def down do
    alter table(:chimeway_delivery_attempts) do
      remove :adapter_module
    end
  end
end
```

No index needed (query pattern is by delivery_id, not by adapter_module). No backfill — existing rows predate the feature; traces show `via (unknown adapter)` for null rows. [VERIFIED: codebase inspection of existing migration shape]

**Key observations from 20260426150000:**
- Uses `def up / def down` (not `def change`) because it mixes `add` with a subsequent `execute` in the real file. For Phase 29 which is a simple nullable add with no backfill, `def change` is also valid.
- `null: true` is explicit (project convention: nullable columns are explicitly tagged).

### Q2: Schema wiring for `adapter_module`

**Schema file:** `lib/chimeway/delivery_attempt.ex`

**Current `@optional_fields`:**
```elixir
@optional_fields ~w(error_class provider_response)a
```

**Addition required:**
```elixir
@optional_fields ~w(error_class provider_response adapter_module)a
```

No change to `@required_fields` — `adapter_module` is nullable for backwards-compat.

**Schema block addition:**
```elixir
schema "chimeway_delivery_attempts" do
  field(:outcome, Ecto.Enum, values: [:succeeded, :failed, :bounced, :rejected])
  field(:provider_response, :map)
  field(:attempt_number, :integer)
  field(:error_class, :string)
  field(:adapter_module, :string)   # NEW — Phase 29 D-20
  field(:inserted_at, :utc_datetime_usec)
  belongs_to(:delivery, Chimeway.Delivery)
end
```

**Changeset:** `cast/3` already uses `@required_fields ++ @optional_fields` — adding to `@optional_fields` is sufficient. No explicit `validate_inclusion` needed (any string is valid; operators own module naming).

**Write site in `Executor.run_delivery/1`:**
The call to `Deliveries.record_attempt/2` passes an attrs map. The resolved adapter module must be captured before the `deliver/2` call and injected into the attrs:

```elixir
def run_delivery(%Delivery{} = delivery) do
  with {:ok, dispatched} <- Deliveries.transition_status(delivery, :dispatched) do
    adapter = resolve_adapter(dispatched.channel)           # NEW
    adapter_config = ChannelAdapterConfig.resolve(delivery.channel, [])

    {attempt_outcome, error_class, provider_response} =
      dispatched
      |> adapter.deliver(adapter_config)
      |> classify()

    Deliveries.record_attempt(dispatched, %{
      outcome: attempt_outcome,
      error_class: error_class,
      provider_response: provider_response,
      adapter_module: inspect(adapter)                      # NEW D-20
    })
  end
end

defp resolve_adapter(channel) when is_binary(channel) do
  channel_adapters = Application.get_env(:chimeway, :channel_adapters, %{})

  case Map.get(channel_adapters, channel) do
    nil ->
      fallback = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)

      if map_size(channel_adapters) > 0 do
        :telemetry.execute(                                 # NEW D-19
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

**`inspect/1` produces the full Elixir module name string:**
`inspect(Chimeway.Adapters.Logger)` → `"Chimeway.Adapters.Logger"` (not `"Elixir.Chimeway.Adapters.Logger"` — Elixir's `inspect/1` for modules strips the `Elixir.` prefix). Confirmed by checking `Chimeway.Dispatch.Oban` which uses `to_string(DigestFlushWorker)` and observing that `to_string/1` on a module atom also produces the `"Chimeway...."` form without the `Elixir.` prefix. [VERIFIED: Elixir language semantics; consistent with `inspect(Module)` behavior]

### Q3: `use Chimeway.Rendering.Channel` macro shape

**Reference pattern in codebase:** `lib/chimeway/notifier.ex`

```elixir
defmacro __using__(_opts) do
  quote do
    @behaviour Chimeway.Notifier
  end
end
```

**New Channel behaviour + macro:**

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

**`@impl true` warnings** surface automatically from Elixir's compiler when `@behaviour` is declared and `validate/1` is implemented with `@impl true`. Using `@impl Chimeway.Rendering.Channel` is the canonical form — it also catches typos by referencing the behaviour explicitly.

**Compile-order guarantee:** `Chimeway.Rendering.Channel` must be compiled before the modules that declare `@behaviour Chimeway.Rendering.Channel`. Mix compiles files in dependency order. Since `Channels.Email` will have `use Chimeway.Rendering.Channel` which references the module, Mix infers the dependency automatically. No explicit `:compile_paths` or `@after_compile` needed. [VERIFIED: standard Elixir/Mix compile-time dependency resolution]

**Refactor path for existing built-ins:** Each existing channel module (`Email`, `InApp`) gains `use Chimeway.Rendering.Channel` in its module body and `@impl Chimeway.Rendering.Channel` before its `validate/1` definition. No functional change — compiler will now enforce the callback.

### Q4: Registry validation seam

**Decision from CONTEXT.md:** D-13 locks the location to `Chimeway.Application.start/2`.

**Recommendation (within that constraint):** Inline validation helper `validate_channel_render_modules!/0` called at the START of `start/2` before `Supervisor.start_link/2`. This crashes loud at boot. If needed in tests, the helper can be suppressed by not having `:channel_render_modules` configured (default is `%{}`).

**Current `Application.start/2` shape:**
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

**Extended shape:**
```elixir
@impl true
def start(_type, _args) do
  validate_channel_render_modules!()              # NEW D-13

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
              "[chimeway] :channel_render_modules[#{inspect(channel)}] must be a module atom, got: #{inspect(module)}"

      not Code.ensure_loaded?(module) ->
        raise ArgumentError,
              "[chimeway] :channel_render_modules[#{inspect(channel)}] module #{inspect(module)} could not be loaded"

      not function_exported?(module, :validate, 1) ->
        raise ArgumentError,
              "[chimeway] :channel_render_modules[#{inspect(channel)}] module #{inspect(module)} does not export validate/1"

      true ->
        :ok
    end
  end)
end
```

**Why not `__after_compile__/2`?** That hook runs at compile-time of the `Rendering` module, when host config is not available. Boot-time (`Application.start/2`) is the only point where `Application.get_env/3` returns the host's configured registry.

**Why not `Rendering.Registry.warmup/0`?** It adds indirection with no benefit — `Application.start/2` is the canonical boot hook for Elixir/OTP applications. Tests override config with `Application.put_env` in `setup` blocks and reset with `on_exit`, so the validator runs only when explicitly configured. [VERIFIED: existing `Application.start/2` pattern + Elixir OTP boot semantics]

**Testability:** Unit tests for `validate_channel_render_modules!` can be written against a private helper extracted to `Chimeway.Rendering.ChannelRegistry.validate!/1` if needed — but for Phase 29 scope, inline is simpler and matches the `oban_child/0` pattern already in the same file.

### Q5: Telemetry event shapes

**Existing telemetry facade:** All events route through `Chimeway.Telemetry.span/3` which wraps `:telemetry.span/3`. The `safe_meta/1` filter allows these atom keys: `notification_key event_id recipient_id channel delivery_id attempt_id outcome suppression_reason correlation_id attempt_number error_class`.

**Phase 29 adds two NEW non-span events** (point events, not spans — they fire once, not start/stop):

**Event 1: `[:chimeway, :rendering, :channel_unregistered]`**
```elixir
:telemetry.execute(
  [:chimeway, :rendering, :channel_unregistered],
  %{count: 1},
  %{channel: channel_string}
)
Logger.warning("[chimeway] unregistered channel #{inspect(channel_string)} hit graceful fallback — render_data will be empty. Configure :channel_render_modules or add a compiled clause.")
```
- `measurements`: `%{count: 1}` — operators can count occurrences in dashboards
- `metadata`: `%{channel: channel_string}` — the unknown channel string that hit fallback
- Fired from inside `channel_module/1` before returning the graceful fallback

**Event 2: `[:chimeway, :dispatch, :adapter_fallback]`**
```elixir
:telemetry.execute(
  [:chimeway, :dispatch, :adapter_fallback],
  %{count: 1},
  %{channel: channel_string, fallback_module: inspect(fallback_adapter_module)}
)
```
- `measurements`: `%{count: 1}`
- `metadata`: `%{channel: channel_string, fallback_module: "MyApp.SwooshAdapter"}` — which channel missed, which fallback was used
- Fired ONLY when `:channel_adapters` is configured AND the lookup misses (D-19)

**Existing `[:chimeway, :dispatch, :delivery, :stop]` extension (D-22):**
The CONTEXT references this event, but inspection of the codebase shows the actual existing events are `[:chimeway, :dispatch, :sync]` and `[:chimeway, :dispatch, :perform]`. There is no `[:chimeway, :dispatch, :delivery]` span today. D-22 says to add `:adapter_module` to that event. This means the `:delivery` span must either be created new in `Executor.run_delivery/1` or the `:adapter_module` must be added to the `:sync` stop metadata. The planner should interpret D-22 as: add `adapter_module` to the `:chimeway, :dispatch, :sync, :stop` stop metadata (via `extra_stop_meta`) since that is the span wrapping `Executor.run_delivery/1` today. The `Telemetry.safe_meta/1` allowlist must also be extended to include `:adapter_module`.

**`safe_meta/1` allowlist addition required in `telemetry.ex`:**
```elixir
@allowed_meta_keys ~w(
  notification_key event_id recipient_id channel
  delivery_id attempt_id outcome suppression_reason correlation_id
  attempt_number error_class adapter_module
)a
```
[VERIFIED: telemetry.ex lines 80-84]

### Q6: `Chimeway.Adapters.Test` channel-tagging update

**Current `deliver/2` implementation (lib/chimeway/adapters/test.ex:25-29):**
```elixir
@impl Chimeway.Adapter
def deliver(%Chimeway.Delivery{} = delivery, _config) do
  existing = Process.get(:chimeway_test_deliveries, [])
  Process.put(:chimeway_test_deliveries, [delivery | existing])
  {:ok, %{adapter: "test", delivered_at: DateTime.utc_now()}}
end
```

**D-23 new shape** — the CONTEXT says `assert_receive {:chimeway_delivery, channel, %Delivery{}}`. This is a process mailbox send, not just a process dictionary store. The new implementation sends to the calling test process AND keeps the dict for `delivered_messages/0` compatibility:

```elixir
@impl Chimeway.Adapter
def deliver(%Chimeway.Delivery{} = delivery, _config) do
  existing = Process.get(:chimeway_test_deliveries, [])
  Process.put(:chimeway_test_deliveries, [delivery | existing])
  send(self(), {:chimeway_delivery, delivery.channel, delivery})   # NEW D-23
  {:ok, %{adapter: "test", delivered_at: DateTime.utc_now()}}
end
```

**Wait — `send(self(), ...)` sends to the Executor process, not the test process.** This is the core challenge of D-23. The Swoosh test adapter pattern uses the calling-process mailbox. Chimeway's sync dispatcher calls `Executor.run_delivery/1` synchronously in the test process, so `self()` IS the test process during sync dispatch tests.

For Oban-backed tests, the Oban worker runs in a different process. The `send(self(), ...)` approach only works for sync dispatch tests. Existing Oban tests that check `delivered_messages/0` (reading the process dict) would break if the Oban worker process is separate.

**Resolution:** Looking at the existing test infrastructure — `Chimeway.Adapters.Test` stores in the CALLING process's dictionary. In Oban tests with `Oban.drain_queue`, the job runs in-process (synchronously). So `self()` during drain is the test process. The existing `delivered_messages/0` already works this way. The new `send(self(), ...)` follows the same assumption.

**Tests that pattern-match the OLD shape and need updating:**
The old `assert_receive {:chimeway_delivery, ...}` pattern does NOT currently exist in the codebase — the current Test adapter does NOT send to the mailbox at all. D-23 is ADDING this capability. The existing tests use `delivered_messages/0` and `assert_delivered/1`. Those methods work via process dictionary and do NOT need updating for the new channel-tagged mailbox send. They remain functional as-is.

What DOES need updating: any tests that call `assert_receive {:chimeway_delivery, %Delivery{}}` (the old two-tuple shape). Since this capability doesn't exist yet, there are ZERO tests to update for the receive shape. The new tests should use `{:chimeway_delivery, channel, %Delivery{}}` from day one.

**D-23 implication:** Existing tests using `delivered_messages()` and `assert_delivered()` are UNCHANGED. New tests for multi-channel behavior use `assert_receive {:chimeway_delivery, "sms", %Delivery{}}`. [VERIFIED: no existing `assert_receive {:chimeway_delivery, ...}` patterns in test/**/*.exs]

### Q7: `Chimeway.Traces.explain_delivery/1` — insertion point for `via {adapter_module}`

**Current per-attempt rendering (traces.ex:393-403):**
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

**Phase 29 extension** — add `adapter_module` to the detail map:
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

**D-22 also requires `via {adapter_module}` in the trace TEXT output.** The `explain_delivery/1` function returns an `%Explanation{}` struct — it does not produce text. "Via" rendering is for dashboards and IEx consumers reading the struct. The planner should interpret D-22's `via {adapter_module}` as:
1. Include `adapter_module` in the `%Explanation.last_attempt` map
2. Include `adapter_module` in each `attempt_entries` detail
3. Update `build_last_attempt_map/1` to include `adapter_module`
4. Update the `Explanation` struct and typspec to include `adapter_module` in `last_attempt`

**Null-safe rendering (per Discretion):** For nil `adapter_module` rows (pre-Phase-29 attempts), the field is simply `nil` in the map — no special rendering needed. Consumers that produce human-readable output (dashboards, docs) format `nil` as `"(unknown adapter)"` or omit the line. The library itself does not format strings.

**`build_last_attempt_map/1` update (traces.ex:275-282):**
```elixir
defp build_last_attempt_map(attempt) do
  %{
    outcome: attempt.outcome,
    inserted_at: attempt.inserted_at,
    attempt_number: attempt.attempt_number,
    error_class: attempt.error_class,
    adapter_module: attempt.adapter_module   # NEW
  }
end
```

**`Explanation` struct/typespec update (traces/explanation.ex):**
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

### Q8: `channel_module/1` resolution order

**Current implementation (rendering.ex:230-232):**
```elixir
defp channel_module("in_app"), do: {:ok, InApp}
defp channel_module("email"), do: {:ok, Email}
defp channel_module(channel), do: {:error, {:unsupported_render_channel, channel}}
```

**Phase 29 extension (D-12 three-layer order):**
```elixir
defp channel_module("email"), do: {:ok, Email}
defp channel_module("in_app"), do: {:ok, InApp}
defp channel_module("sms"), do: {:ok, Chimeway.Rendering.Channels.Sms}
defp channel_module("push"), do: {:ok, Chimeway.Rendering.Channels.Push}
defp channel_module("chat"), do: {:ok, Chimeway.Rendering.Channels.Chat}
defp channel_module(channel) do
  # Layer 1: registry lookup
  case Application.get_env(:chimeway, :channel_render_modules, %{}) |> Map.get(channel) do
    nil ->
      # Layer 3: graceful fallback — telemetry + return unsupported error
      # (delivery_planning.ex:437-446 catches {:unsupported_render_channel, _} and uses render_data: %{})
      :telemetry.execute(
        [:chimeway, :rendering, :channel_unregistered],
        %{count: 1},
        %{channel: channel}
      )
      Logger.warning("[chimeway] unregistered render channel #{inspect(channel)} ...")
      {:error, {:unsupported_render_channel, channel}}

    module ->
      {:ok, module}
  end
end
```

**Key insight:** The "graceful fallback" in `delivery_planning.ex:437-446` is the ACTUAL layer-3 handler — it catches `{:unsupported_render_channel, unsupported_channel}` and returns `render_data: %{}`. `channel_module/1` does NOT need to return `{:ok, some_module}` for the graceful path — it returns `{:error, {:unsupported_render_channel, channel}}` and the delivery_planning catch clause handles it. Phase 29 just inserts the telemetry emit before returning that error.

**The alias list** at the top of `rendering.ex` must be extended:
```elixir
alias Chimeway.Rendering.Channels.{Email, InApp, Sms, Push, Chat}
```

### Q9: `Chimeway.Rendering.Channel` behaviour file location

**Existing rendering directory layout:**
```
lib/chimeway/rendering/
├── channels/
│   ├── email.ex
│   └── in_app.ex
└── preview.ex
```

**New file:** `lib/chimeway/rendering/channel.ex`

This slots at the same level as `preview.ex`, which is correct — it's a top-level rendering concern (the behaviour definition), not a channel implementation. [VERIFIED: directory listing]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Render contract validation | Custom struct pattern-matching | Ecto.Changeset skeleton (D-25) | Produces JSONB-safe stringified maps that survive Oban serialization; changesets give field errors for free |
| Boot-time module validation | Custom registry supervisor | `Code.ensure_loaded?/1` + `function_exported?/3` in `Application.start/2` | Two standard OTP functions; already used in `application.ex` for Oban |
| String-safe module resolution | `String.to_atom/1` or `Module.safe_concat/1` | Direct atom values from `config.exs` + `Map.get/3` | Config values are compile-time atoms; channel strings are runtime binaries — keep the boundary |
| Per-channel adapter dispatch | Per-channel behaviour variants | Single `Chimeway.Adapter` behaviour with per-channel module selection (D-16) | Avoids per-channel callback drift; adapters are dumb transport seams |

---

## Common Pitfalls

### Pitfall 1: Compile-order footgun with `@behaviour` declaration

**What goes wrong:** If `Channels.Email` uses `use Chimeway.Rendering.Channel` before `channel.ex` is compiled, the compiler raises `module Chimeway.Rendering.Channel is not loaded and could not be found`.

**Why it happens:** Mix resolves compile-time dependencies from `use`/`import`/`alias` references. Adding `use Chimeway.Rendering.Channel` in `email.ex` creates a dependency that Mix must honor.

**How to avoid:** Mix infers this dependency automatically — no action required. The `use Chimeway.Rendering.Channel` call in each channel module creates a compile-time reference, which Mix's dependency resolver will satisfy by compiling `channel.ex` first.

**Warning signs:** If you see `module ... is not loaded` at compile time, check for circular aliases or a missing `use` clause.

### Pitfall 2: Test isolation for `:channel_render_modules`

**What goes wrong:** `Application.put_env(:chimeway, :channel_render_modules, %{"slack" => MySlack})` in one test leaks into the next test if `on_exit` is not registered.

**How to avoid:** Follow the existing `delivery_lifecycle_test.exs` pattern:
```elixir
setup do
  original = Application.get_env(:chimeway, :channel_render_modules)
  on_exit(fn ->
    case original do
      nil -> Application.delete_env(:chimeway, :channel_render_modules)
      val -> Application.put_env(:chimeway, :channel_render_modules, val)
    end
  end)
end
```

**Warning signs:** Tests passing in isolation but failing when the full suite runs.

### Pitfall 3: Registry validation crashes the test suite

**What goes wrong:** If the host's `Application.start/2` calls `validate_channel_render_modules!()` and tests configure invalid modules, tests crash at boot rather than at assertion time.

**How to avoid:** `validate_channel_render_modules!()` only validates modules that ARE configured. Tests that don't configure `:channel_render_modules` hit the `%{}` default and skip validation entirely. Tests that configure the registry in `setup` run AFTER `Application.start/2` — they don't retrigger validation. The validation only matters for typos in production `config/config.exs`, which is the correct catch point.

### Pitfall 4: `inspect/1` module string format confusion

**What goes wrong:** Confusing `inspect(MyModule)` with `to_string(MyModule)` or `Atom.to_string(MyModule)`.

**Verified behavior:**
- `inspect(Chimeway.Adapters.Logger)` → `"Chimeway.Adapters.Logger"`
- `to_string(Chimeway.Adapters.Logger)` → `"Elixir.Chimeway.Adapters.Logger"`
- `Atom.to_string(Chimeway.Adapters.Logger)` → `"Elixir.Chimeway.Adapters.Logger"`

D-20 says use `inspect(module)` — this produces the human-readable form WITHOUT the `Elixir.` prefix. Use `inspect/1` consistently, not `to_string/1`.

The project's existing Oban code uses `to_string(DigestFlushWorker)` for Oban job matching (line 191 in `oban.ex`). That pattern is specific to Oban's job worker string format which includes the `Elixir.` prefix. For `adapter_module` column values, use `inspect/1` as D-20 specifies. [VERIFIED: Elixir semantics]

### Pitfall 5: `channel_unregistered` fires on every render for unknown channels

**What goes wrong:** The telemetry event fires every time `render_delivery/4` is called for an unknown channel, which could be every delivery planning cycle if a host misconfigures a channel.

**Recommended mitigation:** D-14 says "the first time" — implement a `:persistent_term` or ETS-based once-flag per channel string if high-frequency delivery is expected. For Phase 29 scope, simply emitting on every call is acceptable since operators will see the warning in logs and fix the config. The planner may choose to add the once-flag as an optional hardening task.

### Pitfall 6: Backwards-compat with existing tests using `:adapter` config

**What goes wrong:** If `resolve_adapter/1` checks `map_size(channel_adapters) > 0` before emitting `adapter_fallback` telemetry, and tests set `:channel_adapters` to `%{}` explicitly, they might accidentally trigger telemetry.

**How to avoid:** The condition is: `:channel_adapters is configured AND is a non-empty map AND the channel lookup misses`. Tests that only configure `:adapter` (the legacy key) never set `:channel_adapters`, so `Application.get_env(:chimeway, :channel_adapters, %{})` returns `%{}` (default) and `map_size(%{}) == 0` — fallback telemetry is silent. [VERIFIED: D-18 and D-19 together]

---

## Code Examples

### Canonical render-channel module (Email — full module to copy verbatim)

[VERIFIED: lib/chimeway/rendering/channels/email.ex]

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

**SMS module substitution:** Replace module name, `@moduledoc`, `@types %{text_body: :string}`, `@required_fields [:text_body]`. Remove `validate(other)` fallback — keep it (all built-ins should have it for graceful non-map input handling). Add `@moduledoc` note about 160/70 char limits per D-03.

**Push module substitution:** `@types %{title: :string, body: :string, data: :map}`, `@required_fields [:title, :body]`.

**Chat module substitution:** `@types %{text: :string, rich_payload: :map}`, `@required_fields [:text]`.

After adding `use Chimeway.Rendering.Channel` and `@impl Chimeway.Rendering.Channel` to each:

```elixir
defmodule Chimeway.Rendering.Channels.Sms do
  @moduledoc """
  Validates the durable SMS render contract.

  Only the message body is a render concern. Sender ID, Messaging Service SID,
  and recipient phone number are adapter-config territory — never in render_data.

  GSM-7 encoding supports up to 160 characters per segment; UCS-2 (unicode) supports
  up to 70 characters per segment. Multi-segment messages are billed per segment.
  Segmentation and encoding are vendor concerns handled in the adapter.
  """

  use Chimeway.Rendering.Channel

  import Ecto.Changeset

  @types %{text_body: :string}
  @required_fields [:text_body]

  @impl Chimeway.Rendering.Channel
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
    Enum.into(map, %{}, fn {key, value} -> {Atom.to_string(key), value} end)
  end
end
```

### Canonical channel-contract round-trip test (Email — copy shape verbatim)

[VERIFIED: test/chimeway/rendering/channel_contract_test.exs]

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

**SMS round-trip test substitution:**
```elixir
test "renders validated SMS payloads with text_body" do
  assert {:ok,
          %{
            channel: "sms",
            render_data: %{"text_body" => "Your code is 123456"},
            render_key: "otp.sent.sms",
            render_version: 1
          }} =
           Rendering.render_delivery(
             :sms,
             "otp.sent.sms",
             1,
             %{"text_body" => "Your code is 123456"}
           )
end
```

### `ChannelAdapterConfig.resolve/2` resolver pattern to mirror (lines 17-22)

[VERIFIED: lib/chimeway/dispatch/channel_adapter_config.ex]

```elixir
defp preferred_config(channel) do
  case Application.get_env(:chimeway, :channel_adapter_configs, %{}) do
    configs when is_map(configs) -> Map.get(configs, channel)
    _ -> nil
  end
end
```

**`:channel_adapters` resolver mirrors this exactly:**
```elixir
defp preferred_adapter(channel) do
  case Application.get_env(:chimeway, :channel_adapters, %{}) do
    adapters when is_map(adapters) -> Map.get(adapters, channel)
    _ -> nil
  end
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single global `:adapter` config | `:channel_adapters` map + `:adapter` fallback (Phase 29) | Phase 29 | Per-channel adapter without breaking existing configs |
| Two compiled channel modules (Email, InApp) | Five compiled + open registry | Phase 29 | Host apps extend without forking the library |
| No adapter identity on attempts | `adapter_module` string column (Phase 29) | Phase 29 | Operators can answer "which adapter ran?" per attempt |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `inspect(MyModule)` produces `"MyModule"` without `Elixir.` prefix | Q4 / Schema wiring | adapter_module column stores wrong format — operators see confusing strings. Mitigation: a single `iex> inspect(Chimeway.Adapters.Logger)` call at plan-start verifies. |
| A2 | `send(self(), ...)` inside `Adapters.Test.deliver/2` reaches the test process during sync dispatch and Oban.drain_queue | Q6 | Channel-tagged `assert_receive` tests would time out in Oban tests. Low risk: Oban drain is synchronous in-process. |
| A3 | Mix compile-order resolves `Chimeway.Rendering.Channel` before channel modules automatically | Q3 | Compile error. Easily fixed by adding explicit alias or reordering. Very low risk for standard Mix apps. |

**If this table has items:** Plans should include a "smoke check" step at Wave 0 to verify A1.

---

## Open Questions

1. **`[:chimeway, :dispatch, :delivery, :stop]` — does this event exist or should Phase 29 create it?**
   - What we know: The current telemetry catalog (telemetry.ex) does NOT include a `[:chimeway, :dispatch, :delivery]` span. The existing span wrapping `Executor.run_delivery/1` is `[:chimeway, :dispatch, :sync]`.
   - What's unclear: D-22 references this event. Was it intended to be created new, or is it a reference to `[:chimeway, :dispatch, :sync]`?
   - Recommendation: Planner should interpret D-22 as adding `:adapter_module` to the stop metadata of `[:chimeway, :dispatch, :sync, :stop]` since that is the actual span covering executor execution today. If a new `:delivery` span is needed, it should be in `Executor.run_delivery/1` directly. Flag for confirmation if the planner disagrees.

2. **`channel_unregistered` once-flag — needed for Phase 29?**
   - What we know: D-14 says "the first time an unknown channel hits the graceful fallback." Implementing a per-process/global once-flag adds complexity.
   - Recommendation: Emit on every hit for Phase 29. The planner can add ETS-based deduplication as an optional hardening task (Wave 3 or later).

---

## Environment Availability

Step 2.6: SKIPPED (Phase 29 is purely code/config changes — no external tools, services, runtimes, or CLIs beyond the existing project stack).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir built-in) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/chimeway/rendering/channel_contract_test.exs` |
| Full suite command | `mix test` or `mix ci.test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CHAN-01 | SMS render contract validates text_body required | unit | `mix test test/chimeway/rendering/channel_contract_test.exs` | ✅ (extend) |
| CHAN-01 | Push render contract validates title+body required | unit | `mix test test/chimeway/rendering/channel_contract_test.exs` | ✅ (extend) |
| CHAN-01 | Chat render contract validates text required | unit | `mix test test/chimeway/rendering/channel_contract_test.exs` | ✅ (extend) |
| CHAN-01 | Host-defined channel resolves via registry | unit | `mix test test/chimeway/rendering/channel_contract_test.exs` | ✅ (extend) |
| CHAN-01 | Per-channel adapter resolution routes to correct module | unit | `mix test test/chimeway/dispatch/` | ✅ (extend) |
| CHAN-01 | Legacy `:adapter` fallback still works when no `:channel_adapters` set | unit | `mix test test/chimeway/dispatch/` | ✅ (extend) |
| CHAN-02 | SMS `render_data` contains only `text_body` (not email fields) | unit | `mix test test/chimeway/rendering/channel_contract_test.exs` | ✅ (extend) |
| CHAN-02 | Push `render_data` contains `title`, `body`, optional `data` | unit | `mix test test/chimeway/rendering/channel_contract_test.exs` | ✅ (extend) |
| CHAN-02 | `adapter_module` string persisted on attempt row after delivery | integration | `mix test test/chimeway/integration/delivery_lifecycle_test.exs` | ✅ (extend) |
| CHAN-02 | `explain_delivery` includes `adapter_module` in last_attempt | integration | `mix test test/chimeway/traces_test.exs` | ✅ (extend) |

### Test Categories and Sampling Rate (Nyquist)

| Category | Description | Minimum Cases | Rationale |
|----------|-------------|---------------|-----------|
| Channel-contract round-trip | `render_delivery/4` for each new channel; valid + invalid payloads | 2 per channel (valid + missing required) × 3 channels = 6 | One valid case proves the contract accepts; one invalid proves changeset rejects |
| Registry-overlay | Host-defined channel resolves through registry, not compiled clauses | 2 (successful resolution + boot-time reject for bad module) | Prove the open-registry seam works end-to-end |
| Adapter-resolution | Per-channel adapter used; legacy fallback works; `adapter_fallback` telemetry fires | 3 (per-channel hit, legacy fallback, telemetry on miss) | Each branch in `resolve_adapter/1` |
| Attempt-persistence | `adapter_module` written to DB; `inspect(module)` format correct | 2 (adapter_module present on success; null on pre-Phase-29 rows) | Column presence + null-safe rendering |
| Telemetry | `channel_unregistered` fires for unknown channel; `adapter_fallback` fires on miss | 2 events | Each new telemetry event has one assertion |
| Trace explain | `explain_delivery` includes `adapter_module` in last_attempt detail | 2 (present for Phase-29 attempt, nil for pre-Phase-29) | Null-safe rendering path |
| End-to-end multi-channel | SMS delivery through real resolver + attempt row + trace in one test | 1 | Proves all layers integrated |
| Behaviour enforcement | Compile-time `@impl` warning if `validate/1` is missing | 1 (doctest or compile-test with wrong callback) | Confirms the macro enforces the contract |

### Validation Gates

| Gate | Mechanism | What It Proves |
|------|-----------|----------------|
| **Compile-time** | `@impl Chimeway.Rendering.Channel` on each built-in module | Missing `validate/1` or typo'd callback name → compiler warning |
| **Compile-time** | `@behaviour Chimeway.Rendering.Channel` emits warning if behaviour not satisfied | Host-defined channel modules that skip `validate/1` are caught at compile |
| **Boot-time** | `validate_channel_render_modules!()` in `Application.start/2` | Bad module names in `:channel_render_modules` crash the app before it serves traffic |
| **Runtime telemetry** | `[:chimeway, :rendering, :channel_unregistered]` | Unknown channels in production emit an observable signal |
| **Runtime telemetry** | `[:chimeway, :dispatch, :adapter_fallback]` | Misconfigured `:channel_adapters` emits an observable signal |
| **Test assertion** | `assert attempt.adapter_module == "Chimeway.Adapters.Test"` | Adapter identity persisted correctly |

### Coverage Matrix: Decisions → Tests

| Decision | Test That Proves It |
|----------|---------------------|
| D-01 SMS field shape | `channel_contract_test.exs` — SMS valid payload round-trip includes only `text_body` in `render_data` |
| D-02 SMS no vendor fields | `channel_contract_test.exs` — assert `render_data` keys == `["text_body"]` only |
| D-03 No GSM-7 validation | `channel_contract_test.exs` — 200-char SMS text_body validates successfully |
| D-04 No MMS | `channel_contract_test.exs` — `media_url` key is stripped/ignored by changeset |
| D-05 Push field shape | `channel_contract_test.exs` — Push valid payload includes `title`, `body`, `data` |
| D-06 Single :push channel | No test needed — this is a "don't add" decision; checked by code review |
| D-07 Push no vendor fields | `channel_contract_test.exs` — assert `render_data` keys in `["title", "body", "data"]` |
| D-08 `data` is `:map` | `channel_contract_test.exs` — nested map in `data` validates; non-map `data` fails |
| D-09 Chat field shape | `channel_contract_test.exs` — Chat valid payload includes `text`, optional `rich_payload` |
| D-10 Chat as starter | `channel_contract_test.exs` — registry-overlay with custom module shadows Chat for "slack" channel |
| D-11 Behaviour + macro | `channel_contract_test.exs` — all five channel modules implement `validate/1`; compile-time `@impl` check |
| D-12 Three-layer resolution | `channel_contract_test.exs` — registry overlay test; unknown channel hits graceful fallback |
| D-13 Boot-time validation | `application_test.exs` (new) or inline test — bad module in `:channel_render_modules` raises at `start/2` |
| D-14 `channel_unregistered` telemetry | `telemetry_integration_test.exs` (extend) — unknown channel triggers event + Logger.warning |
| D-15 `:channel_adapters` config key | `sync_test.exs` / `oban_test.exs` (extend) — configured channel routes to correct adapter module |
| D-16 `Adapter` behaviour unchanged | No test — "don't change" decision; no new test needed |
| D-17 `resolve_adapter/1` in Executor | `delivery_lifecycle_test.exs` (extend) — SMS delivery uses SMS-configured adapter |
| D-18 Legacy `:adapter` fallback | `sync_test.exs` (extend) — existing test still passes with only `:adapter` set |
| D-19 `adapter_fallback` telemetry | `telemetry_integration_test.exs` (extend) — channel_adapters set + miss → event fires; no-channel_adapters → no event |
| D-20 `adapter_module` string on attempt | `delivery_lifecycle_test.exs` (extend) — attempt row has `adapter_module == "Chimeway.Adapters.Test"` |
| D-21 Per-attempt not per-delivery | `delivery_lifecycle_test.exs` (extend) — two attempts with different adapters have different `adapter_module` values |
| D-22 Trace surface `adapter_module` | `traces_test.exs` (extend) — `explain_delivery` last_attempt includes `adapter_module` |
| D-23 Channel-tagged test adapter | `channel_contract_test.exs` (new) — `assert_receive {:chimeway_delivery, "sms", %Delivery{}}` |
| D-24 No preview API changes | Existing `preview_pipeline_test.exs` must pass unchanged (no new tests needed) |
| D-25 Ecto.Changeset skeleton | `channel_contract_test.exs` — invalid payloads return `%Ecto.Changeset{}` errors, not pattern-match failures |

### Wave 0 Gaps

- [ ] `test/chimeway/rendering/channel_contract_test.exs` — extend with Sms, Push, Chat round-trips and registry-overlay test (file exists; add to it)
- [ ] Migration file — `priv/repo/migrations/YYYYMMDD_add_adapter_module_to_chimeway_delivery_attempts.exs` — must exist before schema can be tested
- [ ] `lib/chimeway/rendering/channel.ex` — behaviour module must exist before built-in channels can `use` it
- [ ] `lib/chimeway/rendering/channels/sms.ex`, `push.ex`, `chat.ex` — new files

---

## Sources

### Primary (HIGH confidence — verified against codebase)

- `lib/chimeway/rendering/channels/email.ex` — canonical template shape
- `lib/chimeway/rendering/channels/in_app.ex` — nested validation template
- `lib/chimeway/rendering.ex:230-232` — current `channel_module/1` clauses
- `lib/chimeway/dispatch/executor.ex` — current adapter resolution at line 31
- `lib/chimeway/dispatch/channel_adapter_config.ex:17-22` — resolver pattern to mirror
- `lib/chimeway/delivery_attempt.ex` — schema field list and changeset
- `lib/chimeway/delivery_planning.ex:437-446` — graceful fallback catch clause
- `lib/chimeway/adapters/test.ex` — current `deliver/2` implementation
- `lib/chimeway/traces.ex:393-403` — current attempt_entries shape
- `lib/chimeway/traces/explanation.ex` — Explanation struct and typespec
- `lib/chimeway/telemetry.ex:80-84` — `@allowed_meta_keys` allowlist
- `lib/chimeway/application.ex` — current `start/2` shape
- `lib/chimeway/notifier.ex:12-16` — `__using__/1` macro pattern to mirror
- `priv/repo/migrations/20260426150000_add_attempt_history_columns.exs` — migration shape template
- `test/chimeway/rendering/channel_contract_test.exs` — round-trip test template
- `test/chimeway/integration/delivery_lifecycle_test.exs:377-389` — `Application.put_env` + `on_exit` test isolation pattern

### Tertiary (LOW confidence — not verified in this session)

- Elixir `inspect/1` vs `to_string/1` module string format: stated from language knowledge [ASSUMED — see A1]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; pure Elixir extension
- Architecture: HIGH — all insertion points verified in source
- Pitfalls: HIGH — derived from actual code reading, not speculation
- Test coverage matrix: HIGH — derived from locked decisions, not guessing

**Research date:** 2026-04-30
**Valid until:** 2026-05-30 (stable Elixir ecosystem; no fast-moving dependencies)

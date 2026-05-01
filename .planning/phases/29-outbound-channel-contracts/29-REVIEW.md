---
phase: 29-outbound-channel-contracts
reviewed: 2026-04-30T12:00:00Z
depth: standard
files_reviewed: 25
files_reviewed_list:
  - lib/chimeway/rendering/channel.ex
  - lib/chimeway/rendering/channels/sms.ex
  - lib/chimeway/rendering/channels/push.ex
  - lib/chimeway/rendering/channels/chat.ex
  - lib/chimeway/rendering/channels/email.ex
  - lib/chimeway/rendering/channels/in_app.ex
  - lib/chimeway/delivery_attempt.ex
  - priv/repo/migrations/20260430120000_add_adapter_module_to_chimeway_delivery_attempts.exs
  - lib/chimeway/rendering.ex
  - lib/chimeway/application.ex
  - lib/chimeway/telemetry.ex
  - lib/chimeway/dispatch/executor.ex
  - lib/chimeway/dispatch/sync.ex
  - lib/chimeway/traces.ex
  - lib/chimeway/traces/explanation.ex
  - lib/chimeway/adapters/test.ex
  - test/chimeway/adapters/test_adapter_test.exs
  - test/chimeway/application_validation_test.exs
  - test/chimeway/dispatch/executor_adapter_resolution_test.exs
  - test/chimeway/integration/delivery_lifecycle_test.exs
  - test/chimeway/rendering/channel_behaviour_test.exs
  - test/chimeway/rendering/channel_contract_test.exs
  - test/chimeway/rendering/channels/sms_push_chat_validators_test.exs
  - test/chimeway/rendering/preview_pipeline_test.exs
  - test/chimeway/telemetry_integration_test.exs
findings:
  blocker: 1
  warning: 6
  info: 5
  total: 12
status: issues_found
---

# Phase 29: Code Review Report

**Reviewed:** 2026-04-30T12:00:00Z
**Depth:** standard
**Files Reviewed:** 25
**Status:** issues_found

## Summary

Phase 29 implementation broadly meets the spec — atom-table safety is preserved
(no `String.to_atom` on user input; telemetry uses `String.to_existing_atom`
with rescue), the once-flag suppression mechanism for unregistered-channel
telemetry works as designed, the migration is backwards-compatible (nullable
`adapter_module` column), pre-Phase-29 nil rows are handled in `Traces`, and
the elevated `validate_channel_render_modules!/0` is read-only and safe to call
externally.

However, the review surfaced **one BLOCKER** centered on misleading executor
documentation that contradicts both the implementation and tests, and creates
a real risk that future readers will register `:channel_adapters` with atom
keys (matching the comment) and silently break per-channel routing in
production. Several WARNING-level concerns target unbounded `:persistent_term`
growth, dispatcher metric conflation of failure outcomes, semantic ambiguity
of empty-map config, and significant code duplication across the five built-in
channel validators.

## Blocker Issues

### CR-01: Misleading executor comment contradicts implementation; risks runtime mis-routing in host configs

**File:** `lib/chimeway/dispatch/executor.ex:74-76`

**Issue:** The comment block above `resolve_adapter/1` reads:

> T-29-15/T-29-18: `:channel_adapters` values come from compile-time config atoms;
> the runtime channel string is used only for `Map.get/2` against pre-existing
> atom keys, never via `String.to_atom` — atom-table-safe.

The phrase "Map.get/2 against pre-existing **atom keys**" is wrong. The
implementation calls `Map.get(channel_adapters, channel)` where `channel` is
always a binary (the function head guards `when is_binary(channel)`), and the
test fixtures explicitly populate the registry with **string keys** —
`%{"sms_custom" => Mod}`, `%{"sms" => Mod}` (see
`test/chimeway/dispatch/executor_adapter_resolution_test.exs:57-58, 87-89` and
`test/chimeway/telemetry_integration_test.exs:238`).

A host operator who reads this comment and follows it — e.g. configures
`config :chimeway, :channel_adapters, %{email: MyAdapter, sms: MyOtherAdapter}` —
will get **silent fallback to the legacy `:adapter`** for every delivery
because `Map.get(map, "email")` returns nil when the key is `:email`. There is
no boot-time validation of `:channel_adapters` keys (unlike `:channel_render_modules`,
which `Application.validate_channel_render_modules!/0` validates at boot for
module shape — but neither registry validates key types).

This is BLOCKER-class because:
1. The library ships with this misleading documentation public-facing.
2. The atom-keyed configuration form is the intuitive Elixir idiom.
3. Failure mode is silent — the system "works" by falling back to `:adapter`,
   so the misconfiguration is only visible by inspecting per-attempt
   `adapter_module` rows.
4. The D-19 `adapter_fallback` telemetry will fire on every miss, which
   masquerades as expected behavior unless the operator notices that *every*
   delivery is firing it.

**Fix:** Either (a) accept atom keys with stringification at lookup time, or
(b) keep string-only keys and fix the comment + add boot validation.

Recommended fix (b) — string-only keys, no runtime conversion:

```elixir
# In Application.start/2, alongside validate_channel_render_modules!/0:
defp validate_channel_adapters! do
  registry = Application.get_env(:chimeway, :channel_adapters, %{})

  Enum.each(registry, fn {channel, module} ->
    unless is_binary(channel) do
      raise ArgumentError,
            "[chimeway] :channel_adapters keys must be strings (got #{inspect(channel)}). " <>
              "Channel identity is persisted as a string on the delivery row; " <>
              "configure with %{\"email\" => MyAdapter}, not %{email: MyAdapter}."
    end

    unless is_atom(module) and Code.ensure_loaded?(module) and
             function_exported?(module, :deliver, 2) do
      raise ArgumentError,
            "[chimeway] :channel_adapters[#{inspect(channel)}] must be a loaded " <>
              "module exporting deliver/2; got #{inspect(module)}"
    end
  end)
end
```

And rewrite the comment in `executor.ex:74-76`:

```elixir
# T-29-15/T-29-18: :channel_adapters keys are validated at boot to be binary
# strings matching delivery.channel; values are loaded modules exporting
# deliver/2. Map.get/2 against the binary `channel` is a direct lookup —
# no String.to_atom or runtime atom creation, atom-table-safe.
```

## Warnings

### WR-01: Unbounded `:persistent_term` growth from `channel_module/1` once-flag

**File:** `lib/chimeway/rendering.ex:245, 257`

**Issue:** Each unique unregistered channel string creates a new
`:persistent_term` entry that lives for the BEAM's lifetime. Every
`:persistent_term.put/2` triggers a global GC across all processes that
reference persistent terms — `:persistent_term`'s own documentation flags
this as the major caveat.

While `channel` strings are bounded by notifier authors, a buggy notifier
that constructs channels dynamically (e.g. `"slack_#{tenant_id}"`) will leak
one persistent_term entry per distinct channel string forever, with each
new entry triggering a global GC. This is a slow-burn memory & latency
problem in long-running production BEAMs.

**Fix:** Use a `:persistent_term` flag with a fixed key, plus an ETS table
or `:atomics` set for the per-channel "already logged" tracking. Or accept
the unbounded growth and document it as a known limitation in the
moduledoc:

```elixir
# Option 1 — single persistent_term flag, ETS table for per-channel state:
defp channel_module(channel) do
  case Application.get_env(:chimeway, :channel_render_modules, %{}) |> Map.get(channel) do
    nil ->
      maybe_log_unregistered(channel)
      {:error, {:unsupported_render_channel, channel}}
    module ->
      {:ok, module}
  end
end

# Where maybe_log_unregistered/1 uses a named ETS table created at boot.
```

Alternatively, document the growth bound in the moduledoc so operators know
the tradeoff: each unique channel string consumes one persistent_term entry
permanently and triggers a global GC on first emission.

### WR-02: Dispatcher telemetry conflates :rejected and :bounced as :failed

**File:** `lib/chimeway/dispatch/sync.ex:97`

**Issue:**

```elixir
outcome = if match?({:ok, _}, result), do: :succeeded, else: :failed
```

The executor classifies adapter results into 4 distinct outcomes:
`:succeeded`, `:failed`, `:rejected`, `:bounced` (see
`executor.ex:52-55`). The sync dispatcher's stop-meta `outcome` collapses
all three error variants to `:failed`, **losing the bounced/permanent vs
temporary distinction in the `[:chimeway, :dispatch, :sync, :stop]`
telemetry**.

Operators relying on this telemetry to alert on bounces will get false
"failed" counts that include both transient and terminal outcomes. The
attempt row preserves correct classification, but the dispatch-level
metric does not.

**Fix:** Read the actual outcome from the attempt struct (already
threaded back as part of D-22):

```elixir
defp do_dispatch(delivery) do
  case Executor.run_delivery(delivery) do
    {:ok, %{delivery: updated_delivery, attempt: attempt}} ->
      {{:ok, updated_delivery}, attempt.adapter_module, attempt.outcome}
    # ... etc
  end
end

# In do_dispatch_with_telemetry:
{result, adapter_module, attempt_outcome} = do_dispatch(delivery)
outcome = attempt_outcome || (if match?({:ok, _}, result), do: :succeeded, else: :failed)
```

### WR-03: `:channel_adapters` empty-map vs unset config behave identically (D-19 spec ambiguity)

**File:** `lib/chimeway/dispatch/executor.ex:78, 84`

**Issue:** D-19 says `adapter_fallback` telemetry fires "ONLY when
`:channel_adapters` is explicitly configured AND the lookup misses." The
implementation uses `map_size(channel_adapters) > 0` as the gate. This
collapses two distinct configuration states into one behavior:

1. `Application.get_env(:chimeway, :channel_adapters)` returns `nil` (unset)
2. `Application.put_env(:chimeway, :channel_adapters, %{})` returns `%{}` (set, empty)

Both produce silent fallback, but (2) is "explicitly configured" by a
strict reading of D-19. An operator who sets it to `%{}` to "explicitly
opt out of per-channel routing" will get no telemetry signal, contrary
to spec.

**Fix:** Use `Application.fetch_env/2` to disambiguate:

```elixir
defp resolve_adapter(channel) when is_binary(channel) do
  case Application.fetch_env(:chimeway, :channel_adapters) do
    {:ok, channel_adapters} when is_map(channel_adapters) ->
      case Map.get(channel_adapters, channel) do
        nil ->
          fallback = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
          # D-19: explicit configuration with miss — emit telemetry.
          :telemetry.execute(
            [:chimeway, :dispatch, :adapter_fallback],
            %{count: 1},
            %{channel: channel, fallback_module: inspect(fallback)}
          )
          fallback

        adapter_module ->
          adapter_module
      end

    :error ->
      Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
  end
end
```

Or document the current behavior explicitly: "an empty map is treated as
unset for the purpose of D-19 telemetry suppression."

### WR-04: `:channel_adapters` registry has no boot-time validation (parity gap with `:channel_render_modules`)

**File:** `lib/chimeway/application.ex:41`

**Issue:** `validate_channel_render_modules!/0` validates the
render-module registry at boot (D-13). There is no equivalent for
`:channel_adapters` — invalid module references, non-loadable modules, or
modules without `deliver/2` will only fail at delivery time, producing a
runtime crash mid-dispatch with an opaque `UndefinedFunctionError`
instead of a clear boot-time failure.

This is a parity gap that compounds CR-01: the misleading-comment risk in
the executor would be caught at boot if there were boot validation.

**Fix:** Add the symmetric validator (see CR-01 fix snippet) and call it
from `Application.start/2`:

```elixir
def start(_type, _args) do
  validate_channel_render_modules!()
  validate_channel_adapters!()
  # ...
end
```

### WR-05: Race between `:persistent_term.get` and `:persistent_term.put` allows duplicate telemetry

**File:** `lib/chimeway/rendering.ex:245-257`

**Issue:** The once-flag check is non-atomic:

```elixir
unless :persistent_term.get({:chimeway_channel_unregistered_logged, channel}, false) do
  :telemetry.execute(...)
  Logger.warning(...)
  :persistent_term.put({:chimeway_channel_unregistered_logged, channel}, true)
end
```

Two processes calling `render_delivery/4` concurrently with the same
unregistered channel can both pass the `get` check before either calls
`put`. Result: telemetry + logger fire 2-N times. The contract test at
`channel_contract_test.exs:147-183` runs sequentially and won't catch
this; high-concurrency production traffic might.

This is a WARNING (not BLOCKER) because it's a "log/telemetry fires N
times instead of 1" issue, not a correctness defect. T-29-12/T-29-14
once-flag suppression intent is satisfied for the steady state — only
the initial burst is at risk.

**Fix:** If strict once-only semantics are required, gate via an
ETS-backed mutex or `:atomics.compare_exchange/4`. Otherwise, document
this as best-effort and add a comment:

```elixir
# Note: get/put is non-atomic. Under concurrent first-hits with the same
# channel string, the once-flag may produce 2-N emissions in the burst
# window; subsequent calls are silent. This is acceptable for the
# T-29-14 use case (operator notification, not exactly-once metric).
```

### WR-06: `Map.get(declaration, :assigns, Map.get(declaration, "assigns"))` evaluates fallback even when first key is present

**File:** `lib/chimeway/rendering.ex:43, 45, 151, 152`

**Issue:** Pattern `Map.get(map, :atom_key, Map.get(map, "string_key"))`
always evaluates the second `Map.get/2` call regardless of whether the
atom key exists. For a typical declaration map, this means double-walking
the map. Not a correctness bug, but a sloppy pattern that obscures
intent and adds work.

The bigger concern: if `Map.get(map, :assigns)` returns the legitimate
value `nil` (host explicitly set `assigns: nil`), the second `Map.get`
silently overrides with the string-keyed value. This is *semantically
identical to current behavior in most cases* but creates a non-obvious
override path.

**Fix:**

```elixir
defp fetch_assigns(declaration) do
  case Map.fetch(declaration, :assigns) do
    {:ok, value} -> value
    :error -> Map.get(declaration, "assigns")
  end
end
```

Apply at lines 43, 45, 151, 152.

## Info

### IN-01: Significant duplication across the five built-in channel validators

**File:** `lib/chimeway/rendering/channels/{email,in_app,sms,push,chat}.ex`

**Issue:** All five built-in channel modules implement near-identical
boilerplate:

- `cast(attrs, Map.keys(@types))`
- `validate_required(@required_fields)`
- `apply_action(:insert)` + `case` for `{:ok, validated} -> stringify_keys(...)`
- A duplicated `defp stringify_keys/1` in each module
- A duplicated non-map `validate(other)` clause that wraps non-map input

This is ~25-40 lines of duplication × 5 modules. The
`Chimeway.Rendering.Channel.__using__/1` macro currently injects only
`@behaviour`. Extracting the cast+validate+stringify pattern into the
macro would let each channel module declare only `@types` and
`@required_fields`.

**Fix:** Enrich the `__using__/1` macro:

```elixir
defmacro __using__(_opts) do
  quote do
    @behaviour Chimeway.Rendering.Channel

    import Ecto.Changeset

    @impl Chimeway.Rendering.Channel
    @spec validate(map()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
    def validate(attrs) when is_map(attrs) do
      types = __types__()
      required = __required_fields__()

      {%{}, types}
      |> cast(attrs, Map.keys(types))
      |> validate_required(required)
      |> validate_extra()
      |> apply_action(:insert)
      |> case do
        {:ok, validated} -> {:ok, Chimeway.Rendering.Channel.stringify_keys(validated)}
        {:error, changeset} -> {:error, changeset}
      end
    end

    def validate(other) do
      Chimeway.Rendering.Channel.invalid_payload_changeset(other)
    end

    # Default no-op extra validation; override in channel modules that need it.
    defp validate_extra(changeset), do: changeset

    defoverridable validate: 1, validate_extra: 1
  end
end
```

This is post-MVP polish — the current shape works correctly, just at
maintenance cost.

### IN-02: `validate(other)` non-map clause uses `add_error` after `cast` already errored

**File:** `lib/chimeway/rendering/channels/email.ex:31-37` (and Sms, Push, Chat, InApp equivalents)

**Issue:**

```elixir
def validate(other) do
  types = %{payload: :map}

  {%{}, types}
  |> cast(%{payload: other}, [:payload])
  |> add_error(:payload, "must be a map")
  |> apply_action(:insert)
end
```

`cast(%{payload: :not_a_map}, [:payload])` for type `:map` already produces
a cast error. The subsequent `add_error` adds a duplicate error message.
The resulting changeset has two errors on `:payload`. Functionally fine,
but redundant.

**Fix:** Either drop `add_error` (cast error is sufficient) or skip cast
entirely:

```elixir
def validate(other) do
  changeset = %{
    types: %{payload: :map},
    data: %{},
    valid?: false,
    errors: [payload: {"must be a map", [validation: :type, type: :map, got: other]}]
  }
  {:error, struct!(Ecto.Changeset, changeset)}
end
```

### IN-03: `inspect(adapter)` persistence depends on default Inspect behavior

**File:** `lib/chimeway/dispatch/executor.ex:45`

**Issue:** D-20 specifies adapter_module is persisted as `inspect/1` so
the value omits the "Elixir." prefix. The current implementation calls
`inspect(adapter)` directly; if a host or library globally overrides
`Inspect.Atom` (rare but possible), the persisted value silently changes
shape, breaking analytics queries that look for specific module strings.

**Fix:** Use the explicit `Atom.to_string/1` + prefix-strip:

```elixir
defp module_to_persisted_string(module) when is_atom(module) do
  case Atom.to_string(module) do
    "Elixir." <> rest -> rest
    other -> other
  end
end

# At call site:
adapter_module: module_to_persisted_string(adapter)
```

Equivalent output, deterministic, doesn't depend on `Inspect`.

### IN-04: Test `defmodule` declarations inside `describe` blocks shadow outer scope

**File:** `test/chimeway/rendering/channel_behaviour_test.exs:32`

**Issue:** `defmodule HostChannel do ... end` inside a `describe` block
defines a top-level module
`Chimeway.Rendering.ChannelBehaviourTest.HostChannel` (since it's
nested inside the test module's lexical scope). This works but is
unusual — the module persists for the lifetime of the test process and
is visible to every other test in the file. If two tests both define
`HostChannel` (none currently do, but a future PR could), the second
re-defines and silently shadows the first.

**Fix:** Suffix the module name with the describe block to make
collisions visible:

```elixir
describe "use Chimeway.Rendering.Channel" do
  defmodule HostChannelUseBlock do
    # ...
  end
end
```

### IN-05: `dispatched.channel` vs `delivery.channel` mixed in executor

**File:** `lib/chimeway/dispatch/executor.ex:32-33`

**Issue:**

```elixir
adapter = resolve_adapter(dispatched.channel)
adapter_config = ChannelAdapterConfig.resolve(delivery.channel, [])
```

`adapter` resolves against the post-transition `dispatched` struct;
`adapter_config` resolves against the pre-transition `delivery` struct.
For all current code paths these are identical (transition_status doesn't
change `:channel`), but the inconsistent variable choice obscures intent
and would mask a future bug if a transition function ever did mutate
channel.

**Fix:** Use the same struct in both calls:

```elixir
adapter = resolve_adapter(dispatched.channel)
adapter_config = ChannelAdapterConfig.resolve(dispatched.channel, [])
```

---

_Reviewed: 2026-04-30T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

---
phase: 29-outbound-channel-contracts
plan: "04"
type: execute
wave: 3
depends_on:
  - "01"
  - "03"
files_modified:
  - lib/chimeway/rendering.ex
  - lib/chimeway/application.ex
  - lib/chimeway/telemetry.ex
autonomous: true
requirements:
  - CHAN-01
  - CHAN-02

must_haves:
  truths:
    - "channel_module/1 resolves sms/push/chat to the new compiled clauses"
    - "channel_module/1 resolves host-configured channels via :channel_render_modules registry"
    - "Unknown channels trigger [:chimeway, :rendering, :channel_unregistered] telemetry + Logger.warning on first hit per channel per BEAM lifetime"
    - "Boot validation rejects typo'd module names in :channel_render_modules before the app serves traffic"
    - "adapter_module key passes through the telemetry safe_meta/1 allowlist"
  artifacts:
    - path: "lib/chimeway/rendering.ex"
      provides: "Three-layer channel_module/1 resolution with persistent_term once-flag"
      contains: "channel_unregistered"
    - path: "lib/chimeway/application.ex"
      provides: "validate_channel_render_modules!/0 boot guard"
      contains: "validate_channel_render_modules"
    - path: "lib/chimeway/telemetry.ex"
      provides: "adapter_module in @allowed_meta_keys"
      contains: "adapter_module"
  key_links:
    - from: "lib/chimeway/rendering.ex"
      to: "Application.get_env(:chimeway, :channel_render_modules, %{})"
      via: "Map.get registry lookup in channel_module/1"
      pattern: "channel_render_modules"
    - from: "lib/chimeway/application.ex"
      to: "validate_channel_render_modules!"
      via: "called at top of start/2 before Supervisor.start_link"
      pattern: "validate_channel_render_modules!"
---

<objective>
Extend `Chimeway.Rendering.channel_module/1` from two compiled clauses to the full
three-layer resolution chain (registry → compiled → graceful fallback with telemetry),
add the boot-time registry validation in `Application.start/2`, and extend the
telemetry `@allowed_meta_keys` allowlist with `:adapter_module` (D-12, D-13, D-14, D-22).

Purpose: Makes the channel-render-module registry seam public and validated. Host apps
can configure `:channel_render_modules` in `config.exs`; unknown channels emit an
observable telemetry signal (once per channel per BEAM lifetime, using a `:persistent_term`
once-flag) instead of silently producing empty render_data. Plan 04 runs in Wave 3
(after Plan 03) because it aliases Sms/Push/Chat modules that Plan 03 creates — aliasing
a non-existent module prevents compilation.

Output: Three-layer channel_module/1 in rendering.ex, boot guard in application.ex,
adapter_module in telemetry allowlist.
</objective>

<execution_context>
@/Users/jon/.claude/get-shit-done/workflows/execute-plan.md
@/Users/jon/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/ROADMAP.md
@.planning/phases/29-outbound-channel-contracts/29-CONTEXT.md
@.planning/phases/29-outbound-channel-contracts/29-RESEARCH.md
@.planning/phases/29-outbound-channel-contracts/29-PATTERNS.md

<interfaces>
<!-- Key insertion points from codebase. -->

From lib/chimeway/rendering.ex (current channel_module/1 clauses, lines 230-232):
```elixir
defp channel_module("in_app"), do: {:ok, InApp}
defp channel_module("email"), do: {:ok, Email}
defp channel_module(channel), do: {:error, {:unsupported_render_channel, channel}}
```

From lib/chimeway/rendering.ex (current alias line 6):
```elixir
alias Chimeway.Rendering.Channels.{Email, InApp}
```

From lib/chimeway/application.ex (current start/2, lines 8-19):
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

defp oban_child do
  if Code.ensure_loaded?(Oban) do
    case Application.get_env(:chimeway, Oban) do
      nil -> []
      config -> [{Oban, config}]
    end
  else
    []
  end
end
```

From lib/chimeway/telemetry.ex (@allowed_meta_keys, lines 80-84):
```elixir
@allowed_meta_keys ~w(
  notification_key event_id recipient_id channel
  delivery_id attempt_id outcome suppression_reason correlation_id
  attempt_number error_class
)a
```

From lib/chimeway/notifier.ex (validate_module! pattern for Code.ensure_loaded? + function_exported?):
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
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Extend channel_module/1 with three-layer resolution + persistent_term once-flag</name>
  <files>lib/chimeway/rendering.ex</files>
  <read_first>
    - lib/chimeway/rendering.ex — read the full file before editing; need exact line positions of the alias block and channel_module/1 function clauses; note whether `require Logger` already exists
    - lib/chimeway/dispatch/channel_adapter_config.ex — the string-safe Map.get resolver pattern to mirror for the registry lookup
  </read_first>
  <behavior>
    - channel_module("email") returns {:ok, Email} (compiled clause, unchanged)
    - channel_module("in_app") returns {:ok, InApp} (compiled clause, unchanged)
    - channel_module("sms") returns {:ok, Chimeway.Rendering.Channels.Sms}
    - channel_module("push") returns {:ok, Chimeway.Rendering.Channels.Push}
    - channel_module("chat") returns {:ok, Chimeway.Rendering.Channels.Chat}
    - channel_module("slack") with :channel_render_modules configured to %{"slack" => MySlack} returns {:ok, MySlack}
    - channel_module("unknown_xyz") with no registry entry emits [:chimeway, :rendering, :channel_unregistered] telemetry with %{channel: "unknown_xyz"} metadata on the FIRST call AND returns {:error, {:unsupported_render_channel, "unknown_xyz"}}
    - channel_module("unknown_xyz") on a SECOND call with the same channel does NOT re-emit telemetry (once-per-BEAM-lifetime via :persistent_term)
  </behavior>
  <action>
Make exactly two changes to `lib/chimeway/rendering.ex`:

**Change 1** — Extend the alias line to cover the three new channel modules.

Find the line:
```elixir
alias Chimeway.Rendering.Channels.{Email, InApp}
```

Replace with:
```elixir
alias Chimeway.Rendering.Channels.{Email, InApp, Sms, Push, Chat}
```

**Change 2** — Replace the three existing `channel_module/1` clauses (the two compiled
clauses + the catch-all fallback) with the full three-layer resolution (D-12, D-14).

If `require Logger` is not already present at the top of the module, add it before
the alias block.

Replace the existing:
```elixir
defp channel_module("in_app"), do: {:ok, InApp}
defp channel_module("email"), do: {:ok, Email}
defp channel_module(channel), do: {:error, {:unsupported_render_channel, channel}}
```

With:
```elixir
defp channel_module("email"), do: {:ok, Email}
defp channel_module("in_app"), do: {:ok, InApp}
defp channel_module("sms"), do: {:ok, Sms}
defp channel_module("push"), do: {:ok, Push}
defp channel_module("chat"), do: {:ok, Chat}
defp channel_module(channel) do
  # Layer 1: host-configured registry lookup (D-12)
  case Application.get_env(:chimeway, :channel_render_modules, %{}) |> Map.get(channel) do
    nil ->
      # D-14: emit once per channel per BEAM lifetime using :persistent_term once-flag.
      # Key shape: {:chimeway_channel_unregistered_logged, channel_string}
      # :persistent_term read is constant-time (zero hot-path overhead after first hit).
      unless :persistent_term.get({:chimeway_channel_unregistered_logged, channel}, false) do
        :telemetry.execute(
          [:chimeway, :rendering, :channel_unregistered],
          %{count: 1},
          %{channel: channel}
        )

        Logger.warning(
          "[chimeway] unregistered render channel #{inspect(channel)} hit graceful fallback — " <>
            "render_data will be empty. Configure :channel_render_modules or add a compiled clause."
        )

        :persistent_term.put({:chimeway_channel_unregistered_logged, channel}, true)
      end

      # Layer 3: graceful fallback — delivery_planning.ex catches
      # {:unsupported_render_channel, _} and substitutes render_data: %{}
      {:error, {:unsupported_render_channel, channel}}

    module ->
      {:ok, module}
  end
end
```

Note: The graceful fallback at `delivery_planning.ex:437-446` (the catch-all clause that
produces `render_data: %{}`) is Layer 3 — it is NOT in rendering.ex. rendering.ex returns
`{:error, {:unsupported_render_channel, channel}}` and delivery_planning.ex handles it.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/chimeway && mix test test/chimeway/rendering/channel_contract_test.exs 2>&1 | tail -10</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "channel_render_modules" lib/chimeway/rendering.ex` outputs `1`
    - `grep -c "channel_unregistered" lib/chimeway/rendering.ex` outputs `1`
    - `grep -c "Logger.warning" lib/chimeway/rendering.ex` outputs `1`
    - `grep -c "persistent_term" lib/chimeway/rendering.ex` outputs `2` (get + put)
    - `grep -c "chimeway_channel_unregistered_logged" lib/chimeway/rendering.ex` outputs `2`
    - `grep 'alias Chimeway.Rendering.Channels' lib/chimeway/rendering.ex` contains `Sms, Push, Chat`
    - `grep -c "channel_module(\"sms\")" lib/chimeway/rendering.ex` outputs `1`
    - `grep -c "channel_module(\"push\")" lib/chimeway/rendering.ex` outputs `1`
    - `grep -c "channel_module(\"chat\")" lib/chimeway/rendering.ex` outputs `1`
    - `mix compile` exits 0
    - `mix test test/chimeway/rendering/channel_contract_test.exs` passes
  </acceptance_criteria>
  <done>Three-layer channel_module/1 in rendering.ex; sms/push/chat have compiled clauses; unknown channel triggers telemetry once per BEAM lifetime via :persistent_term</done>
</task>

<task type="auto">
  <name>Task 2: Boot validation + telemetry allowlist extension</name>
  <files>lib/chimeway/application.ex, lib/chimeway/telemetry.ex</files>
  <read_first>
    - lib/chimeway/application.ex — read full file before editing; need exact position of start/2 body to insert validate_channel_render_modules!() call
    - lib/chimeway/telemetry.ex — read the @allowed_meta_keys block (lines 80-84); need the exact current whitespace format to match
    - lib/chimeway/notifier.ex — the Code.ensure_loaded? + function_exported? pattern that validate_channel_render_modules!/0 mirrors
  </read_first>
  <action>
**lib/chimeway/application.ex** (D-13) — two additions:

1. At the very start of `start/2` body, before the `children =` assignment, add:
```elixir
validate_channel_render_modules!()
```

2. Add the private helper function after the existing `oban_child/0` function:
```elixir
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

**lib/chimeway/telemetry.ex** (D-22) — extend `@allowed_meta_keys` by adding `adapter_module`
at the end of the word list:

Before:
```elixir
@allowed_meta_keys ~w(
  notification_key event_id recipient_id channel
  delivery_id attempt_id outcome suppression_reason correlation_id
  attempt_number error_class
)a
```

After:
```elixir
@allowed_meta_keys ~w(
  notification_key event_id recipient_id channel
  delivery_id attempt_id outcome suppression_reason correlation_id
  attempt_number error_class adapter_module
)a
```

The `safe_meta/1` function uses `Map.take(@allowed_meta_keys)` — no other change needed;
it inherits `adapter_module` automatically.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/chimeway && mix compile 2>&1 | grep -E "^(error|warning)" | head -10; mix test test/chimeway/telemetry_integration_test.exs 2>&1 | tail -10</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "validate_channel_render_modules!" lib/chimeway/application.ex` outputs `2` (call site + definition)
    - `grep -c "Code.ensure_loaded?" lib/chimeway/application.ex` outputs `2` (oban_child + new helper)
    - `grep -c "function_exported?" lib/chimeway/application.ex` outputs `1`
    - `grep "allowed_meta_keys" lib/chimeway/telemetry.ex` line contains `adapter_module`
    - `mix compile` exits 0
    - `mix test test/chimeway/telemetry_integration_test.exs` passes (existing telemetry tests unaffected)
  </acceptance_criteria>
  <done>Boot validation guards against typo'd registry modules; adapter_module passes through safe_meta/1 filter</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| config → runtime | :channel_render_modules values cross from config.exs atoms into runtime module resolution |
| unknown channel → fallback | Unknown channel string crosses into graceful fallback path |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-29-11 | Elevation of Privilege | :channel_render_modules arbitrary module | mitigate | D-13: boot validation calls Code.ensure_loaded? AND function_exported?(module, :validate, 1) — only modules with the correct callback can be registered; app crashes loud at boot on typos |
| T-29-12 | Denial of Service | Atom exhaustion from runtime channel strings | mitigate | D-12: registry lookup uses Map.get on config.exs atoms — no String.to_atom anywhere; channel strings stay strings; module atoms come from compile-time config only |
| T-29-13 | Information Disclosure | Logger.warning with channel string | accept | Channel strings (e.g. "slack") are host-app identifiers already in notifier code; logging them at warning level adds no new disclosure beyond what operators can see in source |
| T-29-14 | Spoofing | Fake module in :channel_render_modules | mitigate | D-13 boot guard: Code.ensure_loaded? rejects non-existent modules; function_exported? enforces validate/1 contract; operator must control config.exs to inject a module |
| T-29-14b | Denial of Service | :persistent_term key accumulation from many unknown channels | accept | Keys are keyed by channel string; in practice the set of unknown channels per deployment is small and bounded; :persistent_term has no GC overhead for small fixed sets |
</threat_model>

<verification>
After plan execution:
- `mix compile` exits 0
- `grep -c "validate_channel_render_modules!" lib/chimeway/application.ex` returns `2`
- `grep -c "channel_render_modules" lib/chimeway/rendering.ex` returns `1`
- `grep -c "persistent_term" lib/chimeway/rendering.ex` returns `2`
- `grep "allowed_meta_keys" lib/chimeway/telemetry.ex` contains `adapter_module`
- `mix test test/chimeway/rendering/channel_contract_test.exs` passes
</verification>

<success_criteria>
`channel_module/1` has five compiled clauses plus registry-overlay plus graceful fallback
with telemetry (emitted once per channel per BEAM lifetime via `:persistent_term`).
`Application.start/2` calls `validate_channel_render_modules!/0`.
`@allowed_meta_keys` includes `:adapter_module`. `mix compile` exits 0.
</success_criteria>

<output>
After completion, create `.planning/phases/29-outbound-channel-contracts/29-04-SUMMARY.md`
</output>

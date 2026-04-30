---
phase: 29-outbound-channel-contracts
plan: "05"
type: execute
wave: 3
depends_on:
  - "02"
files_modified:
  - lib/chimeway/dispatch/executor.ex
autonomous: true
requirements:
  - CHAN-01

must_haves:
  truths:
    - "Executor.run_delivery/1 uses resolve_adapter/1 for per-channel adapter lookup"
    - "SMS delivery is routed to the SMS-configured adapter, not the global :adapter"
    - "Legacy :adapter config still works as the fallback when no :channel_adapters is set"
    - "adapter_module is persisted on the attempt row as inspect(module) string"
    - "adapter_fallback telemetry fires when :channel_adapters is set AND lookup misses"
  artifacts:
    - path: "lib/chimeway/dispatch/executor.ex"
      provides: "resolve_adapter/1 private helper + adapter_module in record_attempt attrs"
      contains: "resolve_adapter"
  key_links:
    - from: "lib/chimeway/dispatch/executor.ex"
      to: "Application.get_env(:chimeway, :channel_adapters, %{})"
      via: "resolve_adapter/1"
      pattern: "channel_adapters"
    - from: "lib/chimeway/dispatch/executor.ex"
      to: "Deliveries.record_attempt/2"
      via: "adapter_module: inspect(adapter) in attrs map"
      pattern: "adapter_module: inspect"
---

<objective>
Extend `Chimeway.Dispatch.Executor.run_delivery/1` with per-channel adapter resolution
(`resolve_adapter/1` private helper) and persist the resolved adapter module name on
the attempt row (D-15 through D-21). The `adapter_module` column from Plan 02 must
exist before this plan runs (Wave 3 depends on Wave 1 Plan 02).

Purpose: Satisfies success criterion #3 — "the delivery engine correctly routes payloads
to the specified non-email adapter." Legacy single-`:adapter` configs continue working
unchanged (D-18).

Output: Modified executor.ex with resolve_adapter/1 and adapter_module persistence.
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
<!-- Exact current code shapes in executor.ex and the resolver analog. -->

From lib/chimeway/dispatch/executor.ex (current run_delivery/1, lines 29-44):
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

From lib/chimeway/dispatch/channel_adapter_config.ex (preferred_config/1 pattern, lines 17-22):
```elixir
defp preferred_config(channel) do
  case Application.get_env(:chimeway, :channel_adapter_configs, %{}) do
    configs when is_map(configs) -> Map.get(configs, channel)
    _ -> nil
  end
end
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add resolve_adapter/1 + persist adapter_module on attempt</name>
  <files>lib/chimeway/dispatch/executor.ex</files>
  <read_first>
    - lib/chimeway/dispatch/executor.ex — read the full current file before editing; understand the with-block structure and classify/1 clauses
    - lib/chimeway/dispatch/channel_adapter_config.ex — the preferred_config/1 resolver pattern that resolve_adapter/1 mirrors exactly
  </read_first>
  <behavior>
    - resolve_adapter("email") with only :adapter set returns the :adapter module (legacy fallback)
    - resolve_adapter("sms") with :channel_adapters %{"sms" => MySmsAdapter} returns MySmsAdapter
    - resolve_adapter("email") with :channel_adapters %{"sms" => MySmsAdapter} returns the :adapter fallback AND emits [:chimeway, :dispatch, :adapter_fallback] telemetry
    - resolve_adapter("email") with only :adapter set and NO :channel_adapters emits NO adapter_fallback telemetry (D-19: only when :channel_adapters is explicitly set)
    - Deliveries.record_attempt/2 receives adapter_module: "Chimeway.Adapters.Test" after Test adapter delivery
    - inspect(Chimeway.Adapters.Logger) produces "Chimeway.Adapters.Logger" (no "Elixir." prefix)
  </behavior>
  <action>
Make two changes to `lib/chimeway/dispatch/executor.ex`:

**Change 1** — Replace the `adapter = Application.get_env(...)` line inside `run_delivery/1`
with a call to the new private function, and add `adapter_module: inspect(adapter)` to
the `Deliveries.record_attempt` attrs map:

Replace the body of `run_delivery/1` (the `with` block body) with:
```elixir
def run_delivery(%Delivery{} = delivery) do
  with {:ok, dispatched} <- Deliveries.transition_status(delivery, :dispatched) do
    adapter = resolve_adapter(dispatched.channel)            # D-17: was hardcoded Application.get_env
    adapter_config = ChannelAdapterConfig.resolve(delivery.channel, [])

    {attempt_outcome, error_class, provider_response} =
      dispatched
      |> adapter.deliver(adapter_config)
      |> classify()

    Deliveries.record_attempt(dispatched, %{
      outcome: attempt_outcome,
      error_class: error_class,
      provider_response: provider_response,
      adapter_module: inspect(adapter)                       # D-20: string, never atom
    })
  end
end
```

**Change 2** — Add the `resolve_adapter/1` private function after the existing `classify/1`
clauses (at the end of the module, before the closing `end`):

```elixir
# D-17: Per-channel adapter resolution.
# Resolution order:
#   1. Map.get(:channel_adapters, channel) — explicit per-channel override
#   2. :adapter config — legacy global fallback (D-18: kept unchanged, no deprecation)
#
# D-19: adapter_fallback telemetry fires ONLY when :channel_adapters is explicitly
# configured AND the lookup misses. Silent when only :adapter is configured.
defp resolve_adapter(channel) when is_binary(channel) do
  channel_adapters = Application.get_env(:chimeway, :channel_adapters, %{})

  case Map.get(channel_adapters, channel) do
    nil ->
      fallback = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)

      if map_size(channel_adapters) > 0 do
        :telemetry.execute(
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

Key implementation notes (D-20):
- Use `inspect(adapter)` — produces `"Chimeway.Adapters.Logger"` (no `Elixir.` prefix)
- Do NOT use `to_string(adapter)` — that produces `"Elixir.Chimeway.Adapters.Logger"`
- Atoms exist only in compile-time config; `channel` stays a string throughout; no `String.to_atom`
  </action>
  <verify>
    <automated>cd /Users/jon/projects/chimeway && mix test test/chimeway/integration/delivery_lifecycle_test.exs 2>&1 | tail -15</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "resolve_adapter" lib/chimeway/dispatch/executor.ex` outputs `2` (call site + definition)
    - `grep -c "channel_adapters" lib/chimeway/dispatch/executor.ex` outputs `1`
    - `grep -c "adapter_fallback" lib/chimeway/dispatch/executor.ex` outputs `1`
    - `grep -c "adapter_module: inspect" lib/chimeway/dispatch/executor.ex` outputs `1`
    - `grep "adapter = Application.get_env" lib/chimeway/dispatch/executor.ex` returns empty (old line removed)
    - `mix compile` exits 0
    - `mix test test/chimeway/integration/delivery_lifecycle_test.exs` passes (existing lifecycle tests unaffected — legacy :adapter config still works)
  </acceptance_criteria>
  <done>resolve_adapter/1 exists; adapter_module persisted on attempt; existing delivery_lifecycle tests pass</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| config → executor | :channel_adapters module values cross from config.exs atoms into executor dispatch call |
| executor → DB | adapter_module string (from inspect/1) crosses from runtime into chimeway_delivery_attempts row |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-29-15 | Elevation of Privilege | resolve_adapter loading arbitrary module | mitigate | D-15/D-17: :channel_adapters values come from config.exs compile-time atoms; no String.to_atom or runtime module loading; Map.get returns a pre-existing atom or nil |
| T-29-16 | Tampering | adapter_module column injection | mitigate | D-20: inspect(module) where module is a compile-time atom — operator cannot inject arbitrary strings through the delivery channel field because the lookup is against a static config map |
| T-29-17 | Information Disclosure | adapter_fallback telemetry with fallback_module | accept | Module names are already in host-app source; logging the fallback module in telemetry metadata adds no new disclosure; operators need this to diagnose misconfiguration |
| T-29-18 | Denial of Service | Atom exhaustion from channel string | mitigate | D-17/Phase 11 discipline: channel string stays a string; Map.get lookup against config atom keys; no String.to_atom anywhere in resolve_adapter/1 |
</threat_model>

<verification>
After plan execution:
- `mix compile` exits 0
- `grep -c "resolve_adapter" lib/chimeway/dispatch/executor.ex` returns `2`
- `grep -c "adapter_module: inspect" lib/chimeway/dispatch/executor.ex` returns `1`
- `mix test test/chimeway/integration/delivery_lifecycle_test.exs` passes
</verification>

<success_criteria>
`Executor.run_delivery/1` calls `resolve_adapter(dispatched.channel)` and passes
`adapter_module: inspect(adapter)` to `Deliveries.record_attempt/2`.
`resolve_adapter/1` private function exists with `:channel_adapters` map lookup,
`:adapter` fallback, and conditional `adapter_fallback` telemetry (D-19).
Existing delivery lifecycle tests pass (backwards-compat D-18 preserved).
</success_criteria>

<output>
After completion, create `.planning/phases/29-outbound-channel-contracts/29-05-SUMMARY.md`
</output>

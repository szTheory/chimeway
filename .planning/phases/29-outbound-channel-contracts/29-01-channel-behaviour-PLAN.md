---
phase: 29-outbound-channel-contracts
plan: "01"
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/chimeway/rendering/channel.ex
autonomous: true
requirements:
  - CHAN-01
  - CHAN-02

must_haves:
  truths:
    - "A public module Chimeway.Rendering.Channel exists with a single @callback validate/1"
    - "use Chimeway.Rendering.Channel in any module injects @behaviour Chimeway.Rendering.Channel"
    - "Host-defined channel modules that implement validate/1 with @impl satisfy the behaviour contract"
  artifacts:
    - path: "lib/chimeway/rendering/channel.ex"
      provides: "Public behaviour + __using__ macro for channel render validation"
      exports: ["Chimeway.Rendering.Channel"]
      contains: "@callback validate"
  key_links:
    - from: "lib/chimeway/rendering/channels/email.ex"
      to: "lib/chimeway/rendering/channel.ex"
      via: "use Chimeway.Rendering.Channel"
      pattern: "use Chimeway\\.Rendering\\.Channel"
    - from: "lib/chimeway/rendering/channels/in_app.ex"
      to: "lib/chimeway/rendering/channel.ex"
      via: "use Chimeway.Rendering.Channel"
      pattern: "use Chimeway\\.Rendering\\.Channel"
---

<objective>
Create the public behaviour module `Chimeway.Rendering.Channel` that formalises the
contract all channel-specific render validators must implement, plus a `use` macro
that injects `@behaviour Chimeway.Rendering.Channel` — following the `Chimeway.Notifier`
`__using__/1` convention already in this codebase.

Purpose: Every built-in and host-defined channel render module declares this behaviour
so the Elixir compiler catches missing or misnamed `validate/1` callbacks at compile
time (D-11). This file must be created in Wave 1 because it is a compile-time
dependency of all channel modules created in Wave 2.

Output: `lib/chimeway/rendering/channel.ex` with behaviour + macro.
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
<!-- Analog patterns the executor needs. -->

From lib/chimeway/notifier.ex (behaviour + __using__ macro pattern to mirror):
```elixir
defmacro __using__(_opts) do
  quote do
    @behaviour Chimeway.Notifier
  end
end
```

From lib/chimeway/notifier.ex (validate_module!/1 — Code.ensure_loaded? + function_exported? pattern):
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
  <name>Task 1: Create Chimeway.Rendering.Channel behaviour module</name>
  <files>lib/chimeway/rendering/channel.ex</files>
  <read_first>
    - lib/chimeway/notifier.ex — the exact __using__/1 macro pattern to replicate; lines 12-16 are the template
    - lib/chimeway/rendering/channels/email.ex — the existing channel module to understand the validate/1 contract shape that the new behaviour formalises
  </read_first>
  <behavior>
    - A module with `use Chimeway.Rendering.Channel` satisfies `@behaviour Chimeway.Rendering.Channel`
    - A module that omits `validate/1` and declares `@impl Chimeway.Rendering.Channel` gets a compiler warning
    - The callback signature is exactly: `@callback validate(attrs :: map()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}`
  </behavior>
  <action>
Create `lib/chimeway/rendering/channel.ex` with the following exact content (D-11):

```elixir
defmodule Chimeway.Rendering.Channel do
  @moduledoc """
  Behaviour contract for channel-specific render validation.

  Every channel render validator — built-in or host-defined — must implement
  this behaviour. Declaring `use Chimeway.Rendering.Channel` injects
  `@behaviour Chimeway.Rendering.Channel` so the Elixir compiler issues warnings
  for typo'd or missing `validate/1` implementations.

  ## Usage

      defmodule MyApp.Channels.Slack do
        use Chimeway.Rendering.Channel

        @impl Chimeway.Rendering.Channel
        def validate(attrs) when is_map(attrs) do
          # Ecto.Changeset validation producing a stringified map
          {:ok, attrs}
        end

        def validate(_other) do
          {:error, :invalid}
        end
      end

  ## Contract

  `validate/1` receives the raw render attrs map from the notifier's `rendering/2`
  callback and must return `{:ok, stringified_map}` on success or
  `{:error, %Ecto.Changeset{}}` on validation failure.

  The returned map MUST have string keys (produced by `Atom.to_string/1`) so it
  survives JSONB round-trips and Oban serialization without key-type drift.
  """

  @callback validate(attrs :: map()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Chimeway.Rendering.Channel
    end
  end
end
```
  </action>
  <verify>
    <automated>cd /Users/jon/projects/chimeway && mix compile 2>&1 | grep -v "^$" | head -20</automated>
  </verify>
  <acceptance_criteria>
    - `lib/chimeway/rendering/channel.ex` exists
    - `grep -c "@callback validate" lib/chimeway/rendering/channel.ex` outputs `1`
    - `grep -c "defmacro __using__" lib/chimeway/rendering/channel.ex` outputs `1`
    - `grep -c "@behaviour Chimeway.Rendering.Channel" lib/chimeway/rendering/channel.ex` outputs `1`
    - `mix compile` produces no errors (warnings about unimplemented behaviour in existing channels are expected and will be fixed in Plan 03)
  </acceptance_criteria>
  <done>lib/chimeway/rendering/channel.ex exists with @callback validate/1 and __using__ macro; mix compile succeeds</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| config → compile | Host-app modules referenced in :channel_render_modules config cross from runtime config to compile-time atom space |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-29-01 | Elevation of Privilege | Chimeway.Rendering.Channel __using__ macro | accept | Macro only injects @behaviour — no code executed, no runtime privilege change possible |
| T-29-02 | Tampering | validate/1 callback contract | mitigate | @impl annotation enforces callback name/arity at compile time; typos surface as compiler warnings rather than silent runtime failures |
| T-29-03 | Information Disclosure | @moduledoc examples | accept | Examples show only structural patterns; no secrets, credentials, or PII appear in the behaviour module |
</threat_model>

<verification>
After plan execution:
- `mix compile` exits 0
- `grep -rn "Chimeway.Rendering.Channel" lib/chimeway/rendering/channel.ex` shows both @callback and defmacro
- File is at `lib/chimeway/rendering/channel.ex` (not inside channels/ subdirectory)
</verification>

<success_criteria>
`lib/chimeway/rendering/channel.ex` is a valid compiled Elixir module declaring
`@callback validate(attrs :: map()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}`
and a `__using__/1` macro that injects `@behaviour Chimeway.Rendering.Channel`.
`mix compile` exits 0.
</success_criteria>

<output>
After completion, create `.planning/phases/29-outbound-channel-contracts/29-01-SUMMARY.md`
</output>

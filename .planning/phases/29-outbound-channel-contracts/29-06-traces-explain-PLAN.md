---
phase: 29-outbound-channel-contracts
plan: "06"
type: execute
wave: 4
depends_on:
  - "05"
files_modified:
  - lib/chimeway/traces.ex
  - lib/chimeway/traces/explanation.ex
autonomous: true
requirements:
  - CHAN-01

must_haves:
  truths:
    - "explain_delivery/1 includes adapter_module in the last_attempt map"
    - "explain_delivery/1 includes adapter_module in each attempt_entries detail"
    - "Explanation struct @type includes adapter_module: String.t() | nil in last_attempt"
    - "nil adapter_module on pre-Phase-29 rows is nil in the output (not omitted, not crashed)"
  artifacts:
    - path: "lib/chimeway/traces.ex"
      provides: "adapter_module in build_last_attempt_map/1 and attempt_entries detail"
      contains: "adapter_module"
    - path: "lib/chimeway/traces/explanation.ex"
      provides: "adapter_module in @type t last_attempt map and @moduledoc field list"
      contains: "adapter_module"
  key_links:
    - from: "lib/chimeway/traces.ex"
      to: "lib/chimeway/delivery_attempt.ex"
      via: "attempt.adapter_module read from preloaded attempt struct"
      pattern: "attempt\\.adapter_module"
---

<objective>
Extend `Chimeway.Traces.explain_delivery/1` to include `adapter_module` in both the
`last_attempt` map (via `build_last_attempt_map/1`) and the per-attempt timeline entries
(via the `attempt_entries` Enum.map), plus update the `Explanation` typespec and
`@moduledoc` to document the new field (D-22).

Purpose: Satisfies success criterion #3 — operators can assert "via {adapter_module}"
from trace dumps. Wave 4 (after Plan 05) ensures the DB column exists and executor
writes it before trace code tries to read it.

Output: Two files modified; traces_test.exs can now assert `explanation.last_attempt.adapter_module`.
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
<!-- Exact current code shapes in traces.ex and explanation.ex. -->

From lib/chimeway/traces.ex (build_last_attempt_map/1, lines 275-282):
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

From lib/chimeway/traces.ex (attempt_entries Enum.map, lines 392-403):
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

From lib/chimeway/traces/explanation.ex (last_attempt @type, lines 57-63):
```elixir
last_attempt:
  %{
    outcome: atom(),
    inserted_at: DateTime.t(),
    attempt_number: pos_integer() | nil,
    error_class: String.t() | nil
  }
  | nil,
```

From lib/chimeway/traces/explanation.ex (@moduledoc last_attempt field description, line 32):
```
  - `last_attempt` — map with :outcome, :inserted_at, :attempt_number, :error_class for the most recent attempt, or nil
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add adapter_module to traces explain output and Explanation typespec</name>
  <files>lib/chimeway/traces.ex, lib/chimeway/traces/explanation.ex</files>
  <read_first>
    - lib/chimeway/traces.ex — read the full file; specifically locate build_last_attempt_map/1 (around line 275) and the attempt_entries Enum.map block (around line 392) to make precise line-targeted edits
    - lib/chimeway/traces/explanation.ex — read the full file; locate the @type t definition (around line 39) and the @moduledoc last_attempt field description (around line 32)
  </read_first>
  <behavior>
    - explain_delivery/1 for a Phase-29 attempt returns last_attempt map with adapter_module: "Chimeway.Adapters.Test"
    - explain_delivery/1 for a pre-Phase-29 attempt (nil adapter_module column) returns last_attempt map with adapter_module: nil
    - Each entry in explanation.timeline with event: :attempt_recorded has detail.adapter_module present (nil or string)
  </behavior>
  <action>
Make four targeted additions across two files. Do NOT change any functional logic outside the
four specified insertion points.

**lib/chimeway/traces.ex — Change 1: build_last_attempt_map/1**

Find `build_last_attempt_map/1` (around line 275). Add `adapter_module: attempt.adapter_module`
as the last key in the returned map:

Replace:
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

With:
```elixir
defp build_last_attempt_map(attempt) do
  %{
    outcome: attempt.outcome,
    inserted_at: attempt.inserted_at,
    attempt_number: attempt.attempt_number,
    error_class: attempt.error_class,
    adapter_module: attempt.adapter_module   # Phase 29 D-22 — nil for pre-Phase-29 rows
  }
end
```

**lib/chimeway/traces.ex — Change 2: attempt_entries Enum.map**

Find the `attempt_entries = Enum.map(attempts, fn attempt ->` block (around line 392).
Add `adapter_module: attempt.adapter_module` as the last key in the `detail` map:

Replace the detail map inside:
```elixir
      detail: %{
        outcome: attempt.outcome,
        attempt_number: attempt.attempt_number,
        error_class: attempt.error_class
      }
```

With:
```elixir
      detail: %{
        outcome: attempt.outcome,
        attempt_number: attempt.attempt_number,
        error_class: attempt.error_class,
        adapter_module: attempt.adapter_module   # Phase 29 D-22 — nil for pre-Phase-29 rows
      }
```

**lib/chimeway/traces/explanation.ex — Change 3: @type t last_attempt map**

Find the `last_attempt:` field in the `@type t` definition. Add `adapter_module: String.t() | nil`
as the last key in the last_attempt map type:

Replace:
```elixir
          last_attempt:
            %{
              outcome: atom(),
              inserted_at: DateTime.t(),
              attempt_number: pos_integer() | nil,
              error_class: String.t() | nil
            }
            | nil,
```

With:
```elixir
          last_attempt:
            %{
              outcome: atom(),
              inserted_at: DateTime.t(),
              attempt_number: pos_integer() | nil,
              error_class: String.t() | nil,
              adapter_module: String.t() | nil
            }
            | nil,
```

**lib/chimeway/traces/explanation.ex — Change 4: @moduledoc field description**

Find the `last_attempt` line in the `@moduledoc` Fields section (around line 32). Replace:
```
  - `last_attempt` — map with :outcome, :inserted_at, :attempt_number, :error_class for the most recent attempt, or nil
```

With:
```
  - `last_attempt` — map with :outcome, :inserted_at, :attempt_number, :error_class, :adapter_module for the most recent attempt, or nil. `:adapter_module` is nil for pre-Phase-29 attempts.
```
  </action>
  <verify>
    <automated>cd /Users/jon/projects/chimeway && mix test test/chimeway/traces_test.exs 2>&1 | tail -15</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "adapter_module: attempt.adapter_module" lib/chimeway/traces.ex` outputs `2` (one in build_last_attempt_map, one in attempt_entries)
    - `grep -c "adapter_module: String.t() | nil" lib/chimeway/traces/explanation.ex` outputs `1`
    - `grep "adapter_module" lib/chimeway/traces/explanation.ex | grep "@moduledoc" ` — or verify @moduledoc paragraph contains adapter_module
    - `mix compile` exits 0
    - `mix test test/chimeway/traces_test.exs` passes (existing traces tests unaffected)
  </acceptance_criteria>
  <done>explain_delivery output includes adapter_module in last_attempt and timeline entries; Explanation typespec updated; traces tests pass</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| DB → trace surface | adapter_module string crosses from chimeway_delivery_attempts row to operator-visible explain output |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-29-19 | Information Disclosure | adapter_module in explain_delivery output | accept | Module name strings (e.g. "MyApp.TwilioAdapter") are already in source code; traces.ex already exposes render_key, render_version, suppression_reason; adapter identity is no more sensitive than existing fields |
| T-29-20 | Tampering | nil adapter_module crash | mitigate | D-22: nil is a valid value; the Explanation struct allows nil in the type; no code reads adapter_module as an atom at trace time — it is treated as String.t() | nil throughout |
</threat_model>

<verification>
After plan execution:
- `grep -c "adapter_module: attempt.adapter_module" lib/chimeway/traces.ex` returns `2`
- `mix compile` exits 0
- `mix test test/chimeway/traces_test.exs` passes
</verification>

<success_criteria>
`explain_delivery/1` output includes `adapter_module` in `last_attempt` and in every
`attempt_entries` timeline detail. `Explanation` typespec includes `adapter_module: String.t() | nil`.
Existing traces tests pass. mix compile exits 0.
</success_criteria>

<output>
After completion, create `.planning/phases/29-outbound-channel-contracts/29-06-SUMMARY.md`
</output>

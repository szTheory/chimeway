---
phase: 29-outbound-channel-contracts
plan: "02"
type: execute
wave: 1
depends_on: []
files_modified:
  - priv/repo/migrations/20260430120000_add_adapter_module_to_chimeway_delivery_attempts.exs
  - lib/chimeway/delivery_attempt.ex
autonomous: true
requirements:
  - CHAN-01

must_haves:
  truths:
    - "chimeway_delivery_attempts table has a nullable adapter_module string column"
    - "DeliveryAttempt schema includes the adapter_module field and allows it in cast"
    - "mix ecto.migrate succeeds and mix ecto.rollback returns the table to the prior state"
  artifacts:
    - path: "priv/repo/migrations/20260430120000_add_adapter_module_to_chimeway_delivery_attempts.exs"
      provides: "Reversible migration adding adapter_module :string null: true"
      contains: "adapter_module"
    - path: "lib/chimeway/delivery_attempt.ex"
      provides: "Schema field and cast allowlist for adapter_module"
      contains: "adapter_module"
  key_links:
    - from: "lib/chimeway/dispatch/executor.ex"
      to: "lib/chimeway/delivery_attempt.ex"
      via: "Deliveries.record_attempt/2 passing adapter_module in attrs"
      pattern: "adapter_module"
---

<objective>
Add the `adapter_module :string` nullable column to `chimeway_delivery_attempts` via a
reversible Ecto migration, and wire the schema field + cast allowlist in
`lib/chimeway/delivery_attempt.ex` so the executor can persist adapter identity per
attempt (D-20, D-21).

Purpose: The DB column must exist before any Wave 3 executor changes can write to it,
and before integration tests can assert `attempt.adapter_module`. Running in Wave 1
(parallel with Plan 01) because it has no dependency on the new behaviour module.

Output: Migration file + updated schema module.
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
<!-- Existing schema and migration patterns the executor needs. -->

From lib/chimeway/delivery_attempt.ex (current schema block, lines 39-47):
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

From lib/chimeway/delivery_attempt.ex (current @optional_fields, line 53):
```elixir
@optional_fields ~w(error_class provider_response)a
```

From priv/repo/migrations/20260426150000_add_attempt_history_columns.exs (migration shape analog):
```elixir
defmodule Chimeway.Repo.Migrations.AddAttemptHistoryColumns do
  use Ecto.Migration

  def up do
    alter table(:chimeway_delivery_attempts) do
      add :attempt_number, :integer, null: true
      add :error_class, :string, null: true
    end
    # ... execute for backfill ...
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
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create migration for adapter_module column</name>
  <files>priv/repo/migrations/20260430120000_add_adapter_module_to_chimeway_delivery_attempts.exs</files>
  <read_first>
    - priv/repo/migrations/20260426150000_add_attempt_history_columns.exs — the exact migration shape to follow (alter table + add + null: true project convention)
    - lib/chimeway/delivery_attempt.ex — confirms the table name and field naming convention
  </read_first>
  <action>
Create `priv/repo/migrations/20260430120000_add_adapter_module_to_chimeway_delivery_attempts.exs`
with the following exact content (D-20 — nullable, no backfill, no index):

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

Use `def change` (not `def up/down`) because this is a simple reversible nullable add
with no `execute/1` call. `null: true` is explicit per project convention.
No index is needed — query pattern is by delivery_id, not adapter_module.
No backfill — existing rows predate the feature; traces will show nil for pre-Phase-29 attempts.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/chimeway && mix ecto.migrate 2>&1 | tail -5</automated>
  </verify>
  <acceptance_criteria>
    - `priv/repo/migrations/20260430120000_add_adapter_module_to_chimeway_delivery_attempts.exs` exists
    - `grep -c "adapter_module" priv/repo/migrations/20260430120000_add_adapter_module_to_chimeway_delivery_attempts.exs` outputs `1`
    - `grep -c "null: true" priv/repo/migrations/20260430120000_add_adapter_module_to_chimeway_delivery_attempts.exs` outputs `1`
    - `grep -c "def change" priv/repo/migrations/20260430120000_add_adapter_module_to_chimeway_delivery_attempts.exs` outputs `1`
    - `mix ecto.migrate` exits 0 with no error output
    - `mix ecto.rollback` exits 0 (reversal is clean — `def change` supports automatic reversal)
  </acceptance_criteria>
  <done>Migration file exists; mix ecto.migrate and mix ecto.rollback both succeed</done>
</task>

<task type="auto">
  <name>Task 2: Wire adapter_module field in DeliveryAttempt schema</name>
  <files>lib/chimeway/delivery_attempt.ex</files>
  <read_first>
    - lib/chimeway/delivery_attempt.ex — read the full current file before editing; need the current @optional_fields line number and schema block to make precise edits
  </read_first>
  <action>
Make exactly two changes to `lib/chimeway/delivery_attempt.ex` (D-20):

**Change 1** — Add `field(:adapter_module, :string)` to the schema block, directly after
`field(:error_class, :string)`:

Before:
```elixir
  field(:error_class, :string)
  field(:inserted_at, :utc_datetime_usec)
```

After:
```elixir
  field(:error_class, :string)
  field(:adapter_module, :string)   # Phase 29 D-20 — persisted as inspect(module) string
  field(:inserted_at, :utc_datetime_usec)
```

**Change 2** — Extend `@optional_fields` to include `:adapter_module`:

Before:
```elixir
@optional_fields ~w(error_class provider_response)a
```

After:
```elixir
@optional_fields ~w(error_class provider_response adapter_module)a
```

No change to `@required_fields` — `adapter_module` is nullable for backwards-compat.
No `validate_inclusion` — any string is valid; operators own module naming.
The existing `cast/3` call uses `@required_fields ++ @optional_fields` and picks up the
new field automatically.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/chimeway && mix compile 2>&1 | grep -E "error|warning" | grep -v "^$" | head -10; echo "exit: $?"</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "adapter_module" lib/chimeway/delivery_attempt.ex` outputs `2` (one in schema, one in @optional_fields)
    - `grep -c "field(:adapter_module, :string)" lib/chimeway/delivery_attempt.ex` outputs `1`
    - `grep "optional_fields" lib/chimeway/delivery_attempt.ex` contains `adapter_module`
    - `mix compile` exits 0 with no new errors
    - `mix ecto.migrate` still exits 0 (schema matches migration)
  </acceptance_criteria>
  <done>DeliveryAttempt schema has adapter_module field; changeset cast includes it; mix compile passes</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| executor → DB | adapter_module string written to chimeway_delivery_attempts by the executor process |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-29-04 | Tampering | adapter_module column write | mitigate | D-20: value is always inspect(module) where module is a compile-time atom from config.exs — never a runtime string-to-atom conversion; DB stores a human-readable string, not an executable atom |
| T-29-05 | Information Disclosure | adapter_module in DB | accept | Module name strings (e.g. "MyApp.TwilioAdapter") are already present in source code and logs; storing them in DB adds no new attack surface |
| T-29-06 | Denial of Service | Atom exhaustion via adapter_module | mitigate | inspect(module) produces a string; no atom is created at runtime from DB values — reading adapter_module back from DB yields a string, not an atom; atoms only exist in compile-time config |
</threat_model>

<verification>
After plan execution:
- `mix ecto.migrate` exits 0
- `mix ecto.rollback` exits 0
- `mix compile` exits 0
- `grep -c "adapter_module" lib/chimeway/delivery_attempt.ex` returns `2`
</verification>

<success_criteria>
Migration exists, `mix ecto.migrate` succeeds, `DeliveryAttempt` schema has
`field(:adapter_module, :string)` and `@optional_fields` includes `:adapter_module`.
</success_criteria>

<output>
After completion, create `.planning/phases/29-outbound-channel-contracts/29-02-SUMMARY.md`
</output>

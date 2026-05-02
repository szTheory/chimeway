---
phase: 33-webhook-ingress-durability
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/chimeway/webhooks/ingress.ex
  - priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs
  - test/chimeway/webhooks/ingress_test.exs
autonomous: true
requirements: [FEED-01, FEED-02]
requirements_addressed: [FEED-01, FEED-02]
tags: [elixir, ecto, schema, migration, webhook, ingress]

must_haves:
  truths:
    - "A durable `chimeway_webhook_ingress` row exists for every accepted (verified + parsed + normalized) provider callback."
    - "The ingress row stores ONLY normalized, explainability-first fields — no raw payload, no headers, no source IP."
    - "Duplicate provider retries with the same `(adapter_module, provider_event_id)` collapse to one ingress row at the DB level."
    - "Normalized status (`delivered | bounced | failed`) is queryable on the ingress row independent of delivery resolution success — proving FEED-02 satisfied even when correlation is stale."
  artifacts:
    - path: "lib/chimeway/webhooks/ingress.ex"
      provides: "Chimeway.Webhooks.Ingress Ecto schema with `changeset/2` and partial-unique constraint"
      contains: "schema \"chimeway_webhook_ingress\""
    - path: "priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs"
      provides: "DB migration creating chimeway_webhook_ingress table + partial composite unique index"
      contains: "where: \"provider_event_id IS NOT NULL\""
    - path: "test/chimeway/webhooks/ingress_test.exs"
      provides: "Schema validation tests + partial unique index integration test"
      contains: "describe \"changeset/2"
  key_links:
    - from: "lib/chimeway/webhooks/ingress.ex"
      to: "priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs"
      via: "schema/table name `chimeway_webhook_ingress` and column types must match"
      pattern: "chimeway_webhook_ingress"
    - from: "test/chimeway/webhooks/ingress_test.exs"
      to: "lib/chimeway/webhooks/ingress.ex"
      via: "alias Chimeway.Webhooks.Ingress + changeset assertions"
      pattern: "alias Chimeway.Webhooks.Ingress"
---

<objective>
Create the durable inbound-webhook fact surface: an Ecto schema `Chimeway.Webhooks.Ingress`, the migration that creates `chimeway_webhook_ingress` with a partial composite unique index for provider-retry dedup, and a schema test file.

Purpose: This is the foundation for D-01 (durable ingress lifecycle), D-04 (explainability-first fields, no payload archive), and D-05 (composite-id replay protection). Plans 02 and 03 cannot start without this row schema and migration in place.

Output: Schema module + migration + test file that compile and pass `mix ecto.migrate && mix test test/chimeway/webhooks/ingress_test.exs`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/33-webhook-ingress-durability/33-CONTEXT.md
@.planning/phases/33-webhook-ingress-durability/33-RESEARCH.md
@.planning/phases/33-webhook-ingress-durability/33-PATTERNS.md
@lib/chimeway/signals/signal.ex
@priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs
@priv/repo/migrations/20260424091726_create_chimeway_notification_preferences.exs
@test/chimeway/delivery_attempt_test.exs

<interfaces>
<!-- Analog patterns the executor mirrors. Source: 33-PATTERNS.md and 33-RESEARCH.md (verified 2026-05-01). -->

From `lib/chimeway/signals/signal.ex` (canonical schema-module shape):
```elixir
defmodule Chimeway.Signals.Signal do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "chimeway_signals" do
    field(:tenant_id, :string)
    field(:actor_id, :string)
    field(:event_name, :string)
    field(:payload, :map, default: %{})

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(tenant_id actor_id event_name)a
  @optional_fields ~w(payload)a

  def changeset(signal, attrs) do
    signal
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:tenant_id, min: 1)
    ...
  end
end
```

NOTE: The Phase 33 schema uses `@primary_key {:id, :binary_id, autogenerate: true}` and `@foreign_key_type :binary_id` (matches the migration's `add :id, :binary_id, primary_key: true`), NOT `Ecto.UUID`. This is consistent with `priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs` which uses `:binary_id`. Both `Ecto.UUID` and `:binary_id` work; Phase 33 standardizes on `:binary_id` per the Code Examples in 33-RESEARCH.md.

From `priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs` (table-shape analog):
```elixir
create table(:chimeway_signals, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :tenant_id, :string, null: false
  ...
  timestamps(type: :utc_datetime_usec)
end
```

From `priv/repo/migrations/20260424091726_create_chimeway_notification_preferences.exs` (named unique_index analog):
```elixir
create unique_index(
  :chimeway_notification_preferences,
  [:recipient_id, :notification_key, :channel],
  name: :chimeway_notification_preferences_recipient_key_channel_index
)
```

From `test/chimeway/delivery_attempt_test.exs` (changeset-test skeleton):
```elixir
use ExUnit.Case, async: true

defp valid_attrs(overrides \\ %{}) do
  %{ ... } |> Map.merge(overrides)
end

test "requires delivery_id" do
  changeset = DeliveryAttempt.changeset(%DeliveryAttempt{}, %{...})
  refute changeset.valid?
  assert {"can't be blank", _} = changeset.errors[:delivery_id]
end
```
</interfaces>
</context>

<assumptions>
<!-- Per RESEARCH.md A1, A2 — surfaced for user confirm/override before execution. Both are LOW risk per RESEARCH. -->

- **A1 (table name):** Phase 33 uses `chimeway_webhook_ingress` (singular). CONTEXT.md leaves naming to discretion. If you prefer `chimeway_webhook_ingresses` or `chimeway_feedback_ingress`, override before execution and update the migration filename, schema `schema "..."` declaration, and the test file accordingly.
- **A2 (state vocabulary):** Phase 33 uses `:queued | :processed | :ignored | :failed` for `ingress_state` and `:delivery_not_found | :provider_message_id_not_found` for `ignored_reason`. Both are `Ecto.Enum` (atom-safe, compile-time bounded). Override the atom set if you want different vocabulary; semantics map 1:1 to D-06/D-07/D-08 regardless of names.
</assumptions>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create Wave 0 ingress schema test file</name>
  <files>test/chimeway/webhooks/ingress_test.exs</files>
  <read_first>
    - test/chimeway/delivery_attempt_test.exs (changeset-test skeleton — copy `valid_attrs/1` shape and assertion form)
    - .planning/phases/33-webhook-ingress-durability/33-PATTERNS.md (§ test/chimeway/webhooks/ingress_test.exs)
    - .planning/phases/33-webhook-ingress-durability/33-RESEARCH.md (§ Code Examples > Ingress schema — for the validation rules being tested)
    - test/support/data_case.ex (for the DB-using describe block)
  </read_first>
  <behavior>
    - Test 1: `changeset/2` is valid with required fields (`adapter_module`, `normalized_status`, `ingress_state`, plus a correlation key).
    - Test 2: `changeset/2` requires `:adapter_module` — error `{"can't be blank", _}`.
    - Test 3: `changeset/2` requires `:normalized_status` — error `{"can't be blank", _}`.
    - Test 4: `changeset/2` rejects `:normalized_status` not in `~w(delivered bounced failed)` — `validate_inclusion` error.
    - Test 5: `changeset/2` rejects empty-string `:adapter_module` — `validate_length` min:1 error.
    - Test 6: `changeset/2` is valid when `:ingress_state` is `:ignored` and `:ignored_reason` is `:delivery_not_found` even with no correlation keys (the `validate_correlation_present/1` ignored-with-reason branch).
    - Test 7: `changeset/2` is invalid when neither `:delivery_id`, `:provider_message_id`, nor (`:ingress_state == :ignored` AND `:ignored_reason`) is present — error on `:delivery_id` field.
    - Test 8 (DB integration, `use Chimeway.DataCase, async: true`): Inserting two ingress rows with the same `(adapter_module, provider_event_id)` triggers the partial unique constraint — second `Repo.insert/2` returns `{:error, %Ecto.Changeset{}}` with a unique-constraint error referencing `:chimeway_webhook_ingress_adapter_provider_event_uniq`.
    - Test 9 (DB integration): Two ingress rows with the SAME `adapter_module` but `provider_event_id = nil` for both can BOTH be inserted — partial index does not collide on NULLs.
    - Test 10 (DB integration): Two ingress rows with `provider_event_id = "evt_001"` but DIFFERENT `adapter_module` values can both be inserted — composite key prevents cross-adapter collision (Pitfall 5 in RESEARCH.md).
  </behavior>
  <action>
    Create `test/chimeway/webhooks/ingress_test.exs` with two `describe` blocks:

    1. `describe "changeset/2 — validation"` using `use ExUnit.Case, async: true` (no DB) for tests 1-7. Use a `valid_attrs/1` helper shaped like `test/chimeway/delivery_attempt_test.exs:21-28`:

       ```elixir
       defp valid_attrs(overrides \\ %{}) do
         %{
           adapter_module: "MyAdapter",
           normalized_status: "delivered",
           ingress_state: :queued,
           delivery_id: Ecto.UUID.generate()
         }
         |> Map.merge(overrides)
       end
       ```

       Use the exact assertion shape `assert {"can't be blank", _} = changeset.errors[:field]` for required-field tests (mirrors `delivery_attempt_test.exs:41-42`).

    2. `describe "DB constraints — partial composite unique index"` using `use Chimeway.DataCase, async: true` for tests 8-10. Insert via:

       ```elixir
       {:ok, _first} = %Chimeway.Webhooks.Ingress{}
                       |> Chimeway.Webhooks.Ingress.changeset(valid_attrs(%{provider_event_id: "evt_001", adapter_module: "AdapterA"}))
                       |> Chimeway.Repo.insert()
       {:error, changeset} = %Chimeway.Webhooks.Ingress{}
                              |> Chimeway.Webhooks.Ingress.changeset(valid_attrs(%{provider_event_id: "evt_001", adapter_module: "AdapterA"}))
                              |> Chimeway.Repo.insert()
       refute changeset.valid?
       assert Enum.any?(changeset.errors, fn {_, {_, opts}} -> opts[:constraint_name] == :chimeway_webhook_ingress_adapter_provider_event_uniq end)
       ```

    File header should be `defmodule Chimeway.Webhooks.IngressTest do` and `alias Chimeway.Webhooks.Ingress` at top.

    This file MUST exist before Plan 02 begins — it is the per-task verify command for Plan 01 and the Wave 0 dependency for Plan 02. Create it now even though the schema and migration don't exist yet (RED phase). It will compile-fail until Tasks 2 and 3 land.

    Per D-04 (Plan threat T-33-PII): Tests 1-10 MUST NOT include any `provider_response` or `headers` fields in `valid_attrs/1` — those fields do not exist on the schema and any test asserting them is a contract violation.
  </action>
  <verify>
    <automated>test -f test/chimeway/webhooks/ingress_test.exs &amp;&amp; grep -q "describe \"changeset/2 — validation\"" test/chimeway/webhooks/ingress_test.exs &amp;&amp; grep -q "chimeway_webhook_ingress_adapter_provider_event_uniq" test/chimeway/webhooks/ingress_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - File `test/chimeway/webhooks/ingress_test.exs` exists.
    - File contains `defmodule Chimeway.Webhooks.IngressTest do`.
    - File contains `alias Chimeway.Webhooks.Ingress`.
    - File contains `describe "changeset/2 — validation"`.
    - File contains `describe "DB constraints — partial composite unique index"`.
    - File contains `:chimeway_webhook_ingress_adapter_provider_event_uniq` (the constraint name).
    - File contains `assert {"can't be blank", _}` (the analog assertion form).
    - File does NOT contain `:provider_response` or `:headers` (T-33-PII enforcement).
    - `grep -c "test \"" test/chimeway/webhooks/ingress_test.exs` returns >= 10.
  </acceptance_criteria>
  <done>The Wave 0 test file exists with all 10 test cases stubbed. Tests will fail-to-compile until Tasks 2-3 land — that is the expected RED state.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Create the Chimeway.Webhooks.Ingress Ecto schema</name>
  <files>lib/chimeway/webhooks/ingress.ex</files>
  <read_first>
    - lib/chimeway/signals/signal.ex (full file — canonical schema module)
    - .planning/phases/33-webhook-ingress-durability/33-RESEARCH.md (§ Code Examples > Ingress schema — copy the exact module body)
    - .planning/phases/33-webhook-ingress-durability/33-PATTERNS.md (§ lib/chimeway/webhooks/ingress.ex)
    - .planning/phases/33-webhook-ingress-durability/33-CONTEXT.md (D-04 forbidden fields, D-05 dedup composite)
    - test/chimeway/webhooks/ingress_test.exs (the contract this schema must satisfy)
  </read_first>
  <action>
    Create `lib/chimeway/webhooks/ingress.ex` with this EXACT shape (per D-01, D-04, D-05; copied verbatim from `33-RESEARCH.md` § Code Examples):

    ```elixir
    defmodule Chimeway.Webhooks.Ingress do
      @moduledoc """
      Durable inbound webhook fact: a verified provider callback has been received,
      normalized, and queued for async processing. One ingress row per accepted
      callback; duplicate provider retries with the same `(adapter_module,
      provider_event_id)` collapse to the existing row via the partial unique index.

      Ingress rows are NOT a payload archive (Phase 33 D-04). They store
      explainability-first fields only — adapter identity, correlation keys,
      normalized status, processing state, and (when applicable) an ignored reason.
      Raw provider bodies and headers stay out of this surface by design.

      Replay protection seam (Phase 33 D-05): the partial unique index on
      `(adapter_module, provider_event_id) WHERE provider_event_id IS NOT NULL`
      collapses duplicate provider retries that expose a stable event id.
      Adapters without a stable event id get best-effort dedup only.
      """

      use Ecto.Schema
      import Ecto.Changeset

      @type t :: %__MODULE__{}

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id

      # Normalized outcome from adapter.normalize_feedback/1.
      @normalized_statuses ~w(delivered bounced failed)
      # Lifecycle of the ingress row itself.
      @ingress_states ~w(queued processed ignored failed)a
      # Reason vocabulary for ingress_state == :ignored. Strict enum; never
      # derived from untrusted input. Mirrors Phase 32 D-16 atom-safety discipline.
      @ignored_reasons ~w(delivery_not_found provider_message_id_not_found)a

      schema "chimeway_webhook_ingress" do
        field(:adapter_module, :string)
        field(:delivery_id, :binary_id)
        field(:provider_message_id, :string)
        field(:provider_event_id, :string)
        field(:normalized_status, :string)
        field(:ingress_state, Ecto.Enum, values: @ingress_states, default: :queued)
        field(:ignored_reason, Ecto.Enum, values: @ignored_reasons)
        field(:processed_at, :utc_datetime_usec)

        timestamps(type: :utc_datetime_usec)
      end

      @required_fields ~w(adapter_module normalized_status ingress_state)a
      @optional_fields ~w(delivery_id provider_message_id provider_event_id ignored_reason processed_at)a

      def changeset(ingress, attrs) do
        ingress
        |> cast(attrs, @required_fields ++ @optional_fields)
        |> validate_required(@required_fields)
        |> validate_length(:adapter_module, min: 1)
        |> validate_inclusion(:normalized_status, @normalized_statuses)
        |> validate_correlation_present()
        |> unique_constraint(
          [:adapter_module, :provider_event_id],
          name: :chimeway_webhook_ingress_adapter_provider_event_uniq
        )
      end

      defp validate_correlation_present(changeset) do
        delivery_id = get_field(changeset, :delivery_id)
        pmid = get_field(changeset, :provider_message_id)
        state = get_field(changeset, :ingress_state)
        reason = get_field(changeset, :ignored_reason)

        cond do
          delivery_id || pmid -> changeset
          state == :ignored and reason -> changeset
          true ->
            add_error(changeset, :delivery_id,
              "must be present, or provider_message_id must be present, or ingress must be :ignored with a reason")
        end
      end
    end
    ```

    FORBIDDEN per D-04 / Pitfall 3 / threat T-33-PII: do NOT add `field(:provider_response, :map)`, `field(:headers, :map)`, `field(:source_ip, :string)`, or `field(:raw_body, :binary)`. Schema diff in code review showing any of these is a hard veto.

    Atom-safety per Phase 11 / Phase 29 D-20 / threat T-33-AUTH-LEAK: `:adapter_module`, `:provider_message_id`, `:provider_event_id` are ALL `:string` (never atom on wire). `:ingress_state` and `:ignored_reason` are `Ecto.Enum` with compile-time bounded atom lists; do NOT use `String.to_atom/1` anywhere in this file.
  </action>
  <verify>
    <automated>mix compile --warnings-as-errors 2>&amp;1 | grep -v "^Compiling" || true; test -f lib/chimeway/webhooks/ingress.ex &amp;&amp; grep -q 'schema "chimeway_webhook_ingress"' lib/chimeway/webhooks/ingress.ex &amp;&amp; ! grep -q "field(:provider_response" lib/chimeway/webhooks/ingress.ex &amp;&amp; ! grep -q "field(:headers" lib/chimeway/webhooks/ingress.ex</automated>
  </verify>
  <acceptance_criteria>
    - File `lib/chimeway/webhooks/ingress.ex` exists.
    - File contains `defmodule Chimeway.Webhooks.Ingress do`.
    - File contains `@primary_key {:id, :binary_id, autogenerate: true}`.
    - File contains `@foreign_key_type :binary_id`.
    - File contains `schema "chimeway_webhook_ingress" do`.
    - File contains `field(:adapter_module, :string)`.
    - File contains `field(:delivery_id, :binary_id)`.
    - File contains `field(:provider_message_id, :string)`.
    - File contains `field(:provider_event_id, :string)`.
    - File contains `field(:normalized_status, :string)`.
    - File contains `field(:ingress_state, Ecto.Enum, values:`.
    - File contains `field(:ignored_reason, Ecto.Enum, values:`.
    - File contains `field(:processed_at, :utc_datetime_usec)`.
    - File contains `timestamps(type: :utc_datetime_usec)`.
    - File contains `unique_constraint(`.
    - File contains `:chimeway_webhook_ingress_adapter_provider_event_uniq`.
    - File contains `validate_inclusion(:normalized_status,`.
    - File contains `validate_correlation_present`.
    - File does NOT contain `field(:provider_response`.
    - File does NOT contain `field(:headers`.
    - File does NOT contain `field(:source_ip`.
    - File does NOT contain `field(:raw_body`.
    - File does NOT contain `String.to_atom`.
    - `mix compile --warnings-as-errors` exits 0.
  </acceptance_criteria>
  <done>Schema module compiles clean and matches the analog shape from `lib/chimeway/signals/signal.ex` plus Phase 33 D-04/D-05 specifics.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Create the chimeway_webhook_ingress migration</name>
  <files>priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs</files>
  <read_first>
    - priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs (table-block analog)
    - priv/repo/migrations/20260424091726_create_chimeway_notification_preferences.exs (named unique_index analog)
    - .planning/phases/33-webhook-ingress-durability/33-RESEARCH.md (§ Code Examples > Migration — copy verbatim)
    - .planning/phases/33-webhook-ingress-durability/33-PATTERNS.md (§ priv/repo/migrations/{timestamp}_create_chimeway_webhook_ingress.exs)
    - lib/chimeway/webhooks/ingress.ex (schema this migration must match)
  </read_first>
  <action>
    Create `priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs` with this EXACT body (copied verbatim from `33-RESEARCH.md` § Code Examples > Migration):

    ```elixir
    defmodule Chimeway.Repo.Migrations.CreateChimewayWebhookIngress do
      use Ecto.Migration

      def change do
        create table(:chimeway_webhook_ingress, primary_key: false) do
          add :id, :binary_id, primary_key: true
          add :adapter_module, :string, null: false
          add :delivery_id, references(:chimeway_deliveries, type: :binary_id, on_delete: :nilify_all)
          add :provider_message_id, :string
          add :provider_event_id, :string
          add :normalized_status, :string, null: false
          add :ingress_state, :string, null: false, default: "queued"
          add :ignored_reason, :string
          add :processed_at, :utc_datetime_usec

          timestamps(type: :utc_datetime_usec)
        end

        # Operator query: "what's stuck in :queued?"
        create index(:chimeway_webhook_ingress, [:ingress_state])

        # Correlation lookup paths from worker.
        create index(:chimeway_webhook_ingress, [:delivery_id])
        create index(:chimeway_webhook_ingress, [:provider_message_id])

        # Dedup seam (D-05): provider_event_id is nullable, so the index is partial.
        # Composite on adapter_module to prevent cross-provider id collisions.
        create unique_index(
          :chimeway_webhook_ingress,
          [:adapter_module, :provider_event_id],
          name: :chimeway_webhook_ingress_adapter_provider_event_uniq,
          where: "provider_event_id IS NOT NULL"
        )
      end
    end
    ```

    Critical column-by-column check (T-33-PII enforcement): the `add` calls must EXACTLY match the schema's `field` declarations. Specifically:
    - `add :adapter_module, :string, null: false` (required)
    - `add :delivery_id, references(:chimeway_deliveries, type: :binary_id, on_delete: :nilify_all)` (FK with nilify cascade per RESEARCH.md rationale: hard-delete of delivery leaves audit row intact)
    - `add :normalized_status, :string, null: false`
    - `add :ingress_state, :string, null: false, default: "queued"` (Ecto.Enum stores as string; default keeps fresh inserts in :queued)
    - `add :ignored_reason, :string` (nullable; only set on transitions to `:ignored`)
    - `add :processed_at, :utc_datetime_usec` (nullable; only set on lifecycle transition out of `:queued`)

    FORBIDDEN per D-04 / T-33-PII: do NOT add `add :provider_response, :map`, `add :headers, :map`, `add :raw_body, :binary`, or `add :source_ip, :string`. The migration schema must be byte-identical to the schema module.

    The partial unique index uses the literal string `where: "provider_event_id IS NOT NULL"` — this is the standard PG partial-index DDL, fed to Ecto via the `where:` keyword on `unique_index/3`. Per `33-RESEARCH.md` § "Don't Hand-Roll" row #4, this is the canonical race-free dedup primitive (alternative `Repo.exists?`-then-insert has a race window).
  </action>
  <verify>
    <automated>test -f priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs &amp;&amp; grep -q "create table(:chimeway_webhook_ingress" priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs &amp;&amp; grep -q 'where: "provider_event_id IS NOT NULL"' priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs &amp;&amp; ! grep -q "add :provider_response" priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs &amp;&amp; ! grep -q "add :headers" priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs &amp;&amp; MIX_ENV=test mix ecto.migrate</automated>
  </verify>
  <acceptance_criteria>
    - File `priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs` exists.
    - File contains `defmodule Chimeway.Repo.Migrations.CreateChimewayWebhookIngress do`.
    - File contains `create table(:chimeway_webhook_ingress, primary_key: false) do`.
    - File contains `add :id, :binary_id, primary_key: true`.
    - File contains `add :adapter_module, :string, null: false`.
    - File contains `references(:chimeway_deliveries, type: :binary_id, on_delete: :nilify_all)`.
    - File contains `add :provider_event_id, :string`.
    - File contains `add :normalized_status, :string, null: false`.
    - File contains `add :ingress_state, :string, null: false, default: "queued"`.
    - File contains `add :processed_at, :utc_datetime_usec`.
    - File contains `timestamps(type: :utc_datetime_usec)`.
    - File contains `create index(:chimeway_webhook_ingress, [:ingress_state])`.
    - File contains `create index(:chimeway_webhook_ingress, [:delivery_id])`.
    - File contains `create index(:chimeway_webhook_ingress, [:provider_message_id])`.
    - File contains `name: :chimeway_webhook_ingress_adapter_provider_event_uniq`.
    - File contains `where: "provider_event_id IS NOT NULL"`.
    - File does NOT contain `add :provider_response`.
    - File does NOT contain `add :headers`.
    - File does NOT contain `add :raw_body`.
    - File does NOT contain `add :source_ip`.
    - `MIX_ENV=test mix ecto.migrate` exits 0.
    - `mix test test/chimeway/webhooks/ingress_test.exs` exits 0 (Task 1 + Task 2 + Task 3 GREEN together).
  </acceptance_criteria>
  <done>Migration runs clean against test DB. Schema module + migration + tests all align: `mix test test/chimeway/webhooks/ingress_test.exs` passes.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| client → API | Untrusted provider HTTP request crosses into the host controller. |
| API → DB | Verified+parsed callback crosses into durable Chimeway state via the ingress row insert. |

## STRIDE Threat Register (Plan 01 scope)

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-33-PII | Information Disclosure | `chimeway_webhook_ingress` table & `Chimeway.Webhooks.Ingress` schema | mitigate | Schema's `@allowed_fields` enumerates ONLY normalized facts (adapter_module, delivery_id, provider_message_id, provider_event_id, normalized_status, ingress_state, ignored_reason, processed_at). NO `provider_response :map`, NO `headers :map`, NO `raw_body :binary`, NO `source_ip :string`. Migration matches column-for-column. Acceptance criteria assert the absence of those columns via grep. |
| T-33-DEDUP | Spoofing (replay) | partial composite unique index | mitigate | Partial unique index `(adapter_module, provider_event_id) WHERE provider_event_id IS NOT NULL` (D-05). Plan 05 adds the integration test that proves replay collapses to one row. Plan 01 lays the schema constraint; Plan 02 wires the `on_conflict: :nothing` against this index. |
| T-33-AUTH-LEAK | Information Disclosure | atom table | mitigate | All untrusted strings persisted as `:string` (`adapter_module`, `provider_event_id`, `provider_message_id`). `ingress_state` and `ignored_reason` are `Ecto.Enum` with compile-time bounded atom lists. NO `String.to_atom/1` in this file (acceptance criterion). |
</threat_model>

<verification>
- `mix compile --warnings-as-errors` exits 0.
- `MIX_ENV=test mix ecto.migrate` exits 0.
- `mix test test/chimeway/webhooks/ingress_test.exs` exits 0 (all 10 tests pass).
- `grep "field(" lib/chimeway/webhooks/ingress.ex | wc -l` returns 8 (eight schema fields exactly: adapter_module, delivery_id, provider_message_id, provider_event_id, normalized_status, ingress_state, ignored_reason, processed_at).
- `grep -E "field\\(:(provider_response|headers|raw_body|source_ip)" lib/chimeway/webhooks/ingress.ex` returns nothing (T-33-PII enforcement).
- `grep "String.to_atom" lib/chimeway/webhooks/ingress.ex` returns nothing (T-33-AUTH-LEAK enforcement).
</verification>

<success_criteria>
- New schema module `Chimeway.Webhooks.Ingress` compiles and exports `changeset/2` and the schema struct type `t()`.
- New migration creates `chimeway_webhook_ingress` table with the partial composite unique index `chimeway_webhook_ingress_adapter_provider_event_uniq` and three plain lookup indexes.
- All 10 changeset + DB tests in `test/chimeway/webhooks/ingress_test.exs` pass.
- Schema/migration explicitly contain ZERO of the forbidden fields per D-04 / T-33-PII.
- The schema is ready to be the `:ingress` step in `Ecto.Multi` for Plan 02.
</success_criteria>

<output>
After completion, create `.planning/phases/33-webhook-ingress-durability/33-01-SUMMARY.md` per `$HOME/.claude/get-shit-done/templates/summary.md`. Include:
- `requirements_completed: [FEED-01, FEED-02]` (this plan provides the durable resting place for normalized status — FEED-02 — and the foundation for the durable-handoff guarantee — FEED-01)
- `threats_mitigated: [T-33-PII, T-33-DEDUP-schema, T-33-AUTH-LEAK]`
- One-line note that Plan 02 and Plan 03 may now begin (Wave 2).
</output>

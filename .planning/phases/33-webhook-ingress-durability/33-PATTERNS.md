# Phase 33: webhook-ingress-durability - Pattern Map

**Mapped:** 2026-05-01
**Files analyzed:** 16 (6 modify, 10 create)
**Analogs found:** 15 / 16 (one greenfield: example app skeleton)

## File Classification

### chimeway core (modify)

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/chimeway/webhooks.ex` | api-boundary (pure function) | request-response + atomic transaction | `lib/chimeway/signal.ex` | exact (Multi+Oban handoff) |
| `lib/chimeway/webhooks/process_feedback_worker.ex` | worker (Oban) | event-driven + safe-noop normalization | `lib/chimeway/dispatch/workflow_progression_worker.ex` | exact (queue-boundary noop) |
| `lib/chimeway/deliveries.ex` | context (extend with `fetch_delivery/1`) | CRUD lookup | `lib/chimeway/deliveries.ex:434-445` (`get_delivery_by_provider_message_id/1`) | self-analog (sibling) |
| `mix.exs` (aliases) | build config | n/a | `mix.exs:46-73` (`aliases/0`) | self-analog |
| `test/chimeway/webhooks_test.exs` | unit/integration test | n/a | `test/chimeway/signal_test.exs` | exact (Multi+Oban assertions) |
| `test/chimeway/webhooks/process_feedback_worker_test.exs` | unit/integration test | n/a | self (extend existing describe) | self-analog |

### chimeway core (create)

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/chimeway/webhooks/ingress.ex` | Ecto schema | persistence | `lib/chimeway/signals/signal.ex` | exact (string-typed durable fact) |
| `priv/repo/migrations/{ts}_create_chimeway_webhook_ingress.exs` | DB migration | schema | `priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs` (signals table block) + `priv/repo/migrations/20260424091726_create_chimeway_notification_preferences.exs` (named unique_index) | role-match (no in-repo partial-index precedent — see "No Analog Found") |
| `test/chimeway/webhooks/ingress_test.exs` | schema test | n/a | `test/chimeway/delivery_attempt_test.exs` | exact (changeset cast/validate tests with no DB) |

### example app (create — sibling Mix project)

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `examples/chimeway_demo_host/mix.exs` | build config | n/a | `mix.exs` (root project structure) | role-match (no in-repo example app precedent) |
| `examples/chimeway_demo_host/lib/demo_host/application.ex` | OTP app | n/a | (vanilla Phoenix `mix phx.new --no-ecto …` skeleton) | no analog — see note |
| `examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex` | Phoenix endpoint | request-response (HTTP pipeline) | (vanilla Phoenix skeleton) + canonical hexdocs `Plug.Parsers` `:body_reader` | no analog — see note |
| `examples/chimeway_demo_host/lib/demo_host_web/router.ex` | Phoenix router | route definition | (vanilla Phoenix skeleton) | no analog |
| `examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` | Plug (`:body_reader` MFA) | request-response | hexdocs.pm/plug/Plug.Parsers.html canonical pattern | doc-citation (no in-repo precedent — Phoenix is not a core dep) |
| `examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex` | Phoenix controller | request-response | hexdocs canonical + research RESEARCH.md `Pattern 3` | doc-citation |
| `examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex` | fixture adapter (test fixture) | n/a | `test/chimeway/webhooks_test.exs:7-23` `MockAdapter` | exact (in-test fixture adapter) |
| `examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs` | E2E test | n/a | `test/chimeway/signal_test.exs` (multi+oban assertions) + `Phoenix.ConnTest` conventions | role-match (E2E test layer is greenfield) |

---

## Pattern Assignments

### `lib/chimeway/webhooks.ex` (api-boundary, request-response + atomic transaction)

**Analog:** `lib/chimeway/signal.ex` — VERIFIED read 2026-05-01.
This is the literal template per RESEARCH.md `Pattern 1`. Phase 33 mirrors the entire shape;
swap `Signal`/`SignalRouterWorker` → `Ingress`/`ProcessFeedbackWorker` and reuse the case clause verbatim.

**Module-level pattern** (`lib/chimeway/signal.ex:1-41`, full file):

```elixir
defmodule Chimeway.Signal do
  @moduledoc """
  Host-facing API boundary for submitting workflow progression signals.
  ...
  Both side effects share a single `Ecto.Multi` transaction — if the Oban
  insert fails, the Signal row is rolled back; no orphaned signals or jobs.
  """

  alias Chimeway.Dispatch.SignalRouterWorker
  alias Chimeway.Repo
  alias Chimeway.Signals.Signal
  alias Ecto.Multi

  @spec track(String.t(), String.t(), String.t(), map()) ::
          {:ok, Signal.t()} | {:error, Ecto.Changeset.t() | term()}
  def track(tenant_id, actor_id, event_name, payload \\ %{}) do
    attrs = %{
      tenant_id: tenant_id,
      actor_id: actor_id,
      event_name: event_name,
      payload: payload
    }

    Multi.new()
    |> Multi.insert(:signal, Signal.changeset(%Signal{}, attrs))
    |> Oban.insert(:job, fn %{signal: signal} ->
      SignalRouterWorker.new(%{"signal_id" => signal.id})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{signal: signal}} -> {:ok, signal}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end
end
```

**Phase 33 mapping:**
- `:signal` step → `:ingress` step
- `Signal.changeset/2` → `Ingress.changeset/2`
- `SignalRouterWorker.new(%{"signal_id" => …})` → `ProcessFeedbackWorker.new(%{"ingress_id" => ingress.id})`
- Tagged returns: `{:ok, %Ingress{}}` per CONTEXT.md D-03; `{:error, reason}` for any Multi failure step.

**Unique additions** (not in the Signal analog, but required by Phase 33 D-05):
1. The `with`-pipeline preamble (`verify_webhook` → `Jason.decode` → `resolve_delivery` → `normalize_feedback` → `extract_provider_event_id`) is preserved from the **current** `lib/chimeway/webhooks.ex:7-26`. Tighten the existing collapsing `_ -> :error` clause into tagged tuples per RESEARCH.md `Pitfall 1`.
2. Add `on_conflict: :nothing` + `conflict_target: {:unsafe_fragment, …}` to the `Multi.insert(:ingress, …)` call to honor the partial composite unique index from D-05. No analog in `signal.ex` (signals do not dedup); cite RESEARCH.md `Pattern 1` failure-modes table directly.

**Anti-pattern to remove** (current code, `lib/chimeway/webhooks/process_feedback_worker.ex:64-70`):

```elixir
def enqueue(args) do
  args
  |> new()
  |> Oban.insert()

  {:ok, :enqueued}    # <-- discards Oban.insert return; ALWAYS reports success
end
```

This `enqueue/1` helper is **deleted** by Phase 33; callers go through `Webhooks.process/4` exclusively (RESEARCH.md `State of the Art` and `Anti-Patterns to Avoid`).

---

### `lib/chimeway/webhooks/process_feedback_worker.ex` (worker, event-driven + safe-noop)

**Analog:** `lib/chimeway/dispatch/workflow_progression_worker.ex` — VERIFIED read 2026-05-01.
This is the literal template per RESEARCH.md `Pattern 2`.

**Module-level pattern** (`workflow_progression_worker.ex:1-39`):

```elixir
if Code.ensure_loaded?(Oban) do
  defmodule Chimeway.Dispatch.WorkflowProgressionWorker do
    @moduledoc """
    Oban worker that wakes a due waiting workflow run by stable id.
    ...
    """

    use Oban.Worker,
      queue: :chimeway_delivery,
      max_attempts: 5,
      replace: [scheduled: [:scheduled_at]],
      unique: [
        fields: [:args],
        keys: [:workflow_run_id],
        period: 60,
        timestamp: :scheduled_at
      ]

    alias Chimeway.Workflows.Progression

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"workflow_run_id" => workflow_run_id}})
        when is_binary(workflow_run_id) do
      ...
    end
```

**Phase 33 mapping:**
- Wrap module in `if Code.ensure_loaded?(Oban) do … end` (currently NOT wrapped in `process_feedback_worker.ex:1`; this is a defect to fix).
- Use the same `use Oban.Worker, queue: :chimeway_delivery, max_attempts: 5, …` shape (current code uses `queue: :default`; switch to `:chimeway_delivery` to align with the existing queue config in `config/test.exs:21`).
- Match perform args by `%{"ingress_id" => ingress_id}` with `is_binary/1` guard (mirror line 44-45 verbatim).

**Safe-noop normalizer** (`workflow_progression_worker.ex:67-74` — VERIFIED):

```elixir
@doc false
def normalize_progress_result({:ok, {:advanced, _run, _deliveries}}), do: :ok
def normalize_progress_result({:ok, {:waiting, _run}}), do: :ok
def normalize_progress_result({:ok, {:noop, _run, _reason}}), do: :ok
def normalize_progress_result({:ok, {:completed, _run}}), do: :ok
def normalize_progress_result({:ok, {:stopped, _run}}), do: :ok
def normalize_progress_result({:error, :workflow_run_not_found}), do: :ok
def normalize_progress_result({:error, reason}), do: {:error, reason}
```

**Phase 33 mapping (per CONTEXT.md D-06/D-07):**
- `:workflow_run_not_found` → `nil` from `Repo.get(Ingress, id)` and the `mark_ignored/2` `:delivery_not_found` / `:provider_message_id_not_found` outcomes — all collapse to `:ok`.
- The `{:error, reason} -> {:error, reason}` retry-eligible passthrough is preserved verbatim.

**Bug to fix in current `process_feedback_worker.ex` (line 10):**

```elixir
%{"delivery_id" => id} -> {:ok, Deliveries.get_delivery!(id)}
```

`Deliveries.get_delivery!/1` raises `Ecto.NoResultsError` on miss → Oban retry storm. Replace with non-raising lookup. RESEARCH.md `Pitfall 2` and `State of the Art` row #2.

**Backwards-compat shim** (per RESEARCH.md A6):
Keep two extra `perform/1` clauses matching the legacy `%{"delivery_id" => …}` and `%{"provider_message_id" => …}` shapes for one release cycle so in-flight pre-Phase-33 Oban jobs survive deploy. Marked for removal in a future cleanup phase.

---

### `lib/chimeway/webhooks/ingress.ex` (Ecto schema, persistence)

**Analog:** `lib/chimeway/signals/signal.ex` — VERIFIED read 2026-05-01.

**Schema-module pattern** (`signals/signal.ex:1-39`, full file):

```elixir
defmodule Chimeway.Signals.Signal do
  @moduledoc """
  Durable host-submitted progression signal.
  ...
  """

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
    |> validate_length(:actor_id, min: 1)
    |> validate_length(:event_name, min: 1)
  end
end
```

**Phase 33 mapping:**
- Same module skeleton (`use Ecto.Schema`, `import Ecto.Changeset`, `@type t`, `@primary_key`, `@foreign_key_type`).
- Schema name `"chimeway_webhook_ingress"`.
- Adapter identity persisted as `:string` (mirrors `signals.signal:tenant_id, actor_id, event_name` — never atom on wire). This enforces Phase 11 atom-safety + Phase 29 D-20.
- `Ecto.Enum` for `:ingress_state` and `:ignored_reason` (compile-time bounded vocabularies; no `String.to_atom/1` exposure). Not present in `signal.ex` because signals are open-vocabulary; document this divergence in moduledoc.
- `unique_constraint([:adapter_module, :provider_event_id], name: :chimeway_webhook_ingress_adapter_provider_event_uniq)` — matches the migration's index name.
- Custom `validate_correlation_present/1` (a private function) — no direct analog in `signal.ex`; pattern follows the standard Ecto idiom: read fields with `get_field/2`, branch on `cond`, return `add_error/3` on the failing path. RESEARCH.md `Code Examples > Ingress schema` shows the exact shape.

**Forbidden additions** (RESEARCH.md `Pitfall 3` + CONTEXT.md D-04):
Do NOT add `:provider_response :map` or `:headers :map` fields. The ingress row is explainability-first metadata only. Schema diff that introduces these in code review is a hard veto.

---

### `priv/repo/migrations/{timestamp}_create_chimeway_webhook_ingress.exs` (migration, schema)

**Analog (table shape):** `priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs:26-37` — VERIFIED.

```elixir
create table(:chimeway_signals, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :tenant_id, :string, null: false
  add :actor_id, :string, null: false
  add :event_name, :string, null: false
  add :payload, :map, default: %{}

  timestamps(type: :utc_datetime_usec)
end

create index(:chimeway_signals, [:tenant_id, :actor_id])
create index(:chimeway_signals, [:tenant_id, :event_name])
```

**Analog (named unique_index):** `priv/repo/migrations/20260424091726_create_chimeway_notification_preferences.exs:15-19` — VERIFIED.

```elixir
create unique_index(
  :chimeway_notification_preferences,
  [:recipient_id, :notification_key, :channel],
  name: :chimeway_notification_preferences_recipient_key_channel_index
)
```

**Phase 33 mapping:**
- Table block: same shape — `primary_key: false`, `add :id, :binary_id, primary_key: true`, string-typed identity fields, `:utc_datetime_usec` timestamps.
- Add `references(:chimeway_deliveries, type: :binary_id, on_delete: :nilify_all)` for `delivery_id` FK (cascade rationale per RESEARCH.md `Code Examples > Migration`: nilify so a hard delivery delete leaves the audit row intact).
- Composite + partial unique index (no in-repo precedent — see `## No Analog Found`):
  ```elixir
  create unique_index(
    :chimeway_webhook_ingress,
    [:adapter_module, :provider_event_id],
    name: :chimeway_webhook_ingress_adapter_provider_event_uniq,
    where: "provider_event_id IS NOT NULL"
  )
  ```
  The `where:` keyword on `unique_index` is standard Ecto migration API for PostgreSQL partial indexes. RESEARCH.md `Don't Hand-Roll` row #4 cites this as the canonical PG dedup primitive.

---

### `lib/chimeway/deliveries.ex` (extend with `fetch_delivery/1`)

**Analog (sibling-in-same-file):** `lib/chimeway/deliveries.ex:434-445` — VERIFIED.

```elixir
@doc """
Fetches a delivery by a provider message ID from its attempts.
"""
@spec get_delivery_by_provider_message_id(String.t()) :: {:ok, Delivery.t()} | {:error, :not_found}
def get_delivery_by_provider_message_id(provider_message_id) when is_binary(provider_message_id) do
  case Repo.one(
         from(a in DeliveryAttempt,
           where: a.provider_message_id == ^provider_message_id,
           preload: [:delivery],
           limit: 1
         )
       ) do
    %DeliveryAttempt{delivery: %Delivery{} = delivery} -> {:ok, delivery}
    _ -> {:error, :not_found}
  end
end
```

**Phase 33 addition (sibling to `get_delivery!/1` at line 427-428):**

```elixir
@doc """
Fetches a delivery by ID without raising. Pairs with `get_delivery!/1` for
queue-boundary callers that prefer explicit `{:error, :not_found}`.
"""
@spec fetch_delivery(binary()) :: {:ok, Delivery.t()} | {:error, :not_found}
def fetch_delivery(id) when is_binary(id) do
  case Repo.get(Delivery, id) do
    %Delivery{} = delivery -> {:ok, delivery}
    nil -> {:error, :not_found}
  end
end
```

This is RESEARCH.md `Critical:` callout (line 332); the addition is mandatory to satisfy CONTEXT.md D-06.

---

### `mix.exs` (extend `aliases/0` with `verify.example`)

**Analog:** `mix.exs:46-73` — VERIFIED.

```elixir
defp aliases do
  [
    # Full local gate: run before pushing
    ci: ["ci.lint", "ci.test"],

    # Lint lane
    "ci.lint": [
      "format --check-formatted",
      "compile --warnings-as-errors",
      "credo --strict"
    ],

    # Test lane
    "ci.test": ["test"],

    # Docs gate: fails on undocumented public functions
    "ci.docs": ["docs --warnings-as-errors"],

    # Dependency audit
    "ci.audit": ["hex.audit"],

    # Post-publish verify trio (run locally by maintainer, not in pre-merge CI)
    "verify.clean": ["cmd git diff --exit-code"],
    "verify.parity": [
      "cmd mix hex.build --unpack --output /tmp/chimeway_verify && ls /tmp/chimeway_verify"
    ]
  ]
end
```

**Phase 33 addition** (mirror the `cmd …` pattern used by `verify.clean` and `verify.parity`):

```elixir
"verify.example": [
  "cmd mix do deps.get, test --working-dir examples/chimeway_demo_host"
]
```

OR (if `--working-dir` is unavailable for `mix test` in this Elixir version, use a `cd` form):

```elixir
"verify.example": [
  "cmd cd examples/chimeway_demo_host && mix deps.get && mix test"
]
```

Per RESEARCH.md `Open Questions` #2: keep this OUT of the default `ci.test` lane to preserve fast feedback on core lib tests; phase gate runs `mix ci && mix verify.example`.

---

### `test/chimeway/webhooks_test.exs` (extend)

**Analog:** `test/chimeway/signal_test.exs` — VERIFIED.

**Atomic-handoff assertion pattern** (`signal_test.exs:9-46`):

```elixir
describe "track/4 — Phase 27 host signal API" do
  test "inserts a Signal row with the supplied fields" do
    assert {:ok, %Signal{} = signal} =
             Chimeway.Signal.track("acme", "user_42", "email_opened", %{"campaign" => "march"})

    assert signal.tenant_id == "acme"
    ...
    persisted = Repo.get!(Signal, signal.id)
    assert persisted.tenant_id == "acme"
  end

  test "enqueues a SignalRouterWorker job carrying the new signal id" do
    assert {:ok, %Signal{id: signal_id}} =
             Chimeway.Signal.track("acme", "user_42", "clicked", %{"link" => "/x"})

    assert_enqueued(worker: SignalRouterWorker, args: %{"signal_id" => signal_id})
  end

  test "rolls back the signal insert if job enqueue cannot happen (atomicity)" do
    # Verify that track/4 wires through Ecto.Multi by ensuring no signal exists
    # without a corresponding queued job. After a successful track, both side
    # effects must be observable; if either failed, neither should persist.
    assert {:ok, signal} =
             Chimeway.Signal.track("acme", "user_42", "delivered", %{})

    assert Repo.get(Signal, signal.id)
    assert_enqueued(worker: SignalRouterWorker, args: %{"signal_id" => signal.id})
  end

  test "returns error tuple when required fields are missing" do
    assert {:error, %Ecto.Changeset{valid?: false}} =
             Chimeway.Signal.track("", "user_42", "clicked")
  end
end
```

**Phase 33 mapping:**
- Replace existing `assert {:ok, :enqueued} = …` (current `webhooks_test.exs:45, 58`) with `assert {:ok, %Ingress{} = ingress} = …` and assert `Repo.get!(Ingress, ingress.id)` like the signal test.
- Replace existing `assert :error = …` (current `webhooks_test.exs:32, 37`) with tagged-tuple assertions (`{:error, :unresolvable_delivery}`, `{:error, :unnormalizable_feedback}`) per RESEARCH.md `Pitfall 1`.
- Add `assert_enqueued worker: ProcessFeedbackWorker, args: %{"ingress_id" => ingress.id}` for atomic-handoff coverage.
- Add Wave-0 tests per RESEARCH.md `Wave 0 Gaps`: dedup convergence, `Oban.insert` failure rollback (mock or use Oban testing harness — see `signal_test.exs:37-46` "atomicity" comment for the established framing).

The existing test setup (`use Chimeway.DataCase, async: true; use Oban.Testing, repo: Chimeway.Repo; defmodule MockAdapter`) is preserved verbatim — the `MockAdapter` already implements all needed callbacks at `webhooks_test.exs:7-23`.

---

### `test/chimeway/webhooks/process_feedback_worker_test.exs` (extend)

**Analog (self):** existing file lines 49-145 — VERIFIED.

Existing tests for `delivery_id` (line 50) and `provider_message_id` (line 89) lookup paths use the **old** args shape (`%{"delivery_id" => …, "status" => …, "provider_response" => …, "adapter_module" => …}`). Phase 33 rewrites these to drive perform via an inserted ingress row whose id is the only arg.

**Existing must-rewrite test** (`process_feedback_worker_test.exs:135-145`):

```elixir
test "returns error if delivery cannot be found by delivery_id" do
  args = %{
    "delivery_id" => Ecto.UUID.generate(),
    "status" => "delivered",
    "provider_response" => %{}
  }

  assert_raise Ecto.NoResultsError, fn ->
    ProcessFeedbackWorker.perform(%Oban.Job{args: args})
  end
end
```

**Phase 33 rewrite (literal flip per CONTEXT.md D-06/D-07):**

```elixir
test "marks ingress :ignored with :delivery_not_found and returns :ok on stale delivery_id" do
  {:ok, ingress} =
    %Ingress{}
    |> Ingress.changeset(%{
      adapter_module: "SomeAdapter",
      delivery_id: Ecto.UUID.generate(),  # never persisted as a real delivery
      normalized_status: "delivered",
      ingress_state: :queued
    })
    |> Repo.insert()

  assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: %{"ingress_id" => ingress.id}})

  reloaded = Repo.get!(Ingress, ingress.id)
  assert reloaded.ingress_state == :ignored
  assert reloaded.ignored_reason == :delivery_not_found
  assert reloaded.processed_at
end
```

**Wave-0 additions (per RESEARCH.md `Wave 0 Gaps`):**
- Worker returns `:ok` when ingress row is hard-deleted between commit and perform (`Repo.get(Ingress, id) == nil` branch).
- `provider_message_id_not_found` parallel test for the second lookup path.

The existing `setup` block (lines 12-19) and the `insert_event/insert_notification` helpers (lines 21-47) are reused verbatim for the success-path tests.

---

### `test/chimeway/webhooks/ingress_test.exs` (NEW — schema test)

**Analog:** `test/chimeway/delivery_attempt_test.exs:1-60` — VERIFIED.

**Schema-test skeleton** (no DB hit for cast/validate):

```elixir
defmodule Chimeway.DeliveryAttemptTest do
  @moduledoc """
  REL-02 (Phase 14 Plan 14-02): unit tests for the DeliveryAttempt changeset extensions
  ...
  """

  use ExUnit.Case, async: true

  alias Chimeway.DeliveryAttempt

  defp valid_attrs(overrides \\ %{}) do
    %{
      delivery_id: "00000000-0000-0000-0000-000000000001",
      outcome: :succeeded,
      attempt_number: 1
    }
    |> Map.merge(overrides)
  end

  describe "changeset/2 — base contract (additive change)" do
    test "is valid with delivery_id, outcome, and attempt_number ..." do
      changeset = DeliveryAttempt.changeset(%DeliveryAttempt{}, valid_attrs())

      assert changeset.valid?,
             "expected base attrs to remain valid; errors=#{inspect(changeset.errors)}"
    end

    test "requires delivery_id" do
      changeset =
        DeliveryAttempt.changeset(%DeliveryAttempt{}, %{outcome: :succeeded, attempt_number: 1})

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:delivery_id]
    end
    ...
  end
end
```

**Phase 33 mapping:**
- Use `use ExUnit.Case, async: true` for changeset-only tests (no DB needed for required-field, enum, and length validations).
- Use `use Chimeway.DataCase, async: true` for the **partial-unique-index integration test** (must hit `Repo.insert/2` to surface the constraint).
- `valid_attrs/1` helper with `Map.merge(overrides)` shape mirrors line 21-28 verbatim.
- Assertion shape `{"can't be blank", _} = changeset.errors[:field]` mirrors line 41-42 verbatim.
- Add a dedicated DB test (with `Chimeway.DataCase`) asserting the partial unique index: insert twice with the same `(adapter_module, provider_event_id)` → second `Repo.insert/2` returns `{:error, %Ecto.Changeset{}}` with the unique constraint named `:chimeway_webhook_ingress_adapter_provider_event_uniq`. RESEARCH.md `Phase Requirements → Test Map` row "Duplicate provider retries with same `(adapter_module, provider_event_id)` collapse to one ingress row".

---

### `examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex` (fixture adapter)

**Analog:** `test/chimeway/webhooks_test.exs:7-23` — VERIFIED.

```elixir
defmodule MockAdapter do
  @behaviour Chimeway.Adapter

  def deliver(_delivery, _config), do: {:ok, %{}}

  def verify_webhook(_body, [{"signature", "valid"}], _config), do: :ok
  def verify_webhook(_, _, _config), do: {:error, :unauthorized}

  def resolve_delivery(%{"id" => "del_123"}), do: {:ok, %{delivery_id: "del_123"}}
  def resolve_delivery(%{"msg_id" => "msg_123"}), do: {:ok, %{provider_message_id: "msg_123"}}
  def resolve_delivery(_), do: :error

  def normalize_feedback(%{"status" => "bounce"}), do: {:ok, %{status: :bounced}}
  def normalize_feedback(%{"status" => "ok"}), do: {:ok, %{status: :delivered}}
  def normalize_feedback(%{"status" => "fail"}), do: {:ok, %{status: :failed}}
  def normalize_feedback(_), do: :error
end
```

**Phase 33 mapping:**
The `MockAdapter` shape is the literal pattern for the example app's `EchoAdapter`. Lift it out of `defmodule MockAdapter do` into a real module file, keep the four callbacks (`deliver/2`, `verify_webhook/3`, `resolve_delivery/1`, `normalize_feedback/1`), and add the optional `resolve_provider_event_id/1` callback (per RESEARCH.md A4) so the example app can prove the dedup path.

The `verify_webhook/3` "valid signature" pattern-match-on-header-list trick is acceptable for fixture/test adapters but MUST NOT appear in real adapter examples (`Plug.Crypto.secure_compare/2` is the production primitive — RESEARCH.md `Security Domain > Known Threat Patterns`).

---

### `examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` (Plug `:body_reader` MFA)

**Analog (doc-citation, no in-repo precedent):** hexdocs.pm/plug/Plug.Parsers.html canonical `body_reader` MFA pattern, also documented in RESEARCH.md `Pattern 3`.

The literal canonical implementation (already in RESEARCH.md `Pattern 3`):

```elixir
defmodule DemoHost.Plugs.CacheBodyReader do
  @moduledoc """
  Reads the request body and caches it into `conn.assigns[:raw_body]` so
  webhook signature verification can run on the exact bytes the provider
  signed. Plug.Parsers consumes the body during JSON parsing; without a
  body_reader the raw bytes are unrecoverable.

  This is the canonical pattern from hexdocs.pm/plug/Plug.Parsers.html.
  """

  def read_body(conn, opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts) do
      conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
      {:ok, body, conn}
    end
  end
end
```

**Endpoint wiring** (analog: hexdocs.pm/plug/Plug.Parsers.html `body_reader:` option):

```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :json],
  pass: ["text/*"],
  body_reader: {DemoHost.Plugs.CacheBodyReader, :read_body, []},
  json_decoder: Jason
```

**Critical correctness rule** (CONTEXT.md D-13 + RESEARCH.md `Pitfall 4`):
The controller MUST flatten the iolist via `IO.iodata_to_binary/1` before passing to `Chimeway.Webhooks.process/4`. Adapters compute HMAC over the body and reject iolists silently. The example controller AND the example controller test must both demonstrate the chunked-body case to catch regressions.

---

### `examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex`

**Analog (doc-citation):** RESEARCH.md `Pattern 3` (literal recommendation).

```elixir
defmodule DemoHost.ChimewayWebhookController do
  use DemoHostWeb, :controller

  def create(conn, _params) do
    raw_body = conn.assigns |> Map.get(:raw_body, []) |> IO.iodata_to_binary()
    headers = conn.req_headers
    adapter_module = adapter_for(conn.path_params["adapter"])
    config = Application.get_env(:demo_host, :chimeway_adapter_config, [])

    case Chimeway.Webhooks.process(adapter_module, raw_body, headers, config) do
      {:ok, _ingress}            -> send_resp(conn, 200, "OK")
      {:error, :unauthorized}    -> send_resp(conn, 401, "Unauthorized")
      {:error, _other}           -> send_resp(conn, 500, "Internal Server Error")
    end
  end

  defp adapter_for("echo"), do: DemoHost.Adapters.EchoAdapter
end
```

**Mapping rules** (CONTEXT.md D-03):
- `{:ok, _ingress}` → 200/2xx (host MAY pick any 2xx; example uses 200 OK)
- `{:error, :unauthorized}` → 401
- ANY other `{:error, _}` → non-2xx (example uses 500; provider retries) — must NOT collapse to 200, must NOT collapse to 401

The `Application.get_env(:demo_host, :chimeway_adapter_config, [])` shape mirrors `Chimeway.Adapter` moduledoc guidance ("Adapter config … must be read at call time via `Application.get_env/3`. Never read config in module attributes" — `lib/chimeway/adapter.ex:14-18`).

---

### `examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs`

**Analog (composite):**
- `test/chimeway/signal_test.exs` — Multi+Oban assertion shape (above)
- Phoenix.ConnTest conventions (doc-cited)
- `test/chimeway/webhooks_test.exs:7-23` `MockAdapter` for the fixture-adapter pattern

**Required test cases** (per RESEARCH.md `Phase Requirements → Test Map` and `Pitfall 4`):
1. `POST /webhooks/chimeway/echo` with valid signature + parseable body → `200 OK` AND `Repo.get!(Chimeway.Webhooks.Ingress, …)` succeeds AND `assert_enqueued worker: ProcessFeedbackWorker, args: %{"ingress_id" => …}`.
2. `POST` with bad signature → `401 Unauthorized` AND no ingress row in `Repo.all(Ingress)`.
3. `POST` with chunked body → 200 OK (specifically tests the `IO.iodata_to_binary/1` flattening — sets up by sending body in two `read_body` chunks, e.g., via `Plug.Test.conn` with `chunked_body: true` or using a small body and triggering re-entry).
4. `POST` with malformed JSON → non-2xx (provider retry).

The test must call into `Chimeway.Repo` directly (the fixture app uses `path: "../.."` so it shares `Chimeway.Repo` and the SQL sandbox).

---

## Shared Patterns

### Atom-safety (Phase 11 / Phase 32 D-16 carry-forward)

**Source:** `lib/chimeway/signals/signal.ex:20` (`field(:tenant_id, :string)` — string, never atom on wire), and the convention enforced by Phase 29 D-20.

**Apply to:** `lib/chimeway/webhooks/ingress.ex` and the migration.

Rules:
- `:adapter_module` is `:string` on the schema. Persist via `to_string(adapter_module)` in `Webhooks.process/4`.
- `:ingress_state` and `:ignored_reason` are `Ecto.Enum` with compile-time atom lists; NEVER constructed via `String.to_atom/1`.
- `:provider_event_id`, `:provider_message_id` are `:string`. NEVER `String.to_atom/1`.
- Status round-tripping in the worker uses `String.to_existing_atom/1` only on the bounded `~w(delivered bounced failed)` set (mirror current `process_feedback_worker.ex:20`).

### Adapter config read-at-call-time

**Source:** `lib/chimeway/adapter.ex:14-18` moduledoc.

**Apply to:** `examples/chimeway_demo_host/lib/demo_host_web/controllers/webhooks_controller.ex`.

The example controller MUST use `Application.get_env(:demo_host, :chimeway_adapter_config, [])` at call time. NEVER capture into a module attribute. NEVER read at compile time. This is a documented project discipline.

### Oban guarding

**Source:** `lib/chimeway/dispatch/workflow_progression_worker.ex:1` (`if Code.ensure_loaded?(Oban) do …`) and `lib/chimeway/dispatch/deferred_resume_worker.ex:1` (verified same pattern).

**Apply to:** `lib/chimeway/webhooks/process_feedback_worker.ex` (currently NOT wrapped — defect to fix in Phase 33). The new `lib/chimeway/webhooks.ex` body that calls `Oban.insert/3` ALSO needs guarding (Oban is `optional: true` per `mix.exs:40`). The simplest approach: keep the entire `Webhooks` module as-is but require Oban for the durable handoff path; document this in moduledoc, OR wrap the `Oban.insert(:job, …)` call site with `if Code.ensure_loaded?(Oban)` and surface a clear "Oban required for webhook ingress" boot-validation error per RESEARCH.md `Pattern 1` failure-mode #3.

### Tagged-tuple errors (no bare `:error`)

**Source:** the entire codebase trends toward `{:error, atom_or_changeset_or_term}` returns; the bare `:error` at `lib/chimeway/webhooks.ex:24` is the outlier and an audit defect.

**Apply to:** `lib/chimeway/webhooks.ex` (rewrite tightens to tagged returns); `examples/.../webhooks_controller.ex` (consume tagged tuples without flattening). RESEARCH.md `Pitfall 1` is the canonical reference.

### `:utc_datetime_usec` timestamps

**Source:** `lib/chimeway/signals/signal.ex:25` and the signals migration `priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs:33`.

**Apply to:** ingress schema and migration. Use `timestamps(type: :utc_datetime_usec)` consistently.

---

## No Analog Found

| File / Pattern | Role | Reason | Substitute Source |
|----------------|------|--------|-------------------|
| Partial composite unique index `WHERE provider_event_id IS NOT NULL` | DB constraint | No existing migration in `priv/repo/migrations/` uses `where:` on `unique_index/3`. Verified via `grep -rln "where:" priv/repo/migrations/` (returns nothing). | Ecto migration docs (standard `unique_index/3` `where:` keyword); RESEARCH.md `Don't Hand-Roll` row #4. |
| `examples/chimeway_demo_host/` Phoenix sibling Mix project | example app | No example/fixture Phoenix app exists in the repo (verified: `ls examples/` is empty; only `mix.exs` in repo root). Phoenix and Plug are NOT chimeway core deps per `mix.exs:33-44` (D-10). | Vanilla `mix phx.new --no-ecto --no-mailer --no-tailwind --no-esbuild --no-dashboard` skeleton, edited per RESEARCH.md `Recommended Project Structure` and `Code Examples > Fixture host app`. The skeleton's `application.ex`, `endpoint.ex`, `router.ex`, and supervision tree shape come from the Phoenix generator; only the controller, plug, fixture adapter, and `Plug.Parsers` `body_reader:` wiring carry Phase-33-specific content. |
| `Phoenix.ConnTest` E2E harness | E2E test layer | No Phoenix-backed E2E test exists in the chimeway repo (Phoenix is not a dep). | Phoenix.ConnTest docs + the in-repo `signal_test.exs` Multi/Oban assertion shapes. |

---

## Metadata

**Analog search scope:**
- `lib/chimeway/` (recursive) — primary modules and workers
- `lib/chimeway/signals/` — Ecto schema analog
- `lib/chimeway/dispatch/` — Oban worker analogs
- `priv/repo/migrations/` — migration analogs (full directory grep for `unique_index`, `where:`, `partial`)
- `test/chimeway/` and `test/chimeway/webhooks/` — test analogs
- `test/support/` — DataCase and adapter contract test
- `mix.exs` — aliases section
- `examples/` — verified empty (greenfield)

**Files scanned (read in full or targeted):**
- `lib/chimeway/signal.ex` (full, 41 lines)
- `lib/chimeway/webhooks.ex` (full, 31 lines)
- `lib/chimeway/webhooks/process_feedback_worker.ex` (full, 71 lines)
- `lib/chimeway/dispatch/workflow_progression_worker.ex` (full, 76 lines)
- `lib/chimeway/dispatch/deferred_resume_worker.ex` (40-line head)
- `lib/chimeway/signals/signal.ex` (full, 39 lines)
- `lib/chimeway/adapter.ex` (full, 75 lines)
- `lib/chimeway/deliveries.ex` (lines 420-480)
- `priv/repo/migrations/20260430013208_create_chimeway_signals_and_spine.exs` (full, 40 lines)
- `priv/repo/migrations/20260424091726_create_chimeway_notification_preferences.exs` (full, 22 lines)
- `priv/repo/migrations/20260424082833_create_chimeway_deliveries.exs` (40-line head)
- `mix.exs` (full, 109 lines)
- `test/chimeway/signal_test.exs` (full, 53 lines)
- `test/chimeway/webhooks_test.exs` (full, 67 lines)
- `test/chimeway/webhooks/process_feedback_worker_test.exs` (full, 157 lines)
- `test/chimeway/delivery_attempt_test.exs` (60-line head)
- `test/support/data_case.ex` (20-line head)

**Pattern extraction date:** 2026-05-01

# Phase 26: Escalations & Stop Conditions - Pattern Map

**Mapped:** 2024-05-24
**Files analyzed:** 3
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/chimeway/workflows/progression.ex` | service | transform | `lib/chimeway/workflows/progression.ex` (Self) | exact |
| `lib/chimeway/workflows/workflow_run.ex` | model | CRUD | `lib/chimeway/workflows/workflow_run.ex` (Self) | exact |
| `lib/chimeway/workflows/workflow_transition.ex` | model | CRUD | `lib/chimeway/workflows/workflow_transition.ex` (Self) | exact |

## Pattern Assignments

### `lib/chimeway/workflows/progression.ex` (service, transform)

**Analog:** `lib/chimeway/workflows/progression.ex`

**Progression DSL pattern (`evaluate_step/5`)** (lines 160-184):
```elixir
  defp evaluate_step(repo, run, step, delivery, now) do
    rules = step.config |> Map.get("progress", []) |> List.wrap()
    outcome = ProgressionOutcome.from_delivery(delivery, latest_attempt(delivery))

    cond do
      rules == [] ->
        {:noop, run, :no_progress_rules}

      true ->
        case match_on_outcome(rules, outcome) do
          {:match, rule, branchable_outcome, evidence} ->
            advance_run(repo, run, step, delivery, rule, branchable_outcome, evidence, now)

          :no_match ->
            case match_wait_until(rules, outcome) do
              {:match, rule} ->
                enter_waiting(repo, run, step, delivery, rule, now)

              :no_match ->
                {:noop, run, :no_matching_progress_rule}

              {:not_branchable, _rule} ->
                {:noop, run, :prior_delivery_not_converged}
            end
        end
    end
  end
```
*Note: The `evaluate_step/5` logic will need to handle new explicit matches for `stop` rules, and the fallback `:no_match` branch when rules are exhausted for a `branchable` outcome will transition to `:completed` instead of returning a `:noop`.*

**Rule Matching pattern** (lines 188-197):
```elixir
  defp match_on_outcome(rules, {:branchable, outcome, evidence}) do
    outcome_string = Atom.to_string(outcome)

    rules
    |> Enum.find(fn rule ->
      rule["kind"] == "on_outcome" and rule["outcome"] == outcome_string
    end)
    |> case do
      nil -> :no_match
      rule -> {:match, rule, outcome, evidence}
    end
```

**State Transition and Visibility pattern (`enter_waiting/6`)** (lines 219-246):
```elixir
    with {:ok, updated_run} <-
           Workflows.update_run(repo, run, %{
             state: :waiting,
             status_reason: @waiting_reason,
             status_context: status_context,
             last_transition_at: now
           }),
         {:ok, _transition} <-
           Workflows.append_transition(repo, %{
             workflow_run_id: run.id,
             workflow_step_id: step.id,
             delivery_id: delivery.id,
             from_state: :active,
             to_state: :waiting,
             reason: @waiting_reason,
             context: status_context,
             inserted_at: now
           }) do
      {:ok, {:waiting, updated_run}}
    end
```
*Note: This is the exact pattern that will be copied to implement `complete_run/5` and `stop_run/6` to transition states and append rows to `chimeway_workflow_transitions`.*

**Engine Result Type pattern** (lines 42-46):
```elixir
  @type progress_result ::
          {:ok, {:advanced, WorkflowRun.t(), [Delivery.t()]}}
          | {:ok, {:waiting, WorkflowRun.t()}}
          | {:ok, {:noop, WorkflowRun.t() | nil, atom()}}
          | {:error, term()}
```

---

### `lib/chimeway/workflows/workflow_run.ex` (model, CRUD)

**Analog:** `lib/chimeway/workflows/workflow_run.ex`

**Ecto State Values pattern** (lines 15-28):
```elixir
  @state_values [:active, :waiting, :completed, :stopped]

  schema "chimeway_workflow_runs" do
    belongs_to(:notification, Notification)
    belongs_to(:workflow_definition, WorkflowDefinition)
    belongs_to(:current_step, WorkflowStep)
    has_many(:transitions, WorkflowTransition)

    field(:state, Ecto.Enum, values: @state_values, default: :active)
```
*Note: The `:completed` and `:stopped` states are already explicitly defined in `@state_values` for Ecto, ready to be utilized.*

---

### Schema Migrations

**Analog:** `priv/repo/migrations/20260429170100_create_chimeway_workflow_runs.exs`

**State Column pattern** (line 20):
```elixir
      add(:state, :string, null: false)
```
*Note: Because the underlying Postgres column is a `:string`, and Ecto Enum is already mapped to it with all four possible values, **no new schema migration** is strictly required to support `:completed` and `:stopped` values in the database.*

## Shared Patterns

### Engine Transaction / Update Pattern
**Source:** `lib/chimeway/workflows/progression.ex`
**Apply to:** Exhaustion and stop condition logic. When adding `stop_run/6` or `complete_run/5`, the pattern mandates executing `Workflows.update_run/3` and `Workflows.append_transition/2` within the pre-existing `Repo.transaction/1` loop block, returning `{:ok, {:completed, run}}` or `{:ok, {:stopped, run}}`.

## No Analog Found

*(None. All required modifications map directly to existing files and patterns)*

## Metadata

**Analog search scope:** `lib/chimeway/workflows/`, `priv/repo/migrations/`
**Files scanned:** 4
**Pattern extraction date:** 2024-05-24

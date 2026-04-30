# Phase 26: Escalations & Stop Conditions - Research

**Researched:** 2024-05-18 (Current Date)
**Domain:** Workflow Engine / Progression Semantics
**Confidence:** HIGH

## Summary

Phase 26 focuses on introducing robust stop and completion conditions to the workflow progression engine. The progression DSL must support explicit `{"kind": "stop", "outcome": "some_outcome"}` rules. Additionally, the engine must support implicit completion: when a step reaches a branchable/terminal outcome and no `on_outcome`, `stop`, or `wait_until` progression rules match, the workflow should be implicitly transitioned to a `:completed` state to prevent it from hanging indefinitely in `:active`. 

Both explicit stop and implicit completion conditions must be logged to the `chimeway_workflow_transitions` table and correctly update the `chimeway_workflow_runs` table state.

**Primary recommendation:** Extend `Progression.evaluate_step/5` to evaluate terminal stop rules alongside `on_outcome` rules, falling back to implicit `:completed` transition when the prior delivery outcome is branchable but no rules match. 

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Rule Evaluation (`stop`) | API / Backend (`Progression`) | — | Workflow DSL logic belongs inside `Progression.evaluate_step/5`. |
| Implicit Completion | API / Backend (`Progression`) | — | Evaluated strictly when `outcome` is branchable but `rules` lack any match. |
| State Normalization | API / Backend (`WorkflowProgressionWorker`) | — | Oban workers must gracefully map the new `{:stopped, run}` and `{:completed, run}` tuples to `:ok`. |
| Persistence | Database / Storage (`Repo`) | — | Ecto changesets gracefully support string-backed enumerations for states. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Ecto | ~> 3.10 (assumed based on Elixir typical version) | ORM/Data Mapping | Ecto `Ecto.Enum` maps natively to our varchar columns. |

## Architecture Patterns

### Pattern 1: Terminal Transition Delegates
**What:** Just as `advance_run` and `enter_waiting` map to specific state transitions with explicit reasons, we will introduce `stop_run` and `complete_run` to handle the terminal side of progression evaluation.
**When to use:** In `Progression.evaluate_step/5` when matching a `stop` rule or defaulting to completion.
**Example:**
```elixir
defp stop_run(repo, run, step, delivery, rule, outcome, evidence, now) do
  outcome_string = Atom.to_string(outcome)
  context = %{
    "rule_kind" => "stop",
    "workflow_outcome" => outcome_string,
    "anchor_delivery_id" => delivery.id,
    "from_step" => step.step_key
  } |> maybe_put_evidence(evidence)

  with {:ok, _transition} <- Workflows.append_transition(repo, %{
         workflow_run_id: run.id,
         workflow_step_id: step.id,
         delivery_id: delivery.id,
         from_state: :active,
         to_state: :stopped,
         reason: "workflow_stopped",
         context: context,
         inserted_at: now
       }),
       {:ok, updated_run} <- Workflows.update_run(repo, run, %{
         state: :stopped,
         last_transition_at: now,
         status_reason: "workflow_stopped",
         status_context: context
       }) do
    {:ok, {:stopped, updated_run}}
  end
end
```

### Anti-Patterns to Avoid
- **Database Migrations for Enum Expansion:** We **DO NOT** need to generate a new database migration. The `state`, `from_state`, and `to_state` columns on `chimeway_workflow_runs` and `chimeway_workflow_transitions` are backed by PostgreSQL `:string` types, not native PostgreSQL enums. The Ecto schemas simply validate inclusion in `[:active, :waiting, :completed, :stopped]`. The states `:stopped` and `:completed` are already in `@state_values` lists in the respective schema modules!

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Rule Match Extraction | Hand-rolling multiple `Enum.find` | A unified `match_terminal_rule` pipeline | Both `on_outcome` and `stop` rules match on the `outcome` field; evaluating them in a single pass prevents conflicting evaluations. |

## Common Pitfalls

### Pitfall 1: Unhandled Result Tuples in the Worker
**What goes wrong:** The Oban worker crashes and continuously retries, causing log spam.
**Why it happens:** When `progress_run/2` starts returning `{:ok, {:completed, run}}` and `{:ok, {:stopped, run}}`, the `Chimeway.Dispatch.WorkflowProgressionWorker.normalize_progress_result/1` function will fail to pattern match because it currently only understands `{:advanced, ...}`, `{:waiting, ...}`, and `{:noop, ...}`.
**How to avoid:** Explicitly add `defp normalize_progress_result({:ok, {:completed, _run}}), do: :ok` and `defp normalize_progress_result({:ok, {:stopped, _run}}), do: :ok` in `lib/chimeway/dispatch/workflow_progression_worker.ex`.
**Warning signs:** Worker crashes with `FunctionClauseError`.

### Pitfall 2: Implicit Completion on Non-Terminal Deliveries
**What goes wrong:** A workflow completes prematurely while the delivery is still in progress.
**Why it happens:** If the code falls back to `complete_run` when the delivery outcome is still `:not_branchable_yet` (e.g. `:dispatched` or `:pending`).
**How to avoid:** Ensure implicit completion is only evaluated when `ProgressionOutcome.from_delivery/2` returns `{:branchable, branchable_outcome, evidence}`. If it returns `:not_branchable_yet`, it must continue to return `{:noop, run, :no_matching_progress_rule}` (or `:no_progress_rules`).

## Code Examples

### Evaluation Flow Refactoring (`evaluate_step/5`)
```elixir
defp evaluate_step(repo, run, step, delivery, now) do
  rules = step.config |> Map.get("progress", []) |> List.wrap()
  outcome = ProgressionOutcome.from_delivery(delivery, latest_attempt(delivery))

  case match_rule(rules, outcome) do
    {:match, %{"kind" => "on_outcome"} = rule, branchable_outcome, evidence} ->
      advance_run(repo, run, step, delivery, rule, branchable_outcome, evidence, now)

    {:match, %{"kind" => "stop"} = rule, branchable_outcome, evidence} ->
      stop_run(repo, run, step, delivery, rule, branchable_outcome, evidence, now)

    :no_match ->
      case match_wait_until(rules, outcome) do
        {:match, rule} ->
          enter_waiting(repo, run, step, delivery, rule, now)

        :no_match ->
          case outcome do
            {:branchable, branchable_outcome, evidence} ->
              complete_run(repo, run, step, delivery, branchable_outcome, evidence, now)
            :not_branchable_yet ->
              reason = if rules == [], do: :no_progress_rules, else: :no_matching_progress_rule
              {:noop, run, reason}
          end

        {:not_branchable, _rule} ->
          {:noop, run, :prior_delivery_not_converged}
      end
  end
end

defp match_rule(rules, {:branchable, outcome, evidence}) do
  outcome_string = Atom.to_string(outcome)

  rules
  |> Enum.find(fn rule ->
    (rule["kind"] in ["on_outcome", "stop"]) and rule["outcome"] == outcome_string
  end)
  |> case do
    nil -> :no_match
    rule -> {:match, rule, outcome, evidence}
  end
end

defp match_rule(_rules, :not_branchable_yet), do: :no_match
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Workflows hang indefinitely in `:active` | Implicit completion | Phase 26 | Prevents orphaned active workflow runs when terminal delivery outcomes have no matching progression rules. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | No database migration is needed | Architecture Patterns | The schema may not match database strict enums if the migration used pure PostgreSQL ENUM types instead of `VARCHAR`. I verified the migration file `20260429170100_create_chimeway_workflow_runs.exs` uses `add(:state, :string, null: false)`! Risk is 0, but noted. |

## Open Questions (RESOLVED)

1. **RESOLVED: Wait Until and Completion**
   - What we know: `wait_until` currently fires when the outcome is `{:branchable, ...}`. If a `wait_until` matches, we transition to `:waiting`.
   - What's unclear: Can a workflow step have *only* a `wait_until` rule? If so, when the wait elapses, what is the outcome? `advance_after_wait` explicitly uses the `to_step` defined in the `status_context`. So implicit completion won't be hit post-wait. No conflict exists.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config file | none — see Wave 0 |
| Quick run command | `mix test {file_path}` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-26 | Stop rule evaluates correctly | unit/integration | `mix test test/chimeway/orchestration/workflow_progression_test.exs` | ✅ Wave 0 |
| REQ-26 | Implicit completion defaults correctly | unit/integration | `mix test test/chimeway/orchestration/workflow_progression_test.exs` | ✅ Wave 0 |
| REQ-26 | Oban worker gracefully handles new tuples | unit | `mix test test/chimeway/dispatch/workflow_progression_worker_test.exs` | ✅ Wave 0 |

## Sources

### Primary (HIGH confidence)
- `lib/chimeway/workflows/workflow_run.ex` - Checked existing validation schemas (already includes `[:active, :waiting, :completed, :stopped]`).
- `priv/repo/migrations/20260429170100_create_chimeway_workflow_runs.exs` - Checked PostgreSQL column types (they are `:string`, no ENUM types to migrate).
- `lib/chimeway/workflows/progression.ex` - Checked the active layout of `evaluate_step/5` and logic for rules vs empty lists.
- `lib/chimeway/dispatch/workflow_progression_worker.ex` - Identified the missing result patterns in `normalize_progress_result/1`.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Core standard DB structure aligns optimally.
- Architecture: HIGH - Simple extensions aligned to `advance_run` pattern.
- Pitfalls: HIGH - Extracted direct risk matching the Oban worker's explicit result normalization.

**Research date:** 2024-05-18
**Valid until:** 30 days

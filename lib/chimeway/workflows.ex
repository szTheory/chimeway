defmodule Chimeway.Workflows do
  @moduledoc "Persistence helpers for durable workflow definitions and ordered step rows."

  import Ecto.Query

  alias Ecto.Multi
  alias Chimeway.Repo

  alias Chimeway.Workflows.{
    WorkflowDefinition,
    WorkflowRun,
    WorkflowStep,
    WorkflowTransition
  }

  @active_state :active
  @trigger_context %{"source" => "trigger"}
  @workflow_started_reason "workflow_started"
  @step_activated_reason "step_activated"

  @spec upsert_definition(String.t(), Chimeway.Notifier.workflow_resolution()) ::
          {:ok, WorkflowDefinition.t()} | {:error, term()}
  def upsert_definition(notification_key, workflow)
      when is_binary(notification_key) and is_map(workflow) do
    Multi.new()
    |> Multi.run(:workflow_definition, fn repo, _changes ->
      ensure_definition(repo, notification_key, workflow)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{workflow_definition: definition}} -> {:ok, preload_steps(Repo, definition)}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  @spec ensure_definition(Ecto.Repo.t(), String.t(), Chimeway.Notifier.workflow_resolution()) ::
          {:ok, WorkflowDefinition.t()} | {:error, term()}
  def ensure_definition(repo, notification_key, workflow)
      when is_binary(notification_key) and is_map(workflow) do
    definition_attrs = %{
      workflow_key: workflow.workflow_key,
      workflow_version: workflow.workflow_version,
      notification_key: notification_key
    }

    definition_changeset = WorkflowDefinition.changeset(%WorkflowDefinition{}, definition_attrs)

    with {:ok, _definition} <-
           repo.insert(definition_changeset,
             on_conflict: [
               set: [notification_key: notification_key, updated_at: DateTime.utc_now()]
             ],
             conflict_target: [:workflow_key, :workflow_version]
           ) do
      definition =
        repo.get_by!(WorkflowDefinition,
          workflow_key: workflow.workflow_key,
          workflow_version: workflow.workflow_version
        )
        |> then(&preload_steps(repo, &1))

      case definition.steps do
        [] ->
          with {:ok, _steps} <- insert_steps(repo, definition.id, workflow.steps) do
            {:ok, preload_steps(repo, definition)}
          end

        persisted_steps ->
          if same_steps?(persisted_steps, workflow.steps) do
            {:ok, definition}
          else
            {:error, :workflow_definition_version_conflict}
          end
      end
    end
  end

  @spec fetch_definition(String.t(), pos_integer()) ::
          {:ok, WorkflowDefinition.t() | nil} | {:error, term()}
  def fetch_definition(workflow_key, workflow_version)
      when is_binary(workflow_key) and is_integer(workflow_version) do
    {:ok,
     Repo.get_by(WorkflowDefinition,
       workflow_key: workflow_key,
       workflow_version: workflow_version
     )
     |> preload_steps(Repo)}
  end

  @spec persisted_workflow(Ecto.UUID.t() | map()) ::
          {:ok, Chimeway.Notifier.workflow_resolution() | nil} | {:error, term()}
  def persisted_workflow(%{workflow_definition_id: nil}), do: {:ok, nil}

  def persisted_workflow(%{workflow_definition_id: workflow_definition_id})
      when is_binary(workflow_definition_id) do
    persisted_workflow(workflow_definition_id)
  end

  def persisted_workflow(workflow_definition_id) when is_binary(workflow_definition_id) do
    case Repo.get(WorkflowDefinition, workflow_definition_id) |> then(&preload_steps(Repo, &1)) do
      nil ->
        {:ok, nil}

      definition ->
        {:ok,
         %{
           workflow_key: definition.workflow_key,
           workflow_version: definition.workflow_version,
           source: :planner_override,
           steps:
             Enum.map(definition.steps, fn step ->
               %{
                 step_key: step.step_key,
                 step_order: step.step_order,
                 channel: step.channel,
                 config: step.config || %{}
               }
             end)
         }}
    end
  end

  @spec active_step_linkage(Ecto.UUID.t() | map()) ::
          {:ok,
           %{
             workflow_run_id: Ecto.UUID.t(),
             workflow_step_id: Ecto.UUID.t(),
             channel: String.t()
           }
           | nil}
          | {:error, term()}
  def active_step_linkage(%{id: notification_id}) when is_binary(notification_id) do
    active_step_linkage(notification_id)
  end

  def active_step_linkage(notification_id) when is_binary(notification_id) do
    query =
      from(wr in WorkflowRun,
        join: ws in WorkflowStep,
        on: wr.current_step_id == ws.id,
        where: wr.notification_id == ^notification_id,
        select: %{
          workflow_run_id: wr.id,
          workflow_step_id: ws.id,
          channel: ws.channel
        }
      )

    {:ok, Repo.one(query)}
  end

  @spec create_initial_run(Ecto.Repo.t(), Ecto.UUID.t(), WorkflowDefinition.t(), DateTime.t()) ::
          {:ok, WorkflowRun.t()} | {:error, term()}
  def create_initial_run(repo, notification_id, %WorkflowDefinition{} = definition, timestamp)
      when is_binary(notification_id) do
    definition = preload_steps(repo, definition)

    with {:ok, first_step} <- fetch_first_step(definition),
         {:ok, workflow_run} <-
           repo.insert(
             WorkflowRun.changeset(%WorkflowRun{}, %{
               notification_id: notification_id,
               workflow_definition_id: definition.id,
               current_step_id: first_step.id,
               tenant_id: "default",
               state: @active_state,
               started_at: timestamp,
               last_transition_at: timestamp,
               status_reason: @workflow_started_reason,
               status_context: @trigger_context
             })
           ),
         {:ok, _started_transition} <-
           insert_transition(repo, %{
             workflow_run_id: workflow_run.id,
             to_state: @active_state,
             reason: @workflow_started_reason,
             context: @trigger_context,
             inserted_at: timestamp
           }),
         {:ok, _activated_transition} <-
           insert_transition(repo, %{
             workflow_run_id: workflow_run.id,
             workflow_step_id: first_step.id,
             from_state: @active_state,
             to_state: @active_state,
             reason: @step_activated_reason,
             context: Map.put(@trigger_context, "step_key", first_step.step_key),
             inserted_at: timestamp
           }) do
      {:ok, workflow_run}
    end
  end

  @doc """
  Returns the canonical workflow_run row by id, raising if not found. Used by
  the progression service after locking the row inside its transaction.
  """
  @spec get_run!(Ecto.UUID.t()) :: WorkflowRun.t()
  def get_run!(workflow_run_id) when is_binary(workflow_run_id) do
    Repo.get!(WorkflowRun, workflow_run_id)
  end

  @doc """
  Locks a workflow run for update inside the given repo and returns it. Returns
  `{:error, :workflow_run_not_found}` if the row no longer exists. Must be
  invoked inside a transaction.
  """
  @spec lock_run(Ecto.Repo.t(), Ecto.UUID.t()) ::
          {:ok, WorkflowRun.t()} | {:error, :workflow_run_not_found}
  def lock_run(repo, workflow_run_id) when is_binary(workflow_run_id) do
    case repo.one(from(wr in WorkflowRun, where: wr.id == ^workflow_run_id, lock: "FOR UPDATE")) do
      nil -> {:error, :workflow_run_not_found}
      run -> {:ok, run}
    end
  end

  @doc """
  Returns the active workflow_step row for a workflow_run, raising if none.
  """
  @spec get_current_step!(WorkflowRun.t()) :: WorkflowStep.t()
  def get_current_step!(%WorkflowRun{current_step_id: current_step_id})
      when is_binary(current_step_id) do
    Repo.get!(WorkflowStep, current_step_id)
  end

  @doc """
  Looks up a workflow_step by step_key inside the same workflow definition.
  Returns `nil` if the step does not exist — callers treat this as a noop
  rather than crashing the progression transaction.
  """
  @spec fetch_step_by_key(Ecto.UUID.t(), String.t()) :: WorkflowStep.t() | nil
  def fetch_step_by_key(workflow_definition_id, step_key)
      when is_binary(workflow_definition_id) and is_binary(step_key) do
    Repo.one(
      from(ws in WorkflowStep,
        where: ws.workflow_definition_id == ^workflow_definition_id and ws.step_key == ^step_key
      )
    )
  end

  @doc """
  Appends one workflow_transition row using the supplied repo (so callers can
  participate in the progression transaction). Required keys: `workflow_run_id`,
  `to_state`, and `reason`. Optional keys: `workflow_step_id`, `delivery_id`,
  `from_state`, `context`, `inserted_at`.
  """
  @spec append_transition(Ecto.Repo.t(), map()) ::
          {:ok, WorkflowTransition.t()} | {:error, Ecto.Changeset.t()}
  def append_transition(repo, attrs) when is_map(attrs) do
    insert_transition(repo, attrs)
  end

  @doc """
  Updates a workflow run row with the supplied fields. Used by the progression
  service to record waiting state and reason/context, advance the current step
  cursor, or reactivate a previously waiting run.
  """
  @spec update_run(Ecto.Repo.t(), WorkflowRun.t(), map()) ::
          {:ok, WorkflowRun.t()} | {:error, Ecto.Changeset.t()}
  def update_run(repo, %WorkflowRun{} = run, attrs) when is_map(attrs) do
    run
    |> Ecto.Changeset.change(attrs)
    |> repo.update()
  end

  defp preload_steps(_repo, nil), do: nil

  defp preload_steps(repo, definition) do
    repo.preload(definition, [steps: from(step in WorkflowStep, order_by: [asc: step.step_order])],
      force: true
    )
  end

  defp insert_steps(repo, workflow_definition_id, step_attrs) do
    Enum.reduce_while(step_attrs, {:ok, []}, fn step_attr, {:ok, inserted_steps} ->
      attrs = Map.put(step_attr, :workflow_definition_id, workflow_definition_id)

      case repo.insert(WorkflowStep.changeset(%WorkflowStep{}, attrs)) do
        {:ok, step} -> {:cont, {:ok, [step | inserted_steps]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, inserted_steps} -> {:ok, Enum.reverse(inserted_steps)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_first_step(%WorkflowDefinition{steps: [first_step | _rest]}), do: {:ok, first_step}

  defp fetch_first_step(%WorkflowDefinition{steps: []}),
    do: {:error, :workflow_definition_missing_steps}

  defp insert_transition(repo, attrs) do
    repo.insert(WorkflowTransition.changeset(%WorkflowTransition{}, attrs))
  end

  defp same_steps?(persisted_steps, workflow_steps) do
    normalize_persisted_steps(persisted_steps) == normalize_workflow_steps(workflow_steps)
  end

  defp normalize_persisted_steps(steps) do
    steps
    |> Enum.map(fn step ->
      %{
        step_key: step.step_key,
        step_order: step.step_order,
        channel: step.channel,
        config: step.config || %{}
      }
    end)
    |> Enum.sort_by(& &1.step_order)
  end

  defp normalize_workflow_steps(steps) do
    steps
    |> Enum.map(fn step ->
      %{
        step_key: step.step_key,
        step_order: step.step_order,
        channel: step.channel,
        config: Map.get(step, :config) || Map.get(step, "config") || %{}
      }
    end)
    |> Enum.sort_by(& &1.step_order)
  end
end

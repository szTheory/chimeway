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

    case repo.insert(definition_changeset,
           on_conflict: [
             set: [notification_key: notification_key, updated_at: DateTime.utc_now()]
           ],
           conflict_target: [:workflow_key, :workflow_version]
         ) do
      {:ok, _definition} ->
        definition =
          repo.get_by!(WorkflowDefinition,
            workflow_key: workflow.workflow_key,
            workflow_version: workflow.workflow_version
          )

        {_count, _rows} =
          repo.delete_all(
            from(step in WorkflowStep, where: step.workflow_definition_id == ^definition.id)
          )

        with {:ok, _steps} <- insert_steps(repo, definition.id, workflow.steps) do
          {:ok, preload_steps(repo, definition)}
        end

      {:error, reason} ->
        {:error, reason}
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

  defp preload_steps(_repo, nil), do: nil

  defp preload_steps(repo, definition) do
    repo.preload(definition, steps: from(step in WorkflowStep, order_by: [asc: step.step_order]))
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
end

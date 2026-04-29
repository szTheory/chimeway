defmodule Chimeway.Workflows do
  @moduledoc "Persistence helpers for durable workflow definitions and ordered step rows."

  import Ecto.Query

  alias Ecto.Multi
  alias Chimeway.Repo
  alias Chimeway.Workflows.{WorkflowDefinition, WorkflowStep}

  @spec upsert_definition(String.t(), Chimeway.Notifier.workflow_resolution()) ::
          {:ok, WorkflowDefinition.t()} | {:error, term()}
  def upsert_definition(notification_key, workflow)
      when is_binary(notification_key) and is_map(workflow) do
    definition_attrs = %{
      workflow_key: workflow.workflow_key,
      workflow_version: workflow.workflow_version,
      notification_key: notification_key
    }

    step_attrs = Enum.map(workflow.steps, &Map.take(&1, [:step_key, :step_order, :channel, :config]))

    Multi.new()
    |> Multi.run(:workflow_definition, fn repo, _changes ->
      definition_changeset = WorkflowDefinition.changeset(%WorkflowDefinition{}, definition_attrs)

      case repo.insert(definition_changeset,
             on_conflict: [set: [notification_key: notification_key, updated_at: DateTime.utc_now()]],
             conflict_target: [:workflow_key, :workflow_version]
           ) do
        {:ok, _definition} ->
          {:ok,
           repo.get_by!(WorkflowDefinition,
             workflow_key: workflow.workflow_key,
             workflow_version: workflow.workflow_version
           )}

        {:error, reason} ->
          {:error, reason}
      end
    end)
    |> Multi.delete_all(:delete_steps, fn %{workflow_definition: definition} ->
      from(step in WorkflowStep, where: step.workflow_definition_id == ^definition.id)
    end)
    |> Multi.run(:insert_steps, fn repo, %{workflow_definition: definition} ->
      insert_steps(repo, definition.id, step_attrs)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{workflow_definition: definition}} -> {:ok, preload_steps(definition)}
      {:error, _operation, reason, _changes} -> {:error, reason}
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
     |> preload_steps()}
  end

  defp preload_steps(nil), do: nil

  defp preload_steps(definition) do
    Repo.preload(definition, steps: from(step in WorkflowStep, order_by: [asc: step.step_order]))
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
end

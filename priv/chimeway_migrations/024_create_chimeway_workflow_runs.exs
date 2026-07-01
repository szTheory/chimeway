# chimeway_migration: create_chimeway_workflow_runs
defmodule Chimeway.Repo.Migrations.CreateChimewayWorkflowRuns do
  use Ecto.Migration

  @chimeway_prefix __CHIMEWAY_PREFIX__

  def change do
    create chimeway_table(:chimeway_workflow_runs, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(
        :notification_id,
        chimeway_references(:chimeway_notifications, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(
        :workflow_definition_id,
        chimeway_references(:chimeway_workflow_definitions, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(
        :current_step_id,
        chimeway_references(:chimeway_workflow_steps, type: :uuid, on_delete: :restrict),
        null: false
      )

      add(:state, :string, null: false)
      add(:started_at, :utc_datetime_usec, null: false)
      add(:last_transition_at, :utc_datetime_usec, null: false)
      add(:status_reason, :string, null: false)
      add(:status_context, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec)
    end

    create(
      chimeway_unique_index(:chimeway_workflow_runs, [:notification_id],
        name: :chimeway_workflow_runs_notification_id_index
      )
    )

    create(chimeway_index(:chimeway_workflow_runs, [:workflow_definition_id]))
    create(chimeway_index(:chimeway_workflow_runs, [:current_step_id]))
    create(chimeway_index(:chimeway_workflow_runs, [:state]))
  end

  defp chimeway_prefix_opts(opts \\ []) do
    if @chimeway_prefix do
      Keyword.put_new(opts, :prefix, @chimeway_prefix)
    else
      opts
    end
  end

  defp chimeway_table(name, opts \\ []) do
    table(name, chimeway_prefix_opts(opts))
  end

  defp chimeway_index(table_name, columns, opts \\ []) do
    index(table_name, columns, chimeway_prefix_opts(opts))
  end

  defp chimeway_unique_index(table_name, columns, opts \\ []) do
    unique_index(table_name, columns, chimeway_prefix_opts(opts))
  end

  defp chimeway_references(table_name, opts \\ []) do
    references(table_name, chimeway_prefix_opts(opts))
  end
end

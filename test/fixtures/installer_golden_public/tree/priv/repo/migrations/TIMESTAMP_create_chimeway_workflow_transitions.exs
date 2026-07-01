# chimeway_migration: create_chimeway_workflow_transitions
defmodule InstallerHost.Repo.Migrations.CreateChimewayWorkflowTransitions do
  use Ecto.Migration

  @chimeway_prefix false

  def change do
    create chimeway_table(:chimeway_workflow_transitions, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(
        :workflow_run_id,
        chimeway_references(:chimeway_workflow_runs, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(
        :workflow_step_id,
        chimeway_references(:chimeway_workflow_steps, type: :uuid, on_delete: :nilify_all)
      )

      add(
        :delivery_id,
        chimeway_references(:chimeway_deliveries, type: :uuid, on_delete: :nilify_all)
      )

      add(:from_state, :string)
      add(:to_state, :string, null: false)
      add(:reason, :string, null: false)
      add(:context, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(chimeway_index(:chimeway_workflow_transitions, [:workflow_run_id, :inserted_at]))
    create(chimeway_index(:chimeway_workflow_transitions, [:workflow_step_id]))
    create(chimeway_index(:chimeway_workflow_transitions, [:delivery_id]))
    create(chimeway_index(:chimeway_workflow_transitions, [:reason]))
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

  defp chimeway_references(table_name, opts \\ []) do
    references(table_name, chimeway_prefix_opts(opts))
  end
end

# chimeway_migration: create_chimeway_workflow_steps
defmodule Chimeway.Repo.Migrations.CreateChimewayWorkflowSteps do
  use Ecto.Migration

  @chimeway_prefix __CHIMEWAY_PREFIX__

  def change do
    create chimeway_table(:chimeway_workflow_steps, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(
        :workflow_definition_id,
        chimeway_references(:chimeway_workflow_definitions, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:step_key, :string, null: false)
      add(:step_order, :integer, null: false)
      add(:channel, :string, null: false)
      add(:config, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec)
    end

    create(chimeway_index(:chimeway_workflow_steps, [:workflow_definition_id]))

    create(
      chimeway_unique_index(:chimeway_workflow_steps, [:workflow_definition_id, :step_key],
        name: :chimeway_workflow_steps_definition_id_step_key_index
      )
    )

    create(
      chimeway_unique_index(:chimeway_workflow_steps, [:workflow_definition_id, :step_order],
        name: :chimeway_workflow_steps_definition_id_step_order_index
      )
    )
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

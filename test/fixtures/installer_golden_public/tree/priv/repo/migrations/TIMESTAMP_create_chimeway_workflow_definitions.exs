# chimeway_migration: create_chimeway_workflow_definitions
defmodule InstallerHost.Repo.Migrations.CreateChimewayWorkflowDefinitions do
  use Ecto.Migration

  @chimeway_prefix false

  def change do
    create chimeway_table(:chimeway_workflow_definitions, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:workflow_key, :string, null: false)
      add(:workflow_version, :integer, null: false)
      add(:notification_key, :string, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(
      chimeway_unique_index(:chimeway_workflow_definitions, [:workflow_key, :workflow_version],
        name: :chimeway_workflow_definitions_workflow_key_workflow_version_index
      )
    )

    create(chimeway_index(:chimeway_workflow_definitions, [:notification_key]))
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
end

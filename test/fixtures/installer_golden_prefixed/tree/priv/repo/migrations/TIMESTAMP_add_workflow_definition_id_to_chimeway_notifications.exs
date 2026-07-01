# chimeway_migration: add_workflow_definition_id_to_chimeway_notifications
defmodule InstallerHost.Repo.Migrations.AddWorkflowDefinitionIdToChimewayNotifications do
  use Ecto.Migration

  @chimeway_prefix "chimeway"

  def change do
    alter chimeway_table(:chimeway_notifications) do
      add(
        :workflow_definition_id,
        chimeway_references(:chimeway_workflow_definitions, type: :uuid, on_delete: :nilify_all)
      )
    end

    create(chimeway_index(:chimeway_notifications, [:workflow_definition_id]))
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

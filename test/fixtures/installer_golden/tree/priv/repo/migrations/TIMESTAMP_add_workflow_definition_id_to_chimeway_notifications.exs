# chimeway_migration: add_workflow_definition_id_to_chimeway_notifications
defmodule InstallerHost.Repo.Migrations.AddWorkflowDefinitionIdToChimewayNotifications do
  use Ecto.Migration

  def change do
    alter table(:chimeway_notifications) do
      add(
        :workflow_definition_id,
        references(:chimeway_workflow_definitions, type: :uuid, on_delete: :nilify_all)
      )
    end

    create(index(:chimeway_notifications, [:workflow_definition_id]))
  end
end

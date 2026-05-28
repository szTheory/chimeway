# chimeway_migration: alter_chimeway_deliveries_for_workflow_linkage
defmodule InstallerHost.Repo.Migrations.AlterChimewayDeliveriesForWorkflowLinkage do
  use Ecto.Migration

  def change do
    alter table(:chimeway_deliveries) do
      add(
        :workflow_run_id,
        references(:chimeway_workflow_runs, type: :binary_id, on_delete: :nilify_all)
      )

      add(
        :workflow_step_id,
        references(:chimeway_workflow_steps, type: :binary_id, on_delete: :nilify_all)
      )
    end

    create(index(:chimeway_deliveries, [:workflow_run_id]))
    create(index(:chimeway_deliveries, [:workflow_step_id]))
  end
end

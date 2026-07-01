# chimeway_migration: alter_chimeway_deliveries_for_workflow_linkage
defmodule InstallerHost.Repo.Migrations.AlterChimewayDeliveriesForWorkflowLinkage do
  use Ecto.Migration

  @chimeway_prefix "chimeway"

  def change do
    alter chimeway_table(:chimeway_deliveries) do
      add(
        :workflow_run_id,
        chimeway_references(:chimeway_workflow_runs, type: :binary_id, on_delete: :nilify_all)
      )

      add(
        :workflow_step_id,
        chimeway_references(:chimeway_workflow_steps, type: :binary_id, on_delete: :nilify_all)
      )
    end

    create(chimeway_index(:chimeway_deliveries, [:workflow_run_id]))
    create(chimeway_index(:chimeway_deliveries, [:workflow_step_id]))
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

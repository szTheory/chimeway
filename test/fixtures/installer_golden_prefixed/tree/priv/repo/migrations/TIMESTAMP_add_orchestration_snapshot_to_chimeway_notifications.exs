# chimeway_migration: add_orchestration_snapshot_to_chimeway_notifications
defmodule InstallerHost.Repo.Migrations.AddOrchestrationSnapshotToChimewayNotifications do
  use Ecto.Migration

  @chimeway_prefix "chimeway"

  def up do
    alter chimeway_table(:chimeway_notifications) do
      add(:orchestration, :map, null: false, default: %{})
    end
  end

  def down do
    alter chimeway_table(:chimeway_notifications) do
      remove(:orchestration)
    end
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
end

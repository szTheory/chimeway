defmodule Chimeway.Repo.Migrations.AddOrchestrationSnapshotToChimewayNotifications do
  use Ecto.Migration

  def up do
    alter table(:chimeway_notifications) do
      add(:orchestration, :map, null: false, default: %{})
    end
  end

  def down do
    alter table(:chimeway_notifications) do
      remove(:orchestration)
    end
  end
end

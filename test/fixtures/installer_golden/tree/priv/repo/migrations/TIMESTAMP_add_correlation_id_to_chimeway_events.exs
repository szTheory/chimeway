# chimeway_migration: add_correlation_id_to_chimeway_events
defmodule InstallerHost.Repo.Migrations.AddCorrelationIdToChimewayEvents do
  use Ecto.Migration

  def change do
    alter table(:chimeway_events) do
      add :correlation_id, :string, null: true
    end

    create index(:chimeway_events, [:correlation_id])
  end
end

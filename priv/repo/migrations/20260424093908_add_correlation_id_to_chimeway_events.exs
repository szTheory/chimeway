defmodule Chimeway.Repo.Migrations.AddCorrelationIdToChimewayEvents do
  use Ecto.Migration

  def change do
    alter table(:chimeway_events) do
      add :correlation_id, :string, null: true
    end

    create index(:chimeway_events, [:correlation_id])
  end
end

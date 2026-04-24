defmodule Chimeway.Repo.Migrations.CreateChimewayEvents do
  use Ecto.Migration

  def change do
    create table(:chimeway_events, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :notification_key, :string, null: false
      add :notification_version, :integer, null: false
      add :idempotency_key, :string, null: false
      add :payload, :map, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:chimeway_events, [:idempotency_key],
             name: :chimeway_events_idempotency_key_index
           )
  end
end

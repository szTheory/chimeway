# chimeway_migration: create_chimeway_deliveries
defmodule Chimeway.Repo.Migrations.CreateChimewayDeliveries do
  use Ecto.Migration

  def change do
    create table(:chimeway_deliveries, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :notification_id,
          references(:chimeway_notifications, type: :uuid, on_delete: :delete_all),
          null: false

      add :channel, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :suppression_reason, :string
      add :delay_fallback, :boolean, null: false, default: false
      add :metadata, :map

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:chimeway_deliveries, [:notification_id, :channel],
             name: :chimeway_deliveries_notification_channel_index
           )

    create index(:chimeway_deliveries, [:notification_id])
  end
end

# chimeway_migration: create_chimeway_delivery_attempts
defmodule Chimeway.Repo.Migrations.CreateChimewayDeliveryAttempts do
  use Ecto.Migration

  def change do
    create table(:chimeway_delivery_attempts, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :delivery_id,
          references(:chimeway_deliveries, type: :uuid, on_delete: :delete_all),
          null: false

      add :outcome, :string, null: false
      add :provider_response, :map
      add :inserted_at, :utc_datetime_usec, null: false
    end

    create index(:chimeway_delivery_attempts, [:delivery_id])
  end
end

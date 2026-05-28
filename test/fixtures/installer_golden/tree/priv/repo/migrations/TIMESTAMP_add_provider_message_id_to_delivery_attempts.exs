# chimeway_migration: add_provider_message_id_to_delivery_attempts
defmodule InstallerHost.Repo.Migrations.AddProviderMessageIdToDeliveryAttempts do
  use Ecto.Migration

  def change do
    alter table(:chimeway_delivery_attempts) do
      add :provider_message_id, :string, default: nil
    end

    create index(:chimeway_delivery_attempts, [:provider_message_id])
  end
end

defmodule Chimeway.Repo.Migrations.AddProviderMessageIdToDeliveryAttempts do
  use Ecto.Migration

  def change do
    alter table(:chimeway_delivery_attempts) do
      add :provider_message_id, :string, default: nil
    end

    create index(:chimeway_delivery_attempts, [:provider_message_id])
  end
end

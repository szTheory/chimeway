defmodule Chimeway.Repo.Migrations.AddAdapterModuleToChimewayDeliveryAttempts do
  use Ecto.Migration

  def change do
    alter table(:chimeway_delivery_attempts) do
      add :adapter_module, :string, null: true
    end
  end
end

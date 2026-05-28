# chimeway_migration: add_adapter_module_to_chimeway_delivery_attempts
defmodule Chimeway.Repo.Migrations.AddAdapterModuleToChimewayDeliveryAttempts do
  use Ecto.Migration

  def change do
    alter table(:chimeway_delivery_attempts) do
      add :adapter_module, :string, null: true
    end
  end
end

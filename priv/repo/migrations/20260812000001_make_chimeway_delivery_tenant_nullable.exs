defmodule Chimeway.Repo.Migrations.MakeChimewayDeliveryTenantNullable do
  use Ecto.Migration

  def up do
    alter table(:chimeway_deliveries) do
      modify(:tenant_id, :string, null: true)
    end
  end

  def down do
    raise "delivery tenant ownership reconciliation requires nullable legacy rows; migration is irreversible"
  end
end

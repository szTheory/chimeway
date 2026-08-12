# chimeway_migration: make_chimeway_delivery_tenant_nullable
defmodule InstallerHost.Repo.Migrations.MakeChimewayDeliveryTenantNullable do
  use Ecto.Migration

  @chimeway_prefix "chimeway"

  def up do
    alter chimeway_table(:chimeway_deliveries) do
      modify(:tenant_id, :string, null: true)
    end
  end

  def down do
    raise "delivery tenant ownership reconciliation requires nullable legacy rows; migration is irreversible"
  end

  defp chimeway_prefix_opts(opts \\ []) do
    if @chimeway_prefix, do: Keyword.put_new(opts, :prefix, @chimeway_prefix), else: opts
  end

  defp chimeway_table(name, opts \\ []), do: table(name, chimeway_prefix_opts(opts))
end

# chimeway_migration: add_adapter_module_to_chimeway_delivery_attempts
defmodule InstallerHost.Repo.Migrations.AddAdapterModuleToChimewayDeliveryAttempts do
  use Ecto.Migration

  @chimeway_prefix false

  def change do
    alter chimeway_table(:chimeway_delivery_attempts) do
      add(:adapter_module, :string, null: true)
    end
  end

  defp chimeway_prefix_opts(opts \\ []) do
    if @chimeway_prefix do
      Keyword.put_new(opts, :prefix, @chimeway_prefix)
    else
      opts
    end
  end

  defp chimeway_table(name, opts \\ []) do
    table(name, chimeway_prefix_opts(opts))
  end
end

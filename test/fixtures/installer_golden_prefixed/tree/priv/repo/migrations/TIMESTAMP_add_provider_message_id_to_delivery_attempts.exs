# chimeway_migration: add_provider_message_id_to_delivery_attempts
defmodule InstallerHost.Repo.Migrations.AddProviderMessageIdToDeliveryAttempts do
  use Ecto.Migration

  @chimeway_prefix "chimeway"

  def change do
    alter chimeway_table(:chimeway_delivery_attempts) do
      add(:provider_message_id, :string, default: nil)
    end

    create(chimeway_index(:chimeway_delivery_attempts, [:provider_message_id]))
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

  defp chimeway_index(table_name, columns, opts \\ []) do
    index(table_name, columns, chimeway_prefix_opts(opts))
  end
end

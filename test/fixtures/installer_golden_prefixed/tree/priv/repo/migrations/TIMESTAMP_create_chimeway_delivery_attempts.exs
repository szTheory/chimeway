# chimeway_migration: create_chimeway_delivery_attempts
defmodule InstallerHost.Repo.Migrations.CreateChimewayDeliveryAttempts do
  use Ecto.Migration

  @chimeway_prefix "chimeway"

  def change do
    create chimeway_table(:chimeway_delivery_attempts, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(
        :delivery_id,
        chimeway_references(:chimeway_deliveries, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:outcome, :string, null: false)
      add(:provider_response, :map)
      add(:inserted_at, :utc_datetime_usec, null: false)
    end

    create(chimeway_index(:chimeway_delivery_attempts, [:delivery_id]))
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

  defp chimeway_references(table_name, opts \\ []) do
    references(table_name, chimeway_prefix_opts(opts))
  end
end

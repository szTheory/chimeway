# chimeway_migration: create_chimeway_deliveries
defmodule Chimeway.Repo.Migrations.CreateChimewayDeliveries do
  use Ecto.Migration

  @chimeway_prefix __CHIMEWAY_PREFIX__

  def change do
    create chimeway_table(:chimeway_deliveries, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(
        :notification_id,
        chimeway_references(:chimeway_notifications, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:channel, :string, null: false)
      add(:status, :string, null: false, default: "pending")
      add(:suppression_reason, :string)
      add(:delay_fallback, :boolean, null: false, default: false)
      add(:metadata, :map)

      timestamps(type: :utc_datetime_usec)
    end

    create(
      chimeway_unique_index(:chimeway_deliveries, [:notification_id, :channel],
        name: :chimeway_deliveries_notification_channel_index
      )
    )

    create(chimeway_index(:chimeway_deliveries, [:notification_id]))
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

  defp chimeway_unique_index(table_name, columns, opts \\ []) do
    unique_index(table_name, columns, chimeway_prefix_opts(opts))
  end

  defp chimeway_references(table_name, opts \\ []) do
    references(table_name, chimeway_prefix_opts(opts))
  end
end

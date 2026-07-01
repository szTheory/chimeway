# chimeway_migration: create_chimeway_events
defmodule InstallerHost.Repo.Migrations.CreateChimewayEvents do
  use Ecto.Migration

  @chimeway_prefix false

  def change do
    create_chimeway_schema()

    create chimeway_table(:chimeway_events, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:notification_key, :string, null: false)
      add(:notification_version, :integer, null: false)
      add(:idempotency_key, :string, null: false)
      add(:payload, :map, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(
      chimeway_unique_index(:chimeway_events, [:idempotency_key],
        name: :chimeway_events_idempotency_key_index
      )
    )
  end

  defp create_chimeway_schema do
    if @chimeway_prefix do
      execute("CREATE SCHEMA IF NOT EXISTS #{@chimeway_prefix}", fn -> :ok end)
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

  defp chimeway_unique_index(table_name, columns, opts \\ []) do
    unique_index(table_name, columns, chimeway_prefix_opts(opts))
  end
end

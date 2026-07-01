# chimeway_migration: create_chimeway_digest_memberships
defmodule InstallerHost.Repo.Migrations.CreateChimewayDigestMemberships do
  use Ecto.Migration

  @chimeway_prefix false

  def change do
    create chimeway_table(:chimeway_digest_memberships, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(
        :digest_bucket_id,
        chimeway_references(:chimeway_digest_buckets, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(
        :delivery_id,
        chimeway_references(:chimeway_deliveries, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(
        :notification_id,
        chimeway_references(:chimeway_notifications, type: :uuid, on_delete: :delete_all),
        null: false
      )

      timestamps(type: :utc_datetime_usec)
    end

    create(chimeway_index(:chimeway_digest_memberships, [:digest_bucket_id]))
    create(chimeway_index(:chimeway_digest_memberships, [:notification_id]))

    create(
      chimeway_unique_index(:chimeway_digest_memberships, [:delivery_id],
        name: :chimeway_digest_memberships_delivery_id_index
      )
    )
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

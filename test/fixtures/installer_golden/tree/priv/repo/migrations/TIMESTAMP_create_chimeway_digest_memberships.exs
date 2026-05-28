# chimeway_migration: create_chimeway_digest_memberships
defmodule InstallerHost.Repo.Migrations.CreateChimewayDigestMemberships do
  use Ecto.Migration

  def change do
    create table(:chimeway_digest_memberships, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(
        :digest_bucket_id,
        references(:chimeway_digest_buckets, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(
        :delivery_id,
        references(:chimeway_deliveries, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(
        :notification_id,
        references(:chimeway_notifications, type: :uuid, on_delete: :delete_all),
        null: false
      )

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:chimeway_digest_memberships, [:digest_bucket_id]))
    create(index(:chimeway_digest_memberships, [:notification_id]))

    create(
      unique_index(:chimeway_digest_memberships, [:delivery_id],
        name: :chimeway_digest_memberships_delivery_id_index
      )
    )
  end
end

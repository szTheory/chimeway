# chimeway_migration: alter_chimeway_digest_buckets_for_emission
defmodule InstallerHost.Repo.Migrations.AlterChimewayDigestBucketsForEmission do
  use Ecto.Migration

  def change do
    alter table(:chimeway_digest_buckets) do
      add(:flush_state, :string, null: false, default: "pending")
      add(:claimed_at, :utc_datetime_usec)
      add(:emitted_at, :utc_datetime_usec)

      add(
        :digest_delivery_id,
        references(:chimeway_deliveries, type: :uuid, on_delete: :nilify_all)
      )
    end

    create(index(:chimeway_digest_buckets, [:flush_state]))
    create(index(:chimeway_digest_buckets, [:digest_delivery_id]))
  end
end

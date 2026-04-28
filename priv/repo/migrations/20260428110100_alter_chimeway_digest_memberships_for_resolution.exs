defmodule Chimeway.Repo.Migrations.AlterChimewayDigestMembershipsForResolution do
  use Ecto.Migration

  def change do
    alter table(:chimeway_digest_memberships) do
      add(:resolution, :string)
      add(:resolution_reason, :string)
      add(:resolved_at, :utc_datetime_usec)
      add(:resolved_rule_key, :string)
      add(:resolved_rule_version, :integer)
      add(:resolved_window_starts_at, :utc_datetime_usec)
      add(:resolved_window_ends_at, :utc_datetime_usec)

      add(
        :digest_delivery_id,
        references(:chimeway_deliveries, type: :uuid, on_delete: :nilify_all)
      )
    end

    create(index(:chimeway_digest_memberships, [:resolution]))
    create(index(:chimeway_digest_memberships, [:digest_delivery_id]))
  end
end

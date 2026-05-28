# chimeway_migration: alter_chimeway_deliveries_for_digest_outcome
defmodule InstallerHost.Repo.Migrations.AlterChimewayDeliveriesForDigestOutcome do
  use Ecto.Migration

  def change do
    alter table(:chimeway_deliveries) do
      add(:digest_flush_outcome, :string)
      add(:digest_flush_reason, :string)
      add(:digest_flush_resolved_at, :utc_datetime_usec)

      add(
        :digest_delivery_id,
        references(:chimeway_deliveries, type: :uuid, on_delete: :nilify_all)
      )
    end

    create(index(:chimeway_deliveries, [:digest_flush_outcome]))
    create(index(:chimeway_deliveries, [:digest_delivery_id]))
  end
end

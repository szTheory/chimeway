# chimeway_migration: alter_chimeway_deliveries_for_digest_outcome
defmodule InstallerHost.Repo.Migrations.AlterChimewayDeliveriesForDigestOutcome do
  use Ecto.Migration

  @chimeway_prefix false

  def change do
    alter chimeway_table(:chimeway_deliveries) do
      add(:digest_flush_outcome, :string)
      add(:digest_flush_reason, :string)
      add(:digest_flush_resolved_at, :utc_datetime_usec)

      add(
        :digest_delivery_id,
        chimeway_references(:chimeway_deliveries, type: :uuid, on_delete: :nilify_all)
      )
    end

    create(chimeway_index(:chimeway_deliveries, [:digest_flush_outcome]))
    create(chimeway_index(:chimeway_deliveries, [:digest_delivery_id]))
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

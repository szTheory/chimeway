# chimeway_migration: alter_chimeway_digest_memberships_for_resolution
defmodule Chimeway.Repo.Migrations.AlterChimewayDigestMembershipsForResolution do
  use Ecto.Migration

  @chimeway_prefix __CHIMEWAY_PREFIX__

  def change do
    alter chimeway_table(:chimeway_digest_memberships) do
      add(:resolution, :string)
      add(:resolution_reason, :string)
      add(:resolved_at, :utc_datetime_usec)
      add(:resolved_rule_key, :string)
      add(:resolved_rule_version, :integer)
      add(:resolved_window_starts_at, :utc_datetime_usec)
      add(:resolved_window_ends_at, :utc_datetime_usec)

      add(
        :digest_delivery_id,
        chimeway_references(:chimeway_deliveries, type: :uuid, on_delete: :nilify_all)
      )
    end

    create(chimeway_index(:chimeway_digest_memberships, [:resolution]))
    create(chimeway_index(:chimeway_digest_memberships, [:digest_delivery_id]))
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

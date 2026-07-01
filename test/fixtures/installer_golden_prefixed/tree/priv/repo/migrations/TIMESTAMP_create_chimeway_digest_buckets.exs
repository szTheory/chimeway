# chimeway_migration: create_chimeway_digest_buckets
defmodule InstallerHost.Repo.Migrations.CreateChimewayDigestBuckets do
  use Ecto.Migration

  @chimeway_prefix "chimeway"

  def change do
    create chimeway_table(:chimeway_digest_buckets, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(
        :digest_rule_id,
        chimeway_references(:chimeway_digest_rules, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:rule_key, :string, null: false)
      add(:rule_version, :integer, null: false)
      add(:recipient_id, :string, null: false)
      add(:channel, :string, null: false)
      add(:grouping_mode, :string, null: false)
      add(:grouping_value, :string, null: false)
      add(:window_kind, :string, null: false)
      add(:window_starts_at, :utc_datetime_usec, null: false)
      add(:window_ends_at, :utc_datetime_usec, null: false)
      add(:member_count, :integer, null: false, default: 0)
      add(:first_accumulated_at, :utc_datetime_usec)
      add(:last_accumulated_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    create(
      chimeway_unique_index(
        :chimeway_digest_buckets,
        [
          :digest_rule_id,
          :recipient_id,
          :channel,
          :grouping_value,
          :window_starts_at,
          :window_ends_at
        ],
        name: :chimeway_digest_buckets_identity_index
      )
    )

    create(chimeway_index(:chimeway_digest_buckets, [:digest_rule_id]))
    create(chimeway_index(:chimeway_digest_buckets, [:recipient_id]))
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

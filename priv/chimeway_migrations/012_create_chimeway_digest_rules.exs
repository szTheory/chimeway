# chimeway_migration: create_chimeway_digest_rules
defmodule Chimeway.Repo.Migrations.CreateChimewayDigestRules do
  use Ecto.Migration

  @chimeway_prefix __CHIMEWAY_PREFIX__

  def change do
    create chimeway_table(:chimeway_digest_rules, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:rule_key, :string, null: false)
      add(:rule_version, :integer, null: false)
      add(:channel, :string, null: false)
      add(:match_notification_key, :string)
      add(:match_category, :string)
      add(:group_by, :string, null: false)
      add(:window_kind, :string, null: false)
      add(:window_minutes, :integer)
      add(:boundary_hour, :integer)
      add(:boundary_minute, :integer)
      add(:boundary_time_zone, :string)

      timestamps(type: :utc_datetime_usec)
    end

    create(
      chimeway_unique_index(:chimeway_digest_rules, [:rule_key, :rule_version],
        name: :chimeway_digest_rules_rule_key_rule_version_index
      )
    )

    create(chimeway_index(:chimeway_digest_rules, [:channel]))
    create(chimeway_index(:chimeway_digest_rules, [:match_notification_key]))
    create(chimeway_index(:chimeway_digest_rules, [:match_category]))
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
end

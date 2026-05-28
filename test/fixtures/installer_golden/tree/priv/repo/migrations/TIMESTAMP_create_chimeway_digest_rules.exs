# chimeway_migration: create_chimeway_digest_rules
defmodule InstallerHost.Repo.Migrations.CreateChimewayDigestRules do
  use Ecto.Migration

  def change do
    create table(:chimeway_digest_rules, primary_key: false) do
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
      unique_index(:chimeway_digest_rules, [:rule_key, :rule_version],
        name: :chimeway_digest_rules_rule_key_rule_version_index
      )
    )

    create(index(:chimeway_digest_rules, [:channel]))
    create(index(:chimeway_digest_rules, [:match_notification_key]))
    create(index(:chimeway_digest_rules, [:match_category]))
  end
end

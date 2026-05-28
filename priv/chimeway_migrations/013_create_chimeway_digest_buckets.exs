# chimeway_migration: create_chimeway_digest_buckets
defmodule Chimeway.Repo.Migrations.CreateChimewayDigestBuckets do
  use Ecto.Migration

  def change do
    create table(:chimeway_digest_buckets, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(
        :digest_rule_id,
        references(:chimeway_digest_rules, type: :uuid, on_delete: :delete_all),
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
      unique_index(
        :chimeway_digest_buckets,
        [
          :digest_rule_id,
          :recipient_id,
          :channel,
          :grouping_value,
          :window_starts_at,
          :window_ends_at
        ], name: :chimeway_digest_buckets_identity_index)
    )

    create(index(:chimeway_digest_buckets, [:digest_rule_id]))
    create(index(:chimeway_digest_buckets, [:recipient_id]))
  end
end

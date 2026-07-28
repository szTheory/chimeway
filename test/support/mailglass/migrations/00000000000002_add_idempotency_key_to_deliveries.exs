defmodule Mailglass.TestRepo.Migrations.AddIdempotencyKeyToDeliveries do
  use Ecto.Migration

  # Idempotent shim: on older mailglass the core migrations omit these columns and
  # this fills the gap; on newer mailglass (~> 1.3) core now folds idempotency_key
  # /status/last_error into mailglass_deliveries itself, so the guards below no-op
  # instead of raising 42701 duplicate_column. See test/test_helper.exs, which
  # fast-forwards the full mailglass core chain before this wrapper runs.
  def up do
    alter table(:mailglass_deliveries) do
      add_if_not_exists(:idempotency_key, :text)
      add_if_not_exists(:status, :string, null: false, default: "queued")
      add_if_not_exists(:last_error, :map)
    end

    # Partial UNIQUE index — enforces replay safety for deliver_many/2 batches.
    # Rows with idempotency_key = NULL are NOT constrained (Phase 2's pattern for
    # mailglass_events.idempotency_key matches; same predicate shape).
    # The `where:` clause MUST match the Ecto conflict_target fragment
    # character-for-character (Pitfall 1 / RESEARCH A1).
    create_if_not_exists(
      unique_index(
        :mailglass_deliveries,
        [:idempotency_key],
        name: :mailglass_deliveries_idempotency_key_unique_idx,
        where: "idempotency_key IS NOT NULL"
      )
    )
  end

  def down do
    drop_if_exists(
      index(:mailglass_deliveries, [:idempotency_key],
        name: :mailglass_deliveries_idempotency_key_unique_idx
      )
    )

    alter table(:mailglass_deliveries) do
      remove_if_exists(:idempotency_key, :text)
      remove_if_exists(:status, :string)
      remove_if_exists(:last_error, :map)
    end
  end
end

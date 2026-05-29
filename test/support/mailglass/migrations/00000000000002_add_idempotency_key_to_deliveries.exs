defmodule Mailglass.TestRepo.Migrations.AddIdempotencyKeyToDeliveries do
  use Ecto.Migration

  def up do
    alter table(:mailglass_deliveries) do
      add :idempotency_key, :text
      add :status, :string, null: false, default: "queued"
      add :last_error, :map
    end

    # Partial UNIQUE index — enforces replay safety for deliver_many/2 batches.
    # Rows with idempotency_key = NULL are NOT constrained (Phase 2's pattern for
    # mailglass_events.idempotency_key matches; same predicate shape).
    # The `where:` clause MUST match the Ecto conflict_target fragment
    # character-for-character (Pitfall 1 / RESEARCH A1).
    create unique_index(
      :mailglass_deliveries,
      [:idempotency_key],
      name: :mailglass_deliveries_idempotency_key_unique_idx,
      where: "idempotency_key IS NOT NULL"
    )
  end

  def down do
    drop index(:mailglass_deliveries, [:idempotency_key],
      name: :mailglass_deliveries_idempotency_key_unique_idx)

    alter table(:mailglass_deliveries) do
      remove :idempotency_key
      remove :status
      remove :last_error
    end
  end
end

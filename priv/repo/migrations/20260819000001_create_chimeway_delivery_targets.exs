defmodule Chimeway.Repo.Migrations.CreateChimewayDeliveryTargets do
  use Ecto.Migration

  def change do
    create table(:chimeway_delivery_targets, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:tenant_id, :string, null: false)

      add(:delivery_id, references(:chimeway_deliveries, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:binding_revision_ref, :string, null: false)
      add(:status, :string, null: false, default: "pending")
      add(:claim_token, :string)
      add(:lease_expires_at, :utc_datetime_usec)
      add(:claimed_at, :utc_datetime_usec)
      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:chimeway_delivery_targets, [:delivery_id, :binding_revision_ref]))
    create(index(:chimeway_delivery_targets, [:tenant_id, :status]))
    create(index(:chimeway_delivery_targets, [:tenant_id, :delivery_id]))

    create table(:chimeway_delivery_target_attempts, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:tenant_id, :string, null: false)

      add(
        :delivery_target_id,
        references(:chimeway_delivery_targets, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:attempt_number, :integer, null: false)
      add(:outcome, :string, null: false)
      add(:started_at, :utc_datetime_usec, null: false)
      add(:finished_at, :utc_datetime_usec)
      add(:source, :string, null: false)
      add(:prior_attempt_id, references(:chimeway_delivery_target_attempts, type: :uuid))
      add(:duplicate_risk, :boolean, null: false, default: false)
      add(:safe_facts, :map, null: false, default: %{})
    end

    create(
      unique_index(:chimeway_delivery_target_attempts, [:delivery_target_id, :attempt_number])
    )

    create(index(:chimeway_delivery_target_attempts, [:tenant_id, :delivery_target_id]))
  end
end

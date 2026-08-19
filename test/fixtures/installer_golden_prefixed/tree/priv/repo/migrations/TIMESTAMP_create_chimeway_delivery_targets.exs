# chimeway_migration: create_chimeway_delivery_targets
defmodule InstallerHost.Repo.Migrations.CreateChimewayDeliveryTargets do
  use Ecto.Migration

  @chimeway_prefix "chimeway"

  def change do
    create chimeway_table(:chimeway_delivery_targets, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:tenant_id, :string, null: false)

      add(
        :delivery_id,
        chimeway_references(:chimeway_deliveries, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:binding_revision_ref, :string, null: false)
      add(:status, :string, null: false, default: "pending")
      add(:claim_token, :string)
      add(:lease_expires_at, :utc_datetime_usec)
      add(:claimed_at, :utc_datetime_usec)
      timestamps(type: :utc_datetime_usec)
    end

    create(
      chimeway_index(:chimeway_delivery_targets, [:delivery_id, :binding_revision_ref],
        unique: true
      )
    )

    create(chimeway_index(:chimeway_delivery_targets, [:tenant_id, :status]))
    create(chimeway_index(:chimeway_delivery_targets, [:tenant_id, :delivery_id]))

    create chimeway_table(:chimeway_delivery_target_attempts, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:tenant_id, :string, null: false)

      add(
        :delivery_target_id,
        chimeway_references(:chimeway_delivery_targets, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:attempt_number, :integer, null: false)
      add(:outcome, :string, null: false)
      add(:started_at, :utc_datetime_usec, null: false)
      add(:finished_at, :utc_datetime_usec)
      add(:source, :string, null: false)
      add(:prior_attempt_id, chimeway_references(:chimeway_delivery_target_attempts, type: :uuid))
      add(:duplicate_risk, :boolean, null: false, default: false)
      add(:safe_facts, :map, null: false, default: %{})
    end

    create(
      chimeway_index(:chimeway_delivery_target_attempts, [:delivery_target_id, :attempt_number],
        unique: true
      )
    )

    create(chimeway_index(:chimeway_delivery_target_attempts, [:tenant_id, :delivery_target_id]))
  end

  defp chimeway_prefix_opts(opts \\ []) do
    if @chimeway_prefix, do: Keyword.put_new(opts, :prefix, @chimeway_prefix), else: opts
  end

  defp chimeway_table(name, opts \\ []), do: table(name, chimeway_prefix_opts(opts))

  defp chimeway_index(table_name, columns, opts \\ []),
    do: index(table_name, columns, chimeway_prefix_opts(opts))

  defp chimeway_references(table_name, opts \\ []),
    do: references(table_name, chimeway_prefix_opts(opts))
end

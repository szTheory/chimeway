# chimeway_migration: enforce_delivery_target_tenant_integrity
defmodule Chimeway.Repo.Migrations.EnforceDeliveryTargetTenantIntegrity do
  use Ecto.Migration

  @chimeway_prefix __CHIMEWAY_PREFIX__

  def up do
    create(
      unique_index(:chimeway_deliveries, [:tenant_id, :id],
        name: :chimeway_deliveries_tenant_id_id_unique,
        prefix: @chimeway_prefix
      )
    )

    create(
      unique_index(:chimeway_delivery_targets, [:tenant_id, :id],
        name: :chimeway_delivery_targets_tenant_id_id_unique,
        prefix: @chimeway_prefix
      )
    )

    create(
      unique_index(:chimeway_delivery_target_attempts, [:tenant_id, :delivery_target_id, :id],
        name: :chimeway_delivery_target_attempts_tenant_target_id_unique,
        prefix: @chimeway_prefix
      )
    )

    execute("""
    ALTER TABLE #{chimeway_relation(:chimeway_delivery_targets)}
    ADD CONSTRAINT #{quoted_identifier("chimeway_delivery_targets_tenant_delivery_fkey")}
    FOREIGN KEY (tenant_id, delivery_id)
    REFERENCES #{chimeway_relation(:chimeway_deliveries)} (tenant_id, id)
    ON DELETE CASCADE
    """)

    execute("""
    ALTER TABLE #{chimeway_relation(:chimeway_delivery_target_attempts)}
    ADD CONSTRAINT #{quoted_identifier("chimeway_delivery_target_attempts_tenant_target_fkey")}
    FOREIGN KEY (tenant_id, delivery_target_id)
    REFERENCES #{chimeway_relation(:chimeway_delivery_targets)} (tenant_id, id)
    ON DELETE CASCADE
    """)

    execute("""
    ALTER TABLE #{chimeway_relation(:chimeway_delivery_target_attempts)}
    ADD CONSTRAINT #{quoted_identifier("chimeway_delivery_target_attempts_prior_same_target_fkey")}
    FOREIGN KEY (tenant_id, delivery_target_id, prior_attempt_id)
    REFERENCES #{chimeway_relation(:chimeway_delivery_target_attempts)} (tenant_id, delivery_target_id, id)
    """)
  end

  def down do
    execute(
      "ALTER TABLE #{chimeway_relation(:chimeway_delivery_target_attempts)} DROP CONSTRAINT #{quoted_identifier("chimeway_delivery_target_attempts_prior_same_target_fkey")}"
    )

    execute(
      "ALTER TABLE #{chimeway_relation(:chimeway_delivery_target_attempts)} DROP CONSTRAINT #{quoted_identifier("chimeway_delivery_target_attempts_tenant_target_fkey")}"
    )

    execute(
      "ALTER TABLE #{chimeway_relation(:chimeway_delivery_targets)} DROP CONSTRAINT #{quoted_identifier("chimeway_delivery_targets_tenant_delivery_fkey")}"
    )

    drop(
      chimeway_index(:chimeway_delivery_target_attempts, [:tenant_id, :delivery_target_id, :id],
        name: :chimeway_delivery_target_attempts_tenant_target_id_unique
      )
    )

    drop(
      chimeway_index(:chimeway_delivery_targets, [:tenant_id, :id],
        name: :chimeway_delivery_targets_tenant_id_id_unique
      )
    )

    drop(
      chimeway_index(:chimeway_deliveries, [:tenant_id, :id],
        name: :chimeway_deliveries_tenant_id_id_unique
      )
    )
  end

  defp chimeway_index(table_name, columns, opts),
    do: index(table_name, columns, Keyword.put_new(opts, :prefix, @chimeway_prefix))

  defp chimeway_relation(:chimeway_deliveries), do: quoted_relation("chimeway_deliveries")

  defp chimeway_relation(:chimeway_delivery_targets),
    do: quoted_relation("chimeway_delivery_targets")

  defp chimeway_relation(:chimeway_delivery_target_attempts),
    do: quoted_relation("chimeway_delivery_target_attempts")

  defp quoted_relation(name) do
    if @chimeway_prefix, do: ~s("#{@chimeway_prefix}"."#{name}"), else: quoted_identifier(name)
  end

  defp quoted_identifier(name), do: ~s("#{name}")
end

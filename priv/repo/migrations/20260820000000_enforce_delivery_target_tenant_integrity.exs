defmodule Chimeway.Repo.Migrations.EnforceDeliveryTargetTenantIntegrity do
  use Ecto.Migration

  def up do
    create(
      unique_index(:chimeway_deliveries, [:tenant_id, :id],
        name: :chimeway_deliveries_tenant_id_id_unique
      )
    )

    create(
      unique_index(:chimeway_delivery_targets, [:tenant_id, :id],
        name: :chimeway_delivery_targets_tenant_id_id_unique
      )
    )

    create(
      unique_index(:chimeway_delivery_target_attempts, [:tenant_id, :delivery_target_id, :id],
        name: :chimeway_delivery_target_attempts_tenant_target_id_unique
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
      index(:chimeway_delivery_target_attempts, [:tenant_id, :delivery_target_id, :id],
        name: :chimeway_delivery_target_attempts_tenant_target_id_unique
      )
    )

    drop(
      index(:chimeway_delivery_targets, [:tenant_id, :id],
        name: :chimeway_delivery_targets_tenant_id_id_unique
      )
    )

    drop(
      index(:chimeway_deliveries, [:tenant_id, :id],
        name: :chimeway_deliveries_tenant_id_id_unique
      )
    )
  end

  defp chimeway_relation(:chimeway_deliveries), do: quoted_relation("chimeway_deliveries")

  defp chimeway_relation(:chimeway_delivery_targets),
    do: quoted_relation("chimeway_delivery_targets")

  defp chimeway_relation(:chimeway_delivery_target_attempts),
    do: quoted_relation("chimeway_delivery_target_attempts")

  defp quoted_relation(name), do: quoted_identifier(name)
  defp quoted_identifier(name), do: ~s("#{name}")
end

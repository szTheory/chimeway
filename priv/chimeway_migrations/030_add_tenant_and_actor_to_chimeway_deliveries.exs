# chimeway_migration: add_tenant_and_actor_to_chimeway_deliveries
defmodule Chimeway.Repo.Migrations.AddTenantAndActorToChimewayDeliveries do
  use Ecto.Migration

  @chimeway_prefix __CHIMEWAY_PREFIX__

  def up do
    # 1. Add columns
    alter chimeway_table(:chimeway_deliveries) do
      add(:tenant_id, :string)
      add(:actor_id, :string)
    end

    flush()

    # 2. Backfill actor_id from notifications
    execute("""
    UPDATE #{chimeway_relation(:chimeway_deliveries)} d
    SET actor_id = COALESCE(n.recipient_identity, 'system')
    FROM #{chimeway_relation(:chimeway_notifications)} n
    WHERE d.notification_id = n.id
    """)

    # Catch any orphans
    execute("""
    UPDATE #{chimeway_relation(:chimeway_deliveries)}
    SET actor_id = 'system'
    WHERE actor_id IS NULL
    """)

    # Backfill tenant_id from workflow_runs
    execute("""
    UPDATE #{chimeway_relation(:chimeway_deliveries)} d
    SET tenant_id = COALESCE(wr.tenant_id, 'default')
    FROM #{chimeway_relation(:chimeway_workflow_runs)} wr
    WHERE d.workflow_run_id = wr.id
    """)

    # Catch any rows lacking workflow_run_id or tenant_id
    execute("""
    UPDATE #{chimeway_relation(:chimeway_deliveries)}
    SET tenant_id = 'default'
    WHERE tenant_id IS NULL
    """)

    # 3. Modify columns to not null
    alter chimeway_table(:chimeway_deliveries) do
      modify(:tenant_id, :string, null: false)
      modify(:actor_id, :string, null: false)
    end
  end

  def down do
    alter chimeway_table(:chimeway_deliveries) do
      remove(:tenant_id)
      remove(:actor_id)
    end
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

  defp chimeway_relation(:chimeway_deliveries) do
    chimeway_relation_name("chimeway_deliveries")
  end

  defp chimeway_relation(:chimeway_notifications) do
    chimeway_relation_name("chimeway_notifications")
  end

  defp chimeway_relation(:chimeway_workflow_runs) do
    chimeway_relation_name("chimeway_workflow_runs")
  end

  defp chimeway_relation_name(name) do
    if @chimeway_prefix do
      ~s("#{@chimeway_prefix}"."#{name}")
    else
      name
    end
  end
end

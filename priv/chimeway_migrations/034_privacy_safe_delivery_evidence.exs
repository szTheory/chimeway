# chimeway_migration: privacy_safe_delivery_evidence
defmodule Chimeway.Repo.Migrations.PrivacySafeDeliveryEvidence do
  use Ecto.Migration

  @chimeway_prefix __CHIMEWAY_PREFIX__
  @irreversible_error "privacy-safe delivery evidence cleanup is irreversible"

  def up do
    execute("UPDATE #{chimeway_relation(:chimeway_events)} SET payload = '{}'::jsonb")

    execute("""
    UPDATE #{chimeway_relation(:chimeway_notifications)}
    SET metadata = '{}'::jsonb,
        render_assigns = '{}'::jsonb,
        render_channels = '{}'::jsonb,
        orchestration = '{}'::jsonb
    """)

    execute("""
    UPDATE #{chimeway_relation(:chimeway_deliveries)}
    SET metadata = '{}'::jsonb,
        planning_context = '{}'::jsonb,
        render_data = '{}'::jsonb
    """)

    execute("""
    UPDATE #{chimeway_relation(:chimeway_delivery_attempts)}
    SET provider_response = '{}'::jsonb,
        provider_message_id = CASE
          WHEN provider_message_id LIKE 'cw_%' THEN provider_message_id
          ELSE NULL
        END
    """)
  end

  def down, do: raise(@irreversible_error)

  defp chimeway_relation(:chimeway_events), do: quoted_relation("chimeway_events")
  defp chimeway_relation(:chimeway_notifications), do: quoted_relation("chimeway_notifications")
  defp chimeway_relation(:chimeway_deliveries), do: quoted_relation("chimeway_deliveries")

  defp chimeway_relation(:chimeway_delivery_attempts),
    do: quoted_relation("chimeway_delivery_attempts")

  defp quoted_relation(name) do
    if @chimeway_prefix do
      ~s("#{@chimeway_prefix}"."#{name}")
    else
      ~s("#{name}")
    end
  end
end

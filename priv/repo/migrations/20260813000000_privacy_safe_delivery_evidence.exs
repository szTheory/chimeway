defmodule Chimeway.Repo.Migrations.PrivacySafeDeliveryEvidence do
  use Ecto.Migration

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

  defp chimeway_relation(:chimeway_events), do: ~s("chimeway_events")
  defp chimeway_relation(:chimeway_notifications), do: ~s("chimeway_notifications")
  defp chimeway_relation(:chimeway_deliveries), do: ~s("chimeway_deliveries")
  defp chimeway_relation(:chimeway_delivery_attempts), do: ~s("chimeway_delivery_attempts")
end

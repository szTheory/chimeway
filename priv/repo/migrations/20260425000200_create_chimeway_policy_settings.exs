defmodule Chimeway.Repo.Migrations.CreateChimewayPolicySettings do
  use Ecto.Migration

  def change do
    create table(:chimeway_policy_settings, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :recipient_id, :string, null: false
      add :quiet_hours_start_minute, :integer
      add :quiet_hours_end_minute, :integer
      add :delivery_cap_count, :integer
      add :delivery_cap_window_minutes, :integer

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(
      :chimeway_policy_settings,
      [:recipient_id],
      name: :chimeway_policy_settings_recipient_index
    )
  end
end

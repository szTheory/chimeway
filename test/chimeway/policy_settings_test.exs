defmodule Chimeway.PolicySettingsTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.Policy.Settings
  alias Chimeway.Policy.Settings.Setting
  alias Chimeway.Test.DispatchHelpers

  describe "upsert_settings/1 and get_settings/1" do
    test "creates and fetches a settings row" do
      attrs = %{
        recipient_id: "user:settings-1",
        quiet_hours_start_minute: 10,
        quiet_hours_end_minute: 20,
        delivery_cap_count: 3,
        delivery_cap_window_minutes: 60,
        time_zone: "America/New_York"
      }

      assert {:ok, settings} = Settings.upsert_settings(attrs)
      assert settings.recipient_id == "user:settings-1"
      assert settings.quiet_hours_start_minute == 10
      assert settings.quiet_hours_end_minute == 20
      assert settings.delivery_cap_count == 3
      assert settings.delivery_cap_window_minutes == 60
      assert settings.time_zone == "America/New_York"

      assert fetched = Settings.get_settings("user:settings-1")
      assert fetched.id == settings.id
    end

    test "accepts a valid IANA time zone and rejects an invalid identifier" do
      valid_changeset =
        Setting.changeset(%Setting{}, %{
          recipient_id: "user:time-zone-valid",
          time_zone: "America/Los_Angeles"
        })

      assert valid_changeset.valid?

      invalid_changeset =
        Setting.changeset(%Setting{}, %{
          recipient_id: "user:time-zone-invalid",
          time_zone: "Mars/Olympus"
        })

      refute invalid_changeset.valid?

      assert %{time_zone: ["is invalid"]} =
               Ecto.Changeset.traverse_errors(invalid_changeset, fn {message, _opts} ->
                 message
               end)
    end

    test "updates time_zone through the upsert conflict path" do
      recipient_id = "user:settings-upsert-time-zone"

      assert {:ok, _settings} =
               Settings.upsert_settings(%{
                 recipient_id: recipient_id,
                 quiet_hours_start_minute: 60,
                 quiet_hours_end_minute: 120,
                 time_zone: "America/New_York"
               })

      assert {:ok, updated} =
               Settings.upsert_settings(%{
                 recipient_id: recipient_id,
                 quiet_hours_start_minute: 120,
                 quiet_hours_end_minute: 180,
                 time_zone: "Europe/Paris"
               })

      assert updated.time_zone == "Europe/Paris"

      assert fetched = Settings.get_settings(recipient_id)
      assert fetched.time_zone == "Europe/Paris"
      assert fetched.quiet_hours_start_minute == 120
      assert fetched.quiet_hours_end_minute == 180
    end

    test "returns nil when settings are missing" do
      assert is_nil(Settings.get_settings("missing-user"))
    end
  end

  describe "evaluate/1" do
    test "returns {:ok, :proceed} when no settings exist" do
      fixture = DispatchHelpers.create_pending_delivery(recipient_identity: "user:no-settings")

      assert Settings.evaluate(fixture.delivery) == {:ok, :proceed}
    end

    test "defers during quiet hours with persisted planning facts" do
      fixture = DispatchHelpers.create_pending_delivery(recipient_identity: "user:quiet-hours")
      evaluation_time = ~U[2026-01-15 03:30:00Z]

      assert {:ok, _} =
               Settings.upsert_settings(%{
                 recipient_id: "user:quiet-hours",
                 quiet_hours_start_minute: 22 * 60,
                 quiet_hours_end_minute: 8 * 60,
                 time_zone: "America/New_York"
               })

      assert {:defer, decision} =
               Settings.evaluate(fixture.delivery, evaluation_time: evaluation_time)

      assert decision.orchestration_state == :deferred
      assert decision.planning_reason == "quiet_hours"
      assert DateTime.compare(decision.next_eligible_at, ~U[2026-01-15 13:00:00Z]) == :eq
      assert decision.planning_context["rule"] == "quiet_hours"
      assert decision.planning_context["time_zone"] == "America/New_York"
      assert decision.planning_context["quiet_hours_start_minute"] == 22 * 60
      assert decision.planning_context["quiet_hours_end_minute"] == 8 * 60
    end

    test "suppresses when the delivery cap has already been reached" do
      first = DispatchHelpers.create_pending_delivery(recipient_identity: "user:cap")

      assert Settings.evaluate(first.delivery) == {:ok, :proceed}

      assert {:ok, _} =
               Settings.upsert_settings(%{
                 recipient_id: "user:cap",
                 delivery_cap_count: 1,
                 delivery_cap_window_minutes: 60
               })

      second = DispatchHelpers.create_pending_delivery(recipient_identity: "user:cap")

      assert Settings.evaluate(second.delivery) == {:suppress, :delivery_cap_reached}
    end
  end
end

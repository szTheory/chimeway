defmodule Chimeway.PolicySettingsTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.Policy.Settings
  alias Chimeway.Test.DispatchHelpers

  describe "upsert_settings/1 and get_settings/1" do
    test "creates and fetches a settings row" do
      attrs = %{
        recipient_id: "user:settings-1",
        quiet_hours_start_minute: 10,
        quiet_hours_end_minute: 20,
        delivery_cap_count: 3,
        delivery_cap_window_minutes: 60
      }

      assert {:ok, settings} = Settings.upsert_settings(attrs)
      assert settings.recipient_id == "user:settings-1"
      assert settings.quiet_hours_start_minute == 10
      assert settings.quiet_hours_end_minute == 20
      assert settings.delivery_cap_count == 3
      assert settings.delivery_cap_window_minutes == 60

      assert fetched = Settings.get_settings("user:settings-1")
      assert fetched.id == settings.id
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

    test "suppresses during quiet hours" do
      fixture = DispatchHelpers.create_pending_delivery(recipient_identity: "user:quiet-hours")
      now = DateTime.utc_now()
      minute = now.hour * 60 + now.minute

      start_minute = rem(minute + 1439, 1440)
      end_minute = rem(minute + 1, 1440)

      assert {:ok, _} =
               Settings.upsert_settings(%{
                 recipient_id: "user:quiet-hours",
                 quiet_hours_start_minute: start_minute,
                 quiet_hours_end_minute: end_minute
               })

      assert Settings.evaluate(fixture.delivery) == {:suppress, :quiet_hours}
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

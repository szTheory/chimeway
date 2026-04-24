defmodule Chimeway.PreferencesTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.Preferences
  alias Chimeway.Preferences.NotificationPreference
  alias Chimeway.Repo

  describe "upsert_preference/1 and channel_enabled?/3" do
    test "creates a preference row" do
      attrs = %{
        recipient_id: "user:1",
        notification_key: "comment.created",
        channel: "in_app",
        enabled: true
      }

      assert {:ok, %NotificationPreference{} = pref} = Preferences.upsert_preference(attrs)
      assert pref.recipient_id == "user:1"
      assert pref.notification_key == "comment.created"
      assert pref.channel == "in_app"
      assert pref.enabled == true
    end

    test "returns true when preference row is missing (opt-in default)" do
      assert Preferences.channel_enabled?("missing-user", "missing.key", "in_app")
    end

    test "returns false when preference is explicitly disabled" do
      attrs = %{
        recipient_id: "user:2",
        notification_key: "comment.created",
        channel: "in_app",
        enabled: false
      }

      assert {:ok, _pref} = Preferences.upsert_preference(attrs)
      refute Preferences.channel_enabled?("user:2", "comment.created", "in_app")
    end

    test "upsert updates existing row without duplicates" do
      base_attrs = %{
        recipient_id: "user:3",
        notification_key: "comment.created",
        channel: "email",
        enabled: false
      }

      assert {:ok, pref_1} = Preferences.upsert_preference(base_attrs)
      assert pref_1.enabled == false

      assert {:ok, pref_2} =
               Preferences.upsert_preference(%{
                 recipient_id: "user:3",
                 notification_key: "comment.created",
                 channel: "email",
                 enabled: true
               })

      assert pref_2.enabled == true
      assert Repo.aggregate(NotificationPreference, :count, :id) == 1
      assert Preferences.channel_enabled?("user:3", "comment.created", "email")
    end

    test "get_preference/3 returns nil for unknown key" do
      assert is_nil(Preferences.get_preference("unknown-user", "unknown.key", "sms"))
    end
  end
end

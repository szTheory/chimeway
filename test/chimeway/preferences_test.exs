defmodule Chimeway.PreferencesTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.Preferences
  alias Chimeway.Preferences.NotificationPreference
  alias Chimeway.Preferences.CategoryPreference
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

  describe "upsert_category_preference/1 and category_enabled?/2" do
    test "creates a category preference row" do
      attrs = %{
        recipient_id: "user:cat-1",
        notification_category: "billing",
        enabled: true
      }

      assert {:ok, %CategoryPreference{} = pref} = Preferences.upsert_category_preference(attrs)
      assert pref.recipient_id == "user:cat-1"
      assert pref.notification_category == "billing"
      assert pref.enabled == true
    end

    test "returns true when category preference row is missing (opt-in default)" do
      assert Preferences.category_enabled?("missing-user", "billing")
    end

    test "returns false when category preference is explicitly disabled" do
      attrs = %{
        recipient_id: "user:cat-2",
        notification_category: "marketing",
        enabled: false
      }

      assert {:ok, _pref} = Preferences.upsert_category_preference(attrs)
      refute Preferences.category_enabled?("user:cat-2", "marketing")
    end

    test "upsert updates existing category row without duplicates" do
      base_attrs = %{
        recipient_id: "user:cat-3",
        notification_category: "product",
        enabled: false
      }

      assert {:ok, pref_1} = Preferences.upsert_category_preference(base_attrs)
      assert pref_1.enabled == false

      assert {:ok, pref_2} =
               Preferences.upsert_category_preference(%{
                 recipient_id: "user:cat-3",
                 notification_category: "product",
                 enabled: true
               })

      assert pref_2.enabled == true
      assert Repo.aggregate(CategoryPreference, :count, :id) == 1
      assert Preferences.category_enabled?("user:cat-3", "product")
    end

    test "get_category_preference/2 returns nil for unknown key" do
      assert is_nil(Preferences.get_category_preference("unknown-user", "unknown-category"))
    end
  end
end

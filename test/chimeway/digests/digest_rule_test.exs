defmodule Chimeway.Digests.DigestRuleTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.{Digests, Repo}
  alias Chimeway.Digests.DigestRule

  setup do
    Repo.delete_all(DigestRule)
    :ok
  end

  describe "changeset/2" do
    test "requires durable identity, channel, grouping, and window kind" do
      changeset = DigestRule.changeset(%DigestRule{}, %{})

      refute changeset.valid?

      assert errors_on(changeset) == %{
               channel: ["can't be blank"],
               group_by: ["can't be blank"],
               rule_key: ["can't be blank"],
               rule_version: ["can't be blank"],
               window_kind: ["can't be blank"]
             }
    end

    test "only accepts supported group_by values" do
      changeset =
        DigestRule.changeset(%DigestRule{}, valid_rule_attrs(%{group_by: :team_slug}))

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).group_by
    end

    test "accepts notification_key, category, and digest_key grouping modes" do
      for group_by <- [:notification_key, :category, :digest_key] do
        changeset = DigestRule.changeset(%DigestRule{}, valid_rule_attrs(%{group_by: group_by}))

        assert changeset.valid?, "expected #{inspect(group_by)} to be valid"
      end
    end

    test "fixed windows require positive window_minutes" do
      changeset =
        DigestRule.changeset(
          %DigestRule{},
          valid_rule_attrs(%{
            window_kind: :fixed,
            window_minutes: 0,
            boundary_hour: nil,
            boundary_minute: nil,
            boundary_time_zone: nil
          })
        )

      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).window_minutes
    end

    test "boundary windows require hour, minute, and boundary_time_zone" do
      changeset =
        DigestRule.changeset(
          %DigestRule{},
          valid_rule_attrs(%{
            window_kind: :boundary,
            window_minutes: nil,
            boundary_hour: nil,
            boundary_minute: nil,
            boundary_time_zone: nil
          })
        )

      refute changeset.valid?

      assert errors_on(changeset).boundary_hour == ["can't be blank"]
      assert errors_on(changeset).boundary_minute == ["can't be blank"]
      assert errors_on(changeset).boundary_time_zone == ["can't be blank"]
    end

    test "boundary windows reject invalid boundary_time_zone values" do
      changeset =
        DigestRule.changeset(
          %DigestRule{},
          valid_rule_attrs(%{
            window_kind: :boundary,
            window_minutes: nil,
            boundary_hour: 9,
            boundary_minute: 30,
            boundary_time_zone: "Mars/Olympus"
          })
        )

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).boundary_time_zone
    end
  end

  describe "upsert_rule/1" do
    test "persists one durable identity for rule_key and rule_version" do
      attrs =
        valid_rule_attrs(%{
          rule_key: "team.digest",
          rule_version: 3,
          match_notification_key: "comment.created"
        })

      assert {:ok, first} = Digests.upsert_rule(attrs)
      assert {:ok, second} = Digests.upsert_rule(Map.put(attrs, :group_by, :category))

      assert first.id == second.id

      assert Repo.aggregate(DigestRule, :count, :id) == 1
      assert second.group_by == :category
    end
  end

  describe "find_matching_rule/1" do
    test "matches by notification_key, category, or digest_key without module names" do
      assert {:ok, notification_rule} =
               Digests.upsert_rule(
                 valid_rule_attrs(%{
                   rule_key: "digest.notification",
                   rule_version: 1,
                   match_notification_key: "comment.created",
                   match_category: nil
                 })
               )

      assert {:ok, category_rule} =
               Digests.upsert_rule(
                 valid_rule_attrs(%{
                   rule_key: "digest.category",
                   rule_version: 1,
                   match_notification_key: nil,
                   match_category: "comments"
                 })
               )

      assert {:ok, digest_key_rule} =
               Digests.upsert_rule(
                 valid_rule_attrs(%{
                   rule_key: "digest.explicit",
                   rule_version: 1,
                   match_notification_key: "explicit.digest",
                   group_by: :digest_key
                 })
               )

      assert notification_rule.id ==
               Digests.find_matching_rule(%{
                 channel: "email",
                 notification_key: "comment.created",
                 category: "other",
                 digest_key: nil
               }).id

      assert category_rule.id ==
               Digests.find_matching_rule(%{
                 channel: "email",
                 notification_key: "other.event",
                 category: "comments",
                 digest_key: nil
               }).id

      assert digest_key_rule.id ==
               Digests.find_matching_rule(%{
                 channel: "email",
                 notification_key: "explicit.digest",
                 category: nil,
                 digest_key: "weekly:account:1"
               }).id
    end

    test "prefers digest_key rules over generic notification_key rules when digest_key is present" do
      assert {:ok, generic_rule} =
               Digests.upsert_rule(
                 valid_rule_attrs(%{
                   rule_key: "digest.generic",
                   rule_version: 1,
                   match_notification_key: "comment.created",
                   group_by: :notification_key
                 })
               )

      assert {:ok, digest_key_rule} =
               Digests.upsert_rule(
                 valid_rule_attrs(%{
                   rule_key: "digest.explicit",
                   rule_version: 1,
                   match_notification_key: "comment.created",
                   group_by: :digest_key
                 })
               )

      matched_rule =
        Digests.find_matching_rule(%{
          channel: "email",
          notification_key: "comment.created",
          category: nil,
          digest_key: "thread:123"
        })

      assert matched_rule.id == digest_key_rule.id
      refute matched_rule.id == generic_rule.id
    end
  end

  defp valid_rule_attrs(overrides) do
    %{
      rule_key: "comment.digest",
      rule_version: 1,
      channel: "email",
      match_notification_key: "comment.created",
      match_category: "comments",
      group_by: :notification_key,
      window_kind: :fixed,
      window_minutes: 30,
      boundary_hour: nil,
      boundary_minute: nil,
      boundary_time_zone: nil
    }
    |> Map.merge(overrides)
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

defmodule Chimeway.Digests.DigestBucketTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.{Repo}
  alias Chimeway.Digests.{DigestBucket, DigestRule}

  describe "changeset/2" do
    test "requires durable bucket snapshot fields" do
      changeset = DigestBucket.changeset(%DigestBucket{}, %{})

      refute changeset.valid?

      assert errors_on(changeset) == %{
               channel: ["can't be blank"],
               digest_rule_id: ["can't be blank"],
               grouping_mode: ["can't be blank"],
               grouping_value: ["can't be blank"],
               recipient_id: ["can't be blank"],
               rule_key: ["can't be blank"],
               rule_version: ["can't be blank"],
               window_ends_at: ["can't be blank"],
               window_kind: ["can't be blank"],
               window_starts_at: ["can't be blank"]
             }
    end

    test "enforces uniqueness for digest_rule, recipient, channel, grouping_value, and window" do
      rule = insert_rule!()
      attrs = valid_bucket_attrs(rule)

      assert {:ok, _bucket} =
               %DigestBucket{}
               |> DigestBucket.changeset(attrs)
               |> Repo.insert()

      assert {:error, changeset} =
               %DigestBucket{}
               |> DigestBucket.changeset(attrs)
               |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).grouping_value
    end

    test "persists bucket identity and counters without next_eligible_at" do
      rule = insert_rule!()

      assert {:ok, bucket} =
               %DigestBucket{}
               |> DigestBucket.changeset(valid_bucket_attrs(rule))
               |> Repo.insert()

      assert bucket.rule_key == rule.rule_key
      assert bucket.rule_version == rule.rule_version
      assert bucket.member_count == 1
      assert bucket.first_accumulated_at == bucket.window_starts_at
      assert bucket.last_accumulated_at == bucket.window_starts_at
      refute :next_eligible_at in DigestBucket.__schema__(:fields)
    end
  end

  defp insert_rule! do
    %DigestRule{}
    |> DigestRule.changeset(%{
      rule_key: "digest.rule.#{System.unique_integer([:positive])}",
      rule_version: 1,
      channel: "email",
      match_notification_key: "comment.created",
      match_category: "comments",
      group_by: :notification_key,
      window_kind: :fixed,
      window_minutes: 30
    })
    |> Repo.insert!()
  end

  defp valid_bucket_attrs(rule) do
    window_starts_at = ~U[2026-04-28 12:00:00.000000Z]
    window_ends_at = ~U[2026-04-28 12:30:00.000000Z]

    %{
      digest_rule_id: rule.id,
      rule_key: rule.rule_key,
      rule_version: rule.rule_version,
      recipient_id: "user-123",
      channel: "email",
      grouping_mode: rule.group_by,
      grouping_value: "comment.created",
      window_kind: rule.window_kind,
      window_starts_at: window_starts_at,
      window_ends_at: window_ends_at,
      member_count: 1,
      first_accumulated_at: window_starts_at,
      last_accumulated_at: window_starts_at
    }
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

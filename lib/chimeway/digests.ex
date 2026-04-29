defmodule Chimeway.Digests do
  @moduledoc """
  Public digest-rule persistence API for durable rule lookup and storage.

  Digest flush execution closes automatically only when the configured
  dispatcher is `Chimeway.Dispatch.Oban`, because bucket accumulation can then
  schedule `Chimeway.Dispatch.DigestFlushWorker` from persisted
  `window_ends_at` state.

  Hosts using any other dispatcher still retain the durable public
  `emit_bucket/2` seam and are expected to drive flush execution explicitly.
  Chimeway does not imply built-in automatic digest scheduling outside the Oban
  path.
  """

  import Ecto.Query, only: [from: 2]

  alias Chimeway.Repo
  alias Chimeway.Digests.{DigestRule, Emission}

  @type rule_lookup :: %{
          required(:channel) => String.t(),
          optional(:notification_key) => String.t() | nil,
          optional(:category) => String.t() | nil,
          optional(:digest_key) => String.t() | nil
        }

  @doc "Creates or updates a digest rule by stable `rule_key` and `rule_version`."
  @spec upsert_rule(map()) :: {:ok, DigestRule.t()} | {:error, Ecto.Changeset.t()}
  def upsert_rule(attrs) when is_map(attrs) do
    changeset = DigestRule.changeset(%DigestRule{}, attrs)

    Repo.insert(changeset,
      on_conflict: {:replace, updatable_fields()},
      conflict_target: [:rule_key, :rule_version],
      returning: true
    )
  end

  @doc "Lists digest rules, optionally filtered by exact-match fields."
  @spec list_rules(keyword()) :: [DigestRule.t()]
  def list_rules(opts \\ []) when is_list(opts) do
    DigestRule
    |> maybe_where(:channel, Keyword.get(opts, :channel))
    |> maybe_where(:rule_key, Keyword.get(opts, :rule_key))
    |> Repo.all()
  end

  @doc "Fetches a digest rule by ID."
  @spec get_rule!(binary()) :: DigestRule.t()
  def get_rule!(id), do: Repo.get!(DigestRule, id)

  @doc "Finds the first digest rule matching channel and rule selectors."
  @spec find_matching_rule(rule_lookup()) :: DigestRule.t() | nil
  def find_matching_rule(%{} = attrs) do
    channel = Map.fetch!(attrs, :channel)

    attrs
    |> build_match_queries(channel)
    |> Enum.find_value(&Repo.one/1)
  end

  defp maybe_where(query, _field, nil), do: query

  defp maybe_where(query, field, value) do
    from(record in query, where: field(record, ^field) == ^value)
  end

  defp build_match_queries(attrs, channel) do
    notification_key = Map.get(attrs, :notification_key)
    category = Map.get(attrs, :category)
    digest_key = Map.get(attrs, :digest_key)

    [
      digest_key_query(channel, notification_key, digest_key),
      notification_key_query(channel, notification_key),
      category_query(channel, category)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp notification_key_query(_channel, nil), do: nil

  defp notification_key_query(channel, notification_key) do
    from(rule in DigestRule,
      where: rule.channel == ^channel and rule.match_notification_key == ^notification_key,
      order_by: [asc: rule.inserted_at],
      limit: 1
    )
  end

  defp category_query(_channel, nil), do: nil

  defp category_query(channel, category) do
    from(rule in DigestRule,
      where: rule.channel == ^channel and rule.match_category == ^category,
      order_by: [asc: rule.inserted_at],
      limit: 1
    )
  end

  defp digest_key_query(_channel, _notification_key, nil), do: nil
  defp digest_key_query(_channel, nil, _digest_key), do: nil

  defp digest_key_query(channel, notification_key, _digest_key) do
    from(rule in DigestRule,
      where:
        rule.channel == ^channel and rule.group_by == :digest_key and
          rule.match_notification_key == ^notification_key,
      order_by: [asc: rule.inserted_at],
      limit: 1
    )
  end

  defp updatable_fields do
    [
      :channel,
      :match_notification_key,
      :match_category,
      :group_by,
      :window_kind,
      :window_minutes,
      :boundary_hour,
      :boundary_minute,
      :boundary_time_zone,
      :updated_at
    ]
  end

  @doc """
  Emits a due digest bucket and returns the canonical emitted delivery identity.

  This remains the explicit host-managed flush seam when
  `Chimeway.Dispatch.Oban` is not the configured dispatcher.
  """
  @spec emit_bucket(binary() | map(), keyword()) :: {:ok, map()} | {:error, term()}
  def emit_bucket(bucket_or_id, opts \\ []), do: Emission.emit_bucket(bucket_or_id, opts)
end

defmodule Chimeway.Admin do
  @moduledoc """
  Admin-safe read models for operator UI surfaces.

  This module returns small DTO maps instead of raw Ecto schemas so UI packages do
  not accidentally render payloads, render snapshots, provider responses, or other
  sensitive fields.
  """

  import Ecto.Query

  alias Chimeway.{Delivery, Events.Event, Notifications.Notification, Repo, TenantScope}

  @default_limit 25
  @problem_statuses [:failed, :suppressed, :cancelled]

  @doc """
  Returns compact command-center facts for the operator admin home.
  """
  @spec command_center(keyword()) :: map()
  def command_center(opts \\ []) do
    with {:ok, tenant_id} <- TenantScope.resolve(opts) do
      opts = Keyword.put(opts, :tenant_id, tenant_id)

      %{
        generated_at: DateTime.utc_now() |> DateTime.truncate(:second),
        outcomes: outcome_totals(opts),
        recent_problems: recent_problem_deliveries(opts),
        recovery_candidates: recovery_candidates(Keyword.put_new(opts, :limit, 8)),
        definitions: definitions(Keyword.put_new(opts, :limit, 8))
      }
    end
  end

  @doc """
  Lists recent deliveries in problem terminal states.
  """
  @spec recent_problem_deliveries(keyword()) :: [map()]
  def recent_problem_deliveries(opts \\ []) do
    with {:ok, tenant_id} <- TenantScope.resolve(opts) do
      limit = Keyword.get(opts, :limit, @default_limit)

      Delivery
      |> join(:inner, [d], n in assoc(d, :notification))
      |> join(:inner, [_d, n], e in assoc(n, :event))
      |> where(
        [d, n, e],
        d.status in ^@problem_statuses and d.tenant_id == ^tenant_id and n.tenant_id == ^tenant_id and
          e.tenant_id == ^tenant_id
      )
      |> order_by([d], desc: d.updated_at)
      |> limit(^limit)
      |> select([d, n, e], %{
        delivery_id: d.id,
        event_id: e.id,
        notification_key: e.notification_key,
        notification_version: e.notification_version,
        recipient_id: n.recipient_identity,
        channel: d.channel,
        status: d.status,
        suppression_reason: d.suppression_reason,
        planning_reason: d.planning_reason,
        tenant_id: d.tenant_id,
        correlation_id: e.correlation_id,
        inserted_at: d.inserted_at,
        updated_at: d.updated_at
      })
      |> Repo.all(repo_opts(opts))
      |> Enum.map(&delivery_dto/1)
    end
  end

  @doc """
  Lists persisted notification definitions inferred from durable rows.

  Code-defined notifier registry/skew detection can be layered on later; this
  first pass is deliberately based on the local database source of truth.
  """
  @spec definitions(keyword()) :: [map()]
  def definitions(opts \\ []) do
    with {:ok, tenant_id} <- TenantScope.resolve(opts) do
      limit = Keyword.get(opts, :limit, 100)

      Event
      |> join(:left, [e], n in assoc(e, :notifications), on: n.tenant_id == ^tenant_id)
      |> join(:left, [_e, n], d in assoc(n, :deliveries), on: d.tenant_id == ^tenant_id)
      |> where([e], e.tenant_id == ^tenant_id)
      |> group_by([e], [e.notification_key, e.notification_version])
      |> order_by([e], asc: e.notification_key, desc: e.notification_version)
      |> limit(^limit)
      |> select([e, n, d], %{
        notification_key: e.notification_key,
        notification_version: e.notification_version,
        event_count: count(e.id, :distinct),
        recipient_count: count(n.id, :distinct),
        delivery_count: count(d.id, :distinct),
        channels: fragment("array_remove(array_agg(DISTINCT ?), NULL)", d.channel),
        last_seen_at: max(e.inserted_at)
      })
      |> Repo.all(repo_opts(opts))
      |> Enum.map(fn row ->
        %{
          notification_key: row.notification_key,
          notification_version: row.notification_version,
          event_count: row.event_count,
          recipient_count: row.recipient_count,
          delivery_count: row.delivery_count,
          channels: Enum.sort(row.channels || []),
          last_seen_at: row.last_seen_at
        }
      end)
    end
  end

  @doc """
  Lists per-recipient notification feed facts for operator debugging.
  """
  @spec feed(keyword()) :: [map()]
  def feed(opts \\ []) do
    with {:ok, tenant_id} <- TenantScope.resolve(opts) do
      limit = Keyword.get(opts, :limit, @default_limit)

      Notification
      |> join(:inner, [n], e in assoc(n, :event))
      |> join(:left, [n, _e], d in assoc(n, :deliveries), on: d.tenant_id == ^tenant_id)
      |> maybe_filter_recipient(Keyword.get(opts, :recipient_id))
      |> where([n, e], n.tenant_id == ^tenant_id and e.tenant_id == ^tenant_id)
      |> group_by([n, e], [
        n.id,
        n.recipient_identity,
        n.seen_at,
        n.read_at,
        n.archived_at,
        n.inserted_at,
        e.id,
        e.notification_key,
        e.notification_version,
        e.correlation_id
      ])
      |> order_by([n], desc: n.inserted_at)
      |> limit(^limit)
      |> select([n, e, d], %{
        notification_id: n.id,
        event_id: e.id,
        notification_key: e.notification_key,
        notification_version: e.notification_version,
        recipient_id: n.recipient_identity,
        seen_at: n.seen_at,
        read_at: n.read_at,
        archived_at: n.archived_at,
        inserted_at: n.inserted_at,
        correlation_id: e.correlation_id,
        delivery_count: count(d.id),
        channels: fragment("array_remove(array_agg(DISTINCT ?), NULL)", d.channel),
        statuses: fragment("array_remove(array_agg(DISTINCT ?), NULL)", d.status)
      })
      |> Repo.all(repo_opts(opts))
      |> Enum.map(fn row ->
        %{
          notification_id: row.notification_id,
          event_id: row.event_id,
          notification_key: row.notification_key,
          notification_version: row.notification_version,
          recipient_id: row.recipient_id,
          channel_summary: Enum.sort(row.channels || []),
          status_summary: Enum.sort(Enum.map(row.statuses || [], &to_string/1)),
          state: feed_state(row),
          delivery_count: row.delivery_count,
          correlation_id: row.correlation_id,
          inserted_at: row.inserted_at
        }
      end)
    end
  end

  @doc """
  Lists recoverable events and deliveries as redaction-ready DTOs.
  """
  @spec recovery_candidates(keyword()) :: [map()]
  def recovery_candidates(opts \\ []) do
    with {:ok, tenant_id} <- TenantScope.resolve(opts) do
      limit = Keyword.get(opts, :limit, @default_limit)
      now = Keyword.get(opts, :now, DateTime.utc_now())

      delivery_rows =
        Delivery
        |> join(:inner, [d], n in assoc(d, :notification))
        |> join(:inner, [_d, n], e in assoc(n, :event))
        |> where([d], d.status == :pending and d.orchestration_state == :ready)
        |> where([d], fragment("?->>? IS NULL", d.metadata, ^"recovered_at"))
        |> maybe_older_than(now, Keyword.get(opts, :older_than, 60))
        |> where(
          [d, n, e],
          d.tenant_id == ^tenant_id and n.tenant_id == ^tenant_id and e.tenant_id == ^tenant_id
        )
        |> order_by([d], asc: d.updated_at, asc: d.inserted_at)
        |> limit(^limit)
        |> select([d, n, e], %{
          type: "delivery",
          id: d.id,
          delivery_id: d.id,
          event_id: e.id,
          notification_key: e.notification_key,
          notification_version: e.notification_version,
          recipient_id: n.recipient_identity,
          channel: d.channel,
          tenant_id: d.tenant_id,
          status: d.status,
          orchestration_state: d.orchestration_state,
          reason: "pending ready row older than recovery threshold",
          correlation_id: e.correlation_id,
          inserted_at: d.inserted_at,
          updated_at: d.updated_at
        })
        |> Repo.all(repo_opts(opts))

      event_rows =
        Event
        |> join(:inner, [e], n in assoc(e, :notifications), on: n.tenant_id == ^tenant_id)
        |> join(:left, [_e, n], d in assoc(n, :deliveries))
        |> maybe_older_event_than(now, Keyword.get(opts, :older_than, 60))
        |> where([e], e.tenant_id == ^tenant_id)
        |> group_by([e], [
          e.id,
          e.notification_key,
          e.notification_version,
          e.correlation_id,
          e.inserted_at,
          e.updated_at
        ])
        |> having([_e, _n, d], count(d.id) == 0)
        |> order_by([e], asc: e.updated_at, asc: e.inserted_at)
        |> limit(^limit)
        |> select([e], %{
          type: "event",
          id: e.id,
          delivery_id: nil,
          event_id: e.id,
          notification_key: e.notification_key,
          notification_version: e.notification_version,
          recipient_id: nil,
          channel: nil,
          tenant_id: e.tenant_id,
          status: nil,
          orchestration_state: nil,
          reason: "event has notifications but no planned deliveries",
          correlation_id: e.correlation_id,
          inserted_at: e.inserted_at,
          updated_at: e.updated_at
        })
        |> Repo.all(repo_opts(opts))

      (delivery_rows ++ event_rows)
      |> Enum.sort_by(& &1.updated_at, DateTime)
      |> Enum.take(limit)
      |> Enum.map(&recovery_dto/1)
    end
  end

  @doc """
  Returns outcome totals suitable for status cards.
  """
  @spec outcome_totals(keyword()) :: map()
  def outcome_totals(opts \\ []) do
    with {:ok, tenant_id} <- TenantScope.resolve(opts) do
      Delivery
      |> where([d], d.tenant_id == ^tenant_id)
      |> group_by([d], [d.status])
      |> select([d], {d.status, count(d.id)})
      |> Repo.all(repo_opts(opts))
      |> Map.new(fn {status, count} -> {to_string(status), count} end)
    end
  end

  defp delivery_dto(row) do
    %{
      delivery_id: row.delivery_id,
      event_id: row.event_id,
      notification_key: row.notification_key,
      notification_version: row.notification_version,
      recipient_id: row.recipient_id,
      channel: row.channel,
      status: to_string(row.status),
      suppression_reason: row.suppression_reason,
      planning_reason: row.planning_reason,
      tenant_id: row.tenant_id,
      correlation_id: row.correlation_id,
      inserted_at: row.inserted_at,
      updated_at: row.updated_at
    }
  end

  defp recovery_dto(row) do
    row
    |> Map.update!(:status, &string_or_nil/1)
    |> Map.update!(:orchestration_state, &string_or_nil/1)
  end

  defp feed_state(%{archived_at: %DateTime{}}), do: "archived"
  defp feed_state(%{read_at: %DateTime{}}), do: "read"
  defp feed_state(%{seen_at: %DateTime{}}), do: "seen"
  defp feed_state(_), do: "unread"

  defp string_or_nil(nil), do: nil
  defp string_or_nil(value), do: to_string(value)

  defp maybe_filter_recipient(query, nil), do: query
  defp maybe_filter_recipient(query, ""), do: query

  defp maybe_filter_recipient(query, recipient_id),
    do: where(query, [n], n.recipient_identity == ^recipient_id)

  defp maybe_older_than(query, %DateTime{} = now, older_than) when is_integer(older_than) do
    cutoff = DateTime.add(now, -older_than, :second)
    where(query, [d], d.updated_at <= ^cutoff)
  end

  defp maybe_older_than(query, _now, _older_than), do: query

  defp maybe_older_event_than(query, %DateTime{} = now, older_than) when is_integer(older_than) do
    cutoff = DateTime.add(now, -older_than, :second)
    where(query, [e], e.updated_at <= ^cutoff)
  end

  defp maybe_older_event_than(query, _now, _older_than), do: query

  defp repo_opts(opts) do
    opts
    |> Keyword.drop([:limit, :tenant_id, :recipient_id, :now, :older_than])
    |> Chimeway.Storage.repo_opts()
  end
end

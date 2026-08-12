defmodule Chimeway.Reconciliation do
  @moduledoc """
  Safe maintenance operations for legacy lifecycle rows without tenant ownership.

  The report deliberately exposes only durable identifiers and NULL ownership.
  Assignment is explicit: Chimeway never derives a tenant from lifecycle data.
  """

  import Ecto.Query

  alias Chimeway.{Delivery, Repo, Storage}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  @schema_version 1
  @assignment_instruction "host must explicitly supply tenant_id; no inference performed"

  @spec report(keyword()) :: map()
  def report(opts \\ []) do
    repo_opts = repo_opts(opts)

    events =
      Event
      |> where([event], is_nil(event.tenant_id))
      |> order_by([event], asc: event.id)
      |> select([event], %{id: event.id, tenant_id: event.tenant_id})
      |> Repo.all(repo_opts)

    event_ids = Enum.map(events, & &1.id)

    notification_ids_by_event =
      Notification
      |> where([notification], notification.event_id in ^event_ids)
      |> where([notification], is_nil(notification.tenant_id))
      |> order_by([notification], asc: notification.event_id, asc: notification.id)
      |> select([notification], {notification.event_id, notification.id})
      |> Repo.all(repo_opts)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    report_events =
      Enum.map(events, fn event ->
        %{
          id: event.id,
          tenant_id: nil,
          notification_ids: Map.get(notification_ids_by_event, event.id, [])
        }
      end)

    %{
      schema_version: @schema_version,
      status: "ambiguous_tenant_ownership",
      counts: %{
        events: length(report_events),
        notifications: map_size_notification_count(notification_ids_by_event)
      },
      events: report_events,
      assignment: @assignment_instruction
    }
  end

  @spec assign_event_tree(String.t(), String.t(), keyword()) ::
          {:ok, map()}
          | {:error,
             :invalid_event_id
             | :invalid_tenant_id
             | :not_found
             | :already_assigned
             | :ownership_conflict}
  def assign_event_tree(event_id, tenant_id, opts \\ []) do
    with {:ok, event_id} <- validate_event_id(event_id),
         {:ok, tenant_id} <- validate_tenant_id(tenant_id) do
      Repo.transaction(fn -> assign_locked_event_tree(event_id, tenant_id, repo_opts(opts)) end)
      |> unwrap_transaction()
    end
  end

  defp assign_locked_event_tree(event_id, tenant_id, repo_opts) do
    event =
      Event
      |> where([event], event.id == ^event_id)
      |> lock("FOR UPDATE")
      |> Repo.one(repo_opts)

    notifications =
      Notification
      |> where([notification], notification.event_id == ^event_id)
      |> order_by([notification], asc: notification.id)
      |> lock("FOR UPDATE")
      |> Repo.all(repo_opts)

    deliveries =
      Delivery
      |> join(:inner, [delivery], notification in Notification,
        on: notification.id == delivery.notification_id
      )
      |> where([_delivery, notification], notification.event_id == ^event_id)
      |> order_by([delivery], asc: delivery.id)
      |> lock("FOR UPDATE")
      |> Repo.all(repo_opts)

    case event do
      nil ->
        Repo.rollback(:not_found)

      %Event{tenant_id: ^tenant_id} ->
        Repo.rollback(:already_assigned)

      %Event{tenant_id: tenant} when is_binary(tenant) ->
        Repo.rollback(:ownership_conflict)

      %Event{} ->
        if Enum.any?(notifications, &is_binary(&1.tenant_id)) or
             Enum.any?(deliveries, &(is_binary(&1.tenant_id) and &1.tenant_id != tenant_id)) do
          Repo.rollback(:ownership_conflict)
        end

        {1, _} =
          Event
          |> where([event], event.id == ^event_id and is_nil(event.tenant_id))
          |> Repo.update_all([set: [tenant_id: tenant_id]], repo_opts)

        {notification_count, _} =
          Notification
          |> where(
            [notification],
            notification.event_id == ^event_id and is_nil(notification.tenant_id)
          )
          |> Repo.update_all([set: [tenant_id: tenant_id]], repo_opts)

        {delivery_count, _} =
          Delivery
          |> join(:inner, [delivery], notification in Notification,
            on: notification.id == delivery.notification_id
          )
          |> where(
            [_delivery, notification],
            notification.event_id == ^event_id and is_nil(_delivery.tenant_id)
          )
          |> Repo.update_all([set: [tenant_id: tenant_id]], repo_opts)

        %{
          schema_version: @schema_version,
          status: "assigned",
          event_id: event_id,
          tenant_id: tenant_id,
          counts: %{events: 1, notifications: notification_count, deliveries: delivery_count}
        }
    end
  end

  defp unwrap_transaction({:ok, result}), do: {:ok, result}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}

  defp validate_event_id(event_id) when is_binary(event_id) do
    case Ecto.UUID.cast(event_id) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, :invalid_event_id}
    end
  end

  defp validate_event_id(_), do: {:error, :invalid_event_id}

  defp validate_tenant_id(tenant_id) when is_binary(tenant_id) do
    case String.trim(tenant_id) do
      "" -> {:error, :invalid_tenant_id}
      value -> {:ok, value}
    end
  end

  defp validate_tenant_id(_), do: {:error, :invalid_tenant_id}

  defp repo_opts(opts), do: opts |> Keyword.delete(:tenant_id) |> Storage.repo_opts()

  defp map_size_notification_count(ids_by_event),
    do: ids_by_event |> Map.values() |> List.flatten() |> length()
end

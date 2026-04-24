defmodule Chimeway.DeliveryPlanning do
  @moduledoc """
  Shared fanout planner used by all dispatch strategies.

  Dispatch modules must plan through this module and must not call
  `Chimeway.Deliveries.plan_delivery/3` directly.
  """

  alias Chimeway.{Deliveries, Delivery, Policy}
  alias Chimeway.Notifications.Notification

  @spec plan_notifications([Notification.t()], keyword()) :: {:ok, [Delivery.t()]} | {:error, term()}
  def plan_notifications(notifications, opts \\ []) when is_list(notifications) do
    notifications
    |> Enum.sort_by(& &1.id)
    |> Enum.reduce_while({:ok, []}, fn notification, {:ok, acc} ->
      case plan_notification(notification, opts) do
        {:ok, deliveries} -> {:cont, {:ok, [deliveries | acc]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, grouped_deliveries} ->
        {:ok, grouped_deliveries |> Enum.reverse() |> List.flatten()}

      {:error, _reason} = error ->
        error
    end
  end

  @spec plan_notification(Notification.t(), keyword()) :: {:ok, [Delivery.t()]} | {:error, term()}
  def plan_notification(%Notification{} = notification, opts \\ []) do
    with {:ok, channels} <- resolve_channels(notification, opts),
         {:ok, delayed_fallback_channels, delayed_fallback_source} <-
           resolve_delayed_fallback_channels(notification, channels, opts) do
      delayed_fallback_set = MapSet.new(delayed_fallback_channels)

      channels
      |> Enum.reduce_while({:ok, []}, fn channel, {:ok, acc} ->
        with {:ok, delivery} <-
               Deliveries.plan_delivery(notification.id, channel, delay_fallback: MapSet.member?(delayed_fallback_set, channel), delayed_fallback_source: delayed_fallback_source_for(channel, delayed_fallback_set, delayed_fallback_source)),
             {:ok, planned_delivery} <- evaluate_planning_policy(delivery) do
          {:cont, {:ok, [planned_delivery | acc]}}
        else
          {:error, _reason} = error -> {:halt, error}
        end
      end)
      |> case do
        {:ok, deliveries} -> {:ok, Enum.reverse(deliveries)}
        {:error, _reason} = error -> error
      end
    end
  end

  defp resolve_channels(notification, opts) do
    notifier = Keyword.get(opts, :notifier)
    trigger_params = normalize_trigger_params(Keyword.get(opts, :trigger_params, %{}))
    recipient = notification_recipient(notification)

    if notifier && function_exported?(notifier, :channels, 2) do
      case notifier.channels(trigger_params, recipient) do
        {:ok, channels} ->
          case normalize_channels(channels) do
            {:ok, normalized_channels} ->
              {:ok, normalized_channels}

            {:error, reason} ->
              {:error, {:channels_resolution_failed, reason}}
          end

        {:error, reason} ->
          {:error, {:channels_resolution_failed, reason}}

        unexpected ->
          {:error, {:channels_resolution_failed, {:unexpected_result, unexpected}}}
      end
    else
      normalize_channels([:in_app])
    end
  end

  defp resolve_delayed_fallback_channels(notification, channels, opts) do
    with {:ok, delayed_fallback_channels, source} <-
           delayed_fallback_channels_for(notification, opts),
         :ok <- validate_delayed_fallback_channels(delayed_fallback_channels, channels) do
      {:ok, delayed_fallback_channels, source}
    end
  end

  defp delayed_fallback_channels_for(notification, opts) do
    notifier = Keyword.get(opts, :notifier)
    trigger_params = normalize_trigger_params(Keyword.get(opts, :trigger_params, %{}))
    recipient = notification_recipient(notification)

    if notifier && function_exported?(notifier, :delayed_fallback_channels, 2) do
      case notifier.delayed_fallback_channels(trigger_params, recipient) do
        {:ok, channels} ->
          case normalize_channels(channels) do
            {:ok, normalized_channels} ->
              {:ok, normalized_channels, :notifier}

            {:error, reason} ->
              {:error, {:delayed_fallback_resolution_failed, reason}}
          end

        {:error, reason} ->
          {:error, {:delayed_fallback_resolution_failed, reason}}

        unexpected ->
          {:error, {:delayed_fallback_resolution_failed, {:unexpected_result, unexpected}}}
      end
    else
      resolve_policy_delayed_fallback_channels(opts)
    end
  end

  defp resolve_policy_delayed_fallback_channels(opts) do
    opts
    |> Keyword.get(:policy_delayed_fallback_channels, Keyword.get(opts, :delayed_fallback_channels))
    |> case do
      nil ->
        {:ok, [], :default}

      channels ->
        case normalize_channels(channels) do
          {:ok, normalized_channels} ->
            {:ok, normalized_channels, :policy}

          {:error, reason} ->
            {:error, {:delayed_fallback_resolution_failed, reason}}
        end
    end
  end

  defp delayed_fallback_source_for(channel, delayed_fallback_set, source) do
    if MapSet.member?(delayed_fallback_set, channel), do: source, else: :default
  end

  defp validate_delayed_fallback_channels(delayed_fallback_channels, channels) do
    delayed_fallback_set = MapSet.new(delayed_fallback_channels)

    if MapSet.member?(delayed_fallback_set, "in_app") do
      {:error, {:invalid_delayed_fallback_channels, ["in_app"]}}
    else
      invalid_channels =
        delayed_fallback_set
        |> MapSet.difference(MapSet.new(channels))
        |> MapSet.to_list()
        |> Enum.sort()

      if invalid_channels == [] do
        :ok
      else
        {:error, {:invalid_delayed_fallback_channels, invalid_channels}}
      end
    end
  end

  defp normalize_channels(channels) when is_list(channels) do
    channels
    |> Enum.reduce_while({:ok, MapSet.new()}, fn
      channel, {:ok, acc} when is_atom(channel) ->
        {:cont, {:ok, MapSet.put(acc, Atom.to_string(channel))}}

      channel, {:ok, acc} when is_binary(channel) ->
        normalized_channel = String.trim(channel)

        if normalized_channel == "" do
          {:halt, {:error, {:invalid_channel, channel}}}
        else
          {:cont, {:ok, MapSet.put(acc, normalized_channel)}}
        end

      channel, _acc ->
        {:halt, {:error, {:invalid_channel, channel}}}
    end)
    |> case do
      {:ok, deduped_channels} ->
        {:ok, deduped_channels |> MapSet.to_list() |> Enum.sort()}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_channels(channels), do: {:error, {:invalid_channels, channels}}

  defp evaluate_planning_policy(delivery) do
    case Policy.evaluate(delivery, []) do
      {:ok, :proceed} ->
        {:ok, delivery}

      {:suppress, reason} ->
        suppress_delivery_at_planning_checkpoint(delivery, reason)
    end
  end

  defp suppress_delivery_at_planning_checkpoint(delivery, reason) do
    suppression_opts = [checkpoint: :planning]

    if function_exported?(Deliveries, :suppress_delivery, 3) do
      apply(Deliveries, :suppress_delivery, [delivery, reason, suppression_opts])
    else
      Deliveries.suppress_delivery(delivery, reason)
    end
  end

  defp normalize_trigger_params(params) when is_map(params), do: params
  defp normalize_trigger_params(_params), do: %{}

  defp notification_recipient(%Notification{} = notification) do
    %{
      recipient_identity: notification.recipient_identity,
      recipient_type: notification.recipient_type,
      metadata: notification.metadata || %{}
    }
  end
end

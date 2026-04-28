defmodule Chimeway.DeliveryPlanning do
  @moduledoc """
  Shared fanout planner used by all dispatch strategies.

  Dispatch modules must plan through this module and must not call
  `Chimeway.Deliveries.plan_delivery/3` directly.
  """

  alias Chimeway.{Deliveries, Delivery, Notifier, Policy}
  alias Chimeway.Notifications.Notification

  @spec plan_notifications([Notification.t()], keyword()) ::
          {:ok, [Delivery.t()]} | {:error, term()}
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
      plan_channels(
        notification,
        channels,
        delayed_fallback_channels,
        delayed_fallback_source,
        opts
      )
    end
  end

  defp plan_channels(
         notification,
         channels,
         delayed_fallback_channels,
         delayed_fallback_source,
         opts
       ) do
    delayed_fallback_set = MapSet.new(delayed_fallback_channels)

    channels
    |> Enum.reduce_while({:ok, []}, fn channel, {:ok, acc} ->
      case plan_one_channel(
             notification,
             channel,
             delayed_fallback_set,
             delayed_fallback_source,
             opts
           ) do
        {:ok, planned_delivery} -> {:cont, {:ok, [planned_delivery | acc]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, deliveries} -> {:ok, Enum.reverse(deliveries)}
      {:error, _reason} = error -> error
    end
  end

  defp plan_one_channel(
         notification,
         channel,
         delayed_fallback_set,
         delayed_fallback_source,
         opts
       ) do
    delay_fallback = MapSet.member?(delayed_fallback_set, channel)
    source = delayed_fallback_source_for(channel, delayed_fallback_set, delayed_fallback_source)
    trigger_params = normalize_trigger_params(Keyword.get(opts, :trigger_params, %{}))
    recipient = notification_recipient(notification)

    with {:ok, delivery} <-
           Deliveries.plan_delivery(notification.id, channel,
             delay_fallback: delay_fallback,
             delayed_fallback_source: source,
             notification_key: Keyword.get(opts, :notification_key),
             event_id: Keyword.get(opts, :event_id),
             correlation_id: Keyword.get(opts, :correlation_id)
           ),
         {:ok, orchestration} <-
           resolve_orchestration(opts, trigger_params, recipient),
         {:ok, delivery} <- apply_declared_orchestration(delivery, channel, orchestration) do
      evaluate_planning_policy(delivery, opts)
    end
  end

  defp resolve_channels(notification, opts) do
    notifier = Keyword.get(opts, :notifier)
    trigger_params = normalize_trigger_params(Keyword.get(opts, :trigger_params, %{}))
    recipient = notification_recipient(notification)

    if notifier && function_exported?(notifier, :channels, 2) do
      handle_notifier_channels(notifier.channels(trigger_params, recipient))
    else
      normalize_channels([:in_app])
    end
  end

  defp handle_notifier_channels({:ok, channels}),
    do: wrap_normalized_channels(normalize_channels(channels))

  defp handle_notifier_channels({:error, reason}),
    do: {:error, {:channels_resolution_failed, reason}}

  defp handle_notifier_channels(unexpected),
    do: {:error, {:channels_resolution_failed, {:unexpected_result, unexpected}}}

  defp wrap_normalized_channels({:ok, normalized_channels}), do: {:ok, normalized_channels}

  defp wrap_normalized_channels({:error, reason}),
    do: {:error, {:channels_resolution_failed, reason}}

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
      handle_notifier_delayed_fallback(
        notifier.delayed_fallback_channels(trigger_params, recipient)
      )
    else
      resolve_policy_delayed_fallback_channels(opts)
    end
  end

  defp handle_notifier_delayed_fallback({:ok, channels}) do
    case normalize_channels(channels) do
      {:ok, normalized_channels} -> {:ok, normalized_channels, :notifier}
      {:error, reason} -> {:error, {:delayed_fallback_resolution_failed, reason}}
    end
  end

  defp handle_notifier_delayed_fallback({:error, reason}),
    do: {:error, {:delayed_fallback_resolution_failed, reason}}

  defp handle_notifier_delayed_fallback(unexpected),
    do: {:error, {:delayed_fallback_resolution_failed, {:unexpected_result, unexpected}}}

  defp resolve_policy_delayed_fallback_channels(opts) do
    opts
    |> Keyword.get(
      :policy_delayed_fallback_channels,
      Keyword.get(opts, :delayed_fallback_channels)
    )
    |> case do
      nil -> {:ok, [], :default}
      channels -> handle_policy_channels(normalize_channels(channels))
    end
  end

  defp handle_policy_channels({:ok, normalized_channels}), do: {:ok, normalized_channels, :policy}

  defp handle_policy_channels({:error, reason}),
    do: {:error, {:delayed_fallback_resolution_failed, reason}}

  defp delayed_fallback_source_for(channel, delayed_fallback_set, source) do
    if MapSet.member?(delayed_fallback_set, channel), do: source, else: :default
  end

  defp validate_delayed_fallback_channels(delayed_fallback_channels, channels) do
    delayed_fallback_set = MapSet.new(delayed_fallback_channels)

    if MapSet.member?(delayed_fallback_set, "in_app") do
      {:error, {:invalid_delayed_fallback_channels, ["in_app"]}}
    else
      check_invalid_channels(delayed_fallback_set, channels)
    end
  end

  defp check_invalid_channels(delayed_fallback_set, channels) do
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

  defp normalize_channels(channels) when is_list(channels) do
    channels
    |> Enum.reduce_while({:ok, MapSet.new()}, &do_normalize_channel/2)
    |> case do
      {:ok, deduped_channels} ->
        {:ok, deduped_channels |> MapSet.to_list() |> Enum.sort()}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_channels(channels), do: {:error, {:invalid_channels, channels}}

  defp do_normalize_channel(channel, {:ok, acc}) when is_atom(channel) do
    {:cont, {:ok, MapSet.put(acc, Atom.to_string(channel))}}
  end

  defp do_normalize_channel(channel, {:ok, acc}) when is_binary(channel) do
    normalized_channel = String.trim(channel)

    if normalized_channel == "" do
      {:halt, {:error, {:invalid_channel, channel}}}
    else
      {:cont, {:ok, MapSet.put(acc, normalized_channel)}}
    end
  end

  defp do_normalize_channel(channel, _acc) do
    {:halt, {:error, {:invalid_channel, channel}}}
  end

  defp evaluate_planning_policy(delivery, opts) do
    case Policy.evaluate(delivery, Keyword.put(opts, :checkpoint, :planning)) do
      {:ok, :proceed} ->
        {:ok, delivery}

      {:defer, decision} ->
        Deliveries.apply_planning_decision(delivery, decision)

      {:suppress, reason} ->
        suppress_delivery_at_planning_checkpoint(delivery, reason)
    end
  end

  defp suppress_delivery_at_planning_checkpoint(delivery, reason) do
    Deliveries.suppress_delivery(delivery, reason, checkpoint: :planning)
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

  defp resolve_orchestration(opts, trigger_params, recipient) do
    Notifier.resolve_orchestration(
      Keyword.get(opts, :notifier),
      trigger_params,
      recipient,
      Keyword.get(opts, :orchestration, :unset)
    )
  end

  defp apply_declared_orchestration(delivery, channel, orchestration) do
    mode = Map.get(orchestration.channels, channel, orchestration.default)

    decision =
      case mode do
        :digest_held ->
          %{
            orchestration_state: :digest_held,
            planning_reason: "digest_rule",
            planning_context: %{
              "channel" => channel,
              "source" => Atom.to_string(Map.get(orchestration, :source, :default))
            },
            next_eligible_at: nil
          }

        :immediate ->
          %{
            orchestration_state: :ready,
            planning_reason: nil,
            planning_context: nil,
            next_eligible_at: nil
          }
      end

    Deliveries.apply_planning_decision(delivery, decision)
  end
end

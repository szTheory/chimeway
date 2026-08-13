defmodule Chimeway.DeliveryPlanning do
  @moduledoc """
  Shared fanout planner used by all dispatch strategies.

  Dispatch modules must plan through this module and must not call
  `Chimeway.Deliveries.plan_delivery/3` directly.
  """

  alias Chimeway.{
    Deliveries,
    Delivery,
    Notifier,
    Policy,
    RenderContextResolver,
    Rendering,
    Repo,
    Workflows
  }

  alias Chimeway.Digests.Accumulation
  alias Chimeway.Events.Event
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

  @doc """
  Plans exactly one canonical delivery for the given `channel` on the supplied
  notification using the current active-step workflow linkage.

  Used by `Chimeway.Workflows.Progression` after the engine advances the run
  cursor to the next step — the planner reuses the same idempotent
  `Deliveries.plan_delivery/3` path and the same `resolve_workflow_linkage/3`
  helper so progression-emitted next-step rows go through one canonical
  planning seam (D-10).
  """
  @spec plan_next_step_delivery(Notification.t(), atom() | binary(), keyword()) ::
          {:ok, Delivery.t()} | {:error, term()}
  def plan_next_step_delivery(%Notification{} = notification, channel, opts \\ [])
      when is_list(opts) do
    plan_one_channel(notification, to_string(channel), MapSet.new(), :default, opts)
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
    trigger_params = render_trigger_params(notification, Keyword.get(opts, :trigger_params, %{}))
    recipient = notification_recipient(notification)
    workflow_linkage = resolve_workflow_linkage(notification, channel, opts)

    recipient_address = Map.get(Keyword.get(opts, :recipient_handoffs, %{}), notification.id)

    opts = Keyword.put_new(opts, :recipient, recipient)

    with {:ok, tenant_id} <- resolve_delivery_tenant(notification, opts),
         {:ok, render_result} <-
           resolve_render_result(notification, channel, trigger_params, opts),
         {:ok, delivery} <-
           Deliveries.plan_delivery(notification.id, channel,
             tenant_id: tenant_id,
             actor_id: notification.recipient_identity || "system",
             delay_fallback: delay_fallback,
             delayed_fallback_source: source,
             notification_key: Keyword.get(opts, :notification_key),
             event_id: Keyword.get(opts, :event_id),
             correlation_id: Keyword.get(opts, :correlation_id),
             render_key: render_result[:render_key],
             render_version: render_result[:render_version],
             render_data: %{},
             workflow_run_id: workflow_linkage[:workflow_run_id],
             workflow_step_id: workflow_linkage[:workflow_step_id]
           ),
         {:ok, delivery} <-
           maybe_apply_render_result(delivery, render_result),
         {:ok, delivery} <- attach_recipient_address(delivery, recipient_address),
         {:ok, delivery} <- maybe_apply_workflow_linkage(delivery, workflow_linkage),
         {:ok, orchestration} <-
           resolve_orchestration(notification, opts, trigger_params, recipient),
         {:ok, delivery} <- apply_declared_orchestration(delivery, channel, orchestration) do
      with {:ok, delivery} <- evaluate_planning_policy(delivery, opts),
           {:ok, delivery} <- maybe_accumulate_digest_delivery(delivery) do
        {:ok, attach_render_data(delivery, render_result)}
      end
    end
  end

  defp resolve_delivery_tenant(%Notification{tenant_id: tenant_id}, opts)
       when is_binary(tenant_id) and byte_size(tenant_id) > 0 do
    case Keyword.fetch(opts, :tenant_id) do
      :error -> {:ok, tenant_id}
      {:ok, ^tenant_id} -> {:ok, tenant_id}
      {:ok, _other_tenant_id} -> {:error, :tenant_mismatch}
    end
  end

  defp resolve_delivery_tenant(%Notification{}, _opts), do: {:error, :tenant_mismatch}

  defp resolve_channels(notification, opts) do
    notifier = Keyword.get(opts, :notifier)
    trigger_params = normalize_trigger_params(Keyword.get(opts, :trigger_params, %{}))
    recipient = notification_recipient(notification)

    if notifier && function_exported?(notifier, :channels, 2) do
      handle_notifier_channels(notifier.channels(trigger_params, recipient))
    else
      resolve_fallback_channels(notification, opts)
    end
  end

  defp resolve_fallback_channels(notification, opts) do
    if Keyword.get(opts, :use_persisted_channels, false) == true do
      resolve_persisted_channels(notification, opts)
    else
      {:ok, ["in_app"]}
    end
  end

  defp resolve_persisted_channels(
         %Notification{render_channels: render_channels} = notification,
         opts
       ) do
    (normalize_render_channels(render_channels) ++
       persisted_orchestration_channels(notification) ++ workflow_channels(notification, opts))
    |> Enum.uniq()
    |> case do
      [] -> normalize_channels([:in_app])
      channels -> normalize_channels(channels)
    end
  end

  defp normalize_render_channels(render_channels) when is_map(render_channels) do
    render_channels
    |> Map.keys()
    |> Enum.sort()
  end

  defp normalize_render_channels(_render_channels), do: []

  defp persisted_orchestration_channels(%Notification{orchestration: orchestration})
       when is_map(orchestration) do
    orchestration |> Map.get("channels", %{}) |> Map.keys() |> Enum.map(&to_string/1)
  end

  defp persisted_orchestration_channels(_notification), do: []

  defp workflow_channels(notification, opts) do
    if use_workflow_linkage?(notification, opts) do
      case Workflows.active_step_linkage(notification) do
        {:ok, %{channel: channel}} -> [channel]
        _ -> []
      end
    else
      []
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

  defp render_trigger_params(_notification, trigger_params),
    do: normalize_trigger_params(trigger_params)

  defp notification_recipient(%Notification{} = notification) do
    %{
      recipient_identity: notification.recipient_identity,
      recipient_type: notification.recipient_type,
      metadata: notification.metadata || %{}
    }
  end

  defp resolve_orchestration(notification, opts, trigger_params, recipient) do
    Notifier.resolve_orchestration(
      Keyword.get(opts, :notifier),
      trigger_params,
      recipient,
      orchestration_override(notification, opts)
    )
  end

  defp orchestration_override(%Notification{} = notification, opts) do
    cond do
      Keyword.has_key?(opts, :orchestration) ->
        Keyword.get(opts, :orchestration)

      Keyword.get(opts, :use_persisted_orchestration, false) == true and
        is_map(notification.orchestration) and map_size(notification.orchestration) > 0 ->
        Notifier.persisted_orchestration_override(notification.orchestration)

      true ->
        :unset
    end
  end

  defp apply_declared_orchestration(delivery, channel, orchestration) do
    mode = Map.get(orchestration.channels, channel, orchestration.default)

    digest_key =
      Map.get(
        orchestration.digest_keys,
        channel,
        Map.get(orchestration, :default_digest_key)
      )

    decision =
      case mode do
        :digest_held ->
          %{
            orchestration_state: :digest_held,
            planning_reason: "digest_rule",
            planning_context: digest_planning_context(channel, orchestration, digest_key),
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

  defp resolve_render_result(notification, channel, trigger_params, opts) do
    case Map.fetch(Keyword.get(opts, :precomputed_rendering, %{}), {notification.id, channel}) do
      {:ok, result} ->
        {:ok, result}

      :error ->
        if use_persisted_rendering?(opts) do
          resolve_persisted_render_result(notification, channel, trigger_params, opts)
        else
          {:ok, %{}}
        end
    end
  end

  defp use_persisted_rendering?(opts) do
    Keyword.has_key?(opts, :notifier) or Keyword.get(opts, :use_persisted_channels, false) == true
  end

  defp resolve_persisted_render_result(notification, channel, trigger_params, opts) do
    render_channels = notification.render_channels || %{}

    case Map.fetch(render_channels, channel) do
      {:ok, channel_rendering} ->
        render_key =
          Map.get(channel_rendering, "render_key") || Map.get(channel_rendering, :render_key)

        render_version =
          Map.get(channel_rendering, "render_version") ||
            Map.get(channel_rendering, :render_version)

        normalized_rendering = %{
          render_key: render_key,
          render_version: render_version
        }

        with {:ok, assigns} <- render_assigns(notification, trigger_params, opts),
             {:ok, result} <- render_channel_result(channel, normalized_rendering, assigns) do
          {:ok, result}
        else
          {:error, :render_context_unavailable} when not is_nil(notification.render_channels) ->
            {:ok, Map.put(normalized_rendering, :render_data, %{})}

          error ->
            error
        end

      :error ->
        if Keyword.get(opts, :notifier) do
          {:error, {:missing_render_declaration, channel}}
        else
          {:ok, %{}}
        end
    end
  end

  defp render_assigns(notification, trigger_params, opts) do
    case Keyword.fetch(opts, :notifier) do
      {:ok, notifier} ->
        if function_exported?(notifier, :rendering, 2) or function_exported?(notifier, :build, 2) do
          render_assigns_from_notifier(notifier, trigger_params, Keyword.get(opts, :recipient))
        else
          {:ok, notification.render_assigns || %{}}
        end

      :error ->
        render_assigns_from_context(notification)
    end
  end

  defp render_assigns_from_context(%Notification{} = notification) do
    with %Event{notification_key: key, notification_version: version} <-
           Repo.get(Event, notification.event_id),
         {:ok, %{notifier: notifier, params: params, recipient: recipient}} <-
           RenderContextResolver.resolve(key, version, notification.recipient_identity) do
      render_assigns_from_notifier(notifier, params, recipient)
    else
      nil -> {:error, :render_context_unavailable}
      {:error, reason} -> {:error, reason}
    end
  end

  defp render_assigns_from_notifier(_notifier, _params, nil) do
    {:error, :invalid_render_context}
  end

  defp render_assigns_from_notifier(notifier, params, recipient) do
    with {:ok, declaration} <- Notifier.resolve_rendering(notifier, params, recipient) do
      {:ok, Map.drop(declaration.assigns, [:recipient, "recipient"])}
    end
  end

  defp render_channel_result(channel, channel_rendering, assigns) do
    case Rendering.render_delivery(
           channel,
           channel_rendering.render_key,
           channel_rendering.render_version,
           assigns
         ) do
      {:ok, rendered_delivery} ->
        {:ok, rendered_delivery}

      {:error,
       {:rendering_failed, unsupported_channel,
        {:unsupported_render_channel, unsupported_channel}}} ->
        {:ok,
         %{
           channel: unsupported_channel,
           render_key: channel_rendering.render_key,
           render_version: channel_rendering.render_version,
           render_data: %{}
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_apply_render_result(%Delivery{} = delivery, render_result)
       when map_size(render_result) == 0,
       do: {:ok, delivery}

  defp maybe_apply_render_result(%Delivery{} = delivery, render_result) do
    if delivery.render_key == render_result.render_key &&
         delivery.render_version == render_result.render_version do
      {:ok, delivery}
    else
      Deliveries.apply_render_identity(delivery, render_result)
    end
  end

  defp attach_render_data(%Delivery{} = delivery, render_result) when is_map(render_result) do
    %{delivery | render_data: Map.get(render_result, :render_data, %{})}
  end

  defp attach_recipient_address(%Delivery{} = delivery, address) when is_binary(address),
    do: {:ok, %{delivery | recipient_address: address}}

  defp attach_recipient_address(%Delivery{} = delivery, _address), do: {:ok, delivery}

  defp maybe_apply_workflow_linkage(%Delivery{} = delivery, workflow_linkage)
       when map_size(workflow_linkage) == 0,
       do: {:ok, delivery}

  defp maybe_apply_workflow_linkage(%Delivery{} = delivery, workflow_linkage) do
    if delivery.workflow_run_id == workflow_linkage.workflow_run_id &&
         delivery.workflow_step_id == workflow_linkage.workflow_step_id do
      {:ok, delivery}
    else
      Deliveries.apply_workflow_linkage(delivery, workflow_linkage)
    end
  end

  defp resolve_workflow_linkage(%Notification{} = notification, channel, opts) do
    with true <- use_workflow_linkage?(notification, opts),
         {:ok, %{channel: ^channel} = linkage} <- Workflows.active_step_linkage(notification) do
      linkage
    else
      _ -> %{}
    end
  end

  defp use_workflow_linkage?(%Notification{} = notification, opts) do
    Keyword.get(opts, :use_persisted_workflow, false) == true or
      is_binary(notification.workflow_definition_id)
  end

  defp digest_planning_context(channel, orchestration, digest_key) do
    %{
      "channel" => channel,
      "source" => Atom.to_string(Map.get(orchestration, :source, :default))
    }
    |> maybe_put_digest_key(digest_key)
  end

  defp maybe_put_digest_key(planning_context, nil), do: planning_context

  defp maybe_put_digest_key(planning_context, digest_key),
    do: Map.put(planning_context, "digest_key", digest_key)

  defp maybe_accumulate_digest_delivery(%Delivery{} = delivery) do
    if delivery.status == :pending and delivery.orchestration_state == :digest_held do
      lookup_attrs = %{
        recipient_id: notification_recipient_id(delivery),
        channel: delivery.channel,
        notification_key: delivery_notification_key(delivery),
        notification_version: delivery_notification_version(delivery),
        category: Policy.delivery_category(delivery),
        digest_key: delivery_digest_key(delivery)
      }

      case Accumulation.accumulate_delivery(delivery, lookup_attrs: lookup_attrs) do
        {:ok, _bucket_or_noop} -> {:ok, delivery}
        {:error, reason} -> {:error, reason}
      end
    else
      {:ok, delivery}
    end
  end

  defp notification_recipient_id(%Delivery{} = delivery) do
    Notification
    |> Repo.get!(delivery.notification_id)
    |> Map.fetch!(:recipient_identity)
  end

  defp delivery_notification_key(%Delivery{} = delivery) do
    Notification
    |> Repo.get!(delivery.notification_id)
    |> Map.fetch!(:event_id)
    |> then(&Repo.get!(Event, &1))
    |> Map.fetch!(:notification_key)
  end

  defp delivery_notification_version(%Delivery{} = delivery) do
    Notification
    |> Repo.get!(delivery.notification_id)
    |> Map.fetch!(:event_id)
    |> then(&Repo.get!(Event, &1))
    |> Map.fetch!(:notification_version)
  end

  defp delivery_digest_key(%Delivery{planning_context: planning_context})
       when is_map(planning_context) do
    case Map.get(planning_context, "digest_key") do
      digest_key when is_binary(digest_key) and digest_key != "" -> digest_key
      _ -> nil
    end
  end

  defp delivery_digest_key(_delivery), do: nil
end

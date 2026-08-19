defmodule Chimeway.Dispatch.Executor do
  @moduledoc """
  Shared adapter execution for sync and Oban worker dispatch paths.

  ## Phase 14 contract changes (D-05)

  `classify/1` now returns a 3-tuple `{outcome, error_class, detail}` so
  `:temporary | :permanent | :bounced` classification is preserved end-to-end:

      adapter.deliver -> classify -> Deliveries.record_attempt(error_class:)
                                  -> attempt row .error_class column
                                  -> trace explanation
                                  -> Oban worker {:ok | {:error, _}} return

  `run_delivery/1` passes `error_class` into `Deliveries.record_attempt/2`. The
  return shape is unchanged for sync consumers (`{:ok, %{delivery, attempt}}` |
  `{:error, step, reason, changes}` | `{:error, term()}`). Plan 14-05's Oban
  worker reads the recorded attempt's `outcome` + `error_class` to decide its
  Oban return value (retry vs terminal vs success).
  """

  alias Chimeway.{Deliveries, Delivery, DeliveryTargets, SafeEvidence}
  alias Chimeway.Dispatch.ChannelAdapterConfig

  @spec run_delivery(Delivery.t()) ::
          {:ok, %{delivery: Delivery.t(), attempt: Chimeway.DeliveryAttempt.t()}}
          | {:error, atom(), term(), map()}
          | {:error, term()}
  def run_delivery(%Delivery{} = delivery) do
    with {:ok, dispatched} <- Deliveries.transition_status(delivery, :dispatched) do
      # D-17: per-channel adapter resolution; was hardcoded Application.get_env(:adapter).
      adapter = resolve_adapter(dispatched.channel)
      adapter_config = ChannelAdapterConfig.resolve(delivery.channel, [])

      execution_delivery =
        %{
          dispatched
          | recipient_address: delivery.recipient_address,
            render_data: delivery.render_data
        }

      {attempt_outcome, error_class, safe_attempt_facts} =
        execution_delivery
        |> adapter.deliver(adapter_config)
        |> classify()

      Deliveries.record_attempt(
        execution_delivery,
        Map.merge(safe_attempt_facts, %{
          outcome: attempt_outcome,
          error_class: error_class,
          # D-20: persist module name as inspect/1 string (no "Elixir." prefix).
          adapter_module: inspect(adapter)
        })
      )
    end
  end

  @spec run_target(Delivery.t()) ::
          {:ok,
           %{
             delivery: Delivery.t(),
             target: Chimeway.DeliveryTarget.t(),
             attempt: Chimeway.DeliveryTargetAttempt.t()
           }}
          | {:noop, term()}
          | {:error, term()}
  def run_target(%Delivery{} = delivery) do
    with {:ok, %{target: target, attempt: attempt}} <-
           DeliveryTargets.begin_target_attempt(delivery),
         {:ok, facts} <-
           target_adapter().deliver(
             %Chimeway.TargetAdapter.TargetEnvelope{delivery: delivery, target: target},
             []
           ),
         {:ok, result} <- DeliveryTargets.record_target_result(delivery, target, attempt, facts) do
      {:ok, result}
    end
  end

  defp target_adapter do
    Application.get_env(:chimeway, :target_adapter, Chimeway.Adapters.Logger)
  end

  # Adapter classification preservation (D-05). Returns only stable result facts.
  # error_class is nil on success; otherwise one of "temporary" | "permanent" | "bounced".
  defp classify({:ok, meta}), do: safe_attempt(:succeeded, nil, meta)
  defp classify({:error, :temporary, detail}), do: safe_attempt(:failed, "temporary", detail)
  defp classify({:error, :permanent, detail}), do: safe_attempt(:rejected, "permanent", detail)
  defp classify({:error, :bounced, detail}), do: safe_attempt(:bounced, "bounced", detail)

  # Fallback for unexpected adapter return shapes (BL-02 fix). Routes the unknown
  # tuple through the executor write path so it lands a DeliveryAttempt row and
  # transitions the delivery to :failed (terminal_or_failed_transition's catch-all
  # clause). The Oban worker's map_outcome_to_oban_return/4 catch-all then converges
  # or raises depending on attempt budget and status (oban_worker.ex).
  defp classify(_other), do: {:rejected, "unknown_classification", empty_attempt_facts()}

  defp safe_attempt(outcome, error_class, detail) do
    case SafeEvidence.attempt_attrs(%{
           outcome: outcome,
           error_class: error_class,
           provider_response: detail,
           provider_message_id: provider_message_id(detail)
         }) do
      {:ok, attrs} -> {outcome, error_class, attrs}
      {:error, :unsafe_evidence, _reason} -> {outcome, error_class, empty_attempt_facts()}
    end
  end

  defp provider_message_id(meta) when is_map(meta) do
    case SafeEvidence.provider_message_reference(
           Map.get(meta, :provider_message_id) || Map.get(meta, "provider_message_id")
         ) do
      {:ok, reference} -> reference
      {:error, :unsafe_evidence} -> nil
    end
  end

  defp provider_message_id(_meta), do: nil

  defp empty_attempt_facts, do: %{provider_response: %{}, provider_message_id: nil}

  # D-17: Per-channel adapter resolution.
  # Resolution order:
  #   1. Map.get(:channel_adapters, channel) — explicit per-channel override.
  #   2. :adapter config — legacy global fallback (D-18: kept unchanged, no deprecation).
  #
  # D-19: adapter_fallback telemetry fires ONLY when :channel_adapters is explicitly
  # configured AND the lookup misses. Silent when only :adapter is configured.
  #
  # T-29-15/T-29-18: :channel_adapters values come from compile-time config atoms;
  # the runtime channel string is used only for Map.get/2 against pre-existing
  # atom keys, never via String.to_atom — atom-table-safe.
  defp resolve_adapter(channel) when is_binary(channel) do
    channel_adapters = Application.get_env(:chimeway, :channel_adapters, %{})

    case Map.get(channel_adapters, channel) do
      nil ->
        fallback = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)

        if map_size(channel_adapters) > 0 do
          :telemetry.execute(
            [:chimeway, :dispatch, :adapter_fallback],
            %{count: 1},
            %{channel: channel, fallback_module: inspect(fallback)}
          )
        end

        fallback

      adapter_module ->
        adapter_module
    end
  end
end

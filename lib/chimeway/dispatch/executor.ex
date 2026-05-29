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

  alias Chimeway.{Deliveries, Delivery}
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

      {attempt_outcome, error_class, provider_response} =
        dispatched
        |> adapter.deliver(adapter_config)
        |> classify()

      Deliveries.record_attempt(dispatched, %{
        outcome: attempt_outcome,
        error_class: error_class,
        provider_response: provider_response,
        provider_message_id: extract_provider_message_id(provider_response),
        # D-20: persist module name as inspect/1 string (no "Elixir." prefix).
        adapter_module: inspect(adapter)
      })
    end
  end

  # Adapter classification preservation (D-05). Returns {outcome, error_class, detail}.
  # error_class is nil on success; otherwise one of "temporary" | "permanent" | "bounced".
  defp classify({:ok, meta}), do: {:succeeded, nil, meta}
  defp classify({:error, :temporary, detail}), do: {:failed, "temporary", detail}
  defp classify({:error, :permanent, detail}), do: {:rejected, "permanent", detail}
  defp classify({:error, :bounced, detail}), do: {:bounced, "bounced", detail}

  # Fallback for unexpected adapter return shapes (BL-02 fix). Routes the unknown
  # tuple through the executor write path so it lands a DeliveryAttempt row and
  # transitions the delivery to :failed (terminal_or_failed_transition's catch-all
  # clause). The Oban worker's map_outcome_to_oban_return/4 catch-all then converges
  # or raises depending on attempt budget and status (oban_worker.ex).
  defp classify(other) do
    {:rejected, "unknown_classification", {:unknown_adapter_return, other}}
  end

  defp extract_provider_message_id(meta) when is_map(meta) do
    case Map.get(meta, :provider_message_id) || Map.get(meta, "provider_message_id") do
      id when is_binary(id) -> id
      _ -> nil
    end
  end

  defp extract_provider_message_id(_), do: nil

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

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
      adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
      adapter_config = ChannelAdapterConfig.resolve(delivery.channel, [])

      {attempt_outcome, error_class, provider_response} =
        dispatched
        |> adapter.deliver(adapter_config)
        |> classify()

      Deliveries.record_attempt(dispatched, %{
        outcome: attempt_outcome,
        error_class: error_class,
        provider_response: provider_response
      })
    end
  end

  # Adapter classification preservation (D-05). Returns {outcome, error_class, detail}.
  # error_class is nil on success; otherwise one of "temporary" | "permanent" | "bounced".
  defp classify({:ok, meta}), do: {:succeeded, nil, meta}
  defp classify({:error, :temporary, detail}), do: {:failed, "temporary", detail}
  defp classify({:error, :permanent, detail}), do: {:rejected, "permanent", detail}
  defp classify({:error, :bounced, detail}), do: {:bounced, "bounced", detail}
end

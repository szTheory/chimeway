defmodule Chimeway.Dispatch.Executor do
  @moduledoc """
  Shared adapter execution for sync and Oban worker dispatch paths.
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

      {attempt_outcome, provider_response} =
        dispatched
        |> adapter.deliver(adapter_config)
        |> classify()

      Deliveries.record_attempt(dispatched, %{
        outcome: attempt_outcome,
        provider_response: provider_response
      })
    end
  end

  defp classify({:ok, meta}), do: {:succeeded, meta}
  defp classify({:error, :temporary, detail}), do: {:failed, detail}
  defp classify({:error, :permanent, detail}), do: {:rejected, detail}
  defp classify({:error, :bounced, detail}), do: {:bounced, detail}
end

defmodule Chimeway.Dispatch.Sync do
  @moduledoc """
  Synchronous dispatcher — runs the full delivery pipeline in the calling process.

  Pipeline per delivery:
  1. Terminal state guard — skip if already succeeded/suppressed/cancelled.
  2. Transition delivery to :dispatched (must succeed before adapter is called).
  3. Resolve adapter module from config.
  4. Call adapter.deliver/2.
  5. Classify outcome (dispatcher responsibility, not adapter's).
  6. Record attempt + transition to final status atomically.

  Swap to `Chimeway.Dispatch.Oban` in Phase 3 via config:

      config :chimeway, :dispatcher, Chimeway.Dispatch.Oban
  """

  @behaviour Chimeway.Dispatch

  alias Chimeway.Deliveries

  @terminal_states [:succeeded, :suppressed, :cancelled]

  @impl Chimeway.Dispatch
  def dispatch(notifications, _opts) when is_list(notifications) do
    results =
      Enum.flat_map(notifications, fn notification ->
        case Deliveries.plan_delivery(notification.id, :in_app) do
          {:ok, delivery} ->
            case Chimeway.Policy.evaluate(delivery, []) do
              {:ok, :proceed} ->
                [dispatch_delivery(delivery)]

              {:suppress, reason} ->
                case Deliveries.suppress_delivery(delivery, reason) do
                  {:ok, suppressed} -> [{:ok, suppressed}]
                  {:error, _} = err -> [err]
                end
            end

          {:error, _reason} ->
            []
        end
      end)

    {:ok, results}
  end

  # --- Private ---

  defp dispatch_delivery(%{status: status} = delivery) when status in @terminal_states do
    {:ok, delivery}
  end

  defp dispatch_delivery(delivery) do
    case Chimeway.Policy.evaluate(delivery, check_read_state: delivery.delay_fallback) do
      {:suppress, reason} ->
        Deliveries.suppress_delivery(delivery, reason)

      {:ok, :proceed} ->
        do_dispatch(delivery)
    end
  end

  defp do_dispatch(delivery) do
    with {:ok, dispatched} <- Deliveries.transition_status(delivery, :dispatched) do
      adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
      channel_key = String.to_atom("adapter_#{delivery.channel}")
      adapter_config = Application.get_env(:chimeway, channel_key, [])

      {attempt_outcome, provider_response} =
        case adapter.deliver(dispatched, adapter_config) do
          {:ok, meta} -> {:succeeded, meta}
          {:error, :temporary, detail} -> {:failed, detail}
          {:error, :permanent, detail} -> {:rejected, detail}
          {:error, :bounced, detail} -> {:bounced, detail}
        end

      case Deliveries.record_attempt(dispatched, %{
             outcome: attempt_outcome,
             provider_response: provider_response
           }) do
        {:ok, %{delivery: updated_delivery}} -> {:ok, updated_delivery}
        {:error, step, reason, _changes} -> {:error, {step, reason}}
      end
    end
  end
end

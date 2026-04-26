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

  alias Chimeway.{Deliveries, DeliveryPlanning}
  alias Chimeway.Dispatch.Executor
  alias Chimeway.Policy
  alias Chimeway.Telemetry

  @impl Chimeway.Dispatch
  def dispatch(notifications, opts) when is_list(notifications) do
    notifications
    |> Enum.reduce_while({:ok, []}, fn notification, {:ok, acc} ->
      case dispatch_notification(notification, opts) do
        {:ok, results} -> {:cont, {:ok, [results | acc]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, grouped_results} -> {:ok, grouped_results |> Enum.reverse() |> List.flatten()}
      {:error, _reason} = error -> error
    end
  end

  defp dispatch_notification(notification, opts) do
    case DeliveryPlanning.plan_notification(notification, opts) do
      {:ok, deliveries} ->
        {:ok, Enum.map(deliveries, &dispatch_planned_delivery/1)}

      {:error, reason} ->
        planning_failed(reason)
    end
  end

  # --- Private ---

  defp dispatch_planned_delivery(%{status: :suppressed} = delivery), do: {:ok, delivery}
  defp dispatch_planned_delivery(delivery), do: dispatch_delivery(delivery)

  defp dispatch_delivery(%{status: status} = delivery) do
    if status in Deliveries.terminal_states() do
      {:ok, delivery}
    else
      case Policy.evaluate(delivery, check_read_state: delivery.delay_fallback) do
        {:suppress, reason} -> Deliveries.suppress_delivery(delivery, reason, checkpoint: :perform)
        {:ok, :proceed} -> do_dispatch_with_telemetry(delivery)
      end
    end
  end

  defp do_dispatch_with_telemetry(delivery) do
    Telemetry.span(
      [:dispatch, :sync],
      Telemetry.safe_meta(%{
        delivery_id: delivery.id,
        channel: delivery.channel,
        notification_key: Map.get(delivery.metadata || %{}, "notification_key")
      }),
      fn ->
        result = do_dispatch(delivery)
        outcome = if match?({:ok, _}, result), do: :succeeded, else: :failed
        {result, Telemetry.safe_meta(%{outcome: outcome})}
      end
    )
  end

  defp do_dispatch(delivery) do
    case Executor.run_delivery(delivery) do
      {:ok, %{delivery: updated_delivery}} ->
        {:ok, updated_delivery}

      {:error, step, reason, _changes} ->
        {:error, {step, reason}}

      {:error, _reason} = error ->
        error
    end
  end

  defp planning_failed(reason), do: {:error, {:planning_failed, reason}}
end
